; EdgeRun Tor onion-service self-hosted test runner — x86_64 assembly.

%include "x86_64/macros.inc"
%include "x86_64/crypto/tor_constants.inc"

extern er_tor_hs_build_establish_rendezvous
extern er_tor_hs_mac32_sha3
extern er_tor_hs_kdf_sha3
extern er_tor_hs_derive_intro_keys
extern er_tor_hs_parse_rendezvous_established
extern er_tor_hs_build_rendezvous1
extern er_tor_hs_parse_rendezvous2
extern er_tor_hs_parse_introduce_ack
extern er_tor_hs_build_introduce1_prefix
extern er_tor_hs_build_introduce1_plaintext
extern er_tor_hs_build_introduce1_encrypted
extern er_tor_hs_build_introduce1_ntor_encrypted
extern er_tor_hs_build_establish_intro_v3
extern er_tor_hs_parse_intro_established
extern er_tor_hs_establish_rendezvous
extern er_tor_hs_establish_intro
extern er_tor_hs_send_introduce1
extern er_tor_hs_send_rendezvous1
extern er_tor_aes256_ctr
extern er_memcpy

SECTION .data
passed: dq 0
failed: dq 0

cookie: db 0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09
        db 0x0a,0x0b,0x0c,0x0d,0x0e,0x0f,0x10,0x11,0x12,0x13
handshake: times 64 db 0x5a
auth_key: times TOR_HS_INTRO_AUTH_KEY_LEN db 0xa5
onion_key: times TOR_HS_ONION_KEY_LEN_NTOR db 0x4b
client_priv: times TOR_CURVE25519_KEY_LEN db 0x11
subcred: times TOR_HS_SUBCRED_LEN db 0x55
handshake_auth: times TOR_HS_INTRO_HANDSHAKE_AUTH_LEN db 0x3c
intro_sig: times TOR_HS_ED25519_SIG_LEN db 0xc3
encrypted: db 1,2,3,4,5,6,7,8
client_pk: times TOR_HS_CLIENT_PK_LEN db 0x21
intro_mac: times TOR_HS_INTRODUCE1_MAC_LEN db 0x9d
zero_iv: times 16 db 0
hs_t_hsmac: db "tor-hs-ntor-curve25519-sha3-256-1:hs_mac"
linkspecs:
    db 0,6,127,0,0,1,35,41
    db 2,20
    times 20 db 0x7e
crypto_tag: db "tag"
crypto_key:
    db 0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07
    db 0x08,0x09,0x0a,0x0b,0x0c,0x0d,0x0e,0x0f
    db 0x10,0x11,0x12,0x13,0x14,0x15,0x16,0x17
    db 0x18,0x19,0x1a,0x1b,0x1c,0x1d,0x1e,0x1f
crypto_msg: db "abc"
crypto_mac_expected:
    db 0xd4,0x1b,0x54,0x24,0x30,0x1c,0x2d,0xba
    db 0x73,0x29,0x52,0x54,0x0f,0x72,0x75,0xf8
    db 0x1a,0x39,0x78,0xe3,0x3f,0xea,0x94,0xea
    db 0xb5,0xa0,0x05,0xf3,0x33,0x0c,0x56,0x99
crypto_kdf_expected:
    db 0xd4,0xd5,0xbd,0xec,0x5f,0x4b,0xb4,0xef
    db 0x43,0xc7,0xd2,0x0b,0xe8,0xbf,0xee,0xac
    db 0x16,0x4e,0xf4,0x92,0x68,0x41,0xf6,0x50
    db 0xd5,0xa0,0xd9,0xef,0x82,0xfc,0x74,0x1d
    db 0x99,0x39,0xaa,0x9e,0x33,0x0c,0x36,0x73
    db 0x51,0x80,0x92,0xfd,0x62,0xc0,0xac,0xd9
    db 0xf1,0x43,0x99,0xc1,0x30,0x07,0x94,0x8d
    db 0xbd,0xab,0x87,0x08,0x2d,0x97,0x99,0x56
intro_established_ok: db 0
intro_ack_ok: db 0,0,0
intro_ack_cant_relay: db 0, TOR_HS_INTRO_ACK_CANT_RELAY, 0

SECTION .bss
buf: resb TOR_HS_RELAY_DATA_MAX
copy_buf: resb TOR_HS_RELAY_DATA_MAX
crypto_out: resb 64
iv_copy: resb 16
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

    lea     rdi, [rel crypto_out]
    lea     rsi, [rel crypto_tag]
    mov     edx, 3
    lea     rcx, [rel crypto_key]
    lea     r8, [rel crypto_msg]
    mov     r9d, 3
    call    er_tor_hs_mac32_sha3
    ASSERT_EQ eax, 0
    lea     rdi, [rel crypto_mac_expected]
    lea     rsi, [rel crypto_out]
    mov     edx, 32
    call    _mem_eq
    ASSERT eax

    lea     rdi, [rel crypto_out]
    mov     esi, 64
    lea     rdx, [rel crypto_tag]
    mov     ecx, 3
    lea     r8, [rel crypto_msg]
    mov     r9d, 3
    call    er_tor_hs_kdf_sha3
    ASSERT_EQ eax, 0
    lea     rdi, [rel crypto_kdf_expected]
    lea     rsi, [rel crypto_out]
    mov     edx, 64
    call    _mem_eq
    ASSERT eax

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
    lea     rsi, [rel cookie]
    lea     rdx, [rel onion_key]
    mov     ecx, 2
    lea     r8, [rel linkspecs]
    mov     r9d, 30
    call    er_tor_hs_build_introduce1_plaintext
    ASSERT_EQ eax, TOR_HS_INTRODUCE1_PLAINTEXT_BASE_LEN + 30
    ASSERT_EQ byte [rel buf + 20], 0
    ASSERT_EQ byte [rel buf + 21], TOR_HS_ONION_KEY_TYPE_NTOR
    ASSERT_EQ byte [rel buf + 22], 0
    ASSERT_EQ byte [rel buf + 23], TOR_HS_ONION_KEY_LEN_NTOR
    ASSERT_EQ byte [rel buf + 56], 2
    lea     rdi, [rel cookie]
    lea     rsi, [rel buf]
    mov     edx, TOR_HS_RENDEZVOUS_COOKIE_LEN
    call    _mem_eq
    ASSERT eax
    lea     rdi, [rel onion_key]
    lea     rsi, [rel buf + 24]
    mov     edx, TOR_HS_ONION_KEY_LEN_NTOR
    call    _mem_eq
    ASSERT eax
    lea     rdi, [rel linkspecs]
    lea     rsi, [rel buf + TOR_HS_INTRODUCE1_PLAINTEXT_BASE_LEN]
    mov     edx, 30
    call    _mem_eq
    ASSERT eax

    lea     rdi, [rel buf]
    lea     rsi, [rel client_pk]
    lea     rdx, [rel encrypted]
    mov     ecx, 8
    lea     r8, [rel intro_mac]
    call    er_tor_hs_build_introduce1_encrypted
    ASSERT_EQ eax, TOR_HS_CLIENT_PK_LEN + 8 + TOR_HS_INTRODUCE1_MAC_LEN
    lea     rdi, [rel client_pk]
    lea     rsi, [rel buf]
    mov     edx, TOR_HS_CLIENT_PK_LEN
    call    _mem_eq
    ASSERT eax
    lea     rdi, [rel encrypted]
    lea     rsi, [rel buf + TOR_HS_CLIENT_PK_LEN]
    mov     edx, 8
    call    _mem_eq
    ASSERT eax
    lea     rdi, [rel intro_mac]
    lea     rsi, [rel buf + TOR_HS_CLIENT_PK_LEN + 8]
    mov     edx, TOR_HS_INTRODUCE1_MAC_LEN
    call    _mem_eq
    ASSERT eax

    lea     rdi, [rel crypto_out]
    lea     rsi, [rel auth_key]
    lea     rdx, [rel onion_key]
    lea     rcx, [rel client_priv]
    lea     r8, [rel client_pk]
    lea     r9, [rel subcred]
    call    er_tor_hs_derive_intro_keys
    ASSERT_EQ eax, 0

    sub     rsp, 16
    lea     rax, [rel encrypted]
    mov     [rsp], rax
    mov     qword [rsp + 8], 8
    lea     rdi, [rel buf]
    lea     rsi, [rel auth_key]
    lea     rdx, [rel onion_key]
    lea     rcx, [rel client_priv]
    lea     r8, [rel client_pk]
    lea     r9, [rel subcred]
    call    er_tor_hs_build_introduce1_ntor_encrypted
    add     rsp, 16
    ASSERT_EQ eax, TOR_HS_CLIENT_PK_LEN + 8 + TOR_HS_INTRODUCE1_MAC_LEN
    lea     rdi, [rel client_pk]
    lea     rsi, [rel buf]
    mov     edx, TOR_HS_CLIENT_PK_LEN
    call    _mem_eq
    ASSERT eax
    lea     rdi, [rel iv_copy]
    lea     rsi, [rel zero_iv]
    mov     edx, 16
    call    er_memcpy
    lea     rdi, [rel copy_buf]
    lea     rsi, [rel buf + TOR_HS_CLIENT_PK_LEN]
    mov     edx, 8
    lea     rcx, [rel crypto_out]
    lea     r8, [rel iv_copy]
    call    er_tor_aes256_ctr
    lea     rdi, [rel encrypted]
    lea     rsi, [rel copy_buf]
    mov     edx, 8
    call    _mem_eq
    ASSERT eax

    lea     rdi, [rel last_body]
    lea     rsi, [rel auth_key]
    mov     edx, TOR_HS_INTRO_AUTH_KEY_LEN
    call    er_memcpy
    mov     byte [rel last_body + TOR_HS_INTRO_AUTH_KEY_LEN], 0
    lea     rdi, [rel last_body + TOR_HS_INTRO_AUTH_KEY_LEN + 1]
    lea     rsi, [rel client_pk]
    mov     edx, TOR_HS_CLIENT_PK_LEN
    call    er_memcpy
    lea     rdi, [rel last_body + TOR_HS_INTRO_AUTH_KEY_LEN + 1 + TOR_HS_CLIENT_PK_LEN]
    lea     rsi, [rel buf + TOR_HS_CLIENT_PK_LEN]
    mov     edx, 8
    call    er_memcpy
    lea     rdi, [rel copy_buf + 64]
    lea     rsi, [rel hs_t_hsmac]
    mov     edx, TOR_HS_NTOR_T_HSMAC_LEN
    lea     rcx, [rel crypto_out + 32]
    lea     r8, [rel last_body]
    mov     r9d, TOR_HS_INTRO_AUTH_KEY_LEN + 1 + TOR_HS_CLIENT_PK_LEN + 8
    call    er_tor_hs_mac32_sha3
    ASSERT_EQ eax, 0
    lea     rdi, [rel copy_buf + 64]
    lea     rsi, [rel buf + TOR_HS_CLIENT_PK_LEN + 8]
    mov     edx, TOR_HS_INTRODUCE1_MAC_LEN
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
