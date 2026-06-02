# Changelog

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
