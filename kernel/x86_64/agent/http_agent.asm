; http_agent.asm — EdgeRun kernel HTTP agent
;
; Registers as a local cell identity and responds to agent protocol
; HTTP request cells by making real HTTP GET requests via the kernel's
; TCP/IP stack.
;
; Agent identity: BLAKE3("edgerun.agent.http")
;
; Request cell body format (509 bytes max):
;   [0]     = AGENT_MSG_REQUEST (1)
;   [1]     = AGENT_FLAG_END (flags)
;   [2..5]  = sender_slot_id (u32 LE)
;   [6..9]  = dst_ip (u32, network byte order)
;   [10..11]= dst_port (u16, host byte order)
;   [12]    = host_len
;   [13..]  = host string
;   ...     = url_len + url string
;
; Response cell payload format:
;   [0]     = AGENT_MSG_RESPONSE (2) or AGENT_MSG_ERROR (3)
;   [1]     = AGENT_FLAG_END (2)
;   [2..3]  = status_code (u16 LE)
;   [4..]   = body data (up to cell_payload_len - 4)

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/crypto/local_constants.inc"
%include "x86_64/agent/agent_constants.inc"

extern er_local_route_register
extern er_local_route_set_handler
extern er_local_cell_send_to_slot
extern er_http_get
extern er_memcpy
extern er_memset
extern er_blake3_hash_bytes

SECTION .data

http_agent_label:   db "edgerun.agent.http"
http_agent_label_len: dq 18

; Scratch buffers
http_resp_buf:  times 4096 db 0
http_resp_len:  dd 4096
http_resp_cell: times LOCAL_CELL_SIZE db 0

; String temps
http_host_buf:  times 256 db 0
http_path_buf:  times 512 db 0

SECTION .text

; ==================================================================
; er_agent_http_init — register HTTP agent identity and handler
; void er_agent_http_init(void)
; ==================================================================
er_fn er_agent_http_init
    push    rbx
    push    r12

    sub     rsp, 32                 ; hash output

    lea     rdi, [rel http_agent_label]
    mov     rsi, [rel http_agent_label_len]
    mov     rdx, rsp
    call    er_blake3_hash_bytes
    test    rax, rax
    jz      .fail

    mov     rdi, rsp
    call    er_local_route_register
    test    edx, edx
    jnz     .fail

    mov     r12d, eax               ; slot_id

    mov     edi, r12d
    lea     rsi, [rel _http_handler]
    mov     dl, AGENT_FLAG_SYNC
    call    er_local_route_set_handler

    add     rsp, 32
    xor     eax, eax
    er_ok
    pop     r12
    pop     rbx
    er_ret

.fail:
    add     rsp, 32
    xor     eax, eax
    er_err  ERROR_LOCAL_BUSY
    pop     r12
    pop     rbx
    er_ret

; ==================================================================
; _http_handler — synchronous agent handler
; rdi = cell ptr, rsi = sender slot_id
; ==================================================================
_http_handler:
    push    rbx
    push    r12
    push    r13

    mov     r12, rdi                ; cell ptr
    mov     r13d, esi               ; sender slot_id

    lea     rbx, [r12 + LOCAL_CELL_PAYLOAD]

    ; Validate message type
    cmp     byte [rbx], AGENT_MSG_REQUEST
    jne     .bad

    ; Parse: skip type(1) + flags(1) + sender_slot(4) = offset 6
    ; [6..9]  dst_ip
    ; [10..11] dst_port
    ; [12]    host_len
    ; [13..]  host
    ; ...     url_len + url

    mov     r14d, [rbx + 6]          ; dst_ip
    movzx   r15d, word [rbx + 10]    ; dst_port
    movzx   r12d, byte [rbx + 12]    ; host_len

    ; Copy host string
    lea     rsi, [rbx + 13]
    lea     rdi, [rel http_host_buf]
    movzx   edx, r12b
    call    er_memcpy
    mov     byte [rel http_host_buf + r12], 0

    ; Get url
    movzx   ecx, byte [rbx + 13 + r12]     ; url_len
    lea     rsi, [rbx + 14 + r12]           ; url ptr
    lea     rdi, [rel http_path_buf]
    movzx   edx, cl
    call    er_memcpy
    mov     byte [rel http_path_buf + rcx], 0

    ; Call er_http_get
    ; er_http_get(edi=dst_ip, si=port, rdx=host, rcx=path, r8=buf, r9=buflen_ptr)
    mov     edi, r14d
    movzx   esi, r15w
    lea     rdx, [rel http_host_buf]
    lea     rcx, [rel http_path_buf]
    lea     r8, [rel http_resp_buf]
    lea     r9, [rel http_resp_len]
    call    er_http_get

    ; eax = status code (0 = error)
    ; Build response cell
    lea     r12, [rel http_resp_cell]
    push    rax                         ; save status

    mov     rdi, r12
    xor     esi, esi
    mov     edx, LOCAL_CELL_SIZE
    call    er_memset

    mov     byte [r12 + LOCAL_CELL_CMD], LOCAL_CELL_DATA

    lea     rdi, [r12 + LOCAL_CELL_PAYLOAD]
    pop     rax
    test    ax, ax
    jz      .set_error

    mov     byte [rdi], AGENT_MSG_RESPONSE
    jmp     .build_body

.set_error:
    mov     byte [rdi], AGENT_MSG_ERROR

.build_body:
    mov     byte [rdi + 1], AGENT_FLAG_END
    mov     word [rdi + 2], ax            ; status code

    ; Copy body
    mov     ecx, [rel http_resp_len]
    cmp     ecx, LOCAL_CELL_PAYLOAD - 4
    jbe     .copy_ok
    mov     ecx, LOCAL_CELL_PAYLOAD - 4
.copy_ok:
    lea     rsi, [rel http_resp_buf]
    lea     rdi, [r12 + LOCAL_CELL_PAYLOAD + 4]
    mov     edx, ecx
    call    er_memcpy

    ; Send response to sender
    mov     edi, r13d
    mov     rsi, r12
    call    er_local_cell_send_to_slot

    xor     eax, eax
    er_ok
    pop     r13
    pop     r12
    pop     rbx
    er_ret

.bad:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    pop     r13
    pop     r12
    pop     rbx
    er_ret
