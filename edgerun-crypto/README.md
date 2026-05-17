# edgerun-crypto

Purpose: reusable freestanding cryptographic primitives for EdgeRun C projects.

The module currently provides portable BLAKE3 hashing in `include/er_blake3.h` and `src/er_blake3.c`. It does not depend on the EFI runtime, `ErCryptoProvider`, or libc memory routines.

## Build

```sh
cmake -S edgerun-crypto -B .build/edgerun-crypto
cmake --build .build/edgerun-crypto
ctest --test-dir .build/edgerun-crypto --output-on-failure
```
