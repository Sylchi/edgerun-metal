# Semantic UI

The UI should not be hand-authored from text descriptions. Data should stay structured from parse to render:

```text
raw bytes -> parsed facts -> semantic items and relations -> view intent -> deterministic presentation -> components -> scene
```

The LLM may help turn a user request into intent and priority, but the host owns parsing, indexing, ranking, layout, rendering, and hit regions. This avoids the wasteful loop where data is flattened into prose, parsed back into structure, transformed again, and then rendered as mostly text.

## Goals

- Apps provide meaning, not widget placement.
- Important facts get more pixels automatically.
- State, privacy, risk, and resource pressure have consistent color and icon treatment.
- The same semantic model can render as overview, inspection, schedule, debug, graph, or timeline views.
- UI rendering remains deterministic, preallocated, and dependency-free.

## Model

Semantic items describe what something is and why it matters:

```zig
SemanticItem{
    .id = 124001,
    .kind = .resource,
    .label = "RAM fit",
    .value = "53%",
    .detail = "selected path x grant",
    .importance = .primary,
    .state = .warning,
    .progress = 0.53,
}
```

Intent describes what the user wants to see or do:

```zig
SemanticIntent{
    .mode = .schedule,
    .focus = .resources,
    .density = .normal,
}
```

The renderer chooses the view:

- primary items become metric cards
- normal items become rows
- progress values become bars
- state maps to color and badge treatment
- actions become buttons when enough space exists
- low-priority data stays compact
- timeline intent maps facts onto a horizontal time viewport with vertical semantic lanes

## Pipeline

The intended pipeline is:

```text
user request
 -> intent object
 -> host query/index/transform
 -> semantic model
 -> semanticView
```

The LLM should emit small intent and priority objects. It should not repeatedly write full UI descriptions or code. The host should transform semantic objects into UI directly.

## First Implementation Slice

`Component.View.semanticView` renders a bounded semantic item list using existing cards, rows, badges, progress bars, and buttons. It is deliberately small: a stable API surface that current apps can adopt while graph/timeline/relation renderers evolve behind it.

`Component.View.timelineViewport` renders semantic time as a deterministic left-to-right surface. The user request becomes an intent and viewport state; the host maps events, resources, tool calls, messages, and artifacts into lanes. Horizontal position means time, vertical lanes mean kind of meaning, and zoom/offset decide how much detail is visible without changing the underlying data. `TimelineViewportState`, pan/zoom/reset controls, and action handling belong to the component API so every app exposes the same interaction model instead of drawing one-off timeline tools.
