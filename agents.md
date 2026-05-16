# agents.md

## Core rules

- No fallbacks.
- Warnings are errors.
- Errors are fatal.
- No shortcuts.
- No external dependencies.
- No ambiguity.
- Tests must cover 100% of code.
- Code must be deterministic.
- No monolithic files.
- Use switch statements and constants for control and value selection.
- No magic numbers.
- Eliminate repetition; refactor repeated logic into utility functions.
- Consolidating and removing code is preferred over adding new code.
- No regressions.
- Generated build artifacts must stay untracked.
- Use `.build/` for local CMake output.
- Keep this as one Git repository; nested `.git` directories, `.gitmodules`, and submodule gitlinks are not allowed.

## Enforcement

- Fail fast on unsupported, uncertain, or partial states.
- Do not log, suppress, or downgrade warnings.
- Do not catch and continue; return/abort immediately on failure.
- Do not introduce compatibility layers, shims, or fallback paths.
- Avoid speculative, dynamic, or hidden behavior.
- Prefer editing existing code to simplify/remove duplication instead of appending behavior.
- Preserve existing public behavior and interfaces unless explicitly instructed.
- Keep implementations minimal, explicit, deterministic, and dependency-free.
- Keep root documentation and command wrappers current when workflow changes.
- Add tests for new repository tooling and for behavior changes when deterministic tests are possible.
- Document the purpose and intention of new tools, tests, and top-level structure.
