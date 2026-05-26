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

## Milestones

1. Add an EdgeRun-owned source mode.
   - Accept `.er` workspace roots.
   - Keep current Zig-like export syntax for the narrow supported subset.
   - Do not call Zig `Ast` or `AstGen` for `.er` roots.
   - Emit the same successor WASM path as the current compiler probe.

2. Replace string-pattern lowering with a typed EdgeRun parser.
   - Tokenize source deterministically from caller-owned memory.
   - Parse only supported declarations.
   - Preserve current zero-arg integer export behavior.
   - Reject imports, comptime, generics, arbitrary pointer code, and ambient
     host access.

3. Lower UI declarations to existing component objects.
   - Map source component declarations to `ui_codec.RecordKind`.
   - Use each component's `writeRecord` behavior as the canonical contract.
   - Emit leaf component objects with shared component requirements.
   - Emit composed UI through existing tree objects.

4. Bind compiler output to canonical app artifacts.
   - Return or store canonical source/workspace object identity.
   - Return or store canonical UI object ids.
   - Return WASM bytes as a `WasmAppImage`-ready artifact.
   - Keep allocation, manifest, and receipt binding on existing app paths.

5. Self-host the small compiler.
   - Build the EdgeRun compiler as WASM.
   - Run it through `src/wasm/root.zig`.
   - Keep the host Zig build only as bootstrap and verification tooling.

## Current First Slice

The first slice is deliberately small: `.er` roots compile through an
EdgeRun-owned source analyzer instead of Zig AST/ZIR, while reusing the current
WASM emitter and narrow export lowering. This proves the direction without
inventing a parallel runtime.
