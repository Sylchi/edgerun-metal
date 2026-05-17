# edgerun-ui-core

Purpose: port EdgeRun's Rust `edgerun-ui-core` platform-neutral UI layer to C without changing the product model.

Implemented portable slices:

- primitive bounds and float helpers used by scene, painter, and future component code
- colors, rects, clips, hits, drag sources, drop targets, icon/text quads, and transitions
- painter facade for panels, soft cards, dividers, hits, drag/drop regions, quads, and transitions
- semantic palette/theme records for color schemes, accents, radius scales, density, and token resolution
- required `vrfont` integration for converting variable-font vertex batches into scene text quads
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
