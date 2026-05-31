; EdgeRun Tor onion-service protocol helpers — x86_64 assembly.
; Builds and parses HS relay-message bodies. Circuit cryptography and
; relay-cell framing stay in tor_cell.asm.

%include "x86_64/macros.inc"
%include "x86_64/crypto/tor_constants.inc"

extern er_memcpy
extern er_sha3_256
extern er_shake256
extern er_tor_aes256_ctr
extern er_tor_curve25519_scalar_mult
extern er_tor_send_relay
extern er_tor_recv_relay

SECTION .rodata
tor_hs_ntor_protoid: db "tor-hs-ntor-curve25519-sha3-256-1"
tor_hs_ntor_t_hsenc: db "tor-hs-ntor-curve25519-sha3-256-1:hs_key_extract"
tor_hs_ntor_t_hsmac: db "tor-hs-ntor-curve25519-sha3-256-1:hs_mac"
tor_hs_ntor_m_hsexpand: db "tor-hs-ntor-curve25519-sha3-256-1:hs_key_expand"
tor_hs_onion_checksum: db ".onion checksum"
tor_hs_onion_suffix: db ".onion"
tor_hs_base32_alphabet: db "abcdefghijklmnopqrstuvwxyz234567"
tor_hs_base64_alphabet: db "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
tor_hs_msg_begin: db "-----BEGIN MESSAGE-----", 10
tor_hs_msg_begin_len equ $ - tor_hs_msg_begin
tor_hs_msg_end: db "-----END MESSAGE-----"
tor_hs_msg_end_len equ $ - tor_hs_msg_end
tor_hs_edcert_begin: db "-----BEGIN ED25519 CERT-----"
tor_hs_edcert_begin_len equ $ - tor_hs_edcert_begin
tor_hs_edcert_end: db "-----END ED25519 CERT-----"
tor_hs_edcert_end_len equ $ - tor_hs_edcert_end
tor_hs_line_intro_point: db "introduction-point "
tor_hs_line_intro_point_len equ $ - tor_hs_line_intro_point
tor_hs_line_onion_key: db "onion-key ntor "
tor_hs_line_onion_key_len equ $ - tor_hs_line_onion_key
tor_hs_line_enc_key: db "enc-key ntor "
tor_hs_line_enc_key_len equ $ - tor_hs_line_enc_key
tor_hs_line_create2_formats: db "create2-formats 2", 10
tor_hs_line_create2_formats_len equ $ - tor_hs_line_create2_formats
tor_hs_line_auth_key: db "auth-key", 10
tor_hs_line_auth_key_len equ $ - tor_hs_line_auth_key
tor_hs_line_hs_descriptor: db "hs-descriptor 3", 10
tor_hs_line_hs_descriptor_len equ $ - tor_hs_line_hs_descriptor
tor_hs_line_descriptor_lifetime: db "descriptor-lifetime "
tor_hs_line_descriptor_lifetime_len equ $ - tor_hs_line_descriptor_lifetime
tor_hs_line_descriptor_signing_key_cert: db "descriptor-signing-key-cert", 10
tor_hs_line_descriptor_signing_key_cert_len equ $ - tor_hs_line_descriptor_signing_key_cert
tor_hs_line_revision_counter: db "revision-counter "
tor_hs_line_revision_counter_len equ $ - tor_hs_line_revision_counter
tor_hs_line_superencrypted: db "superencrypted", 10
tor_hs_line_superencrypted_len equ $ - tor_hs_line_superencrypted
tor_hs_line_signature: db "signature "
tor_hs_line_signature_len equ $ - tor_hs_line_signature
tor_hs_nl: db 10

SECTION .bss
tor_hs_msg: resb TOR_HS_RELAY_DATA_MAX
tor_hs_plain: resb TOR_HS_RELAY_DATA_MAX
tor_hs_encrypted: resb TOR_HS_RELAY_DATA_MAX
tor_hs_crypto_buf: resb TOR_HS_CRYPTO_BUF_MAX
tor_hs_desc_mac_buf: resb TOR_HS_DESCRIPTOR_MAX_LEN
tor_hs_zero_iv: resb 16
tor_hs_tmp_stream: resw 1
tor_hs_tmp_cmd: resb 1
tor_hs_tmp_len: resd 1
tor_hs_desc_auth_key: resb TOR_HS_INTRO_AUTH_KEY_LEN
tor_hs_desc_onion_key: resb TOR_HS_ONION_KEY_LEN_NTOR
tor_hs_desc_enc_key: resb TOR_HS_ONION_KEY_LEN_NTOR
tor_hs_desc_linkspecs_len: resd 1
tor_hs_desc_linkspecs: resb TOR_HS_RELAY_DATA_MAX
tor_hs_intro2_encrypted_ptr: resq 1
tor_hs_intro2_encrypted_len: resd 1

SECTION .text

_tor_hs_store_u64_be:
    mov     rax, rsi
    mov     [rdi + 7], al
    shr     rax, 8
    mov     [rdi + 6], al
    shr     rax, 8
    mov     [rdi + 5], al
    shr     rax, 8
    mov     [rdi + 4], al
    shr     rax, 8
    mov     [rdi + 3], al
    shr     rax, 8
    mov     [rdi + 2], al
    shr     rax, 8
    mov     [rdi + 1], al
    shr     rax, 8
    mov     [rdi], al
    ret

; er_tor_hs_build_onion_address(out62, public_identity_key32)
; Builds a Tor v3 onion address:
;   BASE32(public-key || SHA3_256(".onion checksum" || public-key || 0x03)[0..2] || 0x03) || ".onion"
; returns eax = 62, or -1.
global er_tor_hs_build_onion_address
er_fn er_tor_hs_build_onion_address
    push    rbx
    push    rbp
    push    r12
    push    r13
    push    r14
    push    r15
    mov     r12, rdi
    mov     r13, rsi
    test    r12, r12
    jz      .fail
    test    r13, r13
    jz      .fail

    lea     rdi, [rel tor_hs_crypto_buf]
    lea     rsi, [rel tor_hs_onion_checksum]
    mov     edx, 15
    call    er_memcpy
    lea     rdi, [rel tor_hs_crypto_buf + 15]
    mov     rsi, r13
    mov     edx, 32
    call    er_memcpy
    mov     byte [rel tor_hs_crypto_buf + 47], 3

    lea     rdi, [rel tor_hs_crypto_buf]
    mov     esi, 48
    lea     rdx, [rel tor_hs_crypto_buf + 128]
    call    er_sha3_256

    lea     rdi, [rel tor_hs_crypto_buf + 64]
    mov     rsi, r13
    mov     edx, 32
    call    er_memcpy
    movzx   eax, byte [rel tor_hs_crypto_buf + 128]
    mov     [rel tor_hs_crypto_buf + 96], al
    movzx   eax, byte [rel tor_hs_crypto_buf + 129]
    mov     [rel tor_hs_crypto_buf + 97], al
    mov     byte [rel tor_hs_crypto_buf + 98], 3

    lea     r14, [rel tor_hs_crypto_buf + 64]
    mov     r15, r12
    xor     ebx, ebx        ; bit accumulator
    xor     ebp, ebp        ; bits currently in accumulator
    mov     r11d, 35
.byte_loop:
    movzx   eax, byte [r14]
    inc     r14
    shl     rbx, 8
    or      rbx, rax
    add     ebp, 8
.emit_loop:
    cmp     ebp, 5
    jb      .mask_acc
    mov     ecx, ebp
    sub     ecx, 5
    mov     rax, rbx
    shr     rax, cl
    and     eax, 31
    mov     al, [rel tor_hs_base32_alphabet + rax]
    mov     [r15], al
    inc     r15
    sub     ebp, 5
    jmp     .emit_loop
.mask_acc:
    test    ebp, ebp
    jz      .next_byte
    mov     eax, 1
    mov     ecx, ebp
    shl     rax, cl
    dec     rax
    and     rbx, rax
.next_byte:
    dec     r11d
    jnz     .byte_loop

    mov     rdi, r15
    lea     rsi, [rel tor_hs_onion_suffix]
    mov     edx, 6
    call    er_memcpy
    mov     eax, 62
    er_ok
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    pop     rbx
    er_ret
.fail:
    mov     eax, -1
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    pop     rbx
    er_ret

; er_tor_hs_b64_encode(out, cap, input, input_len)
; Standard base64 with '=' padding. Returns encoded length, or -1.
global er_tor_hs_b64_encode
er_fn er_tor_hs_b64_encode
    push    rbx
    push    rbp
    push    r12
    push    r13
    push    r14
    push    r15
    mov     rbx, rdi
    mov     r12d, esi
    mov     r13, rdx
    mov     r14d, ecx
    test    rbx, rbx
    jz      .fail
    test    r14d, r14d
    jz      .empty
    test    r13, r13
    jz      .fail
    mov     eax, r14d
    add     eax, 2
    xor     edx, edx
    mov     ecx, 3
    div     ecx
    shl     eax, 2
    cmp     eax, r12d
    ja      .fail
    mov     r15d, eax
    xor     ebp, ebp
.loop:
    cmp     r14d, 3
    jb      .tail
    movzx   eax, byte [r13]
    shl     eax, 16
    movzx   ecx, byte [r13 + 1]
    shl     ecx, 8
    or      eax, ecx
    movzx   ecx, byte [r13 + 2]
    or      eax, ecx
    mov     ecx, eax
    shr     ecx, 18
    and     ecx, 63
    mov     cl, [rel tor_hs_base64_alphabet + rcx]
    mov     [rbx + rbp], cl
    mov     ecx, eax
    shr     ecx, 12
    and     ecx, 63
    mov     cl, [rel tor_hs_base64_alphabet + rcx]
    mov     [rbx + rbp + 1], cl
    mov     ecx, eax
    shr     ecx, 6
    and     ecx, 63
    mov     cl, [rel tor_hs_base64_alphabet + rcx]
    mov     [rbx + rbp + 2], cl
    and     eax, 63
    mov     al, [rel tor_hs_base64_alphabet + rax]
    mov     [rbx + rbp + 3], al
    add     r13, 3
    sub     r14d, 3
    add     ebp, 4
    jmp     .loop
.tail:
    test    r14d, r14d
    jz      .done
    movzx   eax, byte [r13]
    shl     eax, 16
    cmp     r14d, 2
    jne     .one_tail
    movzx   ecx, byte [r13 + 1]
    shl     ecx, 8
    or      eax, ecx
.one_tail:
    mov     ecx, eax
    shr     ecx, 18
    and     ecx, 63
    mov     cl, [rel tor_hs_base64_alphabet + rcx]
    mov     [rbx + rbp], cl
    mov     ecx, eax
    shr     ecx, 12
    and     ecx, 63
    mov     cl, [rel tor_hs_base64_alphabet + rcx]
    mov     [rbx + rbp + 1], cl
    cmp     r14d, 2
    jne     .pad_one
    mov     ecx, eax
    shr     ecx, 6
    and     ecx, 63
    mov     cl, [rel tor_hs_base64_alphabet + rcx]
    mov     [rbx + rbp + 2], cl
    mov     byte [rbx + rbp + 3], '='
    jmp     .done
.pad_one:
    mov     byte [rbx + rbp + 2], '='
    mov     byte [rbx + rbp + 3], '='
.done:
    mov     eax, r15d
    er_ok
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    pop     rbx
    er_ret
.empty:
    xor     eax, eax
    er_ok
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    pop     rbx
    er_ret
.fail:
    mov     eax, -1
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    pop     rbx
    er_ret

_tor_hs_b64_value:
    cmp     al, 'A'
    jb      .lower
    cmp     al, 'Z'
    ja      .lower
    sub     al, 'A'
    movzx   eax, al
    ret
.lower:
    cmp     al, 'a'
    jb      .digit
    cmp     al, 'z'
    ja      .digit
    sub     al, 'a'
    add     al, 26
    movzx   eax, al
    ret
.digit:
    cmp     al, '0'
    jb      .plus
    cmp     al, '9'
    ja      .plus
    sub     al, '0'
    add     al, 52
    movzx   eax, al
    ret
.plus:
    cmp     al, '+'
    jne     .slash
    mov     eax, 62
    ret
.slash:
    cmp     al, '/'
    jne     .bad
    mov     eax, 63
    ret
.bad:
    mov     eax, -1
    ret

; er_tor_hs_b64_decode(out, cap, input, input_len)
; Standard base64 decoder. Accepts CR/LF whitespace and '=' padding.
; Returns decoded length, or -1.
global er_tor_hs_b64_decode
er_fn er_tor_hs_b64_decode
    push    rbx
    push    rbp
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 8
    mov     rbx, rdi
    mov     r12d, esi
    mov     r13, rdx
    mov     r14d, ecx
    xor     r15d, r15d       ; output length
    xor     ebp, ebp         ; quartet length
    test    rbx, rbx
    jz      .fail
    test    r14d, r14d
    jz      .done
    test    r13, r13
    jz      .fail
.scan:
    test    r14d, r14d
    jz      .finish
    movzx   eax, byte [r13]
    inc     r13
    dec     r14d
    cmp     al, 10
    je      .scan
    cmp     al, 13
    je      .scan
    cmp     al, '='
    jne     .decode
    mov     byte [rsp + rbp], 64
    inc     ebp
    jmp     .maybe_emit
.decode:
    call    _tor_hs_b64_value
    test    eax, eax
    js      .fail
    mov     [rsp + rbp], al
    inc     ebp
.maybe_emit:
    cmp     ebp, 4
    jb      .scan
    movzx   eax, byte [rsp]
    cmp     eax, 64
    jae     .fail
    movzx   ecx, byte [rsp + 1]
    cmp     ecx, 64
    jae     .fail
    shl     eax, 18
    shl     ecx, 12
    or      eax, ecx
    movzx   ecx, byte [rsp + 2]
    cmp     ecx, 64
    je      .one_byte
    shl     ecx, 6
    or      eax, ecx
    movzx   ecx, byte [rsp + 3]
    cmp     ecx, 64
    je      .two_bytes
    or      eax, ecx
    mov     edx, 3
    jmp     .store
.one_byte:
    cmp     byte [rsp + 3], 64
    jne     .fail
    mov     edx, 1
    jmp     .store
.two_bytes:
    mov     edx, 2
.store:
    mov     ecx, r15d
    add     ecx, edx
    cmp     ecx, r12d
    ja      .fail
    cmp     edx, 1
    jb      .after_store
    mov     ecx, eax
    shr     ecx, 16
    mov     [rbx + r15], cl
    cmp     edx, 2
    jb      .after_store
    mov     ecx, eax
    shr     ecx, 8
    mov     [rbx + r15 + 1], cl
    cmp     edx, 3
    jb      .after_store
    mov     [rbx + r15 + 2], al
.after_store:
    add     r15d, edx
    xor     ebp, ebp
    cmp     edx, 3
    jne     .padding_seen
    jmp     .scan
.padding_seen:
    ; Only whitespace may follow padding.
    test    r14d, r14d
    jz      .finish
    movzx   eax, byte [r13]
    inc     r13
    dec     r14d
    cmp     al, 10
    je      .padding_seen
    cmp     al, 13
    je      .padding_seen
    jmp     .fail
.finish:
    test    ebp, ebp
    jnz     .fail
.done:
    mov     eax, r15d
    er_ok
    add     rsp, 8
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    pop     rbx
    er_ret
.fail:
    mov     eax, -1
    add     rsp, 8
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    pop     rbx
    er_ret

; er_tor_hs_desc_armor_message(out, cap, blob, blob_len)
; Builds descriptor MESSAGE armor around standard base64.
global er_tor_hs_desc_armor_message
er_fn er_tor_hs_desc_armor_message
    push    rbx
    push    r12
    push    r13
    push    r14
    mov     rbx, rdi
    mov     r12d, esi
    mov     r13, rdx
    mov     r14d, ecx
    test    rbx, rbx
    jz      .fail
    test    r14d, r14d
    jz      .fail
    test    r13, r13
    jz      .fail
    mov     eax, r14d
    add     eax, 2
    xor     edx, edx
    mov     ecx, 3
    div     ecx
    shl     eax, 2
    add     eax, tor_hs_msg_begin_len + tor_hs_msg_end_len + 1
    cmp     eax, r12d
    ja      .fail

    mov     rdi, rbx
    lea     rsi, [rel tor_hs_msg_begin]
    mov     edx, tor_hs_msg_begin_len
    call    er_memcpy
    lea     rdi, [rbx + tor_hs_msg_begin_len]
    mov     esi, r12d
    sub     esi, tor_hs_msg_begin_len
    mov     rdx, r13
    mov     ecx, r14d
    call    er_tor_hs_b64_encode
    test    eax, eax
    js      .fail
    mov     r12d, eax
    lea     rdi, [rbx + tor_hs_msg_begin_len + r12]
    mov     byte [rdi], 10
    inc     rdi
    lea     rsi, [rel tor_hs_msg_end]
    mov     edx, tor_hs_msg_end_len
    call    er_memcpy
    mov     eax, tor_hs_msg_begin_len + tor_hs_msg_end_len + 1
    add     eax, r12d
    er_ok
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret
.fail:
    mov     eax, -1
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

; er_tor_hs_desc_unarmor_message(out, cap, armor, armor_len)
; Extracts and base64-decodes a single descriptor MESSAGE armor block.
global er_tor_hs_desc_unarmor_message
er_fn er_tor_hs_desc_unarmor_message
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    mov     rbx, rdi
    mov     r12d, esi
    mov     r13, rdx
    mov     r14d, ecx
    test    rbx, rbx
    jz      .fail
    test    r13, r13
    jz      .fail
    mov     eax, tor_hs_msg_begin_len + tor_hs_msg_end_len + 1
    cmp     r14d, eax
    jb      .fail
    mov     rdi, r13
    lea     rsi, [rel tor_hs_msg_begin]
    mov     edx, tor_hs_msg_begin_len
    call    _tor_hs_mem_eq
    test    eax, eax
    jz      .fail
    lea     r15, [r13 + tor_hs_msg_begin_len]
    mov     eax, r14d
    sub     eax, tor_hs_msg_end_len
    lea     rdi, [r13 + rax]
    lea     rsi, [rel tor_hs_msg_end]
    mov     edx, tor_hs_msg_end_len
    call    _tor_hs_mem_eq
    test    eax, eax
    jz      .fail
    mov     eax, r14d
    sub     eax, tor_hs_msg_begin_len + tor_hs_msg_end_len
    test    eax, eax
    jz      .fail
    cmp     byte [r13 + r14 - tor_hs_msg_end_len - 1], 10
    jne     .decode_ready
    dec     eax
.decode_ready:
    mov     rdi, rbx
    mov     esi, r12d
    mov     rdx, r15
    mov     ecx, eax
    call    er_tor_hs_b64_decode
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret
.fail:
    mov     eax, -1
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

; er_tor_hs_cert_armor_ed25519(out, cap, cert, cert_len)
; Builds Tor ED25519 CERT armor around a decoded certificate.
global er_tor_hs_cert_armor_ed25519
er_fn er_tor_hs_cert_armor_ed25519
    push    rbx
    push    r12
    push    r13
    push    r14
    mov     rbx, rdi
    mov     r12d, esi
    mov     r13, rdx
    mov     r14d, ecx
    test    rbx, rbx
    jz      .fail
    test    r13, r13
    jz      .fail
    test    r14d, r14d
    jz      .fail
    mov     eax, r14d
    add     eax, 2
    xor     edx, edx
    mov     ecx, 3
    div     ecx
    shl     eax, 2
    add     eax, tor_hs_edcert_begin_len + tor_hs_edcert_end_len + 3
    cmp     eax, r12d
    ja      .fail

    mov     rdi, rbx
    lea     rsi, [rel tor_hs_edcert_begin]
    mov     edx, tor_hs_edcert_begin_len
    call    er_memcpy
    mov     byte [rbx + tor_hs_edcert_begin_len], 10
    lea     rdi, [rbx + tor_hs_edcert_begin_len + 1]
    mov     esi, r12d
    sub     esi, tor_hs_edcert_begin_len + 1
    mov     rdx, r13
    mov     ecx, r14d
    call    er_tor_hs_b64_encode
    test    eax, eax
    js      .fail
    mov     r12d, eax
    lea     rdi, [rbx + tor_hs_edcert_begin_len + 1 + r12]
    mov     byte [rdi], 10
    inc     rdi
    lea     rsi, [rel tor_hs_edcert_end]
    mov     edx, tor_hs_edcert_end_len
    call    er_memcpy
    mov     byte [rbx + tor_hs_edcert_begin_len + 1 + r12 + 1 + tor_hs_edcert_end_len], 10
    mov     eax, tor_hs_edcert_begin_len + tor_hs_edcert_end_len + 3
    add     eax, r12d
    er_ok
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret
.fail:
    mov     eax, -1
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

; er_tor_hs_mac_key32(out, key32, msg, msg_len)
; Descriptor MAC: SHA3_256(ENCAP(key32) || msg), where ENCAP is u64 length.
global er_tor_hs_mac_key32
er_fn er_tor_hs_mac_key32
    push    rbx
    push    r12
    push    r13
    push    r14
    mov     rbx, rdi
    mov     r12, rsi
    mov     r13, rdx
    mov     r14d, ecx
    test    rbx, rbx
    jz      .fail
    test    r12, r12
    jz      .fail
    test    r14d, r14d
    jz      .msg_ready
    test    r13, r13
    jz      .fail
.msg_ready:
    mov     eax, TOR_HS_ENCAP_LEN + TOR_HS_MAC_KEY_LEN
    add     eax, r14d
    cmp     eax, TOR_HS_DESCRIPTOR_MAX_LEN
    ja      .fail

    lea     rdi, [rel tor_hs_desc_mac_buf]
    mov     esi, TOR_HS_MAC_KEY_LEN
    call    _tor_hs_store_u64_be
    lea     rdi, [rel tor_hs_desc_mac_buf + TOR_HS_ENCAP_LEN]
    mov     rsi, r12
    mov     edx, TOR_HS_MAC_KEY_LEN
    call    er_memcpy
    test    r14d, r14d
    jz      .hash
    lea     rdi, [rel tor_hs_desc_mac_buf + TOR_HS_ENCAP_LEN + TOR_HS_MAC_KEY_LEN]
    mov     rsi, r13
    mov     edx, r14d
    call    er_memcpy
.hash:
    lea     rdi, [rel tor_hs_desc_mac_buf]
    mov     esi, TOR_HS_ENCAP_LEN + TOR_HS_MAC_KEY_LEN
    add     esi, r14d
    mov     rdx, rbx
    call    er_sha3_256
    er_ok
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret
.fail:
    mov     eax, -1
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

; er_tor_hs_desc_encrypt(out, cap, secret_data, secret_len, subcred,
;                        revision_counter, salt16, constant, constant_len,
;                        plaintext, plaintext_len)
; Builds one Tor v3 descriptor encrypted layer:
;   SALT || AES256_CTR(plaintext, key, iv) || MAC
; with keys derived by SHAKE256(secret_data || subcred || rev64 || salt || constant).
; Returns eax = encrypted blob length, or -1.
global er_tor_hs_desc_encrypt
er_fn er_tor_hs_desc_encrypt
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 8
    mov     rbx, rdi        ; out
    mov     r12d, esi       ; cap
    mov     r13, rdx        ; secret_data
    mov     r14d, ecx       ; secret_len
    mov     r15, r8         ; subcred
    mov     [rsp], r9       ; revision_counter
    test    rbx, rbx
    jz      .fail
    test    r13, r13
    jz      .fail
    test    r15, r15
    jz      .fail
    cmp     qword [rbp + 16], 0
    je      .fail
    cmp     qword [rbp + 24], 0
    je      .fail
    cmp     qword [rbp + 40], 0
    je      .fail
    mov     eax, [rbp + 48]
    cmp     eax, TOR_HS_DESCRIPTOR_MAX_LEN - TOR_HS_DESCRIPTOR_ENC_OVERHEAD
    ja      .fail
    add     eax, TOR_HS_DESCRIPTOR_ENC_OVERHEAD
    cmp     eax, r12d
    ja      .fail
    mov     eax, r14d
    add     eax, TOR_HS_SUBCRED_LEN + 8 + TOR_HS_DESCRIPTOR_SALT_LEN
    add     eax, [rbp + 32]
    cmp     eax, TOR_HS_CRYPTO_BUF_MAX
    ja      .fail

    lea     rdi, [rel tor_hs_crypto_buf]
    mov     rsi, r13
    mov     edx, r14d
    call    er_memcpy
    lea     rdi, [rel tor_hs_crypto_buf + r14]
    mov     rsi, r15
    mov     edx, TOR_HS_SUBCRED_LEN
    call    er_memcpy
    lea     rdi, [rel tor_hs_crypto_buf + r14 + TOR_HS_SUBCRED_LEN]
    mov     rsi, [rsp]
    call    _tor_hs_store_u64_be
    mov     eax, r14d
    add     eax, TOR_HS_SUBCRED_LEN + 8
    lea     rdi, [rel tor_hs_crypto_buf + rax]
    mov     rsi, [rbp + 16]
    mov     edx, TOR_HS_DESCRIPTOR_SALT_LEN
    call    er_memcpy
    mov     eax, r14d
    add     eax, TOR_HS_SUBCRED_LEN + 8 + TOR_HS_DESCRIPTOR_SALT_LEN
    lea     rdi, [rel tor_hs_crypto_buf + rax]
    mov     rsi, [rbp + 24]
    mov     edx, [rbp + 32]
    call    er_memcpy

    lea     rdi, [rel tor_hs_crypto_buf]
    mov     esi, r14d
    add     esi, TOR_HS_SUBCRED_LEN + 8 + TOR_HS_DESCRIPTOR_SALT_LEN
    add     esi, [rbp + 32]
    lea     rdx, [rel tor_hs_crypto_buf + 512]
    mov     ecx, TOR_HS_DESCRIPTOR_KEY_LEN + TOR_HS_DESCRIPTOR_IV_LEN + TOR_HS_DESCRIPTOR_MAC_LEN
    call    er_shake256

    mov     rdi, rbx
    mov     rsi, [rbp + 16]
    mov     edx, TOR_HS_DESCRIPTOR_SALT_LEN
    call    er_memcpy
    lea     rdi, [rbx + TOR_HS_DESCRIPTOR_SALT_LEN]
    mov     rsi, [rbp + 40]
    mov     edx, [rbp + 48]
    lea     rcx, [rel tor_hs_crypto_buf + 512]
    lea     r8, [rel tor_hs_crypto_buf + 512 + TOR_HS_DESCRIPTOR_KEY_LEN]
    call    er_tor_aes256_ctr

    mov     eax, [rbp + 48]
    add     eax, TOR_HS_DESCRIPTOR_SALT_LEN
    lea     rdi, [rbx + rax]
    lea     rsi, [rel tor_hs_crypto_buf + 512 + TOR_HS_DESCRIPTOR_KEY_LEN + TOR_HS_DESCRIPTOR_IV_LEN]
    mov     rdx, rbx
    mov     ecx, eax
    call    er_tor_hs_mac_key32
    test    eax, eax
    js      .fail
    mov     eax, [rbp + 48]
    add     eax, TOR_HS_DESCRIPTOR_ENC_OVERHEAD
    er_ok
    add     rsp, 8
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    er_ret
.fail:
    mov     eax, -1
    add     rsp, 8
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    er_ret

; er_tor_hs_desc_decrypt(out_plain, cap, out_len, secret_data, secret_len,
;                        subcred, revision_counter, constant, constant_len,
;                        blob, blob_len)
; Verifies and decrypts one descriptor encrypted layer.
global er_tor_hs_desc_decrypt
er_fn er_tor_hs_desc_decrypt
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 24
    mov     rbx, rdi        ; out_plain
    mov     r12d, esi       ; cap
    mov     r13, rdx        ; out_len
    mov     r14, rcx        ; secret_data
    mov     r15d, r8d       ; secret_len
    mov     [rsp], r9       ; subcred
    test    rbx, rbx
    jz      .fail
    test    r13, r13
    jz      .fail
    test    r14, r14
    jz      .fail
    cmp     qword [rsp], 0
    je      .fail
    cmp     qword [rbp + 24], 0
    je      .fail
    cmp     qword [rbp + 40], 0
    je      .fail
    mov     eax, [rbp + 48]
    cmp     eax, TOR_HS_DESCRIPTOR_ENC_OVERHEAD
    jb      .fail
    cmp     eax, TOR_HS_DESCRIPTOR_MAX_LEN
    ja      .fail
    sub     eax, TOR_HS_DESCRIPTOR_ENC_OVERHEAD
    cmp     eax, r12d
    ja      .fail
    mov     [r13], eax
    mov     eax, r15d
    add     eax, TOR_HS_SUBCRED_LEN + 8 + TOR_HS_DESCRIPTOR_SALT_LEN
    add     eax, [rbp + 32]
    cmp     eax, TOR_HS_CRYPTO_BUF_MAX
    ja      .fail

    lea     rdi, [rel tor_hs_crypto_buf]
    mov     rsi, r14
    mov     edx, r15d
    call    er_memcpy
    lea     rdi, [rel tor_hs_crypto_buf + r15]
    mov     rsi, [rsp]
    mov     edx, TOR_HS_SUBCRED_LEN
    call    er_memcpy
    lea     rdi, [rel tor_hs_crypto_buf + r15 + TOR_HS_SUBCRED_LEN]
    mov     rsi, [rbp + 16]
    call    _tor_hs_store_u64_be
    mov     eax, r15d
    add     eax, TOR_HS_SUBCRED_LEN + 8
    lea     rdi, [rel tor_hs_crypto_buf + rax]
    mov     rsi, [rbp + 40]
    mov     edx, TOR_HS_DESCRIPTOR_SALT_LEN
    call    er_memcpy
    mov     eax, r15d
    add     eax, TOR_HS_SUBCRED_LEN + 8 + TOR_HS_DESCRIPTOR_SALT_LEN
    lea     rdi, [rel tor_hs_crypto_buf + rax]
    mov     rsi, [rbp + 24]
    mov     edx, [rbp + 32]
    call    er_memcpy

    lea     rdi, [rel tor_hs_crypto_buf]
    mov     esi, r15d
    add     esi, TOR_HS_SUBCRED_LEN + 8 + TOR_HS_DESCRIPTOR_SALT_LEN
    add     esi, [rbp + 32]
    lea     rdx, [rel tor_hs_crypto_buf + 512]
    mov     ecx, TOR_HS_DESCRIPTOR_KEY_LEN + TOR_HS_DESCRIPTOR_IV_LEN + TOR_HS_DESCRIPTOR_MAC_LEN
    call    er_shake256

    lea     rdi, [rel tor_hs_crypto_buf + 608]
    lea     rsi, [rel tor_hs_crypto_buf + 512 + TOR_HS_DESCRIPTOR_KEY_LEN + TOR_HS_DESCRIPTOR_IV_LEN]
    mov     rdx, [rbp + 40]
    mov     ecx, [rbp + 48]
    sub     ecx, TOR_HS_DESCRIPTOR_MAC_LEN
    call    er_tor_hs_mac_key32
    test    eax, eax
    js      .fail
    mov     rsi, [rbp + 40]
    mov     ecx, [rbp + 48]
    sub     ecx, TOR_HS_DESCRIPTOR_MAC_LEN
    add     rsi, rcx
    lea     rdi, [rel tor_hs_crypto_buf + 608]
    mov     edx, TOR_HS_DESCRIPTOR_MAC_LEN
    call    _tor_hs_mem_eq
    test    eax, eax
    jz      .fail

    mov     rdi, rbx
    mov     rsi, [rbp + 40]
    add     rsi, TOR_HS_DESCRIPTOR_SALT_LEN
    mov     edx, [r13]
    lea     rcx, [rel tor_hs_crypto_buf + 512]
    lea     r8, [rel tor_hs_crypto_buf + 512 + TOR_HS_DESCRIPTOR_KEY_LEN]
    call    er_tor_aes256_ctr
    xor     eax, eax
    er_ok
    add     rsp, 24
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    er_ret
.fail:
    mov     eax, -1
    add     rsp, 24
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    er_ret

; er_tor_hs_cert_build(out, cap, cert_type, expiration_hours,
;                      certified_key32, signing_key_ext32_or_null, sig64)
; Builds a Tor v1 Ed25519 certificate body. CERT_KEY_TYPE is Ed25519 (1);
; when signing_key_ext32 is non-null, extension type 4 is emitted.
global er_tor_hs_cert_build
er_fn er_tor_hs_cert_build
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    push    r9
    mov     rbx, rdi
    mov     r12d, esi
    mov     r13d, edx
    mov     r14d, ecx
    mov     r15, r8
    test    rbx, rbx
    jz      .fail
    test    r15, r15
    jz      .fail
    cmp     qword [rbp + 16], 0
    je      .fail
    test    r13d, r13d
    jz      .fail
    cmp     r13d, 255
    ja      .fail
    mov     eax, 104
    cmp     qword [rsp], 0
    je      .len_ready
    mov     eax, 140
.len_ready:
    cmp     r12d, eax
    jb      .fail
    mov     byte [rbx], 1
    mov     [rbx + 1], r13b
    mov     eax, r14d
    bswap   eax
    mov     [rbx + 2], eax
    mov     byte [rbx + 6], 1
    lea     rdi, [rbx + 7]
    mov     rsi, r15
    mov     edx, 32
    call    er_memcpy

    mov     rax, [rsp]
    test    rax, rax
    jz      .no_ext
    mov     byte [rbx + 39], 1
    mov     byte [rbx + 40], 0
    mov     byte [rbx + 41], 32
    mov     byte [rbx + 42], 4
    mov     byte [rbx + 43], 0
    lea     rdi, [rbx + 44]
    mov     rsi, rax
    mov     edx, 32
    call    er_memcpy
    lea     rdi, [rbx + 76]
    mov     rsi, [rbp + 16]
    mov     edx, 64
    call    er_memcpy
    mov     eax, 140
    jmp     .done
.no_ext:
    mov     byte [rbx + 39], 0
    lea     rdi, [rbx + 40]
    mov     rsi, [rbp + 16]
    mov     edx, 64
    call    er_memcpy
    mov     eax, 104
.done:
    er_ok
    add     rsp, 8
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    er_ret
.fail:
    mov     eax, -1
    add     rsp, 8
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    er_ret

; er_tor_hs_cert_get_certified_key(out32, cert, cert_len)
; Extracts CERTIFIED_KEY from a decoded Tor Ed25519 certificate.
global er_tor_hs_cert_get_certified_key
er_fn er_tor_hs_cert_get_certified_key
    test    rdi, rdi
    jz      .fail
    test    rsi, rsi
    jz      .fail
    cmp     edx, 104
    jb      .fail
    cmp     byte [rsi], 1
    jne     .fail
    lea     rsi, [rsi + 7]
    mov     edx, 32
    call    er_memcpy
    mov     eax, 0
    er_ok
    er_ret
.fail:
    mov     eax, -1
    er_ret

; er_tor_hs_cert_get_signing_key_ext(out32, cert, cert_len)
; Extracts proposal-220 extension type 04, the signing Ed25519 public key.
global er_tor_hs_cert_get_signing_key_ext
er_fn er_tor_hs_cert_get_signing_key_ext
    push    rbx
    push    r12
    push    r13
    push    r14
    mov     rbx, rdi
    mov     r12, rsi
    mov     r13d, edx
    test    rbx, rbx
    jz      .fail
    test    r12, r12
    jz      .fail
    cmp     r13d, 104
    jb      .fail
    cmp     byte [r12], 1
    jne     .fail
    movzx   r14d, byte [r12 + 39]
    mov     ecx, 40
.loop:
    test    r14d, r14d
    jz      .fail
    mov     eax, ecx
    add     eax, 4
    cmp     eax, r13d
    ja      .fail
    movzx   eax, byte [r12 + rcx]
    shl     eax, 8
    movzx   edx, byte [r12 + rcx + 1]
    or      eax, edx        ; ext len
    mov     edx, ecx
    add     edx, 4
    add     edx, eax
    cmp     edx, r13d
    ja      .fail
    cmp     byte [r12 + rcx + 2], 4
    jne     .next
    cmp     eax, 32
    jne     .fail
    mov     rdi, rbx
    lea     rsi, [r12 + rcx + 4]
    mov     edx, 32
    call    er_memcpy
    xor     eax, eax
    er_ok
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret
.next:
    mov     ecx, edx
    dec     r14d
    jmp     .loop
.fail:
    mov     eax, -1
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

; er_tor_hs_desc_parse_intro(out_auth_key32, out_onion_key32, out_enc_key32,
;                            out_linkspecs, linkspecs_cap, out_linkspecs_len,
;                            plaintext, plaintext_len)
; Parses the first introduction point from decrypted second-layer descriptor
; plaintext into the fields needed by er_tor_hs_client_connect.
global er_tor_hs_desc_parse_intro
er_fn er_tor_hs_desc_parse_intro
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 16
    mov     rbx, rdi
    mov     r12, rsi
    mov     r13, rdx
    mov     r14, rcx
    mov     r15d, r8d
    mov     [rsp], r9
    test    rbx, rbx
    jz      .fail
    test    r12, r12
    jz      .fail
    test    r13, r13
    jz      .fail
    test    r14, r14
    jz      .fail
    cmp     qword [rsp], 0
    je      .fail
    cmp     qword [rbp + 16], 0
    je      .fail
    cmp     dword [rbp + 24], 0
    jle     .fail

    mov     rdi, [rbp + 16]
    mov     esi, [rbp + 24]
    lea     rdx, [rel tor_hs_line_intro_point]
    mov     ecx, tor_hs_line_intro_point_len
    call    _tor_hs_find_line_value
    test    rax, rax
    jz      .fail
    mov     rdi, r14
    mov     esi, r15d
    mov     rcx, rdx
    mov     rdx, rax
    call    er_tor_hs_b64_decode
    test    eax, eax
    jle     .fail
    mov     rcx, [rsp]
    mov     [rcx], eax

    mov     rdi, [rbp + 16]
    mov     esi, [rbp + 24]
    lea     rdx, [rel tor_hs_line_onion_key]
    mov     ecx, tor_hs_line_onion_key_len
    call    _tor_hs_find_line_value
    test    rax, rax
    jz      .fail
    lea     rdi, [rel tor_hs_crypto_buf]
    mov     esi, TOR_HS_ONION_KEY_LEN_NTOR
    mov     rcx, rdx
    mov     rdx, rax
    call    er_tor_hs_b64_decode
    cmp     eax, TOR_HS_ONION_KEY_LEN_NTOR
    jne     .fail
    mov     rdi, r12
    lea     rsi, [rel tor_hs_crypto_buf]
    mov     edx, TOR_HS_ONION_KEY_LEN_NTOR
    call    er_memcpy

    mov     rdi, [rbp + 16]
    mov     esi, [rbp + 24]
    lea     rdx, [rel tor_hs_line_enc_key]
    mov     ecx, tor_hs_line_enc_key_len
    call    _tor_hs_find_line_value
    test    rax, rax
    jz      .fail
    lea     rdi, [rel tor_hs_crypto_buf]
    mov     esi, TOR_HS_ONION_KEY_LEN_NTOR
    mov     rcx, rdx
    mov     rdx, rax
    call    er_tor_hs_b64_decode
    cmp     eax, TOR_HS_ONION_KEY_LEN_NTOR
    jne     .fail
    mov     rdi, r13
    lea     rsi, [rel tor_hs_crypto_buf]
    mov     edx, TOR_HS_ONION_KEY_LEN_NTOR
    call    er_memcpy

    mov     rdi, [rbp + 16]
    mov     esi, [rbp + 24]
    lea     rdx, [rel tor_hs_edcert_begin]
    mov     ecx, tor_hs_edcert_begin_len
    call    _tor_hs_find_marker
    test    rax, rax
    jz      .fail
    add     rax, tor_hs_edcert_begin_len
.skip_cert_lf:
    cmp     byte [rax], 13
    je      .skip_one
    cmp     byte [rax], 10
    jne     .cert_body_ready
.skip_one:
    inc     rax
    jmp     .skip_cert_lf
.cert_body_ready:
    mov     [rsp + 8], rax
    mov     rdi, rax
    mov     rsi, rax
    sub     rsi, [rbp + 16]
    mov     eax, [rbp + 24]
    sub     eax, esi
    mov     esi, eax
    lea     rdx, [rel tor_hs_edcert_end]
    mov     ecx, tor_hs_edcert_end_len
    call    _tor_hs_find_marker
    test    rax, rax
    jz      .fail
    mov     rdx, [rsp + 8]
    mov     rcx, rax
    sub     rcx, rdx
    lea     rdi, [rel tor_hs_desc_mac_buf]
    mov     esi, 1024
    call    er_tor_hs_b64_decode
    cmp     eax, 104
    jb      .fail
    mov     rdi, rbx
    lea     rsi, [rel tor_hs_desc_mac_buf]
    mov     edx, eax
    call    er_tor_hs_cert_get_certified_key
    test    eax, eax
    js      .fail

    xor     eax, eax
    er_ok
    add     rsp, 16
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    er_ret
.fail:
    mov     eax, -1
    add     rsp, 16
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    er_ret

; er_tor_hs_parse_linkspecs(out_legacy_id20, out_ipv4, out_port,
;                           linkspecs, linkspecs_len)
; Parses v3 onion-service link specifiers from an introduction point.
; Supports the fields needed to build a circuit to the intro relay:
;   type 0: IPv4 + ORPort, length 6
;   type 2: legacy identity digest, length 20
; Stores IPv4 bytes in wire order and port as host-order u16.
global er_tor_hs_parse_linkspecs
er_fn er_tor_hs_parse_linkspecs
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    mov     rbx, rdi        ; out_legacy_id20
    mov     r12, rsi        ; out_ipv4
    mov     r13, rdx        ; out_port
    mov     r14, rcx        ; linkspecs
    mov     r15d, r8d       ; linkspecs_len
    xor     r9d, r9d        ; cursor
    xor     r10d, r10d      ; bit0=ipv4 bit1=legacy id
    test    rbx, rbx
    jz      .fail
    test    r12, r12
    jz      .fail
    test    r13, r13
    jz      .fail
    test    r14, r14
    jz      .fail
    test    r15d, r15d
    jle     .fail

.loop:
    cmp     r9d, r15d
    jae     .done
    mov     eax, r15d
    sub     eax, r9d
    cmp     eax, 2
    jb      .fail
    movzx   eax, byte [r14 + r9]
    movzx   r11d, byte [r14 + r9 + 1]
    add     r9d, 2
    mov     ecx, r15d
    sub     ecx, r9d
    cmp     r11d, ecx
    ja      .fail
    cmp     eax, 0
    je      .ipv4
    cmp     eax, 2
    je      .legacy_id
.skip:
    add     r9d, r11d
    jmp     .loop

.ipv4:
    cmp     r11d, 6
    jne     .skip
    mov     eax, [r14 + r9]
    mov     [r12], eax
    movzx   eax, byte [r14 + r9 + 4]
    shl     eax, 8
    movzx   ecx, byte [r14 + r9 + 5]
    or      eax, ecx
    mov     [r13], ax
    or      r10d, 1
    add     r9d, r11d
    jmp     .loop

.legacy_id:
    cmp     r11d, 20
    jne     .skip
    mov     rdi, rbx
    lea     rsi, [r14 + r9]
    mov     edx, 20
    call    er_memcpy
    or      r10d, 2
    add     r9d, r11d
    jmp     .loop

.done:
    cmp     r10d, 3
    jne     .fail
    xor     eax, eax
    er_ok
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret
.fail:
    mov     eax, -1
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

; er_tor_hs_build_linkspecs(out, ipv4_wire, port, legacy_id20)
; Serializes type 0 IPv4+ORPort and type 2 legacy identity digest.
; returns eax = raw linkspec byte length, or -1.
global er_tor_hs_build_linkspecs
er_fn er_tor_hs_build_linkspecs
    push    rbx
    mov     rbx, rdi
    test    rbx, rbx
    jz      .fail
    test    rcx, rcx
    jz      .fail
    cmp     edx, 65535
    ja      .fail
    mov     byte [rbx], 0
    mov     byte [rbx + 1], 6
    mov     [rbx + 2], esi
    mov     eax, edx
    shr     eax, 8
    mov     [rbx + 6], al
    mov     [rbx + 7], dl
    mov     byte [rbx + 8], 2
    mov     byte [rbx + 9], 20
    lea     rdi, [rbx + 10]
    mov     rsi, rcx
    mov     edx, 20
    call    er_memcpy
    mov     eax, 30
    er_ok
    pop     rbx
    er_ret
.fail:
    mov     eax, -1
    pop     rbx
    er_ret

; er_tor_hs_desc_build_intro_plaintext(out, cap, linkspecs, linkspecs_len,
;                                      onion_key32, auth_cert_armor,
;                                      auth_cert_len, enc_key32)
; Emits the intro-point section used inside v3 second-layer descriptor text.
global er_tor_hs_desc_build_intro_plaintext
er_fn er_tor_hs_desc_build_intro_plaintext
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 16
    mov     rbx, rdi        ; out base/cursor
    mov     r12d, esi       ; cap
    mov     r13, rdx        ; linkspecs
    mov     r14d, ecx       ; linkspecs_len
    mov     r15, r8         ; onion key
    mov     [rbp - 48], r9  ; auth cert armor
    mov     [rbp - 56], rbx ; out base
    test    rbx, rbx
    jz      .fail
    test    r12d, r12d
    jle     .fail
    test    r13, r13
    jz      .fail
    test    r14d, r14d
    jle     .fail
    test    r15, r15
    jz      .fail
    cmp     qword [rbp - 48], 0
    je      .fail
    cmp     dword [rbp + 16], 0
    jle     .fail
    cmp     qword [rbp + 24], 0
    je      .fail

    lea     r12, [rbx + r12] ; end
    mov     rdi, rbx
    mov     rsi, r12
    lea     rdx, [rel tor_hs_line_create2_formats]
    mov     ecx, tor_hs_line_create2_formats_len
    call    _tor_hs_append_checked
    test    rax, rax
    jz      .fail
    mov     rbx, rax

    mov     rdi, rbx
    mov     rsi, r12
    lea     rdx, [rel tor_hs_line_intro_point]
    mov     ecx, tor_hs_line_intro_point_len
    call    _tor_hs_append_checked
    test    rax, rax
    jz      .fail
    mov     rbx, rax
    lea     rdi, [rel tor_hs_desc_mac_buf]
    mov     esi, TOR_HS_DESCRIPTOR_MAX_LEN
    mov     rdx, r13
    mov     ecx, r14d
    call    er_tor_hs_b64_encode
    test    eax, eax
    js      .fail
    mov     rdi, rbx
    mov     rsi, r12
    lea     rdx, [rel tor_hs_desc_mac_buf]
    mov     ecx, eax
    call    _tor_hs_append_checked
    test    rax, rax
    jz      .fail
    mov     rbx, rax
    mov     rdi, rbx
    mov     rsi, r12
    lea     rdx, [rel tor_hs_nl]
    mov     ecx, 1
    call    _tor_hs_append_checked
    test    rax, rax
    jz      .fail
    mov     rbx, rax

    mov     rdi, rbx
    mov     rsi, r12
    lea     rdx, [rel tor_hs_line_onion_key]
    mov     ecx, tor_hs_line_onion_key_len
    call    _tor_hs_append_checked
    test    rax, rax
    jz      .fail
    mov     rbx, rax
    lea     rdi, [rel tor_hs_desc_mac_buf]
    mov     esi, TOR_HS_DESCRIPTOR_MAX_LEN
    mov     rdx, r15
    mov     ecx, TOR_HS_ONION_KEY_LEN_NTOR
    call    er_tor_hs_b64_encode
    test    eax, eax
    js      .fail
    mov     rdi, rbx
    mov     rsi, r12
    lea     rdx, [rel tor_hs_desc_mac_buf]
    mov     ecx, eax
    call    _tor_hs_append_checked
    test    rax, rax
    jz      .fail
    mov     rbx, rax
    mov     rdi, rbx
    mov     rsi, r12
    lea     rdx, [rel tor_hs_nl]
    mov     ecx, 1
    call    _tor_hs_append_checked
    test    rax, rax
    jz      .fail
    mov     rbx, rax

    mov     rdi, rbx
    mov     rsi, r12
    lea     rdx, [rel tor_hs_line_auth_key]
    mov     ecx, tor_hs_line_auth_key_len
    call    _tor_hs_append_checked
    test    rax, rax
    jz      .fail
    mov     rbx, rax
    mov     rdi, rbx
    mov     rsi, r12
    mov     rdx, [rbp - 48]
    mov     ecx, [rbp + 16]
    call    _tor_hs_append_checked
    test    rax, rax
    jz      .fail
    mov     rbx, rax
    cmp     byte [rbx - 1], 10
    je      .enc_line
    mov     rdi, rbx
    mov     rsi, r12
    lea     rdx, [rel tor_hs_nl]
    mov     ecx, 1
    call    _tor_hs_append_checked
    test    rax, rax
    jz      .fail
    mov     rbx, rax

.enc_line:
    mov     rdi, rbx
    mov     rsi, r12
    lea     rdx, [rel tor_hs_line_enc_key]
    mov     ecx, tor_hs_line_enc_key_len
    call    _tor_hs_append_checked
    test    rax, rax
    jz      .fail
    mov     rbx, rax
    lea     rdi, [rel tor_hs_desc_mac_buf]
    mov     esi, TOR_HS_DESCRIPTOR_MAX_LEN
    mov     rdx, [rbp + 24]
    mov     ecx, TOR_HS_ONION_KEY_LEN_NTOR
    call    er_tor_hs_b64_encode
    test    eax, eax
    js      .fail
    mov     rdi, rbx
    mov     rsi, r12
    lea     rdx, [rel tor_hs_desc_mac_buf]
    mov     ecx, eax
    call    _tor_hs_append_checked
    test    rax, rax
    jz      .fail
    mov     rbx, rax
    mov     rdi, rbx
    mov     rsi, r12
    lea     rdx, [rel tor_hs_nl]
    mov     ecx, 1
    call    _tor_hs_append_checked
    test    rax, rax
    jz      .fail
    sub     rax, [rbp - 56]
    er_ok
    add     rsp, 16
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    er_ret
.fail:
    mov     eax, -1
    add     rsp, 16
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    er_ret

; er_tor_hs_desc_build_v3(out, cap, blinded_key_b64, blinded_len,
;                         signing_cert_armor, signing_cert_len,
;                         revision_counter, lifetime_minutes,
;                         superencrypted_armor, superencrypted_len, sig64)
; Assembles a complete v3 onion-service descriptor text body. The encrypted
; layer and Ed25519 signature are supplied by the caller.
global er_tor_hs_desc_build_v3
er_fn er_tor_hs_desc_build_v3
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 32
    mov     rbx, rdi        ; cursor
    mov     r12d, esi       ; cap
    mov     r13, rdx        ; blinded key b64
    mov     r14d, ecx       ; blinded len
    mov     r15, r8         ; signing cert armor
    mov     [rbp - 48], r9  ; signing cert len
    mov     [rbp - 56], rdi ; base
    test    rbx, rbx
    jz      .fail
    test    r12d, r12d
    jle     .fail
    test    r13, r13
    jz      .fail
    test    r14d, r14d
    jle     .fail
    test    r15, r15
    jz      .fail
    cmp     dword [rbp - 48], 0
    jle     .fail
    cmp     qword [rbp + 32], 0
    je      .fail
    cmp     dword [rbp + 40], 0
    jle     .fail
    cmp     qword [rbp + 48], 0
    je      .fail
    lea     r12, [rbx + r12] ; end

    mov     rdi, rbx
    mov     rsi, r12
    lea     rdx, [rel tor_hs_line_hs_descriptor]
    mov     ecx, tor_hs_line_hs_descriptor_len
    call    _tor_hs_append_checked
    test    rax, rax
    jz      .fail
    mov     rbx, rax

    mov     rdi, rbx
    mov     rsi, r12
    lea     rdx, [rel tor_hs_line_descriptor_lifetime]
    mov     ecx, tor_hs_line_descriptor_lifetime_len
    call    _tor_hs_append_checked
    test    rax, rax
    jz      .fail
    mov     rbx, rax
    mov     rdi, rbx
    mov     rsi, r12
    mov     edx, [rbp + 24]
    call    _tor_hs_append_u32_checked
    test    rax, rax
    jz      .fail
    mov     rbx, rax
    mov     rdi, rbx
    mov     rsi, r12
    lea     rdx, [rel tor_hs_nl]
    mov     ecx, 1
    call    _tor_hs_append_checked
    test    rax, rax
    jz      .fail
    mov     rbx, rax

    mov     rdi, rbx
    mov     rsi, r12
    lea     rdx, [rel tor_hs_line_descriptor_signing_key_cert]
    mov     ecx, tor_hs_line_descriptor_signing_key_cert_len
    call    _tor_hs_append_checked
    test    rax, rax
    jz      .fail
    mov     rbx, rax
    mov     rdi, rbx
    mov     rsi, r12
    mov     rdx, r15
    mov     ecx, [rbp - 48]
    call    _tor_hs_append_checked
    test    rax, rax
    jz      .fail
    mov     rbx, rax
    cmp     byte [rbx - 1], 10
    je      .revision
    mov     rdi, rbx
    mov     rsi, r12
    lea     rdx, [rel tor_hs_nl]
    mov     ecx, 1
    call    _tor_hs_append_checked
    test    rax, rax
    jz      .fail
    mov     rbx, rax

.revision:
    mov     rdi, rbx
    mov     rsi, r12
    lea     rdx, [rel tor_hs_line_revision_counter]
    mov     ecx, tor_hs_line_revision_counter_len
    call    _tor_hs_append_checked
    test    rax, rax
    jz      .fail
    mov     rbx, rax
    mov     rdi, rbx
    mov     rsi, r12
    mov     edx, [rbp + 16]
    call    _tor_hs_append_u32_checked
    test    rax, rax
    jz      .fail
    mov     rbx, rax
    mov     rdi, rbx
    mov     rsi, r12
    lea     rdx, [rel tor_hs_nl]
    mov     ecx, 1
    call    _tor_hs_append_checked
    test    rax, rax
    jz      .fail
    mov     rbx, rax

    mov     rdi, rbx
    mov     rsi, r12
    lea     rdx, [rel tor_hs_line_superencrypted]
    mov     ecx, tor_hs_line_superencrypted_len
    call    _tor_hs_append_checked
    test    rax, rax
    jz      .fail
    mov     rbx, rax
    mov     rdi, rbx
    mov     rsi, r12
    mov     rdx, [rbp + 32]
    mov     ecx, [rbp + 40]
    call    _tor_hs_append_checked
    test    rax, rax
    jz      .fail
    mov     rbx, rax
    cmp     byte [rbx - 1], 10
    je      .signature
    mov     rdi, rbx
    mov     rsi, r12
    lea     rdx, [rel tor_hs_nl]
    mov     ecx, 1
    call    _tor_hs_append_checked
    test    rax, rax
    jz      .fail
    mov     rbx, rax

.signature:
    mov     rdi, rbx
    mov     rsi, r12
    lea     rdx, [rel tor_hs_line_signature]
    mov     ecx, tor_hs_line_signature_len
    call    _tor_hs_append_checked
    test    rax, rax
    jz      .fail
    mov     rbx, rax
    lea     rdi, [rel tor_hs_desc_mac_buf]
    mov     esi, 128
    mov     rdx, [rbp + 48]
    mov     ecx, TOR_HS_ED25519_SIG_LEN
    call    er_tor_hs_b64_encode
    test    eax, eax
    js      .fail
    mov     rdi, rbx
    mov     rsi, r12
    lea     rdx, [rel tor_hs_desc_mac_buf]
    mov     ecx, eax
    call    _tor_hs_append_checked
    test    rax, rax
    jz      .fail
    mov     rbx, rax
    mov     rdi, rbx
    mov     rsi, r12
    lea     rdx, [rel tor_hs_nl]
    mov     ecx, 1
    call    _tor_hs_append_checked
    test    rax, rax
    jz      .fail
    sub     rax, [rbp - 56]
    er_ok
    add     rsp, 32
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    er_ret
.fail:
    mov     eax, -1
    add     rsp, 32
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    er_ret

; er_tor_hs_mac32_sha3(out, tag, tag_len, key32, msg, msg_len)
; Implements ntor-v3 MAC(k,msg,t) = SHA3_256(ENCAP(t)|ENCAP(k)|msg)
; for a fixed 32-byte MAC key.
global er_tor_hs_mac32_sha3
er_fn er_tor_hs_mac32_sha3
    push    rbx
    push    rbp
    push    r12
    push    r13
    push    r14
    push    r15
    mov     rbx, rdi
    mov     r12, rsi
    mov     r13d, edx
    mov     r14, rcx
    mov     r15, r8
    mov     ebp, r9d
    test    rbx, rbx
    jz      .fail
    test    r12, r12
    jz      .fail
    test    r14, r14
    jz      .fail
    test    ebp, ebp
    jz      .msg_ok
    test    r15, r15
    jz      .fail
.msg_ok:
    mov     eax, TOR_HS_ENCAP_LEN + TOR_HS_ENCAP_LEN + TOR_HS_MAC_KEY_LEN
    add     eax, r13d
    add     eax, ebp
    cmp     eax, TOR_HS_CRYPTO_BUF_MAX
    ja      .fail

    lea     rdi, [rel tor_hs_crypto_buf]
    mov     esi, r13d
    call    _tor_hs_store_u64_be
    lea     rdi, [rel tor_hs_crypto_buf + TOR_HS_ENCAP_LEN]
    mov     rsi, r12
    mov     edx, r13d
    call    er_memcpy

    mov     eax, r13d
    add     eax, TOR_HS_ENCAP_LEN
    lea     rdi, [rel tor_hs_crypto_buf + rax]
    mov     esi, TOR_HS_MAC_KEY_LEN
    call    _tor_hs_store_u64_be

    mov     eax, r13d
    add     eax, TOR_HS_ENCAP_LEN + TOR_HS_ENCAP_LEN
    lea     rdi, [rel tor_hs_crypto_buf + rax]
    mov     rsi, r14
    mov     edx, TOR_HS_MAC_KEY_LEN
    call    er_memcpy

    test    ebp, ebp
    jz      .hash
    mov     eax, r13d
    add     eax, TOR_HS_ENCAP_LEN + TOR_HS_ENCAP_LEN + TOR_HS_MAC_KEY_LEN
    lea     rdi, [rel tor_hs_crypto_buf + rax]
    mov     rsi, r15
    mov     edx, ebp
    call    er_memcpy

.hash:
    mov     esi, TOR_HS_ENCAP_LEN + TOR_HS_ENCAP_LEN + TOR_HS_MAC_KEY_LEN
    add     esi, r13d
    add     esi, ebp
    lea     rdi, [rel tor_hs_crypto_buf]
    mov     rdx, rbx
    call    er_sha3_256
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    pop     rbx
    er_ret
.fail:
    mov     eax, -1
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    pop     rbx
    er_ret

; er_tor_hs_kdf_sha3(out, out_len, tag, tag_len, msg, msg_len)
; Implements ntor-v3 KDF(s,t) = SHAKE256(ENCAP(t)|s).
global er_tor_hs_kdf_sha3
er_fn er_tor_hs_kdf_sha3
    push    rbx
    push    rbp
    push    r12
    push    r13
    push    r14
    push    r15
    mov     rbx, rdi
    mov     rbp, rsi
    mov     r12, rdx
    mov     r13d, ecx
    mov     r14, r8
    mov     r15d, r9d
    test    rbp, rbp
    jz      .ok_empty
    test    rbx, rbx
    jz      .fail
    test    r12, r12
    jz      .fail
    test    r15d, r15d
    jz      .msg_ok
    test    r14, r14
    jz      .fail
.msg_ok:
    mov     eax, TOR_HS_ENCAP_LEN
    add     eax, r13d
    add     eax, r15d
    cmp     eax, TOR_HS_CRYPTO_BUF_MAX
    ja      .fail

    lea     rdi, [rel tor_hs_crypto_buf]
    mov     esi, r13d
    call    _tor_hs_store_u64_be
    lea     rdi, [rel tor_hs_crypto_buf + TOR_HS_ENCAP_LEN]
    mov     rsi, r12
    mov     edx, r13d
    call    er_memcpy
    test    r15d, r15d
    jz      .shake
    mov     eax, r13d
    add     eax, TOR_HS_ENCAP_LEN
    lea     rdi, [rel tor_hs_crypto_buf + rax]
    mov     rsi, r14
    mov     edx, r15d
    call    er_memcpy
.shake:
    mov     esi, TOR_HS_ENCAP_LEN
    add     esi, r13d
    add     esi, r15d
    lea     rdi, [rel tor_hs_crypto_buf]
    mov     rdx, rbx
    mov     rcx, rbp
    call    er_shake256
    jmp     .done
.ok_empty:
    xor     eax, eax
.done:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    pop     rbx
    er_ret
.fail:
    mov     eax, -1
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    pop     rbx
    er_ret

; er_tor_hs_build_establish_rendezvous(out, cookie)
; returns eax = body length, or -1.
global er_tor_hs_build_establish_rendezvous
er_fn er_tor_hs_build_establish_rendezvous
    test    rdi, rdi
    jz      .fail
    test    rsi, rsi
    jz      .fail
    mov     edx, TOR_HS_RENDEZVOUS_COOKIE_LEN
    call    er_memcpy
    mov     eax, TOR_HS_RENDEZVOUS_COOKIE_LEN
    er_ok
    er_ret
.fail:
    mov     eax, -1
    er_ret

; er_tor_hs_parse_rendezvous_established(data, len)
; Extra bytes are ignored by spec.
global er_tor_hs_parse_rendezvous_established
er_fn er_tor_hs_parse_rendezvous_established
    xor     eax, eax
    er_ok
    er_ret

; er_tor_hs_build_rendezvous1(out, cookie, handshake_info, handshake_len)
; returns eax = body length, or -1.
global er_tor_hs_build_rendezvous1
er_fn er_tor_hs_build_rendezvous1
    push    rbx
    push    r12
    push    r13
    mov     rbx, rdi
    mov     r12, rdx
    mov     r13d, ecx
    test    rbx, rbx
    jz      .fail
    test    rsi, rsi
    jz      .fail
    cmp     r13d, TOR_HS_RELAY_DATA_MAX - TOR_HS_RENDEZVOUS_COOKIE_LEN
    ja      .fail
    mov     rdi, rbx
    mov     edx, TOR_HS_RENDEZVOUS_COOKIE_LEN
    call    er_memcpy
    test    r13d, r13d
    jz      .done
    test    r12, r12
    jz      .fail
    lea     rdi, [rbx + TOR_HS_RENDEZVOUS_COOKIE_LEN]
    mov     rsi, r12
    mov     edx, r13d
    call    er_memcpy
.done:
    lea     eax, [r13d + TOR_HS_RENDEZVOUS_COOKIE_LEN]
    er_ok
    pop     r13
    pop     r12
    pop     rbx
    er_ret
.fail:
    mov     eax, -1
    pop     r13
    pop     r12
    pop     rbx
    er_ret

; er_tor_hs_parse_rendezvous2(data, len, out_handshake, out_len)
; returns eax = 0 on success, -1 on malformed arguments.
global er_tor_hs_parse_rendezvous2
er_fn er_tor_hs_parse_rendezvous2
    push    rbx
    push    r12
    mov     rbx, rdx
    mov     r12, rcx
    cmp     esi, TOR_HS_RELAY_DATA_MAX
    ja      .fail
    test    r12, r12
    jz      .fail
    mov     [r12], esi
    test    esi, esi
    jz      .ok
    test    rdi, rdi
    jz      .fail
    test    rbx, rbx
    jz      .fail
    mov     rdx, rsi
    mov     rsi, rdi
    mov     rdi, rbx
    call    er_memcpy
.ok:
    xor     eax, eax
    er_ok
    pop     r12
    pop     rbx
    er_ret
.fail:
    mov     eax, -1
    pop     r12
    pop     rbx
    er_ret

; er_tor_hs_parse_introduce_ack(data, len)
; returns eax = STATUS, or -1.
global er_tor_hs_parse_introduce_ack
er_fn er_tor_hs_parse_introduce_ack
    cmp     esi, 3
    jb      .fail
    test    rdi, rdi
    jz      .fail
    movzx   eax, byte [rdi]
    shl     eax, 8
    movzx   ecx, byte [rdi + 1]
    or      eax, ecx
    er_ok
    er_ret
.fail:
    mov     eax, -1
    er_ret

; er_tor_hs_build_introduce1_prefix(out, auth_key, encrypted, encrypted_len)
; Builds the top-level v3 INTRODUCE1 body with no top-level extensions.
; returns eax = body length, or -1.
global er_tor_hs_build_introduce1_prefix
er_fn er_tor_hs_build_introduce1_prefix
    push    rbx
    push    r12
    push    r13
    mov     rbx, rdi
    mov     r12, rdx
    mov     r13d, ecx
    test    rbx, rbx
    jz      .fail
    test    rsi, rsi
    jz      .fail
    cmp     r13d, TOR_HS_INTRODUCE1_ENCRYPTED_FIELD_MAX
    ja      .fail

    xor     eax, eax
    mov     ecx, 20
    rep     stosb
    mov     byte [rdi], TOR_HS_AUTH_KEY_TYPE_ED25519
    inc     rdi
    mov     byte [rdi], 0
    mov     byte [rdi + 1], TOR_HS_INTRO_AUTH_KEY_LEN
    add     rdi, 2
    mov     edx, TOR_HS_INTRO_AUTH_KEY_LEN
    call    er_memcpy
    lea     rdi, [rbx + 55]
    mov     byte [rdi], 0
    inc     rdi
    test    r13d, r13d
    jz      .done
    test    r12, r12
    jz      .fail
    mov     rsi, r12
    mov     edx, r13d
    call    er_memcpy
.done:
    lea     eax, [r13d + TOR_HS_INTRODUCE1_PREFIX_LEN]
    er_ok
    pop     r13
    pop     r12
    pop     rbx
    er_ret
.fail:
    mov     eax, -1
    pop     r13
    pop     r12
    pop     rbx
    er_ret

; er_tor_hs_build_introduce1_plaintext(out, cookie, onion_key, nspec, linkspecs, linkspecs_len)
; Builds decrypted INTRODUCE1 plaintext with no encrypted extensions or padding.
; returns eax = plaintext length, or -1.
global er_tor_hs_build_introduce1_plaintext
er_fn er_tor_hs_build_introduce1_plaintext
    push    rbx
    push    rbp
    push    r12
    push    r13
    push    r14
    push    r15
    mov     rbx, rdi
    mov     r12, rsi
    mov     r13, rdx
    mov     ebp, ecx
    mov     r14, r8
    mov     r15d, r9d
    test    rbx, rbx
    jz      .fail
    test    r12, r12
    jz      .fail
    test    r13, r13
    jz      .fail
    cmp     ebp, 255
    ja      .fail
    cmp     r15d, TOR_HS_INTRODUCE1_ENCRYPTED_DATA_MAX - TOR_HS_INTRODUCE1_PLAINTEXT_BASE_LEN
    ja      .fail
    test    r15d, r15d
    jz      .copy_cookie
    test    r14, r14
    jz      .fail
.copy_cookie:
    mov     rdi, rbx
    mov     rsi, r12
    mov     edx, TOR_HS_RENDEZVOUS_COOKIE_LEN
    call    er_memcpy
    mov     byte [rbx + 20], 0
    mov     byte [rbx + 21], TOR_HS_ONION_KEY_TYPE_NTOR
    mov     byte [rbx + 22], 0
    mov     byte [rbx + 23], TOR_HS_ONION_KEY_LEN_NTOR
    lea     rdi, [rbx + 24]
    mov     rsi, r13
    mov     edx, TOR_HS_ONION_KEY_LEN_NTOR
    call    er_memcpy
    mov     [rbx + 56], bpl
    test    r15d, r15d
    jz      .done
    lea     rdi, [rbx + TOR_HS_INTRODUCE1_PLAINTEXT_BASE_LEN]
    mov     rsi, r14
    mov     edx, r15d
    call    er_memcpy
.done:
    lea     eax, [r15d + TOR_HS_INTRODUCE1_PLAINTEXT_BASE_LEN]
    er_ok
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    pop     rbx
    er_ret
.fail:
    mov     eax, -1
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    pop     rbx
    er_ret

; er_tor_hs_build_introduce1_encrypted(out, client_pk, encrypted_data, encrypted_len, mac)
; Serializes the hs-ntor ENCRYPTED field: CLIENT_PK | ENCRYPTED_DATA | MAC.
; returns eax = encrypted field length, or -1.
global er_tor_hs_build_introduce1_encrypted
er_fn er_tor_hs_build_introduce1_encrypted
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    mov     rbx, rdi
    mov     r12, rsi
    mov     r13, rdx
    mov     r14d, ecx
    mov     r15, r8
    test    rbx, rbx
    jz      .fail
    test    r12, r12
    jz      .fail
    test    r15, r15
    jz      .fail
    cmp     r14d, TOR_HS_INTRODUCE1_ENCRYPTED_DATA_MAX
    ja      .fail
    test    r14d, r14d
    jz      .copy_client_pk
    test    r13, r13
    jz      .fail
.copy_client_pk:
    mov     rsi, r12
    mov     edx, TOR_HS_CLIENT_PK_LEN
    call    er_memcpy
    test    r14d, r14d
    jz      .copy_mac
    lea     rdi, [rbx + TOR_HS_CLIENT_PK_LEN]
    mov     rsi, r13
    mov     edx, r14d
    call    er_memcpy
.copy_mac:
    lea     rdi, [rbx + TOR_HS_CLIENT_PK_LEN + r14]
    mov     rsi, r15
    mov     edx, TOR_HS_INTRODUCE1_MAC_LEN
    call    er_memcpy
    lea     eax, [r14d + TOR_HS_CLIENT_PK_LEN + TOR_HS_INTRODUCE1_MAC_LEN]
    er_ok
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret
.fail:
    mov     eax, -1
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

; er_tor_hs_parse_introduce_plaintext(out_cookie20, out_onion_key32,
;                                     out_linkspecs, linkspecs_cap,
;                                     out_linkspecs_len, data, len)
; Parses the decrypted INTRODUCE2 plaintext generated by
; er_tor_hs_build_introduce1_plaintext.
global er_tor_hs_parse_introduce_plaintext
er_fn er_tor_hs_parse_introduce_plaintext
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 16
    mov     rbx, rdi
    mov     r12, rsi
    mov     r13, rdx
    mov     r14d, ecx
    mov     r15, r8
    test    rbx, rbx
    jz      .fail
    test    r12, r12
    jz      .fail
    test    r13, r13
    jz      .fail
    test    r15, r15
    jz      .fail
    cmp     qword [rbp + 16], 0
    je      .fail
    cmp     dword [rbp + 24], TOR_HS_INTRODUCE1_PLAINTEXT_BASE_LEN
    jb      .fail
    mov     r9, [rbp + 16]
    mov     [rbp - 48], r9
    mov     rdi, rbx
    mov     rsi, r9
    mov     edx, TOR_HS_RENDEZVOUS_COOKIE_LEN
    call    er_memcpy
    mov     r9, [rbp - 48]
    cmp     byte [r9 + 20], 0
    jne     .fail
    cmp     byte [r9 + 21], TOR_HS_ONION_KEY_TYPE_NTOR
    jne     .fail
    cmp     byte [r9 + 22], 0
    jne     .fail
    cmp     byte [r9 + 23], TOR_HS_ONION_KEY_LEN_NTOR
    jne     .fail
    mov     rdi, r12
    lea     rsi, [r9 + 24]
    mov     edx, TOR_HS_ONION_KEY_LEN_NTOR
    call    er_memcpy
    mov     r9, [rbp - 48]
    movzx   eax, byte [r9 + 56]
    test    eax, eax
    jz      .fail
    mov     eax, [rbp + 24]
    sub     eax, TOR_HS_INTRODUCE1_PLAINTEXT_BASE_LEN
    cmp     eax, r14d
    ja      .fail
    mov     [r15], eax
    test    eax, eax
    jz      .ok
    mov     rdi, r13
    mov     r9, [rbp - 48]
    lea     rsi, [r9 + TOR_HS_INTRODUCE1_PLAINTEXT_BASE_LEN]
    mov     edx, eax
    call    er_memcpy
.ok:
    xor     eax, eax
    er_ok
    add     rsp, 16
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    er_ret
.fail:
    mov     eax, -1
    add     rsp, 16
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    er_ret

; er_tor_hs_extract_introduce_encrypted(out_ptr, out_len, body, body_len)
; Accepts either a full INTRODUCE1/2 body with the v3 prefix or an already
; stripped encrypted field. Returns eax=0 on success.
global er_tor_hs_extract_introduce_encrypted
er_fn er_tor_hs_extract_introduce_encrypted
    test    rdi, rdi
    jz      .fail
    test    rsi, rsi
    jz      .fail
    test    rdx, rdx
    jz      .fail
    cmp     ecx, TOR_HS_CLIENT_PK_LEN + TOR_HS_INTRODUCE1_MAC_LEN
    jb      .fail
    cmp     ecx, TOR_HS_INTRODUCE1_PREFIX_LEN
    jb      .raw
    cmp     byte [rdx + 20], TOR_HS_AUTH_KEY_TYPE_ED25519
    jne     .raw
    cmp     byte [rdx + 21], 0
    jne     .raw
    cmp     byte [rdx + 22], TOR_HS_INTRO_AUTH_KEY_LEN
    jne     .raw
    cmp     byte [rdx + 55], 0
    jne     .raw
    lea     rax, [rdx + TOR_HS_INTRODUCE1_PREFIX_LEN]
    mov     [rdi], rax
    mov     eax, ecx
    sub     eax, TOR_HS_INTRODUCE1_PREFIX_LEN
    cmp     eax, TOR_HS_CLIENT_PK_LEN + TOR_HS_INTRODUCE1_MAC_LEN
    jb      .fail
    mov     [rsi], eax
    xor     eax, eax
    er_ok
    er_ret
.raw:
    mov     [rdi], rdx
    mov     [rsi], ecx
    xor     eax, eax
    er_ok
    er_ret
.fail:
    mov     eax, -1
    er_ret

; er_tor_hs_derive_intro_keys(out64, auth_key, onion_key, client_priv, client_pub, subcred)
; Derives hs-ntor INTRODUCE1 ENC_KEY||MAC_KEY from the service onion key B
; and caller-owned client keypair x/X.
global er_tor_hs_derive_intro_keys
er_fn er_tor_hs_derive_intro_keys
    push    rbp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    mov     rbx, rdi
    mov     r12, rsi
    mov     r13, rdx
    mov     r14, rcx
    mov     r15, r8
    mov     rbp, r9
    test    rbx, rbx
    jz      .fail
    test    r12, r12
    jz      .fail
    test    r13, r13
    jz      .fail
    test    r14, r14
    jz      .fail
    test    r15, r15
    jz      .fail
    test    rbp, rbp
    jz      .fail

    lea     rdi, [rel tor_hs_crypto_buf]
    mov     rsi, r14
    mov     rdx, r13
    call    er_tor_curve25519_scalar_mult

    lea     rdi, [rel tor_hs_crypto_buf + 64]
    lea     rsi, [rel tor_hs_crypto_buf]
    mov     edx, TOR_CURVE25519_KEY_LEN
    call    er_memcpy

    lea     rdi, [rel tor_hs_crypto_buf + 64 + TOR_CURVE25519_KEY_LEN]
    mov     rsi, r12
    mov     edx, TOR_HS_INTRO_AUTH_KEY_LEN
    call    er_memcpy

    lea     rdi, [rel tor_hs_crypto_buf + 64 + TOR_CURVE25519_KEY_LEN + TOR_HS_INTRO_AUTH_KEY_LEN]
    mov     rsi, r15
    mov     edx, TOR_HS_CLIENT_PK_LEN
    call    er_memcpy

    lea     rdi, [rel tor_hs_crypto_buf + 64 + TOR_CURVE25519_KEY_LEN + TOR_HS_INTRO_AUTH_KEY_LEN + TOR_HS_CLIENT_PK_LEN]
    mov     rsi, r13
    mov     edx, TOR_HS_ONION_KEY_LEN_NTOR
    call    er_memcpy

    lea     rdi, [rel tor_hs_crypto_buf + 64 + TOR_CURVE25519_KEY_LEN + TOR_HS_INTRO_AUTH_KEY_LEN + TOR_HS_CLIENT_PK_LEN + TOR_HS_ONION_KEY_LEN_NTOR]
    lea     rsi, [rel tor_hs_ntor_protoid]
    mov     edx, TOR_HS_NTOR_PROTOID_LEN
    call    er_memcpy

    lea     rdi, [rel tor_hs_crypto_buf + 64 + TOR_HS_INTRO_SECRET_LEN]
    lea     rsi, [rel tor_hs_ntor_t_hsenc]
    mov     edx, TOR_HS_NTOR_T_HSENC_LEN
    call    er_memcpy

    lea     rdi, [rel tor_hs_crypto_buf + 64 + TOR_HS_INTRO_SECRET_LEN + TOR_HS_NTOR_T_HSENC_LEN]
    lea     rsi, [rel tor_hs_ntor_m_hsexpand]
    mov     edx, TOR_HS_NTOR_M_HSEXPAND_LEN
    call    er_memcpy

    lea     rdi, [rel tor_hs_crypto_buf + 64 + TOR_HS_INTRO_SECRET_LEN + TOR_HS_NTOR_T_HSENC_LEN + TOR_HS_NTOR_M_HSEXPAND_LEN]
    mov     rsi, rbp
    mov     edx, TOR_HS_SUBCRED_LEN
    call    er_memcpy

    lea     rdi, [rel tor_hs_crypto_buf + 64]
    mov     esi, TOR_HS_INTRO_KDF_INPUT_LEN
    mov     rdx, rbx
    mov     ecx, TOR_HS_INTRO_KEY_MATERIAL_LEN
    call    er_shake256
    er_ok
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    er_ret
.fail:
    mov     eax, -1
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    er_ret

; er_tor_hs_derive_intro_keys_service(out64, auth_key, onion_priv, onion_pub,
;                                     client_pub, subcred)
; Service-side hs-ntor key derivation for INTRODUCE2.  This is the same KDF
; transcript as er_tor_hs_derive_intro_keys, but computes EXP(X,b) from the
; service-owned onion private key b and the client public key X.
global er_tor_hs_derive_intro_keys_service
er_fn er_tor_hs_derive_intro_keys_service
    push    rbp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    mov     rbx, rdi
    mov     r12, rsi
    mov     r13, rdx
    mov     r14, rcx
    mov     r15, r8
    mov     rbp, r9
    test    rbx, rbx
    jz      .fail
    test    r12, r12
    jz      .fail
    test    r13, r13
    jz      .fail
    test    r14, r14
    jz      .fail
    test    r15, r15
    jz      .fail
    test    rbp, rbp
    jz      .fail

    lea     rdi, [rel tor_hs_crypto_buf]
    mov     rsi, r13
    mov     rdx, r15
    call    er_tor_curve25519_scalar_mult

    lea     rdi, [rel tor_hs_crypto_buf + 64]
    lea     rsi, [rel tor_hs_crypto_buf]
    mov     edx, TOR_CURVE25519_KEY_LEN
    call    er_memcpy

    lea     rdi, [rel tor_hs_crypto_buf + 64 + TOR_CURVE25519_KEY_LEN]
    mov     rsi, r12
    mov     edx, TOR_HS_INTRO_AUTH_KEY_LEN
    call    er_memcpy

    lea     rdi, [rel tor_hs_crypto_buf + 64 + TOR_CURVE25519_KEY_LEN + TOR_HS_INTRO_AUTH_KEY_LEN]
    mov     rsi, r15
    mov     edx, TOR_HS_CLIENT_PK_LEN
    call    er_memcpy

    lea     rdi, [rel tor_hs_crypto_buf + 64 + TOR_CURVE25519_KEY_LEN + TOR_HS_INTRO_AUTH_KEY_LEN + TOR_HS_CLIENT_PK_LEN]
    mov     rsi, r14
    mov     edx, TOR_HS_ONION_KEY_LEN_NTOR
    call    er_memcpy

    lea     rdi, [rel tor_hs_crypto_buf + 64 + TOR_CURVE25519_KEY_LEN + TOR_HS_INTRO_AUTH_KEY_LEN + TOR_HS_CLIENT_PK_LEN + TOR_HS_ONION_KEY_LEN_NTOR]
    lea     rsi, [rel tor_hs_ntor_protoid]
    mov     edx, TOR_HS_NTOR_PROTOID_LEN
    call    er_memcpy

    lea     rdi, [rel tor_hs_crypto_buf + 64 + TOR_HS_INTRO_SECRET_LEN]
    lea     rsi, [rel tor_hs_ntor_t_hsenc]
    mov     edx, TOR_HS_NTOR_T_HSENC_LEN
    call    er_memcpy

    lea     rdi, [rel tor_hs_crypto_buf + 64 + TOR_HS_INTRO_SECRET_LEN + TOR_HS_NTOR_T_HSENC_LEN]
    lea     rsi, [rel tor_hs_ntor_m_hsexpand]
    mov     edx, TOR_HS_NTOR_M_HSEXPAND_LEN
    call    er_memcpy

    lea     rdi, [rel tor_hs_crypto_buf + 64 + TOR_HS_INTRO_SECRET_LEN + TOR_HS_NTOR_T_HSENC_LEN + TOR_HS_NTOR_M_HSEXPAND_LEN]
    mov     rsi, rbp
    mov     edx, TOR_HS_SUBCRED_LEN
    call    er_memcpy

    lea     rdi, [rel tor_hs_crypto_buf + 64]
    mov     esi, TOR_HS_INTRO_KDF_INPUT_LEN
    mov     rdx, rbx
    mov     ecx, TOR_HS_INTRO_KEY_MATERIAL_LEN
    call    er_shake256
    er_ok
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    er_ret
.fail:
    mov     eax, -1
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    er_ret

; er_tor_hs_open_introduce2(out_plain, out_len, auth_key, onion_priv,
;                           onion_pub, subcred, encrypted_field, encrypted_len)
; Service-side opening for the hs-ntor encrypted INTRODUCE2 field:
;   CLIENT_PK | ENCRYPTED_DATA | MAC
; On success, verifies MAC, decrypts ENCRYPTED_DATA into out_plain, stores its
; length at out_len, and returns eax=0.  On malformed input or MAC mismatch,
; returns eax=-1 without requiring any external Tor process.
global er_tor_hs_open_introduce2
er_fn er_tor_hs_open_introduce2
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 16
    mov     rbx, rdi        ; out_plain
    mov     r12, rsi        ; out_len
    mov     r13, rdx        ; auth_key
    mov     r14, rcx        ; onion_priv
    mov     r15, r8         ; onion_pub
    mov     [rsp], r9       ; subcred
    mov     rax, [rbp + 16] ; encrypted_field
    mov     [rsp + 8], rax
    mov     eax, [rbp + 24] ; encrypted_len
    cmp     eax, TOR_HS_CLIENT_PK_LEN + TOR_HS_INTRODUCE1_MAC_LEN
    jb      .fail
    cmp     eax, TOR_HS_INTRODUCE1_MAX_LEN
    ja      .fail
    test    rbx, rbx
    jz      .fail
    test    r12, r12
    jz      .fail
    test    r13, r13
    jz      .fail
    test    r14, r14
    jz      .fail
    test    r15, r15
    jz      .fail
    cmp     qword [rsp], 0
    je      .fail
    cmp     qword [rsp + 8], 0
    je      .fail

    mov     ecx, eax
    sub     ecx, TOR_HS_CLIENT_PK_LEN + TOR_HS_INTRODUCE1_MAC_LEN
    mov     [r12], ecx

    lea     rdi, [rel tor_hs_crypto_buf + 512]
    mov     rsi, r13
    mov     rdx, r14
    mov     rcx, r15
    mov     r8, [rsp + 8]
    mov     r9, [rsp]
    call    er_tor_hs_derive_intro_keys_service
    test    eax, eax
    js      .fail

    ; MAC input = AUTH_KEY | single zero byte | CLIENT_PK | ENCRYPTED_DATA.
    lea     rdi, [rel tor_hs_crypto_buf + 384]
    mov     rsi, r13
    mov     edx, TOR_HS_INTRO_AUTH_KEY_LEN
    call    er_memcpy
    mov     byte [rel tor_hs_crypto_buf + 384 + TOR_HS_INTRO_AUTH_KEY_LEN], 0
    lea     rdi, [rel tor_hs_crypto_buf + 384 + TOR_HS_INTRO_AUTH_KEY_LEN + 1]
    mov     rsi, [rsp + 8]
    mov     edx, [rbp + 24]
    sub     edx, TOR_HS_INTRODUCE1_MAC_LEN
    call    er_memcpy

    lea     rdi, [rel tor_hs_crypto_buf + 320]
    lea     rsi, [rel tor_hs_ntor_t_hsmac]
    mov     edx, TOR_HS_NTOR_T_HSMAC_LEN
    lea     rcx, [rel tor_hs_crypto_buf + 512 + 32]
    lea     r8, [rel tor_hs_crypto_buf + 384]
    mov     r9d, [rbp + 24]
    sub     r9d, TOR_HS_INTRODUCE1_MAC_LEN
    add     r9d, TOR_HS_INTRO_AUTH_KEY_LEN + 1
    call    er_tor_hs_mac32_sha3
    test    eax, eax
    js      .fail

    mov     rsi, [rsp + 8]
    mov     ecx, [rbp + 24]
    sub     ecx, TOR_HS_INTRODUCE1_MAC_LEN
    add     rsi, rcx
    lea     rdi, [rel tor_hs_crypto_buf + 320]
    mov     edx, TOR_HS_INTRODUCE1_MAC_LEN
    call    _tor_hs_mem_eq
    test    eax, eax
    jz      .fail

    mov     edx, [r12]
    test    edx, edx
    jz      .ok
    mov     rdi, rbx
    mov     rsi, [rsp + 8]
    add     rsi, TOR_HS_CLIENT_PK_LEN
    lea     rcx, [rel tor_hs_crypto_buf + 512]
    mov     qword [rel tor_hs_crypto_buf + 960], 0
    mov     qword [rel tor_hs_crypto_buf + 968], 0
    lea     r8, [rel tor_hs_crypto_buf + 960]
    call    er_tor_aes256_ctr
.ok:
    xor     eax, eax
    er_ok
    add     rsp, 16
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    er_ret
.fail:
    mov     eax, -1
    add     rsp, 16
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    er_ret

_tor_hs_mem_eq:
    push    rcx
    push    rsi
    push    rdi
    mov     rcx, rdx
    repz    cmpsb
    setz    al
    movzx   eax, al
    pop     rdi
    pop     rsi
    pop     rcx
    ret

; _tor_hs_append_checked(cursor, end, src, len) -> rax=new cursor or 0.
_tor_hs_append_checked:
    mov     rax, rdi
    add     rax, rcx
    cmp     rax, rsi
    ja      .fail
    push    rax
    mov     rsi, rdx
    mov     edx, ecx
    call    er_memcpy
    pop     rax
    ret
.fail:
    xor     eax, eax
    ret

; _tor_hs_find_marker(text, len, marker, marker_len) -> rax=ptr or 0
_tor_hs_find_marker:
    push    rbx
    push    rbp
    push    r12
    push    r13
    push    r14
    push    r15
    mov     r12, rdi
    mov     r13d, esi
    mov     r14, rdx
    mov     r15d, ecx
    test    r12, r12
    jz      .nf
    test    r14, r14
    jz      .nf
    test    r15d, r15d
    jz      .nf
    cmp     r13d, r15d
    jb      .nf
    xor     ebx, ebx
    mov     ebp, r13d
    sub     ebp, r15d
.loop:
    cmp     ebx, ebp
    ja      .nf
    lea     rdi, [r12 + rbx]
    mov     rsi, r14
    mov     edx, r15d
    call    _tor_hs_mem_eq
    test    eax, eax
    jnz     .found
    inc     ebx
    jmp     .loop
.found:
    lea     rax, [r12 + rbx]
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    pop     rbx
    ret
.nf:
    xor     eax, eax
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    pop     rbx
    ret

; _tor_hs_find_line_value(text, len, prefix, prefix_len)
; returns rax=value ptr, edx=value len; rax=0 on not found.
_tor_hs_find_line_value:
    push    rbx
    push    rbp
    push    r12
    push    r13
    push    r14
    push    r15
    mov     r12, rdi
    mov     r13d, esi
    mov     r14, rdx
    mov     r15d, ecx
    xor     ebx, ebx
.line_loop:
    cmp     ebx, r13d
    jae     .nf
    mov     ebp, ebx
.eol:
    cmp     ebp, r13d
    jae     .line_ready
    cmp     byte [r12 + rbp], 10
    je      .line_ready
    inc     ebp
    jmp     .eol
.line_ready:
    mov     r11d, ebp
    sub     r11d, ebx
    test    r11d, r11d
    jz      .next
    cmp     byte [r12 + rbp - 1], 13
    jne     .check_prefix
    dec     r11d
.check_prefix:
    cmp     r11d, r15d
    jb      .next
    lea     rdi, [r12 + rbx]
    mov     rsi, r14
    mov     edx, r15d
    call    _tor_hs_mem_eq
    test    eax, eax
    jz      .next
    lea     rax, [r12 + rbx]
    add     rax, r15
    mov     edx, r11d
    sub     edx, r15d
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    pop     rbx
    ret
.next:
    lea     ebx, [rbp + 1]
    jmp     .line_loop
.nf:
    xor     eax, eax
    xor     edx, edx
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    pop     rbx
    ret

_tor_hs_append_u16_dec:
    push    rbx
    push    rcx
    push    rdx
    mov     r8, rdi
    movzx   eax, si
    test    eax, eax
    jnz     .digits
    mov     byte [r8], '0'
    lea     rax, [r8 + 1]
    pop     rdx
    pop     rcx
    pop     rbx
    ret
.digits:
    sub     rsp, 8
    xor     ecx, ecx
    mov     ebx, 10
.div_loop:
    xor     edx, edx
    div     ebx
    add     dl, '0'
    mov     [rsp + rcx], dl
    inc     ecx
    test    eax, eax
    jnz     .div_loop
.copy_loop:
    dec     ecx
    mov     al, [rsp + rcx]
    mov     [r8], al
    inc     r8
    test    ecx, ecx
    jnz     .copy_loop
    mov     rax, r8
    add     rsp, 8
    pop     rdx
    pop     rcx
    pop     rbx
    ret

; _tor_hs_append_u32_checked(cursor, end, value) -> rax=new cursor or 0.
_tor_hs_append_u32_checked:
    push    rbx
    push    r12
    push    r13
    sub     rsp, 16
    mov     r12, rdi        ; cursor
    mov     r13, rsi        ; end
    mov     eax, edx
    xor     ecx, ecx
    mov     ebx, 10
    test    eax, eax
    jnz     .digits
    lea     rdx, [r12 + 1]
    cmp     rdx, r13
    ja      .fail
    mov     byte [r12], '0'
    mov     rax, rdx
    jmp     .done
.digits:
    xor     edx, edx
    div     ebx
    add     dl, '0'
    mov     [rsp + rcx], dl
    inc     ecx
    test    eax, eax
    jnz     .digits
    lea     rdx, [r12 + rcx]
    cmp     rdx, r13
    ja      .fail
.copy_loop:
    dec     ecx
    mov     al, [rsp + rcx]
    mov     [r12], al
    inc     r12
    test    ecx, ecx
    jnz     .copy_loop
    mov     rax, r12
    jmp     .done
.fail:
    xor     eax, eax
.done:
    add     rsp, 16
    pop     r13
    pop     r12
    pop     rbx
    ret

; er_tor_hs_build_introduce1_ntor_encrypted(out, auth_key, onion_key, client_priv,
;                                           client_pub, subcred, plaintext, plaintext_len)
; Builds CLIENT_PK | AES_256_CTR(ENC_KEY, plaintext) | MAC.
global er_tor_hs_build_introduce1_ntor_encrypted
er_fn er_tor_hs_build_introduce1_ntor_encrypted
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    mov     rbx, rdi        ; out
    mov     r12, rsi        ; auth_key
    mov     r13, r8         ; client_pub
    mov     r14, [rbp + 16] ; plaintext
    mov     r15d, [rbp + 24] ; plaintext_len
    test    rbx, rbx
    jz      .fail
    test    r14, r14
    jz      .fail
    cmp     r15d, TOR_HS_INTRODUCE1_ENCRYPTED_DATA_MAX
    ja      .fail
    lea     rdi, [rel tor_hs_crypto_buf + 512]
    call    er_tor_hs_derive_intro_keys
    test    eax, eax
    js      .fail

    mov     rdi, rbx
    mov     rsi, r13
    mov     edx, TOR_HS_CLIENT_PK_LEN
    call    er_memcpy

    lea     rdi, [rbx + TOR_HS_CLIENT_PK_LEN]
    mov     rsi, r14
    mov     edx, r15d
    lea     rcx, [rel tor_hs_crypto_buf + 512]
    mov     qword [rel tor_hs_crypto_buf + 960], 0
    mov     qword [rel tor_hs_crypto_buf + 968], 0
    lea     r8, [rel tor_hs_crypto_buf + 960]
    call    er_tor_aes256_ctr

    lea     rdi, [rel tor_hs_crypto_buf + 384]
    mov     rsi, r12
    mov     edx, TOR_HS_INTRO_AUTH_KEY_LEN
    call    er_memcpy
    mov     byte [rel tor_hs_crypto_buf + 384 + TOR_HS_INTRO_AUTH_KEY_LEN], 0
    lea     rdi, [rel tor_hs_crypto_buf + 384 + TOR_HS_INTRO_AUTH_KEY_LEN + 1]
    mov     rsi, r13
    mov     edx, TOR_HS_CLIENT_PK_LEN
    call    er_memcpy
    lea     rdi, [rel tor_hs_crypto_buf + 384 + TOR_HS_INTRO_AUTH_KEY_LEN + 1 + TOR_HS_CLIENT_PK_LEN]
    lea     rsi, [rbx + TOR_HS_CLIENT_PK_LEN]
    mov     edx, r15d
    call    er_memcpy

    lea     rdi, [rbx + TOR_HS_CLIENT_PK_LEN + r15]
    lea     rsi, [rel tor_hs_ntor_t_hsmac]
    mov     edx, TOR_HS_NTOR_T_HSMAC_LEN
    lea     rcx, [rel tor_hs_crypto_buf + 512 + 32]
    lea     r8, [rel tor_hs_crypto_buf + 384]
    mov     r9d, TOR_HS_INTRO_AUTH_KEY_LEN + 1 + TOR_HS_CLIENT_PK_LEN
    add     r9d, r15d
    call    er_tor_hs_mac32_sha3
    test    eax, eax
    js      .fail
    lea     eax, [r15d + TOR_HS_CLIENT_PK_LEN + TOR_HS_INTRODUCE1_MAC_LEN]
    er_ok
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    er_ret
.fail:
    mov     eax, -1
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    er_ret

; er_tor_hs_build_establish_intro_v3(out, auth_key, handshake_auth, sig, sig_len)
; Builds the spec v3 ESTABLISH_INTRO body with no extensions. The caller owns
; the Ed25519 signature and SHA3-256 handshake MAC inputs; this helper only
; serializes the relay-message body.
; returns eax = body length, or -1.
global er_tor_hs_build_establish_intro_v3
er_fn er_tor_hs_build_establish_intro_v3
    push    rbx
    push    r12
    push    r13
    push    r14
    mov     rbx, rdi
    mov     r12, rdx
    mov     r13, rcx
    mov     r14d, r8d
    test    rbx, rbx
    jz      .fail
    test    rsi, rsi
    jz      .fail
    test    r12, r12
    jz      .fail
    cmp     r14d, TOR_HS_RELAY_DATA_MAX - TOR_HS_ESTABLISH_INTRO_BASE_LEN
    ja      .fail
    test    r14d, r14d
    jz      .sig_ready
    test    r13, r13
    jz      .fail
.sig_ready:
    mov     byte [rbx], TOR_HS_AUTH_KEY_TYPE_ED25519
    mov     byte [rbx + 1], 0
    mov     byte [rbx + 2], TOR_HS_INTRO_AUTH_KEY_LEN
    lea     rdi, [rbx + 3]
    mov     edx, TOR_HS_INTRO_AUTH_KEY_LEN
    call    er_memcpy
    mov     byte [rbx + 35], 0
    lea     rdi, [rbx + 36]
    mov     rsi, r12
    mov     edx, TOR_HS_INTRO_HANDSHAKE_AUTH_LEN
    call    er_memcpy
    mov     eax, r14d
    shr     eax, 8
    mov     [rbx + 68], al
    mov     [rbx + 69], r14b
    test    r14d, r14d
    jz      .done
    lea     rdi, [rbx + TOR_HS_ESTABLISH_INTRO_BASE_LEN]
    mov     rsi, r13
    mov     edx, r14d
    call    er_memcpy
.done:
    lea     eax, [r14d + TOR_HS_ESTABLISH_INTRO_BASE_LEN]
    er_ok
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret
.fail:
    mov     eax, -1
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

; er_tor_hs_parse_intro_established(data, len)
; Accepts the modern body with N_EXTENSIONS=0 or the legacy empty body.
global er_tor_hs_parse_intro_established
er_fn er_tor_hs_parse_intro_established
    test    esi, esi
    jz      .ok
    test    rdi, rdi
    jz      .fail
    cmp     byte [rdi], 0
    jne     .fail
.ok:
    xor     eax, eax
    er_ok
    er_ret
.fail:
    mov     eax, -1
    er_ret

; er_tor_hs_establish_rendezvous(circ_id, cookie)
; Sends ESTABLISH_RENDEZVOUS and waits for RENDEZVOUS_ESTABLISHED.
global er_tor_hs_establish_rendezvous
er_fn er_tor_hs_establish_rendezvous
    push    rbx
    push    r12
    mov     ebx, edi
    mov     r12, rsi
    lea     rdi, [rel tor_hs_msg]
    mov     rsi, r12
    call    er_tor_hs_build_establish_rendezvous
    test    eax, eax
    js      .fail
    mov     edi, ebx
    xor     esi, esi
    mov     edx, TOR_RELAY_ESTABLISH_RENDEZVOUS
    lea     rcx, [rel tor_hs_msg]
    mov     r8d, eax
    call    er_tor_send_relay
    test    eax, eax
    js      .fail
    mov     edi, ebx
    lea     rsi, [rel tor_hs_tmp_stream]
    lea     rdx, [rel tor_hs_tmp_cmd]
    lea     rcx, [rel tor_hs_msg]
    lea     r8, [rel tor_hs_tmp_len]
    call    er_tor_recv_relay
    test    eax, eax
    js      .fail
    cmp     byte [rel tor_hs_tmp_cmd], TOR_RELAY_RENDEZVOUS_ESTABLISHED
    jne     .fail
    lea     rdi, [rel tor_hs_msg]
    mov     esi, [rel tor_hs_tmp_len]
    call    er_tor_hs_parse_rendezvous_established
    test    eax, eax
    js      .fail
    xor     eax, eax
    er_ok
    pop     r12
    pop     rbx
    er_ret
.fail:
    mov     eax, -1
    pop     r12
    pop     rbx
    er_ret

; er_tor_hs_establish_intro(circ_id, auth_key, handshake_auth, sig, sig_len)
; Sends ESTABLISH_INTRO and waits for INTRO_ESTABLISHED.
global er_tor_hs_establish_intro
er_fn er_tor_hs_establish_intro
    push    rbx
    push    r12
    mov     ebx, edi
    mov     r12, rsi
    lea     rdi, [rel tor_hs_msg]
    mov     rsi, r12
    call    er_tor_hs_build_establish_intro_v3
    test    eax, eax
    js      .fail
    mov     edi, ebx
    xor     esi, esi
    mov     edx, TOR_RELAY_ESTABLISH_INTRO
    lea     rcx, [rel tor_hs_msg]
    mov     r8d, eax
    call    er_tor_send_relay
    test    eax, eax
    js      .fail
    mov     edi, ebx
    lea     rsi, [rel tor_hs_tmp_stream]
    lea     rdx, [rel tor_hs_tmp_cmd]
    lea     rcx, [rel tor_hs_msg]
    lea     r8, [rel tor_hs_tmp_len]
    call    er_tor_recv_relay
    test    eax, eax
    js      .fail
    cmp     byte [rel tor_hs_tmp_cmd], TOR_RELAY_INTRO_ESTABLISHED
    jne     .fail
    lea     rdi, [rel tor_hs_msg]
    mov     esi, [rel tor_hs_tmp_len]
    call    er_tor_hs_parse_intro_established
    test    eax, eax
    js      .fail
    xor     eax, eax
    er_ok
    pop     r12
    pop     rbx
    er_ret
.fail:
    mov     eax, -1
    pop     r12
    pop     rbx
    er_ret

; er_tor_hs_send_introduce1(circ_id, auth_key, encrypted, encrypted_len)
; Sends INTRODUCE1 and waits for INTRODUCE_ACK status 0.
global er_tor_hs_send_introduce1
er_fn er_tor_hs_send_introduce1
    push    rbx
    mov     ebx, edi
    lea     rdi, [rel tor_hs_msg]
    call    er_tor_hs_build_introduce1_prefix
    test    eax, eax
    js      .fail
    mov     edi, ebx
    xor     esi, esi
    mov     edx, TOR_RELAY_INTRODUCE1
    lea     rcx, [rel tor_hs_msg]
    mov     r8d, eax
    call    er_tor_send_relay
    test    eax, eax
    js      .fail
    mov     edi, ebx
    lea     rsi, [rel tor_hs_tmp_stream]
    lea     rdx, [rel tor_hs_tmp_cmd]
    lea     rcx, [rel tor_hs_msg]
    lea     r8, [rel tor_hs_tmp_len]
    call    er_tor_recv_relay
    test    eax, eax
    js      .fail
    cmp     byte [rel tor_hs_tmp_cmd], TOR_RELAY_INTRODUCE_ACK
    jne     .fail
    lea     rdi, [rel tor_hs_msg]
    mov     esi, [rel tor_hs_tmp_len]
    call    er_tor_hs_parse_introduce_ack
    test    eax, eax
    js      .fail
    cmp     eax, TOR_HS_INTRO_ACK_OK
    jne     .fail
    xor     eax, eax
    er_ok
    pop     rbx
    er_ret
.fail:
    mov     eax, -1
    pop     rbx
    er_ret

; er_tor_hs_send_rendezvous1(circ_id, cookie, handshake_info, handshake_len)
global er_tor_hs_send_rendezvous1
er_fn er_tor_hs_send_rendezvous1
    push    rbx
    mov     ebx, edi
    lea     rdi, [rel tor_hs_msg]
    call    er_tor_hs_build_rendezvous1
    test    eax, eax
    js      .fail
    mov     edi, ebx
    xor     esi, esi
    mov     edx, TOR_RELAY_RENDEZVOUS1
    lea     rcx, [rel tor_hs_msg]
    mov     r8d, eax
    call    er_tor_send_relay
    pop     rbx
    er_ret
.fail:
    mov     eax, -1
    pop     rbx
    er_ret

; er_tor_hs_wait_rendezvous2(circ_id, out_handshake, out_len)
; Waits on the rendezvous circuit for RENDEZVOUS2 and copies the service
; handshake info to caller storage. Returns eax=0, or -1 on protocol failure.
global er_tor_hs_wait_rendezvous2
er_fn er_tor_hs_wait_rendezvous2
    push    rbx
    push    r12
    push    r13
    mov     ebx, edi
    mov     r12, rsi
    mov     r13, rdx
    test    r12, r12
    jz      .fail
    test    r13, r13
    jz      .fail
    mov     edi, ebx
    lea     rsi, [rel tor_hs_tmp_stream]
    lea     rdx, [rel tor_hs_tmp_cmd]
    lea     rcx, [rel tor_hs_msg]
    lea     r8, [rel tor_hs_tmp_len]
    call    er_tor_recv_relay
    test    eax, eax
    js      .fail
    cmp     byte [rel tor_hs_tmp_cmd], TOR_RELAY_RENDEZVOUS2
    jne     .fail
    lea     rdi, [rel tor_hs_msg]
    mov     esi, [rel tor_hs_tmp_len]
    mov     rdx, r12
    mov     rcx, r13
    call    er_tor_hs_parse_rendezvous2
    test    eax, eax
    js      .fail
    xor     eax, eax
    er_ok
    pop     r13
    pop     r12
    pop     rbx
    er_ret
.fail:
    mov     eax, -1
    pop     r13
    pop     r12
    pop     rbx
    er_ret

; er_tor_hs_service_wait_introduce2(circ_id, out_plain, out_len,
;                                   auth_key, onion_priv, onion_pub, subcred)
; Waits on an established introduction circuit, opens the INTRODUCE2
; encrypted field with the service's onion key, and returns plaintext.
global er_tor_hs_service_wait_introduce2
er_fn er_tor_hs_service_wait_introduce2
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 16
    mov     ebx, edi
    mov     r12, rsi
    mov     r13, rdx
    mov     r14, rcx
    mov     r15, r8
    mov     [rbp - 48], r9
    test    r12, r12
    jz      .fail
    test    r13, r13
    jz      .fail
    test    r14, r14
    jz      .fail
    test    r15, r15
    jz      .fail
    cmp     qword [rbp - 48], 0
    je      .fail
    cmp     qword [rbp + 16], 0
    je      .fail

    mov     edi, ebx
    lea     rsi, [rel tor_hs_tmp_stream]
    lea     rdx, [rel tor_hs_tmp_cmd]
    lea     rcx, [rel tor_hs_msg]
    lea     r8, [rel tor_hs_tmp_len]
    call    er_tor_recv_relay
    test    eax, eax
    js      .fail
    cmp     byte [rel tor_hs_tmp_cmd], TOR_RELAY_INTRODUCE2
    jne     .fail

    lea     rdi, [rel tor_hs_intro2_encrypted_ptr]
    lea     rsi, [rel tor_hs_intro2_encrypted_len]
    lea     rdx, [rel tor_hs_msg]
    mov     ecx, [rel tor_hs_tmp_len]
    call    er_tor_hs_extract_introduce_encrypted
    test    eax, eax
    js      .fail

    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    mov     rcx, r15
    mov     r8, [rbp - 48]
    mov     r9, [rbp + 16]
    sub     rsp, 16
    mov     rax, [rel tor_hs_intro2_encrypted_ptr]
    mov     [rsp], rax
    mov     eax, [rel tor_hs_intro2_encrypted_len]
    mov     [rsp + 8], rax
    call    er_tor_hs_open_introduce2
    add     rsp, 16
    test    eax, eax
    js      .fail
    xor     eax, eax
    er_ok
    add     rsp, 16
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    er_ret
.fail:
    mov     eax, -1
    add     rsp, 16
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    er_ret

; er_tor_hs_client_connect(intro_circ, rend_circ, cookie, auth_key, onion_key,
;                          client_priv, client_pub, subcred, linkspecs,
;                          linkspecs_len, out_handshake, out_len)
; Client-side onion-service rendezvous path:
;   1. ESTABLISH_RENDEZVOUS on the rendezvous circuit.
;   2. Build and send v3 INTRODUCE1 on the introduction circuit.
;   3. Wait for RENDEZVOUS2 on the rendezvous circuit.
; The caller supplies descriptor-derived auth_key, onion_key, subcred and
; intro-point linkspecs; this function performs the network relay sequence.
global er_tor_hs_client_connect
er_fn er_tor_hs_client_connect
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 24
    mov     ebx, edi        ; intro_circ
    mov     r12d, esi       ; rend_circ
    mov     r13, rdx        ; cookie
    mov     r14, rcx        ; auth_key
    mov     r15, r8         ; onion_key
    mov     [rsp], r9       ; client_priv

    test    r13, r13
    jz      .fail
    test    r14, r14
    jz      .fail
    test    r15, r15
    jz      .fail
    cmp     qword [rsp], 0
    je      .fail
    cmp     qword [rbp + 16], 0
    je      .fail
    cmp     qword [rbp + 24], 0
    je      .fail
    cmp     qword [rbp + 32], 0
    je      .fail
    cmp     qword [rbp + 48], 0
    je      .fail
    cmp     qword [rbp + 56], 0
    je      .fail

    mov     edi, r12d
    mov     rsi, r13
    call    er_tor_hs_establish_rendezvous
    test    eax, eax
    js      .fail

    lea     rdi, [rel tor_hs_plain]
    mov     rsi, r13
    mov     rdx, r15
    mov     ecx, 1
    mov     r8, [rbp + 32]
    mov     r9d, [rbp + 40]
    call    er_tor_hs_build_introduce1_plaintext
    test    eax, eax
    js      .fail
    mov     [rsp + 8], eax

    sub     rsp, 16
    lea     rax, [rel tor_hs_plain]
    mov     [rsp], rax
    mov     eax, [rsp + 24]
    mov     [rsp + 8], rax
    lea     rdi, [rel tor_hs_encrypted]
    mov     rsi, r14
    mov     rdx, r15
    mov     rcx, [rsp + 16]
    mov     r8, [rbp + 16]
    mov     r9, [rbp + 24]
    call    er_tor_hs_build_introduce1_ntor_encrypted
    add     rsp, 16
    test    eax, eax
    js      .fail
    mov     [rsp + 16], eax

    lea     rdi, [rel tor_hs_msg]
    mov     rsi, r14
    lea     rdx, [rel tor_hs_encrypted]
    mov     ecx, [rsp + 16]
    call    er_tor_hs_build_introduce1_prefix
    test    eax, eax
    js      .fail

    mov     edi, ebx
    xor     esi, esi
    mov     edx, TOR_RELAY_INTRODUCE1
    lea     rcx, [rel tor_hs_msg]
    mov     r8d, eax
    call    er_tor_send_relay
    test    eax, eax
    js      .fail

    mov     edi, ebx
    lea     rsi, [rel tor_hs_tmp_stream]
    lea     rdx, [rel tor_hs_tmp_cmd]
    lea     rcx, [rel tor_hs_msg]
    lea     r8, [rel tor_hs_tmp_len]
    call    er_tor_recv_relay
    test    eax, eax
    js      .fail
    cmp     byte [rel tor_hs_tmp_cmd], TOR_RELAY_INTRODUCE_ACK
    jne     .fail
    lea     rdi, [rel tor_hs_msg]
    mov     esi, [rel tor_hs_tmp_len]
    call    er_tor_hs_parse_introduce_ack
    test    eax, eax
    js      .fail
    cmp     eax, TOR_HS_INTRO_ACK_OK
    jne     .fail

    mov     edi, r12d
    mov     rsi, [rbp + 48]
    mov     rdx, [rbp + 56]
    call    er_tor_hs_wait_rendezvous2
    test    eax, eax
    js      .fail

    xor     eax, eax
    er_ok
    add     rsp, 24
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    er_ret
.fail:
    mov     eax, -1
    add     rsp, 24
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    er_ret

; er_tor_hs_client_connect_from_desc(intro_circ, rend_circ, cookie,
;                                    client_priv, client_pub, subcred,
;                                    desc_plain, desc_len,
;                                    out_handshake, out_len)
; Parses the decrypted second-layer descriptor intro point, then runs the
; client-side INTRODUCE1/RENDEZVOUS2 sequence against that descriptor data.
global er_tor_hs_client_connect_from_desc
er_fn er_tor_hs_client_connect_from_desc
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 16
    mov     ebx, edi        ; intro_circ
    mov     r12d, esi       ; rend_circ
    mov     r13, rdx        ; cookie
    mov     r14, rcx        ; client_priv
    mov     r15, r8         ; client_pub
    mov     [rbp - 48], r9  ; subcred

    test    r13, r13
    jz      .fail
    test    r14, r14
    jz      .fail
    test    r15, r15
    jz      .fail
    cmp     qword [rbp - 48], 0
    je      .fail
    cmp     qword [rbp + 16], 0
    je      .fail
    cmp     dword [rbp + 24], 0
    jle     .fail
    cmp     qword [rbp + 32], 0
    je      .fail
    cmp     qword [rbp + 40], 0
    je      .fail

    sub     rsp, 16
    mov     rax, [rbp + 16]
    mov     [rsp], rax
    mov     eax, [rbp + 24]
    mov     [rsp + 8], rax
    lea     rdi, [rel tor_hs_desc_auth_key]
    lea     rsi, [rel tor_hs_desc_onion_key]
    lea     rdx, [rel tor_hs_desc_enc_key]
    lea     rcx, [rel tor_hs_desc_linkspecs]
    mov     r8d, TOR_HS_RELAY_DATA_MAX
    lea     r9, [rel tor_hs_desc_linkspecs_len]
    call    er_tor_hs_desc_parse_intro
    add     rsp, 16
    test    eax, eax
    js      .fail

    sub     rsp, 48
    mov     [rsp], r15
    mov     rax, [rbp - 48]
    mov     [rsp + 8], rax
    lea     rax, [rel tor_hs_desc_linkspecs]
    mov     [rsp + 16], rax
    mov     eax, [rel tor_hs_desc_linkspecs_len]
    mov     [rsp + 24], rax
    mov     rax, [rbp + 32]
    mov     [rsp + 32], rax
    mov     rax, [rbp + 40]
    mov     [rsp + 40], rax
    mov     edi, ebx
    mov     esi, r12d
    mov     rdx, r13
    lea     rcx, [rel tor_hs_desc_auth_key]
    lea     r8, [rel tor_hs_desc_onion_key]
    mov     r9, r14
    call    er_tor_hs_client_connect
    add     rsp, 48
    test    eax, eax
    js      .fail

    xor     eax, eax
    er_ok
    add     rsp, 16
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    er_ret
.fail:
    mov     eax, -1
    add     rsp, 16
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    er_ret

; er_tor_hs_client_introduce_from_desc(intro_circ, rend_circ, cookie,
;                                      client_priv, client_pub, subcred,
;                                      desc_plain, desc_len,
;                                      rend_linkspecs, rend_linkspecs_len)
; Performs ESTABLISH_RENDEZVOUS and INTRODUCE1/ACK, but does not wait for
; RENDEZVOUS2. This lets a single-threaded self-connect service answer
; INTRODUCE2 before the client waits.
global er_tor_hs_client_introduce_from_desc
er_fn er_tor_hs_client_introduce_from_desc
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 16
    mov     ebx, edi
    mov     r12d, esi
    mov     r13, rdx
    mov     r14, rcx
    mov     r15, r8
    mov     [rbp - 48], r9
    test    r13, r13
    jz      .fail
    test    r14, r14
    jz      .fail
    test    r15, r15
    jz      .fail
    cmp     qword [rbp - 48], 0
    je      .fail
    cmp     qword [rbp + 16], 0
    je      .fail
    cmp     dword [rbp + 24], 0
    jle     .fail
    cmp     qword [rbp + 32], 0
    je      .fail
    cmp     dword [rbp + 40], 0
    jle     .fail

    sub     rsp, 16
    mov     rax, [rbp + 16]
    mov     [rsp], rax
    mov     eax, [rbp + 24]
    mov     [rsp + 8], rax
    lea     rdi, [rel tor_hs_desc_auth_key]
    lea     rsi, [rel tor_hs_desc_onion_key]
    lea     rdx, [rel tor_hs_desc_enc_key]
    lea     rcx, [rel tor_hs_desc_linkspecs]
    mov     r8d, TOR_HS_RELAY_DATA_MAX
    lea     r9, [rel tor_hs_desc_linkspecs_len]
    call    er_tor_hs_desc_parse_intro
    add     rsp, 16
    test    eax, eax
    js      .fail

    mov     edi, r12d
    mov     rsi, r13
    call    er_tor_hs_establish_rendezvous
    test    eax, eax
    js      .fail

    lea     rdi, [rel tor_hs_plain]
    mov     rsi, r13
    lea     rdx, [rel tor_hs_desc_onion_key]
    mov     ecx, 1
    mov     r8, [rbp + 32]
    mov     r9d, [rbp + 40]
    call    er_tor_hs_build_introduce1_plaintext
    test    eax, eax
    js      .fail
    mov     [rsp], eax

    sub     rsp, 16
    lea     rax, [rel tor_hs_plain]
    mov     [rsp], rax
    mov     eax, [rsp + 16]
    mov     [rsp + 8], rax
    lea     rdi, [rel tor_hs_encrypted]
    lea     rsi, [rel tor_hs_desc_auth_key]
    lea     rdx, [rel tor_hs_desc_onion_key]
    mov     rcx, r14
    mov     r8, r15
    mov     r9, [rbp - 48]
    call    er_tor_hs_build_introduce1_ntor_encrypted
    add     rsp, 16
    test    eax, eax
    js      .fail
    mov     [rsp + 8], eax

    lea     rdi, [rel tor_hs_msg]
    lea     rsi, [rel tor_hs_desc_auth_key]
    lea     rdx, [rel tor_hs_encrypted]
    mov     ecx, [rsp + 8]
    call    er_tor_hs_build_introduce1_prefix
    test    eax, eax
    js      .fail

    mov     edi, ebx
    xor     esi, esi
    mov     edx, TOR_RELAY_INTRODUCE1
    lea     rcx, [rel tor_hs_msg]
    mov     r8d, eax
    call    er_tor_send_relay
    test    eax, eax
    js      .fail

    mov     edi, ebx
    lea     rsi, [rel tor_hs_tmp_stream]
    lea     rdx, [rel tor_hs_tmp_cmd]
    lea     rcx, [rel tor_hs_msg]
    lea     r8, [rel tor_hs_tmp_len]
    call    er_tor_recv_relay
    test    eax, eax
    js      .fail
    cmp     byte [rel tor_hs_tmp_cmd], TOR_RELAY_INTRODUCE_ACK
    jne     .fail
    lea     rdi, [rel tor_hs_msg]
    mov     esi, [rel tor_hs_tmp_len]
    call    er_tor_hs_parse_introduce_ack
    test    eax, eax
    js      .fail
    cmp     eax, TOR_HS_INTRO_ACK_OK
    jne     .fail

    xor     eax, eax
    er_ok
    add     rsp, 16
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    er_ret
.fail:
    mov     eax, -1
    add     rsp, 16
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    er_ret

; er_tor_hs_open_client_stream(circ_id, stream_id, host, host_len, port)
; Opens an application stream through an established rendezvous circuit.
; Sends RELAY_BEGIN with "host:port\0" and waits for RELAY_CONNECTED on the
; same stream. The caller owns stream-id allocation.
global er_tor_hs_open_client_stream
er_fn er_tor_hs_open_client_stream
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    mov     ebx, edi
    mov     r12w, si
    mov     r13, rdx
    mov     r14d, ecx
    mov     r15w, r8w
    test    r12w, r12w
    jz      .fail
    test    r13, r13
    jz      .fail
    test    r14d, r14d
    jz      .fail
    mov     eax, r14d
    add     eax, 7          ; ':' + max 5 decimal port digits + NUL
    cmp     eax, TOR_HS_RELAY_DATA_MAX
    ja      .fail

    lea     rdi, [rel tor_hs_msg]
    mov     rsi, r13
    mov     edx, r14d
    call    er_memcpy
    lea     rdi, [rel tor_hs_msg]
    add     rdi, r14
    mov     byte [rdi], ':'
    inc     rdi
    movzx   esi, r15w
    call    _tor_hs_append_u16_dec
    mov     byte [rax], 0
    inc     rax
    lea     rcx, [rel tor_hs_msg]
    sub     rax, rcx

    mov     edi, ebx
    movzx   esi, r12w
    mov     edx, TOR_RELAY_BEGIN
    lea     rcx, [rel tor_hs_msg]
    mov     r8d, eax
    call    er_tor_send_relay
    test    eax, eax
    js      .fail

    mov     edi, ebx
    lea     rsi, [rel tor_hs_tmp_stream]
    lea     rdx, [rel tor_hs_tmp_cmd]
    lea     rcx, [rel tor_hs_msg]
    lea     r8, [rel tor_hs_tmp_len]
    call    er_tor_recv_relay
    test    eax, eax
    js      .fail
    cmp     word [rel tor_hs_tmp_stream], r12w
    jne     .fail
    cmp     byte [rel tor_hs_tmp_cmd], TOR_RELAY_CONNECTED
    jne     .fail
    xor     eax, eax
    er_ok
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret
.fail:
    mov     eax, -1
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret
