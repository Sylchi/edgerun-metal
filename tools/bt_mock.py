#!/usr/bin/env python3
"""Mock Bluetooth HCI UART controller for QEMU testing.

Listens on a Unix socket and speaks the HCI H4 protocol over it.
QEMU connects its emulated COM2 (-serial unix:...) to this socket.

Responds to HCI commands with Command Complete events and sends
periodic LE Advertising Reports to exercise the full BLE scan pipeline.
"""

import argparse
import os
import socket
import struct
import sys
import time

# HCI packet types
HCI_CMD_PKT = 0x01
HCI_EVT_PKT = 0x04

# HCI event codes
HCI_EVT_CMD_COMPLETE = 0x0E
HCI_EVT_LE_META = 0x3E

# LE Meta sub-events
HCI_EVT_LE_ADV_REPORT = 0x02


def build_cmd_complete(opcode: int, status: int = 0,
                       ret_params: bytes = b"",
                       num_packets: int = 1) -> bytes:
    """Build a Command Complete HCI event packet."""
    params = struct.pack("<BHB", num_packets, opcode, status) + ret_params
    return struct.pack("<BBB", HCI_EVT_PKT, HCI_EVT_CMD_COMPLETE,
                       len(params)) + params


def build_le_adv_report(mac: bytes, data: bytes, rssi: int = -60) -> bytes:
    """Build an LE Advertising Report HCI event packet."""
    if len(mac) != 6:
        raise ValueError("MAC must be 6 bytes")
    report_data = bytes([
        0x00,        # event_type: connectable undirected
        0x00,        # address_type: public
    ]) + mac + bytes([len(data)]) + data + struct.pack("<b", rssi)
    params = bytes([HCI_EVT_LE_ADV_REPORT, 1]) + report_data
    sub_event = HCI_EVT_LE_ADV_REPORT
    inner = bytes([sub_event]) + params
    return struct.pack("<BBB", HCI_EVT_PKT, HCI_EVT_LE_META,
                       len(inner)) + inner


class HCIController:
    """Minimal HCI controller that responds to commands and sends adverts."""

    def __init__(self, conn, adv_interval: float = 2.0):
        self.conn = conn
        self.adv_interval = adv_interval
        self.last_adv = time.time() + 5.0  # wait 5s before first adv
        self.manufacturer = 0x005D  # Microchip Technology
        self.hci_ver = 5   # Bluetooth 4.0
        self.hci_rev = 0
        self.lmp_ver = 5
        self.lmp_subver = 0

    def send_raw(self, data: bytes):
        print(f"  >> TX {data.hex()}", flush=True)
        self.conn.sendall(data)

    def send_cmd_complete(self, opcode: int, status: int = 0,
                          ret_params: bytes = b""):
        pkt = build_cmd_complete(opcode, status, ret_params)
        self.send_raw(pkt)

    def handle_reset(self):
        self.send_cmd_complete(0x0C03)

    def handle_read_local_version(self):
        params = struct.pack("<BHBHH",
                             self.hci_ver, self.hci_rev,
                             self.lmp_ver,
                             self.manufacturer, self.lmp_subver)
        self.send_cmd_complete(0x0401, ret_params=params)

    def handle_le_set_scan_params(self, params: bytes):
        self.send_cmd_complete(0x200B)

    def handle_le_set_scan_enable(self, params: bytes):
        enable = params[0] if params else 0
        self.send_cmd_complete(0x200C)
        if enable:
            # Send an advertisement shortly after enabling
            self.last_adv = time.time() - self.adv_interval + 0.5
        else:
            # Stop sending
            self.last_adv = time.time() + 9999

    def handle_hci_cmd(self, opcode: int, params: bytes):
        handlers = {
            0x0C03: ("reset", lambda: self.handle_reset()),
            0x0401: ("read_local_version",
                     lambda: self.handle_read_local_version()),
            0x200B: ("le_set_scan_params",
                     lambda: self.handle_le_set_scan_params(params)),
            0x200C: ("le_set_scan_enable",
                     lambda: self.handle_le_set_scan_enable(params)),
        }
        if opcode in handlers:
            name, handler = handlers[opcode]
            print(f"  HCI cmd: {name} (0x{opcode:04X})", flush=True)
            handler()
        else:
            print(f"  HCI cmd: unknown 0x{opcode:04X}", flush=True)
            self.send_cmd_complete(opcode, status=0)

    def maybe_send_adv(self):
        now = time.time()
        if now - self.last_adv < self.adv_interval:
            return
        self.last_adv = now

        mac = bytes([0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0x01])
        adv_data = bytes([
            0x02, 0x01, 0x06,         # flags: LE General Discoverable + BR/EDR
            0x09, 0x09,               # Complete Local Name
        ]) + b"edgerun-mock"
        pkt = build_le_adv_report(mac, adv_data)
        print(f"  -> LE Advertising Report: {mac.hex(':')}", flush=True)
        self.send_raw(pkt)

    def run(self):
        buf = bytearray()
        print("Mock HCI controller connected.", flush=True)
        try:
            while True:
                # Check for incoming data with a short timeout
                self.conn.settimeout(0.1)
                try:
                    chunk = self.conn.recv(1024)
                    if not chunk:
                        print("Connection closed.", flush=True)
                        return
                    print(f"  << RX {chunk.hex()}", flush=True)
                    buf.extend(chunk)
                except socket.timeout:
                    pass

                # Parse complete HCI commands from buffer
                while len(buf) >= 4:
                    pkt_type = buf[0]
                    if pkt_type != HCI_CMD_PKT:
                        print(f"  Unexpected packet type: 0x{pkt_type:02X}",
                              flush=True)
                        buf.pop(0)
                        continue
                    opcode = struct.unpack_from("<H", buf, 1)[0]
                    param_len = buf[3]
                    total = 4 + param_len
                    if len(buf) < total:
                        break
                    params = bytes(buf[4:total])
                    del buf[:total]
                    self.handle_hci_cmd(opcode, params)

                self.maybe_send_adv()
        except (ConnectionError, BrokenPipeError, OSError):
            print("Connection lost.", flush=True)
        finally:
            try:
                self.conn.close()
            except OSError:
                pass


def main():
    ap = argparse.ArgumentParser(
        description="Mock Bluetooth HCI UART controller for QEMU testing")
    ap.add_argument("--socket", default=None,
                    help="Unix socket path (listen)")
    ap.add_argument("--connect", default=None,
                    help="Connect to existing socket instead of listening")
    ap.add_argument("--tcp", default=None,
                    help="TCP address:port to listen on (e.g. 127.0.0.1:9900)")
    ap.add_argument("--adv-interval", type=float, default=2.0,
                    help="Seconds between fake advertisements (default: 2.0)")
    args = ap.parse_args()

    if args.tcp:
        host, port_str = args.tcp.split(":")
        port = int(port_str)
        server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind((host, port))
        server.listen(1)
        print(f"Listening on TCP {host}:{port}", flush=True)
        try:
            while True:
                conn, addr = server.accept()
                conn.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
                print(f"Connection from {addr}", flush=True)
                controller = HCIController(conn, adv_interval=args.adv_interval)
                controller.run()
        except KeyboardInterrupt:
            print("\nShutting down.", flush=True)
        finally:
            server.close()
    elif args.socket or not args.connect:
        socket_path = args.socket or "/tmp/bt_mock.sock"
        try:
            os.unlink(socket_path)
        except FileNotFoundError:
            pass

        server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        server.bind(socket_path)
        server.listen(1)
        os.chmod(socket_path, 0o666)
        print(f"Listening on {socket_path}", flush=True)
        try:
            while True:
                conn, _ = server.accept()
                controller = HCIController(conn, adv_interval=args.adv_interval)
                controller.run()
        except KeyboardInterrupt:
            print("\nShutting down.", flush=True)
        finally:
            server.close()
            try:
                os.unlink(socket_path)
            except FileNotFoundError:
                pass
    else:
        socket_path = args.connect
        for attempt in range(30):
            try:
                sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                sock.connect(socket_path)
                break
            except (ConnectionRefusedError, FileNotFoundError) as e:
                sock.close()
                print(f"Waiting for socket ({e})...", flush=True)
                time.sleep(0.2)
        else:
            print(f"Failed to connect to {socket_path}", flush=True)
            sys.exit(1)
        print(f"Connected to {socket_path}", flush=True)
        controller = HCIController(sock, adv_interval=args.adv_interval)
        controller.run()


if __name__ == "__main__":
    main()
