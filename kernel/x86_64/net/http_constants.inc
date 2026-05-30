; EdgeRun HTTP client protocol constants
; Included by http.asm

HTTP_PORT            equ 80
HTTPS_PORT           equ 443

; HTTP methods
HTTP_METHOD_GET      equ 0

; HTTP version strings built inline; no equ needed

; Response parsing states
HTTP_PARSE_STATUS    equ 0
HTTP_PARSE_HEADERS   equ 1
HTTP_PARSE_BODY      equ 2
HTTP_PARSE_DONE      equ 3

; Max sizes
HTTP_REQUEST_MAX     equ 512
HTTP_HEADER_MAX      equ 2048
HTTP_BODY_MAX        equ 4096

; Poll loop limits
HTTP_CONNECT_POLL    equ 1000
HTTP_RECV_POLL       equ 2000

; HTTP response status code offsets within parsed result
HTTP_STATUS_CODE     equ 0
HTTP_BODY_OFFSET     equ 4
HTTP_BODY_LEN        equ 8
HTTP_RESULT_SIZE     equ 12

; ==================================================================
; SSE (Server-Sent Events) — event structure offsets
; ==================================================================
SSE_EVENT_DATA_PTR  equ 0   ; qword — ptr to first data: value in body (0 if absent)
SSE_EVENT_DATA_LEN  equ 8   ; dword — length of that value
SSE_EVENT_EVENT_PTR equ 12  ; qword — ptr to event: value in body (0 if absent)
SSE_EVENT_EVENT_LEN equ 20  ; dword — length
SSE_EVENT_ID_PTR    equ 24  ; qword — ptr to id: value in body (0 if absent)
SSE_EVENT_ID_LEN    equ 32  ; dword — length
SSE_EVENT_RETRY     equ 36  ; dword — retry ms (0 if absent)
SSE_EVENT_SIZE      equ 40


