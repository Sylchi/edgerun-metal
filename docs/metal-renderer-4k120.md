# Metal Renderer 4K120 Architecture

Purpose: define the display architecture needed to make 3840x2160 at 120 Hz practical without GPU acceleration.

Intention: keep UI rendering deterministic, CPU-feasible, and compatible with the EdgeRun model where apps emit bounded UI state and the host executor only moves packets and draws admitted scene data.

## Target

The renderer must be designed for 4K at 120 Hz from the beginning:

- Resolution: 3840 x 2160.
- Frame budget: 8.33 ms.
- RGBA framebuffer size: 33.2 MiB.
- Full-frame write bandwidth at 120 Hz: about 3.98 GiB/s.
- Current 4x overdraw admission budget at 120 Hz: about 15.9 GiB/s.

This bandwidth is reachable on modern desktop memory, but only for simple linear writes. It is not a license to repaint complex alpha-blended UI every frame. The architecture must make the common case much cheaper than a full repaint.

## Core Rules

- Rendering is retained, not immediate-only. Apps and services emit a scene tree or display list; the renderer keeps frame state and diffs it.
- UI-core components are the source of UI structure. Metal backends render the emitted scene; they do not invent a parallel widget system.
- Apps do not submit arbitrary drawing. They submit state for predetermined UI-core components with predetermined transitions.
- Free-floating user windows are not a primitive. The normal shell is structured layout: panels, tabs, lists, grids, routes, forms, and app surfaces placed by the shell.
- Overlays are reserved system surfaces. Prompts, OSD, secure confirmation, and critical system UI may overlay app surfaces, but apps cannot randomly create overlapping windows.
- No per-frame heap allocation. Frame memory comes from predeclared arenas and ring buffers with fixed budgets.
- Display memory is preallocated from the chosen user mode. Resolution, refresh rate, pixel format, buffering strategy, tile size, and cache budgets determine the complete allocation plan before the mode is entered.
- No runtime font or path rasterization on the hot path. Glyphs, icons, borders, and common shapes are cached or baked before use.
- Dirty work is tile based. Full-screen redraw is allowed for boot and debugging, not normal interaction.
- Opaque fills and copies are preferred. Alpha blending is bounded to text, icons, shadows, and small translucent surfaces.
- Frame output is deterministic. Work is capped by tile count, primitive count, glyph count, bytes written, and app render budget.
- The renderer never depends on host libc or OS display semantics.

## Pipeline

The display path has four layers:

1. UI-core node/component tree
2. Scene/display-list builder
3. CPU compositor
4. Dumb framebuffer scanout

The framebuffer can initially be UEFI GOP. Later it should become a native mode-set display backend, but the compositor contract stays the same: a linear scanout buffer with format, stride, size, and refresh target.

Apps do not draw pixels directly, and they do not choose arbitrary low-level draw commands. They submit bounded component state that resolves into display-list commands:

```text
node tree -> resolved layout -> display list -> dirty tiles -> framebuffer writes
```

The display list contains only explicit operations:

- solid rect
- bordered rect
- clipped rect
- cached glyph run
- cached icon quad
- cached image/object tile
- copy cached surface

Complex components are lowered before the compositor sees them. Component lowering is the only path from app UI state to display commands.

## Component Admission

The app-facing UI ABI is constrained:

- component kind
- stable component id
- component state
- selected style tokens
- layout slot or shell region
- predetermined transition id
- content references such as text, image object id, or icon id

The app does not control:

- raw pixel writes
- arbitrary paths
- arbitrary shaders
- arbitrary overlapping windows
- unbounded animation curves
- unbounded blur/shadow/effect radii
- direct framebuffer addresses

The shell owns placement. Apps can request UI in admitted regions such as a route content area, side panel, list item, card body, command result, or form. System prompts and OSD are separate trusted overlay planes with their own strict budgets and admission path.

## Tiling

The compositor divides the screen into fixed tiles. A practical starting point is 128x64:

- 3840 / 128 = 30 columns
- 2160 / 64 = 34 rows
- 1020 tiles
- one tile is 32 KiB at RGBA8

Each frame tracks:

- tiles touched by changed display-list commands
- tiles touched by removed commands
- tiles touched by moving surfaces
- tiles invalidated by mode or theme changes

Only dirty tiles are rebuilt. Dirty tiles are processed in scanline-friendly order so writes stay linear and cache/prefetch behavior is predictable.

## Framebuffers

Start with one framebuffer for boot. The production path needs a scanout strategy chosen per backend:

- Single buffer with dirty direct writes when tearing is acceptable or hidden.
- Double buffer with dirty-tile copy to scanout when presentation needs coherence.
- Front buffer plus cached tile backing when memory is tight.

Full double-buffer copy at 4K120 is another 3.98 GiB/s. That is still possible on many systems, but it should not be mandatory. Dirty-tile copy must be the default design.

## Preallocation

The renderer must know its memory plan from the selected user display mode before accepting app UI work. The mode record includes:

- width
- height
- refresh rate
- pixel format
- scanout stride
- buffering strategy
- tile width and height
- maximum dirty tiles per frame
- maximum retained display-list commands
- maximum glyph/cache bytes
- maximum app surface bytes

From that record, the renderer computes all required memory:

```text
scanout_bytes      = stride * height * bytes_per_pixel
backing_bytes      = scanout_bytes if double-buffered, otherwise 0
tile_count         = ceil(width / tile_w) * ceil(height / tile_h)
tile_state_bytes   = tile_count * sizeof(tile_state)
dirty_queue_bytes  = max_dirty_tiles * sizeof(tile_id)
command_bytes      = max_commands * sizeof(display_command)
glyph_cache_bytes  = fixed budget from mode/admission policy
surface_bytes      = fixed budget from mode/admission policy
```

The GOP renderer exposes this as `er_ui_gop_memory_plan_from_tile_plan`. It takes the selected tile plan, backing-buffer count, display-command budget, glyph-cache budget, and app-surface budget, then returns the exact byte reservation or rejects the plan if arithmetic would overflow. The resulting plan is checked with `er_ui_gop_memory_plan_first_budget_violation` before boot continues, so memory admission has the same explicit first-violation reporting as frame rendering.

Mode planning does not require a mapped framebuffer. `ErUiGopMode` records width, height, stride, refresh rate, and pixel format, and `er_ui_gop_tile_plan_from_mode` derives the tile plan before scanout memory exists. `er_ui_gop_bandwidth_plan_from_mode` derives scanout bytes per second, full-frame bytes per second, and admitted overdraw bytes per second from the same mode record. `ErUiGopSurface` remains the render-time view that additionally carries the mapped pixel pointer.

Nothing in the hot path asks for more memory. If the configured cache or command budget is exhausted, the renderer evicts deterministic cache entries, rejects the update, lowers visual quality, or keeps the previous frame according to the scheduling policy.

This matters because GPU memory should stay available for AI workloads. The display system gets a predictable reservation based on the user's chosen resolution and refresh rate; it does not grow just because an app submits a larger UI.

The current GOP backend exposes this as a render plan plus caller-owned dirty tile buffers. The plan tells the caller how many tile mark bytes and dirty queue bytes to reserve before rendering begins. Scene dirty helpers can mark all display-list bounds or diff two index-stable retained scenes without allocating. The backend can raster one planned tile or a complete dirty tile list; overflowed lists are rejected so stale pixels are not silently presented. Render stats account bytes, primitives, text quads, requested dirty tiles, rendered tiles, clipped primitives, and rejected primitives. The boot UI now computes this plan with static buffers, derives and logs a memory reservation for the selected mode, derives a frame budget from the selected mode, rejects over-budget frames before committing retained state, uses full-frame render when coverage is full, and uses dirty-list render when coverage is partial.

## Pixel Format And Memory

The backend must expose:

- physical base
- virtual/write address
- width
- height
- stride
- format
- bytes per pixel
- refresh target
- write-combining status when known

The x86 path should eventually configure framebuffer memory as write-combining through PAT/MTRR once the runtime owns page tables. Until then GOP framebuffer writes are functional but not the final performance baseline.

All hot pixel loops are structured for later SIMD replacement. Scalar C stays as the reference implementation, but loops must remain simple:

- linear row pointers
- no callback per pixel
- no heap access per pixel
- minimal branches inside spans

## Text

Text must not rasterize glyphs during normal frames.

The renderer owns a font cache:

- baked boot font atlas for early boot
- runtime font face only outside the hot path
- glyph cache keyed by font id, size, axis tuple, and glyph id
- shaped text cached as glyph runs
- dirty glyph runs rerender only their affected tiles

For the metal boot UI, UI-core can emit varfont text while we validate architecture. The long-term path is to let UI-core emit text runs against a renderer font cache so component code stays shared and metal controls raster cost.

## Frame Admission

Metal render stats are checked against an explicit frame budget after raster work. This is not the final scheduler, but it gives the executor a deterministic accounting contract: pixels, bytes, blended pixels, text pixels, rects, text quads, rendered tiles, requested dirty tiles, clipped primitives, and rejected primitives must all stay inside declared limits before the frame is considered acceptable. The GOP renderer exposes `er_ui_gop_frame_budget_from_plan` so firmware and later runtime code derive the same budget from the selected display mode, UI scene budget, and declared overdraw allowance.

## App Surfaces

Apps receive UI budgets before launch:

- maximum nodes
- maximum display-list commands
- maximum dirty tiles per frame
- maximum glyphs/icons/images referenced
- maximum persistent surface bytes
- maximum frame submission rate

The compositor accounts these budgets before accepting a frame. An app that exceeds its budget does not get implicit host authority; its update is rejected or degraded deterministically.

App surfaces are logical. They can be cached, moved, clipped, or occluded by the compositor without app involvement.

## Scheduling

Frame time is divided into deterministic phases:

1. collect admitted UI updates
2. resolve layout for changed subtrees
3. diff display lists
4. build dirty tile list
5. raster dirty tiles
6. present/copy dirty tiles

Each phase has a byte/count/time budget. If the frame cannot complete inside budget, the renderer chooses a deterministic fallback:

- keep previous frame
- render fewer admitted dirty tiles by stable priority
- lower animation rate
- skip nonessential effects

Input must stay ahead of visual polish. The UI should remain responsive even if optional visual updates are deferred.

## Hardware Plan

The first backend is GOP because it already exists and validates the CPU compositor. The next backend must separate display discovery from rendering:

- framebuffer backend interface
- mode record
- scanout buffer record
- dirty-present operation
- vblank or timer pacing when available

GPU acceleration is not required. A native display driver can still use the card as a dumb scanout engine: set a mode, map a framebuffer, and let the CPU compositor write pixels.

## Near-Term Work

1. Keep the UI-core node/component path as the only UI authoring path.
2. Add a metal renderer cache object for glyph atlases and display-list state.
3. Use the current retained-scene diff helpers in the boot renderer path.
4. Add retained previous-scene state so boot can produce partial dirty lists after the first frame.
5. Feed frame-budget violations back into the retained-frame scheduler.
6. Move boot UI from one-shot render toward retained scene state.
7. Add a synthetic 4K benchmark in host tests for tile fill, glyph blend, and dirty copy.
8. Add a framebuffer backend interface so GOP is one implementation, not the renderer architecture.
