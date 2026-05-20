# AGENTS.md

## Core Rules

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

## Friction Prevention

- Treat the implementation as the source of truth. Read the actual code before changing docs, roadmap text, or architecture descriptions.
- When the user points to a reference implementation, screenshot, copied text, or another repo, inspect that reference directly and port the relevant behavior instead of approximating it.
- Do not invent parallel systems, alternate terminology, or new architecture when an existing project concept already covers the task.
- For broad prompts such as `continue`, `improve`, `fix`, or `get to work`, choose the highest-impact concrete task, state that task briefly, and execute it through verification.
- Material progress means removing wrong code, reducing real complexity, improving a working path, or making a visible/testable behavior better. Avoid tiny cosmetic edits unless they unblock a larger goal.
- Prefer consolidation and deletion over adding another layer. If two files, docs, APIs, or concepts conflict, reconcile them to one canonical version.
- If the task is architectural, update code and tests first; update documentation only after the implemented behavior is clear.
- If the task is documentation, verify the documentation against current code before editing and remove stale/conflicting claims instead of expanding them.
- If the user corrects direction, treat the correction as higher priority than earlier plans and re-read the relevant code before continuing.
- Do not keep retrying a failing build, test, or QEMU run without changing the hypothesis. Capture the specific failure, inspect the responsible code, then make a targeted fix.
- This laptop's USB bus is flaky during hardware bring-up. If USB storage or serial devices appear wedged or report impossible state, reset the affected root hub before changing repo code or assuming the target board failed.
- For the current Pi USB bring-up station, the affected root hub is owned by xHCI PCI device `0000:c3:00.4` and carries USB bus 007/008. Reset it with `sudo sh -c 'echo 0000:c3:00.4 > /sys/bus/pci/drivers/xhci_hcd/unbind; sleep 3; echo 0000:c3:00.4 > /sys/bus/pci/drivers/xhci_hcd/bind'`.
- After a Pi USB root-hub reset, re-run `lsusb` and `chown` the new `/dev/bus/usb/BBB/DDD` Broadcom boot node before running the non-root boot command.

## UI And Visual Work

- UI work must be reference-driven. Use the provided screenshot, reference repo, component source, theme tokens, icon set, and font assets as concrete inputs.
- Do not hand-wave visual parity. Compare the rendered result against the reference and list the remaining visual differences before claiming the task is done.
- Use the actual component system and renderer paths that are meant to ship. Do not create a separate demo-only surface that bypasses the real UI architecture.
- For shadcn-style work, port the component structure, spacing, states, icons, and theme values from the canonical source instead of making approximate lookalikes.
- Run the relevant render path or screenshot/QEMU check when visual output is changed. If visual verification cannot run, report that explicitly.

## Enforcement

- Fail fast on unsupported, uncertain, or partial states.
- Do not log, suppress, or downgrade warnings.
- Do not catch and continue; return or abort immediately on failure.
- Do not introduce compatibility layers, shims, or fallback paths.
- Avoid speculative, dynamic, or hidden behavior.
- Prefer editing existing code to simplify or remove duplication instead of appending behavior.
- Preserve existing public behavior and interfaces unless explicitly instructed.
- Keep implementations minimal, explicit, deterministic, and dependency-free.
- Use project-owned primitives for memory, strings, math, and I/O in production paths; host libc is allowed only inside deterministic host-side tests and build tools.
- Keep root documentation and command wrappers current when workflow changes.
- Add tests for new repository tooling and for behavior changes when deterministic tests are possible.
- Document the purpose and intention of new tools, tests, and top-level structure.

## Repo Inspection Annotations

- `tools/repo-inspect/` supports reasoned annotations for intentional false positives, including duplicate-block findings.
- Use `//@optimizer-ignore reason` on the exact line, `//@optimizer-ignore-function reason` immediately before a function definition, or `//@optimizer-ignore-constant reason` immediately before a constant or macro block.
- Every annotation must include a concrete reason; bare optimizer-ignore markers are misuse.
- Prefer fixing real duplication, CPU-cost, magic-number, or string-indexing findings.
- Use annotations only when the reported shape is required by a protocol, ABI, hardware register layout, cryptographic schedule, SIMD lane packing, or another explicit invariant.
- Do not use annotations to hide incomplete work, accidental complexity, unclear ownership, or missing tests.


## Multi-Agent Safety

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
