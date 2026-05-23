# Security for Whom?

"For security" is not an answer. Security has a direction.

Security can protect the user from malware, the platform from user modification, the carrier from radio abuse, the copyright owner from copying, the payment provider from fraud, the app store from competition, the government from unauthorized communication, or the manufacturer from repair markets.

The phrase sounds final because nobody wants to be against security. But security is never floating in the air. It protects a specific actor from a specific threat using a specific mechanism controlled by specific keys.

## Same mechanism, different owner

- Secure boot can protect users from persistent malware.
- Secure boot can also prevent users from installing their own OS.
- App signing can block malicious apps.
- App signing can also block independent distribution.
- DRM can protect copyright.
- DRM can also prevent repair, archiving, modification, and legitimate ownership.

The technical mechanism may be identical. The political result depends on who can approve software, who can audit policy, who can recover, who can override, and who gets treated as the attacker.

## Override key

Ask where the override key lives. If the user can override, the mechanism is a tool. If only the vendor can override, the mechanism is a control plane. If nobody can override, the mechanism may be brittle. If a government or payment network can override, the user is not the final authority.

## Main lesson

Whenever someone says "for security," ask: security for whom, against whom, and who holds the override key?

## EdgeRun seed

Security should make authority visible. A system that claims to protect users must show which keys, policies, and actors can override the user.
