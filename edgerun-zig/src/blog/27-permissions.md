# App Permissions: Fake Clarity

Permission prompts make surveillance feel like consent.

"Allow camera" rarely means "allow one photo now." "Allow contacts" may mean upload the whole social graph. "Allow location" may mean continuous behavioral tracking. "Allow notifications" may mean engagement manipulation.

> Mental model: real permission names one action, not a permanent territory.

## The problem

Current prompts often grant territories:

- camera
- contacts
- location
- microphone
- photos
- notifications
- background activity

But real permission should describe an action.

## Better model

- narrow
- temporary
- inspectable
- revocable
- logged
- bound to a purpose

The difference is concrete.

Bad permission:

```text
allow contacts
```

Better permission:

```text
let this app send one invitation to this contact now
```

Bad permission:

```text
allow location
```

Better permission:

```text
share approximate location with this driver until this delivery ends
```

## Why prompts feel fake

Prompts appear at the wrong time and hide the real consequence. Users are trained to tap through because the app refuses to work otherwise. The prompt says "allow photos" but not whether photos will be uploaded, indexed, used for AI, shared with SDKs, or retained after deletion.

A permission system should explain the action in terms the user recognizes.

## Consent needs a receipt

The missing piece is memory. After the prompt disappears, the user should still be able to answer: what did I allow, when did I allow it, what data moved, which app used it, and how do I revoke it without breaking unrelated things?

Without that record, consent becomes a one-time ceremony. With a record, permission becomes an inspectable contract.

## Interactive model

[[demo:post_model]]

Permission scope slider: compare "allow contacts" with "pick one contact once" and "allow location" with "share this approximate location for this delivery."

## Main lesson

A real permission should describe an action, not grant a territory.

## EdgeRun seed

EdgeRun capabilities should be explicit objects: who may do what, to which data, for how long, with what audit trail.
