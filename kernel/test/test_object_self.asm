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
extern er_object_canonical_size
extern er_isa_validate_body
extern er_code_validate_body
extern er_code_materialize_flat
extern er_object_write_bytes_node
extern er_object_write_isa_node
extern er_object_write_code_node
extern er_object_write_receipt_node
extern er_object_write_bytes_node_owned
extern er_object_write_tree_node
extern er_object_write_tree_node_owned

CODE_BODY_LEN equ CODE_BODY_HEADER_SIZE + CODE_RECORD_SIZE * 4
ISA_BODY_LEN equ ISA_BODY_HEADER_SIZE + ISA_DEF_SIZE * 2
CANONICAL_BYTES_LEN equ OBJECT_HEADER_SIZE + 5
CANONICAL_ISA_LEN equ OBJECT_HEADER_SIZE + ISA_BODY_LEN
CANONICAL_CODE_BODY_LEN equ OBJECT_HEADER_SIZE + CODE_BODY_LEN
CANONICAL_CODE_LEN equ OBJECT_HEADER_SIZE + OBJECT_CHILD_SIZE + 16
CANONICAL_RECEIPT_LEN equ OBJECT_HEADER_SIZE + CODE_RECEIPT_SIZE
CANONICAL_OWNED_LEN equ OBJECT_HEADER_SIZE + OBJECT_OWNER_SIZE + OBJECT_ENVELOPE_SIZE + 7
CANONICAL_TREE_LEN equ OBJECT_HEADER_SIZE + OBJECT_CHILD_SIZE
CANONICAL_OWNED_TREE_LEN equ OBJECT_HEADER_SIZE + OBJECT_OWNER_SIZE + OBJECT_ENVELOPE_SIZE + OBJECT_CHILD_SIZE

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
canonical_isa: resb CANONICAL_ISA_LEN
canonical_code: resb CANONICAL_CODE_BODY_LEN
canonical_code_len: resq 1
code_out: resb 8
code_receipt: resb CODE_RECEIPT_SIZE
canonical_receipt: resb CANONICAL_RECEIPT_LEN
canonical_owned: resb CANONICAL_OWNED_LEN
canonical_tree: resb CANONICAL_TREE_LEN
canonical_owned_tree: resb CANONICAL_OWNED_TREE_LEN

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
expected_code_receipt_magic: dq CODE_RECEIPT_MAGIC_QWORD
expected_code_bytes: db 0xb8, 42, 0, 0, 0, 0xc3
x86_isa_body:
    dq ISA_BODY_MAGIC_QWORD
    dw ISA_BODY_VERSION
    dw ISA_ID_X86_64
    dd 2
    dd ISA_INSTR_X86_MOV_EAX_IMM32
    dw ISA_MNEMONIC_MOV
    dw ISA_OPERAND_SHAPE_REG_IMM32
    dw ISA_ENCODING_X86_MOV_EAX_IMM32
    dw 0
    db 0
    db 1
    db 0
    db 0
    dd ISA_INSTR_X86_RET
    dw ISA_MNEMONIC_RET
    dw ISA_OPERAND_SHAPE_NONE
    dw ISA_ENCODING_X86_RET_NEAR
    dw 0
    db 0
    db 0
    db 0
    db 0
x86_isa_body_end:
x86_isa_bad_body:
    dq ISA_BODY_MAGIC_QWORD
    dw ISA_BODY_VERSION
    dw ISA_ID_X86_64
    dd 1
    dd 0
    dw ISA_MNEMONIC_RET
    dw ISA_OPERAND_SHAPE_NONE
    dw ISA_ENCODING_X86_RET_NEAR
    dw 0
    db 0
    db 0
    db 0
    db 0
x86_isa_bad_body_end:
code_body:
    dq CODE_BODY_MAGIC_QWORD
    dw CODE_BODY_VERSION
    dw CODE_ISA_X86_64
    dd 4
    dw CODE_RECORD_KIND_EXPORT
    dw 0
    dd 0
    dq 1
    dw CODE_RECORD_KIND_IMPORT
    dw 0
    dd 0
    dq 0
    dw CODE_RECORD_KIND_INSTR
    dw CODE_OP_X86_MOV_EAX_IMM32
    dd 0
    dq 42
    dw CODE_RECORD_KIND_INSTR
    dw CODE_OP_X86_RET
    dd 0
    dq 0
code_body_end:
code_bad_opcode_body:
    dq CODE_BODY_MAGIC_QWORD
    dw CODE_BODY_VERSION
    dw CODE_ISA_X86_64
    dd 1
    dw CODE_RECORD_KIND_INSTR
    dw 0xffff
    dd 0
    dq 0
code_bad_opcode_body_end:

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

    lea     rdi, [rel x86_isa_body]
    mov     esi, x86_isa_body_end - x86_isa_body
    call    er_isa_validate_body
    ASSERT_RAX 2
    ASSERT_RDX 0

    lea     rdi, [rel x86_isa_bad_body]
    mov     esi, x86_isa_bad_body_end - x86_isa_bad_body
    call    er_isa_validate_body
    ASSERT_RAX 0
    ASSERT_RDX OBJECT_ERR_BAD_ARGUMENT

    mov     edi, OBJECT_KIND_ISA
    mov     esi, ISA_BODY_LEN
    xor     edx, edx
    xor     ecx, ecx
    xor     r8d, r8d
    lea     r9, [rel canonical_code_len]
    call    er_object_canonical_size
    ASSERT_RAX 1
    ASSERT_RDX 0
    ASSERT_QWORD [rel canonical_code_len], CANONICAL_ISA_LEN

    lea     rdi, [rel canonical_isa]
    mov     esi, CANONICAL_ISA_LEN
    lea     rdx, [rel header_struct + HEADER_STRUCT_REQUIREMENTS]
    lea     rcx, [rel keeper_stamp]
    lea     r8, [rel x86_isa_body]
    mov     r9d, ISA_BODY_LEN
    call    er_object_write_isa_node
    ASSERT_RAX CANONICAL_ISA_LEN
    ASSERT_RDX 0
    lea     rdi, [rel canonical_isa]
    mov     esi, CANONICAL_ISA_LEN
    lea     rdx, [rel view]
    call    er_object_view_decode
    ASSERT_RAX 1
    ASSERT_RDX 0
    ASSERT_WORD [rel view + OBJECT_VIEW_HEADER + HEADER_STRUCT_KIND], OBJECT_KIND_ISA
    ASSERT_QWORD [rel view + OBJECT_VIEW_BODY_LEN], ISA_BODY_LEN
    mov     rdi, [rel view + OBJECT_VIEW_BODY_PTR]
    mov     rsi, [rel view + OBJECT_VIEW_BODY_LEN]
    call    er_isa_validate_body
    ASSERT_RAX 2
    ASSERT_RDX 0

    call    fill_header_code
    lea     rdi, [rel header_raw]
    lea     rsi, [rel header_struct]
    call    er_object_header_encode
    ASSERT_RAX 1
    ASSERT_RDX 0
    lea     rdi, [rel header_raw]
    lea     rsi, [rel header_decoded]
    call    er_object_header_decode
    ASSERT_RAX 1
    ASSERT_RDX 0
    ASSERT_WORD [rel header_decoded + HEADER_STRUCT_KIND], OBJECT_KIND_CODE
    ASSERT_QWORD [rel header_decoded + HEADER_STRUCT_BODY_LEN], 16
    ASSERT_DWORD [rel header_decoded + HEADER_STRUCT_CHILD_COUNT], 1

    mov     edi, OBJECT_KIND_CODE
    mov     esi, 16
    xor     edx, edx
    xor     ecx, ecx
    mov     r8d, 1
    lea     r9, [rel canonical_code_len]
    call    er_object_canonical_size
    ASSERT_RAX 1
    ASSERT_RDX 0
    ASSERT_QWORD [rel canonical_code_len], CANONICAL_CODE_LEN

    lea     rdi, [rel code_body]
    mov     esi, code_body_end - code_body
    lea     rdx, [rel code_out]
    mov     ecx, 8
    lea     r8, [rel code_receipt]
    call    er_code_materialize_flat
    ASSERT_RAX 6
    ASSERT_RDX 0
    ASSERT_MEM_EQ [rel expected_code_bytes], [rel code_out], 6
    ASSERT_MEM_EQ [rel expected_code_receipt_magic], [rel code_receipt + CODE_RECEIPT_OF_MAGIC], 8
    ASSERT_QWORD [rel code_receipt + CODE_RECEIPT_OF_RECORD_COUNT], 4
    ASSERT_QWORD [rel code_receipt + CODE_RECEIPT_OF_OUTPUT_LEN], 6
    ASSERT_QWORD [rel code_receipt + CODE_RECEIPT_OF_ISA], CODE_ISA_X86_64

    lea     rdi, [rel code_bad_opcode_body]
    mov     esi, code_bad_opcode_body_end - code_bad_opcode_body
    call    er_code_validate_body
    ASSERT_RAX 0
    ASSERT_RDX OBJECT_ERR_UNSUPPORTED

    lea     rdi, [rel code_bad_opcode_body]
    mov     esi, code_bad_opcode_body_end - code_bad_opcode_body
    lea     rdx, [rel code_out]
    mov     ecx, 8
    lea     r8, [rel code_receipt]
    call    er_code_materialize_flat
    ASSERT_RAX 0
    ASSERT_RDX OBJECT_ERR_UNSUPPORTED

    lea     rdi, [rel canonical_code]
    mov     esi, CANONICAL_CODE_BODY_LEN
    lea     rdx, [rel header_struct + HEADER_STRUCT_REQUIREMENTS]
    lea     rcx, [rel keeper_stamp]
    lea     r8, [rel code_bad_opcode_body]
    mov     r9d, code_bad_opcode_body_end - code_bad_opcode_body
    call    er_object_write_code_node
    ASSERT_RAX 0
    ASSERT_RDX OBJECT_ERR_UNSUPPORTED

    lea     rdi, [rel canonical_receipt]
    mov     esi, CANONICAL_RECEIPT_LEN
    lea     rdx, [rel header_struct + HEADER_STRUCT_REQUIREMENTS]
    lea     rcx, [rel keeper_stamp]
    lea     r8, [rel code_receipt]
    mov     r9d, CODE_RECEIPT_SIZE
    call    er_object_write_receipt_node
    ASSERT_RAX CANONICAL_RECEIPT_LEN
    ASSERT_RDX 0
    lea     rdi, [rel canonical_receipt]
    mov     esi, CANONICAL_RECEIPT_LEN
    lea     rdx, [rel view]
    call    er_object_view_decode
    ASSERT_RAX 1
    ASSERT_RDX 0
    ASSERT_WORD [rel view + OBJECT_VIEW_HEADER + HEADER_STRUCT_KIND], OBJECT_KIND_RECEIPT
    ASSERT_QWORD [rel view + OBJECT_VIEW_BODY_LEN], CODE_RECEIPT_SIZE
    mov     rsi, [rel view + OBJECT_VIEW_BODY_PTR]
    ASSERT_MEM_EQ [rel expected_code_receipt_magic], [rsi + CODE_RECEIPT_OF_MAGIC], 8

    lea     rdi, [rel canonical_code]
    mov     esi, CANONICAL_CODE_BODY_LEN
    lea     rdx, [rel header_struct + HEADER_STRUCT_REQUIREMENTS]
    lea     rcx, [rel keeper_stamp]
    lea     r8, [rel code_body]
    mov     r9d, CODE_BODY_LEN
    call    er_object_write_code_node
    ASSERT_RAX CANONICAL_CODE_BODY_LEN
    ASSERT_RDX 0
    lea     rdi, [rel canonical_code]
    mov     esi, CANONICAL_CODE_BODY_LEN
    lea     rdx, [rel view]
    call    er_object_view_decode
    ASSERT_RAX 1
    ASSERT_RDX 0
    ASSERT_WORD [rel view + OBJECT_VIEW_HEADER + HEADER_STRUCT_KIND], OBJECT_KIND_CODE
    ASSERT_QWORD [rel view + OBJECT_VIEW_BODY_LEN], CODE_BODY_LEN
    mov     rdi, [rel view + OBJECT_VIEW_BODY_PTR]
    mov     rsi, [rel view + OBJECT_VIEW_BODY_LEN]
    lea     rdx, [rel code_out]
    mov     ecx, 8
    lea     r8, [rel code_receipt]
    call    er_code_materialize_flat
    ASSERT_RAX 6
    ASSERT_RDX 0
    ASSERT_MEM_EQ [rel expected_code_bytes], [rel code_out], 6

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

    call    fill_child
    mov     word [rel child_struct + CHILD_STRUCT_KIND], OBJECT_KIND_CODE
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
    ASSERT_WORD [rel child_decoded + CHILD_STRUCT_KIND], OBJECT_KIND_CODE

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

    mov     word [rel envelope_struct + ENVELOPE_STRUCT_ALGORITHM], OBJECT_ALGORITHM_XCHACHA20_POLY1305
    lea     rdi, [rel envelope_raw]
    lea     rsi, [rel envelope_struct]
    lea     rdx, [rel owner_struct]
    call    er_object_envelope_encode
    ASSERT_RAX 1
    ASSERT_RDX 0
    mov     word [rel envelope_struct + ENVELOPE_STRUCT_ALGORITHM], OBJECT_ALGORITHM_AES_GCM_256

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
    mov     esi, CANONICAL_BYTES_LEN
    lea     rdx, [rel header_struct + HEADER_STRUCT_REQUIREMENTS]
    lea     rcx, [rel keeper_stamp]
    lea     r8, [rel body_hello]
    mov     r9d, 5
    call    er_object_write_bytes_node
    ASSERT_RAX CANONICAL_BYTES_LEN
    ASSERT_RDX 0
    lea     rdi, [rel canonical_bytes]
    mov     esi, CANONICAL_BYTES_LEN
    lea     rdx, [rel view]
    call    er_object_view_decode
    ASSERT_RAX 1
    ASSERT_RDX 0
    ASSERT_QWORD [rel view + 8], 5

    lea     rdi, [rel canonical_bytes]
    mov     esi, CANONICAL_BYTES_LEN - 1
    lea     rdx, [rel header_struct + HEADER_STRUCT_REQUIREMENTS]
    lea     rcx, [rel keeper_stamp]
    lea     r8, [rel body_hello]
    mov     r9d, 5
    call    er_object_write_bytes_node
    ASSERT_RAX 0
    ASSERT_RDX OBJECT_ERR_NO_SPACE

    call    fill_header_owned
    call    fill_envelope
    lea     rax, [rel envelope_struct]
    mov     ecx, 1
    push    rcx
    push    rax
    mov     eax, 7
    push    rax
    lea     rax, [rel body_payload]
    push    rax
    lea     rdi, [rel canonical_owned]
    mov     esi, CANONICAL_OWNED_LEN
    lea     rdx, [rel header_struct + HEADER_STRUCT_REQUIREMENTS]
    lea     rcx, [rel keeper_stamp]
    lea     r8, [rel owner_struct]
    mov     r9d, 1
    call    er_object_write_bytes_node_owned
    add     rsp, 32
    ASSERT_RAX CANONICAL_OWNED_LEN
    ASSERT_RDX 0
    lea     rdi, [rel canonical_owned]
    mov     esi, CANONICAL_OWNED_LEN
    lea     rdx, [rel view]
    call    er_object_view_decode
    ASSERT_RAX 1
    ASSERT_RDX 0
    ASSERT_QWORD [rel view + 8], 7

    call    fill_envelope
    mov     dword [rel envelope_struct + ENVELOPE_STRUCT_KIND], OBJECT_ENVELOPE_KIND_USER
    mov     dword [rel owner_struct + OWNER_STRUCT_KIND], OBJECT_OWNER_KIND_APP
    ASSERT_DWORD [rel envelope_struct + ENVELOPE_STRUCT_KIND], OBJECT_ENVELOPE_KIND_USER
    ASSERT_DWORD [rel owner_struct + OWNER_STRUCT_KIND], OBJECT_OWNER_KIND_APP
    lea     rdi, [rel envelope_raw]
    lea     rsi, [rel envelope_struct]
    lea     rdx, [rel owner_struct]
    call    er_object_envelope_encode
    ASSERT_RAX 0
    ASSERT_RDX OBJECT_ERR_BAD_ARGUMENT
    lea     rax, [rel envelope_struct]
    mov     ecx, 1
    push    rcx
    push    rax
    mov     eax, 7
    push    rax
    lea     rax, [rel body_payload]
    push    rax
    lea     rdi, [rel canonical_owned]
    mov     esi, CANONICAL_OWNED_LEN
    lea     rdx, [rel header_struct + HEADER_STRUCT_REQUIREMENTS]
    lea     rcx, [rel keeper_stamp]
    lea     r8, [rel owner_struct]
    mov     r9d, 1
    call    er_object_write_bytes_node_owned
    add     rsp, 32
    ASSERT_RAX 0
    ASSERT_RDX OBJECT_ERR_BAD_ARGUMENT

    call    fill_child
    lea     rdi, [rel canonical_tree]
    mov     esi, CANONICAL_TREE_LEN
    lea     rdx, [rel header_struct + HEADER_STRUCT_REQUIREMENTS]
    lea     rcx, [rel keeper_stamp]
    lea     r8, [rel child_struct]
    mov     r9d, 1
    call    er_object_write_tree_node
    ASSERT_RAX CANONICAL_TREE_LEN
    ASSERT_RDX 0
    lea     rdi, [rel canonical_tree]
    lea     rsi, [rel header_decoded]
    call    er_object_header_decode
    ASSERT_RAX 1
    ASSERT_RDX 0
    ASSERT_WORD [rel header_decoded + HEADER_STRUCT_KIND], OBJECT_KIND_TREE
    ASSERT_QWORD [rel header_decoded + HEADER_STRUCT_LOGICAL_LEN], 10
    ASSERT_DWORD [rel header_decoded + HEADER_STRUCT_CHILD_COUNT], 1
    lea     rdi, [rel canonical_tree + OBJECT_HEADER_SIZE]
    xor     esi, esi
    lea     rdx, [rel child_decoded]
    call    er_object_child_decode
    ASSERT_RAX 1
    ASSERT_RDX 0
    ASSERT_QWORD [rel child_decoded + CHILD_STRUCT_LOGICAL_LEN], 10
    lea     rdi, [rel canonical_tree]
    mov     esi, CANONICAL_TREE_LEN
    lea     rdx, [rel view]
    call    er_object_view_decode
    ASSERT_RAX 1
    ASSERT_RDX 0
    ASSERT_WORD [rel view + 16 + HEADER_STRUCT_KIND], OBJECT_KIND_TREE
    ASSERT_QWORD [rel view + 16 + HEADER_STRUCT_LOGICAL_LEN], 10
    ASSERT_QWORD [rel view + 8], 0

    mov     qword [rel child_struct + CHILD_STRUCT_LOGICAL_OFFSET], 1
    lea     rdi, [rel canonical_tree]
    mov     esi, CANONICAL_TREE_LEN
    lea     rdx, [rel header_struct + HEADER_STRUCT_REQUIREMENTS]
    lea     rcx, [rel keeper_stamp]
    lea     r8, [rel child_struct]
    mov     r9d, 1
    call    er_object_write_tree_node
    ASSERT_RAX 0
    ASSERT_RDX OBJECT_ERR_BAD_ARGUMENT
    mov     qword [rel child_struct + CHILD_STRUCT_LOGICAL_OFFSET], 0

    call    fill_envelope
    lea     rax, [rel envelope_struct]
    mov     ecx, 1
    push    rcx
    push    rax
    mov     eax, 1
    push    rax
    lea     rax, [rel child_struct]
    push    rax
    lea     rdi, [rel canonical_owned_tree]
    mov     esi, CANONICAL_OWNED_TREE_LEN
    lea     rdx, [rel header_struct + HEADER_STRUCT_REQUIREMENTS]
    lea     rcx, [rel keeper_stamp]
    lea     r8, [rel owner_struct]
    mov     r9d, 1
    call    er_object_write_tree_node_owned
    add     rsp, 32
    ASSERT_RAX CANONICAL_OWNED_TREE_LEN
    ASSERT_RDX 0
    lea     rdi, [rel canonical_owned_tree]
    mov     esi, CANONICAL_OWNED_TREE_LEN
    lea     rdx, [rel view]
    call    er_object_view_decode
    ASSERT_RAX 1
    ASSERT_RDX 0
    ASSERT_WORD [rel view + 16 + HEADER_STRUCT_KIND], OBJECT_KIND_TREE
    ASSERT_QWORD [rel view + 16 + HEADER_STRUCT_LOGICAL_LEN], 10

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

fill_header_code:
    call    fill_header_bytes
    mov     word [rel header_struct + HEADER_STRUCT_KIND], OBJECT_KIND_CODE
    mov     qword [rel header_struct + HEADER_STRUCT_LOGICAL_LEN], 16
    mov     dword [rel header_struct + HEADER_STRUCT_CHILD_COUNT], 1
    mov     qword [rel header_struct + HEADER_STRUCT_BODY_LEN], 16
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
