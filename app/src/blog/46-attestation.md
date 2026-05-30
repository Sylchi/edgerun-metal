# Attestation Asks Who Gets To Decide Which Software Is Legitimate

The same technology that proves safety can also enforce obedience.

Hardware roots of trust, TPMs, secure enclaves, Android hardware attestation, Play Integrity, DRM, banking checks, and enterprise device management can prove software state. They can also exclude modified devices.

> Mental model: attestation is evidence until one authority makes it permission.

## The question

Attestation answers:

```text
What software is this device running?
Who signed it?
Who accepts that signature?
What happens if the owner changed it?
```

That question can protect the user. A user may want proof that a backup device is running the expected recovery code. A business may want proof that a payment terminal has not been modified. A peer may want proof that a relay is running audited software.

But the same mechanism can also say: the owner changed the device, so the owner is no longer allowed to bank, watch, work, install, repair, or participate.

## Useful proof versus remote permission

Good attestation says:

```text
here is the measured state
here is who measured it
here is the claim being made
you decide whether that claim is enough
```

Bad attestation says:

```text
vendor accepts this state
everyone else must reject the owner
```

The first is evidence. The second is remote permission dressed as security.

## What should be explicit

Every attestation system should name:

- the root key
- the measured software
- the policy verifier
- the consequence of failure
- the appeal or owner override path
- whether the proof reveals unnecessary identity

Without those details, "trusted" usually means "trusted by someone more powerful than the user."

## Interactive model

[[demo:post_model]]

Trust root selector: choose owner key, vendor key, bank policy, enterprise policy, or app store policy. The demo shows which software becomes legitimate.

## Main lesson

Attestation is not automatically pro-user or anti-user. The politics are in who defines acceptable state and who holds the override key.

## EdgeRun seed

EdgeRun should use attestation to prove explicit claims without making vendor approval the only path to trust.
