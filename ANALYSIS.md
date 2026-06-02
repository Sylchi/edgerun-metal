# Performance & Consolidation Analysis

Updated: 2026-06-02

Verified current baseline:

- `.build/host/er_build test-list` and `test-registry` emit the owned test registry.
- `.build/host/er_build x86-objects` builds the registry-owned x86 object set.
- Older notes about `test-wasm-compiler` hanging or TPM hash failures are historical,
  not current blockers.

This file tracks consolidation targets. Implementation and owned registry objects
are authoritative; estimates are intentionally omitted when they would invite
stale accounting.

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
| Signing path | Keep Ed25519 signing in host-side ASM and remove stale WASM guest hooks | No signing-specific Zig/WASM build target or embedded guest remains |
| DA/app bridge | Route all app UI updates through local cells and DA surface messages | No parallel browser/native-only app runtime contract |
| Object authority | Reconcile Zig object/grant concepts with ASM object serialization and route enforcement | Kernel checks the same requirements app code declares |
| Hardware bring-up | Keep one explicit path per device class | Probe-only placeholders are either completed or removed |

### Kernel-Side

- Consolidate repeated WASM memory load/store handlers.
- Consolidate repeated LEB128-read preambles.
- Consolidate poll-with-timeout loops across drivers.
- Remove unused DSL macros only after verifying no registry-owned source uses them.

### App-Side

- Port app entry surfaces and previews out of Zig instead of adding more wrappers.
- Consolidate component serialization around one canonical object writer.
- Remove duplicate geometry and encoded-id helpers as their owned equivalents land.

### SVG Assets

SVG assets in `app/src/assets/` should move toward owned binary sprite/icon
objects. Do not add new Zig data generators.
