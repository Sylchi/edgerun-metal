; Agent protocol constants — message types, flags, well-known identities
;
; Agent messages are carried inside cell payloads (251 bytes).
; The object-native payload envelope is fixed:
;   Byte 0:       Agent message type
;   Byte 1:       Agent message flags
;   Bytes 2..5:   Sender route slot id
;   Bytes 6..37:  Request object id
;   Bytes 38..69: Input object id
;   Bytes 70..101: Grant or receipt object id
;   Bytes 102..250: Small inline arguments

; ==================================================================
; Agent message types (byte 0 of agent cell payload)
; ==================================================================
AGENT_MSG_REQUEST     equ 1
AGENT_MSG_RESPONSE    equ 2
AGENT_MSG_ERROR       equ 3
AGENT_MSG_STAGE_START equ 4
AGENT_MSG_STAGE_RESULT equ 5
AGENT_MSG_TOOL_REQUEST equ 6
AGENT_MSG_TOOL_RESULT equ 7
AGENT_MSG_APPROVAL_REQUEST equ 8
AGENT_MSG_APPROVAL_RESULT equ 9
AGENT_MSG_RECEIPT     equ 10

; ==================================================================
; Agent payload envelope offsets
; ==================================================================
AGENT_PAYLOAD_MSG_TYPE equ 0
AGENT_PAYLOAD_FLAGS    equ 1
AGENT_PAYLOAD_SENDER_SLOT equ 2
AGENT_PAYLOAD_REQUEST_OBJECT equ 6
AGENT_PAYLOAD_INPUT_OBJECT equ 38
AGENT_PAYLOAD_GRANT_OR_RECEIPT equ 70
AGENT_PAYLOAD_INLINE_ARGS equ 102

AGENT_PAYLOAD_SENDER_SLOT_SIZE equ 4
AGENT_PAYLOAD_OBJECT_ID_SIZE equ 32
AGENT_PAYLOAD_INLINE_ARGS_SIZE equ 149

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
