# Your App Is Not One Thing

You opened a chat app. You may have also opened a tiny shopping mall of other people's code.

A modern app can include analytics, crash reporting, ad SDKs, notification SDKs, login providers, UI frameworks, crypto packages, cloud clients, logging, payments, experiments, feature flags, and many layers of dependencies below those.

The icon is a brand promise. The binary is a supply chain.

## What came with the app

The feature the user wanted might be simple: send a message, edit a note, show a calendar, track a workout. But the installed app may also include:

- analytics SDKs
- crash reporters
- ad identifiers
- login providers
- push notification clients
- payment SDKs
- A/B testing systems
- remote configuration
- cloud database clients
- native bridges
- media codecs
- transitive package dependencies

Each dependency brings code, update paths, policy, logging, and failure modes. Some are useful. Some are rent-seeking. Some were added because a developer did not have time to build the small part they needed. Some were added because the platform made the easy path the invasive path.

## The hidden trust graph

```text
chat app -> login SDK -> identity provider
chat app -> analytics SDK -> event stream
chat app -> push SDK -> platform wake path
chat app -> cloud SDK -> remote state owner
```

This graph matters because code is authority once it runs. A library can allocate memory, inspect inputs, make network requests, log errors with sensitive context, change behavior after a remote config update, or become a vulnerability that ships inside thousands of unrelated apps.

## Why dependencies feel free

Dependencies feel free because their costs arrive later. The download gets bigger. Startup gets slower. The privacy policy expands. The attack surface grows. The team spends time tracking versions and security notices. A package changes ownership. An SDK starts collecting more data. A build breaks because a remote package disappeared.

For the user, the result is simple: the app they trusted is not the only thing they trusted.

## Main lesson

Dependencies are not free. They consume storage, CPU, bandwidth, developer attention, update risk, and trust, even when the UI hides them behind one icon.

## EdgeRun seed

Small, inspectable apps running as deterministic units can reduce the amount of code users must trust. The goal is not dependency theater. The goal is authority that is narrow enough to inspect and cheap enough to replace.
