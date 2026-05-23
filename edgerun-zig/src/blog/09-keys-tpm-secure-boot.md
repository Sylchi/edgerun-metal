# Keys, TPMs, and Secure Boot: Who Holds the Root?

Security is not just locks.

It is also about who holds the master key.

Secure boot checks that boot software is approved. A TPM or secure element can store keys, sign data, or help prove system state. Attestation can prove what environment signed something. Sealing can make data open only under the right hardware, software, and user context.

## The hard question

When a device says "this is secure," ask:

- secure from whom?
- measured by whom?
- approved by whom?
- recoverable by whom?
- overrideable by whom?

## Main lesson

Security depends less on having a lock and more on who holds the master key.

## Edgerun seed

Critical services should verify user intent and measured runtime state, not require trust in one vendor-approved phone path.
