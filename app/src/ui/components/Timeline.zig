const app_surfaces = @import("AppSurfaces.zig");
const interaction = @import("../interaction.zig");
const primitives = @import("Primitives.zig");
const ui = @import("../core.zig");

pub const Block = struct {
    id: u32,
    start: f32,
    end: f32,
    value: f32,
    color: ui.Color,
    selected: bool = false,
};

pub const LaneProps = struct {
    label: []const u8,
    lane_index: usize,
    lane_count: usize,
    blocks: []const Block,
    border: ui.Color,
    label_color: ui.Color,
};

pub const ViewportLane = struct {
    label: []const u8,
    blocks: []const Block,
};

pub const Mark = struct {
    x: f32,
    label: []const u8,
};

pub const ViewportMark = struct {
    at: f32,
    label: []const u8,
};

pub const ViewportControls = struct {
    pan_left_id: u32,
    pan_right_id: u32,
    zoom_out_id: u32,
    zoom_in_id: u32,
    reset_id: u32,
};

pub const ViewportAction = enum {
    pan_left,
    pan_right,
    zoom_out,
    zoom_in,
    reset,
};

pub const ViewportState = struct {
    offset: f32 = 0.0,
    scale: f32 = 1.0,
};

pub const ViewportProps = struct {
    title: []const u8 = "",
    detail: []const u8 = "",
    lanes: []const ViewportLane,
    marks: []const ViewportMark = &.{},
    viewport: ViewportState = .{},
    controls: ?ViewportControls = null,
    fill: ?ui.Color = null,
    border: ?ui.Color = null,
    axis_color: ?ui.Color = null,
    label_color: ?ui.Color = null,
    label_w: f32 = 82.0,
    inset: f32 = 14.0,
    radius: f32 = 8.0,
};

pub const Window = struct {
    start: f32,
    end: f32,
};

pub fn actionForHit(hit_id: u32, controls: ViewportControls) ?ViewportAction {
    if (hit_id == controls.pan_left_id) return .pan_left;
    if (hit_id == controls.pan_right_id) return .pan_right;
    if (hit_id == controls.zoom_out_id) return .zoom_out;
    if (hit_id == controls.zoom_in_id) return .zoom_in;
    if (hit_id == controls.reset_id) return .reset;
    return null;
}

pub fn applyAction(state: *ViewportState, action: ViewportAction) void {
    switch (action) {
        .pan_left => pan(state, -1.0),
        .pan_right => pan(state, 1.0),
        .zoom_out => zoom(state, 0.75),
        .zoom_in => zoom(state, 1.35),
        .reset => state.* = .{},
    }
}

pub fn window(offset: f32, scale: f32) Window {
    const width = 1.0 / @max(0.05, scale);
    const start = @max(0.0, @min(1.0, offset));
    return .{ .start = start, .end = @max(start + 0.01, start + width) };
}

pub fn unitInWindow(value: f32, start: f32, end: f32) ?f32 {
    if (end <= start) return null;
    if (value < start or value > end) return null;
    return ui.clampUnit((value - start) / (end - start));
}

pub fn blockInWindow(block_value: Block, start: f32, end: f32) ?Block {
    if (end <= start) return null;
    const block_start = @max(start, block_value.start);
    const block_end = @min(end, @max(block_value.start, block_value.end));
    if (block_end <= block_start) return null;
    return .{
        .id = block_value.id,
        .start = ui.clampUnit((block_start - start) / (end - start)),
        .end = ui.clampUnit((block_end - start) / (end - start)),
        .value = block_value.value,
        .color = block_value.color,
        .selected = block_value.selected,
    };
}

fn pan(state: *ViewportState, direction: f32) void {
    const window_w = 1.0 / @max(0.05, state.scale);
    const max_offset = @max(0.0, 1.0 - window_w);
    state.offset = @max(0.0, @min(max_offset, state.offset + direction * window_w * 0.25));
}

fn zoom(state: *ViewportState, factor: f32) void {
    const previous_scale = @max(0.05, state.scale);
    const previous_w = 1.0 / previous_scale;
    const center = state.offset + previous_w * 0.5;
    state.scale = @max(1.0, @min(6.0, state.scale * factor));
    const next_w = 1.0 / state.scale;
    const max_offset = @max(0.0, 1.0 - next_w);
    state.offset = @max(0.0, @min(max_offset, center - next_w * 0.5));
}

pub fn lane(view: anytype, axis: ui.Rect, props: LaneProps) (ui.RenderError || interaction.Error)!void {
    if (props.lane_count == 0) return;
    const lane_h = @max(primitives.min_extent, (axis.h - 16.0) / @as(f32, @floatFromInt(props.lane_count)));
    const y = axis.y + 18.0 + @as(f32, @floatFromInt(props.lane_index)) * lane_h;
    try view.text(ui.Rect.init(axis.x - 78.0, y + 4.0, 68.0, 16.0), props.label, props.label_color);
    try view.fill(ui.Rect.init(axis.x, y + lane_h - 6.0, axis.w, 1.0), props.border, 0.0);
    for (props.blocks) |block_value| {
        if (block_value.value <= 0.001) continue;
        const start_x = axis.x + axis.w * @max(0.0, @min(1.0, block_value.start));
        const end_x = axis.x + axis.w * @max(0.0, @min(1.0, block_value.end));
        const w = @max(4.0, @max(0.0, end_x - start_x));
        const h = @max(5.0, (lane_h - 18.0) * @max(0.0, @min(1.0, block_value.value)));
        const block_bounds = ui.Rect.init(start_x, y + lane_h - 8.0 - h, w, h);
        try view.selectableSubtleAt(block_bounds, block_value.id, "", "");
        try view.fill(block_bounds, block_value.color, 4.0);
    }
}

pub fn timelineAxis(view: anytype, bounds: ui.Rect, marks: []const Mark, line_color: ui.Color, label_color: ui.Color) ui.RenderError!void {
    try view.fill(ui.Rect.init(bounds.x, bounds.y + 12.0, bounds.w, 1.0), line_color, 0.0);
    for (marks) |mark| {
        const x = bounds.x + bounds.w * @max(0.0, @min(1.0, mark.x));
        try view.fill(ui.Rect.init(x, bounds.y + 7.0, 1.0, 11.0), line_color, 0.0);
        try view.text(ui.Rect.init(x - 22.0, bounds.y - 7.0, 64.0, 14.0), mark.label, label_color);
    }
}

pub fn viewport(view: anytype, bounds: ui.Rect, props: ViewportProps) (ui.RenderError || interaction.Error)!void {
    const fill_color = props.fill orelse view.options.style.row;
    const border_color = props.border orelse view.options.style.border;
    const axis_color = props.axis_color orelse border_color;
    const label_color = props.label_color orelse view.options.style.muted;

    try view.fill(bounds, fill_color, props.radius);
    try view.stroke(bounds, border_color, props.radius);
    const inner = bounds.insetUniform(props.inset);
    const header_h: f32 = if (props.title.len != 0 or props.detail.len != 0) 24.0 else 0.0;
    const controls_w: f32 = if (props.controls != null) @min(inner.w, 194.0) else 0.0;
    const controls_gap: f32 = if (controls_w > 0.0) 10.0 else 0.0;
    const header_text_w = @max(primitives.min_extent, inner.w - controls_w - controls_gap);
    if (props.title.len != 0) {
        try view.strongText(ui.Rect.init(inner.x, inner.y, header_text_w, 16.0), props.title, view.options.style.text);
    }
    if (props.detail.len != 0) {
        try view.text(ui.Rect.init(inner.x, inner.y + 17.0, header_text_w, 14.0), props.detail, label_color);
    }
    if (props.controls) |controls| {
        const specs = [_]app_surfaces.IconButtonSpec{
            .{ .id = controls.pan_left_id, .label = "Earlier", .icon = .chevron_left, .variant = .outline },
            .{ .id = controls.zoom_out_id, .label = "Zoom out", .icon = .zoom_out, .variant = .outline },
            .{ .id = controls.reset_id, .label = "Reset zoom", .icon = .zoom_reset, .variant = .outline },
            .{ .id = controls.zoom_in_id, .label = "Zoom in", .icon = .zoom_in, .variant = .outline },
            .{ .id = controls.pan_right_id, .label = "Later", .icon = .chevron_right, .variant = .outline },
        };
        try app_surfaces.actionToolbar(view, ui.Rect.init(inner.x + inner.w - controls_w, inner.y - 2.0, controls_w, 28.0), .{
            .specs = &specs,
            .button_w = 32.0,
            .button_h = 28.0,
            .gap = 5.0,
        });
    }

    const label_w = @min(inner.w * 0.42, @max(0.0, props.label_w));
    const axis_y = inner.y + header_h + 12.0;
    const axis = ui.Rect.init(inner.x + label_w, axis_y + 14.0, @max(primitives.min_extent, inner.w - label_w), @max(primitives.min_extent, inner.y + inner.h - axis_y - 18.0));
    var mapped_marks: [16]Mark = undefined;
    var mapped_mark_count: usize = 0;
    const visible_window = window(props.viewport.offset, props.viewport.scale);
    for (props.marks) |mark| {
        const x = unitInWindow(mark.at, visible_window.start, visible_window.end) orelse continue;
        if (mapped_mark_count >= mapped_marks.len) break;
        mapped_marks[mapped_mark_count] = .{ .x = x, .label = mark.label };
        mapped_mark_count += 1;
    }
    try timelineAxis(view, axis, mapped_marks[0..mapped_mark_count], axis_color, label_color);

    for (props.lanes, 0..) |lane_value, lane_index| {
        if (lane_index >= 12) break;
        var mapped_blocks: [32]Block = undefined;
        var mapped_count: usize = 0;
        for (lane_value.blocks) |block_value| {
            const mapped = blockInWindow(block_value, visible_window.start, visible_window.end) orelse continue;
            if (mapped_count >= mapped_blocks.len) break;
            mapped_blocks[mapped_count] = mapped;
            mapped_count += 1;
        }
        try lane(view, axis, .{
            .label = lane_value.label,
            .lane_index = lane_index,
            .lane_count = props.lanes.len,
            .blocks = mapped_blocks[0..mapped_count],
            .border = axis_color,
            .label_color = label_color,
        });
    }
}
