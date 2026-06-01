; EdgeRun object serialization self-test — x86_64 assembly.

%include "x86_64/macros.inc"
%include "test/test_macros.inc"
%include "x86_64/object/object_constants.inc"

extern er_object_requirements_encode
extern er_object_requirements_decode
extern er_object_requirements_hash
extern er_object_header_encode
extern er_object_header_decode
extern er_object_owner_encode
extern er_object_owner_decode
extern er_object_child_encode
extern er_object_child_decode
extern er_object_envelope_encode
extern er_object_envelope_decode
extern er_object_envelope_validate
extern er_object_view_decode

OBJECT_VIEW_SIZE equ 148
CANONICAL_BYTES_LEN equ OBJECT_HEADER_SIZE + 5
CANONICAL_OWNED_LEN equ OBJECT_HEADER_SIZE + OBJECT_OWNER_SIZE + OBJECT_ENVELOPE_SIZE + 7

SECTION .bss
TEST_BSS_PASSED_FAILED
req_raw: resb OBJECT_REQUIREMENTS_SIZE
req_decoded: resb OBJECT_REQUIREMENTS_SIZE
req_hash: resb OBJECT_ID_SIZE
header_struct: resb HEADER_STRUCT_SIZE
header_raw: resb OBJECT_HEADER_SIZE
header_decoded: resb HEADER_STRUCT_SIZE
owner_struct: resb OWNER_STRUCT_SIZE
owner_raw: resb OBJECT_OWNER_SIZE
owner_decoded: resb OWNER_STRUCT_SIZE
child_struct: resb CHILD_STRUCT_SIZE
child_raw: resb OBJECT_CHILD_SIZE
child_decoded: resb CHILD_STRUCT_SIZE
envelope_struct: resb ENVELOPE_STRUCT_SIZE
envelope_raw: resb OBJECT_ENVELOPE_SIZE
envelope_decoded: resb ENVELOPE_STRUCT_SIZE
view: resb OBJECT_VIEW_SIZE
canonical_bytes: resb CANONICAL_BYTES_LEN
canonical_owned: resb CANONICAL_OWNED_LEN

SECTION .data
keeper_stamp:
    db 1
    times 31 db 0
    dq 0, 0, 0, 0
node_id:
    db 2
    times 31 db 0
requirements_id:
    db 3
    times 31 db 0
key_id:
    db 5
    times 31 db 0
metadata_hash:
    db 6
    times 31 db 0
body_hello: db "hello"
body_payload: db "payload"
erobj_magic: db "EROBJ001"

SECTION .text
global _start
_start:
    mov     dword [rel req_raw + REQ_OF_DURABILITY], OBJECT_DURABILITY_DURABLE
    mov     dword [rel req_raw + REQ_OF_CONFIDENTIALITY], OBJECT_CONFIDENTIALITY_USER_APP_PRIVATE
    mov     dword [rel req_raw + REQ_OF_PORTABILITY], OBJECT_PORTABILITY_MACHINE_BOUND
    mov     dword [rel req_raw + REQ_OF_INTEGRITY], OBJECT_INTEGRITY_SEALED
    mov     dword [rel req_raw + REQ_OF_LIFETIME], OBJECT_LIFETIME_RETAINED
    mov     dword [rel req_raw + REQ_OF_VISIBILITY], OBJECT_VISIBILITY_PRIVATE
    mov     dword [rel req_raw + REQ_OF_ACCESS], OBJECT_ACCESS_EXPLICIT_IO

    lea     rdi, [rel header_raw]
    lea     rsi, [rel req_raw]
    call    er_object_requirements_encode
    ASSERT_RAX 1
    ASSERT_RDX 0
    lea     rdi, [rel header_raw]
    lea     rsi, [rel req_decoded]
    call    er_object_requirements_decode
    ASSERT_RAX 1
    ASSERT_RDX 0
    ASSERT_MEM_EQ [rel req_raw], [rel req_decoded], OBJECT_REQUIREMENTS_SIZE

    lea     rdi, [rel req_raw]
    lea     rsi, [rel req_hash]
    call    er_object_requirements_hash
    ASSERT_RDX 0
    call    assert_req_hash_nonzero

    call    fill_header_bytes
    lea     rdi, [rel header_raw]
    lea     rsi, [rel header_struct]
    call    er_object_header_encode
    ASSERT_RAX 1
    ASSERT_RDX 0
    ASSERT_MEM_EQ [rel erobj_magic], [rel header_raw], 8
    ASSERT_WORD [rel header_raw + HEADER_OF_VERSION], 1

    lea     rdi, [rel header_raw]
    lea     rsi, [rel header_decoded]
    call    er_object_header_decode
    ASSERT_RAX 1
    ASSERT_RDX 0
    ASSERT_WORD [rel header_decoded + HEADER_STRUCT_KIND], OBJECT_KIND_BYTES
    ASSERT_QWORD [rel header_decoded + HEADER_STRUCT_BODY_LEN], 5
    ASSERT_DWORD [rel header_decoded + HEADER_STRUCT_REQUIREMENTS + REQ_OF_INTEGRITY], OBJECT_INTEGRITY_HASH_ONLY

    mov     byte [rel header_raw + HEADER_OF_RESERVED], 1
    lea     rdi, [rel header_raw]
    lea     rsi, [rel header_decoded]
    call    er_object_header_decode
    ASSERT_RAX 0
    ASSERT_RDX OBJECT_ERR_CORRUPT
    mov     byte [rel header_raw + HEADER_OF_RESERVED], 0

    mov     dword [rel owner_struct + OWNER_STRUCT_KIND], OBJECT_OWNER_KIND_APP
    call    copy_node_to_owner
    lea     rdi, [rel owner_raw]
    lea     rsi, [rel owner_struct]
    call    er_object_owner_encode
    ASSERT_RAX 1
    ASSERT_RDX 0
    lea     rdi, [rel owner_raw]
    lea     rsi, [rel owner_decoded]
    call    er_object_owner_decode
    ASSERT_RAX 1
    ASSERT_RDX 0
    ASSERT_DWORD [rel owner_decoded + OWNER_STRUCT_KIND], OBJECT_OWNER_KIND_APP
    ASSERT_MEM_EQ [rel node_id], [rel owner_decoded + OWNER_STRUCT_NODE_ID], OBJECT_ID_SIZE

    call    fill_child
    lea     rdi, [rel child_raw]
    lea     rsi, [rel child_struct]
    call    er_object_child_encode
    ASSERT_RAX 1
    ASSERT_RDX 0
    lea     rdi, [rel child_raw]
    xor     esi, esi
    lea     rdx, [rel child_decoded]
    call    er_object_child_decode
    ASSERT_RAX 1
    ASSERT_RDX 0
    ASSERT_QWORD [rel child_decoded + CHILD_STRUCT_LOGICAL_LEN], 10
    lea     rdi, [rel child_raw]
    mov     esi, 1
    lea     rdx, [rel child_decoded]
    call    er_object_child_decode
    ASSERT_RAX 0
    ASSERT_RDX OBJECT_ERR_CORRUPT

    call    fill_envelope
    lea     rdi, [rel envelope_raw]
    lea     rsi, [rel envelope_struct]
    lea     rdx, [rel owner_struct]
    call    er_object_envelope_encode
    ASSERT_RAX 1
    ASSERT_RDX 0
    lea     rdi, [rel envelope_raw]
    lea     rsi, [rel envelope_decoded]
    call    er_object_envelope_decode
    ASSERT_RAX 1
    ASSERT_RDX 0
    lea     rdi, [rel envelope_decoded]
    lea     rsi, [rel owner_struct]
    call    er_object_envelope_validate
    ASSERT_RAX 1
    ASSERT_RDX 0
    mov     dword [rel owner_struct + OWNER_STRUCT_KIND], OBJECT_OWNER_KIND_USER
    lea     rdi, [rel envelope_raw]
    lea     rsi, [rel envelope_struct]
    lea     rdx, [rel owner_struct]
    call    er_object_envelope_encode
    ASSERT_RAX 0
    ASSERT_RDX OBJECT_ERR_BAD_ARGUMENT
    mov     dword [rel owner_struct + OWNER_STRUCT_KIND], OBJECT_OWNER_KIND_APP

    call    fill_header_bytes
    lea     rdi, [rel canonical_bytes]
    lea     rsi, [rel header_struct]
    call    er_object_header_encode
    ASSERT_RAX 1
    call    copy_hello_body
    lea     rdi, [rel canonical_bytes]
    mov     esi, CANONICAL_BYTES_LEN
    lea     rdx, [rel view]
    call    er_object_view_decode
    ASSERT_RAX 1
    ASSERT_RDX 0
    ASSERT_QWORD [rel view + 8], 5

    call    fill_header_owned
    lea     rdi, [rel canonical_owned]
    lea     rsi, [rel header_struct]
    call    er_object_header_encode
    ASSERT_RAX 1
    lea     rdi, [rel canonical_owned + OBJECT_HEADER_SIZE]
    lea     rsi, [rel owner_struct]
    call    er_object_owner_encode
    ASSERT_RAX 1
    call    fill_envelope
    lea     rdi, [rel canonical_owned + OBJECT_HEADER_SIZE + OBJECT_OWNER_SIZE]
    lea     rsi, [rel envelope_struct]
    lea     rdx, [rel owner_struct]
    call    er_object_envelope_encode
    ASSERT_RAX 1
    call    copy_payload_body
    lea     rdi, [rel canonical_owned]
    mov     esi, CANONICAL_OWNED_LEN
    lea     rdx, [rel view]
    call    er_object_view_decode
    ASSERT_RAX 1
    ASSERT_RDX 0
    ASSERT_QWORD [rel view + 8], 7

    TEST_EXIT_FAILED

assert_req_hash_nonzero:
    cmp     qword [rel req_hash], 0
    jne     .ok
    cmp     qword [rel req_hash + 8], 0
    jne     .ok
    cmp     qword [rel req_hash + 16], 0
    jne     .ok
    cmp     qword [rel req_hash + 24], 0
    jne     .ok
    inc     qword [rel failed]
    ret
.ok:
    inc     qword [rel passed]
    ret

fill_header_bytes:
    mov     word [rel header_struct + HEADER_STRUCT_KIND], OBJECT_KIND_BYTES
    mov     dword [rel header_struct + HEADER_STRUCT_FLAGS], 0
    mov     qword [rel header_struct + HEADER_STRUCT_LOGICAL_LEN], 5
    mov     word [rel header_struct + HEADER_STRUCT_OWNER_COUNT], 0
    mov     word [rel header_struct + HEADER_STRUCT_ENVELOPE_COUNT], 0
    mov     dword [rel header_struct + HEADER_STRUCT_CHILD_COUNT], 0
    mov     qword [rel header_struct + HEADER_STRUCT_BODY_LEN], 5
    call    copy_stamp_to_header
    mov     dword [rel header_struct + HEADER_STRUCT_REQUIREMENTS + REQ_OF_DURABILITY], OBJECT_DURABILITY_MEMORY
    mov     dword [rel header_struct + HEADER_STRUCT_REQUIREMENTS + REQ_OF_CONFIDENTIALITY], OBJECT_CONFIDENTIALITY_PUBLIC
    mov     dword [rel header_struct + HEADER_STRUCT_REQUIREMENTS + REQ_OF_PORTABILITY], OBJECT_PORTABILITY_PUBLIC_PORTABLE
    mov     dword [rel header_struct + HEADER_STRUCT_REQUIREMENTS + REQ_OF_INTEGRITY], OBJECT_INTEGRITY_HASH_ONLY
    mov     dword [rel header_struct + HEADER_STRUCT_REQUIREMENTS + REQ_OF_LIFETIME], OBJECT_LIFETIME_TRANSIENT
    mov     dword [rel header_struct + HEADER_STRUCT_REQUIREMENTS + REQ_OF_VISIBILITY], OBJECT_VISIBILITY_PUBLIC
    mov     dword [rel header_struct + HEADER_STRUCT_REQUIREMENTS + REQ_OF_ACCESS], OBJECT_ACCESS_HOT_MEMORY_ALLOWED
    ret

fill_header_owned:
    call    fill_header_bytes
    mov     qword [rel header_struct + HEADER_STRUCT_LOGICAL_LEN], 7
    mov     word [rel header_struct + HEADER_STRUCT_OWNER_COUNT], 1
    mov     word [rel header_struct + HEADER_STRUCT_ENVELOPE_COUNT], 1
    mov     qword [rel header_struct + HEADER_STRUCT_BODY_LEN], 7
    ret

copy_stamp_to_header:
    lea     rsi, [rel keeper_stamp]
    lea     rdi, [rel header_struct + HEADER_STRUCT_EPOCH]
    mov     ecx, 64
    jmp     copy_loop

copy_node_to_owner:
    lea     rsi, [rel node_id]
    lea     rdi, [rel owner_struct + OWNER_STRUCT_NODE_ID]
    mov     ecx, OBJECT_ID_SIZE
    jmp     copy_loop

fill_child:
    lea     rsi, [rel node_id]
    lea     rdi, [rel child_struct + CHILD_STRUCT_OBJECT_ID]
    mov     ecx, OBJECT_ID_SIZE
    call    copy_loop
    mov     qword [rel child_struct + CHILD_STRUCT_LOGICAL_OFFSET], 0
    mov     qword [rel child_struct + CHILD_STRUCT_LOGICAL_LEN], 10
    mov     word [rel child_struct + CHILD_STRUCT_KIND], OBJECT_KIND_BYTES
    mov     word [rel child_struct + CHILD_STRUCT_PAD], 0
    lea     rsi, [rel requirements_id]
    lea     rdi, [rel child_struct + CHILD_STRUCT_REQUIREMENTS_HASH]
    mov     ecx, OBJECT_ID_SIZE
    jmp     copy_loop

fill_envelope:
    mov     dword [rel envelope_struct + ENVELOPE_STRUCT_KIND], OBJECT_ENVELOPE_KIND_APP
    mov     word [rel envelope_struct + ENVELOPE_STRUCT_OWNER_INDEX], 0
    mov     word [rel envelope_struct + ENVELOPE_STRUCT_ALGORITHM], OBJECT_ALGORITHM_AES_GCM_256
    mov     dword [rel envelope_struct + ENVELOPE_STRUCT_FLAGS], 7
    lea     rsi, [rel key_id]
    lea     rdi, [rel envelope_struct + ENVELOPE_STRUCT_KEY_ID]
    mov     ecx, OBJECT_ID_SIZE
    call    copy_loop
    lea     rsi, [rel metadata_hash]
    lea     rdi, [rel envelope_struct + ENVELOPE_STRUCT_METADATA_HASH]
    mov     ecx, OBJECT_ID_SIZE
    jmp     copy_loop

copy_hello_body:
    lea     rsi, [rel body_hello]
    lea     rdi, [rel canonical_bytes + OBJECT_HEADER_SIZE]
    mov     ecx, 5
    jmp     copy_loop

copy_payload_body:
    lea     rsi, [rel body_payload]
    lea     rdi, [rel canonical_owned + OBJECT_HEADER_SIZE + OBJECT_OWNER_SIZE + OBJECT_ENVELOPE_SIZE]
    mov     ecx, 7
    jmp     copy_loop

copy_loop:
    xor     eax, eax
.loop:
    mov     dl, [rsi + rax]
    mov     [rdi + rax], dl
    inc     eax
    cmp     eax, ecx
    jb      .loop
    ret
