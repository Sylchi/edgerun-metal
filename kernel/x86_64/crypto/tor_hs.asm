; EdgeRun Tor onion-service protocol helpers — x86_64 assembly.
; Builds and parses HS relay-message bodies. Circuit cryptography and
; relay-cell framing stay in tor_cell.asm.

%include "x86_64/macros.inc"
%include "x86_64/crypto/tor_constants.inc"

extern er_memcpy
extern er_sha3_256
extern er_shake256
extern er_tor_send_relay
extern er_tor_recv_relay

SECTION .bss
tor_hs_msg: resb TOR_HS_RELAY_DATA_MAX
tor_hs_crypto_buf: resb TOR_HS_CRYPTO_BUF_MAX
tor_hs_tmp_stream: resw 1
tor_hs_tmp_cmd: resb 1
tor_hs_tmp_len: resd 1

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
    cmp     r13d, TOR_HS_RELAY_DATA_MAX - 56
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
    lea     eax, [r13d + 56]
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
    cmp     r15d, TOR_HS_INTRODUCE1_MAX_LEN - TOR_HS_INTRODUCE1_PLAINTEXT_BASE_LEN
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
    cmp     r14d, TOR_HS_INTRODUCE1_MAX_LEN - TOR_HS_CLIENT_PK_LEN - TOR_HS_INTRODUCE1_MAC_LEN
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
