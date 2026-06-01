; EdgeRun TPM command builder self-hosted test.
; Verifies EncryptDecrypt2 writes the caller-supplied decrypt flag.

%include "test/test_macros.inc"
%include "x86_64/tpm/tpm_constants.inc"

extern er_tpm_encrypt_decrypt2
extern er_tpm_parse_p256_public

TEST_DATA_TOTAL_PASSED_FAILED

SECTION .bss
cmd_buf: resb 128
x_out:   resb 32
y_out:   resb 32

SECTION .rodata
iv_bytes:
    db 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17
    db 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f
input_bytes:
    db 0xaa, 0xbb, 0xcc, 0xdd

SECTION .text
global _start
_start:
    call    build_encrypt
    ASSERT_EQ rax, cmd_buf
    ASSERT_BYTE [rel cmd_buf + 27], 0
    call    assert_common_encrypt_decrypt2

    call    build_decrypt
    ASSERT_EQ rax, cmd_buf
    ASSERT_BYTE [rel cmd_buf + 27], 1
    call    assert_common_encrypt_decrypt2

    lea     rdi, [rel p256_response]
    mov     esi, p256_response_len
    lea     rdx, [rel x_out]
    lea     rcx, [rel y_out]
    call    er_tpm_parse_p256_public
    ASSERT_EQ eax, 64
    ASSERT_MEM_EQ [rel x_out], [rel p256_x], 32
    ASSERT_MEM_EQ [rel y_out], [rel p256_y], 32

    mov     rdi, x_out
    mov     esi, 0x5a
    mov     edx, 32
    call    fill_bytes
    mov     rdi, y_out
    mov     esi, 0xa5
    mov     edx, 32
    call    fill_bytes
    lea     rdi, [rel p256_response]
    mov     esi, p256_response_len - 1
    lea     rdx, [rel x_out]
    lea     rcx, [rel y_out]
    call    er_tpm_parse_p256_public
    ASSERT_EQ eax, 0
    mov     rdi, x_out
    ASSERT_MEM_ALL 0x5a, 32
    mov     rdi, y_out
    ASSERT_MEM_ALL 0xa5, 32

    TEST_EXIT_FAILED

build_encrypt:
    mov     rdi, cmd_buf
    mov     esi, TEST_HANDLE
    lea     rdx, [rel input_bytes]
    mov     ecx, 4
    lea     r8, [rel iv_bytes]
    mov     r9d, TPM_ALG_CFB
    push    0
    call    er_tpm_encrypt_decrypt2
    add     rsp, 8
    ret

build_decrypt:
    mov     rdi, cmd_buf
    mov     esi, TEST_HANDLE
    lea     rdx, [rel input_bytes]
    mov     ecx, 4
    lea     r8, [rel iv_bytes]
    mov     r9d, TPM_ALG_CFB
    push    1
    call    er_tpm_encrypt_decrypt2
    add     rsp, 8
    ret

assert_common_encrypt_decrypt2:
    ASSERT_BYTE [rel cmd_buf], 0x80
    ASSERT_BYTE [rel cmd_buf + 1], 0x02
    ASSERT_BYTE [rel cmd_buf + 2], 0x00
    ASSERT_BYTE [rel cmd_buf + 3], 0x00
    ASSERT_BYTE [rel cmd_buf + 4], 0x00
    ASSERT_BYTE [rel cmd_buf + 5], 54
    ASSERT_BYTE [rel cmd_buf + 6], 0x00
    ASSERT_BYTE [rel cmd_buf + 7], 0x00
    ASSERT_BYTE [rel cmd_buf + 8], 0x01
    ASSERT_BYTE [rel cmd_buf + 9], 0x93
    ASSERT_BYTE [rel cmd_buf + 10], 0x81
    ASSERT_BYTE [rel cmd_buf + 11], 0x00
    ASSERT_BYTE [rel cmd_buf + 12], 0x00
    ASSERT_BYTE [rel cmd_buf + 13], 0x01
    ASSERT_BYTE [rel cmd_buf + 28], 0x00
    ASSERT_BYTE [rel cmd_buf + 29], 0x43
    ASSERT_BYTE [rel cmd_buf + 30], 0x00
    ASSERT_BYTE [rel cmd_buf + 31], 16
    ASSERT_BYTE [rel cmd_buf + 32], 0x10
    ASSERT_BYTE [rel cmd_buf + 47], 0x1f
    ASSERT_BYTE [rel cmd_buf + 48], 0x00
    ASSERT_BYTE [rel cmd_buf + 49], 4
    ASSERT_BYTE [rel cmd_buf + 50], 0xaa
    ASSERT_BYTE [rel cmd_buf + 53], 0xdd
    ret

fill_bytes:
    mov     rcx, rdx
    mov     eax, esi
.fill_loop:
    test    rcx, rcx
    jz      .fill_done
    mov     [rdi], al
    inc     rdi
    dec     rcx
    jmp     .fill_loop
.fill_done:
    ret

TEST_HANDLE equ 0x81000001

SECTION .rodata
p256_x:
    db 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07
    db 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f
    db 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17
    db 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f
p256_y:
    db 0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27
    db 0x28, 0x29, 0x2a, 0x2b, 0x2c, 0x2d, 0x2e, 0x2f
    db 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37
    db 0x38, 0x39, 0x3a, 0x3b, 0x3c, 0x3d, 0x3e, 0x3f

p256_response:
    db 0x80, 0x01                     ; TPM_ST_NO_SESSIONS
    db 0x00, 0x00, 0x00, p256_response_len
    db 0x00, 0x00, 0x00, 0x00         ; TPM_RC_SUCCESS
    db 0x81, 0x00, 0x00, 0x01         ; object handle
    db 0x00, 0x58                     ; TPM2B_PUBLIC size = 88
    db 0x00, 0x23                     ; type = TPM_ALG_ECC
    db 0x00, 0x0b                     ; nameAlg = SHA256
    db 0x00, 0x06, 0x00, 0x72         ; objectAttributes
    db 0x00, 0x00                     ; authPolicy size
    db 0x00, 0x10                     ; symmetric = NULL
    db 0x00, 0x10, 0x00, 0x10         ; scheme = NULL
    db 0x00, 0x03                     ; curveID = NIST_P256
    db 0x00, 0x10                     ; kdf = NULL
    db 0x00, 0x20
    db 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07
    db 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f
    db 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17
    db 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f
    db 0x00, 0x20
    db 0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27
    db 0x28, 0x29, 0x2a, 0x2b, 0x2c, 0x2d, 0x2e, 0x2f
    db 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37
    db 0x38, 0x39, 0x3a, 0x3b, 0x3c, 0x3d, 0x3e, 0x3f
p256_response_len equ $ - p256_response
