# EdgeRun Toolchain Seed

This directory contains repository-owned static binaries used to cross the
current host-tool boundary.

The binaries in `toolchain/bin/` are generated artifacts, but they are tracked
intentionally so the normal workflow does not need to rebuild the first
`er-build` runner from an installed host C compiler. Each binary must be
statically linked and listed in `MANIFEST.sha256`.

These binaries are not a substitute for the final object-world compiler
boundary. They remove the first layer of host package dependence for repository
tools. Targets that still compile source still require the compiler boundary to
move to a repository-owned compiler artifact before host LLVM packages can be
removed.
