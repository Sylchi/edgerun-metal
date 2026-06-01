; EdgeRun byte utility self-test — x86_64 assembly.

%include "x86_64/macros.inc"
%include "test/test_macros.inc"

extern er_bytes_zero
extern er_bytes_copy
extern er_bytes_nonzero
extern er_bytes_eql
extern er_bytes_order
extern er_storebe16
extern er_storebe32
extern er_storebe64
extern er_store64
extern er_loadbe16
extern er_loadbe32
extern er_loadbe64
extern er_load64

SECTION .bss
TEST_BSS_PASSED_FAILED
raw: resb 8
dst: resb 4

SECTION .data
src4: db 1, 2, 3, 4
prefix2: db 1, 2, 9, 9
order_gt: db 1, 3, 0
be64_expected: db 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88
le64_expected: db 0x88, 0x77, 0x66, 0x55, 0x44, 0x33, 0x22, 0x11
expected_u16: db 0xaa, 0xbb

SECTION .text
global _start
_start:
    lea     rdi, [rel raw]
    mov     rsi, 0x1122334455667788
    call    er_store64
    ASSERT_RAX 1
    ASSERT_MEM_EQ [rel raw], [rel le64_expected], 8

    lea     rdi, [rel raw]
    mov     esi, 8
    call    er_load64
    mov     rbx, 0x1122334455667788
    cmp     rax, rbx
    jne     .le64_fail
    inc     qword [rel passed]
    jmp     .le64_done
.le64_fail:
    inc     qword [rel failed]
.le64_done:

    lea     rdi, [rel dst]
    mov     esi, 4
    lea     rdx, [rel src4]
    mov     ecx, 4
    call    er_bytes_copy
    ASSERT_RAX 1
    ASSERT_MEM_EQ [rel dst], [rel src4], 4

    lea     rdi, [rel dst]
    mov     esi, 4
    lea     rdx, [rel src4]
    mov     ecx, 4
    call    er_bytes_eql
    ASSERT_RAX 1

    lea     rdi, [rel dst]
    mov     esi, 4
    call    er_bytes_nonzero
    ASSERT_RAX 1

    lea     rdi, [rel dst]
    mov     esi, 4
    call    er_bytes_zero
    lea     rdi, [rel dst]
    mov     esi, 4
    call    er_bytes_nonzero
    ASSERT_RAX 0

    lea     rdi, [rel src4]
    mov     esi, 2
    lea     rdx, [rel prefix2]
    mov     ecx, 2
    call    er_bytes_eql
    ASSERT_RAX 1

    lea     rdi, [rel src4]
    mov     esi, 3
    lea     rdx, [rel order_gt]
    mov     ecx, 3
    call    er_bytes_order
    ASSERT_RAX -1

    lea     rdi, [rel order_gt]
    mov     esi, 3
    lea     rdx, [rel src4]
    mov     ecx, 3
    call    er_bytes_order
    ASSERT_RAX 1

    lea     rdi, [rel raw]
    mov     esi, 0x11223344
    call    er_storebe32
    ASSERT_RAX 1
    lea     rdi, [rel raw]
    mov     esi, 4
    call    er_loadbe32
    ASSERT_RAX 0x11223344

    lea     rdi, [rel raw]
    mov     esi, 0xaabb
    call    er_storebe16
    ASSERT_RAX 1
    ASSERT_MEM_EQ [rel raw], [rel expected_u16], 2
    lea     rdi, [rel raw]
    mov     esi, 2
    call    er_loadbe16
    ASSERT_RAX 0xaabb

    lea     rdi, [rel raw]
    mov     rsi, 0x1122334455667788
    call    er_storebe64
    ASSERT_RAX 1
    ASSERT_MEM_EQ [rel raw], [rel be64_expected], 8
    lea     rdi, [rel raw]
    mov     esi, 8
    call    er_loadbe64
    mov     rbx, 0x1122334455667788
    cmp     rax, rbx
    jne     .be64_fail
    inc     qword [rel passed]
    jmp     .be64_done
.be64_fail:
    inc     qword [rel failed]
.be64_done:
    TEST_EXIT_FAILED
