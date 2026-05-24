# Push Notifications: The Remote Bell On Your Friend's Phone

Your friend's phone does not sit awake for every app forever. Mobile operating systems conserve power by routing wakeups through platform push services.

That means a message often travels through the sender's service, a platform notification provider, the friend's operating system, and only then the receiving app. The content may be encrypted, but the wake path still exposes relationships, timing, app identity, and delivery metadata.

Push notifications exist because phones are battery-constrained. Letting every app keep its own permanent network connection would waste power and radio time. So mobile platforms centralize wakeups.

> Mental model: push is a remote wake path, not just a message bubble.

## The wake path

[[demo:push_wake_path]]

```text
sender service -> platform push service
platform push service -> phone OS
phone OS -> app wake -> decrypt or fetch
```

This path is efficient, but it is not neutral. The platform learns that an app is waking a device at a time. Depending on design, the service may know the sender, recipient, device token, app identity, urgency, and delivery state. The receiving app may then fetch content from its own server, creating another server-side event.

## Content and metadata

Encrypting notification content helps, but metadata remains:

- which app sent a wakeup
- which device was targeted
- when delivery happened
- whether the device was online
- whether the user opened the app
- how often a relationship produces traffic

For casual reminders, that may be acceptable. For private conversations, identity recovery, payments, or sensitive alerts, the wake path becomes part of the privacy model.

## The tradeoff

Reliable wakeups require some coordinator when the receiving device sleeps. The question is how much the coordinator must know. A better design can separate wake, route, and content so that intermediaries carry the minimum needed information.

## Main lesson

Convenience often arrives through another company standing in the middle of the path.

## EdgeRun seed

Peer routes and local relays should reduce the number of intermediaries needed to wake and deliver user-owned messages. When a coordinator is needed, it should learn as little as possible and never become the owner of the message.
