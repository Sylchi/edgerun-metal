# Your Friend Sees Hello

At the end, your friend sees hello. The simple moment hides everything that happened before it: input stacks, app dependencies, routers, resolvers, certificates, servers, databases, push systems, and rendering.

The point is not that every layer is evil. The point is that every layer is a trust boundary, and most users never got to choose which boundaries mattered.

## Purpose

Put the whole season together. Compare the current rented-screen path with a local-first path where identity, data, and execution stay closer to the people using the app.

## Visual idea

Current path: device -> app SDKs -> router -> ISP -> DNS -> TLS -> server -> database -> push -> friend.

EdgeRun path: signed event -> local object -> identity route -> sealed transfer -> friend device -> native app surface.

## Interactive demo

A full path comparison lets the reader toggle between the conventional internet path and the EdgeRun path. Each hop lights up with the trust, metadata, compute, and ownership involved.

## Main lesson

Modern internet use feels simple because complexity, trust, compute, identity, and cost were moved somewhere else.

## EdgeRun seed

The rebuild starts when the user's device can run the app, hold the identity, store the object, explain the event log, and route to another user without turning every action into rented infrastructure.
