# EdgeRun UI Relay Architecture

## Separation

UI is not a root authority. It never knows what the objects mean. It renders
slots and emits narrow intent receipts:

```
user hits (x,y)  →  UI emits "slot 7 activated"  →  App resolves to action
user scrolls     →  UI emits "view delta = (0, 12)" →  App adjusts state
app updates      →  App emits scene description →  UI renders natively
```

The UI domain and the App domain are fully decoupled. They communicate only
over a message channel (the "relay"). Each message is a self-contained binary
packet. No shared memory, no pointers, no address space coupling.

This decoupling lets one host render scenes from multiple apps, or one app
broadcast its scene to many devices simultaneously.

## Authority Boundary

```
user → input device → [UI Domain] → relay → [App Domain] → storage/network
                             ↓                         ↓
                      scene renderer              business logic
                      zero authority               full authority
                      no state                      owns state
                      no storage access             owns data
```

The UI domain:
- Renders whatever scene it receives, nothing more
- Collects raw input events and forwards them
- Has no access to storage, identity keys, or app data
- Cannot make decisions — only display what it is told

The App domain:
- Owns all business logic, state, and data
- Decides what to render and when
- Handles input events and updates state
- Has authority (delegated from user through allocator)

Both sides are independent processes that can start, stop, and crash without
corrupting the other. The relay channel is the only connection.

## Relay Protocol

Messages are self-contained binary packets. Every message begins with a header:

```
Offset  Size  Field
0       4     magic: 0x4552524C ("ERRL" = EdgeRun Relay)
4       1     version: 0x01
5       1     message_type
6       4     sequence_number (per-type monotonic)
10      2     payload_length (bytes after header)
12      *     payload
```

Total header: 12 bytes.

### Message Types

| Type | Code | Direction | Payload |
|------|------|-----------|---------|
| SceneUpdate | 0x01 | App → UI | packed Render IR scene |
| InputEvent | 0x02 | UI → App | serialized input events |
| Resize | 0x03 | UI → App | viewport width/height (u16 each) |
| Hover | 0x04 | UI → App | pointer x/y (i16 each) |
| IntentReceipt | 0x05 | UI → App | user intent (kind + slot_id + coords) |
| Ack | 0x80 | bidirectional | acked sequence number |

### SceneUpdate (0x01)

The payload is a packed Render IR scene — a pre-laid-out, pre-styled sequence
of render primitives (filled rects, textured quads, icons, text quads). The
App (Zig/WASM) handles all component rendering, layout, and styling. The
Host (ASM) receives these primitives and rasterizes them directly.

Format:

```
scene_header (19 bytes):
  magic:     4 bytes  "ERS\0"
  version:   1 byte   0x01
  rect_count:     u16
  text_vert_count: u16
  icon_count:     u16
  icon_line_count: u16
  image_vert_count: u16
  payload_bytes:  u32

rect records: rect_count × 60 bytes (15 floats each)
textured vertices: text_vert_count × 32 bytes (8 floats each)
icon records: icon_count × 36 bytes (9 floats each)
icon line vertices: icon_line_count × 24 bytes (6 floats each)
image vertices: image_vert_count × 32 bytes (8 floats each)
```

The float stride and buffer layout match exactly what `er_render_ir_push_*`
functions expect in `render_ir.asm`. The Host writes them directly into the
Render IR buffer and calls `sw_fb_render_ir_rects` / `sw_fb_render_ir_icons`.

The scene is always a complete frame. No incremental diffs — the packed
Render IR is small enough (1-4 KB for typical UIs) that sending the full
frame each time simplifies both sides.

### InputEvent (0x02)

The payload is one or more event records. Each record is 12 bytes:

```
Offset  Size  Field
0       1     kind: 0=pointer_down, 1=pointer_move, 2=pointer_up, 3=key, 4=scroll
1       1     modifiers: bit 0=ctrl, 1=meta, 2=alt, 3=shift
2       2     x: i16 scaled coordinate (12 fractional bits)
4       2     y: i16 scaled coordinate
6       6     data: key scancode/scroll delta/utf8 byte
```

Multiple event records can be batched in one message for efficiency.

### IntentReceipt (0x05)

UI emits this when the user activates a UI element:

```
Offset  Size  Field
0       1     kind (slot_activate=0, value_change=1, scroll_to=2)
1       1     flags
2       4     slot_id (from the scene's component tree)
6       4     value: changed value (checkbox state, slider position, etc.)
```

The App maps slot_id to meaning. The UI never knows what a slot_id
represents — it just emits the opaque id.

## Transport Abstraction

The relay messages are transport-agnostic. The same binary format works over:

### Same-Process (Default)

UI and App run as coroutines on the same CPU. The App exports functions
that the Host calls directly:

```
host loop:
  call app.er_app_render_scene()   → packed_ir (ptr, len) in WASM mem
  sw_fb_render_ir_rects(packed_ir) → framebuffer
  collect input                    → event bytes
  write events to WASM memory
  call app.er_app_handle_event()   → app updates state
```

### Serial / UART

Messages are framed with HDLC-style flag bytes (0x7E) between packets. The
relay works over any UART — COM1, Bluetooth HCI UART, or USB CDC-ACM.

### BLE Advertisement

BLE advertising data is limited to 31 bytes. A SceneUpdate must fit in one
advertisement, or the app uses a multi-advertisement scheme:

- Simple scenes (notification badge, status icon) fit in one 31-byte adv
- The relay header is 12 bytes, leaving 19 bytes for scene data
- For larger scenes, use extended advertising or LE Connection

The BLE transport is receive-only for SceneUpdate (app → UI can advertise).
Input events flow through a different channel (serial, or BLE connection).

### Network (TCP/UDP)

Length-prefixed messages over a TCP connection or UDP datagrams. The 4-byte
length prefix before each 12-byte relay header enables streaming reassembly.

## Multi-App Compositing

The UI host can receive scene messages from multiple apps and composite them:

```
┌─────────────────────┐
│  App A: Scene 1     │───┐
│  App B: Scene 2     │───┤
│  App C: Scene 3     │───┤
└─────────────────────┘   │
                          ▼
                  ┌────────────────┐
                  │  UI Host       │
                  │  composites    │
                  │  and renders   │
                  └────────────────┘
                          │
                          ▼
                  ┌────────────────┐
                  │  Display(s)    │
                  └────────────────┘
```

Each app gets a surface rectangle (defined by the host) and sends full scenes
for that surface. The host blits each app's rendered output to its assigned
region. Apps don't know about each other.

This enables:
- Split-screen views of multiple apps
- Picture-in-picture overlays
- System status bar composited over app content
- Window manager model (each window = one app scene)

## Multi-Device Rendering

A single app can broadcast its scene to multiple UI hosts:

```
┌─────────────────────┐
│  App                │
│  (one authority)    │
└─────────────────────┘
          │
          ├── relay ──→ UI Device 1 (framebuffer)
          ├── relay ──→ UI Device 2 (framebuffer)
          ├── relay ──→ UI Device 3 (framebuffer)
          └── relay ──→ Web Browser (Canvas)
```

Each UI device renders the same scene independently. Input events from any
device flow back to the app. The app processes each event and may emit an
updated scene.

- Devices may render at different resolutions (app scene is layout-agnostic)
- Devices may have different input capabilities (touch vs keyboard vs gamepad)
- Devices may fail — app continues, new device can subscribe mid-stream

## App Authoring API

The App side (Zig/WASM) provides a declarative API for building scenes:

```zig
// Build a scene tree
const view = ui.column(.gap(8), .padding(16),
    ui.text("EdgeRun", .heading),
    ui.button(.id(1), "Start", .primary),
    ui.row(.gap(4),
        ui.checkbox(.id(2), "Option A"),
        ui.checkbox(.id(3), "Option B"),
    ),
    ui.card("Status", "All systems nominal", .subtle),
);

// Serialize to relay message
const scene_bytes = ui.encode(view);
relay_send(.scene_update, scene_bytes);

// Handle incoming events
while (relay_recv()) |msg| {
    switch (msg.type) {
        .input_event => handle_input(msg.payload),
        .resize => handle_resize(msg.payload),
        .hover => handle_hover(msg.payload),
    }
}
```

The `ui.encode()` function runs the full rendering pipeline internally:
build scene tree → layout → style → pack to Render IR buffers → serialize
the packed buffers to the primitive scene wire format. The ASM host only
sees raster primitives, never component trees.

All 57 component types live in Zig (`ui/components/Component.zig`). The
Zig app renders them to Render IR buffers using the same pipeline already
used for the web target. The only change is the output: instead of
rasterizing to pixels, serialize the packed buffers for the relay.

## Visual Builder

The visual builder is a separate tool that outputs Zig source code for an app.

```
drag-and-drop canvas
  → arranges components in a tree
  → sets properties (labels, variants, ids)
  → attaches event handlers (on_click, on_change)
→ outputs .er source or Zig code
→ compile via WASM compiler → relay-ready app
```

The builder is itself an EdgeRun app. It runs in the same WASM runtime as
any other app. It exports its own scene (the builder UI) and handles events
(component placement, property editing).

This means building apps does not require a separate toolchain exit. The
entire authoring workflow runs inside EdgeRun: build → compile → preview →
release.

The compiler (`wasm_compiler_source.asm`) already parses a source language.
The visual builder is an alternative frontend that generates the same source.

## Implementation Plan

### Phase 1 — Relay Protocol

- Define `relay_constants.inc` (ASM) and `relay.zig` (Zig) with message types
  and wire format
- Implement encode/decode helpers for header, events, and intent receipts
- Test: roundtrip all message types in both ASM and Zig

### Phase 2 — Primitive Scene Format

- Define `primitive_scene.inc` (ASM) and `primitive_scene.zig` (Zig) with
  the packed Render IR wire format (header, rect records, vertex records)
- Implement encode (Zig) and decode (ASM) for the compact scene format
- Encode: pack Render IR float buffers into sequential binary
- Decode: parse binary header, write floats directly into Render IR buffers
- Test: roundtrip known scene → verify sw_fb output matches

### Phase 3 — App Scene Export (Zig)

- Add `er_ui_export_scene()` to `app_runtime.zig`: pack the current frame's
  Render IR buffers (packed_rect_floats, packed_text_vertex_floats, etc.)
  into the primitive scene wire format; return (ptr, len)
- The App already packs UI commands into Render IR buffers — this exports
  them instead of rasterizing to pixels
- Keep pixel-render path (`er_ui_render_frame`) for backward compatibility
- Test: known app state → export → verify packed bytes match expected

### Phase 4 — Host Scene Rasterizer (ASM)

- Wire a simple relay loop in `kernel_main.asm`:
  `call app.er_app_render_scene → deserialize Render IR → sw_fb_render_ir_*`
- The host only needs: parse header skip to rect/text/icon data, memcpy
  into Render IR staging buffers, call rasterizer functions
- All component rendering is done by the App in Zig — zero component
  knowledge on the host
- Test: kernel boots, calls WASM app, renders its scene to framebuffer

### Phase 5 — Multi-App Support

- Host maintains N app slots, each with separate relay buffer
- Host composites scenes (Z-order, split-screen)
- App lifecycle: launch, pause, resume, destroy
- Test: two apps running, both scenes visible, input routed correctly

### Phase 6 — Visual Builder

- Builder app (Zig) as a drag-and-drop component tree editor
- Outputs EdgeRun source language or Zig code
- Preview mode: compiled app runs as child WASM, scene appears in builder
- Release mode: compiles to standalone app object

### Files Summary

| File | Purpose |
|------|---------|
| `asm/x86_64/relay_constants.inc` | Message types, header format, event record layout |
| `asm/x86_64/relay.inc` | Relay macros: send/recv with inline framing |
| `asm/x86_64/primitive_scene.inc` | Packed Render IR wire format constants and helpers |
| `asm/x86_64/kernel_main.asm` | Relay loop: app → render → input → app |
| `edgerun-zig/src/relay.zig` | Message encode/decode, transport interface, wire format |
| `edgerun-zig/src/primitive_scene.zig` | Pack Render IR buffers to wire format |
| `edgerun-zig/src/app_runtime.zig` | Add `er_ui_export_scene()`, event dispatch |

### Non-Goals

- No shared memory between apps. Every message is a self-contained copy.
- No scene diffs. Full scene each frame — simplifies both sides.
- No framebuffer access from apps. The UI host owns the display.
- No compositor authority. The host composites, but has no say in app logic.
- No component rendering in ASM. The host only rasterizes packed primitives.
- No BLE GATT implementation yet. BLE transport is Phase 7+.
