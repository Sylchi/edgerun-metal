# The App Store Is A Tax Border Around Software

When distribution and payment are controlled by the same gatekeeper, software becomes feudal.

App stores do not only decide what can be installed. They decide what business models are allowed, whether developers can link to outside payments, what commission is owed, and whether users can have a relationship with a developer outside the platform.

> Mental model: bundling distribution and payment turns software into a taxed border crossing.

## The border

- publish approval
- API approval
- category approval
- payment approval
- commission
- region availability
- update approval
- delisting

Those powers are not all bad. Users need a way to find apps, avoid malware, receive updates, and pay safely. The problem is combining safety, discovery, payment, policy, taxes, identity, and device control into one gate.

Once that happens, a developer is not only selling software. They are requesting permission to exist inside a private jurisdiction.

## What gets bundled together

The store can control:

- installation
- search ranking
- payment rails
- refund rules
- subscription terms
- allowed APIs
- update timing
- region access
- developer identity
- user relationship

If a business depends on that stack, the platform can rewrite the business overnight.

## Better distribution shape

Safer distribution does not require one global store:

```text
signed app -> declared capabilities -> user policy
catalog -> optional discovery
payment -> separate receipt
runtime -> enforce limits
```

The store can recommend. The runtime should enforce capability boundaries. Payment should produce a receipt, not permanent platform ownership of the developer relationship.

## Interactive model

[[demo:post_model]]

Distribution fee gate: move an app from direct install to app store install. The path adds review, payment rules, commission, policy risk, and user relationship limits.

## Main lesson

The app store is not a shop. It is a border checkpoint around installation and a tax office around software businesses.

## EdgeRun seed

EdgeRun apps should be signed and capability-scoped, but distribution and payment should not require one global gatekeeper.
