# EdgeRun Compiler Roadmap

This compiler is the path for dropping the heavy Zig toolchain from normal
EdgeRun app authoring while keeping a familiar Zig-shaped source surface.

The target is not full Zig. The target is EdgeRun source: a small deterministic
language that lowers to the canonical formats already present in this repo.

## Ground Rules

- Keep WASM as the executable app format.
- Keep the EdgeRun WASM interpreter as the execution and verification path.
- Keep canonical `edgerun-object` bytes as the storage and transfer boundary.
- Keep UI output on the existing component/object path:
  - `ERUI001` records from `src/ui_codec.zig`.
  - component requirements from `src/ui/components/Codec.zig`.
  - component registrations from `src/ui/components/Component.zig`.
  - tree composition through `StackTree`, `SlotTree`, `TreeCodec`, and
    `src/ui_resolver.zig`.
- Do not introduce a new UI model, object model, runtime, VM, or fallback
  compiler.
- Unsupported syntax is a fatal compiler error.

## Current State (May 2026)

Two implementations exist:

### Zig frontend (`compiler/zig/src/`)
Full-featured and passing all tests. Supports:
- Multi-statement function bodies
- Local const/var declarations
- Assignment and indexed assignment
- `while` loops
- `if`/`else` expressions
- `@import` between .er workspace files
- Linear memory access (state variables, arrays)
- UI declarations (stack, row, text, button, input, badge)
- Self-hosting test: compiled .er app compiles its own workspace
- Embedded compiler WASM binary for recursive self-hosting

**Goal**: bootstrap tool — to be replaced by the ASM port.

### ASM port (`asm/x86_64/wasm_compiler_source.asm`, `wasm_compiler.asm`)
Self-hosted port in x86_64 assembly DSL. 3 test suites pass (`test-wasm-compiler`:
8 tests, `test-wasm-compile-and-run`, `test-wasm-compile-minimal`).

**Supported**:
- Tokenizer: identifiers, keywords, integers, floats, strings, chars, builtins, punctuation
- `const` declarations (top-level, decimal only)
- `var` declarations (top-level, scanned to semicolon)
- `export fn` / `fn` parsing with params
- Single `return <expr>;` function bodies
- Expressions: `+ - * / % == != < <= > >=`, parenthesized, function calls
- `if`/`else` expressions
- `true`/`false` literals
- Const and param lookup in expressions
- WASM binary emission (6 sections: type, function, memory, export, start, code)

**Missing vs Zig frontend**:

| Feature | Status | Priority |
|---------|--------|----------|
| Multi-statement body loop | Stub — currently hardcodes `return <expr>;` only | High |
| `while` loops | Tokenized, no compile function | High |
| Local `const` in function bodies | Not implemented | High |
| Local `var` + `=` assignment | Not implemented | High |
| State variable load/store | Not implemented (no `@intFromPtr`/`@intFromEnum`) | High |
| Indexed assignment (`arr[i] = x`) | Not implemented | Medium |
| `@import` / multi-file workspace | Not implemented | Medium |
| `@intCast`, `@intFromPtr`, `@intFromEnum` | Not implemented | Medium |
| Const arrays (`[N]u8`) | Not implemented | Medium |
| UI declaration lowering | Not implemented | Medium |
| `else if` chains | Not implemented | Low |
| `break`/`continue` | Not implemented | Low |
| `for` loops | Not implemented | Low |
| `%` modulo operator in expressions | Done | — |
| Signed LEB128 emission | Done | — |
| Keyword tokenizer lookup | Done | — |

### Known bugs in ASM compiler
1. **yasm encoding anomaly**: `movzx ebx, byte [rdi + rdx]` assembles to
   `movzx eax, byte [rdi + r10]` — wrong destination register and wrong index
   register due to spurious REX.X prefix (`0x42`). Only triggers in certain
   contexts within `wasm_compiler.asm`. Workaround: avoid `[base + index]` where
   both are 64-bit with a 32-bit destination and the index is `rdx`.
2. **No diagnostics channel**: compile errors currently return a status code
   with no human-readable error message. The `diagnostic_ptr`/`diagnostic_len`
   ABI exists but is not populated by the ASM compiler.

## Milestones

### 1. EdgeRun-owned source mode (DONE)
- Accept `.er` workspace roots.
- Keep current Zig-like export syntax for the narrow supported subset.
- Do not call Zig `Ast` or `AstGen` for `.er` roots.
- Emit the same successor WASM path as the current compiler probe.

**Status**: Complete in both Zig and ASM compilers.

### 2. Replace string-pattern lowering with a typed EdgeRun parser (DONE)
- Tokenize source deterministically from caller-owned memory.
- Parse only supported declarations.
- Preserve current zero-arg integer export behavior.
- Reject imports, comptime, generics, arbitrary pointer code, and ambient
  host access.

**Status**: Complete in both compilers at the declaration/expression level.

### 3. Multi-statement function bodies and control flow (IN PROGRESS — next priority)
- Add `while` loop compilation
- Add multi-statement body loop (statements separated by `;`)
- Add local `const` inside function bodies
- Add local `var` + assignment (`x = expr;`)
- Wire these into `source_parse` → `handle_fn` instead of single-return body

**Target**: The ASM compiler can compile `er_sum_to`, `er_accumulate`,
`er_fill_byte`, etc. from `wasm_compiler_runner_test.zig`.

**Verification**: Compile these sources through the ASM compiler, then run
through the WASM interpreter and verify results.

### 4. Lower UI declarations to existing component objects
- Map source component declarations to `ui_codec.RecordKind`.
- Use each component's `writeRecord` behavior as the canonical contract.
- Emit leaf component objects with shared component requirements.
- Emit composed UI through existing tree objects.

**Status**: Done in Zig frontend. **Not started** in ASM port.

### 5. State and memory access
- Linear memory variable load/store
- `@intFromPtr`, `@intCast` builtins
- Array index expressions and assignments

**Status**: Done in Zig frontend. **Not started** in ASM port.

### 6. Import resolution and multi-file workspaces
- `@import` directive parsing and workspace file loading
- Cross-file function reference resolution
- Cycle detection and rejection

**Status**: Done in Zig frontend. **Not started** in ASM port.

### 7. Bind compiler output to canonical app artifacts
- Return or store canonical source/workspace object identity.
- Return or store canonical UI object ids.
- Return WASM bytes as a `WasmAppImage`-ready artifact.
- Keep allocation, manifest, and receipt binding on existing app paths.

**Status**: Done in Zig frontend. **Not started** in ASM port.

### 8. Self-host the small compiler
- Build the EdgeRun compiler as WASM.
- Run it through the WASM interpreter.
- Keep the host Zig build only as bootstrap and verification tooling.

**Status**: Done in Zig frontend (test `"compiled app compiles its own
workspace and reproduces wasm hash"` passes). **Not started** in ASM port.

## Current First Slice

The first slice is deliberately small: `.er` roots compile through an
EdgeRun-owned source analyzer instead of Zig AST/ZIR, while reusing the current
WASM emitter and narrow export lowering. This proves the direction without
inventing a parallel runtime. **DONE**.

## Next Concrete Step

Add multi-statement body support with `while` loops to the ASM parser.

**Why this matters**: Currently function bodies are limited to
`return <expr>;` — no program can loop, branch with side effects, or
declare local state. This blocks every algorithmic test.

**Design**: Replace the single `return`-body hack in `handle_fn` with a
`compile_body` loop that processes statements:
- `const x = expr;` → evaluate and store in local table
- `var x: T = expr;` → allocate local, `local.set`
- `x = expr;` → `local.set` for locals, `i32.store` for state
- `while (cond) { body }` → `block/loop/br_if/br/end/end`
- `return expr;` → compile expr, `end`
- `if (cond) { then } else { else }` → (already works as expression)
- `arr[i] = expr;` → `i32.const base, expr, i32.add, i32.store8`

**Blocks**: The yasm `movzx` encoding bug must be avoided.
