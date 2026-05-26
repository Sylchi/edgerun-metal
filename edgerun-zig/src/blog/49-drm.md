# DRM Protects Someone Else's Business Model From Your Computer

DRM is not designed to protect your computer. It is designed to protect someone else's business model from your computer.

Widevine, streaming apps, ebooks, games, HDMI and HDCP, repair restrictions, and anti-circumvention law all show the same pattern: security can be aimed against the owner.

> Mental model: DRM treats the owner of the computer as the attacker.

## Content path

```text
user pays
  -> device must prove approved state
  -> content decrypts only inside approved path
  -> copying, repair, archiving, and modification are blocked
```

The owner of the computer is treated as the attacker. The device must hide keys from its owner, restrict outputs, refuse debugging, block copying, and sometimes obey laws that make circumvention illegal even for repair, preservation, or accessibility.

That is why DRM is such a clean example. It shows that "security" is not automatically good. Security always has a beneficiary.

## What DRM changes

DRM can affect:

- whether a paid file can be backed up
- whether old media remains playable
- whether repair tools are allowed
- whether screenshots or accessibility tools work
- whether a game survives server shutdown
- whether research and interoperability are legal

The user paid, but the user did not receive ordinary ownership. They received conditional playback inside an approved path.

## Better creator support

Creators deserve payment. That does not require turning the user's computer against the user.

Better systems can use explicit licenses, signed receipts, patronage, local ownership records, resale rules, watermarking chosen by contract, community norms, and transparent enforcement. None of those require pretending the owner is a burglar inside their own machine.

## Interactive model

[[demo:post_model]]

Protected content path: toggle owner control, vendor keys, output protection, and anti-circumvention law. The demo shows who the protection protects.

## Main lesson

DRM is one of the clearest examples of security for someone else.

## EdgeRun seed

User-owned computing should protect user secrets and creator rights through explicit contracts and cryptographic receipts, not by making the user's device hostile to the user.
