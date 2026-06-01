; EdgeRun HTTP self-hosted test suite
; Tests er_http_parse_status, er_http_find_body, er_http_find_content_length
; Uses inlined test blocks (no abstraction) to avoid register-clobber bugs from syscall.

%include "x86_64/macros.inc"

extern er_http_parse_status
extern er_http_find_body
extern er_http_find_content_length
extern er_http_is_sse
extern er_http_sse_parse_event

%include "x86_64/net/http_constants.inc"
%include "test/test_macros.inc"
%include "test/test_http_macros.inc"

TEST_DATA_PASSED_FAILED
hex_chars: db "0123456789ABCDEF"
nl_buf:    db 0x0A
sp_buf:    db ' '

SECTION .rodata

; --- Status parse test responses ---
resp_200:
    db "HTTP/1.1 200 OK", 0x0D, 0x0A, 0x0D, 0x0A, "body"
resp_200_len equ $ - resp_200

resp_404:
    db "HTTP/1.1 404 Not Found", 0x0D, 0x0A, 0x0D, 0x0A, "body"
resp_404_len equ $ - resp_404

resp_301:
    db "HTTP/1.1 301 Moved", 0x0D, 0x0A, 0x0D, 0x0A, "body"
resp_301_len equ $ - resp_301

resp_500:
    db "HTTP/1.1 500 Internal", 0x0D, 0x0A, 0x0D, 0x0A, "body"
resp_500_len equ $ - resp_500

resp_no_space:
    db "HTTP/1.1", 0x0D, 0x0A
resp_no_space_len equ $ - resp_no_space

resp_empty:
    db ""
resp_empty_len equ $ - resp_empty

resp_no_status:
    db "HTTP/1.1 ", 0x0D, 0x0A, 0x0D, 0x0A, "body"
resp_no_status_len equ $ - resp_no_status

resp_bad_digit:
    db "HTTP/1.1 xxx", 0x0D, 0x0A, 0x0D, 0x0A, "body"
resp_bad_digit_len equ $ - resp_bad_digit

resp_truncated:
    db "HTTP/1.1 20"
resp_truncated_len equ $ - resp_truncated

; --- Body find ---
resp_body:
    db "HTTP/1.1 200 OK", 0x0D, 0x0A, 0x0D, 0x0A, "Hello, World!"
resp_body_len equ $ - resp_body

resp_no_body:
    db "HTTP/1.1 200 OK", 0x0D, 0x0A, "Content-Length: 5"
resp_no_body_len equ $ - resp_no_body

; --- Content-Length ---
resp_cl:
    db "HTTP/1.1 200 OK", 0x0D, 0x0A, "Content-Length: 13", 0x0D, 0x0A, 0x0D, 0x0A, "Hello, World!"
resp_cl_len equ $ - resp_cl

resp_cl_lower:
    db "HTTP/1.1 200 OK", 0x0D, 0x0A, "content-length: 5", 0x0D, 0x0A, 0x0D, 0x0A, "Hello"
resp_cl_lower_len equ $ - resp_cl_lower

resp_cl_mixed:
    db "HTTP/1.1 200 OK", 0x0D, 0x0A, "Content-length: 42", 0x0D, 0x0A, 0x0D, 0x0A, "x"
resp_cl_mixed_len equ $ - resp_cl_mixed

resp_no_cl:
    db "HTTP/1.1 200 OK", 0x0D, 0x0A, 0x0D, 0x0A, "Hello, World!"
resp_no_cl_len equ $ - resp_no_cl

; --- SSE test responses ---
resp_sse_ct:
    db "HTTP/1.1 200 OK", 0x0D, 0x0A
    db "Content-Type: text/event-stream", 0x0D, 0x0A
    db 0x0D, 0x0A
    db "data: hello", 0x0D, 0x0A
    db 0x0D, 0x0A
resp_sse_ct_len equ $ - resp_sse_ct

resp_sse_ct_lower:
    db "HTTP/1.1 200 OK", 0x0D, 0x0A
    db "content-type: text/event-stream", 0x0D, 0x0A
    db 0x0D, 0x0A
    db "data: hello", 0x0D, 0x0A
    db 0x0D, 0x0A
resp_sse_ct_lower_len equ $ - resp_sse_ct_lower

resp_html_ct:
    db "HTTP/1.1 200 OK", 0x0D, 0x0A
    db "Content-Type: text/html", 0x0D, 0x0A
    db 0x0D, 0x0A
    db "<html></html>"
resp_html_ct_len equ $ - resp_html_ct

resp_no_ct:
    db "HTTP/1.1 200 OK", 0x0D, 0x0A, 0x0D, 0x0A, "body"
resp_no_ct_len equ $ - resp_no_ct

; --- SSE body test data ---
sse_body_simple:
    db "data: hello", 0x0D, 0x0A
    db 0x0D, 0x0A
sse_body_simple_len equ $ - sse_body_simple

sse_body_multi:
    db "event: update", 0x0D, 0x0A
    db "data: payload", 0x0D, 0x0A
    db 0x0D, 0x0A
sse_body_multi_len equ $ - sse_body_multi

sse_body_comment:
    db ": ignore me", 0x0D, 0x0A
    db "data: val", 0x0D, 0x0A
    db 0x0D, 0x0A
sse_body_comment_len equ $ - sse_body_comment

sse_body_id:
    db "id: 42", 0x0D, 0x0A
    db "data: x", 0x0D, 0x0A
    db 0x0D, 0x0A
sse_body_id_len equ $ - sse_body_id

sse_body_retry:
    db "retry: 3000", 0x0D, 0x0A
    db "data: x", 0x0D, 0x0A
    db 0x0D, 0x0A
sse_body_retry_len equ $ - sse_body_retry

sse_body_empty:
    db 0x0D, 0x0A
sse_body_empty_len equ $ - sse_body_empty

; -------------------------------------------------------------------
; Helpers — all preserve rbx, r12-r15
; -------------------------------------------------------------------
SECTION .text

putchar:
    push    rdi
    mov     eax, 1
    mov     edi, 1
    lea     rsi, [rsp]
    mov     edx, 1
    syscall
    pop     rdi
    ret

puts:
    push    rbx
    mov     rbx, rsi
.l:
    cmp     byte [rbx], 0
    je      .d
    mov     dil, [rbx]
    call    putchar
    inc     rbx
    jmp     .l
.d:
    pop     rbx
    ret

print_hex_byte:
    push    rbx
    mov     ebx, eax
    shr     al, 4
    and     al, 0x0F
    movzx   eax, al
    mov     al, [rel hex_chars + rax]
    push    rax
    mov     eax, 1
    mov     edi, 1
    lea     rsi, [rsp]
    mov     edx, 1
    syscall
    pop     rax
    mov     al, bl
    and     al, 0x0F
    movzx   eax, al
    mov     al, [rel hex_chars + rax]
    push    rax
    mov     eax, 1
    mov     edi, 1
    lea     rsi, [rsp]
    mov     edx, 1
    syscall
    pop     rax
    pop     rbx
    ret

print_hex_dword:
    push    rbx
    mov     ebx, edi
    shr     edi, 24
    mov     eax, edi
    call    print_hex_byte
    mov     edi, ebx
    shr     edi, 16
    and     edi, 0xFF
    mov     eax, edi
    call    print_hex_byte
    mov     edi, ebx
    shr     edi, 8
    and     edi, 0xFF
    mov     eax, edi
    call    print_hex_byte
    mov     edi, ebx
    and     edi, 0xFF
    mov     eax, edi
    call    print_hex_byte
    pop     rbx
    ret

print_dec:
    push    rbx
    push    r12
    push    r13

    mov     r12d, eax
    test    eax, eax
    jnz     .get_digits
    mov     dil, '0'
    call    putchar
    jmp     .done

.get_digits:
    xor     edx, edx
    mov     ecx, 10
    div     ecx
    push    rdx
    inc     r13d
    test    eax, eax
    jnz     .get_digits

.print:
    pop     rdx
    mov     dil, dl
    add     dil, '0'
    call    putchar
    dec     r13d
    jnz     .print

.done:
    pop     r13
    pop     r12
    pop     rbx
    ret

; -------------------------------------------------------------------
; Main
; -------------------------------------------------------------------
global _start
_start:
    push    rbx
    push    r12
    push    r13
    push    r14
; --- Status parse (9 tests) ---
    test_status s_test_status_200,   resp_200,      resp_200_len,      200
    test_status s_test_status_404,   resp_404,      resp_404_len,      404
    test_status s_test_status_301,   resp_301,      resp_301_len,      301
    test_status s_test_status_500,   resp_500,      resp_500_len,      500
    test_status s_test_status_nospc,  resp_no_space,  resp_no_space_len,  0
    test_status s_test_status_empty,  resp_empty,     resp_empty_len,     0
    test_status s_test_status_nostat, resp_no_status,  resp_no_status_len,  0
    test_status s_test_status_baddgt, resp_bad_digit,  resp_bad_digit_len,  0
    test_status s_test_status_trunc,  resp_truncated,  resp_truncated_len,  200

; --- Body find (3 tests) ---
    test_ptr   s_test_find_body,      resp_body,    resp_body_len,     1
    test_ptr   s_test_find_body_none,  resp_no_body,  resp_no_body_len,   0
    test_ptr   s_test_find_body_empty, resp_empty,     resp_empty_len,     0

; --- Content-Length (4 tests) ---
    test_cl    s_test_cl,             resp_cl,       resp_cl_len,       13
    test_cl    s_test_cl_lower,       resp_cl_lower, resp_cl_lower_len,  5
    test_cl    s_test_cl_mixed,       resp_cl_mixed, resp_cl_mixed_len,  42
    test_cl    s_test_cl_none,        resp_no_cl,    resp_no_cl_len,     0

; --- SSE tests (11 tests) ---
    test_is_sse s_test_sse_is_sse,      resp_sse_ct,       resp_sse_ct_len,       1
    test_is_sse s_test_sse_is_sse_low,  resp_sse_ct_lower, resp_sse_ct_lower_len, 1
    test_is_sse s_test_sse_is_html,     resp_html_ct,      resp_html_ct_len,      0
    test_is_sse s_test_sse_no_ct,       resp_no_ct,        resp_no_ct_len,        0

    test_sse_event s_test_sse_simple,   sse_body_simple,  sse_body_simple_len,  0, 5, 0
    test_sse_event s_test_sse_retry,    sse_body_retry,   sse_body_retry_len,   0, 1, 3000
    test_sse_event s_test_sse_empty,    sse_body_empty,   sse_body_empty_len,   0, 0, 0

    test_sse_ptr s_test_sse_event_ptr,  sse_body_multi,   sse_body_multi_len,   0, SSE_EVENT_EVENT_PTR, 1
    test_sse_ptr s_test_sse_no_event,   sse_body_simple,  sse_body_simple_len,  0, SSE_EVENT_EVENT_PTR, 0
    test_sse_ptr s_test_sse_id_ptr,     sse_body_id,      sse_body_id_len,      0, SSE_EVENT_ID_PTR,    1
    test_sse_ptr s_test_sse_comment,    sse_body_comment, sse_body_comment_len, 0, SSE_EVENT_DATA_PTR, 1

; --- Summary ---
    lea     rsi, [rel s_nl]
    call    puts
    lea     rsi, [rel s_total]
    call    puts
    mov     eax, dword [rel passed]
    call    print_dec
    lea     rsi, [rel s_slash]
    call    puts
    mov     eax, 27
    call    print_dec

    cmp     qword [rel failed], 0
    jnz     .exit_fail
    xor     edi, edi
    jmp     .exit
.exit_fail:
    mov     edi, 1
.exit:
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    mov     eax, 60
    syscall

; -------------------------------------------------------------------
; Strings
; -------------------------------------------------------------------
SECTION .rodata
s_colon:      db ": ", 0
s_pass:       db "PASS", 0
s_fail:       db "FAIL", 0
s_nl:         db 0x0A, 0
s_sp_colon:   db " : ", 0
s_sp_bang_sp: db " ! ", 0
s_slash:      db "/", 0
s_total:      db "Total: ", 0

s_test_status_200:   db "status_200", 0
s_test_status_404:   db "status_404", 0
s_test_status_301:   db "status_301", 0
s_test_status_500:   db "status_500", 0
s_test_status_nospc:  db "status_no_space", 0
s_test_status_empty:  db "status_empty", 0
s_test_status_nostat: db "status_no_status", 0
s_test_status_baddgt: db "status_bad_digit", 0
s_test_status_trunc:  db "status_truncated", 0
s_test_find_body:      db "find_body", 0
s_test_find_body_none:  db "find_body_none", 0
s_test_find_body_empty: db "find_body_empty", 0
s_test_cl:             db "content_length", 0
s_test_cl_lower:       db "content_length_lower", 0
s_test_cl_mixed:       db "content_length_mixed", 0
s_test_cl_none:        db "content_length_none", 0
s_test_sse_is_sse:     db "sse_is_sse", 0
s_test_sse_is_sse_low: db "sse_is_sse_lower", 0
s_test_sse_is_html:    db "sse_is_html", 0
s_test_sse_no_ct:      db "sse_no_ct", 0
s_test_sse_simple:     db "sse_simple", 0
s_test_sse_retry:      db "sse_retry", 0
s_test_sse_empty:      db "sse_empty", 0
s_test_sse_event_ptr:  db "sse_event_ptr", 0
s_test_sse_no_event:   db "sse_no_event", 0
s_test_sse_id_ptr:     db "sse_id_ptr", 0
s_test_sse_comment:    db "sse_comment", 0
