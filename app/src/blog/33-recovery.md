# Recovery: The Ignored Hard Problem

A better internet must protect people from platforms and from their own accidents.

User-owned identity sounds clean until someone loses a key, breaks a phone, forgets a password, loses a house, or dies. Freedom without recovery becomes self-custody panic.

Cloud accounts solve recovery by becoming the root of everything. That is convenient, but it means the recovery provider can also become the owner, judge, and lockout switch.

The hard problem is building recovery that helps the user without silently handing the user's life back to a platform.

> Mental model: recovery must protect users from loss without making a platform the owner.

## What recovery must handle

- multiple devices
- hardware keys
- encrypted backups
- social recovery
- family recovery
- threshold keys
- dead-man switches
- inheritance
- emergency access
- revocation

Those are different failures. Losing one phone is not the same as compromise. Forgetting a password is not the same as coercion. Death is not the same as a stolen laptop. A humane recovery system cannot pretend one reset button solves them all.

## The dangerous shortcut

The usual shortcut is simple:

```text
lose access -> ask platform -> platform decides
```

That works until the platform thinks you are suspicious, your phone number changed, your region changed, your account was flagged, your recovery email is gone, or support is an automated loop.

At that point "recovery" becomes permission to beg.

## Better recovery shape

Recovery should be explicit before disaster:

- which devices can help
- which people can help
- which hardware keys count
- which delay protects against theft
- which authority can revoke a lost device
- which data can be restored
- which actions require extra confirmation

The user should be able to inspect the policy while everything is calm, not discover the rules while locked out.

## Interactive model

[[demo:post_model]]

Recovery design board: choose between single device, cloud recovery, hardware keys, family trustees, and threshold recovery. The demo shows platform risk, loss risk, and coercion risk.

## Main lesson

Recovery is not optional. If the user owns the root, the user also needs humane paths for loss, compromise, and death.

## EdgeRun seed

EdgeRun identity should support explicit recovery policies without turning recovery into platform ownership.
