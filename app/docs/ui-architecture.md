# UI Architecture

The app UI path is object-backed and built around bounded binary codecs. The root
README keeps the project overview; this file owns the detailed UI streaming and
transport notes that are backed by current code.

## Streaming

If it crosses a device boundary, it is an object.

Everything that moves between devices, including IR frames, input events, hit
results, UI component trees, image textures, and video frames, is encoded as a
bounded binary payload and can be wrapped by `object.NodeWriter` as a canonical
`object.zig` `Kind.bytes` or `Kind.tree` payload.

### Object Types

| What | Object Kind | Body | Reference |
|------|-------------|------|-----------|
| App IR frame | `bytes` | `render.ir.BodyHeader` + float arrays | `app/src/render/ir.zig`: `encodeBody` / `applyBody` |
| Presentation receipt | struct | destination, transport, primitive requirements | `app/src/render/present.zig` |
| UI component tree | `bytes` | `ERuI` header + fixed records + string table | `app/src/ui/codec.zig` |
| Image texture | raw body | `ERIMG001` tiled RGBA | `app/src/media/runtime_image.zig` |
| Input event | `bytes` | Binary event record | `app/src/app_input_event.zig` |
| Hit result | `bytes` | Hit ID + position + scope | `app/src/ui/hit.zig` |

### Pipeline

```text
Device A (app host)                          Device B (renderer)
 App produces IR                              receive object
  -> render.ir.encodeBody() object bytes        -> object.View.decode()
  -> object.NodeWriter     ----------------->   -> render.ir.applyBody()
                         (transport)            -> backend renders

 Media decoded locally                        receive image body
  -> ERIMG tiles           object body          -> ERIMG decode
  -> object.NodeWriter    ----------------->   -> upload as texture
                                                -> IR references it
```

### Current Packing Path

`app/src/render/pipeline.zig` is the current scene-to-IR packing path. It packs
`ui.Command` values into `render.ir.Buffers`, prepares font assets, writes base
and overlay buffers, and delegates final presentation checks to
`app/src/render/present.zig`.

- `render.ir.Layer` currently has `base` and `overlay` layers.
- `render.ir.encodeBody` serializes base and overlay float buffers into one body.
- `render.ir.applyBody` restores those buffers from the encoded body.
- `render.present` validates destination, transport, primitive count, and resource
  requirements.

### Media Objects

Images and video frames are decoded on the source device into `ERIMG001` tiled
RGBA by `app/src/media/runtime_image.zig`. The current code owns the binary image
body (`encodeRgba`, `encodeRgbaTiled`, `decode`, `decodeRgbaInto`); object
wrapping happens through the generic `object.NodeWriter` path when a caller needs
canonical storage or transport. On the receiver, the body is decoded back into
ERIMG tiles, uploaded as a texture, and referenced by `render.ir` image vertices.
No raw pixel stream needs a separate protocol.

### Fragmentation

Large payloads use `Kind.tree`; children with offset/len fields provide built-in
reassembly:

```text
tree object (logical_len = 74 KB)
  child offset=0    len=256
  child offset=256  len=256
  ...
```

No separate fragment protocol is defined in the UI layer. See `app/src/object.zig`:
`Child`, `NodeWriter`, and `View.decode`.

### Module Boundaries

| Module | Responsibility |
|--------|----------------|
| `app/src/render/ir.zig` | IR types, push functions, float-buffer body encode/decode |
| `app/src/render/pipeline.zig` | Scene -> IR packing, text glyph packing, presentation resource helpers |
| `app/src/render/present.zig` | Presentation target, transport, resource validation, receipt |
| `app/src/render/backends/` | Pixel-level renderers |
| `app/src/media/runtime_image.zig` | `ERIMG001` tiled RGBA encode/decode |
| `app/src/ui/codec.zig` | `ERuI` component tree records, BLE frame helpers, object wrapping |
| `app/src/ui/components/Component.zig` | Component API including semantic and timeline views |
| `app/src/app_input_event.zig` | Input event binary format and object wrapping |
| `app/src/ui/hit.zig` | Hit IDs, hit metadata, hit object body encode/decode |
| `app/src/object.zig` | Canonical object format, children, owners, envelopes, views |

## Relay

UI is not a root authority. It renders component trees/IR and emits narrow hit or
intent results. Current app-side code has concrete `ERuI` component tree records
and BLE-sized frame helpers in `app/src/ui/codec.zig`; a separate `ERRL` relay
packet format is not implemented in this checkout.

```text
user hits (x,y)  ->  UI emits hit id / intent  ->  App resolves to action
app updates      ->  App emits UI tree or IR    ->  UI renders natively
```

### Authority Boundary

```text
user -> input device -> [UI Domain] -> relay -> [App Domain] -> storage/network
                             |                         |
                      scene renderer              business logic
                      zero authority               full authority
                      no state                      owns state
```

The UI domain renders whatever scene it receives, collects raw input, and has no
access to storage, identity keys, or app data. The app domain owns business
logic, state, and data.

### Current UI Codec

`app/src/ui/codec.zig` owns the implemented component tree body:

```text
Offset  Size  Field
0       8     magic: "ERuI\0\0\0\0"
8       2     version: 1
10      2     axis: 0 column, 1 row
12      2     gap
14      2     padding
16      2     node_count
18      2     root_count
20      ...   fixed 16-byte records, then string table
```

The same module can wrap the body as a canonical object with `objectNode` or
`objectNodeOwned`.

### Transport Abstraction

BLE-sized transport framing is implemented as `BleFrame` with magic `ERUI`,
version `1`, `stream_id`, `sequence`, `kind`, and body. The current legacy BLE
advertisement budget is `31` bytes, with an implemented manufacturer-payload
limit of `27` bytes after advertising overhead.

### Multi-Device

The intended multi-device path is for one app scene to reach multiple UI hosts,
with each host rendering independently and sending input back through explicit hit
or intent messages. The implemented pieces in this checkout are the canonical UI
body codec, hit object codec, IR body codec, image body codec, and BLE-sized frame
helpers; full multi-host routing still depends on the identity-cell transport
integration tracked in the roadmap.
