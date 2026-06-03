# Changelog

## 2026-06-02 - Canonical Program Model Clarification

- Documented that the target is not a replacement textual assembler.
- Converted the render IR and flat runtime test sources to committed source objects and expanded `catalog.sql` so repo ASM source objects lower into indexed facts for parsed operations, rule matches, operation status, relocations, data references, macro lowerings, and deletion-readiness.
- Added operator queue views for remaining ASM fact gaps and next fixed-encoding candidates; `dec ecx` and `dec eax` now lower through finite encoding facts, moving 154 inventory operations to fixed encodings.
- Materialized and indexed the repo ASM operation, rule-match, and operation-status relations so each new lowering round can query the next gaps quickly instead of recomputing nested source-import views.
- Added tradeoff decision, option, metric, assessment, and selected-option facts so source deletion and operator-loop choices can be ranked from queryable cost, benefit, risk, and canonical-alignment data.
- Defined programs as `.erobj` graphs of hash-addressed code, data, requirements, receipts, and dependencies.
- Clarified that code should move toward canonical instruction records, labels, control edges, data records, and imports that can be validated and materialized directly.
- Documented source, drivers, runtimes, build tools, UI, tests, and text views as pipeline/view layers over canonical object records.
- Clarified that agents should materialize the needed view depth instead of defaulting to flat source reading.
- Reframed authority as requirements, grants, identities, and receipts carried on graph pipeline edges, not an ambient side model.
- Added the single canonical migration path so future work starts with object records, materializers, graph closure, and receipts instead of inventing alternate assembler/compiler models.
- Added first-class `OBJECT_KIND_CODE` support in the object serializer/validator path, with object self-test coverage for code headers, code child references, and code canonical sizing with body records plus graph children.
- Added first-class `OBJECT_KIND_ISA` and the `ERISA001` instruction-set body skeleton so finite instruction vocabularies can live as resident canonical object tables.
- Added `er_isa_validate_body` and `er_object_write_isa_node`, with self-test coverage for a tiny x86_64 ISA table containing canonical definitions for `mov eax, imm32` and `ret`.
- Added `er_build file-to-isa-object INPUT OUTPUT.erobj` so checked `ERISA001` bodies can be written as first-class ISA objects instead of bytes wrappers.
- Added `kernel/x86_64/object/catalog.sql` as the SQL authoring/index view for canonical ISA, instruction, form, register, and register-set object families while keeping `.erobj` as the materialized authority.
- Added the operand vocabulary layer as materialized objects: `ERTYPE01` value/type objects, `EROPK001` operand-kind objects, `EROPSH01` operand-shape objects, and `ERADDR01` addressing-mode objects, all indexed in `catalog.sql`.
- Added seed `EROPER01` concrete operand objects, `ERENC001` encoding objects, and the first `ERFUNC01` function root `return_42_x86_64`; `catalog.sql` can now query that function into flat x86 bytes `b82a000000c3`.
- Added canonical program graph SQL tables for modules, basic blocks, instruction instances, operand bindings, control edges, symbols, and relocations, plus graph-closure and byte-materialization views that emit `return_42_x86_64` from operand data.
- Added pure language import/abstraction SQL tables for languages, syntax atoms, semantic rules, abstraction kinds, abstraction nodes/edges, pipeline nodes/edges, import units, and lowering rules. Seeded C/Zig/WASM/ASM/SQL rule rows and mapped the `return_42_x86_64` abstraction graph to materialized bytes without source-text authority or import receipts.
- Added SQL parser/import tables for source units, token kinds, lex rules, grammar rules, parse nodes, and parse edges. Seeded `return_42.c` so SQL queries expose its token stream, parse tree, abstraction projection, and x86_64 bytes `b82a000000c3`.
- Added relational rule-engine tables for operation kinds/signatures, type rules, effect rules, operation/value instances, data edges, and abstract lowering rules. SQL now proves interpreter/compiler/assembler modes over the same `return_42_x86_64` graph: interpreted return value `42`, lowered x86_64 instruction stream, and assembled bytes `b82a000000c3`.
- Added the first `edgerun_asm_dsl` importer workbench for real repo code. `catalog.sql` stages `kernel/test/test_flat_runtime.asm.erobj`, imports `er_bss_zero`, emits currently materializable bytes, and exposes `asm_dsl_agent_next_gaps` so the AI operator can iteratively add missing rules/objects.
- Added the first minimal canonical code body record schema and `er_code_materialize_flat`, which materializes x86_64 `mov eax, imm32` plus `ret` instruction records into flat bytes and emits a deterministic materialization receipt.
- Added `er_object_write_code_node` so canonical CODE objects can be written, decoded through `er_object_view_decode`, and materialized from the decoded view body.
- Added `er_object_write_receipt_node` through a shared plain-body object writer so materialization receipts can be persisted as canonical RECEIPT objects and decoded as object views.
- Added `er_code_validate_body` and made CODE object writing/materialization reject malformed canonical code records before they can enter the object graph.
- Added canonical CODE `EXPORT` and `IMPORT` metadata record kinds. They validate as graph metadata, materialize as non-emitting records, and preserve deterministic receipt record counts.
- Extended object self-test and `er_build materialize-code-body` coverage so export/import metadata around instruction records still emits the same flat bytes.
- Added `er_build materialize-code-body BODY.erobj OUTPUT RECEIPT.erobj`, an immediate runner workflow that consumes an EROBJ-wrapped `ERCODE01` canonical code body and emits flat bytes plus a canonical RECEIPT object without parsing text ASM.
- Marked `er_asm` as transitional source-object interpretation/canonicalization tooling, not a `yasm` clone target.
- Updated dependency language so `yasm`, `ld`, and `objcopy` are temporary text/materialization bootstrap tools, not shapes to reproduce permanently.

## 2026-06-02 - Owned Tooling Consolidation

- Removed the shell build runner from the workspace.
- Updated root documentation to use direct `kernel/host/er_build.asm` bootstrap.
- Kept the supported command surface in owned ASM host tools:
  - `er_build help`
  - `er_build test-list`
  - `er_build test-registry`
  - `er_build x86-sources`
  - `er_build x86-objects`
  - `er_build validate-object`
  - `er_build body-to-file`
  - `er_build file-to-object`
  - `er_build view`
  - `er_build replace-range`
- `er_build host-tools` remains a one-time bootstrap escape hatch for `.build/host/` tools; routine tests and workflows should use existing owned tools directly.
- Added `kernel/host/er_asm.asm.erobj` and changed `kernel/host/host_tools.erobj` so the assembler is built from an owned source object.
- Added `kernel/host/er_build.asm.erobj` and changed `kernel/host/host_tools.erobj` so the next build runner is built from an owned source object.
- `er_asm` now accepts EROBJ001 `.asm.erobj` source input directly for parsing and supported flat-binary assembly.
- Added explicit `er_asm --interpret` mode for committed source objects so assembler work follows the object-interpreter direction instead of ELF/toolchain compatibility.
- `er_asm --interpret` now emits an `er_asm_interpret` receipt with the normalized source body length and deterministic interpreter counters.
- `app/src/content/kernel_authority.zig` and its Zig test shim were removed; `kernel/x86_64/content/kernel_authority.asm` and `kernel/test/test_kernel_authority_self.asm` are the source of truth.

## Current Verification

Verified by direct bootstrap and owned runner commands:

```sh
mkdir -p .build/host
yasm -f elf64 -I kernel -o .build/host/er_build.o kernel/host/er_build.asm
ld -nostdlib -static -o .build/host/er_build .build/host/er_build.o
./.build/host/er_build host-tools
./.build/host/er_build test-list
./.build/host/er_build x86-objects
./.build/host/er_build validate-object kernel/test/registry.erobj
./.build/host/er_build file-to-object kernel/host/er_build.asm .build/host/er_build.asm.erobj
```

`host-tools` was run once to populate `.build/host/`; subsequent checks use the existing owned tools directly.
