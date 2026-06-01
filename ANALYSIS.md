# Performance & Consolidation Analysis

Updated: 2026-06-01

Verified current baseline:

- `./build.sh test` passes.
- `./build.sh kernel` builds `.build/kernel/kernel.elf` and `.build/kernel/kernel.bin`.
- Older notes about `test-wasm-compiler` hanging or TPM hash failures are historical,
  not current blockers.

This file tracks consolidation targets. Treat line counts as directional because
multiple agents are actively changing the tree.

## Performance Optimizations

### 1. WASM Interpreter: Inline Stack Operations (2-3× speedup)

**Files:** `kernel/x86_64/wasm/wasm_constants.inc`, `wasm_exec.asm`

Every WASM binary/compare/shift op currently makes 3 function calls (pop, pop, push),
each with full frame push/pop/ret (~15 cycles each → ~50 cycles per opcode).

Inlining eliminates 147 call sites in macro-generated handlers. Combined with
register-cached dispatch state, compute-bound WASM workloads see 2-3× improvement.

### 2. Power-of-2 Division → Shift/And

| File | Line | Divisor | Replacement | Impact |
|------|------|---------|-------------|--------|
| `blake3.asm` | 752, 800, 973 | 1024 (2^10) | `shr 10` + `and 1023` | Hot path |
| `local_cell.asm` | ring slot math | 64 (2^6) | `and 63` | Landed; keep regression coverage |
| `render_ir.asm` | 849 | 8 (2^3) | `shr 3` + `and 7` | Validation |
| `render_ir.asm` | 831, 867, 885 | 15, 9, 6 | Not power-of-2; keep `div` | No change |

### 3. Future: WASM JIT As Default

The self-hosted WASM JIT already exists. The source-to-WASM compiler is now
starting as host-side ASM emitter primitives under `kernel/x86_64/wasm/`.
Making JIT execution the default after validation gives 10-50x speedup on
compute-heavy workloads.

## Consolidation Opportunities

### Unification Path

| Area | Direction | Stop Condition |
|------|-----------|----------------|
| App compiler | Keep moving source/TSX parsing and WASM emission into `kernel/x86_64/wasm/` | Kernel can compile the app-authoring subset without Zig |
| Signing guest | Replace Cargo-built signing WASM in `cmd_signing_wasm` with repo-owned compiler/runtime output | `./build.sh kernel` has no Cargo dependency |
| DA/app bridge | Route all app UI updates through local cells and DA surface messages | No parallel browser/native-only app runtime contract |
| Object authority | Reconcile Zig object/grant concepts with ASM object serialization and route enforcement | Kernel checks the same requirements app code declares |
| Hardware bring-up | Keep one explicit path per device class | Probe-only placeholders are either completed or removed |

### Kernel-Side (~500 lines)

| Area | Est. Savings | Description |
|------|:---:|-------------|
| WASM memory load/store handlers | ~150 | 19 handlers share identical skeleton; macro-ize |
| LEB128-read preamble | ~105 | 15 sites copy 9-line identical preamble |
| Wait-loop consolidation | ~110 | 7 poll-with-timeout functions across 3 drivers |
| Integer div/rem handlers | ~60 | 8 handlers share preamble pattern |
| Unused/underused DSL macros | ~70 | 14 macros in macros.inc are never used |
| I2C HID prologues | ~15 | 3 identical function prologues |
| **Total** | **~510** | |

### App-Side (~2,400 lines)

| Area | Est. Savings | Description |
|------|:---:|-------------|
| Duplicate app/route surfaces | ~1,500 | Remove exact-copy app entry points or make one canonical owner |
| Component serialization boilerplate | ~550-825 | 55+ components share identical toObject/writeRecord/fromView |
| `encodedId` wrappers | ~50 | 7 near-identical wrappers |
| `Point` struct | ~30 | 4 identical definitions |
| Render backend duplicated helpers | ~30 | makeRgbaTexture duplicated |
| **Total** | **~2,400** | |

### SVG Assets

5,093 SVG files in `app/src/assets/` (~100K+ lines of markup).
Consolidate to binary sprite atlas or Zig data arrays.
