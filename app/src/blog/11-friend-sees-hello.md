# Your Friend Sees Hello

At the end, your friend sees hello. The simple moment hides everything that happened before it: input stacks, app dependencies, routers, resolvers, certificates, servers, databases, push systems, and rendering.

The point is not that every layer is evil. The point is that every layer is a trust boundary, and most users never got to choose which boundaries mattered.

The message felt simple because the complexity was hidden. That is the bargain most modern software offers: an easy surface in exchange for remote authority, opaque dependencies, platform wake paths, server databases, account policy, and rented infrastructure.

> Mental model: a simple hello is a chain of authority decisions wearing a friendly UI.

## The conventional path

```text
keypress -> app SDKs -> router -> ISP
ISP -> DNS -> TLS -> server
server -> database -> push -> friend device
```

Every hop may be doing a reasonable job in isolation. The keyboard reports input. The app builds a message. The router forwards packets. DNS finds a name. TLS protects the connection. The server coordinates delivery. The database remembers. Push wakes the other phone. The renderer shows hello.

The problem is the whole shape. The user's identity, data, memory, and ability to communicate often end up depending on systems the user does not control.

## A local-first path

```text
keypress -> local draft -> explicit send intent
send intent -> signed event -> sealed object
sealed object -> route or relay -> friend device
friend device -> verify -> local render
```

This path still uses networks. It may still use relays. It may still need abuse limits and accounting. But authority moves closer to the people communicating. The message is not real because a server row says so. It is real because the sending device signed an explicit event and the receiving device can verify it.

## What changed

- the app does not need to upload drafts
- dependencies do not get ambient authority
- the server can relay without owning plaintext
- storage can be verifiable object history
- push and relay paths can be minimized
- the receiving device can verify before rendering
- the user can export meaningful state

The goal is not nostalgia for offline computing. The goal is to use the network without letting the network become the user.

## Interactive model

[[demo:post_model]]

## Main lesson

Modern internet use feels simple because complexity, trust, compute, identity, and cost were moved somewhere else.

## EdgeRun seed

The rebuild starts when the user's device can run the app, hold the identity, store the object, explain the event log, and route to another user without turning every action into rented infrastructure. The friend seeing hello should be the end of a verifiable local chain, not proof that someone else's database allowed the conversation to exist.
