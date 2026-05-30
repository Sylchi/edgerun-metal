# EdgeRun Identity Routing Roadmap

## Vision

Replace the current legacy Tor-over-TCP client with a native identity-addressed
capability OS where every process, device, and user has a fixed identity and the
kernel routes cells by identity — not by IP address.

The full mapping from Tor semantics to OS primitives is specified in
`~/tor-spec/00-os-mapping.md`.

---

## Current State (Legacy Path)

The existing Tor code (`asm/x86_64/crypto/tor_*.asm`, `asm/x86_64/net/`) is a
legacy Tor client that speaks the real Tor link protocol over TCP via a hardcoded
guard relay (`10.0.2.2:9001`). It is retained as-is — no code is deleted.

| Module | State | Reusable For Native Path |
|--------|-------|--------------------------|
| `tor_cell.asm` — cell I/O, circuits, streams over TCP | Working 1-hop | Cell format, circuit table layout, relay cell processing |
| `tor.asm` — client orchestrator, init, poll | Working 1-hop | Bootstrap flow reference |
| `tor_ntor.asm` — ntor handshake | Working client side; **stubs:** `_fe_invert`, `_curve25519_ladder_step`, `er_tor_curve25519_scalar_mult` | Key derivation, handshake protocol — needs real scalar mult |
| `tor_aes.asm` — AES-128-CTR | Working | Reusable as-is |
| `tor_digest.asm` — SHA-256/HMAC via TPM | Working | Replace with software SHA-256 once verified |
| `sha256.asm` — software SHA-256 | Working (bug fixed) | Replaces TPM path for digest |
| `identity.asm` — BLAKE3 identity module | Working | Core primitive for native path |
| `preimage.asm` — domain-separated hashing | Working | Reusable as-is |
| `blake3.asm` — full BLAKE3 | Working | Reusable as-is |
| `net/tcp.asm` — TCP stack | Working | Deprecated — only needed for exit bridge |

---

## Phase 0: Critical Crypto Gaps

These are the minimum cryptographic primitives missing from the ntor path.
Without these, identity-based routing cannot establish encrypted circuits.

### P0a — Curve25519 field inversion (`_fe_invert`)
- **File:** `asm/x86_64/crypto/tor_ntor.asm:412`
- **Current:** Stub — copies input to output
- **Work:** Implement a^(p-2) mod 2^255-19 using existing `_fe_mul`, `_fe_sq`
- **Forms basis of:** Curve25519 scalar multiplication

### P0b — Curve25519 Montgomery ladder (`_curve25519_ladder_step`)
- **File:** `asm/x86_64/crypto/tor_ntor.asm:426`
- **Current:** Stub — only `ret`
- **Work:** Implement the Montgomery ladder step function
- **Dependencies:** P0a (inversion needed for ladder finalization)

### P0c — `er_tor_curve25519_scalar_mult`
- **File:** `asm/x86_64/crypto/tor_ntor.asm:455`
- **Current:** Placeholder — copies base point
- **Work:** Replace with real scalar multiplication using P0b
- **Forms basis of:** ntor handshake for both legacy and native paths

### P0d — Ed25519 signing/verification
- **File:** Does not exist yet (constants in `identity.asm`)
- **Work:** Implement Ed25519 for device identity attestation
- **Needed for:** TPM-backed device identity, beacon signatures
- **Optional for:** legacy Tor CERTS cell (exit bridge path)

---

## Phase 1: Kernel Identity Routing Primitives

Create the kernel syscall interface described in `00-os-mapping.md` section
"Kernel Primitives."

### P1a — `register_handler` syscall
- `register_handler(identity[32], ring_buffer_base, ring_buffer_size)`
- Registers a process as the handler for a given identity
- Kernel creates a shared-memory ring buffer for incoming cells
- One identity per process (enforced at kernel level)
- **Replaces:** `tor_cell.asm`'s circuit listen path
- **New file:** `asm/x86_64/crypto/identity_route.asm`

### P1b — `open_circuit` syscall
- `open_circuit(destination_identity[32]) → circuit_fd`
- Kernel looks up destination in routing table
- Returns a circuit handle (fd) referencing a slot in the per-process circuit table
- **Replaces:** `er_tor_circuit_create` TCP-based circuit
- **New file:** `asm/x86_64/net/circuit.asm`

### P1c — `send` / `recv` cell syscalls
- `send(circuit_fd, cell[256])` — fire-and-forget
- `recv(circuit_fd) → cell[256]` — non-blocking poll
- Kernel encrypts/decrypts per-hop in the send/recv path
- **Replaces:** `er_tor_send_relay`, `er_tor_recv_relay` over TCP
- **Extends:** `asm/x86_64/net/circuit.asm`

### P1d — Per-process circuit table
- Fixed-size table (preallocated at process exec)
- Entry: `[destination_id, path[5], keys[5], window_state, stream_table]`
- Kernel manages the table; process accesses via circuit_fd
- **Reuses:** Circuit table layout from `tor_constants.inc`
- **New file:** `asm/x86_64/kernel/circuit_table.asm`

### P1e — Kernel cell type enum
- Replace Tor command byte with kernel cell type enum
- Types: `CELL_DATA`, `CELL_CREATE`, `CELL_CREATED`, `CELL_DESTROY`,
  `CELL_SENDME`, `CELL_BEACON`, `CELL_REGISTER`, `CELL_ROUTE`
- Fixed 256B cell in kernel ring buffers
- **New file:** `asm/x86_64/net/cell_constants.inc`

---

## Phase 2: Multi-Hop Circuit Path

### P2a — Path extension
- `extend_circuit(circuit_fd, next_hop_identity)` syscall
- Kernel discovers next hop from routing table
- Performs ntor handshake with next hop
- **Dependencies:** Phase 0 (real Curve25519), Phase 1 (circuit table)
- **Reuses:** ntor handshake protocol from `tor_ntor.asm`

### P2b — Telescopic encryption in kernel send/recv
- On send: encrypt cell payload N times (innermost → outermost)
- On recv: decrypt once per hop, check recognition + digest
- If recognized: deliver to handler
- If not: forward to next hop via routing table
- **Reuses:** `tor_aes.asm` (AES-CTR), `sha256.asm` (digest)
- **Extends:** `asm/x86_64/net/circuit.asm`

### P2c — Per-hop ntor key agreement
- At each extend step, derive `Kf/Kb` (AES keys) and `Df/Db` (digest seeds)
- Store in circuit table path slot
- **Dependencies:** Phase 0 (real Curve25519)
- **Reuses:** `er_tor_ntor_client_process` KDF

---

## Phase 3: Directory Authority + Device Discovery

### P3a — Directory Authority process
- **New process:** `er_da` — userspace process
- Maintains routing table: identity → device_id → MAC/link
- Privileged syscall: `set_route(id, next_hop, cost, expiry)` — DA only
- Process registration: `register_handler(id)` at exec time
- Boilerplate process in `asm/x86_64/crypto/da.asm`

### P3b — Device beacon protocol
- Raw ethernet broadcast on LAN
- Beacon payload: `[device_id[32], timestamp, nonce, signature]`
- Neighbor table: fixed N entries per device
- Device discovery daemon (built into kernel or DA)
- **New file:** `asm/x86_64/net/beacon.asm`
- **New MAC:** Use NIC MAC as link-layer address

### P3c — Routing table
- Three-level map: `app_id → device_id`, `device_id → MAC + link_key`, `user_id → device_id`
- Fixed-size, preallocated
- DA updates via `set_route` syscall
- **New file:** `asm/x86_64/net/route_table.asm`

### P3d — Process identity at exec
- Kernel assigns identity `= H(binary + TPM_measurement)` at exec time
- Stores in process control block
- Returns to process via `register_handler` syscall chain
- **Extends:** kernel exec path (`entry.asm`, `kernel_main.asm`)

---

## Phase 4: Migrate From Legacy Tor to Native Mode

### P4a — Exit bridge
- **New process:** `er_exit_bridge`
- Only process that speaks legacy TCP/IP
- Translates native cells to TCP connections (SOCKS/DNS last resort)
- Registers as handler for `IDENTITY_EXIT_BRIDGE`
- **New file:** `asm/x86_64/net/exit_bridge.asm`

### P4b — Wire `er_tor_init` to native mode
- Add native-mode path that bypasses TCP connect, TLS, VERSIONS
- Use `register_handler` + `open_circuit` instead
- Keep legacy path as fallback for exit bridge interop

### P4c — Bypass legacy Tor link handshake
- No VERSIONS negotiation
- No CERTS, AUTH_CHALLENGE, AUTHENTICATE, NETINFO
- Channel state machine becomes: `CLOSED → OPENING → OPEN`
- No TLS — encryption is per-hop in kernel relay path

### P4d — Wire relays to use identity routing
- Replace `er_tor_poll` TCP recv with kernel ring buffer recv
- Replace `er_tor_send_relay` TCP send with kernel send
- Deprecate `tor_cell.asm` TCP-layer functions for non-bridge paths

---

## Phase 5: Full System

### P5a — Streams within circuits
- Streams are cells with a StreamID (seqno)
- Per-stream window control within circuit budget
- `send()` creates a stream implicitly
- **Reuses:** Stream table layout from `tor_constants.inc`

### P5b — Fixed flow control
- Circuit window: preallocated N cells
- Stream budget: preallocated sub-slots
- SENDME validates circuit integrity via rolling hash
- No dynamic allocation, no token bucket

### P5c — Proof of Work for circuit acceptance
- Optional: identity can require PoW in cell header
- Kernel verifies Equi-X + Blake2b nonce
- Higher effort = higher circuit slot priority

### P5d — Controller/monitor syscalls
- `get_info(key)` — query kernel state
- `set_event(mask)` — register for notifications
- `set_config(key, value)` — kernel parameter
- `signal(type)` — send signal

### P5e — Multi-device mesh
- Devices discover each other via beacons
- DA propagates routing table between peer devices
- User identity spans multiple devices

---

## Reuse Strategy

| Existing code | Native path fate |
|---|---|
| `tor_cell.asm` | Circuit/stream table layouts reused; TCP I/O replaced by ring buffers |
| `tor.asm` | Bootstrap flow and state machine reused; TCP transport replaced |
| `tor_ntor.asm` | Handshake protocol fully reused once scalar mult is real |
| `tor_aes.asm` | Reused as-is |
| `tor_digest.asm` | Replaced by software SHA-256 (`sha256.asm`) |
| `sha256.asm` | Reused as-is (streaming digest for relay cells) |
| `identity.asm` | Core primitive — reused as-is, extended with Ed25519 |
| `blake3.asm` | Reused as-is |
| `net/tcp.asm` | Kept for exit bridge only |
| `net/arp.asm` | Kept for exit bridge + device beacon link-layer |
| `net/ipv4.asm` | Kept for exit bridge only |
| `tpm/tpm.asm` | Device key storage and attestation — reused as-is |

## Non-Goals

These Tor features are intentionally not implemented in the native path
(per `00-os-mapping.md`):

- TLS — replaced by per-hop kernel encryption
- SOCKS — replaced by `send(id, cell)` API
- DNS — no hostnames, only identity hashes
- Consensus voting — local authoritative DA
- HSDir hash ring — local DA registration
- Descriptor encryption — no descriptors
- Certificate chains — identity is intrinsic
- Padding / cover traffic — trust model doesn't require it
- Bandwidth measurement — declared fixed budgets
- Dynamic flow control — hard preallocated budgets

## Dependencies Between Phases

```
Phase 0 (Crypto)
    ↓
Phase 1 (Kernel Primitives)
    ↓
Phase 2 (Multi-Hop)
    ↓
Phase 3 (DA + Discovery)
    ↓
Phase 4 (Migration)
    ↓
Phase 5 (Full System)
```

Phases 1 and 3 can partially overlap (routing table needed for circuit extend,
but basic `send/recv` can work with direct device-to-device links first).
