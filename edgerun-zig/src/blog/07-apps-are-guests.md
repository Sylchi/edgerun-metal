# Apps Are Guests, Not Owners

An app should not get the whole device.

It should ask for what it needs: files, network, camera, microphone, notifications, storage, identity, and routes.

Mobile operating systems sandbox apps. Browsers sandbox websites. That is good. But permissions are often broad and confusing.

## Bad permission model

"Allow contacts" can mean upload the whole social graph.

"Allow camera" can mean access to a device, not one photo.

"Allow notifications" can mean a permanent interrupt channel.

## Better permission model

A safe app should receive:

- narrow capabilities
- temporary authority
- inspectable access
- revocable rights
- logs of what happened

## Main lesson

A safe app should receive exactly what it needs, not a tour of your life.

## Edgerun seed

Edgerun apps run inside a parent runtime. They get memory, storage, identity, routes, and capabilities from the parent. Subapps can only spend what they were allocated.
