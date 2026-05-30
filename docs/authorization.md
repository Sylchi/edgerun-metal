# EdgeRun Authorization & Resource Model

## Principals

Every actor in the system has a 32-byte BLAKE3 identity bound to a TPM seed:

| Identity kind | TPM-backed | Scope | Example |
|---|---|---|---|
| DEVICE | Yes, hardware seed | Global (hidden service) | `edgerun.device.<hash>` |
| USER | Yes, via auth secret | Global (hidden service) | `edgerun.user.<hash>` |
| APP | Yes, via manifest hash + measurement | Local | `edgerun.app.<blake3(binary + policy)>` |
| EPHEMERAL | No, per-boot random | Local only | Input sources, guest sessions |

## App Manifest

Every app carries a manifest embedded in the WASM module (custom section). Manifest fields:

```
app_name:      string          // human-readable
app_binary:    bytes           // BLAKE3 hash of the wasm at build
version:       u32
author:        identity        // developer identity (optional)
requires: {
  user_identity:  bool         // needs USER auth for some operations
  min_ram_pages:  u32          // minimum WASM pages (64KB each)
  min_storage_mb: u32          // minimum persistent storage quota
  network:        enum(off, exits_only, hidden_service)
  display:        bool
  input:          bool
  clock:          bool
}
```

## User Grant — Signed Receipt

When the user launches an app, the kernel shows an auth prompt via the DA (modal dialog). The prompt displays:

- App name + version + author identity
- Each required resource with a slider (default = minimum, user can increase)
- A "Review Later" button that rejects the grant but lets the app run with zero extra authority (app sees no user identity, no storage, etc.)

If the user signs (e.g., TPM auth press), the kernel issues a **Grant Receipt**:

```
struct Grant {
  app_identity:   [32]byte    // BLAKE3 of app
  user_identity:  [32]byte    // BLAKE3 of authorizing user
  device_identity: [32]byte   // TPM device identity
  resources: {
    ram_pages:    u32
    storage_mb:   u32
    flags:        bitmask      // user_identity, network, display, input, clock
  }
  signature:      [64]byte    // Ed25519 from USER identity (once implemented)
  // Pre-signature: TPM-quoted hash of the above fields
  tpm_quote:      [64]byte    // TPM PCR quote attesting the grant was created on this device
}
```

The grant is stored in the device's grant registry (kernel BSS, persisted to storage). The kernel checks it before allocating resources or mediating auth-sensitive operations.

If the user revokes, the receipt is removed and the app's resources are reclaimed on next tick boundary.

## Resource Reservation

### RAM
- WASM pages (64KB each) are pre-allocated from a kernel-managed page pool
- The pool enforces `total_granted ≤ total_physical - kernel_reserve`
- On launch: `er_memory_reserve(app_identity, pages)` returns a region or REJECT
- On exit: `er_memory_release(app_identity)` frees the region
- On revocation: grace period of N ticks, then forced reclamation

### Storage
- Each app gets an identity-keyed encrypted block device partition
- `APP identity hash → TPM → storage_key = TPM_Seal(APP_hash || user_grant)`
- The storage layer never sees plaintext — it stores encrypted objects indexed by app identity
- `min_storage_mb` reserves space; the user slider can increase it
- Storage is encrypted at rest with a key derived from the app identity + user grant signature
- The TPM mediates key release: it only unseals `storage_key` for the specific APP identity AND only if a valid user grant exists

## Encryption Hierarchy

```
DEVICE key (TPM hardware seed)
  └─ decrypts device storage superblock
      └─ contains USER key slots
          └─ each USER has:
              ├─ user_storage_key — for user-level documents
              └─ app_grant_authority — what this user authorized
                  └─ per APP:
                      ├─ app_storage_key = TPM_Seal(APP_hash, user_grant, device_key)
                      └─ app_memory_region
```

Key properties:
- **TPM mediates all key release** — no principal derives another's key without TPM policy check
- **Revocation is immediate**: removing the grant from the registry prevents TPM from unsealing the app key on next access
- **Device compromise doesn't expose app data**: app storage key requires both TPM unseal AND valid grant
- **User compromise doesn't expose other users**: each USER has independent key slots
- **Guest users**: EPHEMERAL identity, no TPM-backed storage key — guest data is session-scoped and wiped on reboot

### Object Portability & Confidentiality (Not Single Binding)

The object system (`object_constants.inc`) separates **portability** (who can move/copy the object) from **confidentiality** (who can decrypt it). These combine per-object via the Requirements struct:

**Portability** (`OBJECT_PORTABILITY_*`):
| Value | Name | Meaning |
|---|---|---|
| 1 | `MACHINE_BOUND` | Cannot leave this device |
| 2 | `USER_PORTABLE` | Moves with USER identity |
| 3 | `APP_PORTABLE` | Moves with APP identity (binary hash) |
| 4 | `PUBLIC_PORTABLE` | Anyone can copy |

**Confidentiality** (`OBJECT_CONFIDENTIALITY_*`):
| Value | Name | Who Can Decrypt |
|---|---|---|
| 1 | `PUBLIC` | Anyone |
| 2 | `INTEGRITY_ONLY` | No encryption, tamper detection only |
| 3 | `APP_PRIVATE` | Only the app |
| 4 | `USER_PRIVATE` | Only the user |
| 5 | `USER_APP_PRIVATE` | Both user AND app must authorize |
| 6 | `DEVICE_PRIVATE` | Only this device (TPM-bound) |
| 7 | `LAYERED` | Multiple envelopes, each to a different principal |

These combine freely. Example: an object can be `USER_APP_PRIVATE` confidentiality (requires both identities to decrypt) with `APP_PORTABLE` portability (app identity travels with the binary hash), enabling the app to route data to itself on another device where the user has authorized it.

- `DEVICE_PRIVATE` + `MACHINE_BOUND` = truly device-locked. Lost TPM = lost data. No recovery, no escrow. This is the honest behavior — "bound to device" means bound.
- `USER_APP_PRIVATE` + `USER_PORTABLE` = data follows the user's authorized app across devices.
- `PUBLIC` + `PUBLIC_PORTABLE` = unencrypted, freely movable.

The system provides export/import tooling that re-encrypts objects under the destination device's key hierarchy. Changing portability or confidentiality on an existing object is permitted if the caller has the necessary authority (owner keys).

## Auth Prompt Protocol (Cell-based)

When an app requests an authority that requires user consent:

```
1. App sends DA_MSG_AUTH_REQUEST (cell) to DA
   payload: [type][request_id:4][app_hash:32][auth_kind:1][description:variable]

2. DA shows modal dialog:
   - Which app (name from manifest cache, or hash)
   - What is requested (auth_kind + description)
   - [Accept] [Review Later] [Deny] buttons

3. Input agent forwards keystrokes to DA (da_focused_hash = DA hash while dialog active)

4. DA sends DA_MSG_AUTH_RESPONSE to app's ring:
   payload: [type][request_id:4][response:1(0=deny,1=accept,2=review_later)]

5. If accepted and involves resource grant, kernel creates Grant receipt,
   allocates resources, stores in grant registry.
```

The dialog surface is a DA-owned MODAL-layer surface (like the shell surfaces). It intercepts focus from all app surfaces while visible. On user response, the dialog is destroyed and focus returns to the previously focused app.

## Multi-User / Guest Sessions

### Lock Screen (No Info Leakage)

Boot presents a lock screen with exactly three buttons — always visible, always identical:

```
[ Log In ]  [ Create Account ]  [ Guest ]
```

The lock screen reveals nothing about the device owner or registered users. No usernames, no hints, no count of accounts. The three options look the same on every boot regardless of how many users exist. If a username doesn't exist or a password is wrong, the user is told *after* they try, not before.

### No Global Login Session

Most apps do not require user identity and run fine without it. User authentication is per-app, not per-session:

- A guest user can launch any app that doesn't require user identity
- When an app requests user identity (via grant prompt), the user authenticates at that point
- The authentication is bound to the app grant, not a global login state
- The system can route any I/O securely by identity regardless of user state — this enables sensors, policies, and delegation without revealing user identity

### Three Modes

| Mode | Identity | Storage Persistence | Grant Registry | Use Case |
|---|---|---|---|---|
| Guest | EPHEMERAL (per-boot) | None (wiped on reboot) | None | Default — most apps, no auth needed |
| Log In | USER (TPM-backed) | Persistent, sealed to USER | Persistent, per-USER | Recurring user, established grants |
| Create Account | New USER (TPM-seeded) | Fresh, empty | Fresh, empty | First-time user registration |

Guest is the primary operating mode. USER authentication is an opt-in capability for apps that need identity-bound storage or authority.

### Account Creation

"Create Account" registers a new USER identity on-device:
- User picks a username and passphrase (local only — no server, no phone-home)
- TPM seals a new USER identity key to the passphrase
- A fresh, empty grant registry and storage partition are created
- Username is stored in the TPM-sealed user database (not enumerable from the lock screen)

The user database is encrypted at rest with the DEVICE key. Attempting to log in with a nonexistent username produces the same error as a wrong password — the system doesn't reveal which one failed.

### App Authorization Is Per-User

- Each user has an independent grant registry
- An app that User A authorized is NOT authorized for User B
- If User B launches the same app, they get a fresh grant prompt
- Shared storage objects (e.g., a file shared between users) are encrypted with a well-known DEVICE-derived key readable by all users — an explicit operation, not ambient access

### User Switching

Switching users tears down the app surface registry and re-inits the DA. No app state survives the switch. User B cannot see User A's windows, grant history, or storage.

### Privacy by Routing

Because all I/O is identity-routed through cells:
- Sensors can be routed through policy filters without the app knowing
- Input can be inspected, transformed, or blocked at the routing layer
- Guest and authenticated users coexist in the same routing fabric
- An app never needs to know whether the current user is guest or logged in — it just receives cells or gets rejected at the routing boundary

## Event Log (Observations)

The device maintains a hashed append-only event log. Every meaningful crossing leaves a receipt — these receipts are the event log entries.

### Log Structure

Each entry is chained to the previous by hash:

```
entry[n] = [prev_hash:32][clock_stamp:16][kind:1][data:variable]
prev_hash = BLAKE3(entry[n-1])
```

- `prev_hash` chains the log — tampering with any entry breaks all subsequent hashes
- `clock_stamp` is the pipeline clock value at the time of entry (see Clock section in AGENTS.md)
- `kind` identifies the event type (grant created, resource allocated, cell routed, sensor reading recorded, etc.)
- `data` is event-type-specific payload

The log root (hash of latest entry) is periodically anchored to TPM PCRs for remote attestation.

### What Gets Logged

Every operation that crosses an authority boundary produces a log entry:

- Grant creation / revocation
- Resource allocation / release
- Sensor observations (timestamped)
- App launch / exit
- Storage writes (metadata only — not content)
- Identity routing decisions (optional, policy-gated)

Not every cell crossing is logged — only events that represent authority movement or sensor observation.

App clock stamps are not directly comparable between apps (each app adjusts its tick rate independently). For ordering proofs across apps, events reference the pipeline clock, not the per-app clock. A log entry `clock_stamp` always records the pipeline tick at the time of entry, giving a global ordering base regardless of per-app rate adjustments.

### ZK Proofs

Because every app has a clock (verifiable stamp) and the device maintains the chained event log:

- An app can prove "observation X occurred at time T on device D" by presenting the chain from the observation entry back to a TPM-anchored root
- The clock permits ordering proofs across apps: "event A happened before event B" can be verified without revealing the events themselves
- Apps can produce ZK proofs of their own observations by presenting their clock stamps alongside the relevant log chain segments
- The TPM-anchored log root provides a hardware root of trust for these proofs — a verifier can check that the chain leads to a genuine device

This enables third-party verification of device behavior without granting access to the full log: a prover reveals only the chain segment relevant to the claim being proved.
