# Open Systems Fail When They Ignore Abuse

The answer to abuse cannot be giving one company ownership of everyone's identity.

Open systems get attacked. Spam, scams, harassment, malware, botnets, fraud, and illegal content are real. Closed systems often use those threats as the excuse for total control.

> Mental model: abuse response needs layers, not one company owning everyone's identity.

## The trap

Ignoring abuse fails users.

Centralizing identity fails users too.

The better path is layered:

- user-level filters
- community moderation
- portable reputation
- signed claims
- local block lists
- rate limits
- proof of work where useful
- abuse receipts
- legal escalation when required

Different abuse belongs at different layers. A user can block a person. A community can remove spam from its own space. A relay can refuse malware traffic. A payment network can reject fraud. Courts can handle serious legal disputes.

The mistake is forcing every problem into one universal identity system.

## Why central moderation wins by default

Central moderation is attractive because it is simple to explain:

```text
one platform
one account
one policy
one ban button
```

But that simplicity creates permanent dependence. If the platform owns identity, reputation, distribution, and appeal, then abuse response becomes the justification for total control.

## Better abuse response

Open systems need evidence and boundaries:

- signed reports
- rate limits
- scoped identities
- portable block lists
- community-specific rules
- relay-level resource policy
- local client filters
- appealable receipts

The goal is not zero moderation. The goal is moderation without one company owning everyone's social existence.

## Interactive model

[[demo:post_model]]

Abuse response layers: send spam through an open network and choose which layer responds. The demo shows what gets blocked locally, by communities, by relays, or by legal process.

## Main lesson

Moderation should not require one central speech police. It should be layered, inspectable, and movable with the user.

## EdgeRun seed

Relays can reject abuse without owning identity or message content when reputation, receipts, and capabilities are designed into the substrate.
