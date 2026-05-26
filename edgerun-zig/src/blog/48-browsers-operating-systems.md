# The Web Won Interoperability, Then Dragged An Operating System Into Every Tab

The browser became the universal app runtime, then became too complex to replace.

Browsers now contain rendering engines, JavaScript engines, WASM, WebGL, extension APIs, sandboxing, local storage, service workers, DRM, media stacks, permission systems, and fingerprinting defenses.

That power is why the web won. You can open a link on almost any machine. But every victory became another subsystem inside the browser.

> Mental model: the browser solved reach by becoming an operating system inside the operating system.

## Browser stack

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

## Why this matters

For normal users, "a website" now might mean:

```text
download code -> execute app
store local database -> talk to many servers
use GPU -> ask for camera
register worker -> run after tab closes
fingerprint device -> show protected media
```

That is not a document anymore. It is an app runtime with a network connection.

Browsers deserve credit for sandboxing hostile code at enormous scale. They also show the cost of letting one runtime become the compatibility layer for everything.

## The trap for new systems

It is tempting to say: use the browser for all apps. But then the new system inherits the old system's weight: JavaScript supply chains, bundlers, ad tech habits, tracking defaults, permission confusion, browser quirks, and a massive trusted codebase.

A small runtime should learn from the web's interoperability without copying its accidental operating system.

## Interactive model

[[demo:post_model]]

Browser runtime stack: load a simple app and expand the layers required to render, execute, store, sync, notify, and protect it.

## Main lesson

The web solved cross-device reach, but the cost was moving an operating system worth of complexity into every tab.

## EdgeRun seed

WASM is powerful, but EdgeRun should keep the runtime small, inspectable, capability-scoped, and not dependent on JavaScript as the app architecture.
