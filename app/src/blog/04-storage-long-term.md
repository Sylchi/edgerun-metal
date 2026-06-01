# Storage: Your Device's Long-Term Memory

Storage is where bytes survive.

Files, photos, app databases, caches, downloads, keys, logs, and settings all sit somewhere on storage. On modern phones and laptops, that usually means flash storage.

But storage is not the same as ownership.

The device may hold a copy of your data while someone else controls the account that makes the copy useful. A music file may sit on disk but be unreadable without a license check. A chat database may contain messages but depend on a server to accept the session. A note may look local while sync policy decides which version wins. A photo may be deleted from the gallery while thumbnails, backups, indexes, or remote copies remain.

> Mental model: storage keeps bytes; ownership depends on who can read, change, move, and verify them.

## What storage does not answer

Storage does not answer:

- who can read the bytes
- who can change the bytes
- who can move the bytes
- who can delete the bytes
- whether cloud sync has another copy
- whether an app database is the real source of truth

Deleting something may remove a reference before every physical trace is gone. Cloud apps may show local data while treating a server database as the authority.

## Bytes need rules

Raw bytes are not enough. A durable system needs to answer:

[[demo:storage_sealed_objects]]

- what is this object?
- who created it?
- who can verify it?
- who can open it?
- who can replace it?
- what does deletion mean?
- what survives export?

Without those answers, storage becomes a pile of files and private databases. The user can back up the pile but may not be able to understand it, prove it, move it, or recover it without the original app and service.

## Local does not automatically mean owned

Local storage is a necessary foundation, not a complete solution. If the bytes are plaintext, theft of the device may expose them. If the bytes are encrypted only by a cloud account, the service remains the root. If the data format is private, the user has a backup but not independence. If the app can rewrite history without a verifiable object boundary, storage becomes mutable memory with a longer lifetime.

Useful storage needs structure: canonical object bytes, verification, encryption, explicit authority, and formats that do not require trusting a remote database to explain what the user has.

It also needs restraint. A running app does not need raw storage for every
operation. Most work should live in RAM until the user or runtime explicitly
decides it should survive. Without that boundary, an app can waste flash writes,
fill queues, make caches durable by accident, or turn a failed attempt into
state that later code treats as real.

## Main lesson

Storage is not ownership. Storage is just where bytes sit. Ownership depends on who can read them, verify them, change them, delete them, and move them without asking the original service for permission.

## EdgeRun seed

EdgeRun storage should be sealed objects. If someone steals the disk, they get encrypted blobs without the authority to open them. If the user exports the store, they should get verifiable objects, not an app-shaped heap of unexplained files.

EdgeRun apps therefore write to memory first. The durable object store is reached
through explicit flush authority, not through POSIX files or direct block I/O.
The app can work quickly in RAM, and the kernel decides what dirty objects are
allowed to become durable.
