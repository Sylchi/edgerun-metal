# The Web Won Interoperability, Then Dragged An Operating System Into Every Tab

The browser became the universal app runtime, then became too complex to replace.

Browsers now contain rendering engines, JavaScript engines, WASM, WebGL, extension APIs, sandboxing, local storage, service workers, DRM, media stacks, permission systems, and fingerprinting defenses.

## Browser Stack

- HTML and CSS
- JavaScript
- WASM
- WebGL
- WebRTC
- storage
- service workers
- extensions
- DRM
- sandboxing

## Interactive Demo

Browser runtime stack: load a simple app and expand the layers required to render, execute, store, sync, notify, and protect it.

## Main Lesson

The web solved cross-device reach, but the cost was moving an operating system worth of complexity into every tab.

## EdgeRun Seed

WASM is powerful, but EdgeRun should keep the runtime small, inspectable, capability-scoped, and not dependent on JavaScript as the app architecture.
