const std = @import("std");
const bytes = @import("bytes.zig");
const interaction = @import("ui/interaction.zig");
const ui = @import("ui/core.zig");
const ui_runtime = @import("ui/runtime.zig");
const common = @import("ui/component_common.zig");
const component = @import("ui/components/Component.zig");

pub const Error = ui.RenderError || interaction.Error || error{NoSpace};

const pipeline_bg_top = ui.Color{ .r = 9, .g = 12, .b = 14 };
const pipeline_bg_bottom = ui.Color{ .r = 12, .g = 14, .b = 17 };
const pipeline_panel = ui.Color{ .r = 22, .g = 25, .b = 29, .a = 238 };
const pipeline_row = ui.Color{ .r = 31, .g = 35, .b = 40, .a = 212 };
const pipeline_border = ui.Color{ .r = 68, .g = 76, .b = 88, .a = 140 };
const pipeline_text = ui.Color{ .r = 240, .g = 244, .b = 248 };
const pipeline_muted = ui.Color{ .r = 156, .g = 167, .b = 180 };
const pipeline_ram = ui.Color{ .r = 53, .g = 214, .b = 182 };
const pipeline_ticks = ui.Color{ .r = 88, .g = 166, .b = 255 };
const pipeline_storage = ui.Color{ .r = 245, .g = 184, .b = 78 };
const pipeline_model = ui.Color{ .r = 215, .g = 117, .b = 255 };
const pipeline_commit = ui.Color{ .r = 117, .g = 219, .b = 95 };
const pipeline_reject = ui.Color{ .r = 242, .g = 103, .b = 103 };

const stage_count: usize = 6;
const base_id: u32 = 124_000;
pub const commit_button_id: u32 = base_id + 1;
pub const discard_button_id: u32 = base_id + 2;
pub const model_toggle_id: u32 = base_id + 3;
const ram_slider_id: u32 = base_id + 16;
const tick_slider_id: u32 = base_id + 17;
const timeline_pan_left_id: u32 = base_id + 40;
const timeline_pan_right_id: u32 = base_id + 41;
const timeline_zoom_out_id: u32 = base_id + 42;
const timeline_zoom_in_id: u32 = base_id + 43;
const timeline_reset_id: u32 = base_id + 44;
const timeline_controls = component.TimelineViewportControls{
    .pan_left_id = timeline_pan_left_id,
    .pan_right_id = timeline_pan_right_id,
    .zoom_out_id = timeline_zoom_out_id,
    .zoom_in_id = timeline_zoom_in_id,
    .reset_id = timeline_reset_id,
};
const path_base_id: u32 = base_id + 300;

const StageKind = enum {
    load,
    index,
    relate,
    transform,
    inspect,
    commit,
};

const ResourceLane = enum { ram, ticks, storage };

const fs_path_count: usize = 6;

const FsPath = struct {
    path: []const u8,
    role: []const u8,
    size_label: []const u8,
    size_unit: f32,
    ram_fit: f32,
    hotness: f32,
    indexed: f32,
    dirty: bool = false,
    private: bool = true,

    fn color(self: FsPath) ui.Color {
        if (self.dirty) return pipeline_storage;
        if (self.ram_fit < 0.5) return pipeline_reject;
        if (self.hotness > 0.7) return pipeline_ticks;
        return pipeline_ram;
    }
};

const fs_paths = [_]FsPath{
    .{ .path = "/home/ken/edgerun-c/app/src", .role = "UI and app graph", .size_label = "41 MB", .size_unit = 0.18, .ram_fit = 0.86, .hotness = 0.82, .indexed = 0.63 },
    .{ .path = "/home/ken/edgerun-c/kernel/x86_64", .role = "host ASM core", .size_label = "96 MB", .size_unit = 0.32, .ram_fit = 0.68, .hotness = 0.76, .indexed = 0.48 },
    .{ .path = "/home/ken/edgerun-c/app/src/icons", .role = "large asset set", .size_label = "312 MB", .size_unit = 0.72, .ram_fit = 0.24, .hotness = 0.31, .indexed = 0.18 },
    .{ .path = "/home/ken/edgerun-c/kernel/test", .role = "compiler proofs", .size_label = "28 MB", .size_unit = 0.12, .ram_fit = 0.92, .hotness = 0.61, .indexed = 0.74 },
    .{ .path = "/tmp/edgerun-session", .role = "volatile work area", .size_label = "147 MB", .size_unit = 0.46, .ram_fit = 0.44, .hotness = 0.58, .indexed = 0.22, .dirty = true, .private = false },
    .{ .path = "/home/ken/.cache/zig", .role = "build cache", .size_label = "1.8 GB", .size_unit = 0.94, .ram_fit = 0.08, .hotness = 0.16, .indexed = 0.05, .private = false },
};

const Stage = struct {
    kind: StageKind,
    label: []const u8,
    detail: []const u8,
    start: f32,
    end: f32,
    ram: f32,
    ticks: f32,
    storage: f32,
    external: bool = false,
    is_volatile: bool = true,

    fn accent(self: Stage) ui.Color {
        if (!self.is_volatile) return pipeline_commit;
        if (self.storage > 0.0) return pipeline_storage;
        if (self.external) return pipeline_model;
        if (self.ticks > self.ram) return pipeline_ticks;
        return pipeline_ram;
    }
};

const stages = [_]Stage{
    .{ .kind = .load, .label = "load", .detail = "disk chunk to RAM object", .start = 0.03, .end = 0.18, .ram = 0.22, .ticks = 0.12, .storage = 0.0 },
    .{ .kind = .index, .label = "index", .detail = "RAM projection and keys", .start = 0.18, .end = 0.40, .ram = 0.42, .ticks = 0.34, .storage = 0.0 },
    .{ .kind = .relate, .label = "relate", .detail = "meaning and links", .start = 0.31, .end = 0.58, .ram = 0.58, .ticks = 0.46, .storage = 0.0 },
    .{ .kind = .transform, .label = "transform", .detail = "bounded specialist stage", .start = 0.55, .end = 0.78, .ram = 0.36, .ticks = 0.74, .storage = 0.0, .external = true },
    .{ .kind = .inspect, .label = "inspect", .detail = "user-visible result", .start = 0.76, .end = 0.90, .ram = 0.18, .ticks = 0.16, .storage = 0.0 },
    .{ .kind = .commit, .label = "commit", .detail = "selected durable output", .start = 0.90, .end = 0.98, .ram = 0.10, .ticks = 0.08, .storage = 0.34, .is_volatile = false },
};

const edges = [_]struct { from: usize, to: usize }{
    .{ .from = 0, .to = 1 },
    .{ .from = 1, .to = 2 },
    .{ .from = 2, .to = 3 },
    .{ .from = 2, .to = 4 },
    .{ .from = 3, .to = 4 },
    .{ .from = 4, .to = 5 },
};

const timeline_viewport_marks = [_]component.TimelineViewportMark{
    .{ .at = 0.0, .label = "load" },
    .{ .at = 0.33, .label = "derive" },
    .{ .at = 0.66, .label = "transform" },
    .{ .at = 1.0, .label = "commit" },
};

pub const State = struct {
    ram_budget: f32 = 0.62,
    tick_budget: f32 = 0.55,
    model_enabled: bool = false,
    committed: bool = false,
    discarded: bool = false,
    selected_stage: usize = 1,
    selected_path: usize = 0,
    timeline_viewport: component.TimelineViewportState = .{},

    pub fn activate(self: *State, hit: ?interaction.Region, drag: ?ui_runtime.DragValue) void {
        const region = hit orelse return;
        switch (region.id) {
            commit_button_id => {
                self.committed = true;
                self.discarded = false;
            },
            discard_button_id => {
                self.discarded = true;
                self.committed = false;
            },
            model_toggle_id => self.model_enabled = !self.model_enabled,
            ram_slider_id => {
                if (unitFromDrag(region, drag)) |value| self.ram_budget = value;
            },
            tick_slider_id => {
                if (unitFromDrag(region, drag)) |value| self.tick_budget = value;
            },
            timeline_pan_left_id, timeline_pan_right_id, timeline_zoom_out_id, timeline_zoom_in_id, timeline_reset_id => {
                if (component.timelineViewportActionForHit(region.id, timeline_controls)) |action| {
                    component.applyTimelineViewportAction(&self.timeline_viewport, action);
                }
            },
            base_id + 100...base_id + 100 + stage_count - 1 => self.selected_stage = @intCast(region.id - (base_id + 100)),
            path_base_id...path_base_id + fs_path_count - 1 => {
                self.selected_path = @intCast(region.id - path_base_id);
                self.selected_stage = 0;
                self.committed = false;
                self.discarded = false;
            },
            else => {},
        }
    }

    pub fn render(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, options: common.RenderOptions) Error!void {
        const render_options = options.withStyle(pipelineStyle());
        const app = component.renderer(scene, collector, render_options);
        try self.renderView(app, bounds);
    }

    pub fn renderView(self: *State, app: component.View, bounds: ui.Rect) Error!void {
        try app.gradient(bounds, pipeline_bg_top, pipeline_bg_bottom, 0.0);

        const outer = bounds.insetUniform(18.0);
        try renderHeader(app, outer, self.*);
        const body_y = outer.y + 82.0;
        const body_h = @max(1.0, outer.h - 82.0);
        const fs_stack_h = @min(300.0, @max(220.0, body_h * 0.32));
        const panes = app.responsivePanes(ui.Rect.init(outer.x, body_y, outer.w, body_h), .{
            .breakpoint = 980.0,
            .gap = 14.0,
            .first_w = @min(330.0, outer.w * 0.30),
            .third_w = @min(330.0, outer.w * 0.29),
            .first_stack_h = fs_stack_h,
            .second_stack_h = @max(280.0, (body_h - fs_stack_h - 28.0) * 0.58),
        });
        try self.renderFilesystem(app, panes.first);
        try self.renderGraph(app, panes.second);
        try self.renderInspector(app, panes.third);
    }

    fn renderFilesystem(self: *State, app: component.View, bounds: ui.Rect) Error!void {
        const body = try app.panelScaffold(bounds, .{
            .title = "filesystem",
            .detail = "choose one path to stage into RAM",
            .inset = 14.0,
            .header_gap = 8.0,
        });

        const map_h = @min(132.0, @max(86.0, body.h * 0.24));
        try self.renderDiskMap(app, ui.Rect.init(body.x, body.y, body.w, map_h));

        const row_top = body.y + map_h + 12.0;
        const available_h = @max(1.0, body.y + body.h - row_top);
        const row_gap: f32 = 8.0;
        const row_h = @max(36.0, @min(58.0, (available_h - row_gap * @as(f32, @floatFromInt(fs_path_count - 1))) / @as(f32, @floatFromInt(fs_path_count))));
        for (fs_paths, 0..) |path, index| {
            const row = ui.Rect.init(body.x, row_top + @as(f32, @floatFromInt(index)) * (row_h + row_gap), body.w, row_h);
            try app.pathRow(row, .{
                .id = path_base_id + @as(u32, @intCast(index)),
                .title = shortPath(path.path),
                .detail = path.role,
                .trailing = path.size_label,
                .progress = path.ram_fit,
                .accent = path.color(),
                .progress_color = if (path.ram_fit < 0.5) pipeline_reject else pipeline_ram,
                .selected = index == self.selected_path,
                .fill = pipeline_row,
                .selected_fill = ui.Color{ .r = 39, .g = 45, .b = 51, .a = 238 },
                .border = pipeline_border,
                .text = pipeline_text,
                .muted = pipeline_muted,
            });
        }
    }

    fn renderDiskMap(self: *State, app: component.View, bounds: ui.Rect) Error!void {
        var segments: [fs_path_count]component.Segment = undefined;
        for (fs_paths, 0..) |path, index| {
            const selected = index == self.selected_path;
            segments[index] = .{
                .id = path_base_id + @as(u32, @intCast(index)),
                .weight = path.size_unit,
                .height = @max(0.28, path.hotness),
                .color = if (selected) path.color() else colorWithAlpha(path.color(), 135),
                .selected = selected,
            };
        }
        try app.segmentMap(bounds, .{
            .segments = &segments,
            .background = colorWithAlpha(pipeline_row, 120),
            .border = colorWithAlpha(pipeline_border, 180),
            .selected_border = pipeline_text,
        });
    }

    fn renderGraph(self: *State, app: component.View, bounds: ui.Rect) Error!void {
        const body = try app.panelScaffold(bounds, .{
            .title = "pipeline graph and timeline",
            .detail = "dependencies, RAM lifetime, tick spend, and durable writes share one time axis",
        });

        const canvas_y = body.y;
        const canvas_h = body.h;
        const graph_h = if (body.w >= 720.0) @min(280.0, canvas_h * 0.48) else @min(230.0, canvas_h * 0.44);
        const timeline_y = canvas_y + graph_h + 16.0;
        try self.renderDependencyGraph(app, ui.Rect.init(body.x, canvas_y, body.w, graph_h));
        try self.renderTimeline(app, ui.Rect.init(body.x, timeline_y, body.w, @max(1.0, body.y + body.h - timeline_y)));
    }

    fn renderDependencyGraph(self: *State, app: component.View, bounds: ui.Rect) Error!void {
        try app.fill(bounds, colorWithAlpha(pipeline_row, 120), 8.0);
        try app.stroke(bounds, pipeline_border, 8.0);
        const graph = bounds.insetUniform(14.0);
        var node_bounds: [stage_count]ui.Rect = undefined;
        for (0..stage_count) |index| {
            node_bounds[index] = graphNodeBounds(graph, index);
        }
        for (edges) |edge| {
            try app.elbowEdge(node_bounds[edge.from], node_bounds[edge.to], if (edge.to == self.selected_stage or edge.from == self.selected_stage) stages[edge.to].accent() else colorWithAlpha(pipeline_border, 180), 2.0);
        }
        for (stages, 0..) |stage, index| {
            const node = node_bounds[index];
            try app.pipelineNode(node, .{
                .id = base_id + 100 + @as(u32, @intCast(index)),
                .title = stage.label,
                .detail = stage.detail,
                .accent = stage.accent(),
                .selected = index == self.selected_stage,
                .fill = pipeline_row,
                .selected_fill = ui.Color{ .r = 39, .g = 45, .b = 51, .a = 238 },
                .border = pipeline_border,
                .text = pipeline_text,
                .muted = pipeline_muted,
            });
        }
    }

    fn renderTimeline(self: *State, app: component.View, bounds: ui.Rect) Error!void {
        var ram_blocks: [stage_count]component.TimelineBlock = undefined;
        var tick_blocks: [stage_count]component.TimelineBlock = undefined;
        var storage_blocks: [stage_count]component.TimelineBlock = undefined;
        const lanes = [_]component.TimelineViewportLane{
            .{ .label = "RAM", .blocks = ram_blocks[0..self.writeResourceBlocks(&ram_blocks, pipeline_ram, .ram)] },
            .{ .label = "ticks", .blocks = tick_blocks[0..self.writeResourceBlocks(&tick_blocks, pipeline_ticks, .ticks)] },
            .{ .label = "storage", .blocks = storage_blocks[0..self.writeResourceBlocks(&storage_blocks, pipeline_storage, .storage)] },
        };
        try app.timelineViewport(bounds, .{
            .title = "resource timeline",
            .detail = if (self.model_enabled) "model gate open" else "model gate closed",
            .lanes = &lanes,
            .marks = &timeline_viewport_marks,
            .viewport = self.timeline_viewport,
            .controls = timeline_controls,
            .fill = colorWithAlpha(pipeline_row, 120),
            .border = pipeline_border,
            .axis_color = colorWithAlpha(pipeline_border, 180),
            .label_color = pipeline_muted,
        });
    }

    fn writeResourceBlocks(self: *State, blocks: *[stage_count]component.TimelineBlock, color: ui.Color, comptime resource: ResourceLane) usize {
        var count: usize = 0;
        for (stages, 0..) |stage, index| {
            const raw = switch (resource) {
                .ram => stage.ram * self.ram_budget,
                .ticks => stage.ticks * self.tick_budget,
                .storage => stage.storage,
            };
            if (raw <= 0.001) continue;
            const selected = index == self.selected_stage;
            blocks[count] = .{
                .id = base_id + 100 + @as(u32, @intCast(index)),
                .start = stage.start,
                .end = @max(stage.start + 0.02, stage.end),
                .value = ui.clampUnit(raw),
                .color = if (selected) color else colorWithAlpha(color, 150),
                .selected = selected,
            };
            count += 1;
        }
        return count;
    }

    fn renderInspector(self: *State, app: component.View, bounds: ui.Rect) Error!void {
        const body = try app.panelScaffold(bounds, .{
            .title = "scheduler controls",
            .detail = "stage budgets are explicit before work starts",
        });

        var semantic_items: [9]component.SemanticItem = undefined;
        var ram_buf: [24]u8 = undefined;
        var tick_buf: [24]u8 = undefined;
        var volatile_buf: [24]u8 = undefined;
        const projected = self.writeInspectorSemanticItems(&semantic_items, &ram_buf, &tick_buf, &volatile_buf);

        var stack = app.column(body, 14.0);
        try app.semanticView(stack.take(@min(330.0, @max(250.0, body.h * 0.62))), .{
            .intent = .{ .mode = .schedule, .focus = .resources, .density = .compact },
            .items = projected,
        });

        try app.sliderAt(stack.take(44.0), ram_slider_id, "RAM grant", self.ram_budget);
        stack.skip(14.0);
        try app.sliderAt(stack.take(44.0), tick_slider_id, "Tick budget", self.tick_budget);
    }

    fn writeInspectorSemanticItems(
        self: State,
        items: *[9]component.SemanticItem,
        ram_buf: *[24]u8,
        tick_buf: *[24]u8,
        volatile_buf: *[24]u8,
    ) []const component.SemanticItem {
        const stage = stages[self.selected_stage];
        const path = fs_paths[self.selected_path];
        const ram_value = std.fmt.bufPrint(ram_buf, "{d}%", .{@as(u32, @intFromFloat(@round(path.ram_fit * self.ram_budget * 100.0)))}) catch "RAM";
        const tick_value = std.fmt.bufPrint(tick_buf, "{d}%", .{@as(u32, @intFromFloat(@round(self.tick_budget * 100.0)))}) catch "ticks";
        const volatile_value = std.fmt.bufPrint(volatile_buf, "{d}%", .{@as(u32, @intFromFloat(@round(volatileRatio() * 100.0)))}) catch "volatile";
        items.* = [_]component.SemanticItem{
            .{ .kind = .path, .label = shortPath(path.path), .value = path.size_label, .detail = path.role, .state = if (path.private) .private else .neutral, .importance = .primary, .progress = path.indexed, .accent = path.color() },
            .{ .kind = .resource, .label = "RAM fit", .value = ram_value, .detail = "selected path x grant", .state = if (path.ram_fit < 0.5) .warning else .good, .importance = .primary, .progress = path.ram_fit * self.ram_budget, .accent = if (path.ram_fit < 0.5) pipeline_reject else pipeline_ram },
            .{ .kind = .resource, .label = "Tick budget", .value = tick_value, .detail = "user granted compute", .state = .active, .progress = self.tick_budget, .accent = pipeline_ticks },
            .{ .kind = .artifact, .label = "Volatile work", .value = volatile_value, .detail = "RAM-only until commit", .state = .pending, .progress = volatileRatio(), .accent = pipeline_model },
            .{ .kind = .dependency, .label = "Selected stage", .value = stage.label, .detail = stage.detail, .state = if (stage.external and !self.model_enabled) .blocked else .active, .importance = .normal, .accent = stage.accent() },
            .{ .kind = .event, .label = "State", .value = self.stateLabel(), .detail = if (self.committed) "durable result selected" else "no disk write yet", .state = if (self.committed) .good else .neutral },
            .{ .id = model_toggle_id, .kind = .action, .label = if (self.model_enabled) "Disable model stage" else "Allow model stage", .detail = "explicit user gate", .state = if (self.model_enabled) .active else .blocked, .importance = .normal, .accent = pipeline_model },
            .{ .id = commit_button_id, .kind = .action, .label = "Commit useful result", .detail = "write durable output", .state = .good, .importance = .normal, .accent = pipeline_commit },
            .{ .id = discard_button_id, .kind = .action, .label = "Discard volatile work", .detail = "release RAM objects", .state = .warning, .importance = .normal, .accent = pipeline_reject },
        };
        return items[0..];
    }

    fn stateLabel(self: State) []const u8 {
        if (self.committed) return "committed receipt";
        if (self.discarded) return "volatile discarded";
        return "RAM only";
    }
};

fn renderHeader(app: component.View, bounds: ui.Rect, state: State) Error!void {
    const badges = [_]component.HeaderBadge{
        .{ .label = state.stateLabel(), .variant = .default, .accent = if (state.committed) pipeline_commit else pipeline_ram, .width = 118.0 },
        .{ .label = if (state.model_enabled) "model allowed" else "model gated", .variant = .default, .accent = if (state.model_enabled) pipeline_model else pipeline_muted, .width = 104.0 },
    };
    try app.withTextColor(pipeline_text).pageHeader(bounds, .{
        .title = "User-Scheduled Pipeline",
        .detail = "load data, spend RAM and ticks deliberately, commit only useful results",
        .variant = .subtle,
        .fill = ui.Color.clear,
        .border = ui.Color.clear,
        .detail_color = pipeline_muted,
        .badges = &badges,
        .inset = 0.0,
    });
}

fn graphNodeBounds(bounds: ui.Rect, index: usize) ui.Rect {
    const node_w = @min(168.0, @max(118.0, bounds.w * 0.24));
    const node_h: f32 = 62.0;
    const x_positions = [_]f32{ 0.02, 0.22, 0.43, 0.62, 0.72, 0.86 };
    const y_positions = [_]f32{ 0.18, 0.18, 0.18, 0.58, 0.18, 0.18 };
    const x = bounds.x + @max(0.0, bounds.w - node_w) * x_positions[index];
    const y = bounds.y + @max(0.0, bounds.h - node_h) * y_positions[index];
    return ui.Rect.init(x, y, node_w, node_h);
}

fn shortPath(path: []const u8) []const u8 {
    const repo = "/home/ken/edgerun-c/";
    if (bytes.startsWith(path, repo)) return path[repo.len..];
    if (bytes.startsWith(path, "/home/ken/")) return path["/home/ken/".len..];
    return path;
}

fn pipelineStyle() ui.Style {
    return .{
        .bg = pipeline_bg_top,
        .panel = pipeline_panel,
        .row = pipeline_row,
        .border = pipeline_border,
        .text = pipeline_text,
        .muted = pipeline_muted,
        .accent = pipeline_ram,
    };
}

fn colorWithAlpha(color: ui.Color, alpha: u8) ui.Color {
    return .{ .r = color.r, .g = color.g, .b = color.b, .a = alpha };
}

fn volatileRatio() f32 {
    var count: f32 = 0.0;
    for (stages) |stage| {
        if (stage.is_volatile) count += 1.0;
    }
    return count / @as(f32, @floatFromInt(stage_count));
}

fn unitFromDrag(region: interaction.Region, drag: ?ui_runtime.DragValue) ?f32 {
    const value = drag orelse return null;
    if (value.id != region.id or region.bounds.w <= 0.0) return null;
    return ui.clampUnit((value.pointer_x - region.bounds.x) / region.bounds.w);
}

test "pipeline dashboard activates scheduling controls" {
    var state = State{};
    state.activate(.{ .kind = .button, .id = model_toggle_id, .bounds = ui.Rect.init(0, 0, 10, 10) }, null);
    try std.testing.expect(state.model_enabled);

    const slider_region = interaction.Region{ .kind = .slider, .id = ram_slider_id, .bounds = ui.Rect.init(10, 0, 100, 20) };
    state.activate(slider_region, .{ .id = ram_slider_id, .pointer_x = 85.0 });
    try std.testing.expect(@abs(state.ram_budget - 0.75) < 0.001);

    state.activate(.{ .kind = .button, .id = commit_button_id, .bounds = ui.Rect.init(0, 0, 10, 10) }, null);
    try std.testing.expect(state.committed);
    try std.testing.expect(!state.discarded);

    state.activate(.{ .kind = .button, .id = timeline_zoom_in_id, .bounds = ui.Rect.init(0, 0, 10, 10) }, null);
    try std.testing.expect(state.timeline_viewport.scale > 1.0);
    state.activate(.{ .kind = .button, .id = timeline_pan_right_id, .bounds = ui.Rect.init(0, 0, 10, 10) }, null);
    try std.testing.expect(state.timeline_viewport.offset > 0.0);
    state.activate(.{ .kind = .button, .id = timeline_reset_id, .bounds = ui.Rect.init(0, 0, 10, 10) }, null);
    try std.testing.expectEqual(@as(f32, 0.0), state.timeline_viewport.offset);
    try std.testing.expectEqual(@as(f32, 1.0), state.timeline_viewport.scale);

    state.activate(.{ .kind = .button, .id = path_base_id + 2, .bounds = ui.Rect.init(0, 0, 10, 10) }, null);
    try std.testing.expectEqual(@as(usize, 2), state.selected_path);
    try std.testing.expectEqual(@as(usize, 0), state.selected_stage);
    try std.testing.expect(!state.committed);
}

test "pipeline dashboard renders graph and interaction controls" {
    var commands: [768]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [96]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);
    var state = State{};

    try state.render(&scene, &collector, ui.Rect.init(0, 0, 1100, 720), .{});

    try std.testing.expect(hasText(scene.written(), "User-Scheduled Pipeline"));
    try std.testing.expect(hasText(scene.written(), "filesystem"));
    try std.testing.expect(hasText(scene.written(), "app/src"));
    try std.testing.expect(hasText(scene.written(), "index"));
    try std.testing.expect(collector.written().len >= stage_count + fs_path_count + 3);
    try std.testing.expect(hasHit(collector.written(), timeline_zoom_in_id));
    try std.testing.expect(hasHit(collector.written(), timeline_pan_right_id));
}

fn hasText(commands: []const ui.Command, value: []const u8) bool {
    for (commands) |command| {
        if (command == .text and bytes.eql(command.text.value, value)) return true;
    }
    return false;
}

fn hasHit(regions: []const interaction.Region, id: u32) bool {
    for (regions) |region| {
        if (region.id == id) return true;
    }
    return false;
}
