# edgerun-ui-core

`edgerun-ui-core` renders composable UI. It should stay free of app, storage,
identity, routing, manifest, and durable-object policy.

## Boundary

Keep:

- UI primitives: bounds, colors, spacing, theme, text, icons.
- Painter and scene command buffers.
- Node composition and component rendering.
- Transient runtime interaction helpers: focus, pointer, keyboard, text input,
  scroll, toggles, sliders, drag/drop.
- Surface rendering and surface memory/bandwidth calculators.
- Asset pack validation for caller-provided UI assets.

Do not add:

- App launchers, app stores, domains, ledgers, device policy, or routing.
- Storage access, object persistence, object signing, or identity authority.
- Demo/gallery/showcase state in the core library.
- Source-framework metadata such as docs routes, source component names,
  fixture names, or port mappings.
- A second serialization format inside UI. Durable/wire data belongs to
  `edgerun-object` above this layer.

## Source Of Truth

Nodes are the canonical composable UI model. Components should either be node
constructors or internal emit helpers used by node rendering. Avoid maintaining
parallel registries that describe the same component set.

Scene commands are the canonical render output. They are frame-local data for
the renderer and hit testing, not durable app state.

Runtime state is transient interaction state. Apps own durable values and feed
them back into nodes/components each frame.

Asset specs are in-memory validation inputs. Durable asset packages should be
canonical objects outside UI core.

## Remaining Simplification

1. Collapse the component catalog into the node/component definitions.
2. Make component emitters internal where nodes already cover the same surface.
3. Keep `uint32_t` widget IDs frame-local; use identity/object IDs outside UI.
4. Keep runtime state transient and remove durable app-value ownership from it.
5. Keep surface planning as calculators only; app manifests own final budgets.
