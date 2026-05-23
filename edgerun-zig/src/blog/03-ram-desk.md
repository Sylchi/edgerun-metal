# RAM: The Desk, Not the Filing Cabinet

RAM is the desk where work happens.

Storage is the filing cabinet where things survive after power loss.

RAM is fast but temporary. Storage is slower but persistent. Apps need RAM to run. If an app gets too much RAM or leaks memory, the device slows down or crashes.

## Why this matters

When an app is alive, its working state lives in RAM:

- text you are editing
- images being processed
- network responses
- UI state
- temporary buffers
- decrypted data

When the app closes, that memory should be released.

## Main lesson

RAM is where a program lives while it is alive. Storage is where its remains are kept after it closes.

## Edgerun seed

Edgerun apps receive memory from a parent runtime. Subapps can only use what the parent gave them. When an app closes, its memory can disappear cleanly.
