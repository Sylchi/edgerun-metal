# EdgeRun Primitive Model

This document is the working constraint for simplifying this repository. Do not
invent a Git clone, a Unix process model, a filesystem, a global login session,
or a TLS-centered security model. The system is a deterministic graph of
content-addressed objects, identities, receipts, clocks, and local admission
domains.

## Core Thesis

Everything is dumb and lives in its own world.

Each device, app, allocator, UI surface, and storage instance is its own
admission domain. It only knows its own objects, identity, slices, and receipts.
No component has global meaning. No component gets ambient authority because it
is a parent, storage layer, UI layer, transport, or device.

Authority is explicit and replayable:

```text
user -> machine -> allocator -> ui -> app -> storage
```

Delegation proves lineage back to the source authority. It does not mean the
delegate has the source key in immediate possession.

## Existing Primitives

The current core modules already map to the intended primitive set:

- `edgerun-clock`: deterministic epoch coordinates for replay and local
  admission. This replaces wall-clock session thinking.
- `edgerun-identity`: stable user, device, app, storage, and delegated
  identities. Delegated identity is lineage proof, not broad possession.
- `edgerun-object`: canonical content-addressed objects, owners, envelopes,
  child refs, requirements, and receipt-shaped objects.
- `edgerun-storage`: append-only accepted-object log, log root, recovery by
  replay, and rebuildable projections.
- `edgerun-crypto`: hashing foundation used by object, identity, and storage.

UI is not a root authority. UI emits narrow intent receipts over objects it was
delegated to show. A launcher UI can display object slots and emit "user clicked
object number 1" without knowing what that object means. Another app can map
that object to a launch or transition.

## Objects, Not Files

Nothing is a file in the core model. Everything that matters is a
content-addressed object.

Labels, paths, refs, indexes, and projections are conveniences. They are not
truth. If a string lookup exists, it is a rebuildable projection over accepted
object history.

Core invariant:

```text
If it matters, it is an object.
If it grants authority, it is a receipt object.
If it changes state, it is a deterministic transition object or receipt.
If it is lookup convenience, it is a projection and can be discarded.
```

## Slices And Ownership

Apps do not receive broad capabilities. They own explicit preallocated memory
and storage slices.

A parent may request that part of its slice be transferred to a child, but the
actual split/transfer goes through the allocator admission domain. After the
transition is accepted, the child owns that slice. The parent cannot read it
unless the child explicitly shares it back to that identity.

Memory and storage follow the same shape:

```text
slice id
backing kind
offset
length
owner identity
requirements
epoch
```

Sharing is separate from ownership. No share receipt, no access.

The allocator records range ownership transitions. It does not need to read app
memory or understand app data.

## App Authoring, Preview, Release, And Sharing

EdgeRun apps must be able to create other EdgeRun apps. This is not a separate
developer toolchain bolted onto the side of the runtime. Authoring, preview,
release, sharing, and execution are one object-and-receipt workflow.

The WASM interpreter exists for that workflow. It lets a parent app run a draft
child app inside the parent while the child is still being built. In preview
mode, the parent may see the draft app memory and execution state because that
visibility is the developer experience: inspect, debug, replay, edit, and
render the same app the author is creating.

Preview mode is not the release security boundary.

Release mode promotes the draft into a real app object and manifest. The child
receives memory and storage from allocator-owned slices, not from ambient parent
access. The actual slice movement goes through the allocator admission domain.
After release/admission, the parent gets handles, object ids, and receipts. The
parent does not keep direct memory visibility unless the child explicitly shares
a view back with a receipt.

The intended lifecycle is:

```text
draft app object
parent-visible interpreter preview
release build object and manifest
allocator admission for memory/storage slices
installed child app with handles and receipts
shared executable object for another user
```

A shared executable is still just an object graph plus requirements and
receipts. A friend who receives it should be able to run the same app the
developer previewed without installing another runtime, package manager, native
helper, or dependency chain. The receiving user's allocator is the authority
that grants any memory and storage slices on that machine.

WASM code does not inherit network, storage, device, identity, or parent memory
authority merely because it executes. Those powers only arrive through explicit
EdgeRun APIs/imports backed by requirements, admission, and receipts. Authority
bubbles up to the user whenever a consequential transition needs a real grant.

This gives the system a single loop:

```text
author inside EdgeRun
preview inside EdgeRun
release inside EdgeRun
share as canonical objects
run under the recipient user's allocator
```

## Requirements Are Constraint Vectors

`er_object_requirements_t` is intentional. It captures constraints from app
developers so admission can take decisions away from app code and make state
transitions deterministic.

Requirements should stay declarative and non-authoritative:

```text
developer declares constraints
runtime/admission derives allowed transition
object records resolved constraints
storage records accepted objects and projections
```

The requirements axes make hidden costs explicit:

- durability: volatile, durable, replicated
- confidentiality: public, integrity-only, app/user/device/layered private
- portability: machine-bound, user/app/public portable
- integrity: hash-only, signed, sealed
- lifetime: transient, session, cache, retained, pinned
- visibility: private, app namespace, user namespace, public
- access cost: explicit IO, hot memory allowed

Do not replace this with hidden caching or broad permission prompts. If a
transition cannot satisfy requirements, admission should return the exact
missing requirement so UI can show the user the consequence chain before
authorization.

## Sealing

Sealing scope is conjunctive and narrow. A user key alone must not unlock all
data on stolen storage.

Typical private app/user data should be sealed to:

```text
device identity + app identity + user identity + object scope + manifest hash
```

Sync is explicit re-sealing, not key sharing:

```text
source device unseals under source scope after user intent
source app re-seals for destination device/app/user scope
destination verifies receipts and imports sealed objects
```

Storage may store sealed bytes, but storage should not decrypt unless storage is
itself the intended data owner.

## Boundary Crossing

Transport is dumb. Boundary crossing is not IO; it is an object-state
transition.

No object should cross an app or device boundary unless it is:

- explicitly public,
- integrity-only and safe to reveal, or
- sealed for the recipient scope.

This must be built into app/object emission. Apps should not "remember to
encrypt before send"; they should be unable to emit invalid outbound state.

TLS is not the trust root. The object and receipt chain carry confidentiality,
integrity, identity, and replay proof. A middleman may relay, delay, copy, or
drop objects, but must not be able to decrypt or forge valid boundary content.

## Runtime Authorization UX

There is no global login that authorizes everything. The system asks for user
intent only when a consequential transition needs it.

Admission should produce a deterministic preview of the chain before user
authorization:

```text
read these sealed objects
allocate this destination slice
re-seal these objects for destination scope
emit these boundary objects
record these receipts
```

The user grants the specific transition, not broad storage/network/app access.

## What To Remove Or Consolidate

When simplifying, remove extra nouns and old-world vocabulary before touching
the core primitives.

Good removal/consolidation targets:

- Host/syscall/import-table vocabulary in `include/er_wasm_contract.h`.
- Driver/PCI/MMIO/bus ABI vocabulary in `include/er_driver_abi.h`, unless it is
  quarantined as a specific app-level hardware object protocol.
- Storage concepts that compete with object truth: public content type names,
  index definitions as authority, raw blob APIs as first-class app surface.
- Path/file/VFS language in core APIs. Historical VFS was useful only as
  object packet/ref transport, not as a filesystem model.
- Broad permission concepts. Replace them with missing requirement reports and
  specific transition receipts.

Things not to remove:

- `er_object_requirements_t` as a constraint vector.
- Deterministic clock stamps.
- Stable identity and delegation lineage.
- Append-only storage log and replay.
- Canonical object verification.
- Caller-owned arenas and fixed capacities.

## Design Test

Before adding or preserving a concept, ask:

1. Is this an object, identity, receipt, clock coordinate, slice, seal scope,
   projection, or local admission rule?
2. Does it introduce ambient authority?
3. Does it hide cost behind caching, sessions, global state, or transport trust?
4. Can the transition be replayed and independently verified?
5. Can a dumb component validate its part without knowing global meaning?

If the answer does not fit this model, consolidate it or remove it.
