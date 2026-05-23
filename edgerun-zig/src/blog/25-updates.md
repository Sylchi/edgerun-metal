# Updates: Who Is Allowed To Change Your Machine?

Ownership means little if the thing you own can be silently redefined after purchase.

Modern devices are remotely mutable. The operating system updates. Apps update. Dependencies update. Firmware updates. Models update. Feature flags flip. Server-side behavior changes without the app binary changing at all.

The user rarely gives meaningful consent. They wake up and the rules are different.

## What Changes

- OS code
- app code
- dependency code
- firmware
- model weights and prompts
- feature flags
- remote kill switches
- server APIs
- app store availability
- rollback policy

## Interactive Demo

Mutation timeline: start with a device the user bought, then apply an OS update, app update, dependency compromise, firmware patch, feature flag, and server policy change. The demo shows which layer changed and who approved it.

## Main Lesson

A stable device needs an explicit update authority. Signed updates are necessary, but the important question is who holds the signing key, who can force the update, and whether the owner can refuse or roll back.

## EdgeRun Seed

Apps should be signed, versioned, inspectable, and pinned by user policy. Updates should be events the owner can audit, not surprises delivered by someone else's control plane.
