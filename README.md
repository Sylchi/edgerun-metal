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

- Source text is one import/input view. It is parsed only to extract durable facts, relations, and abstractions; once those facts are complete, the source is disposable provenance.
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

## Finite Fact Authority

Canonical pipeline: `source bytes -> one-time import -> finite base facts -> derived views`.

- Source is temporary evidence. Facts are authority.
- Keep only irreducible facts; delete source, generated rows, caches, summaries, and projections once derivable.
- Manual facts are valid only when checked by gap/conflict/proof queries.
- Materializers consume base facts only. Re-exported source, bytes, graphs, docs, tests, and receipts are derived views.
- Unsupported constructs are fatal gaps.

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

Current gaps:

- `er_build x86-objects` builds the registry-owned object set; executable program work is moving toward hash-linked code-object graphs, deterministic materialization, and receipts.
- `er_asm` is being reduced to an owned source-object interpreter/canonicalizer and record emitter; `yasm` remains a temporary fresh-checkout bootstrap tool only.
- CODE and WASM byte materialization need a real canonical record backend; the old narrow `mov eax, imm32; ret` CODE bridge and MVP expression-to-WASM emitter have been removed.

## Current Facts

- `kernel/x86_64/object/catalog.sql` indexes finite fact vocabularies, ISA records, program graphs, media facts, and materialization queries; it is not a runtime database.
- `ERISA001`, `ERTYPE01`, `EROPK001`, `EROPSH01`, `ERADDR01`, and `ERFUNC01` objects are the current materialized vocabulary/function roots.
- Code editing targets finite facts and canonical graph rows. Token/parse/source rows are importer intermediates to delete once facts have closure.
- App-side Zig is porting evidence only; reduce it to finite facts and delete derivable source, caches, and projections.
- Existing owned runner/object commands remain the workflow bridge until graph materialization replaces them.

## Rule

Finite facts are truth. Implementation is a materialized view over those facts. Remove stale parallel paths instead of documenting around them. Do not add fallbacks, compatibility shims, hidden authority, new shell orchestration, or new Zig app behavior.
