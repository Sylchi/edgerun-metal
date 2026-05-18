# EdgeRun Metal Next Work

Purpose: point metal-runtime work at the single repository roadmap.

Intention: avoid a second milestone list inside `edgerun-metal` that can drift
from the OS/runtime plan.

The metal core is the bootable OS runtime for user-authored Wasm apps. Netboot,
GOP, PCI scans, and direct hostcalls are support surfaces. The product
architecture is `edgerun-work` carried by erwire between apps, UI renderers,
input, drivers, storage, relays, and hardware capabilities.

Use these repository-level documents for active planning:

- `../docs/coherent-system-milestones.md`: ordered roadmap, milestones, and proof gates.
- `../docs/relay-architecture.md`: runtime architecture and jurisdiction model.
- `../docs/runtime-concepts-c-port.md`: C runtime concepts and ABI intent.

The immediate implementation slice is Milestone 1 in the roadmap: wire native
VirtIO-net erwire ingress into the OS loop, decode admitted work through route
verification, and emit deterministic acknowledgement or transit records.
