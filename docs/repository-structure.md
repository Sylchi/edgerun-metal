# Repository Structure

Purpose: document why each top-level path exists so new files have a clear home.

Intention: keep the repository source-first, with generated output ignored and no nested Git repositories.

## Top-Level Paths

```text
.
├── README.md              project overview and command entrypoints
├── AGENTS.md              engineering rules enforced by humans and tooling
├── Makefile               root command wrapper for build, test, check, and clean
├── codex/                 hosted Codex support library and tests
├── docs/                  repository-level engineering documentation
├── edgerun-crypto/        freestanding crypto used by the runtime
├── edgerun-metal/         UEFI OS runtime and support tooling
├── edgerun-ui-core/       portable UI scene/component/input runtime
├── firmware/              firmware-facing runtime source areas
├── include/               repository-wide freestanding C headers
├── tests/                 repository maintenance tests
├── third_party/           vendored source kept inside this repository
├── tools/                 repository maintenance tools
└── .build/                ignored local build output
```

## Runtime Areas

This repository is one EdgeRun OS and runtime project. The top-level runtime
directories are intentionally split by responsibility so the OS image, UI,
font, crypto, storage, relay, and device paths can compose without becoming one
monolithic source tree.

`edgerun-metal/` exists to build the freestanding EFI OS runtime, embedded Wasm
host, runtime-owned device paths, and runtime-owned binary telemetry protocol.
Its generated EFI artifacts are allowed only under `edgerun-metal/build/`, which
is ignored.

`edgerun-crypto/` exists to hold freestanding cryptographic primitives shared by
the runtime, tools, and deterministic tests. It must not depend on the EFI
runtime or provider boundaries owned by a higher layer. Generated build output
must use `.build/edgerun-crypto/`.

`edgerun-ui-core/` exists to port the Rust `edgerun-ui-core` platform-neutral UI
layer to C for the OS runtime. It owns scene records, component contracts, input
state, layout nodes, render budgets, host preview tooling, deterministic tests,
and the `edgerun-ui-core/varfont/` text renderer. Generated build output must
use `.build/edgerun-ui-core/`, `.build/edgerun-ui-core-*`, or `.build/varfont/`
as selected by the root Makefile.

`edgerun-ui-core/varfont/` exists to provide the freestanding variable-font
renderer used by `edgerun-ui-core` and the metal UI path. Its source, tests,
public headers, examples, fonts, and CMake configuration are tracked there so
UI text has one owner. Its generated build output must use `.build/varfont/`,
not `edgerun-ui-core/varfont/build/`.

`codex/` exists for the hosted Codex support code and tests. It is built through
the root Makefile and must remain part of this repository, not a nested checkout.

`firmware/` exists for firmware-facing runtime code that is source input to the
EdgeRun runtime, not generated firmware output.

`include/` exists for repository-wide freestanding headers shared across runtime
areas. Area-specific public headers should stay under that area's `include/`
directory unless they are intentionally shared at repository scope.

`third_party/` exists for vendored source that is intentionally tracked inside
this repository. Vendored code must not introduce nested `.git` directories,
`.gitmodules`, or generated build output.

`tools/` exists for deterministic repository-maintenance commands that are
shared by the Makefile and tests. Tools must state their purpose at the top of
the file.

`tests/` exists for repository-level tests that do not belong to a runtime area.
Tests must be runnable from `make check` or an explicit root Makefile target.

`docs/` exists for repository-wide OS/runtime engineering intent. Root
`README.md` owns the project overview and command entrypoints; detailed
decisions belong in named `docs/` files, not nested READMEs.

## Repository Boundary

This is one Git repository. The following are intentionally rejected:

- nested `.git` directories
- `.gitmodules`
- Git submodule gitlinks
- tracked generated build output

Run:

```bash
make repo-check
```
