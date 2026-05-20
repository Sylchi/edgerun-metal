# EdgeRun Toolchain Seed

This directory contains repository-owned static binaries used to cross the
current host-tool boundary.

The binaries in `toolchain/bin/` are generated artifacts, but they are tracked
intentionally so the normal workflow does not need to rebuild the first
`er-build` runner from an installed host C compiler. Each binary must be
statically linked and listed in `MANIFEST.sha256`.

`toolchain/bin/clang` is a static Clang 22.1.5 build with the targets currently
needed by the repository plus the near-term optional targets: X86, AArch64, ARM,
WebAssembly, BPF, RISCV, and AMDGPU. The matching Clang resource headers live in
`toolchain/lib/clang/22`.

`toolchain/bin/lld`, `toolchain/bin/ld.lld`, `toolchain/bin/wasm-ld`,
`toolchain/bin/llvm-ar`, `toolchain/bin/llvm-objcopy`, and
`toolchain/bin/llvm-strip` are static LLVM tool binaries used by the normal
build path.

These binaries are not a substitute for the final object-world compiler
boundary. They remove the host LLVM package dependency from the normal
repository workflow while keeping the final compiler boundary explicit.
