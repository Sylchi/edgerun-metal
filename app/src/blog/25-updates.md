# Updates: Who Is Allowed To Change Your Machine?

Ownership means little if the thing you own can be silently redefined after purchase.

Modern devices are remotely mutable. The operating system updates. Apps update. Dependencies update. Firmware updates. Models update. Feature flags flip. Server-side behavior changes without the app binary changing at all.

The user rarely gives meaningful consent. They wake up and the rules are different.

> Mental model: updates are remote mutation authority, even when they are useful.

## What changes

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

An update can fix a vulnerability. It can also remove a feature, add telemetry, change defaults, install a model, break compatibility, revoke an app, or make older hardware slow enough that replacement feels inevitable.

That means updates are not only maintenance. They are remote mutation authority.

## Who approves the change

The important questions are:

- who signed it
- who requested it
- who can delay it
- who can refuse it
- who can roll it back
- who can see what changed
- who pays if it breaks the user's work

Without those answers, "automatic update" means "someone else can redefine this machine."

## The owner should have a policy

Most people do not want to approve every patch by hand. That would be miserable. The answer is not endless prompts. The answer is owner policy.

The user should be able to say: install critical security fixes quickly, delay feature changes until I review them, never replace local data formats without export, keep the previous version available, and show me a receipt for what changed. The machine can still stay safe without making the owner passive.

## Interactive model

[[demo:post_model]]

Mutation timeline: start with a device the user bought, then apply an OS update, app update, dependency compromise, firmware patch, feature flag, and server policy change. The demo shows which layer changed and who approved it.

## Main lesson

A stable device needs an explicit update authority. Signed updates are necessary, but the important question is who holds the signing key, who can force the update, and whether the owner can refuse or roll back.

## EdgeRun seed

Apps should be signed, versioned, inspectable, and pinned by user policy. Updates should be events the owner can audit, not surprises delivered by someone else's control plane.
