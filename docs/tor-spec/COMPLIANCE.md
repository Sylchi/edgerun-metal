# Tor Spec Compliance

Source specs are copied from `~/tor-spec` into this directory. The implementation must be audited against these files, not against memory or comments.

## Current implementation state

| Spec area | Source | Repo support | Required next work |
| --- | --- | --- | --- |
| Cell framing, VERSIONS, CERTS, AUTH_CHALLENGE, NETINFO | `02-tor-protocol.md` | Partial. Link v4/v5 negotiation, CERTS/AUTH_CHALLENGE structural validation, CERTS duplicate type rejection, NETINFO body validation, NETINFO send/receive, and handshake VPADDING skipping are implemented in `kernel/x86_64/crypto/tor_cell.asm`. | Authenticate responder certificate chain and identity against configured guard material; implement AUTHENTICATE when acting as public relay. |
| CREATE2/CREATED2 ntor | `02-tor-protocol.md` | Partial. CREATE2 ntor client path and strict CREATED2 parsing are implemented. | Add ntor-v3 CREATE2/CREATED2 and extension parsing. Add DESTROY handling on circuit-create failure. |
| EXTEND2/EXTENDED2 | `02-tor-protocol.md` | Partial. IPv4 plus legacy identity EXTEND2 client body and EXTENDED2 ntor reply parsing are implemented. | Add Ed25519 link specifiers, IPv6 link specifiers, duplicate/invalid link-spec rejection, and relay-side EXTEND2 handling if relay role is enabled. |
| Relay cells and streams | `02-tor-protocol.md` | Partial. BEGIN, BEGIN_DIR, DATA, END, CONNECTED, SENDME recognition exist. | Complete stream close accounting, SENDME window enforcement, RESOLVE/RESOLVED, DESTROY/TRUNCATE/TRUNCATED, DROP padding behavior. |
| Directory protocol | `03-directory-protocol.md` | Partial. Consensus first-guard parsing and descriptor ntor-key extraction exist. | Full consensus validation, microdescriptor support, signatures, freshness, guard sampling inputs. |
| Path and guard selection | `04-path-spec.md`, `05-guard-spec.md` | Minimal. Explicit guard material can be configured and bootstrapping fails closed without it. | Full sampled guard set, primary/confirmed guard state, persistence, retry logic, path constraints, family/exclusion rules. |
| Onion services v3 | `13-onion-services.md` | Partial. Address encoding, descriptor crypto helpers, intro/rendezvous message builders/parsers, and local self-connect paths exist. | Complete descriptor validation, HSDir selection, upload/fetch policy, PoW/extensions, client auth, replay caches, revision counters. |
| Padding and DoS behavior | `07-padding-spec.md`, `08-dos-prevention.md` | Minimal. Link handshake VPADDING is accepted. | Padding negotiation, circuit padding machines, DoS defenses, overload behavior. |
| Control/SOCKS/ext OR/proxy surfaces | `09-socks-extensions.md`, `15-ext-orport.md`, `17-control-protocol.md` | Not implemented as host Tor control surfaces. | Decide whether these are in scope for kernel Tor support or explicitly out of scope for EdgeRun identity routing. |
| Role model and app SDK authority | `02-tor-protocol.md`, `04-path-spec.md`, `05-guard-spec.md`, `13-onion-services.md` | Partial. `TOR_ROLE_*` and `TOR_CAP_*` cover Tor-compatible client, guard, relay, exit, directory, bridge, and onion-service roles. Bootstrap preserves an explicitly configured role instead of forcing client-only. Local identity routing sends unknown valid identities through the kernel public relay path by default. | Kernel public relay and domain authority operation, app-owned onion-service/guard/relay/exit roles, and SDK role grants must be backed by process-owned identity, route authority, TPM-backed key material where available, and deterministic relay-side tests. |

## EdgeRun Tor Role Model

The kernel public Tor relay is the default IPC path for nonlocal identities, and the kernel owns the domain authority. Local delivery wins when an identity is registered in the local route table; otherwise a valid destination identity is forwarded through the kernel relay path. Relay identity, relay signing keys, ORPort behavior, directory behavior, domain authority state, and advertised capabilities are kernel-owned authority and must only activate when the required explicit material is present.

The app SDK exposes Tor-compatible roles to WASM apps, including hidden service, guard, middle relay, exit, directory, bridge, introduction, rendezvous, and combined peer roles. If an app wants to expose a service, it operates a Tor hidden service through the SDK. These roles are process-owned capabilities, not ambient filesystem or socket permissions. Role activation maps to `TOR_CAP_*` and must be authorized through grants and receipts before an app can route traffic as that role.

There must be one Tor-compatible protocol path, not parallel EdgeRun-specific protocol variants. All roles use the same routing path: Tor-compatible cells are carried through EdgeRun identity routing and local circuits. Tor is the privacy and compatibility envelope for legacy IP and app-to-app privacy paths; it is not a POSIX process model inside EdgeRun.

WASM apps do not receive sockets, host networking calls, or filesystem authority. Security boundaries that Tor traditionally represents with local process configuration, files, sockets, or controller ports must be represented by absence of those capabilities plus explicit EdgeRun grants.

Apps manage their own Tor-compatible routing only within granted resources and must use the device relay for nonlocal communication. The kernel does not emulate sockets, DNS, filesystem paths, password databases, or ambient auth for apps. Content protection belongs to sealed data and object requirements: app content is sealed by the app, user data is sealed for the user, device data is sealed for the device, and each object carries the requirements needed to move, decrypt, verify, or flush it.

Generic bootstrap must not overwrite explicit role state. Missing guard, relay, directory, onion-service, or exit material fails closed instead of falling back to client-only behavior or pretending a filesystem-backed configuration exists.

## EdgeRun Storage And Path Boundary

Tor specs describe several POSIX-oriented surfaces: torrc paths, DataDirectory state, cached directory files, control-port path fields, pluggable-transport executable paths, filesystem sockets, and local descriptor/certificate caches. EdgeRun does not expose a host filesystem to Tor code and must not fake one.

Required mapping:

| Tor filesystem expectation | EdgeRun implementation rule |
| --- | --- |
| torrc / command-line path configuration | Kernel-owned constants, grants, and identity-route configuration. No string path is treated as ambient authority. |
| DataDirectory, cached consensus, cached descriptors, guard state | Kernel-owned in-memory state first. Durable state is an explicit flush into the append-only object store, sealed to device/user/app authority as described in `docs/authorization.md`. |
| Authority certificates and relay certificates | Parsed from directory protocol objects or configured authority material, then verified with TPM-backed hash/signature primitives where available. No certificate trust is loaded from a path. |
| Relay identity, guard identity, onion keys | Process-owned/kernel-owned identity material. Bootstrap fails closed without explicit guard material. Persistent identity release should be TPM-mediated whenever hardware support exists. |
| Pluggable transport program paths and filesystem control sockets | Not implemented as filesystem paths. If required, these must become explicit identity-routed components with grants and receipts. |
| Hidden-service keys/descriptors | Generated and signed through TPM-backed or TPM-sealed identity keys wherever possible. Published/fetched as Tor directory objects over BEGIN_DIR, not read from files. |

Implementation rule: a Tor spec requirement that names a file, directory, executable path, socket path, or cache path must be implemented as an explicit EdgeRun authority path before it can be marked supported. If there is no EdgeRun authority mapping, the feature is unsupported and must fail closed.

Certificate/key rule: Tor certificate validation and signing should use TPM-mediated hashing, signing, verification, sealing, and key release whenever the current TPM layer supports the needed primitive. Software parsing is acceptable; trust decisions and persistent private-key access should not depend on unsealed RAM alone when TPM support exists.

## Rule

Do not describe Tor support as complete until every required item above is implemented with deterministic tests or explicitly ruled out by architecture with a spec-backed replacement.
