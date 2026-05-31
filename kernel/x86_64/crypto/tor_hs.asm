; EdgeRun Tor onion-service protocol helpers — x86_64 assembly.
; Builds and parses HS relay-message bodies. Circuit cryptography and
; relay-cell framing stay in tor_cell.asm.

%include "x86_64/macros.inc"
%include "x86_64/crypto/tor_constants.inc"

extern er_memcpy
extern er_tor_send_relay
extern er_tor_recv_relay

SECTION .bss
tor_hs_msg: resb TOR_HS_RELAY_DATA_MAX
tor_hs_tmp_stream: resw 1
tor_hs_tmp_cmd: resb 1
tor_hs_tmp_len: resd 1

SECTION .text

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
