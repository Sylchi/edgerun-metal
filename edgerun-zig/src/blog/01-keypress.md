# You Pressed a Key. Now What?

Pressing a key is not "typing into the internet." It is a chain of events that starts as electricity and becomes meaning only after several layers agree on what happened.

When you press H, the computer does not know you are saying hello. It only knows an electrical event happened.

The first lie of modern software is that action begins on the internet. It usually begins much closer: a switch changes state, a controller reports a scan code, the operating system converts that into an input event, and the focused app decides what to do with it.

## From electricity to text

A keypress has to become several different things before it becomes part of a message:

- physical movement
- electrical signal
- hardware event
- operating system input event
- app event
- text buffer change
- rendered pixels
- message draft

None of those are the same object. The keyboard does not know about the chat. The OS does not know whether H is the beginning of hello or a game command. The app does not know the message exists until it changes its own state.

## The event path

[[demo:keypress_commit_path]]

```text
finger -> keyboard hardware -> OS input queue
OS input queue -> app event loop -> draft buffer
draft buffer -> render -> visible text
```

Every step changes the shape of the event. Hardware reports a low-level signal. The OS turns that into an input event. The app turns the event into state. The renderer turns state into pixels. Only later does the app decide whether that state should become a durable message object.

## Why this matters

If an app can observe every key before the user commits, the app owns more than sent messages. It owns hesitation, corrections, deleted drafts, passwords typed into the wrong field, and private thoughts that never became communication.

The clean boundary is not "everything typed goes to a server." The clean boundary is "local input becomes local state, and only explicit user intent turns selected state into an object worth storing or sending."

## Main lesson

Even before the internet, there are layers. Each layer changes the shape of reality, and the commit point should be explicit.

## EdgeRun seed

If every important committed event is recorded as an append-only signed event, your device can explain what happened instead of asking a server to remember for you. Raw input can stay local; durable intent can become a verifiable object.
