# EdgeRun Identity Routing Roadmap

## Vision

Replace the current legacy Tor-over-TCP client with a native identity-addressed
capability OS where every process, device, and user has a fixed identity and the
kernel routes cells by identity — not by IP address.

The full mapping from Tor semantics to OS primitives is specified in
`~/tor-spec/00-os-mapping.md`.

---

## Current State

The host-side implementation lives under `kernel/x86_64/`. The Tor code
(`kernel/x86_64/crypto/tor*.asm`, `kernel/x86_64/net/`) still contains the
legacy Tor-over-TCP path, but identity-addressed local cells, route registration,
handler dispatch, and per-process circuit helpers now exist in
`kernel/x86_64/crypto/local_cell.asm`, `local_route.asm`, and
`local_circuit.asm`. The remaining work is to make those primitives the default
network path instead of a tested side path.

| Module | State | Reusable For Native Path |
|--------|-------|--------------------------|
| `local_cell.asm` / `local_route.asm` / `local_circuit.asm` | Working, tested | Native identity transport primitives |
| `tor_cell.asm` — cell I/O, circuits, streams over TCP | Working 1-hop | Cell format, circuit table layout, relay cell processing |
| `tor.asm` — client orchestrator, init, poll | Working 1-hop plus local route binding | Bootstrap flow reference and bridge path |
| `tor_ntor.asm` — ntor handshake | Working client side; Curve25519 coverage exists through `test-x25519` | Key derivation and handshake protocol |
| `tor_aes.asm` — AES-128-CTR | Working | Reusable as-is |
| `tor_digest.asm` — SHA-256/HMAC via TPM | Working | Replace with software SHA-256 once verified |
| `sha256.asm` — software SHA-256 | Working (bug fixed) | Replaces TPM path for digest |
| `identity.asm` — BLAKE3 identity module | Working | Core primitive for native path |
| `preimage.asm` — domain-separated hashing | Working | Reusable as-is |
| `blake3.asm` — full BLAKE3 | Working | Reusable as-is |
| `net/tcp.asm` — TCP stack | Working | Deprecated — only needed for exit bridge |

---

## Phase 0: Critical Crypto Gaps

These are the cryptographic primitives that gate full native encrypted circuits.
Curve25519 arithmetic is implemented and covered; Ed25519 remains open.

| Primitive | File | Current | Coverage |
|-----------|------|---------|----------|
| `_fe_invert` | `kernel/x86_64/crypto/curve25519.asm` | Implemented | `./build.sh test-fe-mul`, `./build.sh test-x25519` |
| `_curve25519_ladder_step` | `kernel/x86_64/crypto/curve25519.asm` | Implemented | `./build.sh test-x25519` |
| `er_tor_curve25519_scalar_mult` | `kernel/x86_64/crypto/curve25519.asm` | Implemented | `./build.sh test-x25519` |

These form the basis of ntor handshake support for both legacy and native paths.

### P0d — Ed25519 signing/verification
- **File:** Does not exist yet (constants in `identity.asm`)
- **Work:** Implement Ed25519 for device identity attestation
- **Needed for:** TPM-backed device identity, beacon signatures
- **Optional for:** legacy Tor CERTS cell (exit bridge path)

---

## Phase 1: Kernel Identity Routing Primitives

The in-kernel local transport exists and is covered by `./build.sh test-local-route`.
The remaining work is syscall/exec integration and full production policy wiring.

### P1a — `register_handler` syscall
- `register_handler(identity[32], ring_buffer_base, ring_buffer_size)`
- Local route registration and handler dispatch exist in
  `kernel/x86_64/crypto/local_route.asm`
- Kernel-created process ring ownership and syscall exposure remain future work
- One identity per process still needs exec/syscall enforcement
- **Replaces:** `tor_cell.asm`'s circuit listen path
- **Current file:** `kernel/x86_64/crypto/local_route.asm`

### P1b — `open_circuit` syscall
- `open_circuit(destination_identity[32]) → circuit_fd`
- Local circuit open/close/send/recv helpers exist in
  `kernel/x86_64/crypto/local_circuit.asm`
- Syscall exposure and process table ownership remain future work
- **Replaces:** `er_tor_circuit_create` TCP-based circuit
- **Current file:** `kernel/x86_64/crypto/local_circuit.asm`

### P1c — `send` / `recv` cell syscalls
- `send(circuit_fd, cell[LOCAL_CELL_SIZE])` — fire-and-forget
- `recv(circuit_fd) → cell[LOCAL_CELL_SIZE]` — non-blocking poll
- Local cell send/recv and WASM import wrappers exist; per-hop encryption remains
  future multi-hop work
- **Replaces:** `er_tor_send_relay`, `er_tor_recv_relay` over TCP
- **Extends:** `kernel/x86_64/crypto/local_cell.asm` and `local_circuit.asm`

### P1d — Per-process circuit table
- Fixed-size table (preallocated at process exec)
- Entry: `[destination_id, path[5], keys[5], window_state, stream_table]`
- Local fixed-size circuit table exists; process exec ownership is not complete
- **Reuses:** Circuit table layout from `tor_constants.inc`
- **Current file:** `kernel/x86_64/crypto/local_circuit.asm`

### P1e — Local cell command enum
- Current commands are `LOCAL_CELL_DATA`, `LOCAL_CELL_OPEN`, and
  `LOCAL_CELL_CLOSE` in `kernel/x86_64/crypto/local_constants.inc`
- Tor fixed-cell shaped local cells exist as the current universal transport
  shape: `[circ_id:4][cmd:1][payload:509]`, `LOCAL_CELL_SIZE = 514`
- **Current file:** `kernel/x86_64/crypto/local_constants.inc`

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
- **Extends:** `kernel/x86_64/crypto/local_circuit.asm`

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
- Boilerplate process in `kernel/x86_64/agent/da.asm`

### P3b — Device beacon protocol
- Raw ethernet broadcast on LAN
- Beacon payload: `[device_id[32], timestamp, nonce, signature]`
- Neighbor table: fixed N entries per device
- Device discovery daemon (built into kernel or DA)
- **New file:** `kernel/x86_64/net/beacon.asm`
- **New MAC:** Use NIC MAC as link-layer address

### P3c — Routing table
- Three-level map: `app_id → device_id`, `device_id → MAC + link_key`, `user_id → device_id`
- Fixed-size, preallocated
- DA updates via `set_route` syscall
- **New file:** `kernel/x86_64/net/route_table.asm`

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
- **New file:** `kernel/x86_64/net/exit_bridge.asm`

### P4b — Wire `er_tor_init` to native mode
- Add native-mode path that bypasses TCP connect, TLS, VERSIONS
- Use `register_handler` + `open_circuit` instead
- Keep legacy path only as the explicit exit bridge interop path

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

---

## Phase 6: EdgeRun Object Store

Convert all disk storage to content-addressed canonical EdgeRun Objects. Replace
the POSIX filesystem with a kernel-owned object store. Apps have zero direct disk
access — they operate on in-RAM object stores carved from their parent's arena at
spawn, and must call `er_flush()` to commit dirty objects to the append-log WAL
on the block device.

This is intentional, not a temporary shortcut. App working state belongs in RAM:
scratch buffers, caches, decoded assets, partial edits, transient network
responses, undo stacks, and failed attempts should not hit storage unless a
caller crosses an explicit flush boundary. Memory is what running programs are
for. Storage is slower, durable, and shared with the rest of the machine, so an
app must not be able to burn flash, flood I/O queues, or manufacture durable
state just by mutating its heap.

### P6a — Storage Justification in Manifest

- **File:** `app/src/app.zig:398-447`
- **Current:** `DeclaredAllocation` has `storage_bytes`/`storage_slots` but no
  explanation requirement
- **Work:** Add `storage_justification: [64]u8` field. `hasStorage()` returns
  true only when justification is non-empty. Include in allocation body encoding
  and hash. The grant permits explicit flush capacity, not direct disk access.
- **Enforces:** No app gets persistent storage or durable flush authority without
  declaring why

### P6b — NVMe Read/Write Block Commands

- **File:** `kernel/driver/nvme.asm`
- **Current:** `er_nvme_read_blocks` and `er_nvme_write_blocks` build IO queue
  1 read/write SQEs, ring the SQ1 tail doorbell at BAR0 + 0x1008, poll
  `NVME_IO_CQ`, and are covered by `./build.sh test-nvme`.
- **Work:** Validate the IO path against real hardware and connect it to the
  store flush path with explicit error propagation for controller status codes.
- **Dependencies:** P6b hardware validation
- **Forms basis of:** Block I/O backend for PersistentStore

### P6c — Kernel Block Device Abstraction

- **New file:** `kernel/x86_64/storage/block_io.asm`
- **Work:** Unified `BlockIo` struct with function pointers: `read(slot, lba, buf, count)`,
  `write(slot, lba, buf, count)`, `sync(slot)`. Backed by NVMe or SDHCI at
  boot-time selection.
- **Replaces:** Raw driver calls in kernel main
- **Dependencies:** P6b (NVMe), existing SDHCI read/write

### P6d — PersistentStore in Kernel ASM

- **New files:** `kernel/x86_64/storage/persistent_store.asm`,
  `kernel/x86_64/storage/persistent_store_constants.inc`
- **Current:** `app/src/store.zig` has a complete `PersistentStore` with WAL append-log,
  blob index, key index, prefix scan, replay, and superblock — but only in Zig/test
- **Work:** Port the WAL append-log + index + replay to kernel ASM. On-disk format
  unchanged (compatible with Zig version).
- **Dependencies:** P6c (block device abstraction)
- **Key functions:**
  - `er_persistent_store_open(io, config, blobs, keys) → store`
  - `er_persistent_store_put_object(canonical) → hash`
  - `er_persistent_store_get_object(hash, out) → view`
  - `er_persistent_store_index_put(index_id, key, hash)`
  - `er_persistent_store_index_scan(index_id, prefix, out) → count`
  - `er_persistent_store_sync()`
  - `er_persistent_store_replay()`

### P6e — Kernel Object Runtime (WASM Imports)

- **New files:** `kernel/x86_64/wasm/wasm_object_api.asm`,
  `kernel/x86_64/storage/object_runtime.asm`
- **Work:** WASM import functions that replace POSIX I/O:
  - `er_object_get(hash, out) → body pointer` — reads from app's RAM Store
  - `er_object_put(canonical) → hash` — writes to app's RAM Store
  - `er_flush()` — copies dirty RAM Store objects to PersistentStore WAL
  - `er_index_scan(index_id, prefix, out) → count` — prefix scan over index
  - `er_object_resolve(tree_hash, path) → child hash` — VFS path walk
- **Dependencies:** P6a, P6d
- **Enforces:** No app ever touches a block device. POSIX open/read/write does
  not exist in the WASM import namespace. Unflushed app objects remain volatile
  RAM state and are reclaimed with the app's memory slice.

### P6f — Boot-Time Store Load

- **File:** `kernel/x86_64/kernel_main.asm`
- **Work:** After NVMe/SDHCI probe, call `er_persistent_store_open` + `replay`
  on the object store partition. Read root tree hash from superblock. The root
  tree's children form the top-level VFS namespace. Any app spawned gets its
  storage carved from the kernel's RAM cache of loaded objects.
- **Dependencies:** P6d, P6e

### P6g — Host Conversion Tool

- **New file:** `kernel/host/obj_convert.asm`
- **Work:** Linux userspace tool that walks a filesystem tree, wraps every file
  as `OBJECT_KIND_BYTES`, every directory as `OBJECT_KIND_TREE`, and writes them
  into a PersistentStore partition. Also builds the index: each file is indexed
  by its path label for instant `indexScanPrefix()` lookup.
- **Dependencies:** P6d (on-disk format)
- **Enables:** `./obj_convert /mnt/old_disk /dev/nvme0n1p1` → instant migration

### P6h — Object Store Index Cache

- **New file:** `kernel/x86_64/storage/index_cache.asm`
- **Work:** On boot, load PersistentStore index slots into a fixed RAM array.
  Enables O(n) prefix scan within microseconds for datasets up to ~1M entries.
  For larger datasets, a hash-table index on disk with RAM cache of hot pages.
- **Dependencies:** P6d, P6f
- **Enables:** "search within moments" across all objects on disk

---

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
