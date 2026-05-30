#!/usr/bin/env python3
"""Ground truth for _fe_mul raw 512-bit product (4-limb radix-2^64)."""

import struct

P = 2**255 - 19

def limbs_to_int(limbs):
    return sum((l & ((1<<64)-1)) << (64*i) for i, l in enumerate(limbs))

def int_to_limbs(x, n=4):
    return [(x >> (64*i)) & ((1<<64)-1) for i in range(n)]

def mul_512(a, b):
    """Compute 512-bit product as 8 limbs."""
    prod = [0] * 8
    for i in range(4):
        for j in range(4):
            p = a[i] * b[j]
            lo = p & ((1<<64)-1)
            hi = p >> 64
            prod[i+j] += lo
            carry = prod[i+j] >> 64
            prod[i+j] &= (1<<64)-1
            prod[i+j+1] += hi + carry
    # Normalize: propagate any remaining carries
    for k in range(8):
        if prod[k] >= (1<<64):
            carry = prod[k] >> 64
            prod[k] &= (1<<64)-1
            if k+1 < 8:
                prod[k+1] += carry
    return prod

def mul_512_128bit_accum(a, b):
    """Schoolbook with 128-bit accumulators (matching the ASM pattern)."""
    lo = [0] * 8
    hi = [0] * 8
    for i in range(4):
        for j in range(4):
            p = a[i] * b[j]
            p_lo = p & ((1<<64)-1)
            p_hi = p >> 64
            # Accumulate lo at position i+j
            lo[i+j] += p_lo
            carry = lo[i+j] >> 64
            lo[i+j] &= (1<<64)-1
            hi[i+j] += carry
            # Accumulate hi at position i+j+1
            lo[i+j+1] += p_hi
            carry = lo[i+j+1] >> 64
            lo[i+j+1] &= (1<<64)-1
            hi[i+j+1] += carry
    # Collapse: for k=0..7: total = lo[k] + carry_in; product[k] = total & 2^64-1; carry_out = total>>64 + hi[k]
    product = [0] * 8
    carry = 0
    for k in range(8):
        total = lo[k] + carry
        carry = (total >> 64) + hi[k]
        product[k] = total & ((1<<64)-1)
    return product

def fe_reduce(prod_8limbs):
    """Reduce 512-bit product (8 limbs) modulo 2^255-19."""
    low = prod_8limbs[:4]
    high = prod_8limbs[4:]
    # Multiply high by 38, add to low
    h38 = [0] * 4
    carry = 0
    for i in range(4):
        p = high[i] * 38 + carry
        h38[i] = p & ((1<<64)-1)
        carry = p >> 64
    # Carry may be > 0, add to result
    result = [0] * 4
    c = 0
    for i in range(4):
        s = low[i] + h38[i] + c
        result[i] = s & ((1<<64)-1)
        c = s >> 64
    # Carry from last addition: multiply by 38 and add back
    result_int = limbs_to_int(result) + c * 38
    return int_to_limbs(result_int % (2**256))

def fe_mul_field(a, b):
    """Full fe_mul: multiply, reduce, return field element."""
    prod = mul_512_128bit_accum(a, b)
    reduced = fe_reduce(prod)
    val = limbs_to_int(reduced)
    if val >= P:
        val -= P
    return int_to_limbs(val)

# Test values
a = [9, 0, 0, 0]  # base point

# inv(9) from the kernel output
inv9 = [0xc71c71c71c71c6ff, 0x1c71c71c71c71c71, 0x71c71c71c71c71c7, 0xc71c71c71c71c71c]

print("=== inv(9) from kernel output ===")
for i, l in enumerate(inv9):
    print(f"  limb {i}: 0x{l:016x}")

# Expected raw 512-bit product of 9 * inv(9)
prod = mul_512_128bit_accum(a, inv9)
print("\n=== Raw 512-bit product (128-bit accumulator method) ===")
for i, l in enumerate(prod):
    print(f"  limb {i}: 0x{l:016x}")
val = limbs_to_int(prod)
print(f"  value = 0x{val:x}")
print(f"  value mod p = 0x{(val % P):x}")
print(f"  expected = 1")

# Also compute the naively correct 512-bit product
prod_naive = mul_512(a, inv9)
print("\n=== Raw 512-bit product (naive carry) ===")
for i, l in enumerate(prod_naive):
    print(f"  limb {i}: 0x{l:016x}")
val2 = limbs_to_int(prod_naive)
print(f"  value = 0x{val2:x}")
assert val == val2, "Methods differ!"
print("  (128-bit accumulator matches naive carry)")

# Now reduce
reduced = fe_reduce(prod)
print("\n=== After reduction ===")
for i, l in enumerate(reduced):
    print(f"  limb {i}: 0x{l:016x}")
print(f"  value = 0x{limbs_to_int(reduced):x}")
print(f"  expected = 1")

# Check: does 9 * inv(9) mod p = 1?
assert limps_to_int(reduced) % P == 1, "Reduction failed!"
print("\n✓ 9 * inv(9) ≡ 1 (mod p)")

# Also test 9 * 1 case
print("\n=== 9 * 1 test ===")
one = [1, 0, 0, 0]
prod_9_1 = mul_512_128bit_accum(a, one)
print("Raw product:")
for i, l in enumerate(prod_9_1):
    print(f"  limb {i}: 0x{l:016x}")
reduced_9_1 = fe_reduce(prod_9_1)
print("Reduced:")
for i, l in enumerate(reduced_9_1):
    print(f"  limb {i}: 0x{l:016x}")
assert limps_to_int(reduced_9_1) == 9, "9*1 failed!"

print("\n=== 9^3 = 729 test ===")
b = [9, 0, 0, 0]
c = fe_mul_field(a, b)  # 9*9 = 81
d = fe_mul_field(c, a)  # 81*9 = 729
print(f"  9^3 = 0x{limbs_to_int(d):x}")
assert limps_to_int(d) == 729, "9^3 failed!"

print("\n=== seq_8 test ===")
val = [9, 0, 0, 0]
for _ in range(8):
    val = fe_mul_field(fe_mul_field(val, val), a)  # sq then mul by 9
print(f"  seq_8 = 0x{limbs_to_int(val):016x}")
