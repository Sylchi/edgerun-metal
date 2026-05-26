# Computers Are Deterministic. We Made Them Guess.

I had to turn swap off on a machine with 64GB of RAM.

> Mental model: computers are easiest to trust when ownership is explicit before pressure appears.

## The wrong guess

Not because I was out of memory.

I was using around 30GB. I had around 30GB left. I knew the workload was not going to keep growing. But the system was still swapping heavily, dragging live work through disk I/O for no useful reason.

The computer became slow, not because it lacked resources, but because the resource manager guessed wrong.

Then I had to spend half an hour proving that the machine was doing pointless I/O.

That is modern computing in one sentence:

The machine does something hidden, the user suffers, and then the user has to investigate their own computer like a crime scene.

## Where uncertainty enters

A computer is naturally deterministic.

Given known input, known state, and known code, it should do known things.

But modern software stacks deliberately add uncertainty everywhere:

- dynamic allocation everywhere
- overcommit
- swap heuristics
- background cache eviction
- browser tab discarders
- OOM killers
- autoscaling
- retry loops
- hidden background services
- automatic updates
- dependency resolution
- JIT behavior
- garbage collection pauses
- speculative caching
- telemetry queues
- runtime feature flags

Then we act surprised when behavior becomes impossible to reason about.

We replaced "this program owns this much" with "let the system guess until something breaks."

## Authority has the same bug

The same pattern shows up in authority.

We give processes absurd rights by default, then try to claw them back later.

The old default model is broad permission first:

- process starts
- gets broad filesystem access
- gets broad memory allocation behavior
- gets network unless blocked
- can write caches, logs, and temporary files
- can spawn helpers
- can consume resources until the OS intervenes

Then after abuse appears, we add more machinery:

- sandboxes
- containers
- cgroups
- seccomp
- AppArmor and SELinux
- Flatpak portals
- browser permission prompts
- mobile app permissions
- Kubernetes limits
- policy engines
- monitoring stacks

Some of that machinery is useful.

But the shape is backwards.

The correct model is not: give everything, then restrict.

The correct model is: give nothing except the exact resources and authority delegated.

Security has the same disease as memory management: give too much first, then build expensive machinery to claw it back.

Swap is not a resource model. It is an emergency mechanism that became a hiding place for bad behavior.

A program should not be allowed to spend resources it was never given.

The fastest computer is the one that does not need to guess what matters.

If the user has to trace disk I/O to understand why their own machine is slow, the system already failed.

## What explicit control says

This is the reason preallocation matters.

Preallocation is not primitive.

It is honesty.

It says:

- this app owns this much memory
- this app owns this storage slice
- this cache is bounded
- this child app inherits from this parent
- this route was delegated
- this identity authority was scoped
- this resource request must flow upward

The system does not need to guess who is responsible when pressure appears.

It already knows.

EdgeRun starts from that opposite assumption.

The app does not get the world.

It gets a budget.

The app does not get the user's identity.

It gets delegated authority.

The app does not get storage by accident.

It gets a slice.

The app does not get to create a system-wide crisis.

It can only exhaust what it was given.

If it needs more, it asks the parent or the user.

If it exceeds its budget, it fails locally, prunes, checkpoints, or waits.

## Interactive model

[[demo:post_model]]

## Main lesson

No global emergency.

No mystery swap storm.

No killing unrelated work.

No app silently converting memory pressure into disk pressure.

That is not less advanced.

That is what control should have meant from the beginning.

## EdgeRun seed

EdgeRun makes resource and authority ownership explicit before work starts. The runtime should know which app owns memory, storage, routes, identity authority, children, and failure responsibility, so pressure produces a local decision instead of a system-wide guess.
