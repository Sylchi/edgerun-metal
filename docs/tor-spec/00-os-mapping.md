# Tor Spec → OS Primitive Mapping

This document maps each Tor specification document to its equivalent
OS-level primitive in an identity-addressed capability OS where:
- Every process has a fixed identity (hash of binary)
- Every device has a persistent identity (TPM-backed keypair)
- The kernel routes cells by identity, not address
- Same-machine IPC shares memory without encryption
- Crypto is used only when crossing authority boundaries (user, device, app)

---

## 02-tor-protocol.md — Core Cell & Circuit Protocol

### Cell Format
| Tor | OS |
|---|---|
| Fixed 514B cell (CircID+Command+Body) | Fixed-size cell in kernel ring buffers |
| Variable cells (VERSIONS, CERTS, etc.) | Kernel bootstrap / channel setup |
| CircID (2 or 4 bytes) | Circuit slot index (kernel-managed table) |
| Command byte (PADDING, CREATE, RELAY, DESTROY, etc.) | Kernel cell type enum |

**Kernel primitive:** Fixed-size cell (256B or 514B) as universal message unit.
Ring buffer per (identity, identity) pair in shared memory.
Cell header: [circuit_slot:2, flags:2, type:1, payload:251].

### Channels (link protocol)
| Tor | OS |
|---|---|
| TLS session between relays | No TLS. Direct process-to-process encrypted channel |
| VERSIONS cell negotiation | Kernel auto-negotiates link version at circuit setup |
| CERTS + AUTH_CHALLENGE + AUTHENTICATE | Device-to-device key exchange (no TLS needed) |
| NETINFO (addresses, time) | Kernel fills routing metadata, no IP addresses |
| Link padding (PADDING_NEGOTIATE) | Not needed at kernel level (device layer doesn't pad) |

**Kernel primitive:** Channel = route table entry with
[next_device_id, circuit_slot_map, encryption_key, state_machine].

No TLS — encryption is built into the cell forwarding layer.

### Circuits
| Tor | OS |
|---|---|
| CREATE2/CREATED2 (ntor handshake) | Circuit establishment between identities |
| EXTEND2/EXTENDED2 | Path extension — kernel discovers next hop from routing table |
| RELAY_EARLY (8-cell hop limit) | Kernel enforces max circuit depth |
| DESTROY | Circuit teardown syscall |
| CircID management (per-connection) | Per-process circuit table (fixed size, preallocated) |

**Kernel primitive:** Circuit table per process — fixed N entries.
Each entry: [destination_id, path[5], keys[5], window_state, stream_table].

**User API:**
```
fd = open_circuit(destination_identity_hash)  // returns circuit handle
send(fd, cell[256])                           // fire-and-forget
recv(fd, cell[256])                           // non-blocking poll
close(fd)                                     // DESTROY
```

### Relay Cell Encryption (Telescoping)
| Tor | OS |
|---|---|
| Encrypt with Kf_N, ..., Kf_1 | Kernel encrypts each layer for each hop in path |
| Decrypt with Kf_1, recognize at hop | Kernel decrypts per-hop, forwards if not recognized |
| Kf/Kb (forward/backward AES keys) | Per-hop symmetric keys derived from ntor handshake |
| Df/Db (digest seeds) | Per-hop digest state for integrity |
| Relay command + StreamID | Encrypted inner envelope |

**Kernel primitive:** For each circuit, kernel maintains [N][Kf, Kb, Df, Db].
On send: encrypt N times from innermost hop outward.
On recv: decrypt once per hop, check recognize+digest, forward or deliver.

### Streams (TCP connections)
| Tor | OS |
|---|---|
| RELAY_BEGIN + RELAY_CONNECTED | Open a message channel to a destination identity |
| RELAY_DATA | Stream data frames |
| RELAY_END (reason code) | Stream close with reason |
| RELAY_RESOLVE / RELAY_RESOLVED | Not needed (no DNS) |
| RELAY_BEGIN_DIR | App registers as identity handler (replaces directory) |

**Kernel primitive:** Streams are just cells on a circuit with a StreamID.
In this OS, every `send()` creates a stream (StreamID = seqno).
The kernel provides stream-level window control.

### Flow Control
| Tor | OS |
|---|---|
| Circuit window (1000 cells, +100 per SENDME) | Kernel circuit budget (preallocated slots per circuit) |
| Stream window (500 cells, +50 per SENDME) | Per-stream budget within circuit budget |
| SENDME version 1 (authenticated digest) | Kernel validates circuit integrity via rolling hash |
| Package window / deliver window | Kernel tracks sent/received per circuit |
| Token bucket rate limiting | Preallocated budget per process identity |

**Kernel primitive:** Fixed budgets. A process declares "I support N circuits."
When N exhausted, new circuit requests are rejected.
No dynamic allocation. Flow control is a hard budget, not a window.

### Keys and Identities
| Tor | OS |
|---|---|
| KP_relayid_ed (Ed25519 identity) | Device identity (TPM-backed Ed25519) |
| KP_relayid_rsa (legacy RSA identity) | Not needed |
| KP_relaysign_ed (medium-term signing) | Device session signing key |
| KP_ntor (curve25519 onion key) | Per-circuit ephemeral key |
| KP_link_ed (link auth key) | Device-to-device session key |
| KP_hs_id (hidden service identity) | App identity = hash(binary) |
| Certificate chains (CERTS) | Not needed — identity is intrinsic, not certified |

**Kernel primitive:** Each process has an intrinsic identity
`H(binary + TPM_measurement)`. The kernel enforces identity at exec time.

### Subprotocol Versioning
| Tor | OS |
|---|---|
| Protocol negotiation via proto lines | Kernel capability bits (fixed at compile time) |
| Required/recommended lists | Not needed — single OS implementation |

### Relay Cell Routing
| Tor | OS |
|---|---|
| Recognize via zero 'recognized' field + digest | Kernel checks per-hop AES-CTR decryption |
| Forward direction (origin → exit) | Send encrypts telescopically |
| Backward direction (exit → origin) | Recv decrypts telescopically |
| Digest is SHA-1 (circuits) or SHA3-256 (HS circuits) | Kernel uses same per-circuit-type hash |

**Kernel primitive:** Encryption/decryption loop is inline in kernel send/recv paths.
No dynamic allocation. Per-circuit key schedule precomputed at circuit setup.

---

## 03-directory-protocol.md — Directory & Descriptor Protocol

| Tor | OS |
|---|---|
| Directory authority (voting, consensus) | Directory Authority process per machine |
| Router descriptor (keys, addresses, ports) | Process registration: identity + device |
| Network status / consensus | Routing table: identity → next_hop |
| Server descriptor upload (HTTP POST) | `register_handler(id)` syscall |
| Extra-info document | Not needed |
| Microdescriptor | Minimal route entry: [id, cost, next_hop, expiry] |
| HSDir hash ring | Not needed — routing is authoritative, not distributed |
| Voting protocol (authorities agree) | Single DA per machine (local consensus) |
| Flag assignment (Running, Fast, Guard, etc.) | Capability flags: [can_forward, is_exit, is_da] |
| Bandwidth measurement | Preallocated budget (declared, not measured) |
| Download scheduling (exponential backoff) | Not needed — DA is local |

**Kernel primitive:** `set_route(id, next_hop, cost, expiry)` — privileged syscall
for the DA process only.
Process registration: `register_handler(id, ring_buffer_base)` — called by
process at startup; kernel assigns an identity.

**Userspace process:** Directory Authority (DA).
One per machine. Maintains routing table for:
- All local processes (identity → shm ring)
- All known peer devices (device_id → MAC + link key)
- All known remote app identities (app_id → device_id)
- All known remote user identities (user_id → app_id → device_id)

The DA does NOT do consensus voting. It is authoritative for its machine.

---

## 04-path-spec.md — Path Selection

| Tor | OS |
|---|---|
| Circuit building (extend N-1 hops) | Kernel extends path one hop at a time via routing table |
| Cannibalizing circuits | Kernel reuses idle circuit slots |
| Path bias defense | Not needed (no guard discovery attack in this model) |
| Stream attachment to circuits | `send()` attaches to any circuit bound for destination |
| SOCKS timeout → abandon | Not needed (no SOCKS, send is fire-and-forget) |

**Kernel primitive:** Path extension is a kernel operation.
When an app sends to an identity, the kernel:
1. Looks up destination in routing table
2. If destination is local (process on same machine), routes via shm ring directly
3. If destination is on a peer device, extends circuit through that device
4. If destination is N hops away, extends circuit N hops, encrypting each layer

Path selection is deterministic — routing table says next hop.

---

## 05-guard-spec.md — Guard Node Selection

| Tor | OS |
|---|---|
| Sampled guard set (persistent) | First-hop peer devices (fixed, configured or discovered) |
| Confirmed guard set | Devices that have responded to beacons |
| Primary guard set | Active neighbor devices |
| Reachability tests (is_reachable tristate) | Device beacon timeout → mark unreachable |
| Guard filtering (Stable, Fast, V2Dir) | Device flags: [beaconing, forwarding, has_exit] |
| Guard lifetime / rotation | Device stays in neighbor table as long as it beacons |

**Kernel primitive:** Neighbor table: fixed N entries.
Each entry: [device_id, mac, last_beacon, is_reachable, flags].

Guard = first device on LAN that a machine peers with.
No guard selection algorithm — the DA learns neighbors via device beacons
and picks the most reliable as "first hop out."

**Userspace process:** Device discovery daemon (built into kernel or DA).
Handles beacon broadcasts on raw ethernet. Updates neighbor table.

---

## 06-vanguards-spec.md — Vanguard (Multi-Layer Guard)

| Tor | OS |
|---|---|
| Full vanguards (3 guard layers) | Multi-hop path through known peer devices |
| Vanguards-lite (1 guard layer) | Single-hop path through one peer device |
| Circuit stem (common prefix for HS circuits) | Kernel reuses established path prefix |
| Mesh topology (any layer-2 to any layer-3) | Any neighbor device can route to any further device |

**Kernel primitive:** Not needed. Paths are N hops through the neighbor graph.
Vanguard concept maps to "don't use an exit-capable device as the first hop" —
a routing policy bit.

Not applicable in same authority boundary.

---

## 07-padding-spec.md — Circuit Padding

| Tor | OS |
|---|---|
| Circuit padding state machines | Not needed at OS level |
| PADDING_NEGOTIATE / PADDING_NEGOTIATED | Not needed |
| Cover traffic (WTF-PAD) | Not needed — no traffic analysis in this trust model |
| Adaptive padding (APE histograms) | Not needed |

**Kernel primitive:** None. Padding is an app-layer concern, if at all.

---

## 08-dos-prevention.md — Denial of Service

| Tor | OS |
|---|---|
| MaxMemInQueues (RAM cap) | Preallocated fixed budgets → no memory exhaustion possible |
| Circuit queue trimming | Kernel drops circuits when budget exhausted |
| Token bucket rate limiting | Preallocated forwarding slots per identity |
| CPU exhaustion (circuit handshake) | Fixed max circuits per process, enforced at kernel |
| Half-open stream limits | Fixed stream table per circuit |

**Kernel primitive:** Budget enforcement is intrinsic to the fixed-allocation model.
A process cannot exceed its declared budget because:
- Circuits are preallocated slots
- Streams are preallocated sub-slots
- Memory is fixed at exec time

The DOS spec is solved by architecture, not by runtime mitigation.

---

## 09-socks-extensions.md — SOCKS Extensions

| Tor | OS |
|---|---|
| SOCKS4/SOCKS5 proxy | Not needed — `send(id)` replaces SOCKS entirely |
| RESOLVE command | Not needed — no DNS |
| RESOLVE_PTR command | Not needed |
| Optimistic data | `send()` is always fire-and-forget (always optimistic) |
| Extended error codes (F0-F7) | Kernel return codes for circuit/send failures |
| HTTP-resistance | Not needed |
| Username/password auth | Not needed |

**Kernel primitive:** None. SOCKS is replaced by the identity-based `send(id, cell)` API.

**User API** (replaces SOCKS interface):
```
open_circuit(destination_id) → fd
send(fd, data[256])           → 0 or error
recv(fd) → data[256]          → data or empty
close(fd)                     → teardown
```

---

## 10-http-connect.md — HTTP CONNECT Proxy

| Tor | OS |
|---|---|
| HTTP CONNECT proxy | Not needed |
| OPTIONS method | Not needed |
| Error code mapping | Not needed |
| Cross-site probing prevention | Not needed |

**Kernel primitive:** None. HTTP CONNECT is replaced by the native identity API.

---

## 11-address-spec.md — Special Hostnames

| Tor | OS |
|---|---|
| .exit notation (force exit node) | Not needed — routing is identity-based, not exit-based |
| .onion address format | App identity `= H(binary)`, not a hostname |
| base32(PUBKEY | CHECKSUM | VERSION) | Identity is raw 32-byte hash, not encoded address |
| ed25519 torsion check | Kernel validates public keys at registration |

**Kernel primitive:** Identity is a 32-byte hash. No hostnames, no address encoding.
The .onion encoding format is only relevant if you need to represent an identity
as a string for out-of-band exchange (scan QR code, typed by user).

---

## 12-haproxy-proxy.md — HAProxy PROXY Protocol

| Tor | OS |
|---|---|
| PROXY v1 header | Not needed |
| Circuit ID encoded as IPv6 address | Not needed |
| Onion service virtual port mapping | Not needed — apps rendezvous via identity, not port |

**Kernel primitive:** None.

---

## 13-onion-services.md — Onion Services v3

### Blinded Keys & Subcredentials
| Tor | OS |
|---|---|
| Blinded public key (time-period key) | Not needed — app identity is fixed, not time-varying |
| Subcredential derivation | Not needed |
| Time periods (TP) | Not needed — no descriptor expiration |
| Shared random values (SRV) | Not needed — no distributed consensus |

### Descriptor Upload/Download
| Tor | OS |
|---|---|
| HSDir hash ring (hsdir_n_replicas, etc.) | DA stores registration locally — no hash ring |
| Descriptor encryption (two layers) | Not needed — no descriptor to encrypt |
| Revision counter | Process registration TTL (refresh every N minutes) |
| Introduction point list | Not needed — DA routes to process directly |

### Introduction & Rendezvous Protocol
| Tor | OS |
|---|---|
| ESTABLISH_INTRO / INTRO_ESTABLISHED | `register_handler(id)` — process declares it accepts messages |
| INTRODUCE1 / INTRODUCE2 | `send(id, cell)` — routed by kernel |
| ESTABLISH_RENDEZVOUS / RENDEZVOUS_ESTABLISHED | Not needed — no rendezvous point |
| RENDEZVOUS1 / RENDEZVOUS2 | Not needed |
| INTRODUCE_ACK | Not needed — send is fire-and-forget |

### Key Management
| Tor | OS |
|---|---|
| KP_hs_id (Ed25519 master identity) | App identity = hash(binary) |
| KP_hs_desc_sign (descriptor signing) | Not needed — no descriptor |
| KP_hs_blind_id (blinded signing) | Not needed |
| KP_hs_intro_auth (introduction auth) | Not needed |
| KP_hss_ntor (intro encryption key) | Per-destination session key (derived via handshake) |
| N_hs_subcred (subcredential) | Not needed |
| N_hs_cred (credential) | Not needed |

**Kernel primitive:** `register_handler(id)` = "I accept cells for this identity."
The DA stores the mapping: identity → ring buffer.
When a cell arrives for this identity, kernel copies it to the handler's ring buffer.

In this OS, every app is a "hidden service" and every app is a "client."
There is no distinction. `register_handler` is the service side.
`open_circuit(id)` is the client side. Both are first-class kernel primitives.

**Userspace process:** The on-machine routing aspect of HSDirs is handled by the DA.

### Proof of Work (PoW)
| Tor | OS |
|---|---|
| Equi-X + Blake2b puzzle | Optional: app can request PoW from sender |
| Introduction priority queue | Kernel circuit slot priority (higher effort = higher slot) |
| Seed / suggested effort | Consensus parameter → kernel parameter |
| Replay protection (seed, nonce) | Kernel nonce cache per receiver |

**Kernel primitive:** Optional — kernel can require a PoW nonce in cell header
for circuits to a particular identity. The identity sets the required effort.

---

## 14-proof-of-work.md — PoW for Onion Services

Same as 13-onion-services PoW section above.
Additional detail:

| Tor | OS |
|---|---|
| v1 solver (Equi-X) | Kernel PoW verification for slot allocation |
| Effort adjustment | DA publishes required effort per identity |
| Queue draining (highest effort first) | Kernel circuit accept priority |

---

## 15-ext-orport.md — Extended ORPort

| Tor | OS |
|---|---|
| Extended ORPort for pluggable transports | Not needed |
| SAFE_COOKIE auth (cookie file) | Not needed |
| Client address/port passthrough | Not needed — no IP addresses |

**Kernel primitive:** None.

---

## 16-pluggable-transport.md — Pluggable Transports

| Tor | OS |
|---|---|
| PT client (SOCKS proxy) | Not needed |
| PT server (reverse proxy) | Exit bridge process (translates identity→IP) |
| TOR_PT_* environment variables | Not needed — no subprocess transport model |
| Managed subprocess protocol | Not needed |

**Userspace process:** Exit bridge. Only process that speaks legacy IP.
Receives cells destined for IP hosts, opens TCP connections, bridges data.
This is the *only* place where SOCKS/DNS/IP addresses exist.

**Kernel primitive:** The exit bridge registers as a handler for
`IDENTITY_EXIT_BRIDGE`. All IP-bound traffic is addressed to this identity.
The kernel routes it there like any other identity.

---

## 17-control-protocol.md — Controller Protocol

| Tor | OS |
|---|---|
| SETCONF / GETCONF | Kernel config syscall (fixed set of parameters) |
| SETEVENTS | Event registration syscall (circuit_up, cell_recv, etc.) |
| AUTHENTICATE (cookie/password) | Capability-based — no passwords needed |
| MAPADDRESS | Route table manipulation (DA-only) |
| GETINFO (status queries) | Kernel info syscall (process stats, circuit stats) |
| SIGNAL (NEWNYM, SHUTDOWN, etc.) | Kernel signal syscall |
| Circuit status / stream status | Kernel circuit table introspection |
| Onion service commands (HSFETCH, etc.) | Route registration / lookup |

**Kernel primitive:** The control protocol is replaced by kernel syscalls:
- `get_info(key)` — query kernel state
- `set_event(mask)` — register for notifications
- `set_config(key, value)` — set kernel parameter
- `signal(type)` — send signal to process or kernel

The control protocol spec is a reference for what query/control surfaces
an OS should expose to privileged processes (like a system monitor, debugger,
or DA admin tool).

---

## 18-version-spec.md — Version Numbering

| Tor | OS |
|---|---|
| MAJOR.MINOR.MICRO.PATCHLEVEL | OS version (single implementation, no negotiation) |
| Status tags (alpha, rc, -dev) | Build type |
| Recommended versions list | Not needed |

**Kernel primitive:** None.

---

## 19-bandwidth-file.md — Bandwidth File Format

| Tor | OS |
|---|---|
| Bandwidth file (V3BandwidthsFile) | Not needed |
| Measured bandwidth values | Budget is declared, not measured |
| Header line / relay line format | Not needed |

**Kernel primitive:** None. Budget is a parameter of process creation,
not a measured quantity.

---

## 20-dir-list.md — Directory List Format

| Tor | OS |
|---|---|
| Fallback directory list (hardcoded C array) | Initial bootstrap — hardcoded peer device identities |
| FallbackDir entries (IP:port, fingerprint) | Device ID + MAC address |

**Kernel primitive:** Hardcoded bootstrap identities in the kernel image
for first-boot peer discovery. After boot, DA manages discovered peers.

---

## 21-parameters.md — Network Parameters

| Tor | OS kernel parameter |
|---|---|
| circwindow (1000 cells) | `kernel.circuit.window_size` |
| usecreatefast (CREATE_FAST on 1st hop) | Not needed (always ntor-v3 equivalent) |
| sendme_emit_min_version | `kernel.sendme.version` |
| sendme_accept_min_version | `kernel.sendme.accept_version` |
| CircuitPriorityHalflifeMsec | `kernel.scheduler.priority_halflife` |
| KISTSchedRunInterval | `kernel.scheduler.run_interval` |
| bwweightscale | Not needed |
| hsdir_n_replicas | Not needed |
| min_paths_for_circs_pct | Not needed |

The parameters file is a reference for tuning knobs.
Most are irrelevant in the fixed-budget model.
Relevant ones map to kernel `/sys`-style parameters.

---

## 22-ssh-protocols.md — SSH Protocol Extensions

| Tor | OS |
|---|---|
| Ed25519 key format in OpenSSH files | Reference for key serialization format |
| x25519 key format in OpenSSH files | Reference for key serialization format |
| PROTOCOL.key encoding | Reference for private key storage |

**Kernel primitive:** Not directly. Key encoding reference for userspace tools.

---

## 29-cert-spec.md — Certificate Formats

| Tor | OS |
|---|---|
| Tor Ed25519 Certificate (VERSION, CERT_TYPE, etc.) | Not needed |
| RSA→Ed25519 cross-certificate | Not needed |
| Certificate type 04 (IDENTITY_V_SIGNING) | Not needed — no certificate chains |
| Certificate type 05 (SIGNING_V_TLS) | Not needed |
| Expiration date (hours since epoch) | Not needed |
| ExtFlags / ExtType extensions | Not needed |

**Kernel primitive:** None. Identity is intrinsic (hash of binary + TPM),
not certified through chains. No TLS, no X.509.

The cert format is only relevant for legacy Tor interoperability
(exit bridge speaking to real Tor network).

---

## Summary: What the OS Actually Implements

### Kernel Primitives (fixed allocations, no dynamic memory)

| Primitive | Syscall / Interface | Preallocation |
|---|---|---|
| Open circuit | `open_circuit(dest_id) → fd` | Per-process circuit table (N entries) |
| Send cell | `send(fd, cell[256])` | Slot in circuit window |
| Receive cell | `recv(fd) → cell[256]` | Ring buffer per identity |
| Close circuit | `close(fd)` | Frees circuit slot |
| Register identity | `register_handler(id, ring_base)` | One identity per process (fixed) |
| Encrypt data | `encrypt(data, key_slot) → ciphertext` | Per-hop key schedule (fixed) |
| Decrypt data | `decrypt(data, key_slot) → plaintext` | Per-hop key schedule (fixed) |
| Get message | `get_message() → cell[256]` | Ring buffer slot |

### Userspace Processes

| Role | What it does | Identity |
|---|---|---|
| Directory Authority | Route table management, peer discovery | Fixed (DA binary hash) |
| Exit bridge | Legacy IP interop | Fixed (bridge binary hash) |
| App | User-facing process | Fixed (its own binary hash) |
| Device discovery | Beacon broadcasts, neighbor table | Part of kernel or DA |

### What Tor Concepts Don't Map

These Tor features are solved by architectural decisions rather than protocols:

- **TLS** → Replaced by per-hop encryption at kernel level
- **SOCKS** → Replaced by `send(id, cell)` API
- **DNS** → No hostnames, only identity hashes
- **Consensus voting** → Replaced by local authoritative DA
- **HSDir hash ring** → Replaced by local DA registration
- **Descriptor encryption** → No descriptors to encrypt
- **Certificate chains** → Identity is intrinsic, not certified
- **Padding / cover traffic** → Out of scope (trust model doesn't require it)
- **Bandwidth measurement** → Replaced by declared fixed budgets
- **Flow control windows** → Replaced by hard preallocated budgets
