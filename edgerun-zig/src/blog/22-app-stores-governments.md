# App Stores Became Governments

The app store is not just a shop. It is a border checkpoint, tax office, court, and police force.

App stores decide who can publish, what APIs apps can use, what payments are allowed, what content is acceptable, what apps are removed, what updates are allowed, what countries can access software, and what business models survive.

Whoever controls installation controls the practical law of the device.

> Mental model: an app store becomes government when it controls installation, payment, updates, and appeal.

## Distribution chain

```text
developer
  -> review
  -> signing
  -> payment policy
  -> regional policy
  -> update approval
  -> user installation
```

This chain can block malware and scams. It can also block competing payments, alternate browsers, emulators, repair tools, political apps, interoperability clients, adult content, crypto wallets, local runtimes, or anything that threatens the platform's business model.

## Update power

Distribution is not only initial installation. Updates matter more. If every security fix, feature change, and policy response needs gatekeeper approval, then the store governs the living app. It can delay fixes, require changes, remove capabilities, or make entire categories economically impossible.

## Why this feels normal

App stores became normal because they solved real pain:

- users needed safer installation
- developers needed distribution
- devices needed update channels
- payments needed fraud handling
- malware needed resistance

The mistake was letting one institution bundle all of those jobs into permanent authority over the device.

## Better store shape

A store should be a catalog, not a government. It can recommend apps, publish reputation, process payments, and warn users. The runtime should still let the owner install signed software, inspect capabilities, choose payment paths, pin versions, and remove authority without losing the whole device.

## What an appeal reveals

The quickest way to understand an app store is to ask what happens when it says no.

Can the developer explain the problem to users? Can users install anyway after seeing the risk? Is there an independent appeal? Can the rejected app still publish security updates? Can a small developer survive the delay? Can the store block a competitor while pretending the decision was only about safety?

Appeal paths reveal whether the store is acting like infrastructure or acting like a sovereign.

## Interactive model

[[demo:post_model]]

## Main lesson

Distribution is power. A store that controls installation, updates, payments, and policy is governing software, not merely selling it.

## EdgeRun seed

The better model is a user-controlled app runtime with signed apps, capability permissions, reputation, and verification, but no single gatekeeper over installation.
