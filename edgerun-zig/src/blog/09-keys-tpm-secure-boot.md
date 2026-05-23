# Keys, TPMs, and Secure Boot: Who Holds the Root?

Security is not just locks.

It is also about who holds the master key.

Secure boot checks that boot software is approved. A TPM or secure element can store keys, sign data, or help prove system state. Attestation can prove what environment signed something. Sealing can make data open only under the right hardware, software, and user context.

Those tools can protect the user. They can also protect a vendor from the user. The mechanism is not enough. You have to ask who controls the keys, who can enroll new software, who can recover after failure, and who can override the policy.

## The hard question

When a device says "this is secure," ask:

- secure from whom?
- measured by whom?
- approved by whom?
- recoverable by whom?
- overrideable by whom?

Secure boot is a chain. Early boot code checks the next stage before running it. That stage checks the next one, and so on. If the chain ends in user authority, it can help prove the user's machine is running the user's expected software. If the chain ends in vendor authority, it can also prevent the user from replacing software on hardware they bought.

## What a TPM is useful for

A TPM or secure element can make keys harder to extract. It can sign a statement saying a key operation happened inside a measured environment. It can seal data so that it opens only when boot state and policy match. That is useful for local identity, encrypted storage, recovery flows, transaction approval, and device-to-device trust.

But a TPM should not become a magic word. It does not make a bad policy good. It does not prove the UI told the truth. It does not prove the user intended an action unless the signing path includes a real intent boundary.

## Good root-of-trust shape

[[demo:secure_boot_root]]

```text
measured boot -> local runtime identity
local runtime identity -> user intent
user intent -> sealed object or signature
```

The important part is the direction. Hardware helps bind keys to a measured local runtime. The runtime still has to bind actions to explicit user intent.

## Main lesson

Security depends less on having a lock and more on who holds the master key, who can change the lock, and what the key is allowed to approve.

## Edgerun seed

Critical services should verify user intent and measured runtime state, not require trust in one vendor-approved phone path. A TPM-backed identity is valuable when it signs explicit local authority, not when it becomes another opaque platform blessing.
