# Engineering Practices

Purpose: define how changes are made, verified, and documented in this repository.

Intention: make repository rules executable where possible and explicit where human judgment is required.

## Change Requirements

Every non-generated file must have a clear purpose:

- Source files implement one bounded responsibility.
- Tests describe the behavior or invariant they protect.
- Tools state their purpose and intention near the top of the file.
- Documentation explains decisions that are not obvious from code or command names.

Generated output is not source and must not be tracked.

## Verification

Run the full local check before committing:

```bash
make check
```

`make check` verifies:

- repository structure through `tools/repo-check.c`
- repository-policy tests through `tests/repo-check-tests.sh`
- the `edgerun-metal` OS image builds with warnings as errors
- `edgerun-ui-core/varfont` tests through the repository-owned `tools/er-build` runner
- `edgerun-ui-core` builds with CMake and Ninja
- `edgerun-ui-core` tests pass through CTest
- `edgerun-crypto` tests through the repository-owned `tools/er-build` runner

## Tooling

Use current, deterministic tools already available on the machine:

- `rg` for search
- `clang` and `lld` for freestanding EFI builds
- `ccache` for repeat local C builds when available
- `mold` for hosted Linux test/tool links when available; do not use it for EFI links
- `CMake` and `Ninja` for `edgerun-ui-core` and hosted demos
- `ctest --output-on-failure` for test execution
- `git status --short --branch` before and after changes

The Makefile wrappers discover `ccache` and `mold` automatically and keep the
tool selections overridable through make variables. `tools/er-build` is the
repository-owned build runner for migrated targets; prefer adding new repository
tooling and hosted test orchestration there instead of adding new shell or CMake
orchestration.

## Test Policy

Tests must be added with behavior changes and with new repository tooling. If code cannot be unit-tested directly because it targets UEFI or hardware, the fallback check is not silent acceptance: add the strongest deterministic build or policy check available and document the remaining hardware-only verification path.

## Documentation Policy

Keep documentation close to the decision:

- all first-party workflow, commands, and runtime-area summaries belong in root `README.md`
- repository-wide rules belong in `AGENTS.md`
- structure and engineering intent belong in `docs/`
- detailed architecture belongs in named `docs/` files, not nested READMEs

When a workflow changes, update the command wrapper and documentation in the same change.
