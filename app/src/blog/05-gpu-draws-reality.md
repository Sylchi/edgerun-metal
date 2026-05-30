# GPU: The Machine That Draws Your Reality

The screen does not show truth.

It shows pixels drawn by software.

The CPU can decide what should happen. The GPU is specialized for drawing and accelerating visual work. Every button, line of text, chart, icon, video frame, and animation becomes pixels.

That makes the display powerful and dangerous. A screen can show a real account balance, a cached number, a spoofed prompt, a fake permission dialog, or an animation that makes the user believe work happened when nothing durable changed.

> Mental model: the interface is a rendered claim about state, not the state itself.

## UI is a boundary

Normal websites often put text and UI into the DOM, where JavaScript and browser tools can inspect it.

A graphics pipeline can render directly to a canvas or WebGL surface. That does not magically make everything secure, but it changes what page scripts own and inspect.

The rendering path is part of the trust model. If the page owns the text, the page can read the text. If the page owns the input fields, the page can inspect what the user typed. If the page owns the control tree, the page can rewrite prompts at the worst possible time.

## The pixel pipeline

A rough UI path looks like this:

- app state decides what should exist
- layout places boxes, text, and controls
- rendering turns those decisions into draw commands
- the GPU turns draw commands into pixels
- the display scans those pixels to glass

At each step, software can lose information, misrepresent information, or expose information to a layer that did not need it.

## Why screenshots are not enough

A screenshot proves that pixels appeared. It does not prove which authority produced them. It does not prove whether a button was backed by a real operation, whether a value came from signed state, or whether another layer could read the secret before it was drawn.

For ordinary web pages, that is usually acceptable. For identity, payments, recovery, sealed storage, or local AI prompts, the question gets sharper: who owns the UI state before it becomes pixels?

## Tiny trace

```text
object state -> trusted layout -> draw commands
draw commands -> GPU -> pixels
pixels -> user decision
```

## Interactive model

[[demo:post_model]]

## Main lesson

What you see is not the app. It is the app's claim drawn as pixels, and the authority behind that claim matters.

## EdgeRun seed

If sensitive state never becomes DOM text or JavaScript-owned data, malicious page code has less to steal. JavaScript can host a canvas without owning the secrets behind it. The browser can present the surface, while the trusted runtime owns the state, layout decisions, and authority checks.
