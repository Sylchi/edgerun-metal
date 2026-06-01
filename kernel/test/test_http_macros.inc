; EdgeRun HTTP self-hosted test macros.
; The including test provides puts, print_dec, shared pass/fail counters, and
; the s_* labels used for printed diagnostics.

; test_status(name_str, buf, len, expected)
%macro test_status 4
    lea     rdi, [rel %2]
    mov     esi, %3
    call    er_http_parse_status
    mov     r14d, eax

    lea     rsi, [rel %1]
    call    puts
    lea     rsi, [rel s_colon]
    call    puts

    cmp     r14d, %4
    jne     %%fail

    lea     rsi, [rel s_pass]
    call    puts
    lea     rsi, [rel s_nl]
    call    puts
    jmp     %%pass

%%fail:
    lea     rsi, [rel s_fail]
    call    puts
    lea     rsi, [rel s_sp_colon]
    call    puts
    mov     eax, %4
    call    print_dec
    lea     rsi, [rel s_sp_bang_sp]
    call    puts
    mov     eax, r14d
    call    print_dec
    lea     rsi, [rel s_nl]
    call    puts
    inc     qword [rel failed]
    jmp     %%done
%%pass:
    inc     qword [rel passed]
%%done:
%endmacro

; test_ptr(name_str, buf, len, expect_nonnull)
%macro test_ptr 4
    lea     rdi, [rel %2]
    mov     esi, %3
    call    er_http_find_body
    mov     r14, rax

    lea     rsi, [rel %1]
    call    puts
    lea     rsi, [rel s_colon]
    call    puts

    test    r14, r14
    setnz   al
    movzx   eax, al
    cmp     eax, %4
    jne     %%fail

    lea     rsi, [rel s_pass]
    call    puts
    lea     rsi, [rel s_nl]
    call    puts
    jmp     %%pass

%%fail:
    lea     rsi, [rel s_fail]
    call    puts
    lea     rsi, [rel s_sp_colon]
    call    puts
    mov     eax, %4
    call    print_dec
    lea     rsi, [rel s_sp_bang_sp]
    call    puts
    mov     eax, r14d
    call    print_dec
    lea     rsi, [rel s_nl]
    call    puts
    inc     qword [rel failed]
    jmp     %%done
%%pass:
    inc     qword [rel passed]
%%done:
%endmacro

; test_is_sse(name_str, buf, len, expected)
%macro test_is_sse 4
    lea     rdi, [rel %2]
    mov     esi, %3
    call    er_http_is_sse
    mov     r14d, eax

    lea     rsi, [rel %1]
    call    puts
    lea     rsi, [rel s_colon]
    call    puts

    cmp     r14d, %4
    jne     %%fail

    lea     rsi, [rel s_pass]
    call    puts
    lea     rsi, [rel s_nl]
    call    puts
    jmp     %%pass

%%fail:
    lea     rsi, [rel s_fail]
    call    puts
    lea     rsi, [rel s_sp_colon]
    call    puts
    mov     eax, %4
    call    print_dec
    lea     rsi, [rel s_sp_bang_sp]
    call    puts
    mov     eax, r14d
    call    print_dec
    lea     rsi, [rel s_nl]
    call    puts
    inc     qword [rel failed]
    jmp     %%done
%%pass:
    inc     qword [rel passed]
%%done:
%endmacro

; test_sse_event(name_str, body, len, offset, exp_data_len, exp_retry)
%macro test_sse_event 6
    sub     rsp, SSE_EVENT_SIZE

    lea     rdi, [rel %2]
    mov     esi, %3
    mov     edx, %4
    mov     rcx, rsp
    call    er_http_sse_parse_event

    lea     rsi, [rel %1]
    call    puts
    lea     rsi, [rel s_colon]
    call    puts

    mov     eax, [rsp + SSE_EVENT_DATA_LEN]
    cmp     eax, %5
    jne     %%fail

    mov     eax, [rsp + SSE_EVENT_RETRY]
    cmp     eax, %6
    jne     %%fail

    lea     rsi, [rel s_pass]
    call    puts
    lea     rsi, [rel s_nl]
    call    puts
    add     rsp, SSE_EVENT_SIZE
    inc     qword [rel passed]
    jmp     %%done

%%fail:
    lea     rsi, [rel s_fail]
    call    puts
    lea     rsi, [rel s_nl]
    call    puts
    add     rsp, SSE_EVENT_SIZE
    inc     qword [rel failed]
%%done:
%endmacro

; test_sse_ptr(name_str, body, len, offset, field_offs, exp_nonnull)
%macro test_sse_ptr 6
    sub     rsp, SSE_EVENT_SIZE

    lea     rdi, [rel %2]
    mov     esi, %3
    mov     edx, %4
    mov     rcx, rsp
    call    er_http_sse_parse_event

    lea     rsi, [rel %1]
    call    puts
    lea     rsi, [rel s_colon]
    call    puts

    mov     rax, [rsp + %5]
    test    rax, rax
    setnz   al
    movzx   eax, al
    cmp     eax, %6
    jne     %%fail

    lea     rsi, [rel s_pass]
    call    puts
    lea     rsi, [rel s_nl]
    call    puts
    add     rsp, SSE_EVENT_SIZE
    inc     qword [rel passed]
    jmp     %%done

%%fail:
    lea     rsi, [rel s_fail]
    call    puts
    lea     rsi, [rel s_nl]
    call    puts
    add     rsp, SSE_EVENT_SIZE
    inc     qword [rel failed]
%%done:
%endmacro

; test_cl(name_str, buf, len, expected)
%macro test_cl 4
    lea     rdi, [rel %2]
    mov     esi, %3
    call    er_http_find_content_length
    mov     r14d, eax

    lea     rsi, [rel %1]
    call    puts
    lea     rsi, [rel s_colon]
    call    puts

    cmp     r14d, %4
    jne     %%fail

    lea     rsi, [rel s_pass]
    call    puts
    lea     rsi, [rel s_nl]
    call    puts
    jmp     %%pass

%%fail:
    lea     rsi, [rel s_fail]
    call    puts
    lea     rsi, [rel s_sp_colon]
    call    puts
    mov     eax, %4
    call    print_dec
    lea     rsi, [rel s_sp_bang_sp]
    call    puts
    mov     eax, r14d
    call    print_dec
    lea     rsi, [rel s_nl]
    call    puts
    inc     qword [rel failed]
    jmp     %%done
%%pass:
    inc     qword [rel passed]
%%done:
%endmacro
