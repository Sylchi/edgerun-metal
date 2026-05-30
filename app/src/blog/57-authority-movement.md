# Authority Is Not A Vibe. It Is A Receipt Chain.

The hard part is not deciding that apps should be sandboxed.

> Mental model: every boundary crossing must name the actor, the subject, the authority, and the receipt.

The hard part is keeping track of the proof once the system gets real.

An app wants to send a message. Another app wants to read a small memory view. A storage app wants to persist bytes. A TPM app wants to seal or unseal something. A child app wants resources. A UI app wants state.

If any one of those paths becomes "just call the other thing," the model collapses.

The system has to treat every crossing as a transaction.

## The rule

No principal gets authority over another principal.

Not the user.

Not the device.

Not the parent app.

Not the storage app.

Not the relay.

Not the TPM app.

They all have roles. None of them gets to silently become another role.

That sounds severe until you write down what actually happens when data moves.

## Moving through the system

[[demo:authority_flow]]

The picture is simple:

- an app owns its memory
- a child gets only an allocated slice
- storage receives encrypted objects
- relay forwards encrypted messages
- TPM seals only for policy-bound callers
- allocator approves resource movement
- every crossing leaves a receipt

The relay cannot read the message.

The storage app cannot decrypt app-private state.

The parent cannot inspect child memory.

The allocator cannot pretend to be the reader.

The reader cannot invent a shared memory grant.

Each participant can verify the step it is responsible for, but cannot take over the other participants.

## Main lesson

The system is not built around trust.

It is built around refusal.

Refuse raw bytes where a canonical object is expected.

Refuse a route without relay transit.

Refuse a memory share without owner bytes, reader identity, allocator approval, and receipt id.

Refuse a TPM role unless the identity is TPM-backed.

Refuse storage decrypt unless caller and policy match.

Refuse child spawn unless the host performs it and the allocation is available.

That is why the implementation feels dense. It is not one permission check. It is a graph of small checks that prevent any principal from quietly stretching past its boundary.

## What apps actually exchange

Apps do not exchange trust.

They exchange objects.

A message is an encrypted object plus a route plus a relay receipt.

A memory view is owner memory plus allocator approval plus reader identity plus a read-only receipt.

A storage write is a canonical object whose envelope says who can open it.

A TPM operation is a policy-bound event whose caller was admitted first.

A spawn is a host-created child plus a resource receipt.

That is the whole shape:

```text
actor -> request -> authority -> receipt -> object
```

The caller can ask.

The authority can approve one exact crossing.

The receipt records what happened.

The object carries only the bytes that are meant to move.

## Why this matters

Most systems start with broad ambient authority.

The app can see too much. The parent can inspect too much. The OS can read everything. The storage layer stores plaintext. The server becomes the judge. The account becomes identity. The platform becomes owner.

Then everyone adds patches.

Permissions. Sandboxes. Consent prompts. Containers. Policy engines. Audit logs. Secret managers. Compliance dashboards.

EdgeRun starts from the other side.

The app starts with nothing except allocated memory, explicit handles, and its own identity.

When it wants something else, the request has to cross a named boundary.

That crossing is where the proof lives.

## EdgeRun seed

This is the seed of the architecture:

- memory is owned before it is used
- storage stores encrypted canonical objects
- identity is routed, not guessed
- relays forward without reading
- TPM authority is explicit and policy-bound
- app-private data can remain private even from the user
- user authority grants space, not automatic access to developer secrets
- the device manages resources without becoming the owner of app data
- every meaningful crossing can be verified later

If that feels like a lot, it is because the old systems made the same decisions silently.

The goal is not to make computing complicated.

The goal is to stop hiding where authority moved.
