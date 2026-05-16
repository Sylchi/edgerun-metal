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
├── edgerun-metal/         UEFI metal runtime and support tooling
├── varfont/               variable-font renderer library
└── .build/                ignored local build output
```

## Project Areas

`edgerun-metal/` exists to build the EFI runtime, embedded Wasm host, real-hardware boot path, netboot tooling, and systemd service helpers. Its generated EFI artifacts are allowed only under `edgerun-metal/build/`, which is ignored.

`varfont/` exists to build and test the variable-font renderer. Its source, tests, public headers, examples, fonts, and CMake configuration are tracked. Its generated build output must use `.build/varfont/`, not `varfont/build/`.

`tools/` exists for deterministic repository-maintenance commands that are shared by the Makefile and tests. Tools must state their purpose at the top of the file.

`tests/` exists for repository-level tests that do not belong to either C project. Tests must be runnable from `make check`.

`docs/` exists for cross-project engineering intent. Project-specific usage remains in each project README.

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
