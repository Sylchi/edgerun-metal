# EdgeRun

EdgeRun is a self-owned app and OS stack. The goal is a deterministic object graph -> materialized execution -> WASM/runtime -> identity-routed cells -> receipts loop with no package-manager trust chain and no ambient authority.

## Boundaries

- `kernel/` is host-side code. Current production host code is x86_64 assembly using the project macro DSL in `kernel/x86_64/macros.inc`; the target source authority is canonical `.erobj` code records addressed by hash.
- `kernel/host/er_build.asm` is the owned Linux userspace build runner. Bootstrap it directly with `yasm` and `ld` until owned object graph validation and materialization bypass textual assembly/linking.
- `app/` contains transitional Zig app-side code. Treat it as porting input only. Do not add new Zig app behavior.
- Objects, grants, cells, and receipts are the canonical system model. Paths and labels are conveniences, not authority.

## Program Model

The target is not a better textual assembler. A traditional assembler parses text, expands macros, resolves symbols, encodes instructions, emits sections/relocations, and hands them to a linker. EdgeRun's final model does not need that tool shape.

- A program is an `.erobj` graph of code, data, requirements, receipts, and dependencies addressed by hash.
- Code is canonical instruction records plus labels/control edges/data records/imports, not free-form source text.
- Instruction sets are finite resident object tables. `ERISA001` bodies define canonical ISA vocabularies such as x86_64, x86_32, AArch64, ARM32, and WASM; CODE records should reference those instruction definitions instead of growing ad hoc opcode branches.
- Hash-linked instruction records can be validated and materialized directly; already-canonical programs do not need compiling.
- Text `.asm` files and `.asm.erobj` bodies are the current editing/inspection bridge while the repo migrates toward canonical code objects.
- `er_asm` is transitional: it should canonicalize and emit records, not grow into a full `yasm` clone.

## Pipeline Views

Everything in the repo is a way to pipeline or view canonical records:

- Source text is an inspection/editing view over object records.
- Drivers materialize records into hardware effects and device-facing cells.
- Runtimes materialize records into WASM execution, host execution, traces, or receipts.
- Build tools validate graph closure and materialize only the requested depth.
- The UI should visualize and edit instruction chains, dependencies, receipts, grants, cells, and materialized views instead of forcing users to read flat source files.

Agents should not default to “read code, compile code, run binary.” Prefer materializing the needed view: instruction record, function graph, dependency closure, source bridge, flat bytes, image bytes, runtime trace, or receipt chain.

Authority is carried by the object graph. Pipeline edges record requirements, grants, identities, and receipts; missing constraints fail closed. There is no ambient permission layer outside the graph.

## Migration Path

Use one path only:

1. Define canonical record bodies inside existing `EROBJ001` objects.
2. Add first-class object kinds only with serializer, validator, and test coverage.
3. Represent instruction sets as canonical ISA objects, then represent code as instruction records, labels/control edges, data records, imports, requirements, and receipts that reference those ISA definitions.
4. Build materializers that emit a requested view: flat bytes, image bytes, WASM bytes, runtime trace, source bridge, graph view, or receipt chain.
5. Convert one small committed `.asm.erobj` path at a time to canonical code records.
6. Make `er_asm` emit records from text bridge input, then delete text machinery as converted paths no longer need it.
7. Move `er_build` to graph closure, hash resolution, validation, materialization, and receipt emission.
8. Move UI work to graph/pipeline views over records.

Do not create alternate assemblers, linkers, compiler IRs, package graphs, permission systems, or UI source models. The current target is first-class ISA/CODE object graphs: instruction-set objects define the finite vocabulary, code objects form relationships between those definitions, and materializers emit requested executable views with receipts.

## Repository Map

- `kernel/x86_64/` - kernel, runtime, crypto, object serialization, networking, UI/render IR, WASM interpreter/compiler, TPM, local routing.
- `kernel/driver/` - host ASM hardware drivers.
- `kernel/host/` - owned host tools: `er_build`, `er_asm`, object body/wrap tools, Pi USB boot, and ESP32 serial boot.
- `kernel/test/` - self-hosted ASM test runners.
- `kernel/arm/pi/` - Raspberry Pi Zero W bring-up kernel and drivers.
- `app/` - transitional app-side sources and UI/runtime porting input.
- `docs/` and `app/docs/` - architecture notes that must be kept subordinate to implementation.

## Developer Workflow

Start from the already-built owned tools in `.build/host/`. If `.build/host/er_build` is missing on a fresh checkout, bootstrap only the runner directly:

```sh
mkdir -p .build/host
yasm -f elf64 -I kernel -o .build/host/er_build.o kernel/host/er_build.asm
ld -nostdlib -static -o .build/host/er_build .build/host/er_build.o
```

Use the runner and owned object tools from `.build/host/`:

```sh
./.build/host/er_build help
./.build/host/er_build test-list
./.build/host/er_build test-registry
./.build/host/er_build test-status
./.build/host/er_build x86-sources
./.build/host/er_build x86-objects
./.build/host/er_build validate-object kernel/test/registry.erobj
./.build/host/er_build view kernel/host/er_build.asm.erobj
./.build/host/er_build file-to-object kernel/host/er_build.asm .build/host/er_build.asm.erobj
./.build/host/er_build file-to-isa-object .build/host/x86_64_isa.body kernel/x86_64/object/x86_64_isa.erobj
./.build/host/er_obj_body kernel/host/host_tools.erobj
```

Canonical code-record bodies can be materialized directly without parsing ASM:

```sh
./.build/host/er_build file-to-object .build/host/code-body.bin .build/host/code-body.erobj
./.build/host/er_build materialize-code-body .build/host/code-body.erobj .build/host/code.bin .build/host/code.receipt.erobj
```

For direct source-object edits, write replacement bytes to a small file and patch the object body without materializing the full source:

```sh
printf 'replacement text' > .build/host/replacement.txt
./.build/host/er_build replace-range SOURCE.erobj OFFSET DELETE_LEN .build/host/replacement.txt .build/host/source-edited.erobj
./.build/host/er_build validate-object .build/host/source-edited.erobj
```

For inspection or larger manual edits, use a temporary view and wrap it back into an object:

```sh
./.build/host/er_build body-to-file kernel/host/er_build.asm.erobj .build/host/er_build.asm
./.build/host/er_build file-to-object .build/host/er_build.asm .build/host/er_build.edited.asm.erobj
./.build/host/er_build validate-object .build/host/er_build.edited.asm.erobj
```

Development rules:

- Treat `.erobj` files as authoritative build data and source objects.
- Use `view` and `replace-range` for object-first edits. Treat materialized files under `.build/` as inspection/debug views.
- Do not make `host-tools` rebuilds part of routine work. The goal is to get off host build tools, not preserve a rebuild loop around them.
- After editing `er_build.asm` or `er_asm.asm`, update the matching `.asm.erobj` with `er_build file-to-object` and verify the existing owned tool path directly.
- Do not add shell build orchestration. Add owned `er_build` commands or object registry records instead.
- If a command fails, fix the owned registry/object/tool path. Do not add fallback commands.
- When possible, add canonical object records and materializers instead of increasing text assembler compatibility.
- Use `file-to-isa-object` for checked `ERISA001` instruction-set bodies; malformed ISA bodies must fail before they enter the object graph.
- Use `materialize-code-body` for the current CODE-record bridge; it consumes an EROBJ001 body containing `ERCODE01` records and emits flat bytes plus a canonical RECEIPT object.

Current gaps:

- `er_build x86-objects` builds the registry-owned object set; executable program work is moving toward hash-linked code-object graphs, deterministic materialization, and receipts.
- `er_asm` is being reduced to an owned source-object interpreter/canonicalizer and record emitter; `yasm` remains a temporary fresh-checkout bootstrap tool only.

## Current Facts

- The x86 source registry is an owned object consumed by `er_build`.
- `kernel/x86_64/object/x86_64_isa.erobj` is the first committed canonical ISA object table; grow instruction-set objects instead of ad hoc materializer opcode branches.
- `kernel/x86_64/object/catalog.sql` is the SQL authoring/index view for canonical ISA, instruction, form, register, and register-set objects. Use it to define finite vocabularies compactly; `.erobj` files remain the materialized authority.
- The operand vocabulary layer is materialized as `ERTYPE01`, `EROPK001`, `EROPSH01`, and `ERADDR01` objects under `kernel/x86_64/object/type/`, `operand_kind/`, `operand_shape/`, and `addressing/`. These are the finite type, operand-kind, operand-shape, and addressing-mode records that concrete CODE operands will reference.
- Functions are the SQL/query root for materialization. `kernel/x86_64/object/function/return_42_x86_64.erobj` is the first `ERFUNC01` function root; `catalog.sql` records its forms, operands, encodings, edges, and a deterministic SQL byte view that emits `b82a000000c3`.
- SQL code editing is over canonical graph rows, not generic source text. `catalog.sql` now has module, basic-block, instruction-instance, operand-binding, control-edge, symbol, and relocation tables; text source should attach as provenance later rather than become the editing authority.
- Language import is pure. `catalog.sql` defines languages, syntax atoms, semantic rules, abstraction kinds, abstraction nodes/edges, pipeline nodes/edges, import units, and lowering rules. Unsupported constructs have no rule and therefore cannot enter the graph; source text is not saved as authority.
- The active authority in this model is the query tool operating over relations. `catalog.sql` now includes source units, token kinds, lex rules, grammar rules, parse nodes, and parse edges so source bytes can be queried into tokens, parse trees, abstractions, functions, and target bytes without treating source as the stored program.
- `catalog.sql` now proves the rule-engine shape: operation kinds/signatures, type rules, effect rules, operation/value instances, data edges, and abstract lowering rules let SQL interpret `return_42_x86_64` as `42`, lower it to x86_64 instruction/form/encoding rows, and assemble `b82a000000c3` from the same graph.
- The first repo importer workbench is `edgerun_asm_dsl`. It stages `kernel/test/test_flat_runtime.asm.erobj` as ASM DSL function rows, imports `er_bss_zero`, exposes currently materializable bytes, and provides gap views such as `asm_dsl_agent_next_gaps`. The AI operator loop is: query gaps, add the missing rules/objects, rerun import/materialization queries.
- `er_build x86-objects` builds the registry-owned x86 object set.
- `er_build host-tools` remains a one-time bootstrap escape hatch for `.build/host/` tools, not a normal workflow step.
- `er_asm --interpret` consumes committed EROBJ001 `.asm.erobj` source objects directly. Flat byte output remains a smoke/debug path, not the system target.
- The system target is canonical `.erobj` code records whose hash-linked graph can be validated and materialized without reparsing free-form assembly text.
- `er_build view`, `replace-range`, `file-to-object`, and `body-to-file` provide the current source-object editing bridge.
- Local identity routing, object serialization, crypto slices, media parsers, UI/render IR, and WASM paths have self-hosted ASM test coverage in the owned registry.
- App-side Zig remains a temporary bootstrap surface being ported out.

## Rule

Implementation is truth. Remove stale parallel paths instead of documenting around them. Do not add fallbacks, compatibility shims, hidden authority, new shell orchestration, or new Zig app behavior.
