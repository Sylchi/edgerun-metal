; Display Agent (DA) protocol and surface constants
;
; DA manages the framebuffer, composites app surfaces in layer order,
; and routes input events to the focused app.
;
; DA identity label: "edgerun.agent.da" (precomputed BLAKE3 hash at init)

; DA message types (cell payload byte 0)
DA_MSG_SURFACE_REGISTER   equ 1
DA_MSG_SURFACE_UPDATE     equ 2
DA_MSG_SURFACE_UNREGISTER equ 3
DA_MSG_SURFACE_FOCUS      equ 4
DA_MSG_INPUT_EVENT        equ 5

; DA surface layer order (lower = farther back)
DA_LAYER_SCRIM    equ 0
DA_LAYER_MENU     equ 1
DA_LAYER_POPOVER  equ 2
DA_LAYER_MODAL    equ 3
DA_LAYER_TOAST    equ 4
DA_LAYER_COUNT    equ 5

; DA surface flags
DA_SURFACE_VISIBLE   equ 1
DA_SURFACE_FOCUSED   equ 2

; DA surface struct (84 bytes)
DA_SURFACE_HASH      equ 0    ; 32 BLAKE3 identity hash
DA_SURFACE_LAYER     equ 32   ; 1 byte
DA_SURFACE_FLAGS     equ 33   ; 1 byte
DA_SURFACE_PAD       equ 34   ; 2 bytes padding
DA_SURFACE_RECT_PTR  equ 36   ; 8 ptr to rect float buffer
DA_SURFACE_RECT_LEN  equ 44   ; 8 count
DA_SURFACE_RECT_CAP  equ 52   ; 8 capacity
DA_SURFACE_ICON_PTR  equ 60   ; 8 ptr to icon float buffer
DA_SURFACE_ICON_LEN  equ 68   ; 8 count
DA_SURFACE_ICON_CAP  equ 76   ; 8 capacity
DA_SURFACE_SIZE      equ 84

DA_MAX_SURFACES      equ 8

; Compositing output buffer limits (per frame)
DA_COMPOSITE_MAX_RECTS   equ 256
DA_COMPOSITE_MAX_ICONS   equ 128
DA_COMPOSITE_MAX_VTX     equ 256

; Composit buffer sizes in bytes
DA_COMPOSITE_RECT_BYTES  equ DA_COMPOSITE_MAX_RECTS * 60   ; 15 * 4 bytes per rect
DA_COMPOSITE_ICON_BYTES  equ DA_COMPOSITE_MAX_ICONS * 36   ; 9 * 4 bytes per icon

; DA identity label length
DA_LABEL_LEN equ 16
