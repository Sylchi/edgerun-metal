; EdgeRun Tor onion-service self-hosted test runner — x86_64 assembly.

%include "x86_64/macros.inc"
%include "x86_64/crypto/tor_constants.inc"

extern er_tor_hs_build_establish_rendezvous
extern er_tor_hs_build_onion_address
extern er_tor_hs_b64_encode
extern er_tor_hs_b64_decode
extern er_tor_hs_desc_armor_message
extern er_tor_hs_desc_unarmor_message
extern er_tor_hs_desc_decrypt
extern er_tor_hs_desc_encrypt
extern er_tor_hs_cert_build
extern er_tor_hs_cert_armor_ed25519
extern er_tor_hs_cert_get_certified_key
extern er_tor_hs_cert_get_signing_key_ext
extern er_tor_hs_desc_parse_intro
extern er_tor_hs_parse_linkspecs
extern er_tor_hs_build_linkspecs
extern er_tor_hs_desc_build_intro_plaintext
extern er_tor_hs_desc_build_v3
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
extern er_tor_hs_parse_introduce_plaintext
extern er_tor_hs_extract_introduce_encrypted
extern er_tor_hs_build_introduce1_ntor_encrypted
extern er_tor_hs_derive_intro_keys_service
extern er_tor_hs_open_introduce2
extern er_tor_hs_build_establish_intro_v3
extern er_tor_hs_parse_intro_established
extern er_tor_hs_establish_rendezvous
extern er_tor_hs_establish_intro
extern er_tor_hs_send_introduce1
extern er_tor_hs_send_rendezvous1
extern er_tor_hs_wait_rendezvous2
extern er_tor_hs_client_connect
extern er_tor_hs_client_connect_from_desc
extern er_tor_hs_open_client_stream
extern er_tor_aes256_ctr
extern er_tor_curve25519_scalar_mult
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
identity_pub: times 32 db 0x11
identity_onion: db "ceirceirceirceirceirceirceirceirceirceirceirceircei7l4yd.onion"
identity_onion_len equ $ - identity_onion
intro_mac: times TOR_HS_INTRODUCE1_MAC_LEN db 0x9d
zero_iv: times 16 db 0
curve_base: db 9
            times 31 db 0
service_priv:
    db 0x31,0x32,0x33,0x34,0x35,0x36,0x37,0x38
    db 0x39,0x3a,0x3b,0x3c,0x3d,0x3e,0x3f,0x40
    db 0x41,0x42,0x43,0x44,0x45,0x46,0x47,0x48
    db 0x49,0x4a,0x4b,0x4c,0x4d,0x4e,0x4f,0x50
hs_t_hsmac: db "tor-hs-ntor-curve25519-sha3-256-1:hs_mac"
onion_host: db "examplehiddenservice.onion"
onion_host_len equ $ - onion_host
onion_begin: db "examplehiddenservice.onion:80", 0
onion_begin_len equ $ - onion_begin
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
desc_secret: db "secret-data"
desc_secret_len equ $ - desc_secret
desc_salt:
    db 0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07
    db 0x08,0x09,0x0a,0x0b,0x0c,0x0d,0x0e,0x0f
desc_constant: db "hsdir-superencrypted-data"
desc_constant_len equ $ - desc_constant
desc_plain: db "hello descriptor layer"
desc_plain_len equ $ - desc_plain
b64_input: db "foobar"
b64_expected: db "Zm9vYmFy"
b64_expected_len equ $ - b64_expected
armor_expected:
    db "-----BEGIN MESSAGE-----", 10
    db "Zm9vYmFy", 10
    db "-----END MESSAGE-----"
armor_expected_len equ $ - armor_expected
blinded_key_b64: db "AbCdEfGhIjKl"
blinded_key_b64_len equ $ - blinded_key_b64
cert_subject: times 32 db 0x44
cert_signer: times 32 db 0x99
cert_sig: times 64 db 0xaa
cert_blob:
    db 1, 9
    db 0, 0, 0, 1
    db 1
    times 32 db 0x44
    db 1
    db 0, 32, 4, 0
    times 32 db 0x99
    times 64 db 0xaa
cert_blob_len equ $ - cert_blob
auth_cert_armor:
    db "-----BEGIN ED25519 CERT-----", 10
    db "AQkAAAABAUREREREREREREREREREREREREREREREREREREREREREAQAgBACZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmaqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqo=", 10
    db "-----END ED25519 CERT-----", 10
auth_cert_armor_len equ $ - auth_cert_armor
desc_intro_text:
    db "create2-formats 2", 10
    db "introduction-point AAZ/AAABIykCFH5+fn5+fn5+fn5+fn5+fn5+fn5+", 10
    db "onion-key ntor S0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0s=", 10
    db "auth-key", 10
    db "-----BEGIN ED25519 CERT-----", 10
    db "AQkAAAABAUREREREREREREREREREREREREREREREREREREREREREAQAgBACZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmaqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqo=", 10
    db "-----END ED25519 CERT-----", 10
    db "enc-key ntor ISEhISEhISEhISEhISEhISEhISEhISEhISEhISEhISE=", 10
desc_intro_text_len equ $ - desc_intro_text
desc_v3_expected:
    db "hs-descriptor 3", 10
    db "descriptor-lifetime 180", 10
    db "descriptor-signing-key-cert", 10
    db "-----BEGIN ED25519 CERT-----", 10
    db "AQkAAAABAUREREREREREREREREREREREREREREREREREREREREREAQAgBACZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmaqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqo=", 10
    db "-----END ED25519 CERT-----", 10
    db "revision-counter 7", 10
    db "superencrypted", 10
    db "-----BEGIN MESSAGE-----", 10
    db "Zm9vYmFy", 10
    db "-----END MESSAGE-----", 10
    db "signature w8PDw8PDw8PDw8PDw8PDw8PDw8PDw8PDw8PDw8PDw8PDw8PDw8PDw8PDw8PDw8PDw8PDw8PDw8PDw8PDw8PDww==", 10
desc_v3_expected_len equ $ - desc_v3_expected
desc_expected:
    db 0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07
    db 0x08,0x09,0x0a,0x0b,0x0c,0x0d,0x0e,0x0f
    db 0xb7,0x56,0x64,0xd1,0x39,0x3d,0x8e,0xee
    db 0x52,0xb1,0x96,0x72,0x3e,0x5c,0x0f,0xea
    db 0x1e,0xd8,0x9e,0x5f,0x11,0x8b,0x4f,0xdc
    db 0x8d,0x3e,0x17,0xbe,0xe0,0xb5,0x16,0x6b
    db 0xae,0xbb,0xea,0x57,0x04,0x67,0x82,0x4e
    db 0x43,0xac,0x40,0xa2,0x5c,0xb2,0x3e,0xf7
    db 0x9a,0xdf,0x18,0x91,0xb9,0x9c
desc_expected_len equ $ - desc_expected
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
desc_text_out: resb 768
crypto_out: resb 64
service_keys: resb 64
service_onion_pub: resb TOR_HS_ONION_KEY_LEN_NTOR
derived_client_pub: resb TOR_HS_CLIENT_PK_LEN
client_hs_out: resb 64
onion_out: resb 62
desc_out: resb 128
cert_out: resb 160
armor_out: resb 256
decode_out: resb 128
plain_out: resb 128
plain_len: resd 1
cert_key_out: resb 32
parse_auth_out: resb 32
parse_onion_out: resb 32
parse_enc_out: resb 32
parse_link_id_out: resb 20
parse_link_ip_out: resd 1
parse_link_port_out: resw 1
parse_linkspecs_out: resb 64
parse_linkspecs_len_out: resd 1
intro_encrypted_ptr_out: resq 1
intro_encrypted_len_out: resd 1
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

    lea     rdi, [rel onion_out]
    lea     rsi, [rel identity_pub]
    call    er_tor_hs_build_onion_address
    ASSERT_EQ eax, identity_onion_len
    lea     rdi, [rel identity_onion]
    lea     rsi, [rel onion_out]
    mov     edx, identity_onion_len
    call    _mem_eq
    ASSERT eax

    lea     rdi, [rel armor_out]
    mov     esi, 128
    lea     rdx, [rel b64_input]
    mov     ecx, 6
    call    er_tor_hs_b64_encode
    ASSERT_EQ eax, b64_expected_len
    lea     rdi, [rel b64_expected]
    lea     rsi, [rel armor_out]
    mov     edx, b64_expected_len
    call    _mem_eq
    ASSERT eax

    lea     rdi, [rel armor_out]
    mov     esi, 128
    lea     rdx, [rel b64_input]
    mov     ecx, 6
    call    er_tor_hs_desc_armor_message
    ASSERT_EQ eax, armor_expected_len
    lea     rdi, [rel armor_expected]
    lea     rsi, [rel armor_out]
    mov     edx, armor_expected_len
    call    _mem_eq
    ASSERT eax
    lea     rdi, [rel decode_out]
    mov     esi, 128
    lea     rdx, [rel armor_out]
    mov     ecx, armor_expected_len
    call    er_tor_hs_desc_unarmor_message
    ASSERT_EQ eax, 6
    lea     rdi, [rel b64_input]
    lea     rsi, [rel decode_out]
    mov     edx, 6
    call    _mem_eq
    ASSERT eax
    lea     rdi, [rel decode_out]
    mov     esi, 128
    lea     rdx, [rel b64_expected]
    mov     ecx, b64_expected_len
    call    er_tor_hs_b64_decode
    ASSERT_EQ eax, 6
    lea     rdi, [rel b64_input]
    lea     rsi, [rel decode_out]
    mov     edx, 6
    call    _mem_eq
    ASSERT eax
    lea     rax, [rel cert_sig]
    push    rax
    lea     rdi, [rel cert_out]
    mov     esi, 160
    mov     edx, 9
    mov     ecx, 1
    lea     r8, [rel cert_subject]
    lea     r9, [rel cert_signer]
    call    er_tor_hs_cert_build
    add     rsp, 8
    ASSERT_EQ eax, cert_blob_len
    lea     rdi, [rel cert_blob]
    lea     rsi, [rel cert_out]
    mov     edx, cert_blob_len
    call    _mem_eq
    ASSERT eax
    lea     rdi, [rel armor_out]
    mov     esi, 256
    lea     rdx, [rel cert_out]
    mov     ecx, cert_blob_len
    call    er_tor_hs_cert_armor_ed25519
    ASSERT_EQ eax, auth_cert_armor_len
    lea     rdi, [rel auth_cert_armor]
    lea     rsi, [rel armor_out]
    mov     edx, auth_cert_armor_len
    call    _mem_eq
    ASSERT eax
    lea     rdi, [rel cert_key_out]
    lea     rsi, [rel cert_blob]
    mov     edx, cert_blob_len
    call    er_tor_hs_cert_get_certified_key
    ASSERT_EQ eax, 0
    lea     rdi, [rel cert_subject]
    lea     rsi, [rel cert_key_out]
    mov     edx, 32
    call    _mem_eq
    ASSERT eax
    lea     rdi, [rel cert_key_out]
    lea     rsi, [rel cert_blob]
    mov     edx, cert_blob_len
    call    er_tor_hs_cert_get_signing_key_ext
    ASSERT_EQ eax, 0
    lea     rdi, [rel cert_signer]
    lea     rsi, [rel cert_key_out]
    mov     edx, 32
    call    _mem_eq
    ASSERT eax
    push    desc_intro_text_len
    lea     rax, [rel desc_intro_text]
    push    rax
    lea     rdi, [rel parse_auth_out]
    lea     rsi, [rel parse_onion_out]
    lea     rdx, [rel parse_enc_out]
    lea     rcx, [rel copy_buf]
    mov     r8d, TOR_HS_RELAY_DATA_MAX
    lea     r9, [rel copy_len]
    call    er_tor_hs_desc_parse_intro
    add     rsp, 16
    ASSERT_EQ eax, 0
    ASSERT_EQ dword [rel copy_len], 30
    lea     rdi, [rel cert_subject]
    lea     rsi, [rel parse_auth_out]
    mov     edx, 32
    call    _mem_eq
    ASSERT eax
    lea     rdi, [rel onion_key]
    lea     rsi, [rel parse_onion_out]
    mov     edx, 32
    call    _mem_eq
    ASSERT eax
    lea     rdi, [rel client_pk]
    lea     rsi, [rel parse_enc_out]
    mov     edx, 32
    call    _mem_eq
    ASSERT eax
    lea     rdi, [rel linkspecs]
    lea     rsi, [rel copy_buf]
    mov     edx, 30
    call    _mem_eq
    ASSERT eax
    sub     rsp, 16
    mov     qword [rsp], auth_cert_armor_len
    lea     rax, [rel client_pk]
    mov     [rsp + 8], rax
    lea     rdi, [rel desc_text_out]
    mov     esi, 768
    lea     rdx, [rel linkspecs]
    mov     ecx, 30
    lea     r8, [rel onion_key]
    lea     r9, [rel auth_cert_armor]
    call    er_tor_hs_desc_build_intro_plaintext
    add     rsp, 16
    ASSERT_EQ eax, desc_intro_text_len
    lea     rdi, [rel desc_intro_text]
    lea     rsi, [rel desc_text_out]
    mov     edx, desc_intro_text_len
    call    _mem_eq
    ASSERT eax

    sub     rsp, 40
    mov     qword [rsp], 7
    mov     qword [rsp + 8], 180
    lea     rax, [rel armor_expected]
    mov     [rsp + 16], rax
    mov     qword [rsp + 24], armor_expected_len
    lea     rax, [rel intro_sig]
    mov     [rsp + 32], rax
    lea     rdi, [rel desc_text_out]
    mov     esi, 768
    lea     rdx, [rel blinded_key_b64]
    mov     ecx, blinded_key_b64_len
    lea     r8, [rel auth_cert_armor]
    mov     r9d, auth_cert_armor_len
    call    er_tor_hs_desc_build_v3
    add     rsp, 40
    ASSERT_EQ eax, desc_v3_expected_len
    lea     rdi, [rel desc_v3_expected]
    lea     rsi, [rel desc_text_out]
    mov     edx, desc_v3_expected_len
    call    _mem_eq
    ASSERT eax

    lea     rdi, [rel parse_link_id_out]
    lea     rsi, [rel parse_link_ip_out]
    lea     rdx, [rel parse_link_port_out]
    lea     rcx, [rel copy_buf]
    mov     r8d, 30
    call    er_tor_hs_parse_linkspecs
    ASSERT_EQ eax, 0
    ASSERT_EQ dword [rel parse_link_ip_out], 0x0100007f
    ASSERT_EQ word [rel parse_link_port_out], 9001
    lea     rdi, [rel linkspecs + 10]
    lea     rsi, [rel parse_link_id_out]
    mov     edx, 20
    call    _mem_eq
    ASSERT eax

    lea     rax, [rel desc_plain]
    push    desc_plain_len
    push    rax
    push    desc_constant_len
    lea     rax, [rel desc_constant]
    push    rax
    lea     rax, [rel desc_salt]
    push    rax
    lea     rdi, [rel desc_out]
    mov     esi, 128
    lea     rdx, [rel desc_secret]
    mov     ecx, desc_secret_len
    lea     r8, [rel subcred]
    mov     r9d, 7
    call    er_tor_hs_desc_encrypt
    add     rsp, 40
    ASSERT_EQ eax, desc_expected_len
    lea     rdi, [rel desc_expected]
    lea     rsi, [rel desc_out]
    mov     edx, desc_expected_len
    call    _mem_eq
    ASSERT eax
    lea     rax, [rel desc_out]
    push    desc_expected_len
    push    rax
    push    desc_constant_len
    lea     rax, [rel desc_constant]
    push    rax
    push    7
    lea     rdi, [rel plain_out]
    mov     esi, 128
    lea     rdx, [rel plain_len]
    lea     rcx, [rel desc_secret]
    mov     r8d, desc_secret_len
    lea     r9, [rel subcred]
    call    er_tor_hs_desc_decrypt
    add     rsp, 40
    ASSERT_EQ eax, 0
    ASSERT_EQ dword [rel plain_len], desc_plain_len
    lea     rdi, [rel desc_plain]
    lea     rsi, [rel plain_out]
    mov     edx, desc_plain_len
    call    _mem_eq
    ASSERT eax
    xor     byte [rel desc_out + desc_expected_len - 1], 1
    lea     rax, [rel desc_out]
    push    desc_expected_len
    push    rax
    push    desc_constant_len
    lea     rax, [rel desc_constant]
    push    rax
    push    7
    lea     rdi, [rel plain_out]
    mov     esi, 128
    lea     rdx, [rel plain_len]
    lea     rcx, [rel desc_secret]
    mov     r8d, desc_secret_len
    lea     r9, [rel subcred]
    call    er_tor_hs_desc_decrypt
    add     rsp, 40
    ASSERT_EQ eax, -1
    xor     byte [rel desc_out + desc_expected_len - 1], 1

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

    lea     rdi, [rel parse_linkspecs_out]
    mov     esi, 0x0100007f
    mov     edx, 9001
    lea     rcx, [rel linkspecs + 10]
    call    er_tor_hs_build_linkspecs
    ASSERT_EQ eax, 30
    lea     rdi, [rel linkspecs]
    lea     rsi, [rel parse_linkspecs_out]
    mov     edx, 30
    call    _mem_eq
    ASSERT eax

    sub     rsp, 16
    lea     rax, [rel buf]
    mov     [rsp], rax
    mov     qword [rsp + 8], TOR_HS_INTRODUCE1_PLAINTEXT_BASE_LEN + 30
    lea     rdi, [rel copy_buf]
    lea     rsi, [rel parse_onion_out]
    lea     rdx, [rel parse_linkspecs_out]
    mov     ecx, 64
    lea     r8, [rel parse_linkspecs_len_out]
    call    er_tor_hs_parse_introduce_plaintext
    add     rsp, 16
    ASSERT_EQ eax, 0
    ASSERT_EQ dword [rel parse_linkspecs_len_out], 30
    lea     rdi, [rel cookie]
    lea     rsi, [rel copy_buf]
    mov     edx, TOR_HS_RENDEZVOUS_COOKIE_LEN
    call    _mem_eq
    ASSERT eax
    lea     rdi, [rel onion_key]
    lea     rsi, [rel parse_onion_out]
    mov     edx, TOR_HS_ONION_KEY_LEN_NTOR
    call    _mem_eq
    ASSERT eax
    lea     rdi, [rel linkspecs]
    lea     rsi, [rel parse_linkspecs_out]
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

    ; Service-owned node path: derive the same hs-ntor INTRODUCE2 keys from
    ; our onion private key, open the encrypted field, and recover plaintext.
    lea     rdi, [rel service_onion_pub]
    lea     rsi, [rel service_priv]
    lea     rdx, [rel curve_base]
    call    er_tor_curve25519_scalar_mult
    lea     rdi, [rel derived_client_pub]
    lea     rsi, [rel client_priv]
    lea     rdx, [rel curve_base]
    call    er_tor_curve25519_scalar_mult

    lea     rdi, [rel crypto_out]
    lea     rsi, [rel auth_key]
    lea     rdx, [rel service_onion_pub]
    lea     rcx, [rel client_priv]
    lea     r8, [rel derived_client_pub]
    lea     r9, [rel subcred]
    call    er_tor_hs_derive_intro_keys
    ASSERT_EQ eax, 0

    lea     rdi, [rel service_keys]
    lea     rsi, [rel auth_key]
    lea     rdx, [rel service_priv]
    lea     rcx, [rel service_onion_pub]
    lea     r8, [rel derived_client_pub]
    lea     r9, [rel subcred]
    call    er_tor_hs_derive_intro_keys_service
    ASSERT_EQ eax, 0
    lea     rdi, [rel crypto_out]
    lea     rsi, [rel service_keys]
    mov     edx, 64
    call    _mem_eq
    ASSERT eax

    sub     rsp, 16
    lea     rax, [rel encrypted]
    mov     [rsp], rax
    mov     qword [rsp + 8], 8
    lea     rdi, [rel buf]
    lea     rsi, [rel auth_key]
    lea     rdx, [rel service_onion_pub]
    lea     rcx, [rel client_priv]
    lea     r8, [rel derived_client_pub]
    lea     r9, [rel subcred]
    call    er_tor_hs_build_introduce1_ntor_encrypted
    add     rsp, 16
    ASSERT_EQ eax, TOR_HS_CLIENT_PK_LEN + 8 + TOR_HS_INTRODUCE1_MAC_LEN
    mov     [rel copy_len], eax

    lea     rdi, [rel copy_buf]
    lea     rsi, [rel auth_key]
    lea     rdx, [rel buf]
    mov     ecx, [rel copy_len]
    call    er_tor_hs_build_introduce1_prefix
    ASSERT_EQ eax, TOR_HS_INTRODUCE1_PREFIX_LEN + TOR_HS_CLIENT_PK_LEN + 8 + TOR_HS_INTRODUCE1_MAC_LEN
    lea     rdi, [rel intro_encrypted_ptr_out]
    lea     rsi, [rel intro_encrypted_len_out]
    lea     rdx, [rel copy_buf]
    mov     ecx, eax
    call    er_tor_hs_extract_introduce_encrypted
    ASSERT_EQ eax, 0
    ASSERT_EQ dword [rel intro_encrypted_len_out], TOR_HS_CLIENT_PK_LEN + 8 + TOR_HS_INTRODUCE1_MAC_LEN
    mov     rax, [rel intro_encrypted_ptr_out]
    lea     rdx, [rel copy_buf + TOR_HS_INTRODUCE1_PREFIX_LEN]
    cmp     rax, rdx
    sete    al
    movzx   eax, al
    ASSERT eax
    lea     rdi, [rel intro_encrypted_ptr_out]
    lea     rsi, [rel intro_encrypted_len_out]
    lea     rdx, [rel buf]
    mov     ecx, [rel copy_len]
    call    er_tor_hs_extract_introduce_encrypted
    ASSERT_EQ eax, 0
    ASSERT_EQ dword [rel intro_encrypted_len_out], TOR_HS_CLIENT_PK_LEN + 8 + TOR_HS_INTRODUCE1_MAC_LEN

    sub     rsp, 16
    lea     rax, [rel buf]
    mov     [rsp], rax
    mov     eax, [rel copy_len]
    mov     [rsp + 8], rax
    lea     rdi, [rel copy_buf]
    lea     rsi, [rel copy_len]
    lea     rdx, [rel auth_key]
    lea     rcx, [rel service_priv]
    lea     r8, [rel service_onion_pub]
    lea     r9, [rel subcred]
    call    er_tor_hs_open_introduce2
    add     rsp, 16
    ASSERT_EQ eax, 0
    ASSERT_EQ dword [rel copy_len], 8
    lea     rdi, [rel encrypted]
    lea     rsi, [rel copy_buf]
    mov     edx, 8
    call    _mem_eq
    ASSERT eax

    xor     byte [rel buf + TOR_HS_CLIENT_PK_LEN + 8], 0x01
    sub     rsp, 16
    lea     rax, [rel buf]
    mov     [rsp], rax
    mov     eax, TOR_HS_CLIENT_PK_LEN + 8 + TOR_HS_INTRODUCE1_MAC_LEN
    mov     [rsp + 8], rax
    lea     rdi, [rel copy_buf]
    lea     rsi, [rel copy_len]
    lea     rdx, [rel auth_key]
    lea     rcx, [rel service_priv]
    lea     r8, [rel service_onion_pub]
    lea     r9, [rel subcred]
    call    er_tor_hs_open_introduce2
    add     rsp, 16
    ASSERT_EQ eax, -1

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

    sub     rsp, 48
    lea     rax, [rel client_pk]
    mov     [rsp], rax
    lea     rax, [rel subcred]
    mov     [rsp + 8], rax
    lea     rax, [rel linkspecs]
    mov     [rsp + 16], rax
    mov     qword [rsp + 24], 8
    lea     rax, [rel client_hs_out]
    mov     [rsp + 32], rax
    lea     rax, [rel copy_len]
    mov     [rsp + 40], rax
    mov     edi, 10
    mov     esi, 11
    lea     rdx, [rel cookie]
    lea     rcx, [rel auth_key]
    lea     r8, [rel onion_key]
    lea     r9, [rel client_priv]
    call    er_tor_hs_client_connect
    add     rsp, 48
    ASSERT_EQ eax, 0
    ASSERT_EQ dword [rel last_circ], 10
    ASSERT_EQ byte [rel last_cmd], TOR_RELAY_INTRODUCE1
    ASSERT_EQ dword [rel copy_len], 64
    lea     rdi, [rel handshake]
    lea     rsi, [rel client_hs_out]
    mov     edx, 64
    call    _mem_eq
    ASSERT eax

    sub     rsp, 32
    lea     rax, [rel desc_intro_text]
    mov     [rsp], rax
    mov     qword [rsp + 8], desc_intro_text_len
    lea     rax, [rel client_hs_out]
    mov     [rsp + 16], rax
    lea     rax, [rel copy_len]
    mov     [rsp + 24], rax
    mov     edi, 12
    mov     esi, 11
    lea     rdx, [rel cookie]
    lea     rcx, [rel client_priv]
    lea     r8, [rel client_pk]
    lea     r9, [rel subcred]
    call    er_tor_hs_client_connect_from_desc
    add     rsp, 32
    ASSERT_EQ eax, 0
    ASSERT_EQ dword [rel last_circ], 12
    ASSERT_EQ byte [rel last_cmd], TOR_RELAY_INTRODUCE1
    ASSERT_EQ dword [rel copy_len], 64
    lea     rdi, [rel cert_subject]
    lea     rsi, [rel last_body + 23]
    mov     edx, TOR_HS_INTRO_AUTH_KEY_LEN
    call    _mem_eq
    ASSERT eax
    lea     rdi, [rel handshake]
    lea     rsi, [rel client_hs_out]
    mov     edx, 64
    call    _mem_eq
    ASSERT eax

    mov     edi, 11
    mov     esi, 3
    lea     rdx, [rel onion_host]
    mov     ecx, onion_host_len
    mov     r8d, 80
    call    er_tor_hs_open_client_stream
    ASSERT_EQ eax, 0
    ASSERT_EQ dword [rel last_circ], 11
    ASSERT_EQ word [rel last_stream], 3
    ASSERT_EQ byte [rel last_cmd], TOR_RELAY_BEGIN
    ASSERT_EQ dword [rel last_len], onion_begin_len
    lea     rdi, [rel onion_begin]
    lea     rsi, [rel last_body]
    mov     edx, onion_begin_len
    call    _mem_eq
    ASSERT eax

%ifdef HS_BENCH
    lea     rdi, [rel msg_hs_total]
    call    putstr
    call    rdtsc64
    mov     r12, rax

    sub     rsp, 48
    lea     rax, [rel client_pk]
    mov     [rsp], rax
    lea     rax, [rel subcred]
    mov     [rsp + 8], rax
    lea     rax, [rel linkspecs]
    mov     [rsp + 16], rax
    mov     qword [rsp + 24], 8
    lea     rax, [rel client_hs_out]
    mov     [rsp + 32], rax
    lea     rax, [rel copy_len]
    mov     [rsp + 40], rax
    mov     edi, 10
    mov     esi, 11
    lea     rdx, [rel cookie]
    lea     rcx, [rel auth_key]
    lea     r8, [rel onion_key]
    lea     r9, [rel client_priv]
    call    er_tor_hs_client_connect
    add     rsp, 48
    ASSERT_EQ eax, 0

    mov     edi, 11
    mov     esi, 4
    lea     rdx, [rel onion_host]
    mov     ecx, onion_host_len
    mov     r8d, 80
    call    er_tor_hs_open_client_stream
    ASSERT_EQ eax, 0

    call    rdtsc64
    sub     rax, r12
    mov     rdi, rax
    call    puthex64
    call    newline

    lea     rdi, [rel msg_hs_connect]
    call    putstr
    call    rdtsc64
    mov     r12, rax
    sub     rsp, 48
    lea     rax, [rel client_pk]
    mov     [rsp], rax
    lea     rax, [rel subcred]
    mov     [rsp + 8], rax
    lea     rax, [rel linkspecs]
    mov     [rsp + 16], rax
    mov     qword [rsp + 24], 8
    lea     rax, [rel client_hs_out]
    mov     [rsp + 32], rax
    lea     rax, [rel copy_len]
    mov     [rsp + 40], rax
    mov     edi, 10
    mov     esi, 11
    lea     rdx, [rel cookie]
    lea     rcx, [rel auth_key]
    lea     r8, [rel onion_key]
    lea     r9, [rel client_priv]
    call    er_tor_hs_client_connect
    add     rsp, 48
    ASSERT_EQ eax, 0
    call    rdtsc64
    sub     rax, r12
    mov     rdi, rax
    call    puthex64
    call    newline

    lea     rdi, [rel msg_hs_stream]
    call    putstr
    call    rdtsc64
    mov     r12, rax
    mov     edi, 11
    mov     esi, 5
    lea     rdx, [rel onion_host]
    mov     ecx, onion_host_len
    mov     r8d, 80
    call    er_tor_hs_open_client_stream
    ASSERT_EQ eax, 0
    call    rdtsc64
    sub     rax, r12
    mov     rdi, rax
    call    puthex64
    call    newline
%endif

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

%ifdef HS_BENCH
rdtsc64:
    lfence
    rdtsc
    shl     rdx, 32
    or      rax, rdx
    ret

putstr:
    push    rdi
    xor     rdx, rdx
.len:
    cmp     byte [rdi + rdx], 0
    je      .write
    inc     rdx
    jmp     .len
.write:
    mov     rsi, rdi
    mov     edi, 1
    mov     eax, 1
    syscall
    pop     rdi
    ret

puthex64:
    push    rbx
    push    rcx
    push    rdx
    lea     rsi, [rel hexbuf + 18]
    mov     byte [rsi], 0
    mov     rbx, rdi
    mov     ecx, 16
.digit:
    dec     rsi
    mov     edx, ebx
    and     edx, 0x0f
    mov     dl, [rel hexdigits + rdx]
    mov     [rsi], dl
    shr     rbx, 4
    dec     ecx
    jnz     .digit
    dec     rsi
    mov     byte [rsi], 'x'
    dec     rsi
    mov     byte [rsi], '0'
    mov     edi, 1
    mov     edx, 18
    mov     eax, 1
    syscall
    pop     rdx
    pop     rcx
    pop     rbx
    ret

newline:
    mov     edi, 1
    lea     rsi, [rel nl]
    mov     edx, 1
    mov     eax, 1
    syscall
    ret

SECTION .data
msg_hs_total: db "hs self-connect + stream cycles: ", 0
msg_hs_connect: db "hs self-connect cycles: ", 0
msg_hs_stream: db "hs stream-open cycles: ", 0
hexdigits: db "0123456789abcdef"
nl: db 10
hexbuf: times 19 db 0
SECTION .text
%endif

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
    cmp     edi, 11
    jne     .not_client_rend
    cmp     byte [rel last_cmd], TOR_RELAY_INTRODUCE1
    jne     .not_client_rend
    mov     byte [rdx], TOR_RELAY_RENDEZVOUS2
    lea     rdi, [rcx]
    lea     rsi, [rel handshake]
    mov     edx, 64
    push    r8
    call    er_memcpy
    pop     r8
    mov     dword [r8], 64
    xor     eax, eax
    ret
.not_client_rend:
    cmp     byte [rel last_cmd], TOR_RELAY_BEGIN
    je      .connected
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
.connected:
    mov     ax, [rel last_stream]
    mov     [rsi], ax
    mov     byte [rdx], TOR_RELAY_CONNECTED
    mov     dword [r8], 0
    xor     eax, eax
    ret
