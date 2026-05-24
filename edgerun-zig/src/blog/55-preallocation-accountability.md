# Preallocation Is Accountability

Modern software has become very good at hiding its bad behavior.

> Mental model: preallocation turns resource use from a system-wide surprise into a local promise.

## Hidden cushions

Programs allocate too much memory, write too much cache, spawn too many helpers, pull too many dependencies, and leave too much garbage behind.

Instead of making programs honest, we add cushions.

- swap
- zram
- overcommit
- lazy allocation
- garbage collectors
- huge caches
- background cleaners
- OOM killers
- container limits
- auto-scaling
- observability stacks
- disk caches
- retry queues

Some of these are useful. They can save a machine from crashing. They can keep a workload alive under pressure. They can give operators time to react.

But together they create a culture where software does not need to know what it owns, what it costs, or when it should stop.

The programmer asks for memory casually. The runtime gives it. The OS lies and says: sure. The app grows. The cache grows. The disk churns. The system compresses RAM into zram, then swaps, then stalls. Then some background killer murders a process.

The user gets a slow computer and nobody knows who is responsible.

That is insane.

## What preallocation says

Preallocation sounds old-fashioned until you remember what it actually does.

It makes a program tell the truth.

If an app gets 256 MB, it has 256 MB.

If it wants to open a child app, it must allocate from its own budget.

If it wants durable storage, it must request a storage slice.

If it wants cache, that cache has a visible limit.

If it runs out, it must choose:

- prune
- checkpoint
- ask for more
- refuse the work
- stop clearly

That is not primitive.

That is honest.

Modern dynamic allocation often teaches the opposite lesson: allocate now and hope the system handles it.

Then the system handles it by making the user pay later through latency, disk writes, battery drain, thermal throttling, SSD wear, and mystery freezes.

Overcommit turns programmer optimism into user suffering.

Swap is not memory. Swap is a confession that the program spent memory it did not really have.

That does not mean swap and zram are evil.

Swap is an emergency lane. Modern software treats it like a highway.

zram can help workloads with compressible memory. Swap can prevent a crash. Both are useful safety nets.

They should not be the core resource model.

## When the system guesses

The fastest memory available to a program is RAM. If the app is designed around a known budget, it can use RAM intentionally and predictably. If it assumes infinite memory and relies on the OS to fake it, the system becomes unpredictable.

The worst part is not only that software overuses memory.

The worst part is that when the system finally breaks, the user does not get to choose what gets sacrificed.

The OS decides. The OOM killer decides. The browser tab discarder decides. The mobile OS background killer decides. The container orchestrator decides.

Those decisions are usually based on crude heuristics: memory usage, process score, background status, priority class, cgroup pressure, recent activity.

But those heuristics do not know what matters to the human.

The offending process might be a telemetry logger, runaway cache, compiler, browser tab, Electron app, AI worker, updater, or background service.

The thing killed might be the unsaved document, the terminal job, the editor session, the render, the upload, or the app where the user was doing real work.

That is backwards.

The user's work has priority over the system's guesses.

Current model:

- App abuses memory.
- System gets pressured.
- OS guesses what to kill.
- User loses work.
- Offending app may survive.

Better model:

- App reaches its budget.
- Parent runtime refuses silent expansion.
- App must prune, checkpoint, ask, or fail.
- User chooses what to evict.
- Offender cannot silently punish unrelated work.

A program should not be able to spend memory it does not own and make another program pay the bill.

## Pressure flows upward

This is why preallocation is not just performance engineering.

It is accountability.

If every app has a declared budget, then blame is local. The app that runs out of memory hits its own wall. It does not get to push the whole machine into crisis and let the OS randomly kill someone else.

Resource pressure should flow upward as a request, not sideways as collateral damage.

A child app needs more memory.

It asks the parent.

The parent can:

- deny
- grant from unused budget
- ask the user
- evict one of its own children
- checkpoint something
- prune cache
- escalate upward

No app gets to create a global emergency by pretending resources are infinite.

EdgeRun takes this seriously.

Memory is the live world.

Storage is explicit.

Apps run inside a budget.

Subapps inherit from their parent.

Children cannot exceed parent allocation.

Caches are bounded.

Durable state crosses an authorization boundary.

If resources run out, the user or parent runtime decides what happens.

No pretending.

No hidden infinite pile.

No mystery abuse.

## Interactive model

[[demo:post_model]]

## Main lesson

The point is not to make computers harsh.

The point is to stop lying.

If an app needs memory, say how much.

If it needs storage, ask for it.

If it creates cache, account for it.

If it cannot continue, fail clearly.

If it wants more, ask the authority above it.

Good software does not hide its cost.

Good software accounts for it.

If something must die, the user should know what is dying, why it is dying, and which app caused the pressure.

## EdgeRun seed

EdgeRun treats resource pressure as an authority question. A child asks its parent. A parent accounts for its children. The user can see the budget, the pressure, and the consequence before unrelated work gets punished.
