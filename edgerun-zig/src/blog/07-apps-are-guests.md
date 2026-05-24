# Apps Are Guests, Not Owners

An app should not get the whole device.

It should ask for what it needs: files, network, camera, microphone, notifications, storage, identity, and routes.

Mobile operating systems sandbox apps. Browsers sandbox websites. That is good. But permissions are often broad and confusing.

The problem is not that apps need access. Apps are useful because they do things for the user. The problem is that platforms often turn one reasonable request into a permanent, oversized grant.

> Mental model: an app should borrow specific rooms, not receive the keys to the building.

## Bad permission model

"Allow contacts" can mean upload the whole social graph.

"Allow camera" can mean access to a device, not one photo.

"Allow notifications" can mean a permanent interrupt channel.

The words are familiar, but the authority is vague. A photo picker and full photo library access are not the same thing. Sending one message and reading every conversation are not the same thing. Using the microphone during a call and having background microphone permission are not the same thing.

## Better permission model

A safe app should receive:

- narrow capabilities
- temporary authority
- inspectable access
- revocable rights
- logs of what happened

The best permission is often not a permission at all. Instead of granting an app the whole address book, the system can let the user choose one recipient. Instead of granting a whole directory, the system can pass one file object. Instead of letting an app open arbitrary network connections, the parent can give it a route with a purpose and budget.

## Guests need budgets

A guest should know which room it is allowed to use, how long it may stay, and what it may spend. Software is the same. CPU time, memory, storage, network, identity, notifications, and background work should all be allocated explicitly.

That turns permission from a pop-up into a contract:

```text
app asks -> parent grants capability
capability is used -> action is logged
parent revokes -> app loses access
```

The contract does not have to be loud. It has to be real.

## Interactive model

[[demo:post_model]]

## Main lesson

A safe app should receive exactly what it needs for the task in front of the user, not a tour of the user's life.

## EdgeRun seed

EdgeRun apps run inside a parent runtime. They get memory, storage, identity, routes, and capabilities from the parent. Subapps can only spend what they were allocated, and useful software can be composed without turning every plugin into an owner.
