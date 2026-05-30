#!/usr/bin/env python3
"""X25519 Montgomery ladder reference using Python big integers.
Compare intermediate X2/Z2 values with ASM dumps.
Values taken from ASM test file struct definitions (little-endian dq).
"""
import struct, sys

p = 2**255 - 19
a24 = 121665  # (486662 - 2) / 4

def dq_to_bytes(v):
    """64-bit value as 8 bytes little-endian."""
    return v.to_bytes(8, 'little')

def decode_u_from_dq(dq0, dq1, dq2, dq3):
    """Decode 4 dq values (little-endian) to integer u-coordinate."""
    raw = dq0.to_bytes(8, 'little') + dq1.to_bytes(8, 'little') + dq2.to_bytes(8, 'little') + dq3.to_bytes(8, 'little')
    return int.from_bytes(raw, 'little') & ((1 << 255) - 1)

def clamp_scalar_from_dq(dq0, dq1, dq2, dq3):
    """Decode 4 dq values as little-endian, then clamp."""
    raw = bytearray(dq0.to_bytes(8, 'little') + dq1.to_bytes(8, 'little') + dq2.to_bytes(8, 'little') + dq3.to_bytes(8, 'little'))
    raw[0] &= 248
    raw[31] &= 127
    raw[31] |= 64
    return int.from_bytes(raw, 'little')

def ladder_step(x2, z2, x3, z3, x1):
    a = (x2 + z2) % p
    aa = (a * a) % p
    b = (x2 - z2) % p
    bb = (b * b) % p
    e = (aa - bb) % p
    c = (x3 + z3) % p
    d = (x3 - z3) % p
    da = (d * a) % p
    cb = (c * b) % p
    x3 = ((da + cb) ** 2) % p
    z3 = (x1 * ((da - cb) ** 2)) % p
    x2 = (aa * bb) % p
    z2 = (e * (aa + a24 * e)) % p
    return x2, z2, x3, z3

def scalar_mult_raw(s_int, x1):
    """Montgomery ladder given clamped scalar int and u-coordinate int."""
    x2, z2 = 1, 0
    x3, z3 = x1, 1
    swap = 0
    for t in range(254, -1, -1):
        k_t = (s_int >> t) & 1
        swap ^= k_t
        if swap:
            x2, x3 = x3, x2
            z2, z3 = z3, z2
        swap = k_t
        x2, z2, x3, z3 = ladder_step(x2, z2, x3, z3, x1)
    if swap:
        x2, x3 = x3, x2
        z2, z3 = z3, z2
    u = (x2 * pow(z2, p - 2, p)) % p
    return u.to_bytes(32, 'little'), x2, z2

def get_dq_label(hex_str, n):
    """Extract the nth dq value from a hex string."""
    pass

# ====== ASM Test Vector 1 ======
s1_dq0 = 0x9d7c52f06be346a5
s1_dq1 = 0xdd5e46824b15163b
s1_dq2 = 0x185afcc10a4c1462
s1_dq3 = 0xc49a44ba44226a50

p1_dq0 = 0xdb3030586768dbe6
p1_dq1 = 0x7c5fb124a4c19435
p1_dq2 = 0x3b35b326ec246672
p1_dq3 = 0x4c1cabd0a603a910

o1_dq0 = 0x90c6e99d3755dac3
o1_dq1 = 0x4f088df24dea948e
o1_dq2 = 0xf7711c4903cfec32
o1_dq3 = 0x5285a2775507b454

# ====== ASM Test Vector 2 ======
s2_dq0 = 0x3c67b4d1d4e9664b
s2_dq1 = 0xf56a7d952691d25a
s2_dq2 = 0xd401eae021641bc1
s2_dq3 = 0x0dba18799e16a42c

p2_dq0 = 0xd3116878120f21e5
p2_dq1 = 0x2cae38059d95b7f4
p2_dq2 = 0x3e3cc06f10e7db31
p2_dq3 = 0x93a415c749d54cfc

o2_dq0 = 0x7d90e87694decb95
o2_dq1 = 0xf873b8b45ce4ad7a
o2_dq2 = 0x52a19f79685a598b
o2_dq3 = 0x5779ac7a64f7f8e6

print("=" * 70)
print("VECTOR 1")
print("=" * 70)
s1 = clamp_scalar_from_dq(s1_dq0, s1_dq1, s1_dq2, s1_dq3)
x1 = decode_u_from_dq(p1_dq0, p1_dq1, p1_dq2, p1_dq3)
exp1_bytes = o1_dq0.to_bytes(8,'little') + o1_dq1.to_bytes(8,'little') + o1_dq2.to_bytes(8,'little') + o1_dq3.to_bytes(8,'little')
result1_bytes, res_x2, res_z2 = scalar_mult_raw(s1, x1)
print(f"Result:   {result1_bytes.hex()}")
print(f"Expected: {exp1_bytes.hex()}")
print(f"PASS: {result1_bytes == exp1_bytes}")

print()
print("=" * 70)
print("VECTOR 2")
print("=" * 70)
s2 = clamp_scalar_from_dq(s2_dq0, s2_dq1, s2_dq2, s2_dq3)
x2 = decode_u_from_dq(p2_dq0, p2_dq1, p2_dq2, p2_dq3)
exp2_bytes = o2_dq0.to_bytes(8,'little') + o2_dq1.to_bytes(8,'little') + o2_dq2.to_bytes(8,'little') + o2_dq3.to_bytes(8,'little')
result2_bytes, res2_x2, res2_z2 = scalar_mult_raw(s2, x2)
print(f"Result:   {result2_bytes.hex()}")
print(f"Expected: {exp2_bytes.hex()}")
print(f"PASS: {result2_bytes == exp2_bytes}")

# Also check RFC original scalar2
print()
print("=" * 70)
print("RFC 7748 STANDARD Vector 2 (correct scalar)")
print("=" * 70)
rfc_s2 = int.from_bytes(bytes.fromhex("4b66e9d4d1b4673c5ad22691957d6af5c11b6421e0ea01d42ca4169e7918ba0d"), 'little')
rfc_s2_clamped = rfc_s2 & ~7
rfc_s2_clamped &= ~(1 << 255)
rfc_s2_clamped |= 1 << 254
rfc_result, _, _ = scalar_mult_raw(rfc_s2_clamped, x2)
print(f"RFC scalar2 result: {rfc_result.hex()}")
print(f"Match RFC output2:  {rfc_result == exp2_bytes}")

# Compare ASM scalar2 vs RFC scalar2
print()
asm_s2_int = int.from_bytes(s2_dq0.to_bytes(8,'little') + s2_dq1.to_bytes(8,'little') + s2_dq2.to_bytes(8,'little') + s2_dq3.to_bytes(8,'little'), 'little')
rfc_s2_int = int.from_bytes(bytes.fromhex("4b66e9d4d1b4673c5ad22691957d6af5c11b6421e0ea01d42ca4169e7918ba0d"), 'little')
print(f"ASM scalar2 hex: {asm_s2_int:064x}")
print(f"RFC scalar2 hex: {rfc_s2_int:064x}")
print(f"Bytes 10-11 swapped in ASM: {asm_s2_int != rfc_s2_int}")
