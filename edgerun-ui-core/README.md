# EdgeRun UI Core

Purpose: document the current portable UI runtime owned by `edgerun-ui-core` so UI work has a local source of truth.

Intention: keep UI composition backend-neutral, deterministic, freestanding, and consumable by the metal runtime without routing application surfaces through renderer primitives directly.

## Current Situation

`edgerun-ui-core` is the platform-neutral UI layer for the C runtime. It owns:

- scene records, hit regions, clips, text quads, icon quads, and render-budget checks
- design-aligned theme tokens and spacing primitives
- component catalog, parity contracts, projected-field contracts, accessibility metadata, and state matrices
- native emitters for controls, feedback, data-display surfaces, shell surfaces, setup surfaces, and the metal boot UI composition
- layout nodes including rows, columns, cards, grids, masonry, bento grids, scroll areas, dialogs, tooltips, progress rings, and conversation/package/runtime rows
- hosted deterministic tests plus an optional SDL preview shell

The component catalog currently records 59 native components. The canonical component set records 55 base components from `ui/shadcn-ui/apps/v4/registry/bases/base/ui`, and tests assert that every catalog entry has a parity contract and a scene preview.

## Implemented Paths

The core library is built from focused source files rather than a monolithic renderer:

- `src/er_ui_scene.c` and related render files own scene command storage, stats, clipping, and render-budget validation.
- `src/er_ui_components_catalog*.c` own the component registry and reference metadata.
- `src/er_ui_components_contracts.c` owns parity, projection, state, and accessibility contracts.
- `src/er_ui_components_emit.c` owns reusable component emitters.
- `src/er_ui_components_preview.c` owns the component gallery and per-component preview surfaces.
- `src/er_ui_node*.c` own declarative layout node creation, accessibility mapping, layout, and rendering.
- `src/er_ui_runtime*.c` own deterministic focus, input, state, and text handling.
- `src/er_ui_metal.c` composes the metal boot/runtime UI surface from ui-core components.

The metal path already exercises `er_ui_edgerun_metal_surface_emit` at 3840x2160, 1920x1080, 1280x720, and compact 800x720 bounds in tests, with budget checks for native interactive frames.

## Preview And Workflow

Use the root Makefile targets for local UI work:

```bash
make ui-core-test
make ui-core-sdl-build
make ui-core-sdl-run PROMPT="inspect the component gallery"
```

`ui-core-test` configures and tests `.build/edgerun-ui-core`. The SDL shell is optional hosted tooling configured under `.build/edgerun-ui-core-sdl` with `ER_UI_CORE_BUILD_SDL_HOST=ON`.

For scoped progress verification, use:

```bash
make repo-progress REPO_PROGRESS_SCOPE=edgerun-ui-core
```

That scope builds `repo-inspect`, inspects `edgerun-ui-core`, and runs `ui-core-test`.

## Boundaries

App and shell surfaces should compose `er_ui_component_*_emit`, prompt emitters, and layout nodes. Direct `er_ui_scene_push_*` calls belong in renderer primitives, component internals, workspace placement, and reusable component implementation.

Production UI code must remain freestanding. Hosted file loading, SDL preview code, CTest entrypoints, and host-only helpers stay in tests or tools.
