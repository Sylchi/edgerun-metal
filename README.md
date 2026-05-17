# edgerun-c

This repository contains three C projects:

- `edgerun-metal`: a freestanding x86_64 UEFI runtime that boots as `BOOTX64.EFI` and runs embedded Wasm modules with native hostcalls.
- `varfont`: a zero-dependency variable-font renderer library with parser, shaping, rasterization, atlas, and test coverage.
- `edgerun-ui-core`: the C port of EdgeRun's platform-neutral UI scene command buffer.

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
