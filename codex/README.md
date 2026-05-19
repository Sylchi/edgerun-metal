# edgerun-c

`edgerun-c` is a dependency-free C workspace client for prompting Codex against
an in-memory repo snapshot, staging repo edits in memory, and committing only
verified useful work.

It does not mutate the repository while you search, read, or propose changes.
Agent prompts receive host-generated repository status and workflow context
automatically. The first agent turn includes `AGENTS.md`, known `repo-progress`
plans, a compact repository tree snapshot, and a running-process snapshot so the
model can start work without spending tool calls on routine orientation. Prompt
mode runs as a progress loop: if a model turn ends with no pending proposals, the
host feeds that back and asks the model to make a concrete change instead of
returning a review. When an agent finishes with pending proposals, the host
writes only those proposed paths, runs the matching `repo-progress` scope checks,
creates a git checkpoint commit only if verification passes, and then asks the
user for the next prompt. At each checkpoint boundary, the host compacts the
assistant exchange and tool results into a carry-forward context item for the
next user prompt. Enter `quit` or `exit` at the `codex user>` prompt when you
have enough progress.

Terminal output uses ANSI color when stdout or stderr is a terminal. Set
`NO_COLOR=1` or `EDGERUN_C_COLOR=0` to disable color. Interactive reads apply
lightweight C syntax highlighting for `.c` and `.h` files. Agent responses render
Markdown structure, inline code, links, and fenced `c`, `h`, `md`, and `markdown`
blocks with lightweight ANSI highlighting, and agent turns end with a host-side
summary of turns, tool calls, checkpoints, review-only turns, proposals, and
verified commit status. Checkpoint summaries are retained for the next prompt
without replaying the full transcript.

Agent mode reads local Codex auth from `CODEX_HOME/auth.json` or
`~/.codex/auth.json`, uses `CODEX_TUI_MODEL` when set, and otherwise defaults to
`gpt-5.5`.

The C program has no linked third-party dependencies. HTTPS streaming is handled
by the system `curl` command because the C standard library has no TLS client.

## Build

```sh
make -C codex
```

The binary is written to `.build/codex`.

## Run

```sh
.build/codex /path/to/repo
```

If no path is supplied, the current directory is used.

## Prompt Codex

```sh
.build/codex --prompt "inspect edgerun-c and explain what it can do"
```

or choose a root explicitly:

```sh
.build/codex --root /path/to/repo --prompt "find the Codex client entry point"
```

The built-in agent tools are:

- `project_status`
- `repo_rules`
- `search_code`
- `read_code`
- `propose_change`
- `verify_scope`
- `commit_verified`

The model can stage complete-file replacements with `propose_change`. It should
not ask for routine `git status`, build, or test commands: the host supplies
status context and performs scoped verification automatically.

## Commands

- `help`
- `stats`
- `search <text> [limit]`
- `read <path> [start_line] [max_lines]`
- `propose <path>` then enter full file content, ending with a line containing only `.end`
- `show <path>`
- `diff [path]`
- `discard <path>`
- `discard --all`
- `commit`
- `commit-verified`
- `quit`

`commit` is deliberately simple: it writes the full staged file contents to disk.
It does not run tests, formatters, hooks, or `git commit`.

`commit-verified` writes pending proposals, runs `tools/repo-progress.sh` for
the scopes touched by those proposals, stages only the proposed paths, and runs
`git commit` only after every verification step passes.
