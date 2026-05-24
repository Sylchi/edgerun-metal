# The Account That Recovers Your Accounts Owns Your Accounts

Your master identity should not be someone else's customer record.

Google accounts, Apple IDs, Microsoft accounts, Facebook accounts, and email accounts are not just logins. They become recovery keys for everything else.

> Mental model: the account that recovers your accounts becomes a root of life.

## Root of life

- email recovery
- phone number recovery
- OAuth login
- password manager unlock
- cloud backups
- device activation locks
- app purchases
- photos and documents
- account bans

If the root account is locked, every dependent account can become unreachable.

This is how a convenience becomes a constitutional problem. The account started as a login. Then it became email. Then it became app purchases, device activation, photo backup, password reset, OAuth identity, two-factor recovery, and payment approval.

Lose the root and the tree falls.

## Blast radius

A root account failure can mean:

- no phone activation
- no email recovery
- no password manager reset
- no app purchases
- no cloud backup restore
- no photos
- no work login
- no bank recovery
- no support path except the same locked account

The user does not experience this as "one account issue." They experience it as exile from ordinary life.

## Better root shape

Identity should have layers:

```text
user-held key -> device keys
device keys -> app relationships
app relationships -> optional cloud labels
cloud labels -> sync and convenience
```

The cloud account can still be useful. It can route, sync, notify, and label. But it should not be the root proof that the person exists.

## Interactive model

[[demo:post_model]]

Root account graph: connect bank, work, photos, messaging, device activation, and password manager to a cloud account. Then lock the cloud account and watch the blast radius.

## Main lesson

The account that can recover your accounts has authority over your life. That authority should not live inside one company's customer database.

## EdgeRun seed

Identity should start with user-held keys and multi-device recovery. Cloud accounts can be labels and sync helpers, not roots of personhood.
