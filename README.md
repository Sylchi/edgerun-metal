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
├── edgerun-metal/         UEFI metal runtime, netboot tools, systemd units
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
cmake --version
ninja --version
ctest --version
```

The preferred local build tools are:

- `clang` and `lld` for `edgerun-metal`
- `CMake` with `Ninja` for `varfont` and `edgerun-ui-core`
- `ctest --output-on-failure` for tests
- `rg` for repository search
- `socat` or `nc` for UDP boot log capture

## Common Commands

Build the default projects:

```bash
make
```

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

Build individual `edgerun-metal` profiles:

```bash
make edgerun-smoke
make edgerun-pci
make edgerun-quiet
make -C edgerun-metal mmio
```

Listen for real-hardware UDP boot logs:

```bash
make log-listen
```

Install the listener as an always-on systemd service:

```bash
make install-log-listen
make logs-log-listen
make status-log-listen
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
