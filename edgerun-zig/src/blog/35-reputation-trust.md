# Reputation Should Be Portable

A reputation you cannot take with you is not yours.

If users own identity, people need a way to decide who to trust. Platforms currently trap trust inside stars, likes, badges, reviews, handles, and internal risk scores.

> Mental model: reputation should be scoped proof you can carry, not a badge trapped in one platform.

## Portable trust

Trust can be represented as signed claims:

- this key belongs to a person I know
- this developer published this app
- this merchant completed these orders
- this device belongs to my account
- this community trusts this moderator

Claims can expire, be revoked, and be scoped.

That matters because trust is not one global score. You may trust a person to review cameras but not hold your house key. You may trust a developer to publish a calculator but not a banking app. You may trust a merchant for small orders but not expensive equipment.

Platforms flatten those relationships into internal badges because badges are easier to monetize and control.

## What portable reputation needs

Portable trust should answer:

- who made the claim
- what exactly was claimed
- when it expires
- how it can be revoked
- what evidence supports it
- whether revealing it leaks private relationships

The goal is not to make everyone carry a public permanent score. That becomes social credit with better branding. The goal is to let users carry useful, scoped proofs between tools.

## Local trust lists

A user should be able to combine:

```text
my contacts
community claims
developer signatures
device attestations
merchant receipts
local block lists
```

Different apps can read different parts with permission. Trust becomes a user-owned graph, not a platform-owned prison.

## Interactive model

[[demo:post_model]]

Signed claim graph: add claims between users, devices, merchants, apps, and communities. Move the user to a new app and keep the trust graph.

## Main lesson

Trust should be portable, not trapped inside platform badges.

## EdgeRun seed

EdgeRun can use keys, attestations, local trust lists, and revocable credentials to prove relationships without exposing more data than necessary.
