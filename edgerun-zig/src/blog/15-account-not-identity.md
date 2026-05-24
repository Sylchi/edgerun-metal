# Your Account Is Not Your Identity

Most people are trained to think "my account" means "me." But an account is a rented identity container.

Accounts can be suspended, deleted, locked, shadowbanned, region-restricted, rate-limited, reset, or trapped behind support processes. The platform can decide the account exists or does not exist.

An account is a relationship with a service. It is useful, but it is not the person. The service created the namespace, stores the record, enforces the rules, and decides what recovery means.

> Mental model: an account is a rented container; identity should be proof you can carry.

## Account identity

[[demo:account_vs_key]]

```text
real person -> platform account -> app login -> service access
```

This model is easy to understand, which is why it spread. But it means the platform sits between the person and recognition. A locked account can make the same human unreachable. A deleted account can erase years of relationships. A region restriction can turn identity into geography.

## Key identity

```text
real person
  -> user-owned key
  -> optional names, profiles, and recovery
  -> services recognize proofs
```

A private key is like a stamp only you can use. A public key is how others verify that stamp. The point is not crypto fashion. The point is portability: the person can prove continuity without renting the root of identity from one service.

## Layers above identity

Names, avatars, profiles, contact methods, social graphs, recovery guardians, and reputation can all sit above keys. They can change. They can be disputed. They can be lost and rebuilt. The root identity should survive those changes.

## Why this matters for normal life

Most account problems are treated like customer support problems: fill the form, wait for review, hope a human agrees. But when an account becomes identity, support becomes citizenship. A locked account can cut someone off from work, money, friends, photos, purchases, or the ability to sign in elsewhere.

User-owned identity does not remove services. It changes the root. A service can still ban abuse from its own space, but it should not be able to erase the person's continuity everywhere. The person should be able to prove "I am the same key holder as before" even when a platform account fails.

## Main lesson

An account is permission. A key is identity.

## EdgeRun seed

Services should recognize proofs from user-owned keys. Names, profiles, and recovery methods should be optional layers above identity, not the root of identity.
