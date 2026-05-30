; EdgeRun local cell transport constants
; Same-machine identity-based cell routing using SPSC ring buffers.

; ==================================================================
; Local cell format (fixed-size, 256 bytes)
; ==================================================================
LOCAL_CELL_CIRC_ID      equ 0   ; 4 bytes
LOCAL_CELL_CMD          equ 4   ; 1 byte
LOCAL_CELL_PAYLOAD      equ 5   ; 251 bytes
LOCAL_CELL_SIZE         equ 256 ; 4 + 1 + 251
LOCAL_CELL_HEADER_LEN   equ 5
LOCAL_CELL_PAYLOAD_LEN  equ 251

; ==================================================================
; Local cell commands
; ==================================================================
LOCAL_CELL_DATA         equ 1
LOCAL_CELL_OPEN         equ 2
LOCAL_CELL_CLOSE        equ 3

; ==================================================================
; SPSC ring buffer layout (per identity, incoming mailbox)
; ==================================================================
LOCAL_RING_SLOTS        equ 64
LOCAL_RING_HEAD         equ 0   ; u32 write index (producer = kernel)
LOCAL_RING_TAIL         equ 4   ; u32 read index (consumer = app)
LOCAL_RING_CELLS        equ 8   ; cells[SLOTS][LOCAL_CELL_SIZE]
LOCAL_RING_SIZE         equ 8 + LOCAL_RING_SLOTS * LOCAL_CELL_SIZE

; ==================================================================
; Identity routing table entry
; ==================================================================
LOCAL_ID_HASH           equ 0   ; 32 bytes identity hash (BLAKE3)
LOCAL_ID_RING           equ 32  ; incoming ring buffer (LOCAL_RING_SIZE bytes)
LOCAL_ID_HANDLER        equ 32 + LOCAL_RING_SIZE  ; 8-byte agent handler fn ptr
LOCAL_ID_FLAGS          equ 40 + LOCAL_RING_SIZE  ; 1-byte agent flags
LOCAL_ID_SLOT_SIZE      equ 41 + LOCAL_RING_SIZE
LOCAL_MAX_IDENTITIES    equ 16
LOCAL_ROUTE_TABLE_SIZE  equ LOCAL_MAX_IDENTITIES * LOCAL_ID_SLOT_SIZE

; ==================================================================
; Local circuit state (extended for local-only circuits)
; ==================================================================
; Reuse Tor circuit state values: TOR_CIRC_OPENING=1, TOR_CIRC_OPEN=2, etc.
; Local circuits skip directly to TOR_CIRC_OPEN.

; ==================================================================
; Error codes
; ==================================================================
ERROR_LOCAL_FULL        equ 80
ERROR_LOCAL_EMPTY       equ 81
ERROR_LOCAL_NOT_FOUND   equ 82
ERROR_LOCAL_EXISTS      equ 83
ERROR_LOCAL_BUSY        equ 84
