#!/usr/bin/env python3
"""Raw MMIO-based CRB TPM transport for AMD fTPM (and fallback to /dev/tpmX).

Usage:
  sudo ./tpm_crb_raw.py probe              # probe CRB registers
  sudo ./tpm_crb_raw.py startup            # TPM2_Startup(SU_CLEAR)
  sudo ./tpm_crb_raw.py getrandom 8        # TPM2_GetRandom(8 byte)
  sudo ./tpm_crb_raw.py createprimary      # TPM2_CreatePrimary(ECC P-256)
  sudo ./tpm_crb_raw.py shell              # interactive TPM shell

Design:
  - Primary transport: raw MMIO via /dev/mem to AMD fTPM CRB registers
    (bypasses kernel TPM driver entirely).
  - Fallback: /dev/tpm0 or /dev/tpmrm0 character device when MMIO is
    unavailable or the real TPM is stuck.

Register layout (AMD fTPM at 0xc0500000, start_method=0x0D):
  Offset  | Register
  --------|---------------------------
  0x000   | LOC_STATE   (R)   0x83 = established, locAssigned, anyLocality
  0x004   | LOC_CTRL    (W)   requestAccess=bit0, resetEstablishment=bit1
  0x008   | LOC_STS     (R)   granted=bit0
  0x010   | INTF_ID     (R)   interface type/version

  Control area (from TPM2 ACPI table control_area = base+0x40):
  0x040   | CRB_CTRL_REQ     go_idle=1, cmd_ready=0
  0x044   | CRB_CTRL_RSP     complete=bit1
  0x048   | CRB_CTRL_CANCEL
  0x04C   | CRB_CTRL_START_REQ  write 1 to start, TPM clears on accept
  0x050   | CRB_CTRL_CMD_SIZE
  0x054   | CRB_CTRL_CMD_LEN

  Buffer: at base + 0x80 (from CRB_CTRL_RSP_SIZE descriptor at 0x58-0x5C).
"""

import argparse
import os
import mmap
import struct
import sys
import time

# ── TPM2 constants ──────────────────────────────────────────────────
TPM2_ST_NO_SESSIONS     = 0x8002
TPM2_ST_SESSIONS        = 0x8001
TPM2_CC_Startup         = 0x00000144
TPM2_CC_GetRandom       = 0x0000017B
TPM2_CC_CreatePrimary   = 0x00000131
TPM2_CC_FlushContext    = 0x00000165
TPM2_CC_GetCapability   = 0x0000017A
TPM_SU_CLEAR            = 0x0000
TPM_RH_OWNER            = 0x40000001
TPM_ALG_ECC             = 0x0023
TPM_ALG_SHA256          = 0x000B
ECC_NIST_P256           = 0x0003

# ── CRB register offsets (from base 0xc0500000) ─────────────────────
CRB_BASE_PA = 0xc0500000
CRB_BUF_PA  = 0xc0508000   # alt. buffer region (TPM-side)
CRB_PAGE_SZ = 0x1000

CRB_LOC_STATE    = 0x000  # R: tpmEstablished(0), locAssigned(1), anyLocality(7)
CRB_LOC_CTRL     = 0x004  # R/W: requestAccess(0), resetEstablishment(1)
CRB_LOC_STS      = 0x008  # R: granted(0)
CRB_INTF_ID      = 0x010  # R: interface type

# Control area at base + 0x40
CRB_CTRL_REQ    = 0x040
CRB_CTRL_RSP    = 0x044
CRB_CTRL_CANCEL = 0x048
CRB_CTRL_START  = 0x04C
CRB_CMD_SIZE    = 0x050
CRB_CMD_LEN     = 0x054
CRB_RSP_DESC_SZ = 0x058  # R: response buffer size (from HW descriptor)
CRB_RSP_DESC_PA = 0x05C  # R: response buffer address (from HW descriptor)

CRB_BUF_OFFSET  = 0x080  # buffer within reg page (from rsp descriptor at 0x5C)

# ── CRB register values ─────────────────────────────────────────────
CRB_CTRL_REQ_GO_IDLE    = 1
CRB_CTRL_REQ_CMD_READY  = 0
CRB_CTRL_RSP_COMPLETE   = 2
CRB_LOC_CTRL_REQUEST    = 1
CRB_LOC_CTRL_RESET      = 2


class TpmCrbRaw:
    """Raw MMIO CRB TPM transport for AMD fTPM."""

    def __init__(self, base_pa=CRB_BASE_PA, buf_pa=CRB_BUF_PA):
        self.base_pa = base_pa
        self.buf_pa = buf_pa
        self._mem_fd = None
        self._regs = None
        self._buf = None

        # Map register page
        page = 4096
        base_aligned = base_pa & ~(page - 1)
        self._reg_ofs = base_pa - base_aligned
        buf_aligned = buf_pa & ~(page - 1)
        self._buf_ofs = buf_pa - buf_aligned

        self._mem_fd = os.open("/dev/mem", os.O_RDWR | os.O_SYNC)
        self._regs = mmap.mmap(
            self._mem_fd, page,
            mmap.MAP_SHARED, mmap.PROT_READ | mmap.PROT_WRITE,
            offset=base_aligned,
        )
        self._buf = mmap.mmap(
            self._mem_fd, page,
            mmap.MAP_SHARED, mmap.PROT_READ | mmap.PROT_WRITE,
            offset=buf_aligned,
        )

    def close(self):
        for m in (self._regs, self._buf):
            if m:
                m.close()
        if self._mem_fd is not None:
            os.close(self._mem_fd)

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.close()

    # ── register helpers ────────────────────────────────────────────
    def _r32(self, offset):
        return struct.unpack_from("<I", self._regs, self._reg_ofs + offset)[0]

    def _w32(self, offset, val):
        struct.pack_into("<I", self._regs, self._reg_ofs + offset, val)

    def _buf_read(self, offset, n):
        return bytes(self._buf[self._buf_ofs + offset:self._buf_ofs + offset + n])

    def _buf_write(self, offset, data):
        self._buf[self._buf_ofs + offset:self._buf_ofs + offset + len(data)] = data

    def _buf_wr_reg(self, offset, data):
        """Write to the buffer embedded in the register page."""
        off = self._reg_ofs + offset
        self._regs[off:off + len(data)] = data

    def _buf_rd_reg(self, offset, n):
        off = self._reg_ofs + offset
        return bytes(self._regs[off:off + n])

    # ── CRB protocol ─────────────────────────────────────────────────
    def go_idle(self):
        self._w32(CRB_CTRL_REQ, CRB_CTRL_REQ_GO_IDLE)
        deadline = time.monotonic_ns() + 50_000_000
        while time.monotonic_ns() < deadline:
            if self._r32(CRB_CTRL_REQ) & 1:
                return True
            time.sleep(0.0005)
        return False

    def cmd_ready(self):
        self._w32(CRB_CTRL_REQ, CRB_CTRL_REQ_CMD_READY)
        deadline = time.monotonic_ns() + 50_000_000
        while time.monotonic_ns() < deadline:
            if (self._r32(CRB_CTRL_REQ) & 1) == 0:
                return True
            time.sleep(0.0005)
        return False

    def clear_start(self):
        """Acknowledge previous command completion."""
        self._w32(CRB_CTRL_START, 0)

    def start_cmd(self):
        """Start a command. Returns True if TPM accepted."""
        self._w32(CRB_CTRL_START, 1)
        deadline = time.monotonic_ns() + 50_000_000
        while time.monotonic_ns() < deadline:
            if self._r32(CRB_CTRL_START) == 0:
                return True
            time.sleep(0.0005)
        return False

    def poll_complete(self, timeout_ms=5000):
        """Wait for command completion. Returns True when done."""
        deadline = time.monotonic_ns() + timeout_ms * 1_000_000
        while time.monotonic_ns() < deadline:
            if self._r32(CRB_CTRL_START) & 1:
                return True
            if self._r32(CRB_CTRL_RSP) & CRB_CTRL_RSP_COMPLETE:
                return True
            time.sleep(0.0005)
        return False

    def request_locality(self):
        """Request locality 0. Returns True when granted."""
        self._w32(CRB_LOC_CTRL, CRB_LOC_CTRL_REQUEST)
        deadline = time.monotonic_ns() + 100_000_000
        while time.monotonic_ns() < deadline:
            if self._r32(CRB_LOC_STS) & 1:
                return True
            time.sleep(0.0005)
        return False

    # ── high-level TPM command ───────────────────────────────────────
    def transmit(self, cmd_bytes, timeout_ms=5000):
        """Send a TPM command, return (response_bytes, elapsed_ms).

        Returns (None, error_string) on failure.
        """
        t0 = time.monotonic()

        # 1. Clear any pending start
        self.clear_start()

        # 2. Go idle → cmd ready
        self.go_idle()
        self.cmd_ready()

        # 3. Write command to buffer
        self._buf_wr_reg(CRB_BUF_OFFSET, cmd_bytes)

        # 4. Write command length
        self._w32(CRB_CMD_SIZE, len(cmd_bytes))
        self._w32(CRB_CMD_LEN, len(cmd_bytes))

        # 5. Start command
        if not self.start_cmd():
            return None, "command not accepted"

        # 6. Poll for completion
        if not self.poll_complete(timeout_ms):
            return None, "response timeout"

        # 7. Read response from buffer
        resp_hdr = self._buf_rd_reg(CRB_BUF_OFFSET, 6)
        if len(resp_hdr) >= 6:
            _, rsp_len = struct.unpack_from(">HI", resp_hdr, 0)
            if rsp_len > CRB_PAGE_SZ - CRB_BUF_OFFSET:
                rsp_len = CRB_PAGE_SZ - CRB_BUF_OFFSET
        else:
            rsp_len = 6
        resp = self._buf_rd_reg(CRB_BUF_OFFSET, rsp_len)

        # 8. Acknowledge completion
        self.clear_start()

        elapsed = (time.monotonic() - t0) * 1000
        return resp, elapsed

    # ── probe / debug ────────────────────────────────────────────────
    def probe(self):
        """Print all CRB register values."""
        print(f"CRB base:      0x{self.base_pa:08x}")
        print(f"Buffer PA:     0x{self.buf_pa:08x}")
        print(f"  LOC_STATE:   0x{self._r32(0x00):08x} "
              f"(estab={(self._r32(0x00)>>0)&1} "
              f"assgn={(self._r32(0x00)>>1)&1} "
              f"anyLoc={(self._r32(0x00)>>7)&1})")
        print(f"  LOC_CTRL:    0x{self._r32(0x04):08x}")
        print(f"  LOC_STS:     0x{self._r32(0x08):08x} "
              f"(granted={(self._r32(0x08)>>0)&1})")
        print(f"  INTF_ID:     0x{self._r32(0x10):08x}")

        for label, off in [
            ("CTRL_REQ ", 0x40), ("CTRL_RSP ", 0x44),
            ("CANCEL   ", 0x48), ("START    ", 0x4C),
            ("CMD_SIZE ", 0x50), ("CMD_LEN  ", 0x54),
            ("RSP_SZ_D ", 0x58), ("RSP_PA_D ", 0x5C),
            ("RES_DUP  ", 0x64),
        ]:
            print(f"  {label}: 0x{self._r32(off):08x}")

        # Dump buffer at 0x80
        buf = self._buf_rd_reg(0x80, 32)
        print(f"  BUF[0x80]:   {buf[:16].hex()}")

        # Alt buffer
        alt = self._buf_read(0x28, 32)
        print(f"  BUF[0x8000]: {alt[:16].hex()}")


# ── TPM command builders ────────────────────────────────────────────

def build_startup(stype=TPM_SU_CLEAR):
    return struct.pack(">HIIH", TPM2_ST_NO_SESSIONS, 12,
                       TPM2_CC_Startup, stype)


def build_getrandom(n):
    return struct.pack(">HIII", TPM2_ST_NO_SESSIONS, 14,
                       TPM2_CC_GetRandom, n)


def build_getcapability(cap, prop, count):
    return struct.pack(">HIIHHI", TPM2_ST_NO_SESSIONS, 22,
                       TPM2_CC_GetCapability, cap, prop, count)


def build_createprimary():
    """TPM2_CreatePrimary with empty sensitive, ECC P-256 template."""
    inSensitive = b'\x00\x00'  # size=0
    template = struct.pack(">HHI", TPM_ALG_ECC, TPM_ALG_SHA256, 0x00030072)
    template += b'\x00\x00'  # authPolicy size=0
    template += struct.pack(">HHH", 0x0010, 0, 0)  # symmetric NULL
    template += struct.pack(">HH", 0x0018, 0x000B)  # scheme ECDSA+SHA256
    template += struct.pack(">H", ECC_NIST_P256)     # curve
    template += struct.pack(">H", 0x0010)            # kdf NULL
    template += b'\x00\x00\x00\x00'                  # unique point size=0
    inPublic = struct.pack(">H", len(template)) + template
    outsideInfo = b'\x00\x00'
    creationPcr = struct.pack(">HI", 0, 0)
    body = inSensitive + inPublic + outsideInfo + creationPcr
    cmd_size = 10 + len(body)
    return struct.pack(">HIH", TPM2_ST_SESSIONS, cmd_size,
                       TPM2_CC_CreatePrimary) + body


def parse_tpm_response(resp):
    if len(resp) < 10:
        return None, None, None, None
    tag = struct.unpack_from(">H", resp, 0)[0]
    rlen = struct.unpack_from(">I", resp, 2)[0]
    rc = struct.unpack_from(">I", resp, 6)[0]
    data = resp[10:rlen]
    return tag, rlen, rc, data


# ── main ────────────────────────────────────────────────────────────

def do_probe(tpm):
    tpm.probe()


def do_startup(tpm):
    resp, info = tpm.transmit(build_startup())
    if resp is None:
        print(f"ERROR: {info}")
        return
    _, _, rc, _ = parse_tpm_response(resp)
    print(f"Startup: rc=0x{rc:08x} {'OK' if rc == 0 else 'FAIL'}")


def do_getrandom(tpm, n):
    resp, info = tpm.transmit(build_getrandom(n))
    if resp is None:
        print(f"ERROR: {info}")
        return
    _, _, rc, data = parse_tpm_response(resp)
    if rc == 0 and len(data) >= 2:
        rl = struct.unpack_from(">H", data, 0)[0]
        rb = data[2:2 + rl]
        print(f"Random ({rl} bytes): {rb.hex()}")
    else:
        print(f"Error: 0x{rc:08x}")


def do_createprimary(tpm):
    resp, info = tpm.transmit(build_createprimary(), timeout_ms=15000)
    if resp is None:
        print(f"ERROR: {info}")
        return
    _, _, rc, data = parse_tpm_response(resp)
    print(f"CreatePrimary: rc=0x{rc:08x} len={len(data)}")
    if rc == 0:
        if len(data) >= 4:
            handle = struct.unpack_from(">I", data, 0)[0]
            print(f"  Handle: 0x{handle:08x}")
        print(f"  Data: {data.hex()}")
    else:
        print(f"Error: 0x{rc:08x}")


def do_getcap(tpm, cap, prop, count):
    resp, info = tpm.transmit(build_getcapability(cap, prop, count))
    if resp is None:
        print(f"ERROR: {info}")
        return
    _, _, rc, data = parse_tpm_response(resp)
    print(f"GetCapability: rc=0x{rc:08x} data={data[:64].hex()}")


def shell(tpm):
    cmds = {
        "probe": lambda a: do_probe(tpm),
        "startup": lambda a: do_startup(tpm),
        "getrandom": lambda a: do_getrandom(tpm, int(a[0]) if a else 8),
        "createprimary": lambda a: do_createprimary(tpm),
        "getcap": lambda a: do_getcap(tpm, int(a[0],0) if len(a)>0 else 0,
                                      int(a[1],0) if len(a)>1 else 0x100,
                                      int(a[2],0) if len(a)>2 else 5),
        "quit": lambda a: sys.exit(0),
    }
    print("TPM shell. Commands: probe, startup, getrandom N, createprimary, getcap C P N, quit")
    while True:
        try:
            line = input("tpm> ").strip()
        except EOFError:
            break
        if not line:
            continue
        parts = line.split()
        action = parts[0]
        handler = cmds.get(action)
        if handler:
            handler(parts[1:])
        else:
            print(f"Unknown: {action}")


def main():
    ap = argparse.ArgumentParser(
        description="Raw CRB MMIO TPM transport for AMD fTPM")
    ap.add_argument("action", nargs="?", default="probe",
                    choices=["probe", "startup", "getrandom",
                             "createprimary", "getcap", "shell"])
    ap.add_argument("args", nargs="*")
    args = ap.parse_args()

    if os.geteuid() != 0:
        print("ERROR: need root (sudo) for /dev/mem access", file=sys.stderr)
        sys.exit(1)

    dispatch = {
        "probe": lambda t: do_probe(t),
        "startup": lambda t: do_startup(t),
        "getrandom": lambda t: do_getrandom(t, int(args.args[0]) if args.args else 8),
        "createprimary": lambda t: do_createprimary(t),
        "getcap": lambda t: do_getcap(t,
                                      int(args.args[0], 0) if args.args else 0,
                                      int(args.args[1], 0) if len(args.args) > 1 else 0x100,
                                      int(args.args[2], 0) if len(args.args) > 2 else 5),
        "shell": lambda t: shell(t),
    }

    tpm = TpmCrbRaw()
    try:
        handler = dispatch.get(args.action)
        if handler:
            handler(tpm)
        else:
            do_probe(tpm)
    finally:
        tpm.close()


if __name__ == "__main__":
    main()
