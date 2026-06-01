er_fn is_directive
    er_push rbx, r12
    mov     rbx, rdi
    mov     r12, rsi
%macro CHECK_DIR 2
    mov     rdi, rbx
    mov     rsi, r12
    lea     rdx, [rel %1]
    mov     ecx, %2
    call    token_eq
    test    eax, eax
    jnz     .yes
%endmacro
    CHECK_DIR tok_section, tok_section_len
    CHECK_DIR tok_global, tok_global_len
    CHECK_DIR tok_extern, tok_extern_len
    CHECK_DIR tok_default, tok_default_len
    CHECK_DIR tok_bits, tok_bits_len
    CHECK_DIR tok_db, tok_db_len
    CHECK_DIR tok_dw, tok_dw_len
    CHECK_DIR tok_dd, tok_dd_len
    CHECK_DIR tok_dq, tok_dq_len
    CHECK_DIR tok_resb, tok_resb_len
    CHECK_DIR tok_resw, tok_resw_len
    CHECK_DIR tok_resd, tok_resd_len
    CHECK_DIR tok_resq, tok_resq_len
    CHECK_DIR tok_times, tok_times_len
    CHECK_DIR tok_align, tok_align_len
    CHECK_DIR tok_incbin, tok_incbin_len
    CHECK_DIR tok_equ, tok_equ_len
    xor     eax, eax
    jmp     .done
.yes:
    mov     eax, 1
.done:
    er_pop  rbx, r12
    ret

; token_eq(token, len, str, str_len) -> eax=1/0
er_fn token_eq
    cmp     rsi, rcx
    jne     .no
    xor     r8d, r8d
.loop:
    cmp     r8, rsi
    jae     .yes
    movzx   eax, byte [rdi + r8]
    movzx   r9d, byte [rdx + r8]
    cmp     al, 'A'
    jb      .cmp
    cmp     al, 'Z'
    ja      .cmp
    add     al, 32
.cmp:
    cmp     r9b, 'A'
    jb      .cmp_folded
    cmp     r9b, 'Z'
    ja      .cmp_folded
    add     r9b, 32
.cmp_folded:
    cmp     al, r9b
    jne     .no
    inc     r8
    jmp     .loop
.yes:
    mov     eax, 1
    ret
.no:
    xor     eax, eax
    ret

er_fn print_report
    lea     rdi, [rel key_magic]
    call    write_report_cstr
    lea     rdi, [rel key_lines]
    mov     rsi, [rel line_count]
    call    print_kv
    lea     rdi, [rel key_preproc]
    mov     rsi, [rel preproc_count]
    call    print_kv
    lea     rdi, [rel key_directives]
    mov     rsi, [rel directive_count]
    call    print_kv
    lea     rdi, [rel key_labels]
    mov     rsi, [rel label_count]
    call    print_kv
    lea     rdi, [rel key_instructions]
    mov     rsi, [rel instr_count]
    call    print_kv
    lea     rdi, [rel key_text_len]
    mov     rsi, [rel text_len]
    call    print_kv
    lea     rdi, [rel key_exit_step]
    mov     rsi, [rel exit_instr_step]
    call    print_kv
    lea     rdi, [rel key_exit_bad]
    mov     rsi, [rel exit_subset_bad]
    call    print_kv
    lea     rdi, [rel key_generic_mode]
    mov     rsi, [rel generic_instr_mode]
    call    print_kv
    lea     rdi, [rel key_generic_bad]
    mov     rsi, [rel generic_instr_bad]
    call    print_kv
    lea     rdi, [rel key_globals]
    mov     rsi, [rel global_count]
    call    print_kv
    lea     rdi, [rel key_pending_globals]
    mov     rsi, [rel pending_global_count]
    call    print_kv
    lea     rdi, [rel key_pending_branches]
    mov     rsi, [rel pending_branch_count]
    call    print_kv
    lea     rdi, [rel key_pending_calls]
    mov     rsi, [rel pending_call_count]
    call    print_kv
    lea     rdi, [rel key_equ_seen]
    mov     rsi, [rel equ_count]
    call    print_kv
    ret

; print_kv(cstr, value)
er_fn print_kv
    er_push r12, r13
    mov     r12, rdi
    mov     r13, rsi
    mov     rdi, r12
    call    write_report_cstr
    lea     rdi, [rel tab_str]
    call    write_report_cstr
    mov     rdi, r13
    call    print_u64
    lea     rdi, [rel nl_str]
    call    write_report_cstr
    er_pop  r12, r13
    ret

er_fn print_u64
    lea     rsi, [rel num_buf + 31]
    mov     byte [rsi], 0
    mov     rax, rdi
    mov     ecx, 10
.loop:
    xor     edx, edx
    div     rcx
    add     dl, '0'
    dec     rsi
    mov     [rsi], dl
    test    rax, rax
    jnz     .loop
    mov     rdi, rsi
    jmp     write_report_cstr

er_fn write_report_cstr
    mov     esi, [rel report_fd]
    jmp     write_cstr_fd

er_fn streq
    xor     ecx, ecx
.loop:
    movzx   eax, byte [rdi + rcx]
    movzx   edx, byte [rsi + rcx]
    cmp     al, dl
    jne     .no
    test    al, al
    jz      .yes
    inc     rcx
    jmp     .loop
.yes:
    mov     eax, 1
    ret
.no:
    xor     eax, eax
    ret

er_fn write_stderr
    mov     esi, STDERR_FD
    jmp     write_cstr_fd

; write_cstr_fd(cstr, fd)
er_fn write_cstr_fd
    er_push rbx, r12
    mov     r12, rdi
    xor     edx, edx
.len:
    cmp     byte [r12 + rdx], 0
    je      .write
    inc     rdx
    jmp     .len
.write:
    mov     ebx, esi
    mov     edi, ebx
    mov     rsi, r12
    mov     eax, SYS_write
    syscall
    er_pop  rbx, r12
    ret

er_fn exit_now
    mov     eax, SYS_exit_group
    syscall
