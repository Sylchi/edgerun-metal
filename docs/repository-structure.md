# Repository Structure

Purpose: document why each top-level path exists so new files have a clear home.

Intention: keep the repository source-first, with generated output ignored and no nested Git repositories.

## Top-Level Paths

```text
.
├── README.md              project overview and command entrypoints
├── Makefile               root command wrapper for build, test, check, and clean
├── agents.md              engineering rules enforced by humans and tooling
├── docs/                  repository-level engineering documentation
├── tools/                 repository maintenance tools
├── tests/                 repository maintenance tests
├── edgerun-crypto/        freestanding crypto used by the runtime
├── edgerun-metal/         UEFI OS runtime and support tooling
├── edgerun-ui-core/       portable UI scene/component/input runtime
├── varfont/               variable-font renderer used by UI text paths
└── .build/                ignored local build output
```

## Runtime Areas

This repository is one EdgeRun OS and runtime project. The top-level runtime
directories are intentionally split by responsibility so the OS image, UI,
font, crypto, storage, relay, and device paths can compose without becoming one
monolithic source tree.

`edgerun-metal/` exists to build the freestanding EFI OS runtime, embedded Wasm host, runtime-owned device paths, and runtime-owned binary telemetry protocol. Its generated EFI artifacts are allowed only under `edgerun-metal/build/`, which is ignored.

`edgerun-crypto/` exists to hold freestanding cryptographic primitives shared by the runtime, tools, and deterministic tests. It must not depend on the EFI runtime or provider boundaries owned by a higher layer. Generated build output must use `.build/edgerun-crypto/`.

`edgerun-ui-core/` exists to port the Rust `edgerun-ui-core` platform-neutral UI layer to C for the OS runtime. It owns scene records, component contracts, input state, layout nodes, render budgets, and deterministic tests. Generated build output must use `.build/edgerun-ui-core/`.

`varfont/` exists to provide the freestanding variable-font renderer used by `edgerun-ui-core` and the metal UI path. Its source, tests, public headers, examples, fonts, and CMake configuration are tracked. Its generated build output must use `.build/varfont/`, not `varfont/build/`.

`tools/` exists for deterministic repository-maintenance commands that are shared by the Makefile and tests. Tools must state their purpose at the top of the file.

`tests/` exists for repository-level tests that do not belong to either C project. Tests must be runnable from `make check`.

`docs/` exists for repository-wide OS/runtime engineering intent. Root
`README.md` is the only first-party README; area-specific usage belongs in root
README sections or named `docs/` files, not nested READMEs.

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
