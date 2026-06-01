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
WASMC_TSX_MAX_NAME_LEN equ 127

%ifndef ER_TSX_PARSER_NO_EXTERN_WASMC
extern _er_wasmc_skip_ws
%endif

SECTION .text

; er_wasmc_parse_tsx(source=rdi, source_len=rsi)
; Validates one TSX element tree.
; Returns rax=element_count, rcx=attribute_count, r8=text_node_count, rdx=0.
er_fn er_wasmc_parse_tsx
    xor     edx, edx
    xor     ecx, ecx
    jmp     er_wasmc_parse_tsx_tree

; er_wasmc_scan_tsx_source(source=rdi, source_len=rsi)
; Scans a TS/TSX source buffer and validates probable TSX roots.
; Returns rax=root_count, rcx=element_count, r8=attribute_count,
; r9=text_node_count, rdx=0.
er_fn er_wasmc_scan_tsx_source
    er_frame_push
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 64

    test    rdi, rdi
    jz      .bad_argument
    test    rsi, rsi
    jz      .bad_argument
    mov     rbx, rdi
    mov     [rbp - 56], rdi
    lea     r12, [rdi + rsi]
    xor     r13d, r13d
    xor     r14d, r14d
    xor     r15d, r15d
    mov     qword [rbp - 48], 0

.scan_loop:
    cmp     rbx, r12
    jae     .success
    movzx   eax, byte [rbx]
    cmp     al, '"'
    je      .skip_string
    cmp     al, 39
    je      .skip_string
    cmp     al, '`'
    je      .skip_template
    cmp     al, '/'
    je      .slash
    cmp     al, '<'
    je      .maybe_tsx
    inc     rbx
    jmp     .scan_loop

.slash:
    lea     r10, [rbx + 1]
    cmp     r10, r12
    jae     .advance_one
    cmp     byte [r10], '/'
    je      .skip_line_comment
    cmp     byte [r10], '*'
    je      .skip_block_comment
    mov     rdi, rbx
    mov     rsi, [rbp - 56]
    call    _er_tsx_source_context_allows_regex
    test    eax, eax
    jz      .advance_one
    mov     rdi, rbx
    mov     rsi, r12
    call    _er_tsx_skip_regex_source
    test    rdx, rdx
    jnz     .parse_error
    mov     rbx, rax
    jmp     .scan_loop

.maybe_tsx:
    lea     r10, [rbx + 1]
    cmp     r10, r12
    jae     .parse_error
    cmp     byte [r10], '/'
    je      .advance_one
    cmp     byte [r10], '>'
    je      .parse_prefix
    movzx   eax, byte [r10]
    call    _er_tsx_is_name_start
    test    eax, eax
    jz      .advance_one
    mov     rdi, rbx
    mov     rsi, [rbp - 56]
    call    _er_tsx_source_context_allows_root
    test    eax, eax
    jz      .advance_one

.parse_prefix:
    mov     rdi, rbx
    mov     rsi, r12
    sub     rsi, rbx
    xor     edx, edx
    xor     ecx, ecx
    call    er_wasmc_parse_tsx_prefix_tree
    test    rdx, rdx
    jnz     .advance_one
    inc     r13
    add     r14, rax
    add     r15, rcx
    add     [rbp - 48], r8
    add     rbx, r9
    jmp     .scan_loop

.skip_string:
    mov     rdi, rbx
    mov     rsi, r12
    call    _er_tsx_skip_quoted_source
    test    rdx, rdx
    jnz     .parse_error
    mov     rbx, rax
    jmp     .scan_loop

.skip_template:
    mov     rdi, rbx
    mov     rsi, r12
    call    _er_tsx_scan_template_source
    test    rdx, rdx
    jnz     .parse_error
    add     r13, rcx
    add     r14, r8
    add     r15, r9
    add     [rbp - 48], r10
    mov     rbx, rax
    jmp     .scan_loop

.skip_line_comment:
    mov     rdi, rbx
    mov     rsi, r12
    call    _er_tsx_skip_line_comment_source
    test    rdx, rdx
    jnz     .parse_error
    mov     rbx, rax
    jmp     .scan_loop

.skip_block_comment:
    mov     rdi, rbx
    mov     rsi, r12
    call    _er_tsx_skip_block_comment_source
    test    rdx, rdx
    jnz     .parse_error
    mov     rbx, rax
    jmp     .scan_loop

.advance_one:
    inc     rbx
    jmp     .scan_loop

.success:
    mov     rax, r13
    mov     rcx, r14
    mov     r8, r15
    mov     r9, [rbp - 48]
    xor     edx, edx
    jmp     .done
.bad_argument:
    xor     eax, eax
    xor     ecx, ecx
    xor     r8d, r8d
    xor     r9d, r9d
    mov     edx, ERROR_BAD_ARGUMENT
    jmp     .done
.parse_error:
    xor     eax, eax
    xor     ecx, ecx
    xor     r8d, r8d
    xor     r9d, r9d
    mov     edx, ERROR_PARSE
.done:
    add     rsp, 64
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; er_wasmc_parse_tsx_tree(source=rdi, source_len=rsi, nodes=rdx, node_cap=rcx)
; Validates one TSX element tree and optionally writes preorder element records.
; Node record: qword name_ptr, name_len, parent_index, attr_count, text_count.
; Parent index is -1 for the root. If nodes is zero, node_cap is ignored.
; Returns rax=element_count, rcx=attribute_count, r8=text_node_count, rdx=0.
er_fn er_wasmc_parse_tsx_tree
    xor     r8d, r8d
    jmp     _er_wasmc_parse_tsx_tree_mode

; er_wasmc_parse_tsx_prefix_tree(source=rdi, source_len=rsi, nodes=rdx, node_cap=rcx)
; Same parser, but succeeds after the first complete TSX root and returns
; r9=bytes_consumed. Used by TSX source-file scanning.
er_fn er_wasmc_parse_tsx_prefix_tree
    mov     r8d, 1
    jmp     _er_wasmc_parse_tsx_tree_mode

er_fn _er_wasmc_parse_tsx_tree_mode
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
    mov     [rbp - 136], r8
    mov     rbx, r12
    xor     r14d, r14d
    xor     r15d, r15d
    mov     qword [rbp - 48], 0
    mov     qword [rbp - 80], 0
    mov     qword [rbp - 88], 0
    mov     qword [rbp - 128], 0

.leading_wrapper_loop:
    mov     rdi, rbx
    mov     rsi, r13
    call    _er_wasmc_skip_ws
    mov     rbx, rax
    cmp     rbx, r13
    jae     .parse_error
    cmp     byte [rbx], '!'
    jne     .leading_not_done
    inc     rbx
    jmp     .leading_wrapper_loop
.leading_not_done:
    cmp     byte [rbx], '('
    jne     .expect_root_tag
    inc     qword [rbp - 128]
    inc     rbx
    jmp     .leading_wrapper_loop
.expect_root_tag:
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
    cmp     byte [rbx], '{'
    je      .brace_child
    movzx   eax, byte [rbx]
    cmp     al, '&'
    je      .entity_text
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
.entity_text:
    mov     qword [rbp - 96], 1
    mov     rdi, rbx
    mov     rsi, r13
    call    _er_tsx_skip_entity
    test    rdx, rdx
    jnz     .parse_error
    mov     rbx, rax
    jmp     .text_loop
.brace_child:
    cmp     qword [rbp - 96], 0
    je      .skip_brace_child
    inc     qword [rbp - 88]
    mov     r10, [rbp - 112]
    test    r10, r10
    jz      .skip_brace_child
    mov     r11, r14
    dec     r11
    lea     r9, [rbp - WASMC_TSX_STACK_INDEX_OFF]
    mov     r11, [r9 + r11 * 8]
    imul    r11, r11, WASMC_TSX_NODE_STRIDE
    inc     qword [r10 + r11 + WASMC_TSX_NODE_TEXT_COUNT]
.skip_brace_child:
    mov     rdi, rbx
    mov     rsi, r13
    call    _er_tsx_skip_balanced_braces
    test    rdx, rdx
    jnz     .parse_error
    mov     [rbp - 152], rax
    cmp     qword [rbp - 112], 0
    jne     .brace_child_tree
    lea     rdi, [rbx + 1]
    mov     rsi, [rbp - 152]
    dec     rsi
    call    _er_tsx_scan_inner_stats
    test    rdx, rdx
    jnz     .parse_error
    add     r15, rcx
    add     [rbp - 80], r8
    add     [rbp - 88], r9
    jmp     .brace_child_done
.brace_child_tree:
    lea     rdi, [rbx + 1]
    mov     rsi, [rbp - 152]
    dec     rsi
    mov     rdx, [rbp - 112]
    mov     rcx, [rbp - 120]
    mov     r8, r14
    dec     r8
    lea     r9, [rbp - WASMC_TSX_STACK_INDEX_OFF]
    mov     r8, [r9 + r8 * 8]
    mov     r9, r15
    call    _er_tsx_scan_inner_tree
    test    rdx, rdx
    jnz     .inner_tree_error
    add     r15, rax
    add     [rbp - 80], rcx
    add     [rbp - 88], r8
.brace_child_done:
    mov     rbx, [rbp - 152]
    jmp     .loop
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
    cmp     rbx, r13
    jae     .parse_error
    cmp     byte [rbx], '>'
    je      .open_fragment
    mov     rdi, rbx
    mov     rsi, r13
    call    _er_tsx_parse_name
    test    rdx, rdx
    jnz     .parse_error
    mov     [rbp - 56], rax
    mov     [rbp - 64], rcx
    mov     rbx, r8
    cmp     rbx, r13
    jae     .parse_error
    cmp     byte [rbx], '<'
    jne     .open_name_done
    mov     rdi, rbx
    mov     rsi, r13
    call    _er_tsx_skip_type_args
    test    rdx, rdx
    jnz     .parse_error
    mov     rbx, rax
.open_name_done:
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
    jmp     .attr_loop

.open_fragment:
    xor     eax, eax
    mov     [rbp - 56], rax
    mov     [rbp - 64], rax
    mov     [rbp - 104], r15
    mov     r10, [rbp - 112]
    test    r10, r10
    jz      .record_fragment_done
    cmp     r15, [rbp - 120]
    jae     .no_space
    mov     r11, r15
    imul    r11, r11, WASMC_TSX_NODE_STRIDE
    mov     qword [r10 + r11 + WASMC_TSX_NODE_NAME_PTR], 0
    mov     qword [r10 + r11 + WASMC_TSX_NODE_NAME_LEN], 0
    mov     qword [r10 + r11 + WASMC_TSX_NODE_ATTR_COUNT], 0
    mov     qword [r10 + r11 + WASMC_TSX_NODE_TEXT_COUNT], 0
    test    r14, r14
    jz      .record_fragment_root
    mov     rax, r14
    dec     rax
    lea     r9, [rbp - WASMC_TSX_STACK_INDEX_OFF]
    mov     rax, [r9 + rax * 8]
    jmp     .record_fragment_parent
.record_fragment_root:
    mov     rax, -1
.record_fragment_parent:
    mov     [r10 + r11 + WASMC_TSX_NODE_PARENT], rax
.record_fragment_done:
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
    je      .attr_slash
    cmp     byte [rbx], '{'
    je      .spread_attr
    mov     rdi, rbx
    mov     rsi, r13
    call    _er_tsx_parse_name
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

.attr_slash:
    lea     r9, [rbx + 1]
    cmp     r9, r13
    jae     .parse_error
    cmp     byte [r9], '>'
    je      .self_close
    cmp     byte [r9], '/'
    je      .attr_line_comment
    cmp     byte [r9], '*'
    je      .attr_block_comment
    jmp     .parse_error
.attr_line_comment:
    lea     rbx, [rbx + 2]
.attr_line_comment_loop:
    cmp     rbx, r13
    jae     .parse_error
    movzx   eax, byte [rbx]
    cmp     al, 10
    je      .attr_line_comment_done
    cmp     al, 13
    je      .attr_line_comment_done
    inc     rbx
    jmp     .attr_line_comment_loop
.attr_line_comment_done:
    inc     rbx
    jmp     .attr_loop
.attr_block_comment:
    lea     rbx, [rbx + 2]
.attr_block_comment_loop:
    lea     r9, [rbx + 1]
    cmp     r9, r13
    jae     .parse_error
    cmp     byte [rbx], '*'
    jne     .attr_block_comment_next
    cmp     byte [r9], '/'
    je      .attr_block_comment_done
.attr_block_comment_next:
    inc     rbx
    jmp     .attr_block_comment_loop
.attr_block_comment_done:
    lea     rbx, [rbx + 2]
    jmp     .attr_loop

.spread_attr:
    mov     rdi, rbx
    mov     rsi, r13
    call    _er_tsx_skip_balanced_braces
    test    rdx, rdx
    jnz     .parse_error
    mov     [rbp - 152], rax
    cmp     qword [rbp - 112], 0
    jne     .spread_attr_tree
    lea     rdi, [rbx + 1]
    mov     rsi, [rbp - 152]
    dec     rsi
    call    _er_tsx_scan_inner_stats
    test    rdx, rdx
    jnz     .parse_error
    add     r15, rcx
    add     [rbp - 80], r8
    add     [rbp - 88], r9
    jmp     .spread_attr_count
.spread_attr_tree:
    lea     rdi, [rbx + 1]
    mov     rsi, [rbp - 152]
    dec     rsi
    mov     rdx, [rbp - 112]
    mov     rcx, [rbp - 120]
    mov     r8, [rbp - 104]
    mov     r9, r15
    call    _er_tsx_scan_inner_tree
    test    rdx, rdx
    jnz     .inner_tree_error
    add     r15, rax
    add     [rbp - 80], rcx
    add     [rbp - 88], r8
.spread_attr_count:
    mov     rax, [rbp - 152]
    mov     rbx, rax
    inc     qword [rbp - 80]
    mov     r10, [rbp - 112]
    test    r10, r10
    jz      .attr_loop
    mov     r11, [rbp - 104]
    imul    r11, r11, WASMC_TSX_NODE_STRIDE
    inc     qword [r10 + r11 + WASMC_TSX_NODE_ATTR_COUNT]
    jmp     .attr_loop

.quoted_attr:
    mov     rdi, rbx
    mov     rsi, r13
    call    _er_tsx_skip_quoted_attr
    test    rdx, rdx
    jnz     .parse_error
    mov     rbx, rax
    jmp     .attr_loop

.brace_attr:
    mov     qword [rbp - 144], 1
    inc     rbx
    mov     [rbp - 160], rbx
.brace_loop:
    cmp     rbx, r13
    jae     .parse_error
    movzx   eax, byte [rbx]
    cmp     al, '{'
    je      .brace_inc
    cmp     al, '}'
    je      .brace_dec
    cmp     al, '"'
    je      .brace_quoted
    cmp     al, 39
    je      .brace_quoted
    cmp     al, '`'
    je      .brace_quoted
    cmp     al, '/'
    je      .brace_slash
    inc     rbx
    jmp     .brace_loop
.brace_inc:
    inc     qword [rbp - 144]
    inc     rbx
    jmp     .brace_loop
.brace_dec:
    dec     qword [rbp - 144]
    inc     rbx
    cmp     qword [rbp - 144], 0
    jnz     .brace_loop
    mov     [rbp - 152], rbx
    cmp     qword [rbp - 112], 0
    jne     .brace_attr_tree
    mov     rdi, [rbp - 160]
    mov     rsi, [rbp - 152]
    dec     rsi
    call    _er_tsx_scan_inner_stats
    test    rdx, rdx
    jnz     .parse_error
    add     r15, rcx
    add     [rbp - 80], r8
    add     [rbp - 88], r9
    jmp     .brace_attr_done
.brace_attr_tree:
    mov     rdi, [rbp - 160]
    mov     rsi, [rbp - 152]
    dec     rsi
    mov     rdx, [rbp - 112]
    mov     rcx, [rbp - 120]
    mov     r8, [rbp - 104]
    mov     r9, r15
    call    _er_tsx_scan_inner_tree
    test    rdx, rdx
    jnz     .inner_tree_error
    add     r15, rax
    add     [rbp - 80], rcx
    add     [rbp - 88], r8
.brace_attr_done:
    mov     rbx, [rbp - 152]
    jmp     .attr_loop
.brace_quoted:
    mov     rdi, rbx
    mov     rsi, r13
    call    _er_tsx_skip_quoted_source
    test    rdx, rdx
    jnz     .parse_error
    mov     rbx, rax
    jmp     .brace_loop
.brace_slash:
    lea     r9, [rbx + 1]
    cmp     r9, r13
    jae     .parse_error
    cmp     byte [r9], '/'
    je      .brace_line_comment
    cmp     byte [r9], '*'
    je      .brace_block_comment
    mov     rdi, rbx
    mov     rsi, r12
    call    _er_tsx_source_context_allows_regex
    test    eax, eax
    jz      .brace_slash_advance
    mov     rdi, rbx
    mov     rsi, r13
    call    _er_tsx_skip_regex_source
    test    rdx, rdx
    jnz     .parse_error
    mov     rbx, rax
    jmp     .brace_loop
.brace_slash_advance:
    inc     rbx
    jmp     .brace_loop
.brace_line_comment:
    lea     rbx, [rbx + 2]
.brace_line_comment_loop:
    cmp     rbx, r13
    jae     .parse_error
    movzx   eax, byte [rbx]
    cmp     al, 10
    je      .brace_line_comment_done
    cmp     al, 13
    je      .brace_line_comment_done
    inc     rbx
    jmp     .brace_line_comment_loop
.brace_line_comment_done:
    inc     rbx
    jmp     .brace_loop
.brace_block_comment:
    lea     rbx, [rbx + 2]
.brace_block_comment_loop:
    lea     r9, [rbx + 1]
    cmp     r9, r13
    jae     .parse_error
    cmp     byte [rbx], '*'
    jne     .brace_block_comment_next
    cmp     byte [r9], '/'
    je      .brace_block_comment_done
.brace_block_comment_next:
    inc     rbx
    jmp     .brace_block_comment_loop
.brace_block_comment_done:
    lea     rbx, [rbx + 2]
    jmp     .brace_loop

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
    mov     rdi, [rbp - 56]
    mov     rsi, [rbp - 64]
    call    _er_tsx_name_is_raw
    test    eax, eax
    jnz     .raw_text_element
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

.raw_text_element:
    inc     rbx
    mov     rdi, rbx
    mov     rsi, r13
    mov     rdx, [rbp - 56]
    mov     rcx, [rbp - 64]
    call    _er_tsx_scan_raw_close
    test    rdx, rdx
    jnz     .parse_error
    mov     rbx, rax
    test    r8, r8
    jz      .raw_text_counted
    inc     qword [rbp - 88]
    mov     r10, [rbp - 112]
    test    r10, r10
    jz      .raw_text_counted
    mov     r11, [rbp - 104]
    imul    r11, r11, WASMC_TSX_NODE_STRIDE
    inc     qword [r10 + r11 + WASMC_TSX_NODE_TEXT_COUNT]
.raw_text_counted:
    test    r14, r14
    jnz     .loop
    mov     qword [rbp - 48], 1
    jmp     .after_root_close

.close_tag:
    test    r14, r14
    jz      .parse_error
    lea     rbx, [rbx + 2]
    cmp     rbx, r13
    jae     .parse_error
    cmp     byte [rbx], '>'
    je      .close_fragment
    mov     rdi, rbx
    mov     rsi, r13
    call    _er_tsx_parse_name
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
    jmp     .name_compare
.close_fragment:
    xor     eax, eax
    xor     ecx, ecx
    mov     r8, rbx
    dec     r14
    lea     r11, [rbp - WASMC_TSX_STACK_LEN_OFF]
    cmp     qword [r11 + r14 * 8], 0
    jne     .parse_error
    mov     rbx, r8
    xor     r10d, r10d
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
    cmp     qword [rbp - 136], 0
    je      .strict_after_root_close
    mov     r9, rbx
    sub     r9, r12
    mov     rax, r15
    mov     rcx, [rbp - 80]
    mov     r8, [rbp - 88]
    xor     edx, edx
    jmp     .done
.strict_after_root_close:
    mov     rdi, rbx
    mov     rsi, r13
    call    _er_wasmc_skip_ws
    mov     rbx, rax
    mov     r10, [rbp - 128]
.trailing_wrapper_loop:
    mov     rdi, rbx
    mov     rsi, r13
    call    _er_tsx_skip_trailing_assertions
    test    rdx, rdx
    jnz     .parse_error
    mov     rbx, rax
    test    r10, r10
    jz      .trailing_semicolon
    cmp     rbx, r13
    jae     .parse_error
    cmp     byte [rbx], ')'
    jne     .parse_error
    inc     rbx
    dec     r10
    mov     rdi, rbx
    mov     rsi, r13
    call    _er_wasmc_skip_ws
    mov     rbx, rax
    jmp     .trailing_wrapper_loop
.trailing_semicolon:
    cmp     rbx, r13
    jae     .trailing_done
    cmp     byte [rbx], ';'
    jne     .parse_error
    inc     rbx
    mov     rdi, rbx
    mov     rsi, r13
    call    _er_wasmc_skip_ws
    mov     rbx, rax
.trailing_done:
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
    jmp     .done
.inner_tree_error:
    xor     eax, eax
    xor     ecx, ecx
    xor     r8d, r8d
.done:
    add     rsp, 640
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; _er_tsx_scan_inner_stats(start=rdi, end_exclusive=rsi)
; Returns rcx=elements, r8=attributes, r9=text nodes, rdx=0/error.
er_fn _er_tsx_scan_inner_stats
    cmp     rsi, rdi
    jbe     .empty
    sub     rsi, rdi
    call    er_wasmc_scan_tsx_source
    ret
.empty:
    xor     ecx, ecx
    xor     r8d, r8d
    xor     r9d, r9d
    xor     edx, edx
    ret

; _er_tsx_skip_line_comment_source(cursor=rdi, end=rsi)
; Returns rax after newline or end, rdx=0.
er_fn _er_tsx_skip_line_comment_source
    mov     rax, rdi
    lea     rax, [rax + 2]
.loop:
    cmp     rax, rsi
    jae     .ok
    movzx   edx, byte [rax]
    inc     rax
    cmp     dl, 10
    je      .ok
    cmp     dl, 13
    je      .ok
    jmp     .loop
.ok:
    xor     edx, edx
    ret

; _er_tsx_skip_block_comment_source(cursor=rdi, end=rsi)
; Returns rax after closing */, rdx=0/error.
er_fn _er_tsx_skip_block_comment_source
    mov     rax, rdi
    lea     rax, [rax + 2]
.loop:
    lea     r10, [rax + 1]
    cmp     r10, rsi
    jae     .bad
    cmp     byte [rax], '*'
    jne     .next
    cmp     byte [r10], '/'
    je      .done
.next:
    inc     rax
    jmp     .loop
.done:
    lea     rax, [rax + 2]
    xor     edx, edx
    ret
.bad:
    xor     eax, eax
    mov     edx, ERROR_PARSE
    ret

; _er_tsx_scan_inner_tree(start=rdi, end_exclusive=rsi, nodes=rdx,
;                         node_cap=rcx, parent_index=r8, base_index=r9)
; Scans expression contents, appends nested JSX nodes, and remaps parent indexes.
; Returns rax=elements, rcx=attributes, r8=text nodes, rdx=0/error.
er_fn _er_tsx_scan_inner_tree
    er_frame_push
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 128

    xor     r13d, r13d
    xor     r14d, r14d
    xor     r15d, r15d
    cmp     rsi, rdi
    jbe     .success
    test    rdx, rdx
    jz      .bad_argument
    mov     rbx, rdi
    mov     [rbp - 56], rdi
    mov     r12, rsi
    mov     [rbp - 64], rdx
    mov     [rbp - 72], rcx
    mov     [rbp - 80], r8
    mov     [rbp - 128], r9

.scan_loop:
    cmp     rbx, r12
    jae     .success
    movzx   eax, byte [rbx]
    cmp     al, '"'
    je      .skip_string
    cmp     al, 39
    je      .skip_string
    cmp     al, '`'
    je      .scan_template
    cmp     al, '/'
    je      .slash
    cmp     al, '<'
    je      .maybe_tsx
    inc     rbx
    jmp     .scan_loop

.slash:
    lea     r10, [rbx + 1]
    cmp     r10, r12
    jae     .advance_one
    cmp     byte [r10], '/'
    je      .skip_line_comment
    cmp     byte [r10], '*'
    je      .skip_block_comment
    mov     rdi, rbx
    mov     rsi, [rbp - 56]
    call    _er_tsx_source_context_allows_regex
    test    eax, eax
    jz      .advance_one
    mov     rdi, rbx
    mov     rsi, r12
    call    _er_tsx_skip_regex_source
    test    rdx, rdx
    jnz     .parse_error
    mov     rbx, rax
    jmp     .scan_loop

.maybe_tsx:
    lea     r10, [rbx + 1]
    cmp     r10, r12
    jae     .parse_error
    cmp     byte [r10], '/'
    je      .advance_one
    cmp     byte [r10], '>'
    je      .parse_prefix
    movzx   eax, byte [r10]
    call    _er_tsx_is_name_start
    test    eax, eax
    jz      .advance_one
    mov     rdi, rbx
    mov     rsi, [rbp - 56]
    call    _er_tsx_source_context_allows_root
    test    eax, eax
    jz      .advance_one

.parse_prefix:
    mov     r11, [rbp - 128]
    add     r11, r13
    mov     [rbp - 88], r11
    mov     r10, [rbp - 72]
    cmp     r10, r11
    jb      .no_space
    sub     r10, r11
    mov     rdx, r11
    imul    rdx, rdx, WASMC_TSX_NODE_STRIDE
    add     rdx, [rbp - 64]
    mov     rdi, rbx
    mov     rsi, r12
    sub     rsi, rbx
    mov     rcx, r10
    call    er_wasmc_parse_tsx_prefix_tree
    test    rdx, rdx
    jnz     .inner_error
    mov     [rbp - 96], rax
    mov     [rbp - 104], rcx
    mov     [rbp - 112], r8
    mov     [rbp - 120], r9
    xor     r10d, r10d
.adjust_loop:
    cmp     r10, [rbp - 96]
    jae     .adjust_done
    mov     rdx, [rbp - 88]
    add     rdx, r10
    imul    rdx, rdx, WASMC_TSX_NODE_STRIDE
    add     rdx, [rbp - 64]
    mov     rax, [rdx + WASMC_TSX_NODE_PARENT]
    cmp     rax, -1
    jne     .relative_parent
    mov     rax, [rbp - 80]
    jmp     .store_parent
.relative_parent:
    add     rax, [rbp - 88]
.store_parent:
    mov     [rdx + WASMC_TSX_NODE_PARENT], rax
    inc     r10
    jmp     .adjust_loop
.adjust_done:
    add     r13, [rbp - 96]
    add     r14, [rbp - 104]
    add     r15, [rbp - 112]
    add     rbx, [rbp - 120]
    jmp     .scan_loop

.skip_string:
    mov     rdi, rbx
    mov     rsi, r12
    call    _er_tsx_skip_quoted_source
    test    rdx, rdx
    jnz     .parse_error
    mov     rbx, rax
    jmp     .scan_loop

.scan_template:
    mov     rdi, rbx
    mov     rsi, r12
    mov     rdx, [rbp - 64]
    mov     rcx, [rbp - 72]
    mov     r8, [rbp - 80]
    mov     r9, [rbp - 128]
    add     r9, r13
    call    _er_tsx_scan_template_tree
    test    rdx, rdx
    jnz     .parse_error
    mov     rbx, rax
    add     r13, rcx
    add     r14, r8
    add     r15, r9
    jmp     .scan_loop

.skip_line_comment:
    mov     rdi, rbx
    mov     rsi, r12
    call    _er_tsx_skip_line_comment_source
    test    rdx, rdx
    jnz     .parse_error
    mov     rbx, rax
    jmp     .scan_loop

.skip_block_comment:
    mov     rdi, rbx
    mov     rsi, r12
    call    _er_tsx_skip_block_comment_source
    test    rdx, rdx
    jnz     .parse_error
    mov     rbx, rax
    jmp     .scan_loop

.advance_one:
    inc     rbx
    jmp     .scan_loop

.success:
    mov     rax, r13
    mov     rcx, r14
    mov     r8, r15
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
.inner_error:
    xor     eax, eax
    xor     ecx, ecx
    xor     r8d, r8d
    jmp     .done
.parse_error:
    xor     eax, eax
    xor     ecx, ecx
    xor     r8d, r8d
    mov     edx, ERROR_PARSE
.done:
    add     rsp, 128
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; _er_tsx_parse_name(cursor=rdi, end=rsi)
; Returns rax=name_ptr, rcx=name_len, r8=cursor_after_name, rdx=0.
er_fn _er_tsx_parse_name
    cmp     rdi, rsi
    jae     .bad
    movzx   eax, byte [rdi]
    call    _er_tsx_is_name_start
    test    eax, eax
    jz      .bad
    mov     r8, rdi
    inc     r8
.loop:
    cmp     r8, rsi
    jae     .done
    movzx   eax, byte [r8]
    call    _er_tsx_is_name_continue
    test    eax, eax
    jz      .done
    inc     r8
    jmp     .loop
.done:
    mov     rcx, r8
    sub     rcx, rdi
    cmp     rcx, WASMC_TSX_MAX_NAME_LEN
    ja      .bad
    mov     rax, rdi
    xor     edx, edx
    ret
.bad:
    xor     eax, eax
    xor     ecx, ecx
    xor     r8d, r8d
    mov     edx, ERROR_PARSE
    ret

er_fn _er_tsx_is_name_start
    cmp     al, '_'
    je      .true
    cmp     al, '$'
    je      .true
    cmp     al, 'A'
    jb      .false
    cmp     al, 'Z'
    jbe     .true
    cmp     al, 'a'
    jb      .false
    cmp     al, 'z'
    jbe     .true
    cmp     al, 128
    jae     .true
.false:
    xor     eax, eax
    ret
.true:
    mov     eax, 1
    ret

er_fn _er_tsx_is_name_continue
    cmp     al, '0'
    jb      .punct
    cmp     al, '9'
    jbe     .true
.punct:
    cmp     al, '-'
    je      .true
    cmp     al, '.'
    je      .true
    cmp     al, ':'
    je      .true
    jmp     _er_tsx_is_name_start
.true:
    mov     eax, 1
    ret

; _er_tsx_skip_entity(cursor=rdi, end=rsi)
; Accepts &name;, &#123;, and &#x7b; text entities.
er_fn _er_tsx_skip_entity
    push    rbx
    mov     rbx, rdi
    cmp     rbx, rsi
    jae     .bad
    cmp     byte [rbx], '&'
    jne     .bad
    inc     rbx
    cmp     rbx, rsi
    jae     .bad
    cmp     byte [rbx], '#'
    je      .numeric
    movzx   edx, byte [rbx]
    call    _er_tsx_is_entity_alpha
    test    eax, eax
    jz      .bad
.name_loop:
    inc     rbx
    cmp     rbx, rsi
    jae     .bad
    cmp     byte [rbx], ';'
    je      .done
    movzx   edx, byte [rbx]
    call    _er_tsx_is_entity_alnum
    test    eax, eax
    jnz     .name_loop
    jmp     .bad
.numeric:
    inc     rbx
    cmp     rbx, rsi
    jae     .bad
    cmp     byte [rbx], 'x'
    je      .hex_prefix
    cmp     byte [rbx], 'X'
    je      .hex_prefix
    movzx   edx, byte [rbx]
    call    _er_tsx_is_digit
    test    eax, eax
    jz      .bad
.digit_loop:
    inc     rbx
    cmp     rbx, rsi
    jae     .bad
    cmp     byte [rbx], ';'
    je      .done
    movzx   edx, byte [rbx]
    call    _er_tsx_is_digit
    test    eax, eax
    jnz     .digit_loop
    jmp     .bad
.hex_prefix:
    inc     rbx
    cmp     rbx, rsi
    jae     .bad
    movzx   edx, byte [rbx]
    call    _er_tsx_is_hex_digit
    test    eax, eax
    jz      .bad
.hex_loop:
    inc     rbx
    cmp     rbx, rsi
    jae     .bad
    cmp     byte [rbx], ';'
    je      .done
    movzx   edx, byte [rbx]
    call    _er_tsx_is_hex_digit
    test    eax, eax
    jnz     .hex_loop
    jmp     .bad
.done:
    lea     rax, [rbx + 1]
    xor     edx, edx
    pop     rbx
    ret
.bad:
    xor     eax, eax
    mov     edx, ERROR_PARSE
    pop     rbx
    ret

er_fn _er_tsx_is_entity_alpha
    cmp     dl, 'A'
    jb      .false
    cmp     dl, 'Z'
    jbe     .true
    cmp     dl, 'a'
    jb      .false
    cmp     dl, 'z'
    jbe     .true
.false:
    xor     eax, eax
    ret
.true:
    mov     eax, 1
    ret

er_fn _er_tsx_is_digit
    cmp     dl, '0'
    jb      .false
    cmp     dl, '9'
    ja      .false
    mov     eax, 1
    ret
.false:
    xor     eax, eax
    ret

er_fn _er_tsx_is_entity_alnum
    call    _er_tsx_is_entity_alpha
    test    eax, eax
    jnz     .true
    jmp     _er_tsx_is_digit
.true:
    mov     eax, 1
    ret

er_fn _er_tsx_is_hex_digit
    call    _er_tsx_is_digit
    test    eax, eax
    jnz     .true
    cmp     dl, 'A'
    jb      .false
    cmp     dl, 'F'
    jbe     .true
    cmp     dl, 'a'
    jb      .false
    cmp     dl, 'f'
    jbe     .true
.false:
    xor     eax, eax
    ret
.true:
    mov     eax, 1
    ret

; _er_tsx_source_context_allows_root(cursor=rdi, source_start=rsi)
; Heuristic for TSX roots embedded in TypeScript source.
er_fn _er_tsx_source_context_allows_root
    mov     rax, rdi
.back_ws:
    cmp     rax, rsi
    jbe     .true
    dec     rax
    movzx   edx, byte [rax]
    cmp     dl, ' '
    je      .back_ws
    cmp     dl, 9
    je      .back_ws
    cmp     dl, 10
    je      .back_ws
    cmp     dl, 13
    je      .back_ws
    cmp     dl, '='
    je      .true
    cmp     dl, '('
    je      .true
    cmp     dl, ')'
    je      .true
    cmp     dl, '['
    je      .true
    cmp     dl, '{'
    je      .true
    cmp     dl, ','
    je      .true
    cmp     dl, ':'
    je      .true
    cmp     dl, '?'
    je      .true
    cmp     dl, '>'
    je      .true
    cmp     dl, '!'
    je      .true
    cmp     dl, '&'
    je      .true
    cmp     dl, '|'
    je      .true
    cmp     dl, ';'
    je      .true
    cmp     dl, '}'
    je      .true
    cmp     dl, 'n'
    je      .maybe_return
    cmp     dl, 'd'
    je      .maybe_yield
    cmp     dl, 'e'
    je      .maybe_case
    cmp     dl, 'w'
    je      .maybe_throw
    cmp     dl, 't'
    je      .maybe_await
    cmp     dl, 'o'
    je      .maybe_do
    cmp     dl, 'f'
    je      .maybe_of
    cmp     dl, 'g'
    je      .maybe_using
    jmp     .false
.maybe_return:
    mov     r8, rax
    sub     r8, 5
    cmp     r8, rsi
    jb      .maybe_in
    cmp     byte [r8], 'r'
    jne     .maybe_in
    cmp     byte [r8 + 1], 'e'
    jne     .maybe_in
    cmp     byte [r8 + 2], 't'
    jne     .maybe_in
    cmp     byte [r8 + 3], 'u'
    jne     .maybe_in
    cmp     byte [r8 + 4], 'r'
    jne     .maybe_in
    jmp     .keyword_boundary
.maybe_in:
    mov     r8, rax
    dec     r8
    cmp     r8, rsi
    jb      .false
    cmp     byte [r8], 'i'
    jne     .false
    jmp     .keyword_boundary
.maybe_yield:
    mov     r8, rax
    sub     r8, 4
    cmp     r8, rsi
    jb      .maybe_void
    cmp     byte [r8], 'y'
    jne     .maybe_void
    cmp     byte [r8 + 1], 'i'
    jne     .maybe_void
    cmp     byte [r8 + 2], 'e'
    jne     .maybe_void
    cmp     byte [r8 + 3], 'l'
    jne     .maybe_void
    jmp     .keyword_boundary
.maybe_void:
    mov     r8, rax
    sub     r8, 3
    cmp     r8, rsi
    jb      .false
    cmp     byte [r8], 'v'
    jne     .false
    cmp     byte [r8 + 1], 'o'
    jne     .false
    cmp     byte [r8 + 2], 'i'
    jne     .false
    jmp     .keyword_boundary
.maybe_case:
    mov     r8, rax
    sub     r8, 3
    cmp     r8, rsi
    jb      .maybe_else
    cmp     byte [r8], 'c'
    jne     .maybe_else
    cmp     byte [r8 + 1], 'a'
    jne     .maybe_else
    cmp     byte [r8 + 2], 's'
    jne     .maybe_else
    jmp     .keyword_boundary
.maybe_else:
    mov     r8, rax
    sub     r8, 3
    cmp     r8, rsi
    jb      .maybe_delete
    cmp     byte [r8], 'e'
    jne     .maybe_delete
    cmp     byte [r8 + 1], 'l'
    jne     .maybe_delete
    cmp     byte [r8 + 2], 's'
    jne     .maybe_delete
    jmp     .keyword_boundary
.maybe_delete:
    mov     r8, rax
    sub     r8, 5
    cmp     r8, rsi
    jb      .false
    cmp     byte [r8], 'd'
    jne     .false
    cmp     byte [r8 + 1], 'e'
    jne     .false
    cmp     byte [r8 + 2], 'l'
    jne     .false
    cmp     byte [r8 + 3], 'e'
    jne     .false
    cmp     byte [r8 + 4], 't'
    jne     .false
    jmp     .keyword_boundary
.maybe_throw:
    mov     r8, rax
    sub     r8, 4
    cmp     r8, rsi
    jb      .maybe_new
    cmp     byte [r8], 't'
    jne     .maybe_new
    cmp     byte [r8 + 1], 'h'
    jne     .maybe_new
    cmp     byte [r8 + 2], 'r'
    jne     .maybe_new
    cmp     byte [r8 + 3], 'o'
    jne     .maybe_new
    jmp     .keyword_boundary
.maybe_new:
    mov     r8, rax
    sub     r8, 2
    cmp     r8, rsi
    jb      .false
    cmp     byte [r8], 'n'
    jne     .false
    cmp     byte [r8 + 1], 'e'
    jne     .false
    jmp     .keyword_boundary
.maybe_await:
    mov     r8, rax
    sub     r8, 4
    cmp     r8, rsi
    jb      .maybe_default
    cmp     byte [r8], 'a'
    jne     .maybe_default
    cmp     byte [r8 + 1], 'w'
    jne     .maybe_default
    cmp     byte [r8 + 2], 'a'
    jne     .maybe_default
    cmp     byte [r8 + 3], 'i'
    jne     .maybe_default
    jmp     .keyword_boundary
.maybe_default:
    mov     r8, rax
    sub     r8, 6
    cmp     r8, rsi
    jb      .false
    cmp     byte [r8], 'd'
    jne     .false
    cmp     byte [r8 + 1], 'e'
    jne     .false
    cmp     byte [r8 + 2], 'f'
    jne     .false
    cmp     byte [r8 + 3], 'a'
    jne     .false
    cmp     byte [r8 + 4], 'u'
    jne     .false
    cmp     byte [r8 + 5], 'l'
    jne     .false
    jmp     .keyword_boundary
.maybe_do:
    mov     r8, rax
    dec     r8
    cmp     r8, rsi
    jb      .false
    cmp     byte [r8], 'd'
    jne     .false
    jmp     .keyword_boundary
.maybe_of:
    mov     r8, rax
    sub     r8, 9
    cmp     r8, rsi
    jb      .maybe_typeof
    cmp     byte [r8], 'i'
    jne     .maybe_typeof
    cmp     byte [r8 + 1], 'n'
    jne     .maybe_typeof
    cmp     byte [r8 + 2], 's'
    jne     .maybe_typeof
    cmp     byte [r8 + 3], 't'
    jne     .maybe_typeof
    cmp     byte [r8 + 4], 'a'
    jne     .maybe_typeof
    cmp     byte [r8 + 5], 'n'
    jne     .maybe_typeof
    cmp     byte [r8 + 6], 'c'
    jne     .maybe_typeof
    cmp     byte [r8 + 7], 'e'
    jne     .maybe_typeof
    cmp     byte [r8 + 8], 'o'
    jne     .maybe_typeof
    jmp     .keyword_boundary
.maybe_typeof:
    mov     r8, rax
    sub     r8, 5
    cmp     r8, rsi
    jb      .short_of
    cmp     byte [r8], 't'
    jne     .short_of
    cmp     byte [r8 + 1], 'y'
    jne     .short_of
    cmp     byte [r8 + 2], 'p'
    jne     .short_of
    cmp     byte [r8 + 3], 'e'
    jne     .short_of
    cmp     byte [r8 + 4], 'o'
    jne     .short_of
    jmp     .keyword_boundary
.short_of:
    mov     r8, rax
    dec     r8
    cmp     r8, rsi
    jb      .false
    cmp     byte [r8], 'o'
    jne     .false
    jmp     .keyword_boundary
.maybe_using:
    mov     r8, rax
    sub     r8, 4
    cmp     r8, rsi
    jb      .false
    cmp     byte [r8], 'u'
    jne     .false
    cmp     byte [r8 + 1], 's'
    jne     .false
    cmp     byte [r8 + 2], 'i'
    jne     .false
    cmp     byte [r8 + 3], 'n'
    jne     .false
.keyword_boundary:
    mov     r9, r8
    cmp     r9, rsi
    jbe     .true
    dec     r9
    movzx   edx, byte [r9]
    cmp     dl, 'A'
    jb      .true
    cmp     dl, 'Z'
    jbe     .false
    cmp     dl, 'a'
    jb      .true
    cmp     dl, 'z'
    jbe     .false
.true:
    mov     eax, 1
    ret
.false:
    xor     eax, eax
    ret

; _er_tsx_source_context_allows_regex(cursor=rdi, source_start=rsi)
; Regex literals use expression-start contexts, but not TSX statement boundaries.
er_fn _er_tsx_source_context_allows_regex
    call    _er_tsx_source_context_allows_root
    test    eax, eax
    jz      .false
    mov     rax, rdi
.back_ws:
    cmp     rax, rsi
    jbe     .true
    dec     rax
    movzx   edx, byte [rax]
    cmp     dl, ' '
    je      .back_ws
    cmp     dl, 9
    je      .back_ws
    cmp     dl, 10
    je      .back_ws
    cmp     dl, 13
    je      .back_ws
    cmp     dl, '}'
    je      .false
.true:
    mov     eax, 1
    ret
.false:
    xor     eax, eax
    ret

; _er_tsx_skip_quoted_source(cursor=rdi, end=rsi)
; Returns rax=after closing quote, rdx=0.
er_fn _er_tsx_skip_quoted_source
    mov     rax, rdi
    cmp     rax, rsi
    jae     .bad
    movzx   ecx, byte [rax]
    inc     rax
.loop:
    cmp     rax, rsi
    jae     .bad
    movzx   edx, byte [rax]
    cmp     dl, '\'
    je      .escape
    cmp     dl, cl
    je      .done
    inc     rax
    jmp     .loop
.escape:
    inc     rax
    cmp     rax, rsi
    jae     .bad
    inc     rax
    jmp     .loop
.done:
    inc     rax
    xor     edx, edx
    ret
.bad:
    xor     eax, eax
    mov     edx, ERROR_PARSE
    ret

; _er_tsx_skip_quoted_attr(cursor=rdi, end=rsi)
; Returns rax=after closing quote, validating text entities inside the value.
er_fn _er_tsx_skip_quoted_attr
    push    rbx
    push    r12
    push    r13
    mov     rbx, rdi
    mov     r12, rsi
    cmp     rbx, r12
    jae     .bad
    movzx   r13d, byte [rbx]
    inc     rbx
.loop:
    cmp     rbx, r12
    jae     .bad
    movzx   edx, byte [rbx]
    cmp     dl, '\'
    je      .escape
    cmp     dl, '&'
    je      .entity
    cmp     dl, r13b
    je      .done
    inc     rbx
    jmp     .loop
.escape:
    inc     rbx
    cmp     rbx, r12
    jae     .bad
    inc     rbx
    jmp     .loop
.entity:
    mov     rdi, rbx
    mov     rsi, r12
    call    _er_tsx_skip_entity
    test    rdx, rdx
    jnz     .bad
    mov     rbx, rax
    jmp     .loop
.done:
    lea     rax, [rbx + 1]
    xor     edx, edx
    pop     r13
    pop     r12
    pop     rbx
    ret
.bad:
    xor     eax, eax
    mov     edx, ERROR_PARSE
    pop     r13
    pop     r12
    pop     rbx
    ret

; _er_tsx_skip_trailing_assertions(cursor=rdi, end=rsi)
; Skips trailing "as Type" and "satisfies Type" expression assertions.
er_fn _er_tsx_skip_trailing_assertions
    push    rbx
    push    r12
    mov     rbx, rdi
    mov     r12, rsi
.loop:
    mov     rdi, rbx
    mov     rsi, r12
    call    _er_wasmc_skip_ws
    mov     rbx, rax
    cmp     rbx, r12
    jae     .success
    cmp     byte [rbx], '!'
    jne     .keyword_probe
    inc     rbx
    jmp     .loop
.keyword_probe:
    lea     r9, [rbx + 2]
    cmp     r9, r12
    ja      .success
    cmp     byte [rbx], 'a'
    jne     .try_satisfies
    cmp     byte [rbx + 1], 's'
    jne     .success
    mov     rbx, r9
    jmp     .keyword_done
.try_satisfies:
    lea     r9, [rbx + 9]
    cmp     r9, r12
    ja      .success
    cmp     byte [rbx], 's'
    jne     .success
    cmp     byte [rbx + 1], 'a'
    jne     .success
    cmp     byte [rbx + 2], 't'
    jne     .success
    cmp     byte [rbx + 3], 'i'
    jne     .success
    cmp     byte [rbx + 4], 's'
    jne     .success
    cmp     byte [rbx + 5], 'f'
    jne     .success
    cmp     byte [rbx + 6], 'i'
    jne     .success
    cmp     byte [rbx + 7], 'e'
    jne     .success
    cmp     byte [rbx + 8], 's'
    jne     .success
    mov     rbx, r9
.keyword_done:
    cmp     rbx, r12
    jae     .bad
    movzx   eax, byte [rbx]
    call    _er_tsx_is_name_continue
    test    eax, eax
    jnz     .success
    mov     rdi, rbx
    mov     rsi, r12
    call    _er_tsx_skip_trailing_type_expr
    test    rdx, rdx
    jnz     .bad
    mov     rbx, rax
    jmp     .loop
.success:
    mov     rax, rbx
    xor     edx, edx
    pop     r12
    pop     rbx
    ret
.bad:
    xor     eax, eax
    mov     edx, ERROR_PARSE
    pop     r12
    pop     rbx
    ret

; _er_tsx_skip_trailing_type_expr(cursor=rdi, end=rsi)
; Returns before enclosing ")" / ";" / EOF after an assertion type.
er_fn _er_tsx_skip_trailing_type_expr
    push    rbx
    push    r12
    push    r13
    push    r14
    mov     rbx, rdi
    mov     r12, rsi
    xor     r13d, r13d
    xor     r14d, r14d
    mov     rdi, rbx
    mov     rsi, r12
    call    _er_wasmc_skip_ws
    mov     rbx, rax
    cmp     rbx, r12
    jae     .bad
.loop:
    cmp     rbx, r12
    jae     .success
    movzx   eax, byte [rbx]
    cmp     al, '"'
    je      .quoted
    cmp     al, 39
    je      .quoted
    cmp     al, '`'
    je      .quoted
    cmp     al, '{'
    je      .braced
    cmp     al, '/'
    je      .slash
    cmp     al, '<'
    je      .angle_inc
    cmp     al, '>'
    je      .angle_dec
    cmp     al, '('
    je      .paren_inc
    cmp     al, ')'
    je      .maybe_done_paren
    cmp     al, ';'
    je      .maybe_done_semicolon
    inc     rbx
    jmp     .loop
.quoted:
    mov     rdi, rbx
    mov     rsi, r12
    call    _er_tsx_skip_quoted_source
    test    rdx, rdx
    jnz     .bad
    mov     rbx, rax
    jmp     .loop
.braced:
    mov     rdi, rbx
    mov     rsi, r12
    call    _er_tsx_skip_balanced_braces
    test    rdx, rdx
    jnz     .bad
    mov     rbx, rax
    jmp     .loop
.slash:
    lea     r9, [rbx + 1]
    cmp     r9, r12
    jae     .bad
    cmp     byte [r9], '/'
    je      .line_comment
    cmp     byte [r9], '*'
    je      .block_comment
    inc     rbx
    jmp     .loop
.line_comment:
    lea     rbx, [rbx + 2]
.line_loop:
    cmp     rbx, r12
    jae     .success
    movzx   eax, byte [rbx]
    cmp     al, 10
    je      .success
    cmp     al, 13
    je      .success
    inc     rbx
    jmp     .line_loop
.block_comment:
    lea     rbx, [rbx + 2]
.block_loop:
    lea     r9, [rbx + 1]
    cmp     r9, r12
    jae     .bad
    cmp     byte [rbx], '*'
    jne     .block_next
    cmp     byte [r9], '/'
    je      .block_done
.block_next:
    inc     rbx
    jmp     .block_loop
.block_done:
    lea     rbx, [rbx + 2]
    jmp     .loop
.angle_inc:
    inc     r13
    inc     rbx
    jmp     .loop
.angle_dec:
    test    r13, r13
    jz      .advance
    cmp     byte [rbx - 1], '='
    je      .advance
    dec     r13
.advance:
    inc     rbx
    jmp     .loop
.paren_inc:
    inc     r14
    inc     rbx
    jmp     .loop
.maybe_done_paren:
    test    r13, r13
    jnz     .advance
    test    r14, r14
    jz      .success
    dec     r14
    inc     rbx
    jmp     .loop
.maybe_done_semicolon:
    test    r13, r13
    jnz     .advance
    test    r14, r14
    jz      .success
    inc     rbx
    jmp     .loop
.success:
    mov     rax, rbx
    xor     edx, edx
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret
.bad:
    xor     eax, eax
    mov     edx, ERROR_PARSE
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

; _er_tsx_scan_template_source(cursor=rdi, end=rsi)
; Returns rax=after template, rcx/r8/r9/r10=roots/elements/attrs/text, rdx=0.
er_fn _er_tsx_scan_template_source
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 24
    mov     qword [rsp], 0
    mov     qword [rsp + 8], 0
    mov     qword [rsp + 16], 0
    mov     rbx, rdi
    mov     r12, rsi
    xor     r13d, r13d
    xor     r14d, r14d
    xor     r15d, r15d
    cmp     rbx, r12
    jae     .bad
    cmp     byte [rbx], '`'
    jne     .bad
    inc     rbx
.loop:
    cmp     rbx, r12
    jae     .bad
    movzx   edx, byte [rbx]
    cmp     dl, '\'
    je      .escape
    cmp     dl, '`'
    je      .done
    cmp     dl, '$'
    je      .maybe_expr
    inc     rbx
    jmp     .loop
.escape:
    inc     rbx
    cmp     rbx, r12
    jae     .bad
    inc     rbx
    jmp     .loop
.maybe_expr:
    lea     r11, [rbx + 1]
    cmp     r11, r12
    jae     .bad
    cmp     byte [r11], '{'
    jne     .advance
    lea     rax, [r11 + 1]
    mov     [rsp + 16], rax
    mov     rdi, r11
    mov     rsi, r12
    call    _er_tsx_skip_balanced_braces
    test    rdx, rdx
    jnz     .bad
    mov     [rsp + 8], rax
    mov     rdi, [rsp + 16]
    mov     rsi, rax
    dec     rsi
    sub     rsi, rdi
    jbe     .expr_done
    call    er_wasmc_scan_tsx_source
    test    rdx, rdx
    jnz     .bad
    add     r13, rax
    add     r14, rcx
    add     r15, r8
    add     [rsp], r9
.expr_done:
    mov     rbx, [rsp + 8]
    jmp     .loop
.advance:
    inc     rbx
    jmp     .loop
.done:
    inc     rbx
    mov     rax, rbx
    mov     rcx, r13
    mov     r8, r14
    mov     r9, r15
    mov     r10, [rsp]
    xor     edx, edx
    jmp     .ret
.bad:
    xor     eax, eax
    xor     ecx, ecx
    xor     r8d, r8d
    xor     r9d, r9d
    xor     r10d, r10d
    mov     edx, ERROR_PARSE
.ret:
    add     rsp, 24
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

; _er_tsx_scan_template_tree(cursor=rdi, end=rsi, nodes=rdx,
;                            node_cap=rcx, parent_index=r8, base_index=r9)
; Returns rax=after template, rcx=elements, r8=attrs, r9=text, rdx=0/error.
er_fn _er_tsx_scan_template_tree
    er_frame_push
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 96

    mov     rbx, rdi
    mov     r12, rsi
    mov     [rbp - 56], rdx
    mov     [rbp - 64], rcx
    mov     [rbp - 72], r8
    mov     [rbp - 80], r9
    xor     r13d, r13d
    xor     r14d, r14d
    xor     r15d, r15d
    mov     qword [rbp - 88], 0
    cmp     rbx, r12
    jae     .bad
    cmp     byte [rbx], '`'
    jne     .bad
    inc     rbx
.loop:
    cmp     rbx, r12
    jae     .bad
    movzx   edx, byte [rbx]
    cmp     dl, '\'
    je      .escape
    cmp     dl, '`'
    je      .done
    cmp     dl, '$'
    je      .maybe_expr
    inc     rbx
    jmp     .loop
.escape:
    inc     rbx
    cmp     rbx, r12
    jae     .bad
    inc     rbx
    jmp     .loop
.maybe_expr:
    lea     r11, [rbx + 1]
    cmp     r11, r12
    jae     .bad
    cmp     byte [r11], '{'
    jne     .advance
    lea     rax, [r11 + 1]
    mov     [rbp - 96], rax
    mov     rdi, r11
    mov     rsi, r12
    call    _er_tsx_skip_balanced_braces
    test    rdx, rdx
    jnz     .bad
    mov     [rbp - 88], rax
    mov     rdi, [rbp - 96]
    mov     rsi, rax
    dec     rsi
    mov     rdx, [rbp - 56]
    mov     rcx, [rbp - 64]
    mov     r8, [rbp - 72]
    mov     r9, [rbp - 80]
    add     r9, r13
    call    _er_tsx_scan_inner_tree
    test    rdx, rdx
    jnz     .inner_error
    add     r13, rax
    add     r14, rcx
    add     r15, r8
    mov     rbx, [rbp - 88]
    jmp     .loop
.advance:
    inc     rbx
    jmp     .loop
.done:
    inc     rbx
    mov     rax, rbx
    mov     rcx, r13
    mov     r8, r14
    mov     r9, r15
    xor     edx, edx
    jmp     .ret
.inner_error:
    xor     eax, eax
    xor     ecx, ecx
    xor     r8d, r8d
    xor     r9d, r9d
    jmp     .ret
.bad:
    xor     eax, eax
    xor     ecx, ecx
    xor     r8d, r8d
    xor     r9d, r9d
    mov     edx, ERROR_PARSE
.ret:
    add     rsp, 96
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; _er_tsx_skip_regex_source(cursor=rdi, end=rsi)
; Returns rax=after regex literal and flags, rdx=0.
er_fn _er_tsx_skip_regex_source
    mov     rax, rdi
    cmp     rax, rsi
    jae     .bad
    cmp     byte [rax], '/'
    jne     .bad
    inc     rax
    xor     r8d, r8d
.loop:
    cmp     rax, rsi
    jae     .bad
    movzx   edx, byte [rax]
    cmp     dl, '\'
    je      .escape
    cmp     dl, 10
    je      .bad
    cmp     dl, 13
    je      .bad
    cmp     dl, '['
    je      .class_open
    cmp     dl, ']'
    je      .class_close
    cmp     dl, '/'
    je      .maybe_done
    inc     rax
    jmp     .loop
.escape:
    inc     rax
    cmp     rax, rsi
    jae     .bad
    inc     rax
    jmp     .loop
.class_open:
    mov     r8d, 1
    inc     rax
    jmp     .loop
.class_close:
    xor     r8d, r8d
    inc     rax
    jmp     .loop
.maybe_done:
    test    r8d, r8d
    jnz     .regex_slash
.done:
    inc     rax
.flag_loop:
    cmp     rax, rsi
    jae     .ok
    movzx   edx, byte [rax]
    cmp     dl, 'A'
    jb      .ok
    cmp     dl, 'Z'
    jbe     .flag_next
    cmp     dl, 'a'
    jb      .ok
    cmp     dl, 'z'
    ja      .ok
.flag_next:
    inc     rax
    jmp     .flag_loop
.ok:
    xor     edx, edx
    ret
.regex_slash:
    inc     rax
    jmp     .loop
.bad:
    xor     eax, eax
    mov     edx, ERROR_PARSE
    ret

; _er_tsx_skip_type_args(cursor=rdi, end=rsi)
; Returns rax=after matching generic tag type arguments, rdx=0.
er_fn _er_tsx_skip_type_args
    push    rbx
    push    r12
    push    r13
    mov     rbx, rdi
    mov     r12, rsi
    cmp     rbx, r12
    jae     .bad
    cmp     byte [rbx], '<'
    jne     .bad
    mov     r13d, 1
    inc     rbx
.loop:
    cmp     rbx, r12
    jae     .bad
    movzx   edx, byte [rbx]
    cmp     dl, '"'
    je      .quoted
    cmp     dl, 39
    je      .quoted
    cmp     dl, '`'
    je      .quoted
    cmp     dl, '{'
    je      .braced
    cmp     dl, '/'
    je      .slash
    cmp     dl, '<'
    je      .inc_depth
    cmp     dl, '>'
    je      .maybe_close
    inc     rbx
    jmp     .loop
.quoted:
    mov     rdi, rbx
    mov     rsi, r12
    call    _er_tsx_skip_quoted_source
    test    rdx, rdx
    jnz     .bad
    mov     rbx, rax
    jmp     .loop
.braced:
    mov     rdi, rbx
    mov     rsi, r12
    call    _er_tsx_skip_balanced_braces
    test    rdx, rdx
    jnz     .bad
    mov     rbx, rax
    jmp     .loop
.slash:
    lea     r9, [rbx + 1]
    cmp     r9, r12
    jae     .bad
    cmp     byte [r9], '/'
    je      .line_comment
    cmp     byte [r9], '*'
    je      .block_comment
    inc     rbx
    jmp     .loop
.line_comment:
    lea     rbx, [rbx + 2]
.line_comment_loop:
    cmp     rbx, r12
    jae     .bad
    movzx   edx, byte [rbx]
    cmp     dl, 10
    je      .line_comment_done
    cmp     dl, 13
    je      .line_comment_done
    inc     rbx
    jmp     .line_comment_loop
.line_comment_done:
    inc     rbx
    jmp     .loop
.block_comment:
    lea     rbx, [rbx + 2]
.block_comment_loop:
    lea     r9, [rbx + 1]
    cmp     r9, r12
    jae     .bad
    cmp     byte [rbx], '*'
    jne     .block_comment_next
    cmp     byte [r9], '/'
    je      .block_comment_done
.block_comment_next:
    inc     rbx
    jmp     .block_comment_loop
.block_comment_done:
    lea     rbx, [rbx + 2]
    jmp     .loop
.inc_depth:
    inc     r13
    inc     rbx
    jmp     .loop
.maybe_close:
    cmp     byte [rbx - 1], '='
    je      .advance
    dec     r13
    inc     rbx
    test    r13, r13
    jnz     .loop
    mov     rax, rbx
    xor     edx, edx
    pop     r13
    pop     r12
    pop     rbx
    ret
.advance:
    inc     rbx
    jmp     .loop
.bad:
    xor     eax, eax
    mov     edx, ERROR_PARSE
    pop     r13
    pop     r12
    pop     rbx
    ret

; _er_tsx_name_is_raw(name=rdi, name_len=rsi) -> eax=1 for raw-text tags.
er_fn _er_tsx_name_is_raw
    cmp     rsi, 6
    je      .try_script
    cmp     rsi, 5
    je      .try_style
    xor     eax, eax
    ret
.try_script:
    cmp     byte [rdi], 's'
    jne     .false
    cmp     byte [rdi + 1], 'c'
    jne     .false
    cmp     byte [rdi + 2], 'r'
    jne     .false
    cmp     byte [rdi + 3], 'i'
    jne     .false
    cmp     byte [rdi + 4], 'p'
    jne     .false
    cmp     byte [rdi + 5], 't'
    jne     .false
    mov     eax, 1
    ret
.try_style:
    cmp     byte [rdi], 's'
    jne     .false
    cmp     byte [rdi + 1], 't'
    jne     .false
    cmp     byte [rdi + 2], 'y'
    jne     .false
    cmp     byte [rdi + 3], 'l'
    jne     .false
    cmp     byte [rdi + 4], 'e'
    jne     .false
    mov     eax, 1
    ret
.false:
    xor     eax, eax
    ret

; _er_tsx_scan_raw_close(cursor=rdi, end=rsi, name=rdx, name_len=rcx)
; Returns rax=after_close_gt, r8=has_non_ws_text, rdx=0.
er_fn _er_tsx_scan_raw_close
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    mov     rbx, rdi
    mov     r12, rsi
    mov     r13, rdx
    mov     r14, rcx
    xor     r15d, r15d
.scan_loop:
    cmp     rbx, r12
    jae     .bad
    cmp     byte [rbx], '<'
    je      .maybe_close
    movzx   eax, byte [rbx]
    cmp     al, ' '
    je      .advance
    cmp     al, 9
    je      .advance
    cmp     al, 10
    je      .advance
    cmp     al, 13
    je      .advance
    mov     r15d, 1
.advance:
    inc     rbx
    jmp     .scan_loop
.maybe_close:
    lea     r9, [rbx + 1]
    cmp     r9, r12
    jae     .bad
    cmp     byte [r9], '/'
    jne     .not_close
    lea     r9, [rbx + 2]
    mov     r10, r14
    mov     r11, r13
.name_loop:
    test    r10, r10
    jz      .name_done
    cmp     r9, r12
    jae     .bad
    mov     al, [r9]
    cmp     al, [r11]
    jne     .not_close
    inc     r9
    inc     r11
    dec     r10
    jmp     .name_loop
.name_done:
    mov     rdi, r9
    mov     rsi, r12
    call    _er_wasmc_skip_ws
    cmp     rax, r12
    jae     .bad
    cmp     byte [rax], '>'
    jne     .not_close
    inc     rax
    mov     r8, r15
    xor     edx, edx
    jmp     .done
.not_close:
    mov     r15d, 1
    inc     rbx
    jmp     .scan_loop
.bad:
    xor     eax, eax
    xor     r8d, r8d
    mov     edx, ERROR_PARSE
.done:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

; _er_tsx_skip_balanced_braces(cursor=rdi, end=rsi)
; Returns rax=cursor_after_balanced_expression, rdx=0.
er_fn _er_tsx_skip_balanced_braces
    push    rbx
    push    r12
    push    r13
    push    r14
    mov     rbx, rdi
    mov     r12, rsi
    mov     r14, rdi
    cmp     rbx, r12
    jae     .bad
    cmp     byte [rbx], '{'
    jne     .bad
    mov     r13d, 1
    inc     rbx
.loop:
    cmp     rbx, r12
    jae     .bad
    movzx   eax, byte [rbx]
    cmp     al, '{'
    je      .inc_depth
    cmp     al, '}'
    je      .dec_depth
    cmp     al, '"'
    je      .quoted
    cmp     al, 39
    je      .quoted
    cmp     al, '`'
    je      .quoted
    cmp     al, '/'
    je      .slash
    inc     rbx
    jmp     .loop
.inc_depth:
    inc     r13
    inc     rbx
    jmp     .loop
.dec_depth:
    dec     r13
    inc     rbx
    test    r13, r13
    jnz     .loop
    mov     rax, rbx
    xor     edx, edx
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret
.quoted:
    mov     rdi, rbx
    mov     rsi, r12
    call    _er_tsx_skip_quoted_source
    test    rdx, rdx
    jnz     .bad
    mov     rbx, rax
    jmp     .loop
.slash:
    lea     r9, [rbx + 1]
    cmp     r9, r12
    jae     .bad
    cmp     byte [r9], '/'
    je      .line_comment
    cmp     byte [r9], '*'
    je      .block_comment
    mov     rdi, rbx
    mov     rsi, r14
    call    _er_tsx_source_context_allows_regex
    test    eax, eax
    jz      .slash_advance
    mov     rdi, rbx
    mov     rsi, r12
    call    _er_tsx_skip_regex_source
    test    rdx, rdx
    jnz     .bad
    mov     rbx, rax
    jmp     .loop
.slash_advance:
    inc     rbx
    jmp     .loop
.line_comment:
    lea     rbx, [rbx + 2]
.line_comment_loop:
    cmp     rbx, r12
    jae     .bad
    movzx   eax, byte [rbx]
    cmp     al, 10
    je      .line_comment_done
    cmp     al, 13
    je      .line_comment_done
    inc     rbx
    jmp     .line_comment_loop
.line_comment_done:
    inc     rbx
    jmp     .loop
.block_comment:
    lea     rbx, [rbx + 2]
.block_comment_loop:
    lea     r9, [rbx + 1]
    cmp     r9, r12
    jae     .bad
    cmp     byte [rbx], '*'
    jne     .block_comment_next
    cmp     byte [r9], '/'
    je      .block_comment_done
.block_comment_next:
    inc     rbx
    jmp     .block_comment_loop
.block_comment_done:
    lea     rbx, [rbx + 2]
    jmp     .loop
.bad:
    xor     eax, eax
    mov     edx, ERROR_PARSE
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret
