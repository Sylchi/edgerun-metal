; EdgeRun hidden-service inbox/contact protocol self-test.

%include "x86_64/macros.inc"
%include "x86_64/crypto/tor_constants.inc"

extern er_tor_hs_app_init
extern er_tor_hs_app_build_contact_put
extern er_tor_hs_app_build_message_put
extern er_tor_hs_app_handle_frame
extern er_tor_hs_app_add_contact
extern er_tor_hs_app_send_contact
extern er_tor_hs_app_send_message
extern er_tor_hs_app_send_message_to_contact
extern er_tor_hs_app_recv_once
extern er_tor_hs_app_service_poll
extern er_tor_hs_app_contact_count
extern er_tor_hs_app_message_count
extern er_tor_hs_app_contact_ptr
extern er_tor_hs_app_message_ptr
extern er_memcpy

%define ER_HS_CONTACT_NLEN 32
%define ER_HS_CONTACT_ONION 36
%define ER_HS_CONTACT_OLEN 100
%define ER_HS_MSG_FLEN 32
%define ER_HS_MSG_BODY 36
%define ER_HS_MSG_BLEN 420

SECTION .data
passed: dq 0
failed: dq 0

name_alice: db "alice"
name_alice_len equ $ - name_alice
onion_alice: db "aliceexamplehiddenservice.onion"
onion_alice_len equ $ - onion_alice
body_hello: db "hello over onion inbox"
body_hello_len equ $ - body_hello
body_contact: db "contact book routed message"
body_contact_len equ $ - body_contact

SECTION .bss
frame: resb TOR_HS_RELAY_DATA_MAX
last_body: resb TOR_HS_RELAY_DATA_MAX
last_circ: resd 1
last_stream: resw 1
last_cmd: resb 1
last_len: resd 1

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
    call    er_tor_hs_app_init
    ASSERT_EQ eax, 0
    call    er_tor_hs_app_contact_count
    ASSERT_EQ eax, 0
    call    er_tor_hs_app_message_count
    ASSERT_EQ eax, 0

    lea     rdi, [rel frame]
    lea     rsi, [rel name_alice]
    mov     edx, name_alice_len
    lea     rcx, [rel onion_alice]
    mov     r8d, onion_alice_len
    call    er_tor_hs_app_build_contact_put
    ASSERT eax
    lea     rdi, [rel frame]
    mov     esi, eax
    call    er_tor_hs_app_handle_frame
    ASSERT_EQ eax, 0
    call    er_tor_hs_app_contact_count
    ASSERT_EQ eax, 1
    xor     edi, edi
    call    er_tor_hs_app_contact_ptr
    ASSERT rax
    mov     rbx, rax
    ASSERT_EQ dword [rbx + ER_HS_CONTACT_NLEN], name_alice_len
    ASSERT_EQ dword [rbx + ER_HS_CONTACT_OLEN], onion_alice_len
    lea     rdi, [rel name_alice]
    lea     rsi, [rbx]
    mov     edx, name_alice_len
    call    _mem_eq
    ASSERT eax
    lea     rdi, [rel onion_alice]
    lea     rsi, [rbx + ER_HS_CONTACT_ONION]
    mov     edx, onion_alice_len
    call    _mem_eq
    ASSERT eax

    lea     rdi, [rel frame]
    lea     rsi, [rel name_alice]
    mov     edx, name_alice_len
    lea     rcx, [rel body_hello]
    mov     r8d, body_hello_len
    call    er_tor_hs_app_build_message_put
    ASSERT eax
    lea     rdi, [rel frame]
    mov     esi, eax
    call    er_tor_hs_app_handle_frame
    ASSERT_EQ eax, 0
    call    er_tor_hs_app_message_count
    ASSERT_EQ eax, 1
    xor     edi, edi
    call    er_tor_hs_app_message_ptr
    ASSERT rax
    mov     rbx, rax
    ASSERT_EQ dword [rbx + ER_HS_MSG_FLEN], name_alice_len
    ASSERT_EQ dword [rbx + ER_HS_MSG_BLEN], body_hello_len
    lea     rdi, [rel body_hello]
    lea     rsi, [rbx + ER_HS_MSG_BODY]
    mov     edx, body_hello_len
    call    _mem_eq
    ASSERT eax

    sub     rsp, 8
    mov     qword [rsp], body_hello_len
    mov     edi, 77
    mov     esi, 3
    lea     rdx, [rel name_alice]
    mov     ecx, name_alice_len
    lea     r8, [rel body_hello]
    call    er_tor_hs_app_send_message
    add     rsp, 8
    ASSERT_EQ eax, 0
    ASSERT_EQ dword [rel last_circ], 77
    ASSERT_EQ word [rel last_stream], 3
    ASSERT_EQ byte [rel last_cmd], TOR_RELAY_DATA

    call    er_tor_hs_app_init
    ASSERT_EQ eax, 0
    mov     edi, 77
    mov     esi, 3
    call    er_tor_hs_app_recv_once
    ASSERT_EQ eax, 0
    call    er_tor_hs_app_message_count
    ASSERT_EQ eax, 1

    call    er_tor_hs_app_init
    ASSERT_EQ eax, 0
    lea     rdi, [rel name_alice]
    mov     esi, name_alice_len
    lea     rdx, [rel onion_alice]
    mov     ecx, onion_alice_len
    call    er_tor_hs_app_add_contact
    ASSERT_EQ eax, 0
    call    er_tor_hs_app_contact_count
    ASSERT_EQ eax, 1

    sub     rsp, 8
    mov     qword [rsp], onion_alice_len
    mov     edi, 88
    mov     esi, 4
    lea     rdx, [rel name_alice]
    mov     ecx, name_alice_len
    lea     r8, [rel onion_alice]
    call    er_tor_hs_app_send_contact
    add     rsp, 8
    ASSERT_EQ eax, 0
    ASSERT_EQ dword [rel last_circ], 88
    ASSERT_EQ word [rel last_stream], 4
    ASSERT_EQ byte [rel last_cmd], TOR_RELAY_DATA

    call    er_tor_hs_app_init
    ASSERT_EQ eax, 0
    mov     edi, 88
    mov     esi, 4
    call    er_tor_hs_app_recv_once
    ASSERT_EQ eax, 0
    call    er_tor_hs_app_contact_count
    ASSERT_EQ eax, 1

    call    er_tor_hs_app_init
    ASSERT_EQ eax, 0
    lea     rdi, [rel name_alice]
    mov     esi, name_alice_len
    lea     rdx, [rel onion_alice]
    mov     ecx, onion_alice_len
    call    er_tor_hs_app_add_contact
    ASSERT_EQ eax, 0
    sub     rsp, 8
    mov     qword [rsp], body_contact_len
    mov     edi, 99
    mov     esi, 5
    xor     edx, edx
    lea     rcx, [rel name_alice]
    mov     r8d, name_alice_len
    lea     r9, [rel body_contact]
    call    er_tor_hs_app_send_message_to_contact
    add     rsp, 8
    ASSERT_EQ eax, 0

    call    er_tor_hs_app_init
    ASSERT_EQ eax, 0
    mov     edi, 99
    mov     esi, 5
    mov     edx, 1
    call    er_tor_hs_app_service_poll
    ASSERT_EQ eax, 1
    call    er_tor_hs_app_message_count
    ASSERT_EQ eax, 1
    xor     edi, edi
    call    er_tor_hs_app_message_ptr
    ASSERT rax
    mov     rbx, rax
    ASSERT_EQ dword [rbx + ER_HS_MSG_BLEN], body_contact_len
    lea     rdi, [rel body_contact]
    lea     rsi, [rbx + ER_HS_MSG_BODY]
    mov     edx, body_contact_len
    call    _mem_eq
    ASSERT eax

    sub     rsp, 8
    mov     qword [rsp], body_contact_len
    mov     edi, 99
    mov     esi, 5
    mov     edx, 9
    lea     rcx, [rel name_alice]
    mov     r8d, name_alice_len
    lea     r9, [rel body_contact]
    call    er_tor_hs_app_send_message_to_contact
    add     rsp, 8
    ASSERT_EQ eax, -1

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
    mov     ax, [rel last_stream]
    mov     [rsi], ax
    mov     byte [rdx], TOR_RELAY_DATA
    mov     eax, [rel last_len]
    mov     [r8], eax
    lea     rdi, [rcx]
    lea     rsi, [rel last_body]
    mov     edx, eax
    call    er_memcpy
    xor     eax, eax
    ret
