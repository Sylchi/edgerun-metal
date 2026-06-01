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
