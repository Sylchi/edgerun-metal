# RAM: The Desk, Not the Filing Cabinet

RAM is the desk where work happens.

Storage is the filing cabinet where things survive after power loss.

RAM is fast but temporary. Storage is slower but persistent. Apps need RAM to run. If an app gets too much RAM or leaks memory, the device slows down or crashes.

RAM is where the living version of a program exists. The file on disk may contain the app. The database may contain saved records. But when the app is running, the active state is in memory: the current document, the current cursor position, the decoded image, the temporary network response, the decrypted secret, the undo stack, the open handles, and the buffers waiting to be written.

> Mental model: memory is temporary authority to exist while work is happening.

That boundary is deliberate. Apps should not turn every temporary thought into
disk traffic. Scratch data, caches, previews, failed edits, and decoded media
belong in memory until the app crosses an explicit commit or flush boundary.
Memory is what running programs use for work; storage is what the system uses
when work is meant to survive.

## Why this matters

When an app is alive, its working state lives in RAM:

- text you are editing
- images being processed
- network responses
- UI state
- temporary buffers
- decrypted data

When the app closes, that memory should be released.

That sounds simple, but it is one of the most important ownership boundaries on a device. If one app can read another app's memory, sandboxing has failed. If a secret stays in memory after it is no longer needed, later code may find it. If a child task can allocate forever, it can starve the parent. If memory lifetime is unclear, "delete" may only mean "stop showing it."

## Memory is authority

Memory is not just capacity. It is authority to exist at runtime. A parent that gives a subapp 4 megabytes is not only giving it space; it is limiting how much temporary state the subapp can hold, how much work it can queue, and how much damage a leak can cause.

The same idea applies to secret material. A private key, decrypted note, or local AI prompt might only need to exist for one operation. Keeping it around because it is convenient turns temporary authority into ambient authority.

## Failure modes

- leak: memory is never returned
- overread: code reads bytes outside its allocation
- use after free: code keeps using memory after ownership ended
- shared buffer confusion: two owners believe they control the same bytes
- secret residue: sensitive bytes remain after the operation ended

These are not abstract computer science problems. They are ways that apps crash, slow down, expose data, or make local decisions impossible to audit.

## Interactive model

[[demo:post_model]]

## Main lesson

RAM is where a program lives while it is alive. Controlling memory means controlling what can exist, what can be touched, and when temporary authority ends.

## EdgeRun seed

EdgeRun apps receive memory from a parent runtime. Subapps can only use what the parent gave them. When an app closes, its memory can disappear cleanly, and sensitive work can be scoped to the operation that actually needed it.

EdgeRun app storage follows the same rule: app writes first land in an in-memory
object store. Only an explicit flush asks the kernel to commit selected dirty
objects to durable storage. This prevents ordinary app activity from burning I/O
or accidentally making temporary state permanent.
