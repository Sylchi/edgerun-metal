# edgerun-ui-core

Purpose: port EdgeRun's Rust `edgerun-ui-core` platform-neutral UI layer to C without changing the product model.

Implemented portable slices:

- primitive bounds and float helpers used by scene, painter, and future component code
- colors, rects, clips, hits, drag sources, drop targets, icon/text quads, and transitions
- painter facade for panels, soft cards, dividers, hits, drag/drop regions, quads, and transitions
- shadcn demo catalog and parity metadata ported from the Rust UI core source, including 57 component specs, slots, states, identifier resolution, and port mappings
- reusable EdgeRun component contracts ported from Rust, including stable selectors, state matrices, projected input fields, and accessibility role/label metadata
- semantic palette/theme records for color schemes, accents, radius scales, density, and token resolution
- shadcn preset-code recipes, base62 encode/decode parity, style-family palettes/specs, extracted style tokens, and source-capture provenance
- required `vrfont` integration for converting variable-font vertex batches into scene text quads
- Rust-compatible UI record codec for deterministic setup/admission records using caller-owned buffers
- initial setup and YubiKey grant ceremony state machines plus reusable node-surface builders
- fingerprint, TPM, YubiKey, and user-device admission grant records using the Rust setup record format
- cursor-based opacity and translation for grouped commands
- scene budgets for native, browser, and public showcase frames
- deterministic tests for validation, clipping, topmost interaction queries, transition easing, budget checks, painter output, theme resolution, and varfont text-quad emission

The runtime input slice includes:

- key and modifier records
- UTF-8 text buffer with character-index cursor movement
- text insertion, deletion, word deletion, submit/change actions, cursor display strings, and deterministic tests
- runtime state for transitions, scroll offsets, toggles, sliders, open values, selected tabs, text values, and deterministic tests
- focus state, focusable/text hit classification, open focus scopes, scoped focus cycling, and deterministic tests
- pointer, wheel, key, drag/drop, activation, escape, and blur dispatch returning canonical `er_ui_action_t` records
- tiled workspace scene emission publishes one drop target per surface tile, so apps can rely on core-owned surface placement

## Component System

App and shell surfaces should compose `er_ui_shadcn_*_emit` and
`er_ui_*_prompt_emit` component functions instead of drawing one-off rectangles,
ASCII glyphs, and ad hoc hit targets. Components own their visual density,
radius, borders, semantic hits, projected-state contracts, and Tabler-compatible
canonical icon IDs. Direct `er_ui_scene_push_*` calls are reserved for renderer
primitives, component internals, workspace placement, and genuinely new
component implementations that are then reused by surfaces.

Layout primitives are first-class nodes: use `er_ui_node_row`,
`er_ui_node_column`, `er_ui_node_grid`, `er_ui_node_masonry`,
`er_ui_node_bento_grid`, and `er_ui_node_scroll_area` for app structure.
`er_ui_node_set_spacing` defines padding, gap, and margin together; bento items
use `er_ui_node_set_grid_span`; draggable/reorderable surfaces use
`er_ui_node_set_draggable`, `er_ui_node_set_drop_target`, or
`er_ui_node_set_reorderable`. Visual polish that belongs to a reusable node is
also declared on the node with `er_ui_node_set_background_gradient` and
`er_ui_node_set_transition`, so gradients and motion stay in the component
system rather than scattered across app surfaces.

Production code is freestanding:

- `src/` does not depend on host libc allocation, string, or math APIs.
- dynamic storage uses explicit `er_ui_allocator_t` callbacks supplied by the caller.
- the library target builds with `-ffreestanding -fno-builtin` and does not link host `m`; hosted tests provide a test allocator.

Build and test:

```bash
cmake -S edgerun-ui-core -B .build/edgerun-ui-core -G Ninja
cmake --build .build/edgerun-ui-core
ctest --test-dir .build/edgerun-ui-core --output-on-failure
```

The root wrapper is:

```bash
make ui-core-test
```
