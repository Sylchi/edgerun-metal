; EdgeRun HTTP Client — x86_64 assembly
; Synchronous HTTP/1.1 GET client using the existing TCP/IP stack.
; Freestanding — no libc, no external dependencies.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/net/net_constants.inc"
%include "x86_64/net/http_constants.inc"

extern er_tcp_connect
extern er_tcp_get_state
extern er_tcp_send
extern er_tcp_recv
extern er_tcp_close
extern er_net_poll
extern er_tcp_poll
extern er_memcpy
extern er_memset
extern er_strlen

SECTION .bss

http_req_buf:    resb HTTP_REQUEST_MAX
http_resp_buf:   resb HTTP_HEADER_MAX
http_resp_len:   resd 1

SECTION .rodata

http_str_get:       db "GET "
http_str_get_len    equ 4

http_str_version:   db " HTTP/1.1", 0x0D, 0x0A, "Host: "
http_str_version_len equ 16

http_str_tail:      db 0x0D, 0x0A, "Connection: close", 0x0D, 0x0A, 0x0D, 0x0A
http_str_tail_len   equ 23

http_str_content_len: db "Content-Length: "
http_str_content_len_len equ 16

http_str_content_type: db "content-type: "
http_str_content_type_len equ 14

http_str_sse_ct:      db "text/event-stream"
http_str_sse_ct_len   equ 17

http_str_sse_data:    db "data"
http_str_sse_data_len equ 4

http_str_sse_event:   db "event"
http_str_sse_event_len equ 5

http_str_sse_id:      db "id"
http_str_sse_id_len   equ 2

http_str_sse_retry:   db "retry"
http_str_sse_retry_len equ 5

SECTION .text

; ==================================================================
; er_http_get — synchronous HTTP GET request
;
; int er_http_get(uint32_t dst_ip, uint16_t dst_port,
;                 const char *host, const char *path,
;                 void *resp_buf, uint32_t *resp_len)
;
; Args:
;   edi = destination IP (network byte order)
;   si  = destination port (host byte order)
;   rdx = host string (null-terminated)
;   rcx = path string (null-terminated)
;   r8  = response body buffer
;   r9  = pointer to response length (in: max capacity, out: actual)
;
; Returns:
;   eax = HTTP status code (200, 404, etc.) on success
;   eax = 0 on transport/HTTP error
;   rdx = 0 on success, error code on response
; ==================================================================
er_fn er_http_get
    er_push rbx, r12, r13, r14, r15

    mov     r12d, edi           ; dst_ip
    mov     r13w, si            ; dst_port
    mov     r14, rdx            ; host
    mov     r15, rcx            ; path

    sub     rsp, 32
    mov     [rsp], r8           ; resp_buf
    mov     [rsp + 8], r9       ; resp_len_ptr

    ; ── Step 1: TCP connect ──────────────────────────────────────
    mov     edi, r12d
    movzx   esi, r13w
    xor     edx, edx
    xor     ecx, ecx
    call    er_tcp_connect
    test    eax, eax
    js      .fail_connect

    mov     ebx, eax

    ; ── Step 2: Poll until ESTABLISHED ───────────────────────────
    mov     r12d, HTTP_CONNECT_POLL
.poll_connect:
    call    er_net_poll
    call    er_tcp_poll

    mov     edi, ebx
    call    er_tcp_get_state
    test    eax, eax
    js      .close_fail

    cmp     eax, TCP_ESTABLISHED
    je      .connected

    cmp     eax, TCP_CLOSED
    je      .close_fail

    dec     r12d
    jnz     .poll_connect

    ; Timeout
    mov     edi, ebx
    call    er_tcp_close
    xor     eax, eax
    er_err  ERROR_HTTP_TIMEOUT
    add     rsp, 32
    er_pop  rbx, r12, r13, r14, r15
    er_ret

    ; ── Step 3: Build request ────────────────────────────────────
.connected:
    ; path_len = strlen(path)
    mov     rdi, r15
    call    er_strlen
    mov     r12d, eax            ; r12d = path_len
    mov     [rsp + 16], r15      ; save path ptr

    ; host_len = strlen(host)
    mov     rdi, r14
    call    er_strlen
    mov     r13d, eax            ; r13d = host_len
    mov     [rsp + 24], r14      ; save host ptr

    ; Build request in http_req_buf, track offset at [rsp + 28]
    mov     dword [rsp + 28], 0

    ; "GET "
    mov     eax, [rsp + 28]
    lea     rdi, [http_req_buf + rax]
    lea     rsi, [rel http_str_get]
    mov     edx, http_str_get_len
    call    er_memcpy
    mov     dword [rsp + 28], http_str_get_len

    ; path
    mov     eax, [rsp + 28]
    lea     rdi, [http_req_buf + rax]
    mov     rsi, [rsp + 16]      ; path ptr
    mov     edx, r12d            ; path_len
    call    er_memcpy
    mov     eax, [rsp + 28]
    add     eax, r12d
    mov     [rsp + 28], eax

    ; " HTTP/1.1\r\nHost: "
    mov     eax, [rsp + 28]
    lea     rdi, [http_req_buf + rax]
    lea     rsi, [rel http_str_version]
    mov     edx, http_str_version_len
    call    er_memcpy
    mov     eax, [rsp + 28]
    add     eax, http_str_version_len
    mov     [rsp + 28], eax

    ; host
    mov     eax, [rsp + 28]
    lea     rdi, [http_req_buf + rax]
    mov     rsi, [rsp + 24]      ; host ptr
    mov     edx, r13d            ; host_len
    call    er_memcpy
    mov     eax, [rsp + 28]
    add     eax, r13d
    mov     [rsp + 28], eax

    ; "\r\nConnection: close\r\n\r\n"
    mov     eax, [rsp + 28]
    lea     rdi, [http_req_buf + rax]
    lea     rsi, [rel http_str_tail]
    mov     edx, http_str_tail_len
    call    er_memcpy
    mov     eax, [rsp + 28]
    add     eax, http_str_tail_len
    mov     [rsp + 28], eax       ; total request length

    ; ── Step 4: Send request ────────────────────────────────────
    mov     edi, ebx
    lea     rsi, [http_req_buf]
    mov     edx, [rsp + 28]
    call    er_tcp_send
    test    eax, eax
    js      .close_fail

    ; ── Step 5: Receive response ─────────────────────────────────
    ; Clear response buffer
    lea     rdi, [http_resp_buf]
    xor     esi, esi
    mov     edx, HTTP_HEADER_MAX
    call    er_memset
    mov     dword [http_resp_len], 0

    mov     r14d, HTTP_RECV_POLL       ; poll counter
    mov     r15d, 0                     ; total bytes received

.recv_loop:
    call    er_net_poll
    call    er_tcp_poll

    ; Check connection state
    mov     edi, ebx
    call    er_tcp_get_state
    test    eax, eax
    js      .recv_done                 ; error = bail with what we have

    cmp     eax, TCP_CLOSED
    je      .recv_done                 ; closed = no more data

    cmp     eax, TCP_ESTABLISHED
    je      .try_recv
    cmp     eax, TCP_CLOSE_WAIT
    je      .try_recv

    dec     r14d
    jnz     .recv_loop
    jmp     .recv_done                 ; timeout

.try_recv:
    ; er_tcp_recv(conn_id, buf, &len)
    mov     edi, ebx
    lea     rsi, [http_resp_buf + r15]
    lea     rdx, [http_resp_len]
    mov     dword [http_resp_len], HTTP_HEADER_MAX
    sub     dword [http_resp_len], r15d
    js      .recv_done                 ; buffer full

    call    er_tcp_recv
    test    eax, eax
    js      .recv_done                 ; error

    mov     eax, [http_resp_len]
    add     r15d, eax
    mov     [http_resp_len], r15d

    ; Check if we have enough data (full headers)
    cmp     eax, 0
    je      .recv_loop                 ; no data yet, keep polling

    ; Try to find end of headers
    ; We'll just keep receiving until connection closes or timeout
    jmp     .recv_loop

.recv_done:
    ; ── Step 6: Parse response ───────────────────────────────────
    mov     r12d, r15d                 ; total bytes received

    ; Need at least "HTTP/1.1 xxx ...\r\n\r\n" (~20 bytes)
    cmp     r12d, 20
    jb      .parse_fail

    ; Parse status code
    lea     rdi, [http_resp_buf]
    mov     esi, r12d
    call    _http_parse_status_code
    mov     r13d, eax                  ; status code

    ; Find body start (after \r\n\r\n)
    lea     rdi, [http_resp_buf]
    mov     esi, r12d
    call    _http_find_body_start
    er_check_zero rax, .close_ret_status

    mov     r14, rax                   ; body start pointer

    ; Compute body length
    lea     rdi, [http_resp_buf]
    mov     esi, r12d
    call    _http_find_content_length
    mov     r15d, eax                  ; content-length or 0

    ; If Content-Length found, cap at that. Otherwise use remaining buffer.
    er_check_nonzero r15d, .have_clen
    ; No Content-Length: use rest of buffer
    lea     rax, [http_resp_buf + r12]
    sub     rax, r14
    mov     r15d, eax
    jmp     .copy_body

.have_clen:
    ; Clamp to available data
    lea     rax, [http_resp_buf + r12]
    sub     rax, r14
    cmp     r15d, eax
    jbe     .copy_body
    mov     r15d, eax

.copy_body:
    ; Copy body to caller buffer, respecting capacity
    mov     rdi, [rsp]                 ; resp_buf
    mov     rsi, r14                   ; body start
    mov     edx, r15d                  ; body length

    ; Clamp to caller's max
    mov     r8, [rsp + 8]              ; resp_len_ptr
    mov     eax, [r8]                  ; caller's max capacity
    cmp     r15d, eax
    jbe     .clamp_done
    mov     r15d, eax
.clamp_done:
    mov     edx, r15d
    call    er_memcpy
    mov     eax, [rsp + 8]
    mov     [eax], r15d                ; store actual body length

    jmp     .close_ret_status

.parse_fail:
    xor     r13d, r13d

    ; ── Step 7: Close connection and return ──────────────────────
.close_ret_status:
    mov     edi, ebx
    call    er_tcp_close

    mov     eax, r13d                  ; HTTP status code
    er_ok
    add     rsp, 32
    er_pop  rbx, r12, r13, r14, r15
    er_ret

.close_fail:
    mov     edi, ebx
    call    er_tcp_close
    xor     eax, eax
    er_err  ERROR_HTTP_CLOSED
    add     rsp, 32
    er_pop  rbx, r12, r13, r14, r15
    er_ret

.fail_connect:
    xor     eax, eax
    er_err  ERROR_HTTP_NORESP
    add     rsp, 32
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; ==================================================================
; _http_parse_status_code — extract HTTP status code from response
;
; int _http_parse_status_code(const char *resp, uint32_t resp_len)
;
; Scans for the first space after "HTTP/" and reads 3 ASCII digits
; following it. Returns 0 if not found or invalid.
; ==================================================================
_http_parse_status_code:
    er_push rbx, r12

    mov     rbx, rdi            ; buffer
    mov     r12d, esi           ; length

    ; Find first space (after "HTTP/x.x ")
    xor     ecx, ecx
.scan_space:
    cmp     ecx, r12d
    jae     .not_found

    cmp     byte [rbx + rcx], ' '
    je      .found_space

    inc     ecx
    jmp     .scan_space

.found_space:
    inc     ecx                 ; skip the space

    ; Read 3 ASCII digits
    cmp     ecx, r12d
    jae     .not_found

    xor     eax, eax
    mov     al, [rbx + rcx]
    sub     al, '0'
    cmp     al, 9
    ja      .not_found
    imul    eax, 100

    inc     ecx
    cmp     ecx, r12d
    jae     .digit3_done

    xor     edx, edx
    mov     dl, [rbx + rcx]
    sub     dl, '0'
    cmp     dl, 9
    ja      .digit3_done
    imul    edx, 10
    add     eax, edx

    inc     ecx
    cmp     ecx, r12d
    jae     .digit3_done

    xor     edx, edx
    mov     dl, [rbx + rcx]
    sub     dl, '0'
    cmp     dl, 9
    ja      .digit3_done
    add     eax, edx

.digit3_done:
    er_pop  rbx, r12
    er_ok
    er_ret

.not_found:
    xor     eax, eax
    er_pop  rbx, r12
    er_ok
    er_ret

; ==================================================================
; _http_find_body_start — find body after \r\n\r\n
;
; void *_http_find_body_start(const char *resp, uint32_t resp_len)
;
; Returns pointer to body start, or 0 if headers incomplete.
; ==================================================================
_http_find_body_start:
    er_push rbx, r12

    mov     rbx, rdi
    mov     r12d, esi

    xor     ecx, ecx
.scan_delim:
    cmp     ecx, r12d
    jae     .no_body

    cmp     byte [rbx + rcx], 0x0D
    jne     .next_byte

    cmp     ecx, r12d
    jae     .no_body

    cmp     byte [rbx + rcx + 1], 0x0A
    jne     .next_byte

    cmp     ecx, r12d
    jae     .no_body

    cmp     byte [rbx + rcx + 2], 0x0D
    jne     .next_byte

    cmp     ecx, r12d
    jae     .no_body

    cmp     byte [rbx + rcx + 3], 0x0A
    jne     .next_byte

    ; Found \r\n\r\n at offset ecx
    lea     rax, [rbx + rcx + 4]
    er_pop  rbx, r12
    er_ok
    er_ret

.next_byte:
    inc     ecx
    jmp     .scan_delim

.no_body:
    xor     eax, eax
    er_pop  rbx, r12
    er_ok
    er_ret

; ==================================================================
; _http_find_content_length — find Content-Length header value
;
; int _http_find_content_length(const char *resp, uint32_t resp_len)
;
; Scans headers (up to \r\n\r\n) for "Content-Length: " and parses
; the numeric value. Returns 0 if header not found.
; ==================================================================
_http_find_content_length:
    er_push rbx, r12, r13

    mov     rbx, rdi
    mov     r12d, esi

    xor     ecx, ecx
.scan_header:
    cmp     ecx, r12d
    jae     .not_found

    ; Check for \r\n\r\n (end of headers)
    cmp     byte [rbx + rcx], 0x0D
    jne     .check_cl
    cmp     ecx, r12d
    jae     .not_found

    cmp     byte [rbx + rcx + 1], 0x0A
    jne     .check_cl
    cmp     ecx, r12d
    jae     .not_found

    cmp     byte [rbx + rcx + 2], 0x0D
    jne     .check_cl
    cmp     ecx, r12d
    jae     .not_found

    cmp     byte [rbx + rcx + 3], 0x0A
    je      .not_found              ; hit end of headers before finding CL

.check_cl:
    ; Compare with "Content-Length: "
    push    rcx
    lea     rsi, [rel http_str_content_len]
    mov     r13d, http_str_content_len_len

    xor     edx, edx
.check_loop:
    cmp     edx, r13d
    jae     .check_match_done

    cmp     ecx, r12d
    jae     .check_mismatch

    mov     al, [rbx + rcx]
    mov     ah, [rsi + rdx]
    cmp     al, ah
    jne     .check_mismatch_ci

    inc     ecx
    inc     edx
    jmp     .check_loop

.check_mismatch_ci:
    ; Case-insensitive retry: check if uppercase/lowercase diff
    mov     al, [rbx + rcx]
    mov     ah, [rsi + rdx]
    ; Convert both to uppercase if they're letters
    cmp     al, 'a'
    jb      .no_up1
    cmp     al, 'z'
    ja      .no_up1
    sub     al, 32
.no_up1:
    cmp     ah, 'a'
    jb      .no_up2
    cmp     ah, 'z'
    ja      .no_up2
    sub     ah, 32
.no_up2:
    cmp     al, ah
    jne     .check_mismatch         ; still mismatch

    inc     ecx
    inc     edx
    jmp     .check_loop

.check_match_done:
    ; Found "Content-Length: " — parse number
    ; ecx points to first digit
    xor     eax, eax
.parse_digits:
    cmp     ecx, r12d
    jae     .parse_done

    xor     edx, edx
    mov     dl, [rbx + rcx]
    sub     dl, '0'
    cmp     dl, 9
    ja      .parse_done

    imul    eax, 10
    add     eax, edx
    inc     ecx
    jmp     .parse_digits

.parse_done:
    pop     rcx                     ; discard saved position
    er_pop  rbx, r12, r13
    er_ok
    er_ret

.check_mismatch:
    pop     rcx
    inc     ecx
    jmp     .scan_header

.not_found:
    xor     eax, eax
    er_pop  rbx, r12, r13
    er_ok
    er_ret

; ==================================================================
; er_http_parse_status — public wrapper for _http_parse_status_code
;
; int er_http_parse_status(const char *resp, uint32_t resp_len)
; ==================================================================
er_fn er_http_parse_status
    jmp     _http_parse_status_code

; ==================================================================
; er_http_find_body — public wrapper for _http_find_body_start
;
; void *er_http_find_body(const char *resp, uint32_t resp_len)
; ==================================================================
er_fn er_http_find_body
    jmp     _http_find_body_start

; ==================================================================
; er_http_find_content_length — public wrapper for _http_find_content_length
;
; int er_http_find_content_length(const char *resp, uint32_t resp_len)
; ==================================================================
er_fn er_http_find_content_length
    jmp     _http_find_content_length

; ==================================================================
; _http_find_content_type — find Content-Type header value
;
; const char *_http_find_content_type(const char *resp, uint32_t resp_len,
;                                     uint32_t *value_len)
;
; Scans headers for "content-type:" (case-insensitive) and returns
; pointer to the value portion.  Sets *value_len to the length.
; Returns 0 if header not found.
; ==================================================================
_http_find_content_type:
    er_push rbx, r12, r13, r14

    mov     rbx, rdi
    mov     r12d, esi
    mov     r14, rdx            ; value_len out ptr

    xor     ecx, ecx
.scan:
    cmp     ecx, r12d
    jae     .not_found

    ; Check for \r\n\r\n (end of headers)
    cmp     byte [rbx + rcx], 0x0D
    jne     .check_hdr
    cmp     ecx, r12d
    jae     .not_found
    cmp     byte [rbx + rcx + 1], 0x0A
    jne     .check_hdr
    cmp     ecx, r12d
    jae     .not_found
    cmp     byte [rbx + rcx + 2], 0x0D
    jne     .check_hdr
    cmp     ecx, r12d
    jae     .not_found
    cmp     byte [rbx + rcx + 3], 0x0A
    je      .not_found

.check_hdr:
    push    rcx
    lea     rsi, [rel http_str_content_type]
    mov     r13d, http_str_content_type_len

    xor     edx, edx
.check_loop:
    cmp     edx, r13d
    jae     .check_match

    cmp     ecx, r12d
    jae     .check_mismatch

    mov     al, [rbx + rcx]
    mov     ah, [rsi + rdx]
    ; case-insensitive: uppercase both
    cmp     al, 'a'
    jb      .cup1
    cmp     al, 'z'
    ja      .cup1
    sub     al, 32
.cup1:
    cmp     ah, 'a'
    jb      .cup2
    cmp     ah, 'z'
    ja      .cup2
    sub     ah, 32
.cup2:
    cmp     al, ah
    jne     .check_mismatch

    inc     ecx
    inc     edx
    jmp     .check_loop

.check_match:
    ; Matched "content-type: " — ecx points past the string
    add     rsp, 8           ; discard saved line start
    ; ecx now points to value start
    lea     rax, [rbx + rcx] ; pointer to value

    ; Scan to \r\n to get value length
    xor     edx, edx
.scan_val:
    cmp     ecx, r12d
    jae     .val_done
    cmp     byte [rbx + rcx], 0x0D
    je      .val_done
    inc     ecx
    inc     edx
    jmp     .scan_val

.val_done:
    ; Write value length
    er_check_zero r14, .ret_ok
    mov     [r14], edx

.ret_ok:
    er_pop  rbx, r12, r13, r14
    er_ok
    er_ret

.check_mismatch:
    pop     rcx
    inc     ecx
    jmp     .scan

.not_found:
    xor     eax, eax
    er_check_zero r14, .ret_nf
    mov     dword [r14], 0

.ret_nf:
    er_pop  rbx, r12, r13, r14
    er_ok
    er_ret

; ==================================================================
; er_http_find_content_type — public wrapper
;
; const char *er_http_find_content_type(const char *resp, uint32_t resp_len,
;                                       uint32_t *value_len)
; ==================================================================
er_fn er_http_find_content_type
    jmp     _http_find_content_type

; ==================================================================
; er_http_is_sse — check if response is Server-Sent Events
;
; int er_http_is_sse(const char *resp, uint32_t resp_len)
;
; Returns 1 if Content-Type is text/event-stream, 0 otherwise.
; ==================================================================
er_fn er_http_is_sse
    er_push rbx, r12, r13

    ; Allocate space for value_len on stack
    sub     rsp, 4
    mov     rdx, rsp            ; value_len out

    call    _http_find_content_type
    er_check_zero rax, .not_sse

    mov     rbx, rax            ; value ptr
    mov     r12d, [rsp]         ; value len

    ; Compare with "text/event-stream" (18 chars)
    cmp     r12d, http_str_sse_ct_len
    jb      .not_sse

    lea     rsi, [rel http_str_sse_ct]
    xor     ecx, ecx
.cmp_loop:
    cmp     ecx, http_str_sse_ct_len
    jae     .is_sse

    mov     al, [rbx + rcx]
    mov     ah, [rsi + rcx]
    ; uppercase both
    cmp     al, 'a'
    jb      .uc1
    cmp     al, 'z'
    ja      .uc1
    sub     al, 32
.uc1:
    cmp     ah, 'a'
    jb      .uc2
    cmp     ah, 'z'
    ja      .uc2
    sub     ah, 32
.uc2:
    cmp     al, ah
    jne     .not_sse

    inc     ecx
    jmp     .cmp_loop

.is_sse:
    mov     eax, 1
    add     rsp, 4
    er_pop  rbx, r12, r13
    er_ok
    er_ret

.not_sse:
    xor     eax, eax
    add     rsp, 4
    er_pop  rbx, r12, r13
    er_ok
    er_ret

; ==================================================================
; _http_sse_parse_event — parse the next SSE event from a body buffer
;
; uint32_t _http_sse_parse_event(const char *body, uint32_t body_len,
;                                uint32_t offset, SSEEvent *event_out)
;
; Parses fields (data:, event:, id:, retry:) from the body starting
; at offset until a blank line (\r\n) or end of buffer.  Fills
; event_out with pointers (into the original body buffer) and lengths
; for each field found.  Multiple data: lines return the first only.
; For retry: the numeric value is parsed and stored.
;
; Returns the offset past the consumed bytes (pointing after the
; blank line).  Returns 0 if offset >= body_len.
; ==================================================================
_http_sse_parse_event:
    er_push rbx, r12, r13, r14, r15

    mov     rbx, rdi            ; body
    mov     r12d, esi           ; body_len
    mov     r13d, edx           ; offset
    mov     r14, rcx            ; event_out

    ; Return 0 if offset past end
    cmp     r13d, r12d
    jae     .past_end

    ; Clear event struct
    mov     qword [r14 + SSE_EVENT_DATA_PTR], 0
    mov     qword [r14 + SSE_EVENT_EVENT_PTR], 0
    mov     qword [r14 + SSE_EVENT_ID_PTR], 0
    mov     dword [r14 + SSE_EVENT_DATA_LEN], 0
    mov     dword [r14 + SSE_EVENT_EVENT_LEN], 0
    mov     dword [r14 + SSE_EVENT_ID_LEN], 0
    mov     dword [r14 + SSE_EVENT_RETRY], 0

    xor     r15d, r15d          ; data_field_count

.event_loop:
    cmp     r13d, r12d
    jae     .event_done

    ; Blank line (\r\n) = end of event
    cmp     byte [rbx + r13], 0x0D
    jne     .chk_comment
    cmp     r13d, r12d
    jae     .event_done
    cmp     byte [rbx + r13 + 1], 0x0A
    jne     .chk_comment
    add     r13d, 2
    jmp     .event_done

.chk_comment:
    ; Comment line (starts with ':')
    cmp     byte [rbx + r13], ':'
    jne     .parse_field_line
    inc     r13d
.scan_comment_nl:
    cmp     r13d, r12d
    jae     .event_done
    cmp     byte [rbx + r13], 0x0A
    je      .after_comment_nl
    inc     r13d
    jmp     .scan_comment_nl
.after_comment_nl:
    inc     r13d
    jmp     .event_loop

.parse_field_line:
    ; r13d = field start. Scan for ':'
    mov     r15d, r13d          ; save field name start
    xor     ecx, ecx            ; field name length
.scan_colon:
    cmp     r13d, r12d
    jae     .skip_to_nl
    mov     al, [rbx + r13]
    cmp     al, ':'
    je      .found_colon
    cmp     al, 0x0D
    je      .skip_to_nl        ; no colon = malformed, skip line
    inc     ecx
    inc     r13d
    jmp     .scan_colon

.found_colon:
    ; r13d = position of ':', ecx = field name length
    ; r15d = field name start
    inc     r13d                ; skip ':'
    ; Skip spaces after colon
.skip_val_spaces:
    cmp     r13d, r12d
    jae     .skip_to_nl
    cmp     byte [rbx + r13], ' '
    jne     .got_val_start
    inc     r13d
    jmp     .skip_val_spaces

.got_val_start:
    mov     r8d, r13d           ; save value start

    ; Scan to \r\n to get value length
.scan_val_end:
    cmp     r13d, r12d
    jae     .val_end_found
    cmp     byte [rbx + r13], 0x0D
    je      .val_end_found
    inc     r13d
    jmp     .scan_val_end

.val_end_found:
    ; r8d = value start, r13d = at \r, value_len = r13d - r8d
    mov     r9d, r13d
    sub     r9d, r8d            ; r9d = value length

    ; Dispatch by field name length
    cmp     ecx, 4
    je      .try_field_data
    cmp     ecx, 5
    je      .try_field_5
    cmp     ecx, 2
    je      .try_field_id
    jmp     .advance_line

.try_field_data:
    ; Check "data" (case-insensitive)
    mov     al, [rbx + r15]
    or      al, 32
    cmp     al, 'd'
    jne     .advance_line
    mov     al, [rbx + r15 + 1]
    or      al, 32
    cmp     al, 'a'
    jne     .advance_line
    mov     al, [rbx + r15 + 2]
    or      al, 32
    cmp     al, 't'
    jne     .advance_line
    mov     al, [rbx + r15 + 3]
    or      al, 32
    cmp     al, 'a'
    jne     .advance_line
    ; It's a data field
    cmp     qword [r14 + SSE_EVENT_DATA_PTR], 0
    jne     .advance_line       ; already have one, ignore extras
    lea     rax, [rbx + r8]
    mov     [r14 + SSE_EVENT_DATA_PTR], rax
    mov     [r14 + SSE_EVENT_DATA_LEN], r9d
    inc     r15d                ; (reuse as counter)
    jmp     .advance_line

.try_field_5:
    ; Check "event" or "retry"
    mov     al, [rbx + r15]
    or      al, 32
    cmp     al, 'e'
    je      .try_field_event
    cmp     al, 'r'
    je      .try_field_retry
    jmp     .advance_line

.try_field_event:
    mov     al, [rbx + r15 + 1]
    or      al, 32
    cmp     al, 'v'
    jne     .advance_line
    mov     al, [rbx + r15 + 2]
    or      al, 32
    cmp     al, 'e'
    jne     .advance_line
    mov     al, [rbx + r15 + 3]
    or      al, 32
    cmp     al, 'n'
    jne     .advance_line
    mov     al, [rbx + r15 + 4]
    or      al, 32
    cmp     al, 't'
    jne     .advance_line
    ; It's an event field
    cmp     qword [r14 + SSE_EVENT_EVENT_PTR], 0
    jne     .advance_line       ; already set, skip
    lea     rax, [rbx + r8]
    mov     [r14 + SSE_EVENT_EVENT_PTR], rax
    mov     [r14 + SSE_EVENT_EVENT_LEN], r9d
    jmp     .advance_line

.try_field_retry:
    mov     al, [rbx + r15 + 1]
    or      al, 32
    cmp     al, 'e'
    jne     .advance_line
    mov     al, [rbx + r15 + 2]
    or      al, 32
    cmp     al, 't'
    jne     .advance_line
    mov     al, [rbx + r15 + 3]
    or      al, 32
    cmp     al, 'r'
    jne     .advance_line
    mov     al, [rbx + r15 + 4]
    or      al, 32
    cmp     al, 'y'
    jne     .advance_line
    ; It's a retry field — parse value as decimal
    ; r8d = value start, r9d = value length
    ; If retry already set, skip
    cmp     dword [r14 + SSE_EVENT_RETRY], 0
    jne     .advance_line
    ; Parse integer
    xor     eax, eax
    mov     ecx, r8d
    mov     edx, r9d
.parse_retry:
    er_check_zero edx, .retry_done
    movzx   r11d, byte [rbx + rcx]
    lea     r11d, [r11d - '0']
    cmp     r11d, 9
    ja      .retry_done
    imul    eax, 10
    add     eax, r11d
    inc     ecx
    dec     edx
    jmp     .parse_retry
.retry_done:
    mov     [r14 + SSE_EVENT_RETRY], eax
    jmp     .advance_line

.try_field_id:
    ; Check "id" (case-insensitive)
    mov     al, [rbx + r15]
    or      al, 32
    cmp     al, 'i'
    jne     .advance_line
    mov     al, [rbx + r15 + 1]
    or      al, 32
    cmp     al, 'd'
    jne     .advance_line
    ; It's an id field
    cmp     qword [r14 + SSE_EVENT_ID_PTR], 0
    jne     .advance_line       ; already set, skip
    lea     rax, [rbx + r8]
    mov     [r14 + SSE_EVENT_ID_PTR], rax
    mov     [r14 + SSE_EVENT_ID_LEN], r9d
    jmp     .advance_line

.advance_line:
    ; r13d is at \r, skip to after \n
    cmp     r13d, r12d
    jae     .event_done
    cmp     byte [rbx + r13], 0x0A
    je      .after_nl
    inc     r13d
    jmp     .advance_line
.after_nl:
    inc     r13d
    jmp     .event_loop

.skip_to_nl:
    ; r13d is somewhere in the line; scan for \n
    cmp     r13d, r12d
    jae     .event_done
    cmp     byte [rbx + r13], 0x0A
    je      .after_nl
    inc     r13d
    jmp     .skip_to_nl

.event_done:
    mov     eax, r13d
    er_pop  rbx, r12, r13, r14, r15
    er_ok
    er_ret

.past_end:
    xor     eax, eax
    er_pop  rbx, r12, r13, r14, r15
    er_ok
    er_ret

; ==================================================================
; er_http_sse_parse_event — public wrapper
;
; uint32_t er_http_sse_parse_event(const char *body, uint32_t body_len,
;                                  uint32_t offset, SSEEvent *event_out)
; ==================================================================
er_fn er_http_sse_parse_event
    jmp     _http_sse_parse_event
