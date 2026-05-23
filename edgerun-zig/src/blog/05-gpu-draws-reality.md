# GPU: The Machine That Draws Your Reality

The screen does not show truth.

It shows pixels drawn by software.

The CPU can decide what should happen. The GPU is specialized for drawing and accelerating visual work. Every button, line of text, chart, icon, video frame, and animation becomes pixels.

## UI is a boundary

Normal websites often put text and UI into the DOM, where JavaScript and browser tools can inspect it.

A graphics pipeline can render directly to a canvas or WebGL surface. That does not magically make everything secure, but it changes what page scripts own and inspect.

## Main lesson

What you see is not the app. It is the app's claim drawn as pixels.

## Edgerun seed

If sensitive state never becomes DOM text or JavaScript-owned data, malicious page code has less to steal. JavaScript can host a canvas without owning the secrets behind it.
