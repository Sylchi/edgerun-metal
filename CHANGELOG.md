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
- `er_build host-tools` builds the owned object body/wrap tools, object-backed `er_asm`, and object-backed `er_build.next` from `kernel/host/host_tools.erobj`.
- Added `kernel/host/er_asm.asm.erobj` and changed `kernel/host/host_tools.erobj` so the assembler is built from an owned source object.
- Added `kernel/host/er_build.asm.erobj` and changed `kernel/host/host_tools.erobj` so the next build runner is built from an owned source object.
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

Expected `host-tools` output:

```text
host-tools: .build/host/er_obj_body .build/host/er_obj_wrap .build/host/er_build.next .build/host/er_asm
```
