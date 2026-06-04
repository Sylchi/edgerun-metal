# Tor Spec → OS Primitive Mapping

This document maps each Tor specification document to its equivalent
OS-level primitive in an identity-addressed capability OS where:
- Every process has a fixed identity (hash of binary)
- Every device has a persistent identity (TPM-backed keypair)
- The kernel routes fixed cells by identity, not address
- WASM apps own their Tor role behavior inside their own binary
- The system relays cells between identities and enforces grants
- Crypto is used when crossing authority boundaries (user, device, app)

---

## 02-tor-protocol.md — Core Cell & Circuit Protocol

### Cell Format
| Tor | OS |
|---|---|
| Fixed 514B cell (CircID+Command+Body) | Fixed-size cell in kernel ring buffers |
| Variable cells (VERSIONS, CERTS, etc.) | Kernel bootstrap / channel setup |
| CircID (2 or 4 bytes) | Circuit slot index (kernel-managed table) |
| Command byte (PADDING, CREATE, RELAY, DESTROY, etc.) | Kernel cell type enum |

**Kernel primitive:** the 514-byte Tor fixed cell is the universal message unit.
Each identity has a grant-backed incoming mailbox. The host may validate the
outer destination and mailbox capacity, but app role state and inner Tor
protocol behavior remain inside the WASM binary.

### Channels (link protocol)
| Tor | OS |
|---|---|
| TLS session between relays | No TLS. Direct process-to-process encrypted channel |
| VERSIONS cell negotiation | Kernel auto-negotiates link version at circuit setup |
| CERTS + AUTH_CHALLENGE + AUTHENTICATE | Device-to-device key exchange (no TLS needed) |
| NETINFO (addresses, time) | Kernel fills routing metadata, no IP addresses |
| Link padding (PADDING_NEGOTIATE) | Not needed at kernel level (device layer doesn't pad) |

**System primitive:** channel = route table entry plus receipt state. Local
delivery writes the destination mailbox. Nonlocal delivery hands the same fixed
cell to the device relay. The app, not the host SDK, owns any Tor link or role
state needed inside the cell stream.

### Circuits
| Tor | OS |
|---|---|
| CREATE2/CREATED2 (ntor handshake) | Circuit establishment between identities |
| EXTEND2/EXTENDED2 | Path extension — kernel discovers next hop from routing table |
| RELAY_EARLY (8-cell hop limit) | Kernel enforces max circuit depth |
| DESTROY | Circuit teardown syscall |
| CircID management (per-connection) | Per-process circuit table (fixed size, preallocated) |

**App primitive:** circuit state is WASM-owned data backed by explicit memory
and key grants. The system stores only the route and mailbox state required to
deliver fixed cells.

**User API:**
```
register_identity(identity_hash, grant_receipt)
send_cell(destination_identity_hash, cell[514])
recv_cell(cell[514])
```

### Relay Cell Encryption (Telescoping)
| Tor | OS |
|---|---|
| Encrypt with Kf_N, ..., Kf_1 | Kernel encrypts each layer for each hop in path |
| Decrypt with Kf_1, recognize at hop | Kernel decrypts per-hop, forwards if not recognized |
| Kf/Kb (forward/backward AES keys) | Per-hop symmetric keys derived from ntor handshake |
| Df/Db (digest seeds) | Per-hop digest state for integrity |
| Relay command + StreamID | Encrypted inner envelope |

**App primitive:** for each circuit, the WASM role implementation maintains the
Tor key schedule and digest state it is granted to hold. The system does not add
a separate app-facing role controller.

### Streams (TCP connections)
| Tor | OS |
|---|---|
| RELAY_BEGIN + RELAY_CONNECTED | Open a message channel to a destination identity |
| RELAY_DATA | Stream data frames |
| RELAY_END (reason code) | Stream close with reason |
| RELAY_RESOLVE / RELAY_RESOLVED | Not needed (no DNS) |
| RELAY_BEGIN_DIR | App registers as identity handler (replaces directory) |

**App primitive:** streams are Tor cells interpreted by the WASM binary. The
system provides bounded mailbox capacity, not socket emulation or stream-level
host authority.

### Flow Control
| Tor | OS |
|---|---|
| Circuit window (1000 cells, +100 per SENDME) | app-owned flow-control state plus granted mailbox budget |
| Stream window (500 cells, +50 per SENDME) | Per-stream budget within circuit budget |
| SENDME version 1 (authenticated digest) | Kernel validates circuit integrity via rolling hash |
| Package window / deliver window | Kernel tracks sent/received per circuit |
| Token bucket rate limiting | Preallocated budget per process identity |

**System primitive:** fixed mailbox and grant budgets. A process receives only
the cell slots, memory, durable flush capacity, identity access, and key
material granted to it. Tor flow-control state stays in app-owned WASM memory.

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
| Recognize via zero 'recognized' field + digest | app-owned Tor role checks inner relay cells |
| Forward direction (origin → exit) | app-owned role encrypts telescopically |
| Backward direction (exit → origin) | app-owned role decrypts telescopically |
| Digest is SHA-1 (circuits) or SHA3-256 (HS circuits) | app-owned role tracks the digest state |

**App primitive:** relay-cell encryption is part of the WASM role binary. The
system only moves already-formed fixed cells between identities.

---

## 03-directory-protocol.md — Directory & Descriptor Protocol

| Tor | OS |
|---|---|
| Directory authority (voting, consensus) | Directory Authority process per machine |
| Router descriptor (keys, addresses, ports) | Process registration: identity + device |
| Network status / consensus | Routing table: identity → next_hop |
| Server descriptor upload (HTTP POST) | app-owned directory behavior over fixed cells |
| Extra-info document | Not needed |
| Microdescriptor | Minimal route entry: [id, cost, next_hop, expiry] |
| HSDir hash ring | Not needed — routing is authoritative, not distributed |
| Voting protocol (authorities agree) | Single DA per machine (local consensus) |
| Flag assignment (Running, Fast, Guard, etc.) | Capability flags: [can_forward, is_exit, is_da] |
| Bandwidth measurement | Preallocated budget (declared, not measured) |
| Download scheduling (exponential backoff) | Not needed — DA is local |

**System primitive:** identity route registration plus grant receipts. A local
authority component may maintain route entries for local and known remote
identities, but app directory behavior remains a WASM role over the same fixed
cell transport.

---

## 04-path-spec.md — Path Selection

| Tor | OS |
|---|---|
| Circuit building (extend N-1 hops) | app-owned role emits the needed fixed cells |
| Cannibalizing circuits | app-owned circuit cache inside granted memory |
| Path bias defense | Not needed (no guard discovery attack in this model) |
| Stream attachment to circuits | app-owned stream-to-circuit policy |
| SOCKS timeout → abandon | Not needed (no SOCKS, send is fire-and-forget) |

**App primitive:** path selection and extension are Tor role behavior inside
the WASM binary. When an app sends a fixed cell, the system looks up only the
outer destination identity, writes a local mailbox when local delivery is
available, or forwards the cell to the device relay when nonlocal delivery is
required.

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
| Circuit stem (common prefix for HS circuits) | app-owned role may reuse a path prefix |
| Mesh topology (any layer-2 to any layer-3) | Any neighbor device can route to any further device |

**System primitive:** not needed for apps. Paths are app-owned Tor role data.
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
| Circuit queue trimming | app cannot exceed granted mailbox and memory budget |
| Token bucket rate limiting | Preallocated forwarding slots per identity |
| CPU exhaustion (circuit handshake) | app-owned work is bounded by granted runtime budget |
| Half-open stream limits | app-owned stream state is bounded by granted memory |

**System primitive:** budget enforcement is intrinsic to the fixed-allocation model.
A process cannot exceed its grant because mailbox cells, runtime memory, durable
flush capacity, and identity/key access are fixed before the app runs.

The DOS spec is solved by architecture, not by runtime mitigation.

---

## 09-socks-extensions.md — SOCKS Extensions

| Tor | OS |
|---|---|
| SOCKS4/SOCKS5 proxy | Not needed — `send_cell(id, cell)` replaces SOCKS entirely |
| RESOLVE command | Not needed — no DNS |
| RESOLVE_PTR command | Not needed |
| Optimistic data | `send_cell()` is always fire-and-forget at the relay layer |
| Extended error codes (F0-F7) | fixed SDK return codes for cell delivery failures |
| HTTP-resistance | Not needed |
| Username/password auth | Not needed |

**System primitive:** None. SOCKS is replaced by the identity-based
`send_cell(id, cell[514])` API.

**User API** (replaces SOCKS interface):
```
register_identity(identity_id, grant_receipt) -> slot
send_cell(destination_id, cell[514])          -> 0 or error
recv_cell(cell[514])                          -> data or empty
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
| ESTABLISH_INTRO / INTRO_ESTABLISHED | app-owned behavior over `register_identity(id, grant)` |
| INTRODUCE1 / INTRODUCE2 | app-owned behavior over `send_cell(id, cell)` |
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

**System primitive:** `register_identity(id, grant)` binds a granted app identity
to its incoming mailbox. When a cell arrives for that identity, the system
copies the fixed cell to the mailbox. Hidden-service and client distinctions are
WASM role behavior layered on the same fixed-cell transport.

**Userspace process:** The on-machine routing aspect of HSDirs is handled by the DA.

### Proof of Work (PoW)
| Tor | OS |
|---|---|
| Equi-X + Blake2b puzzle | Optional: app can request PoW from sender |
| Introduction priority queue | app-owned queue inside granted memory |
| Seed / suggested effort | app-owned consensus or local policy data |
| Replay protection (seed, nonce) | app-owned cache inside granted memory |

**App primitive:** optional. The receiving app can require PoW material inside
its app-level Tor messages and reject cells that do not satisfy its policy.

---

## 14-proof-of-work.md — PoW for Onion Services

Same as 13-onion-services PoW section above.
Additional detail:

| Tor | OS |
|---|---|
| v1 solver (Equi-X) | app-owned PoW verification inside granted memory |
| Effort adjustment | app-owned policy data |
| Queue draining (highest effort first) | app-owned queue policy |

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

**System primitive:** the exit bridge registers a granted identity. All
IP-bound traffic is addressed to that identity and relayed like any other fixed
cell destination.

---

## Tor Control Protocol — Controller Protocol

| Tor | OS |
|---|---|
| SETCONF / GETCONF | Kernel config syscall (fixed set of parameters) |
| SETEVENTS | Event registration syscall (circuit_up, cell_recv, etc.) |
| AUTHENTICATE (cookie/password) | Capability-based — no passwords needed |
| MAPADDRESS | Route table manipulation (DA-only) |
| GETINFO (status queries) | Kernel info syscall (process stats, circuit stats) |
| SIGNAL (NEWNYM, SHUTDOWN, etc.) | Kernel signal syscall |
| Circuit status / stream status | app-owned state; privileged monitors may inspect route/mailbox status |
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

## Tor Bandwidth File Format

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

### System Primitives (fixed allocations, no dynamic memory)

| Primitive | Syscall / Interface | Preallocation |
|---|---|---|
| Register identity | `register_identity(id, grant_receipt) -> slot` | Granted identity mailbox |
| Send cell | `send_cell(dest_id, cell[514])` | Granted outgoing cell budget |
| Receive cell | `recv_cell(cell[514])` | Granted incoming mailbox slots |
| Emit receipt | `receipt(edge, input, output)` | Granted object/flush capacity |
| Relay nonlocal cell | device relay path | Device relay budget |

### Userspace Processes

| Role | What it does | Identity |
|---|---|---|
| Route authority | Route table management, peer discovery | Fixed binary hash |
| Device relay | Nonlocal fixed-cell forwarding | Fixed binary hash |
| App | App-owned Tor role and data transform | Fixed binary hash |
| Device discovery | Beacon broadcasts, neighbor table | Part of kernel or DA |

### What Tor Concepts Don't Map

These Tor features are solved by architectural decisions rather than protocols:

- **TLS** → App-owned Tor roles handle link/relay encryption where needed
- **SOCKS** → Replaced by `send_cell(id, cell[514])`
- **DNS** → No hostnames, only identity hashes
- **Consensus voting** → Replaced by local authoritative DA
- **HSDir hash ring** → Replaced by local DA registration
- **Descriptor encryption** → No descriptors to encrypt
- **Certificate chains** → Identity is intrinsic, not certified
- **Padding / cover traffic** → Out of scope (trust model doesn't require it)
- **Bandwidth measurement** → Replaced by declared fixed budgets
- **Flow control windows** → Replaced by hard preallocated budgets
