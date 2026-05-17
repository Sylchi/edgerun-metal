# edgerun-c

This repository contains three C projects:

- `edgerun-metal`: a freestanding x86_64 UEFI runtime that boots as `BOOTX64.EFI` and runs embedded Wasm modules with native hostcalls.
- `varfont`: a zero-dependency variable-font renderer library with parser, shaping, rasterization, atlas, and test coverage.
- `edgerun-ui-core`: the C port of EdgeRun's platform-neutral UI scene command buffer.

## Why This Work Exists

EdgeRun is built around sealed, identity-routed work instead of trusted network
sessions. A node's durable protocol identity is its public key. Transport
addresses, including Ethernet MAC addresses, are local delivery locators, not
authority. The packet or work object carries the authority: recipient-bound
encryption, signatures, hashes, admission-defined routes, ordered-channel state,
delivery proofs, and receipts.

That changes what the native runtime needs from hardware. It does not need a
full IP stack, DNS, TLS termination, VPN overlays, service-mesh sidecars, or API
gateway identity assumptions before useful protocol traffic can move. It needs
drivers that can move opaque EdgeRun frames through local devices, starting with
VirtIO networking and direct Ethernet delivery. If a wrong MAC address receives
sealed content, it still cannot decrypt it, authorize it, forge recipient
proofs, or make it payable.

The goal of the metal work is to replace firmware boot-service networking with
runtime-owned drivers:

1. Discover PCI/MMIO devices from ACPI and PCI configuration space.
2. Bring up VirtIO queues in freestanding C.
3. Move raw Ethernet frames through the native NIC path.
4. Carry EdgeRun channel/work bytes directly over local L2 frames.
5. Keep IP/UDP/TLS as compatibility bridges only, not as protocol foundations.

This is valuable because it removes duplicated infrastructure from the critical
path. Existing systems often secure pipes: IP endpoints, TLS sessions, proxies,
gateways, meshes, and private-network perimeters. EdgeRun secures the work
itself, so memory, Ethernet, USB, Bluetooth, WebSocket, TCP, files, or future
transports can all move the same verifiable bytes.

## Global Resource Sharing

> "I think compute is going to be the currency of the future."
>
> Sam Altman, [Lex Fridman Podcast #419](https://www.youtube.com/watch?v=jvqFAi7vkBc&t=10s) ([transcript](https://lexfridman.com/sam-altman-2-transcript/))

The larger goal is user-governed global resource sharing. A user should be able
to join a computer, phone, storage device, renderer, or local network link to a
global EdgeRun network without handing authority to a carrier, cloud operator,
VPN, TLS endpoint, or trusted relay.

Each device remains inside its owner's jurisdiction. The owner can decide what
it offers, who may use it, what it costs, and what limits apply. That offer can
be free, paid, reciprocal, or policy-based. Tokens or admissions can represent
scoped rights such as:

- move up to N bytes through this relay
- store up to N sealed object bytes
- use this local Wi-Fi path for N packets
- reserve N CPU, memory, render, or scheduling units
- reach only this route, recipient, role, department, or time window

The token is not control over the device. It is a bounded claim that local
policy may accept, reject, rate-limit, revoke, price, or settle. The device
still governs its own queues, storage, radio, battery, CPU, memory, display,
and user relationships.

The practical path is that every admission authority can issue tokens only up
to the resources it actually governs and can prove. A laptop admission can mint
bounded claims against its measured CPU, disk, Wi-Fi relay, battery budget,
local apps, and local users. A phone admission can mint bounded claims against
its radio, hotspot path, storage, camera, and background scheduling windows.
Those claims are created by deterministic, identity-routed accounting programs
that bind capacity, admission policy, packet cost, work output, proof, and
receipt to the device identity. They are meaningful only where that admission
is accepted. An identity without an accepted admission token can still sign
packets, but it has no right to consume that jurisdiction's resources.

For hardware-backed devices, the proof chain can start below the operating
system. A signed EFI image gives the device owner and admission policy a known
runtime entry point. Secure Boot can refuse unsigned or unauthorized boot code.
Measured boot can extend firmware, EFI image, boot configuration, drivers, and
runtime measurements into TPM PCRs. The device can then produce TPM quotes that
bind those measurements to a device-held attestation key and to an EdgeRun
node identity.

That does not prove an infinite abstract machine; it proves a specific measured
machine state. EdgeRun admission can combine the TPM quote with deterministic
hardware discovery and runtime self-measurement: CPU topology, memory map,
storage device identity and size, NIC identity, accelerator presence, battery
state, queue limits, and booted EdgeRun runtime hash. The admission program can
then mint only the token budget allowed by that measured state and local owner
policy. If the EFI image, boot chain, hardware inventory, or accounting program
changes, the measurements change and old capacity claims stop matching the
admission policy.

The useful invariant is:

```text
signed EFI + Secure Boot + TPM measured boot
  -> attested EdgeRun runtime identity
  -> deterministic hardware/resource inventory
  -> admission policy
  -> bounded resource-token issuance
  -> packet/work proofs and receipts
```

This makes hardware resources identity-routed and auditable without giving the
TPM, firmware vendor, or network operator authority over the user's device. They
only help prove what code booted and what resources that code measured. Local
admission still decides what is offered, what it costs, who can use it, and how
much capacity can be turned into spendable claims.

Each packet, object, compute slice, storage interval, relay hop, or scheduling
slot can therefore carry a cost before it is admitted. Local programs may spend
tokens created by the same user up to the limits the device owner assigned.
Friends, nearby devices, organizations, apps, or strangers crossing into another
jurisdiction must pay in a token that the destination admission accepts, under
that destination's current price and policy.

There does not need to be one global token or one global operator. Users can
accept tokens from other users, price their own resources against those tokens,
and rebalance by spending the mixed tokens they earn on other people's
resources. External settlement bridges, stablecoins, or swap services can help
when a user wants harder settlement, but they are bridges around local
admission, not the source of authority. The protocol only needs the work claim,
admission, route, proof, receipt, and settlement records to agree on what was
authorized and what was actually delivered.

This means phones can relay packets over open Wi-Fi without first reaching a
global operator network over 4G. Computers can store or relay other users'
sealed data without being able to decrypt it. Any transport can carry packets
because every packet is accounted for by signed intent, scoped admission,
ordered-channel state, payload hashes, transit evidence, delivery proofs, and
receipts.

Global compatibility comes from the shared `edgerun-work` contract. Abuse is
limited by local admission policy and by proof-based accounting: resources are
shared only inside the scope the owner admitted, and payment or credit is owed
only for verified work.

The rough global scale is large enough to matter. IEA estimates data centres
used about 415 TWh in 2024 and may reach about 945 TWh by 2030. IEA also
estimates data transmission networks used about 260-360 TWh in 2022. A simple
current addressable pool for digital infrastructure is therefore about
675-775 TWh/year before end-user devices.

Order-of-magnitude savings if protocol and infrastructure simplification remove
part of that waste:

| Digital infra reduction | Electricity saved today | Value at $0.10/kWh | CO2 avoided at 445 g/kWh |
|---:|---:|---:|---:|
| 1% | 7 TWh/year | $0.7B/year | 3.1 Mt/year |
| 5% | 35 TWh/year | $3.5B/year | 15.6 Mt/year |
| 10% | 70 TWh/year | $7.0B/year | 31.2 Mt/year |
| 20% | 140 TWh/year | $14.0B/year | 62.3 Mt/year |

At 2030 scale, using a 1,250-1,450 TWh/year digital infrastructure pool, a
5-10% reduction is roughly 62-145 TWh/year, or $6.2B-$14.5B/year at
$0.10/kWh. Higher commercial electricity prices or carbon pricing increase the
economic value. These figures are planning estimates, not protocol guarantees;
they explain the size of the prize for deleting avoidable layers.

Primary data references:

- [IEA Energy and AI report](https://www.iea.org/reports/energy-and-ai/executive-summary): data centre electricity demand, 2024 and 2030.
- [IEA Data centres and data transmission networks](https://www.iea.org/energy-system/digitalisation/data-centres-and-data-transmission-networks): network electricity demand.
- [IEA Electricity 2025 emissions](https://www.iea.org/reports/electricity-2025/emissions): 445 g CO2/kWh 2024 global power intensity.

## Repository Layout

```text
.
├── agents.md              repository engineering rules
├── docs/                  repository structure and engineering intent
├── tools/                 repository maintenance tools
├── tests/                 repository maintenance tests
├── edgerun-metal/         freestanding UEFI runtime and boot profiles
├── edgerun-ui-core/       portable UI scene records and command buffer tests
├── varfont/               variable-font C library and tests
└── .build/                local generated builds, ignored
```

Generated build output must stay out of source directories. Use `.build/` for local CMake builds and `edgerun-metal/build/` for EFI artifacts produced by the metal Makefile.

This is one Git repository. Do not add nested `.git` directories, `.gitmodules`, or submodule gitlinks.

## Required Tools

Use the current system toolchain:

```bash
clang --version
cc --version
ccache --version
mold --version
wat2wasm --version
cmake --version
ninja --version
ctest --version
```

The preferred local build tools are:

- `clang` and `lld` for `edgerun-metal`
- `ccache` when available for repeated C builds
- `mold` when available for hosted Linux test/tool executables
- `wat2wasm` for source-first metal Wasm module fixtures
- `CMake` with `Ninja` for `varfont` and `edgerun-ui-core`
- `ctest --output-on-failure` for tests
- `rg` for repository search

The root Makefile auto-detects `ccache` and `mold`. Override with `CCACHE=`,
`MOLD=`, `HOST_CC=`, or `CC=` when a specific environment needs different tools.
UEFI/EFI links stay on LLVM `lld`; `mold` is only used for hosted binaries.

## Common Commands

Build the default freestanding metal image:

```bash
make
```

Hosted CMake builds are for development, testing, and benchmarking only. Runtime
code stays freestanding and is pulled into `edgerun-metal` directly.

Run all local checks:

```bash
make check
```

Check only repository structure:

```bash
make repo-check
```

Run repository-policy tests:

```bash
make repo-test
```

Build the host-side erwire decoder:

```bash
make erwire-decode
```

The decoder reads raw erwire packets from standard input, prints packet kind/sequence/CRC state, and decodes current log-text and PCI-device payloads. It can also listen directly for firmware UDP packets:

```bash
.build/erwire-decode --udp 9000
```

It is host tooling only; runtime code still emits binary erwire packets without depending on host OS APIs.

Build individual `edgerun-metal` profiles:

```bash
make -C edgerun-metal wasm-modules
make edgerun-smoke
make edgerun-pci
make edgerun-quiet
make -C edgerun-metal mmio
make edgerun-ui
```

Build and test `varfont`:

```bash
cmake --preset dev -S varfont
cmake --build .build/varfont
ctest --test-dir .build/varfont --output-on-failure
```

The root Makefile wraps the same flow:

```bash
make varfont-test
```

Build and test `edgerun-ui-core`:

```bash
cmake -S edgerun-ui-core -B .build/edgerun-ui-core -G Ninja
cmake --build .build/edgerun-ui-core
ctest --test-dir .build/edgerun-ui-core --output-on-failure
```

The root Makefile wraps the same flow:

```bash
make ui-core-test
```

Clean generated local output:

```bash
make clean
```

## Rules

`agents.md` is authoritative for engineering behavior. In short:

- warnings are errors
- unsupported states fail immediately
- generated artifacts are not source
- no hidden fallback paths
- preserve public behavior unless the task explicitly changes it

Keep new docs and commands aligned with those rules.

Additional intent documents:

- [Repository structure](docs/repository-structure.md)
- [Engineering practices](docs/engineering-practices.md)
- [Relay architecture](docs/relay-architecture.md)
- [Coherent system milestones](docs/coherent-system-milestones.md)
