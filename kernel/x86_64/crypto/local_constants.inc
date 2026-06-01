; EdgeRun local cell transport constants
; Same-machine identity-based cell routing using SPSC ring buffers.

; ==================================================================
; Local cell format (Tor fixed cell, link protocol v4+)
; ==================================================================
LOCAL_CELL_CIRC_ID      equ 0   ; 4 bytes
LOCAL_CELL_CMD          equ 4   ; 1 byte
LOCAL_CELL_PAYLOAD      equ 5   ; 509 bytes
LOCAL_CELL_SIZE         equ 514 ; 4-byte CircID + 1-byte Command + 509-byte Body
LOCAL_CELL_HEADER_LEN   equ 5
LOCAL_CELL_PAYLOAD_LEN  equ 509

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
LOCAL_ID_ROUTE_KIND     equ 41 + LOCAL_RING_SIZE  ; 1=local ring, 2=relay forwarding
LOCAL_ID_SLOT_SIZE      equ 42 + LOCAL_RING_SIZE
LOCAL_MAX_IDENTITIES    equ 16
LOCAL_ROUTE_TABLE_SIZE  equ LOCAL_MAX_IDENTITIES * LOCAL_ID_SLOT_SIZE

LOCAL_ROUTE_KIND_LOCAL  equ 1
LOCAL_ROUTE_KIND_RELAY  equ 2   ; raw Tor fixed-cell forwarding

; ==================================================================
; Local circuit state (extended for local-only circuits)
; ==================================================================
; Reuse Tor circuit state values: TOR_CIRC_OPENING=1, TOR_CIRC_OPEN=2, etc.
; Local circuits skip directly to TOR_CIRC_OPEN.

; ==================================================================
; Circuit table entry layout (per-process, fixed-size)
; ==================================================================
CIRCUIT_DEST_HASH       equ 0   ; 32 bytes — destination identity
CIRCUIT_DEST_SLOT       equ 32  ; 4 bytes — cached destination slot_id
CIRCUIT_STATE           equ 36  ; 4 bytes — 0=FREE, 1=OPEN
CIRCUIT_SLOT_SIZE       equ 40

MAX_CIRCUITS            equ 16
CIRCUIT_TABLE_SIZE      equ MAX_CIRCUITS * CIRCUIT_SLOT_SIZE

; Circuit states
CIRCUIT_STATE_FREE      equ 0
CIRCUIT_STATE_OPEN      equ 1

; ==================================================================
; Error codes
; ==================================================================
ERROR_LOCAL_FULL        equ 80
ERROR_LOCAL_EMPTY       equ 81
ERROR_LOCAL_NOT_FOUND   equ 82
ERROR_LOCAL_EXISTS      equ 83
ERROR_LOCAL_BUSY        equ 84
ERROR_CIRCUIT_INVALID   equ 85
