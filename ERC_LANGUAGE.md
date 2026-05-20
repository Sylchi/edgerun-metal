# ERC Language Contract

ERC is the EdgeRun app language. The name expands to EdgeRun C--: a small
C-shaped source format for admitted EdgeRun packages, not hosted C and not a
freestanding C profile.

The purpose of ERC is to give apps and Wasm drivers a deterministic source
language whose only outside world is the explicit EdgeRun ABI table in
`include/er_wasm_contract.h`. The repository-owned compiler in
`tools/wasm-compile` currently emits WebAssembly modules for the metal runtime.
Wasm is the current portable object format; it is not the language contract.
The compiler core accepts source bytes and emits Wasm bytes; filesystem paths
belong to the current host CLI wrapper only.

## Hard Boundary

ERC source must not depend on host libc, host process state, host filesystems,
or conventional C program startup. The compiler rejects the current known host
surface before parsing:

```text
#, FILE, argc, argv, char, fopen, free, include, int, malloc, open, printf,
read, size_t, stdio, stdlib, string, write
```

This list is an enforcement floor, not a compatibility promise. More host
tokens may be rejected as the compiler boundary gets tighter.

ERC packages use `app.erc` as the canonical source filename. Existing
`source=app.c` package manifests remain accepted as a transitional spelling
because earlier package fixtures used that filename for ERC source.

## Current Source Shape

Current ERC source is ordered and explicit:

```text
imports
constants
memory declaration
helper functions
exported main
```

Minimal UI app:

```c
extern i64 ui_emit(i64, i64) __import("edgerun.ui", "emit");
memory(1);
export i64 main(void) { return ui_emit(0, 0); }
```

Current forms:

```text
extern i64 name(i64, i64) __import("module", "field");
extern i64 name(void) __import("module", "field");
const i64 NAME = literal;
memory(1);
i64 helper(i64 arg, i64 other) { statements return expression; }
export i64 main(void) { statements return expression; }
```

Current statements:

```text
i64 name = expression;
name = expression;
store16(base, offset, expression);
store32(base, offset, expression);
store64(base, offset, expression);
if (expression) { statements } else { statements }
```

Current expressions:

```text
literal
local_name
constant_name
hostcall_or_helper(expression, ...)
load32(base, offset)
load64(base, offset)
```

All user-visible scalar values are currently `i64`. Memory offsets may be
integer literals or constants and must fit in an unsigned 32-bit offset.
`memory(1)` is required because admitted modules currently use one Wasm page.

## ABI And Admission

ERC imports must name hostcalls present in `include/er_wasm_contract.h`. The
compiler records the import kind from that shared table, and runtime admission
rejects modules whose imports, signatures, memory size, or exported `main`
shape do not match an admitted contract.

The first admitted package contracts are:

- `ui-app`: imports `edgerun.ui/emit`
- `bus-driver`: imports `edgerun.bus/exec`

Additional helper imports from the shared ABI table are allowed only when the
runtime contract admits them.

## Not ERC

These are intentionally outside the language today:

- `#include` and preprocessing
- libc names and host C startup
- `main(int argc, char** argv)`
- pointers as a source-level type
- structs, unions, enums, typedefs, and headers
- implicit filesystem or network access
- allocation APIs such as `malloc` and `free`
- unspecified imports or dynamic linking
- syntax accepted only because a host C compiler would accept it

Unsupported syntax is fatal.

## Diagnostics

The path-based host CLI prints a stable diagnostic code before the prose
message. Current codes:

```text
ERWC0001 bad arguments
ERWC0100 unsupported ERC source
ERWC0200 WAT tokenization failed
ERWC0201 unsupported WAT subset
ERWC0300 module contract rejected
ERWC0400 Wasm emit failed
ERWC0500 unsupported source kind
ERWC0999 unknown compiler status
```

## Roadmap

The next ERC work should tighten the boundary before growing the language:

- Rename transitional compiler symbols from `wasm_compile_c` to ERC names.
- Replace the path-based host CLI wrapper with the EdgeRun VFS/blob boundary.
- Move package source, manifest, output, and identity toward content-addressed
  blobs; keep `.build/` as a local export cache.
- Add language features only when compiler output, runtime admission, and tests
  are updated together.
