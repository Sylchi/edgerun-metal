; EdgeRun Tor onion-service self-hosted test runner — x86_64 assembly.

%include "x86_64/macros.inc"
%include "x86_64/crypto/tor_constants.inc"

extern er_tor_hs_build_establish_rendezvous
extern er_tor_hs_parse_rendezvous_established
extern er_tor_hs_build_rendezvous1
extern er_tor_hs_parse_rendezvous2
extern er_tor_hs_parse_introduce_ack
extern er_tor_hs_build_introduce1_prefix
extern er_tor_hs_build_establish_intro_v3
extern er_tor_hs_parse_intro_established
extern er_tor_hs_establish_rendezvous
extern er_tor_hs_establish_intro
extern er_tor_hs_send_introduce1
extern er_tor_hs_send_rendezvous1
extern er_memcpy

SECTION .data
passed: dq 0
failed: dq 0

cookie: db 0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09
        db 0x0a,0x0b,0x0c,0x0d,0x0e,0x0f,0x10,0x11,0x12,0x13
handshake: times 64 db 0x5a
auth_key: times TOR_HS_INTRO_AUTH_KEY_LEN db 0xa5
handshake_auth: times TOR_HS_INTRO_HANDSHAKE_AUTH_LEN db 0x3c
intro_sig: times TOR_HS_ED25519_SIG_LEN db 0xc3
encrypted: db 1,2,3,4,5,6,7,8
intro_established_ok: db 0
intro_ack_ok: db 0,0,0
intro_ack_cant_relay: db 0, TOR_HS_INTRO_ACK_CANT_RELAY, 0

SECTION .bss
buf: resb TOR_HS_RELAY_DATA_MAX
copy_buf: resb TOR_HS_RELAY_DATA_MAX
copy_len: resd 1
last_circ: resd 1
last_stream: resw 1
last_cmd: resb 1
last_len: resd 1
last_body: resb TOR_HS_RELAY_DATA_MAX

%macro ASSERT 1
    test    %1, %1
    jz      %%fail
    inc     qword [rel passed]
    jmp     %%done
%%fail:
    inc     qword [rel failed]
%%done:
%endmacro

%macro ASSERT_EQ 2
    cmp     %1, %2
    jne     %%fail
    inc     qword [rel passed]
    jmp     %%done
%%fail:
    inc     qword [rel failed]
%%done:
%endmacro

SECTION .text
global _start
_start:

    lea     rdi, [rel buf]
    lea     rsi, [rel cookie]
    call    er_tor_hs_build_establish_rendezvous
    ASSERT_EQ eax, TOR_HS_RENDEZVOUS_COOKIE_LEN
    lea     rdi, [rel cookie]
    lea     rsi, [rel buf]
    mov     edx, TOR_HS_RENDEZVOUS_COOKIE_LEN
    call    _mem_eq
    ASSERT eax

    lea     rdi, [rel buf]
    lea     rsi, [rel cookie]
    lea     rdx, [rel handshake]
    mov     ecx, 64
    call    er_tor_hs_build_rendezvous1
    ASSERT_EQ eax, TOR_HS_RENDEZVOUS_COOKIE_LEN + 64
    lea     rdi, [rel cookie]
    lea     rsi, [rel buf]
    mov     edx, TOR_HS_RENDEZVOUS_COOKIE_LEN
    call    _mem_eq
    ASSERT eax
    lea     rdi, [rel handshake]
    lea     rsi, [rel buf + TOR_HS_RENDEZVOUS_COOKIE_LEN]
    mov     edx, 64
    call    _mem_eq
    ASSERT eax

    lea     rdi, [rel handshake]
    mov     esi, 64
    lea     rdx, [rel copy_buf]
    lea     rcx, [rel copy_len]
    call    er_tor_hs_parse_rendezvous2
    ASSERT_EQ eax, 0
    ASSERT_EQ dword [rel copy_len], 64
    lea     rdi, [rel handshake]
    lea     rsi, [rel copy_buf]
    mov     edx, 64
    call    _mem_eq
    ASSERT eax

    lea     rdi, [rel intro_ack_ok]
    mov     esi, 3
    call    er_tor_hs_parse_introduce_ack
    ASSERT_EQ eax, TOR_HS_INTRO_ACK_OK
    lea     rdi, [rel intro_ack_cant_relay]
    mov     esi, 3
    call    er_tor_hs_parse_introduce_ack
    ASSERT_EQ eax, TOR_HS_INTRO_ACK_CANT_RELAY

    lea     rdi, [rel buf]
    lea     rsi, [rel auth_key]
    lea     rdx, [rel encrypted]
    mov     ecx, 8
    call    er_tor_hs_build_introduce1_prefix
    ASSERT_EQ eax, 64
    cmp     byte [rel buf + 20], TOR_HS_AUTH_KEY_TYPE_ED25519
    sete    al
    movzx   eax, al
    ASSERT eax
    ASSERT_EQ byte [rel buf + 21], 0
    ASSERT_EQ byte [rel buf + 22], TOR_HS_INTRO_AUTH_KEY_LEN
    ASSERT_EQ byte [rel buf + 55], 0
    lea     rdi, [rel auth_key]
    lea     rsi, [rel buf + 23]
    mov     edx, TOR_HS_INTRO_AUTH_KEY_LEN
    call    _mem_eq
    ASSERT eax
    lea     rdi, [rel encrypted]
    lea     rsi, [rel buf + 56]
    mov     edx, 8
    call    _mem_eq
    ASSERT eax

    lea     rdi, [rel buf]
    lea     rsi, [rel auth_key]
    lea     rdx, [rel handshake_auth]
    lea     rcx, [rel intro_sig]
    mov     r8d, TOR_HS_ED25519_SIG_LEN
    call    er_tor_hs_build_establish_intro_v3
    ASSERT_EQ eax, TOR_HS_ESTABLISH_INTRO_BASE_LEN + TOR_HS_ED25519_SIG_LEN
    ASSERT_EQ byte [rel buf], TOR_HS_AUTH_KEY_TYPE_ED25519
    ASSERT_EQ byte [rel buf + 1], 0
    ASSERT_EQ byte [rel buf + 2], TOR_HS_INTRO_AUTH_KEY_LEN
    ASSERT_EQ byte [rel buf + 35], 0
    ASSERT_EQ byte [rel buf + 68], 0
    ASSERT_EQ byte [rel buf + 69], TOR_HS_ED25519_SIG_LEN
    lea     rdi, [rel auth_key]
    lea     rsi, [rel buf + 3]
    mov     edx, TOR_HS_INTRO_AUTH_KEY_LEN
    call    _mem_eq
    ASSERT eax
    lea     rdi, [rel handshake_auth]
    lea     rsi, [rel buf + 36]
    mov     edx, TOR_HS_INTRO_HANDSHAKE_AUTH_LEN
    call    _mem_eq
    ASSERT eax
    lea     rdi, [rel intro_sig]
    lea     rsi, [rel buf + TOR_HS_ESTABLISH_INTRO_BASE_LEN]
    mov     edx, TOR_HS_ED25519_SIG_LEN
    call    _mem_eq
    ASSERT eax

    lea     rdi, [rel intro_established_ok]
    mov     esi, 1
    call    er_tor_hs_parse_intro_established
    ASSERT_EQ eax, 0

    mov     edi, 7
    lea     rsi, [rel cookie]
    call    er_tor_hs_establish_rendezvous
    ASSERT_EQ eax, 0
    ASSERT_EQ dword [rel last_circ], 7
    ASSERT_EQ word [rel last_stream], 0
    ASSERT_EQ byte [rel last_cmd], TOR_RELAY_ESTABLISH_RENDEZVOUS
    ASSERT_EQ dword [rel last_len], TOR_HS_RENDEZVOUS_COOKIE_LEN

    mov     edi, 8
    lea     rsi, [rel auth_key]
    lea     rdx, [rel handshake_auth]
    lea     rcx, [rel intro_sig]
    mov     r8d, TOR_HS_ED25519_SIG_LEN
    call    er_tor_hs_establish_intro
    ASSERT_EQ eax, 0
    ASSERT_EQ dword [rel last_circ], 8
    ASSERT_EQ word [rel last_stream], 0
    ASSERT_EQ byte [rel last_cmd], TOR_RELAY_ESTABLISH_INTRO
    ASSERT_EQ dword [rel last_len], TOR_HS_ESTABLISH_INTRO_BASE_LEN + TOR_HS_ED25519_SIG_LEN

    mov     edi, 6
    lea     rsi, [rel auth_key]
    lea     rdx, [rel encrypted]
    mov     ecx, 8
    call    er_tor_hs_send_introduce1
    ASSERT_EQ eax, 0
    ASSERT_EQ dword [rel last_circ], 6
    ASSERT_EQ word [rel last_stream], 0
    ASSERT_EQ byte [rel last_cmd], TOR_RELAY_INTRODUCE1
    ASSERT_EQ dword [rel last_len], 64

    mov     edi, 9
    lea     rsi, [rel cookie]
    lea     rdx, [rel handshake]
    mov     ecx, 64
    call    er_tor_hs_send_rendezvous1
    ASSERT_EQ eax, 0
    ASSERT_EQ dword [rel last_circ], 9
    ASSERT_EQ byte [rel last_cmd], TOR_RELAY_RENDEZVOUS1
    ASSERT_EQ dword [rel last_len], TOR_HS_RENDEZVOUS_COOKIE_LEN + 64

    mov     rax, [rel failed]
    test    rax, rax
    jnz     .exit_fail
    xor     edi, edi
    jmp     .exit
.exit_fail:
    mov     edi, 1
.exit:
    mov     eax, 60
    syscall

_mem_eq:
    push    rcx
    push    rsi
    push    rdi
    mov     rcx, rdx
    repz cmpsb
    setz    al
    movzx   eax, al
    pop     rdi
    pop     rsi
    pop     rcx
    ret

global er_tor_send_relay
er_tor_send_relay:
    mov     [rel last_circ], edi
    mov     [rel last_stream], si
    mov     [rel last_cmd], dl
    mov     [rel last_len], r8d
    test    r8d, r8d
    jz      .ok
    lea     rdi, [rel last_body]
    mov     rsi, rcx
    mov     edx, r8d
    call    er_memcpy
.ok:
    xor     eax, eax
    ret

global er_tor_recv_relay
er_tor_recv_relay:
    mov     word [rsi], 0
    cmp     byte [rel last_cmd], TOR_RELAY_ESTABLISH_INTRO
    je      .intro_established
    cmp     byte [rel last_cmd], TOR_RELAY_INTRODUCE1
    je      .introduce_ack
    mov     byte [rdx], TOR_RELAY_RENDEZVOUS_ESTABLISHED
    mov     dword [r8], 0
    xor     eax, eax
    ret
.intro_established:
    mov     byte [rdx], TOR_RELAY_INTRO_ESTABLISHED
    mov     byte [rcx], 0
    mov     dword [r8], 1
    xor     eax, eax
    ret
.introduce_ack:
    mov     byte [rdx], TOR_RELAY_INTRODUCE_ACK
    mov     byte [rcx], 0
    mov     byte [rcx + 1], 0
    mov     byte [rcx + 2], 0
    mov     dword [r8], 3
    xor     eax, eax
    ret
