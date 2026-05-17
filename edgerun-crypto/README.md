# edgerun-crypto

Purpose: reusable freestanding cryptographic primitives for EdgeRun C projects.

The module currently provides portable BLAKE3 hashing in `include/er_blake3.h` and `src/er_blake3.c`. It does not depend on the EFI runtime, `ErCryptoProvider`, or libc memory routines.

## Build

```sh
cmake -S edgerun-crypto -B .build/edgerun-crypto
cmake --build .build/edgerun-crypto
ctest --test-dir .build/edgerun-crypto --output-on-failure
```

## Benchmarks

```sh
make crypto-bench-sota
```

The SOTA comparison target is hosted-only. It benchmarks the freestanding
implementation, fetches official upstream BLAKE3 into `.build/blake3-upstream`,
prints the upstream commit, and runs matching upstream C/amd64-asm benchmarks.
If oneTBB is available through `pkg-config`, it also runs the upstream TBB path.
