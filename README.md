# EdgeRun

EdgeRun is a self-owned app and OS stack. The goal is a deterministic source-object -> compiler -> WASM/runtime -> identity-routed cells -> receipts loop with no package-manager trust chain and no ambient authority.

## Boundaries

- `kernel/` is host-side code. Production host code is x86_64 assembly using the project macro DSL in `kernel/x86_64/macros.inc`.
- `kernel/host/er_build.asm` is the owned Linux userspace build runner. Bootstrap it directly with `yasm` and `ld` until the repo-owned assembler/linker replace them.
- `app/` contains transitional Zig app-side code. Treat it as porting input only. Do not add new Zig app behavior.
- Objects, grants, cells, and receipts are the canonical system model. Paths and labels are conveniences, not authority.

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

Current gaps:

- `er_build x86-objects` builds the registry-owned object set, but full kernel/test linking is still being moved into owned commands.
- `er_asm` is the owned assembler path under active development; `yasm` remains a temporary fresh-checkout bootstrap tool only.

## Current Facts

- The x86 source registry is an owned object consumed by `er_build`.
- `er_build x86-objects` builds the registry-owned x86 object set.
- `er_build host-tools` remains a one-time bootstrap escape hatch for `.build/host/` tools, not a normal workflow step.
- `er_asm` accepts plain `.asm` and EROBJ001 `.asm.erobj` source input directly. ELF object emission is still pending, so host-tools still uses the bootstrap assembler for ELF64 outputs.
- `er_build view`, `replace-range`, `file-to-object`, and `body-to-file` provide the current source-object editing bridge.
- Local identity routing, object serialization, crypto slices, media parsers, UI/render IR, and WASM paths have self-hosted ASM test coverage in the owned registry.
- App-side Zig remains a temporary bootstrap surface being ported out.

## Rule

Implementation is truth. Remove stale parallel paths instead of documenting around them. Do not add fallbacks, compatibility shims, hidden authority, new shell orchestration, or new Zig app behavior.
