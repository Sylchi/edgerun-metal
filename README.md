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
