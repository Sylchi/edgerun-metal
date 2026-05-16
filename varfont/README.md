# vr-font (zero-dependency variable-font renderer skeleton)

This is a C implementation scaffold for a variable-font-to-OpenGL texture workflow with no
runtime third-party dependencies. It provides:

- SFNT/TrueType table parsing (`head`, `maxp`, `loca`, `glyf`, `hhea`, `hmtx`, `cmap`, `fvar`)
- Basic glyph shaping scaffold (`codepoint -> glyph_id` + advances)
- Glyph outline decode + rasterized grayscale atlas upload interface
- Texture atlas with dynamic growth and pluggable GL callbacks
- C API for axis control and vertex batch generation

## Current status and limits

- **Partially complete** for variable interpolation: `fvar`/`avar` axis mapping is implemented (including fixed-point axis parsing and axis remapping), `gvar` tuple decoding/scalar application is applied during bake/advance, and composite glyph decomposition for `glyf` is now implemented for recursive outline construction. `CFF2` is still TODO.
- Includes basic `kern` format-0 pair kerning pass during shaping.
- Cache entries are invalidated automatically when axis or point size changes.
- Public API now includes `vr_font_clear_cache()`.
- Vertex batches carry atlas page IDs (`vr_vertex_t::atlas_id`).
- Added atlas texture/range helpers: `vr_font_atlas_count`, `vr_font_atlas_texture`, and `vr_font_build_vertex_batches_by_atlas`.
- Draw usage is atlas-batched: one draw call per range with `atlas_id`, using `glDrawArrays(GL_TRIANGLES, range.start_vertex, range.vertex_count)` after binding `atlas_texture(atlas_id)`.
- No complex shaping (GSUB/GPOS/Bidi). This is a fallback-compatible foundation.
- Rasterizer uses 2x2 supersampling for anti-aliased coverage output.
- CMap support is constrained to formats 4 and 12; other formats return `VR_ERR_UNSUPPORTED`.

## Files

- `include/vr_font.h` public API
- `src/vr_font_internal.h` private declarations
- `src/vr_font_utils.c` file and table parser
- `src/vr_font_shape.c` shaping facade
- `src/vr_font_raster.c` outline decode + rasterization
- `src/vr_font_atlas.c` glyph cache and atlas
- `src/vr_font.c` lifecycle entrypoints
- `examples/main.c` quick compile-time smoke entry

## Build

```bash
Install SDL2 development package in your toolchain.
mkdir build
cd build
cmake ..
cmake --build .
./vrfont_demo fonts/Geist[wght].ttf
```

### Geist variable font

Download Geist from:

```bash
mkdir -p fonts
curl -L -o fonts/Geist[wght].ttf https://raw.githubusercontent.com/vercel/geist-font/main/fonts/Geist/variable/Geist%5Bwght%5D.ttf
```

Run:

```bash
./build/vrfont_demo fonts/Geist[wght].ttf
```
