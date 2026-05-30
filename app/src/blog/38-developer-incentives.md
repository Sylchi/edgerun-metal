# Modern Development Often Replaces Engineering With Subscription Assembly

Software is bloated because the economy rewards shipping dependencies, not understanding systems.

Developers are pushed to move fast, rent infrastructure, add SDKs, use giant frameworks, collect metrics, plug in cloud APIs, and avoid ownership problems that do not show up in the next sprint.

> Mental model: bloat is often the bill for incentives that reward assembly over understanding.

## Incentive stack

- npm, cargo, and pip sprawl
- Electron shells for simple apps
- cloud SDK defaults
- SaaS auth
- CI/CD layers
- observability vendors
- Kubernetes for small workloads
- A/B testing everywhere
- growth analytics

Each choice can be rational locally. A team wants auth, payments, charts, logs, crash reporting, push notifications, AI, sync, and deployment before Friday. The fastest answer is another package or service.

The bill arrives later as complexity:

- larger attack surface
- slower builds
- more hidden I/O
- more update pressure
- more legal surfaces
- more tracking by default
- less understanding by anyone on the team

Nobody chose a monster. Everyone chose a shortcut.

## What engineering should optimize

Good engineering is not refusing all reuse. It is knowing where reuse is allowed.

The core should be small and owned. App edges can use replaceable services. Tooling should account for resources. Dependencies should be exceptional when they cross identity, storage, signing, update, execution, or resource authority.

That distinction matters more than fashion. A UI icon package is not the same risk as a package inside the signing root.

## Interactive model

[[demo:post_model]]

Dependency incentive map: start with a simple app, then add common business requirements. The graph shows code size, trust surface, update surface, and monthly vendor dependency.

## Main lesson

Bloat is not only a technical failure. It is an economic outcome.

## EdgeRun seed

Small deterministic WASM apps, first-party components, and explicit capabilities make it easier to ship understandable software without renting every foundation.
