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

The workspace snapshot also builds a deterministic in-memory summary index for
text source files. The agent can call `summarize_code` to get file purpose,
size/hash, includes, visible symbols, and related files by include/stem
relationship for matching paths or topics before falling back to full
`read_code` calls. The index is rebuilt when the workspace is reloaded after
verified commits.

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

## Zsh shortcut

Source the zsh helper once from your shell startup file:

```zsh
source /path/to/repo/codex/edgerun-c.zsh
```

After that, call the graphical Codex workspace with the short canonical `c`
command:

```zsh
c inspect edgerun-c and explain what it can do
c --root /path/to/repo find the Codex client entry point
```

The helper builds `.build/codex` and `.build/edgerun-ui-core-sdl/er_ui_sdl_shell`
when either binary is missing or stale. Use `c term ...` for terminal prompt
mode, `c repl` for the interactive workspace REPL, or `c raw ...` to pass exact
arguments to the compiled binary.

## Run

Start the interactive workspace REPL through the zsh helper:

```zsh
c repl /path/to/repo
```

or run the compiled binary directly:

```sh
.build/codex /path/to/repo
```

If no path is supplied, the current directory is used.

## Prompt Codex

The graphical workspace is normally invoked through the zsh helper:

```zsh
c inspect edgerun-c and explain what it can do
c --root /path/to/repo find the Codex client entry point
```

The terminal prompt mode is still available when needed:

```zsh
c term inspect edgerun-c and explain what it can do
c term --root /path/to/repo find the Codex client entry point
```

The built-in agent tools are:

- `project_status`
- `repo_rules`
- `summarize_code`
- `search_code`
- `read_code`
- `propose_change`
- `verify_scope`
- `commit_verified`

The model can stage complete-file replacements with `propose_change`. It should
not ask for routine `git status`, build, or test commands: the host supplies
status context and performs scoped verification automatically.

## Improvement opportunities

The current client already covers the core in-memory edit and verified-commit
loop. The highest-impact next improvements are:

- Decode `pclose` statuses from the streaming `curl` transport before reporting
  failures, matching the existing `command_status_code` helper used by command
  execution. This would turn raw wait statuses into actionable exit codes.
- Consolidate the duplicated streaming request setup in `edgerun_c.c` and
  `edgerun_c_agent.c` so header construction, temporary body cleanup, and SSE
  parsing have one implementation path.
- Add focused self-tests for SSE item ownership and response rendering. The
  current self-test covers fence-language detection, but not streamed tool item
  parsing, output item lifetime, or partial-line renderer flushing.
- Split the agent wrapper into smaller files once the duplicated stream path is
  consolidated. `edgerun_c_agent.c` currently includes the base implementation
  and overrides selected behavior, which makes ownership harder to inspect.

## Commands

- `help`
- `stats`
- `summarize [query] [limit]`
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
