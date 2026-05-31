; EdgeRun hidden-service inbox/contact protocol — x86_64 assembly.
; Runs over an established onion-service stream using RELAY_DATA.

%include "x86_64/macros.inc"
%include "x86_64/crypto/tor_constants.inc"

%define ER_HS_APP_MAGIC      0x53485245 ; "ERHS" little-endian
%define ER_HS_APP_VERSION    1
%define ER_HS_OP_CONTACT_PUT 1
%define ER_HS_OP_MESSAGE_PUT 2

%define ER_HS_CONTACT_MAX    16
%define ER_HS_CONTACT_SIZE   104
%define ER_HS_CONTACT_NAME   0
%define ER_HS_CONTACT_NLEN   32
%define ER_HS_CONTACT_ONION  36
%define ER_HS_CONTACT_OLEN   100

%define ER_HS_INBOX_MAX      32
%define ER_HS_MSG_SIZE       424
%define ER_HS_MSG_FROM       0
%define ER_HS_MSG_FLEN       32
%define ER_HS_MSG_BODY       36
%define ER_HS_MSG_BLEN       420

%define ER_HS_FRAME_HDR_LEN  8
%define ER_HS_NAME_MAX       31
%define ER_HS_ONION_MAX      63
%define ER_HS_BODY_MAX       384

extern er_memcpy
extern er_memset
extern er_tor_send_relay
extern er_tor_recv_relay

SECTION .bss
hs_app_contacts: resb ER_HS_CONTACT_MAX * ER_HS_CONTACT_SIZE
hs_app_messages: resb ER_HS_INBOX_MAX * ER_HS_MSG_SIZE
hs_app_contact_count: resd 1
hs_app_message_count: resd 1
hs_app_tmp_stream: resw 1
hs_app_tmp_cmd: resb 1
hs_app_tmp_len: resd 1
hs_app_tmp_data: resb TOR_HS_RELAY_DATA_MAX

SECTION .text

; er_tor_hs_app_init()
global er_tor_hs_app_init
er_fn er_tor_hs_app_init
    lea     rdi, [rel hs_app_contacts]
    xor     esi, esi
    mov     edx, ER_HS_CONTACT_MAX * ER_HS_CONTACT_SIZE
    call    er_memset
    lea     rdi, [rel hs_app_messages]
    xor     esi, esi
    mov     edx, ER_HS_INBOX_MAX * ER_HS_MSG_SIZE
    call    er_memset
    mov     dword [rel hs_app_contact_count], 0
    mov     dword [rel hs_app_message_count], 0
    xor     eax, eax
    er_ok
    er_ret

_hs_app_store_header:
    mov     dword [rdi], ER_HS_APP_MAGIC
    mov     byte [rdi + 4], ER_HS_APP_VERSION
    mov     byte [rdi + 5], sil
    mov     word [rdi + 6], 0
    ret

; er_tor_hs_app_build_contact_put(out, name, name_len, onion, onion_len)
; Frame: "ERHS" version op reserved2 name_len onion_len name onion
global er_tor_hs_app_build_contact_put
er_fn er_tor_hs_app_build_contact_put
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    mov     rbx, rdi
    mov     r12, rsi
    mov     r13d, edx
    mov     r14, rcx
    mov     r15d, r8d
    test    rbx, rbx
    jz      .fail
    test    r12, r12
    jz      .fail
    test    r14, r14
    jz      .fail
    test    r13d, r13d
    jz      .fail
    test    r15d, r15d
    jz      .fail
    cmp     r13d, ER_HS_NAME_MAX
    ja      .fail
    cmp     r15d, ER_HS_ONION_MAX
    ja      .fail
    mov     eax, ER_HS_FRAME_HDR_LEN + 2
    add     eax, r13d
    add     eax, r15d
    cmp     eax, TOR_HS_RELAY_DATA_MAX
    ja      .fail
    mov     rdi, rbx
    mov     esi, ER_HS_OP_CONTACT_PUT
    call    _hs_app_store_header
    mov     [rbx + ER_HS_FRAME_HDR_LEN], r13b
    mov     [rbx + ER_HS_FRAME_HDR_LEN + 1], r15b
    lea     rdi, [rbx + ER_HS_FRAME_HDR_LEN + 2]
    mov     rsi, r12
    mov     edx, r13d
    call    er_memcpy
    lea     rdi, [rbx + ER_HS_FRAME_HDR_LEN + 2 + r13]
    mov     rsi, r14
    mov     edx, r15d
    call    er_memcpy
    mov     eax, ER_HS_FRAME_HDR_LEN + 2
    add     eax, r13d
    add     eax, r15d
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

; er_tor_hs_app_build_message_put(out, from, from_len, body, body_len)
global er_tor_hs_app_build_message_put
er_fn er_tor_hs_app_build_message_put
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    mov     rbx, rdi
    mov     r12, rsi
    mov     r13d, edx
    mov     r14, rcx
    mov     r15d, r8d
    test    rbx, rbx
    jz      .fail
    test    r12, r12
    jz      .fail
    test    r14, r14
    jz      .fail
    test    r13d, r13d
    jz      .fail
    test    r15d, r15d
    jz      .fail
    cmp     r13d, ER_HS_NAME_MAX
    ja      .fail
    cmp     r15d, ER_HS_BODY_MAX
    ja      .fail
    mov     eax, ER_HS_FRAME_HDR_LEN + 3
    add     eax, r13d
    add     eax, r15d
    cmp     eax, TOR_HS_RELAY_DATA_MAX
    ja      .fail
    mov     rdi, rbx
    mov     esi, ER_HS_OP_MESSAGE_PUT
    call    _hs_app_store_header
    mov     [rbx + ER_HS_FRAME_HDR_LEN], r13b
    mov     eax, r15d
    shr     eax, 8
    mov     [rbx + ER_HS_FRAME_HDR_LEN + 1], al
    mov     [rbx + ER_HS_FRAME_HDR_LEN + 2], r15b
    lea     rdi, [rbx + ER_HS_FRAME_HDR_LEN + 3]
    mov     rsi, r12
    mov     edx, r13d
    call    er_memcpy
    lea     rdi, [rbx + ER_HS_FRAME_HDR_LEN + 3 + r13]
    mov     rsi, r14
    mov     edx, r15d
    call    er_memcpy
    mov     eax, ER_HS_FRAME_HDR_LEN + 3
    add     eax, r13d
    add     eax, r15d
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

; er_tor_hs_app_handle_frame(data, len)
global er_tor_hs_app_handle_frame
er_fn er_tor_hs_app_handle_frame
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    mov     rbx, rdi
    mov     r12d, esi
    test    rbx, rbx
    jz      .fail
    cmp     r12d, ER_HS_FRAME_HDR_LEN
    jb      .fail
    cmp     dword [rbx], ER_HS_APP_MAGIC
    jne     .fail
    cmp     byte [rbx + 4], ER_HS_APP_VERSION
    jne     .fail
    movzx   eax, byte [rbx + 5]
    cmp     eax, ER_HS_OP_CONTACT_PUT
    je      .contact
    cmp     eax, ER_HS_OP_MESSAGE_PUT
    je      .message
    jmp     .fail

.contact:
    cmp     r12d, ER_HS_FRAME_HDR_LEN + 2
    jb      .fail
    movzx   r13d, byte [rbx + ER_HS_FRAME_HDR_LEN]
    movzx   r14d, byte [rbx + ER_HS_FRAME_HDR_LEN + 1]
    test    r13d, r13d
    jz      .fail
    test    r14d, r14d
    jz      .fail
    cmp     r13d, ER_HS_NAME_MAX
    ja      .fail
    cmp     r14d, ER_HS_ONION_MAX
    ja      .fail
    mov     eax, ER_HS_FRAME_HDR_LEN + 2
    add     eax, r13d
    add     eax, r14d
    cmp     r12d, eax
    jb      .fail
    mov     eax, [rel hs_app_contact_count]
    cmp     eax, ER_HS_CONTACT_MAX
    jae     .fail
    imul    eax, ER_HS_CONTACT_SIZE
    lea     r15, [rel hs_app_contacts + rax]
    mov     [r15 + ER_HS_CONTACT_NLEN], r13d
    mov     [r15 + ER_HS_CONTACT_OLEN], r14d
    lea     rdi, [r15 + ER_HS_CONTACT_NAME]
    lea     rsi, [rbx + ER_HS_FRAME_HDR_LEN + 2]
    mov     edx, r13d
    call    er_memcpy
    mov     byte [r15 + ER_HS_CONTACT_NAME + r13], 0
    lea     rdi, [r15 + ER_HS_CONTACT_ONION]
    lea     rsi, [rbx + ER_HS_FRAME_HDR_LEN + 2 + r13]
    mov     edx, r14d
    call    er_memcpy
    mov     byte [r15 + ER_HS_CONTACT_ONION + r14], 0
    inc     dword [rel hs_app_contact_count]
    xor     eax, eax
    jmp     .ok

.message:
    cmp     r12d, ER_HS_FRAME_HDR_LEN + 3
    jb      .fail
    movzx   r13d, byte [rbx + ER_HS_FRAME_HDR_LEN]
    movzx   r14d, byte [rbx + ER_HS_FRAME_HDR_LEN + 1]
    shl     r14d, 8
    movzx   eax, byte [rbx + ER_HS_FRAME_HDR_LEN + 2]
    or      r14d, eax
    test    r13d, r13d
    jz      .fail
    test    r14d, r14d
    jz      .fail
    cmp     r13d, ER_HS_NAME_MAX
    ja      .fail
    cmp     r14d, ER_HS_BODY_MAX
    ja      .fail
    mov     eax, ER_HS_FRAME_HDR_LEN + 3
    add     eax, r13d
    add     eax, r14d
    cmp     r12d, eax
    jb      .fail
    mov     eax, [rel hs_app_message_count]
    cmp     eax, ER_HS_INBOX_MAX
    jae     .fail
    imul    eax, ER_HS_MSG_SIZE
    lea     r15, [rel hs_app_messages + rax]
    mov     [r15 + ER_HS_MSG_FLEN], r13d
    mov     [r15 + ER_HS_MSG_BLEN], r14d
    lea     rdi, [r15 + ER_HS_MSG_FROM]
    lea     rsi, [rbx + ER_HS_FRAME_HDR_LEN + 3]
    mov     edx, r13d
    call    er_memcpy
    mov     byte [r15 + ER_HS_MSG_FROM + r13], 0
    lea     rdi, [r15 + ER_HS_MSG_BODY]
    lea     rsi, [rbx + ER_HS_FRAME_HDR_LEN + 3 + r13]
    mov     edx, r14d
    call    er_memcpy
    mov     byte [r15 + ER_HS_MSG_BODY + r14], 0
    inc     dword [rel hs_app_message_count]
    xor     eax, eax
    jmp     .ok

.fail:
    mov     eax, -1
.ok:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

; er_tor_hs_app_send_message(circ_id, stream_id, from, from_len, body, body_len)
global er_tor_hs_app_send_message
er_fn er_tor_hs_app_send_message
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    mov     ebx, edi
    mov     r12w, si
    lea     rdi, [rel hs_app_tmp_data]
    mov     rsi, rdx
    mov     edx, ecx
    mov     rcx, r8
    mov     r8d, [rbp + 16]
    call    er_tor_hs_app_build_message_put
    test    eax, eax
    js      .fail
    mov     edi, ebx
    movzx   esi, r12w
    mov     edx, TOR_RELAY_DATA
    lea     rcx, [rel hs_app_tmp_data]
    mov     r8d, eax
    call    er_tor_send_relay
    pop     r12
    pop     rbx
    pop     rbp
    er_ret
.fail:
    mov     eax, -1
    pop     r12
    pop     rbx
    pop     rbp
    er_ret

; er_tor_hs_app_add_contact(name, name_len, onion, onion_len)
global er_tor_hs_app_add_contact
er_fn er_tor_hs_app_add_contact
    push    rbx
    push    r12
    push    r13
    mov     rbx, rdi
    mov     r12d, esi
    mov     r13, rdx
    mov     eax, ecx
    lea     rdi, [rel hs_app_tmp_data]
    mov     rsi, rbx
    mov     rcx, r13
    mov     edx, r12d
    mov     r8d, eax
    call    er_tor_hs_app_build_contact_put
    test    eax, eax
    js      .fail
    lea     rdi, [rel hs_app_tmp_data]
    mov     esi, eax
    call    er_tor_hs_app_handle_frame
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

; er_tor_hs_app_send_contact(circ_id, stream_id, name, name_len, onion, onion_len)
global er_tor_hs_app_send_contact
er_fn er_tor_hs_app_send_contact
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    mov     ebx, edi
    mov     r12w, si
    lea     rdi, [rel hs_app_tmp_data]
    mov     rsi, rdx
    mov     edx, ecx
    mov     rcx, r8
    mov     r8d, [rbp + 16]
    call    er_tor_hs_app_build_contact_put
    test    eax, eax
    js      .fail
    mov     edi, ebx
    movzx   esi, r12w
    mov     edx, TOR_RELAY_DATA
    lea     rcx, [rel hs_app_tmp_data]
    mov     r8d, eax
    call    er_tor_send_relay
    pop     r12
    pop     rbx
    pop     rbp
    er_ret
.fail:
    mov     eax, -1
    pop     r12
    pop     rbx
    pop     rbp
    er_ret

; er_tor_hs_app_send_message_to_contact(circ_id, stream_id, contact_idx,
;                                       from, from_len, body, body_len)
; Uses contact_idx as a bounds-checked send target. The caller still supplies
; the already-open HS stream for that contact.
global er_tor_hs_app_send_message_to_contact
er_fn er_tor_hs_app_send_message_to_contact
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    mov     ebx, edi
    mov     r12w, si
    mov     r13d, edx
    cmp     r13d, [rel hs_app_contact_count]
    jae     .fail
    test    rcx, rcx
    jz      .fail
    test    r9, r9
    jz      .fail
    sub     rsp, 8
    mov     eax, [rbp + 16]
    mov     qword [rsp], 0
    mov     [rsp], eax
    mov     edi, ebx
    movzx   esi, r12w
    mov     rdx, rcx
    mov     ecx, r8d
    mov     r8, r9
    call    er_tor_hs_app_send_message
    add     rsp, 8
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    er_ret
.fail:
    mov     eax, -1
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    er_ret

; er_tor_hs_app_recv_once(circ_id, expected_stream)
global er_tor_hs_app_recv_once
er_fn er_tor_hs_app_recv_once
    push    rbx
    push    r12
    mov     ebx, edi
    mov     r12w, si
    mov     edi, ebx
    lea     rsi, [rel hs_app_tmp_stream]
    lea     rdx, [rel hs_app_tmp_cmd]
    lea     rcx, [rel hs_app_tmp_data]
    lea     r8, [rel hs_app_tmp_len]
    call    er_tor_recv_relay
    test    eax, eax
    js      .fail
    cmp     word [rel hs_app_tmp_stream], r12w
    jne     .fail
    cmp     byte [rel hs_app_tmp_cmd], TOR_RELAY_DATA
    jne     .fail
    lea     rdi, [rel hs_app_tmp_data]
    mov     esi, [rel hs_app_tmp_len]
    call    er_tor_hs_app_handle_frame
    pop     r12
    pop     rbx
    er_ret
.fail:
    mov     eax, -1
    pop     r12
    pop     rbx
    er_ret

; er_tor_hs_app_service_poll(circ_id, expected_stream, max_frames)
; Drains up to max_frames RELAY_DATA frames into contacts/inbox. Returns the
; number of frames handled. A receive miss after at least one frame is success.
global er_tor_hs_app_service_poll
er_fn er_tor_hs_app_service_poll
    push    rbx
    push    r12
    push    r13
    push    r14
    mov     ebx, edi
    mov     r12w, si
    mov     r13d, edx
    xor     r14d, r14d
    test    r13d, r13d
    jz      .done
.loop:
    mov     edi, ebx
    movzx   esi, r12w
    call    er_tor_hs_app_recv_once
    test    eax, eax
    js      .miss
    inc     r14d
    dec     r13d
    jz      .done
    jmp     .loop
.miss:
    jmp     .done
.done:
    mov     eax, r14d
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

; Accessors for tests/UI.
global er_tor_hs_app_contact_count
er_tor_hs_app_contact_count:
    mov     eax, [rel hs_app_contact_count]
    ret

global er_tor_hs_app_message_count
er_tor_hs_app_message_count:
    mov     eax, [rel hs_app_message_count]
    ret

global er_tor_hs_app_contact_ptr
er_tor_hs_app_contact_ptr:
    cmp     edi, ER_HS_CONTACT_MAX
    jae     .bad
    imul    edi, ER_HS_CONTACT_SIZE
    lea     rax, [rel hs_app_contacts + rdi]
    ret
.bad:
    xor     eax, eax
    ret

global er_tor_hs_app_message_ptr
er_tor_hs_app_message_ptr:
    cmp     edi, ER_HS_INBOX_MAX
    jae     .bad
    imul    edi, ER_HS_MSG_SIZE
    lea     rax, [rel hs_app_messages + rdi]
    ret
.bad:
    xor     eax, eax
    ret
