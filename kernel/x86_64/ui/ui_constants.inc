; EdgeRun UI constants — shared across all UI components
; %include'd by every ui_*.asm file

; ==================================================================
; Pixel format (same as sw_fb)
; ==================================================================
; Packed 32-bit color: 0xAABBGGRR (little-endian)
;   byte 0 = R, byte 1 = G, byte 2 = B, byte 3 = A

; ==================================================================
; UI Color constants — palette from ui_tokens.zig Palette
; ==================================================================
; Macro to pack RGBA into u32: 0xAABBGGRR
; Usage: UI_COLOR name, r, g, b, a
%macro UI_COLOR 5
    %define %1 ((%5 << 24) | (%4 << 16) | (%3 << 8) | %2)
%endm

; Named color constants (0xAABBGGRR hex)
%define UI_COLOR_BLACK        0xFF000000
%define UI_COLOR_WHITE        0xFFFFFFFF
%define UI_COLOR_CLEAR        0x00000000

; Palette — from ui_tokens.zig Palette
%define UI_COLOR_BG           0xFF0B0B0B
%define UI_COLOR_PANEL        0xFF131416
%define UI_COLOR_PANEL_ALT    0xFF1A1B1E
%define UI_COLOR_ROW          0xFF1C1D20
%define UI_COLOR_BORDER       0xFF3E4046
%define UI_COLOR_TEXT         0xFFF2F2F2
%define UI_COLOR_DIM          0xFFB0B5BE
%define UI_COLOR_MUTED        0xFF7E8796
%define UI_COLOR_ACCENT       0xFF4ADE80
%define UI_COLOR_DANGER       0xFFF87171
%define UI_COLOR_ORANGE       0xFFF97316
%define UI_COLOR_BLUE         0xFF60A5FA
%define UI_COLOR_CYAN         0xFF22D3EE
%define UI_COLOR_SHADOW       0x60000000
%define UI_COLOR_SHADOW_HOVER 0xA0000000

; State colors
%define UI_COLOR_HOVER_BORDER 0xFF7DD3FC
%define UI_COLOR_FOCUS_BORDER 0xFFFACC15

; ==================================================================
; Style constants — from ui_tokens.zig
; ==================================================================
%define UI_CONTROL_H            36.0
%define UI_CONTROL_COMPACT_H    32.0
%define UI_CONTROL_MIN_TOUCH    32.0

; Radius
%define UI_RADIUS_CONTROL       7.0
%define UI_RADIUS_SURFACE       8.0
%define UI_RADIUS_ROW           4.0

; Type metrics
%define UI_TYPE_BODY_H          17.0
%define UI_TYPE_BODY_LINE_H     20.0
%define UI_TYPE_SECTION_H       22.0
%define UI_TYPE_TITLE_H         26.0
%define UI_TYPE_CAPTION_H       12.0
%define UI_TYPE_AVG_BODY_W       8.8

; Component metrics
%define UI_BUTTON_H             36.0
%define UI_BUTTON_LABEL_H       17.0
%define UI_BUTTON_LABEL_PAD     16.0
%define UI_BUTTON_RADIUS         7.0

%define UI_CHECKBOX_BOX_SIZE    18.0
%define UI_CHECKBOX_ICON_INSET   3.0
%define UI_CHECKBOX_TEXT_GAP    10.0
%define UI_CHECKBOX_MIN_WIDTH   96.0

%define UI_SWITCH_WIDTH         42.0
%define UI_SWITCH_HEIGHT        24.0
%define UI_SWITCH_KNOB_SIZE     18.0
%define UI_SWITCH_KNOB_INSET     3.0
%define UI_SWITCH_LABEL_GAP     10.0
%define UI_SWITCH_MIN_WIDTH    112.0

%define UI_SLIDER_LABEL_H       14.0
%define UI_SLIDER_TRACK_GAP     12.0
%define UI_SLIDER_TRACK_H        6.0
%define UI_SLIDER_THUMB_SIZE    16.0
%define UI_SLIDER_MIN_WIDTH    120.0
%define UI_SLIDER_MIN_H         32.0

%define UI_INPUT_MIN_WIDTH      44.0
%define UI_ICON_DEFAULT_SIZE    18.0
%define UI_TEXT_LINE_H          18.0
%define UI_TEXT_MAX_LINES        8
%define UI_TEXT_MIN_WIDTH       24.0

%define UI_FIELD_LABEL_H        14.0
%define UI_FIELD_GAP             6.0
%define UI_FIELD_INPUT_H        36.0
%define UI_FIELD_MIN_WIDTH     120.0
%define UI_FIELD_MIN_H          48.0

; ==================================================================
; Axis
; ==================================================================
%define UI_AXIS_ROW   0
%define UI_AXIS_COL   1

; ==================================================================
; Alignment
; ==================================================================
%define UI_ALIGN_START   0
%define UI_ALIGN_CENTER  1
%define UI_ALIGN_END     2
%define UI_ALIGN_STRETCH 3

; ==================================================================
; HitKind — from ui.zig HitKind
; ==================================================================
%define UI_HIT_BUTTON          0
%define UI_HIT_INPUT           1
%define UI_HIT_ROW_ITEM        2
%define UI_HIT_CHECKBOX        3
%define UI_HIT_SWITCH          4
%define UI_HIT_SLIDER          5
%define UI_HIT_TEXTAREA        6
%define UI_HIT_SELECT          7
%define UI_HIT_OVERLAY_TRIGGER 8

; ==================================================================
; Text alignment
; ==================================================================
%define UI_TEXT_ALIGN_START  0
%define UI_TEXT_ALIGN_CENTER 1
%define UI_TEXT_ALIGN_END    2

; ==================================================================
; Font weight
; ==================================================================
%define UI_FONT_WEIGHT_REGULAR   0
%define UI_FONT_WEIGHT_SEMIBOLD  1
%define UI_FONT_WEIGHT_BOLD      2

; ==================================================================
; Rect mode — from render_ir.asm
; ==================================================================
%define UI_RECT_MODE_FILL            0
%define UI_RECT_MODE_SHADOW          1
%define UI_RECT_MODE_BORDER          2
%define UI_RECT_MODE_LINEAR_GRADIENT 3
%define UI_RECT_MODE_PIE_SLICE       4

; ==================================================================
; Button variant
; ==================================================================
%define UI_BTN_PRIMARY   0
%define UI_BTN_SECONDARY 1
%define UI_BTN_OUTLINE   2
%define UI_BTN_GHOST     3
%define UI_BTN_DESTRUCTIVE 4
%define UI_BTN_LINK      5

; ==================================================================
; Control state flags (bitmask)
; ==================================================================
%define UI_STATE_HOVERED   (1 << 0)
%define UI_STATE_ACTIVE    (1 << 1)
%define UI_STATE_FOCUSED   (1 << 2)
%define UI_STATE_DISABLED  (1 << 3)
%define UI_STATE_LOADING   (1 << 4)
%define UI_STATE_INVALID   (1 << 5)

; ==================================================================
; Scene error codes
; ==================================================================
%define UI_SCENE_OK      0
%define UI_SCENE_BUDGET -1

; ==================================================================
; Layout cursor struct offsets (bytes)
; ==================================================================
%define CURSOR_BOUNDS_X    0   ; f32
%define CURSOR_BOUNDS_Y    4   ; f32
%define CURSOR_BOUNDS_W    8   ; f32
%define CURSOR_BOUNDS_H    12  ; f32
%define CURSOR_AXIS        16  ; u32 (0=row, 1=col)
%define CURSOR_GAP         20  ; f32
%define CURSOR_OFFSET      24  ; f32
%define CURSOR_SIZE        32

; ==================================================================
; Scene struct offsets (bytes)
; ==================================================================
%define SCENE_RECT_BUF     0   ; ptr (8 bytes)
%define SCENE_RECT_LEN     8   ; ptr (8 bytes)
%define SCENE_RECT_CAP     16  ; u64 (8 bytes)
%define SCENE_ICON_BUF     24  ; ptr
%define SCENE_ICON_LEN     32  ; ptr
%define SCENE_ICON_CAP     40  ; u64
%define SCENE_TEXT_BUF     48  ; ptr
%define SCENE_TEXT_LEN     56  ; ptr
%define SCENE_TEXT_CAP     64  ; u64
%define SCENE_SIZE         72

; ==================================================================
; Interaction region struct offsets (bytes)
; ==================================================================
%define REGION_SLOT      0   ; u32
%define REGION_KIND      4   ; u32
%define REGION_ID        8   ; u32
%define REGION_PAD       12  ; padding
%define REGION_BOUNDS_X  16  ; f32
%define REGION_BOUNDS_Y  20  ; f32
%define REGION_BOUNDS_W  24  ; f32
%define REGION_BOUNDS_H  28  ; f32
%define REGION_SIZE      32

; ==================================================================
; Collector struct offsets (bytes)
; ==================================================================
%define COLLECTOR_REGIONS   0   ; ptr (8 bytes)
%define COLLECTOR_LEN       8   ; u64 (8 bytes)
%define COLLECTOR_CAP       16  ; u64 (8 bytes)
%define COLLECTOR_SIZE      24
