; EdgeRun host-side TSX parser primitives.
; Validates a bounded TSX element tree without recursion.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"

default rel

WASMC_TSX_MAX_DEPTH equ 16
WASMC_TSX_STACK_INDEX_OFF equ 256
WASMC_TSX_STACK_PTR_OFF equ 384
WASMC_TSX_STACK_LEN_OFF equ 512
WASMC_TSX_NODE_STRIDE equ 40
WASMC_TSX_NODE_NAME_PTR equ 0
WASMC_TSX_NODE_NAME_LEN equ 8
WASMC_TSX_NODE_PARENT equ 16
WASMC_TSX_NODE_ATTR_COUNT equ 24
WASMC_TSX_NODE_TEXT_COUNT equ 32

%ifndef ER_TSX_PARSER_NO_EXTERN_WASMC
extern _er_wasmc_skip_ws
extern _er_wasmc_parse_ident
%endif

SECTION .text

; er_wasmc_parse_tsx(source=rdi, source_len=rsi)
; Validates one TSX element tree.
; Returns rax=element_count, rcx=attribute_count, r8=text_node_count, rdx=0.
er_fn er_wasmc_parse_tsx
    xor     edx, edx
    xor     ecx, ecx
    jmp     er_wasmc_parse_tsx_tree

; er_wasmc_parse_tsx_tree(source=rdi, source_len=rsi, nodes=rdx, node_cap=rcx)
; Validates one TSX element tree and optionally writes preorder element records.
; Node record: qword name_ptr, name_len, parent_index, attr_count, text_count.
; Parent index is -1 for the root. If nodes is zero, node_cap is ignored.
; Returns rax=element_count, rcx=attribute_count, r8=text_node_count, rdx=0.
er_fn er_wasmc_parse_tsx_tree
    er_frame_push
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 640

    test    rdi, rdi
    jz      .bad_argument
    test    rsi, rsi
    jz      .bad_argument
    mov     r12, rdi
    lea     r13, [rdi + rsi]
    mov     [rbp - 112], rdx
    mov     [rbp - 120], rcx
    mov     rbx, r12
    xor     r14d, r14d
    xor     r15d, r15d
    mov     qword [rbp - 48], 0
    mov     qword [rbp - 80], 0
    mov     qword [rbp - 88], 0

    mov     rdi, rbx
    mov     rsi, r13
    call    _er_wasmc_skip_ws
    mov     rbx, rax
    cmp     rbx, r13
    jae     .parse_error
    cmp     byte [rbx], '<'
    jne     .parse_error

.loop:
    cmp     rbx, r13
    jae     .parse_error
    cmp     byte [rbx], '<'
    je      .tag
    test    r14, r14
    jz      .top_text
    mov     qword [rbp - 96], 0
.text_loop:
    cmp     rbx, r13
    jae     .parse_error
    cmp     byte [rbx], '<'
    je      .finish_text_node
    movzx   eax, byte [rbx]
    cmp     al, ' '
    je      .text_advance
    cmp     al, 9
    je      .text_advance
    cmp     al, 10
    je      .text_advance
    cmp     al, 13
    je      .text_advance
    mov     qword [rbp - 96], 1
.text_advance:
    inc     rbx
    jmp     .text_loop
.finish_text_node:
    cmp     qword [rbp - 96], 0
    je      .loop
    inc     qword [rbp - 88]
    mov     r10, [rbp - 112]
    test    r10, r10
    jz      .loop
    mov     r11, r14
    dec     r11
    lea     r9, [rbp - WASMC_TSX_STACK_INDEX_OFF]
    mov     r11, [r9 + r11 * 8]
    imul    r11, r11, WASMC_TSX_NODE_STRIDE
    inc     qword [r10 + r11 + WASMC_TSX_NODE_TEXT_COUNT]
    jmp     .loop

.top_text:
    mov     rdi, rbx
    mov     rsi, r13
    call    _er_wasmc_skip_ws
    cmp     rax, r13
    jne     .parse_error
    test    r14, r14
    jnz     .parse_error
    test    r15, r15
    jz      .parse_error
    mov     rax, r15
    mov     rcx, [rbp - 80]
    mov     r8, [rbp - 88]
    xor     edx, edx
    jmp     .done

.tag:
    lea     r10, [rbx + 1]
    cmp     r10, r13
    jae     .parse_error
    cmp     byte [r10], '/'
    je      .close_tag
    cmp     qword [rbp - 48], 0
    jne     .parse_error
    inc     rbx
    mov     rdi, rbx
    mov     rsi, r13
    call    _er_wasmc_parse_ident
    test    rdx, rdx
    jnz     .parse_error
    mov     [rbp - 56], rax
    mov     [rbp - 64], rcx
    mov     rbx, r8
    mov     [rbp - 104], r15
    mov     r10, [rbp - 112]
    test    r10, r10
    jz      .record_done
    cmp     r15, [rbp - 120]
    jae     .no_space
    mov     r11, r15
    imul    r11, r11, WASMC_TSX_NODE_STRIDE
    mov     rax, [rbp - 56]
    mov     [r10 + r11 + WASMC_TSX_NODE_NAME_PTR], rax
    mov     rax, [rbp - 64]
    mov     [r10 + r11 + WASMC_TSX_NODE_NAME_LEN], rax
    mov     qword [r10 + r11 + WASMC_TSX_NODE_ATTR_COUNT], 0
    mov     qword [r10 + r11 + WASMC_TSX_NODE_TEXT_COUNT], 0
    test    r14, r14
    jz      .record_root
    mov     rax, r14
    dec     rax
    lea     r9, [rbp - WASMC_TSX_STACK_INDEX_OFF]
    mov     rax, [r9 + rax * 8]
    jmp     .record_parent
.record_root:
    mov     rax, -1
.record_parent:
    mov     [r10 + r11 + WASMC_TSX_NODE_PARENT], rax
.record_done:
    inc     r15

.attr_loop:
    mov     rdi, rbx
    mov     rsi, r13
    call    _er_wasmc_skip_ws
    mov     rbx, rax
    cmp     rbx, r13
    jae     .parse_error
    cmp     byte [rbx], '>'
    je      .open_done
    cmp     byte [rbx], '/'
    je      .self_close
    mov     rdi, rbx
    mov     rsi, r13
    call    _er_wasmc_parse_ident
    test    rdx, rdx
    jnz     .parse_error
    mov     rbx, r8
    inc     qword [rbp - 80]
    mov     r10, [rbp - 112]
    test    r10, r10
    jz      .attr_record_done
    mov     r11, [rbp - 104]
    imul    r11, r11, WASMC_TSX_NODE_STRIDE
    inc     qword [r10 + r11 + WASMC_TSX_NODE_ATTR_COUNT]
.attr_record_done:
    mov     rdi, rbx
    mov     rsi, r13
    call    _er_wasmc_skip_ws
    mov     rbx, rax
    cmp     rbx, r13
    jae     .parse_error
    cmp     byte [rbx], '='
    jne     .attr_loop
    inc     rbx
    mov     rdi, rbx
    mov     rsi, r13
    call    _er_wasmc_skip_ws
    mov     rbx, rax
    cmp     rbx, r13
    jae     .parse_error
    movzx   eax, byte [rbx]
    cmp     al, '"'
    je      .quoted_attr
    cmp     al, 39
    je      .quoted_attr
    cmp     al, '{'
    jne     .parse_error
    jmp     .brace_attr

.quoted_attr:
    mov     [rbp - 72], al
    inc     rbx
.quoted_loop:
    cmp     rbx, r13
    jae     .parse_error
    movzx   eax, byte [rbx]
    cmp     al, [rbp - 72]
    je      .quoted_done
    cmp     al, '<'
    je      .parse_error
    inc     rbx
    jmp     .quoted_loop
.quoted_done:
    inc     rbx
    jmp     .attr_loop

.brace_attr:
    mov     ecx, 1
    inc     rbx
.brace_loop:
    cmp     rbx, r13
    jae     .parse_error
    movzx   eax, byte [rbx]
    cmp     al, '{'
    je      .brace_inc
    cmp     al, '}'
    je      .brace_dec
    cmp     al, '<'
    je      .parse_error
    inc     rbx
    jmp     .brace_loop
.brace_inc:
    inc     ecx
    inc     rbx
    jmp     .brace_loop
.brace_dec:
    dec     ecx
    inc     rbx
    test    ecx, ecx
    jnz     .brace_loop
    jmp     .attr_loop

.self_close:
    lea     r10, [rbx + 1]
    cmp     r10, r13
    jae     .parse_error
    cmp     byte [r10], '>'
    jne     .parse_error
    lea     rbx, [rbx + 2]
    test    r14, r14
    jnz     .loop
    mov     qword [rbp - 48], 1
    jmp     .after_root_close

.open_done:
    cmp     r14, WASMC_TSX_MAX_DEPTH
    jae     .no_space
    lea     r11, [rbp - WASMC_TSX_STACK_PTR_OFF]
    mov     rax, [rbp - 56]
    mov     [r11 + r14 * 8], rax
    lea     r11, [rbp - WASMC_TSX_STACK_LEN_OFF]
    mov     rax, [rbp - 64]
    mov     [r11 + r14 * 8], rax
    lea     r11, [rbp - WASMC_TSX_STACK_INDEX_OFF]
    mov     rax, [rbp - 104]
    mov     [r11 + r14 * 8], rax
    inc     r14
    inc     rbx
    jmp     .loop

.close_tag:
    test    r14, r14
    jz      .parse_error
    lea     rbx, [rbx + 2]
    mov     rdi, rbx
    mov     rsi, r13
    call    _er_wasmc_parse_ident
    test    rdx, rdx
    jnz     .parse_error
    dec     r14
    lea     r11, [rbp - WASMC_TSX_STACK_LEN_OFF]
    cmp     rcx, [r11 + r14 * 8]
    jne     .parse_error
    lea     r11, [rbp - WASMC_TSX_STACK_PTR_OFF]
    mov     rdi, [r11 + r14 * 8]
    mov     rsi, rax
    mov     rbx, r8
    mov     r10, rcx
.name_compare:
    test    r10, r10
    jz      .name_match
    mov     al, [rdi]
    cmp     al, [rsi]
    jne     .parse_error
    inc     rdi
    inc     rsi
    dec     r10
    jmp     .name_compare
.name_match:
    mov     rdi, rbx
    mov     rsi, r13
    call    _er_wasmc_skip_ws
    mov     rbx, rax
    cmp     rbx, r13
    jae     .parse_error
    cmp     byte [rbx], '>'
    jne     .parse_error
    inc     rbx
    test    r14, r14
    jnz     .loop
    mov     qword [rbp - 48], 1

.after_root_close:
    mov     rdi, rbx
    mov     rsi, r13
    call    _er_wasmc_skip_ws
    mov     rbx, rax
    cmp     rbx, r13
    jne     .parse_error
    mov     rax, r15
    mov     rcx, [rbp - 80]
    mov     r8, [rbp - 88]
    xor     edx, edx
    jmp     .done

.bad_argument:
    xor     eax, eax
    xor     ecx, ecx
    xor     r8d, r8d
    mov     edx, ERROR_BAD_ARGUMENT
    jmp     .done
.no_space:
    xor     eax, eax
    xor     ecx, ecx
    xor     r8d, r8d
    mov     edx, ERROR_NO_SPACE
    jmp     .done
.parse_error:
    xor     eax, eax
    xor     ecx, ecx
    xor     r8d, r8d
    mov     edx, ERROR_PARSE
.done:
    add     rsp, 640
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret
