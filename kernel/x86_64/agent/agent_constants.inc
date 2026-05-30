; Agent protocol constants — message types, flags, well-known identities
;
; Agent messages are carried inside cell payloads (251 bytes).
; The payload format:
;   Byte 0:     Agent message type
;   Byte 1:     Agent message flags
;   Bytes 2+:   Agent message body

; ==================================================================
; Agent message types (byte 0 of agent cell payload)
; ==================================================================
AGENT_MSG_REQUEST     equ 1
AGENT_MSG_RESPONSE    equ 2
AGENT_MSG_ERROR       equ 3

; ==================================================================
; Agent message flags (byte 1 of agent cell payload)
; ==================================================================
AGENT_FLAG_MORE       equ 1  ; more cells follow (multi-cell message)
AGENT_FLAG_END        equ 2  ; last cell of this message

; ==================================================================
; Agent handler function signature
; All agent handlers follow the same calling convention:
;   rdi = pointer to incoming cell (256 bytes)
;   rsi = sender slot_id
; Returns: eax = 0, edx = 0 on success
; ==================================================================

; ==================================================================
; Identity route table agent handler fields
;
; Stored at the end of each identity slot, after the ring buffer.
; LOCAL_ID_HANDLER = 8-byte function pointer (0 = no handler)
; LOCAL_ID_FLAGS   = 1-byte flags (bit 0 = synchronous dispatch)
; ==================================================================
%define AGENT_FLAG_SYNC     1  ; synchronous dispatch on cell_send

; Well-known agent identity labels (hashed by kernel at init time)
AGENT_HTTP_LABEL      db "edgerun.agent.http"
AGENT_HTTP_LABEL_LEN  equ 18
