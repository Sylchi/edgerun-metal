# agents.md

## Core rules

- No fallbacks.
- Warnings are errors.
- Errors are fatal.
- No shortcuts.
- No external dependencies.
- Production code must be freestanding and must not depend on host libc.
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
- Multiple agents may work in this repository at the same time.
- Stay inside the bounds of the assigned task and owned files.
- Use `main` only. Do not create, switch to, or continue work on feature branches unless the user explicitly asks for a temporary archival branch.
- Commit and push finished work directly to `main`; do not leave implementation work stranded on side branches.

## Enforcement

- Fail fast on unsupported, uncertain, or partial states.
- Do not log, suppress, or downgrade warnings.
- Do not catch and continue; return/abort immediately on failure.
- Do not introduce compatibility layers, shims, or fallback paths.
- Avoid speculative, dynamic, or hidden behavior.
- Prefer editing existing code to simplify/remove duplication instead of appending behavior.
- Preserve existing public behavior and interfaces unless explicitly instructed.
- Keep implementations minimal, explicit, deterministic, and dependency-free.
- Use project-owned primitives for memory, strings, math, and I/O in production paths; host libc is allowed only inside deterministic host-side tests and build tools.
- Keep root documentation and command wrappers current when workflow changes.
- Add tests for new repository tooling and for behavior changes when deterministic tests are possible.
- Document the purpose and intention of new tools, tests, and top-level structure.

## Repo inspection annotations

- `tools/repo-inspect.c` supports reasoned annotations for intentional false positives, including duplicate-block findings.
- Use `//@optimizer-ignore reason` on the exact line, `//@optimizer-ignore-function reason` immediately before a function definition, or `//@optimizer-ignore-constant reason` immediately before a constant or macro block.
- Every annotation must include a concrete reason; bare optimizer-ignore markers are misuse.
- Prefer fixing real duplication, CPU-cost, magic-number, or string-indexing findings. Use annotations only when the reported shape is required by a protocol, ABI, hardware register layout, cryptographic schedule, SIMD lane packing, or another explicit invariant.
- Do not use annotations to hide incomplete work, accidental complexity, unclear ownership, or missing tests.

## Progress checks

- Use `make repo-progress` for the standard `edgerun-ui-core` iteration check instead of running the individual progress commands by hand.
- `make repo-progress` runs status, scoped diff stats, scoped whitespace checks, rebuilds `repo-inspect`, runs `repo-inspect` for the scope, and runs the scope's test target.
- For other scopes, pass `REPO_PROGRESS_SCOPE=<path>` and, when the scope is not one of the known defaults, `REPO_PROGRESS_TEST=<make-target>`.
- Use `./tools/repo-progress.sh --print-plan <scope> [test-target]` to inspect the exact command sequence without running it.

## Multi-agent safety

- Assume every agent shares the same working tree and current branch.
- Do not switch branches during normal work. Branch switching moves all agents sharing this checkout and can hide or strand their changes.
- Treat unrecognized local changes as another agent's work.
- Do not overwrite, revert, reformat, move, or delete another agent's files unless explicitly instructed.
- Do not run destructive Git commands such as `git reset --hard`, `git checkout --`, `git clean`, or broad restore operations.
- Do not use `git add -A` or broad staging when unrelated changes are present; stage only owned paths.
- Check `git status --short --branch` before edits, before staging, and before committing.
- Before starting work, verify the checkout is on `main`; if it is not, stop and report the branch rather than switching automatically.
- If a needed change overlaps another agent's work, stop and coordinate instead of resolving by force.
- Keep commits scoped to one coherent task and mention any intentionally touched shared files.
