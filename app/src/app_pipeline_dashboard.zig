const std = @import("std");
const bytes = @import("bytes.zig");
const interaction = @import("ui/interaction.zig");
const ui = @import("ui/core.zig");
const ui_runtime = @import("ui/runtime.zig");
const common = @import("ui/component_common.zig");
const Component = @import("ui/components/Component.zig").Component;
const icon_component = @import("ui/components/Icon.zig");
const icon = @import("ui/icon.zig");

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

pub const State = struct {
    ram_budget: f32 = 0.62,
    tick_budget: f32 = 0.55,
    model_enabled: bool = false,
    committed: bool = false,
    discarded: bool = false,
    selected_stage: usize = 1,
    selected_path: usize = 0,

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
        var render_options = options;
        render_options.style = pipelineStyle();
        try scene.pushGradientRect(bounds, pipeline_bg_top, pipeline_bg_bottom, 0.0);

        const outer = bounds.insetUniform(18.0);
        try renderHeader(scene, collector, outer, self.*, render_options);
        const body_y = outer.y + 82.0;
        const body_h = @max(1.0, outer.h - 82.0);
        if (outer.w >= 980.0) {
            const fs_w = @min(330.0, outer.w * 0.30);
            const side_w = @min(330.0, outer.w * 0.29);
            const gap: f32 = 14.0;
            const fs = ui.Rect.init(outer.x, body_y, fs_w, body_h);
            const graph = ui.Rect.init(fs.x + fs.w + gap, body_y, @max(1.0, outer.w - fs_w - side_w - gap * 2.0), body_h);
            const side = ui.Rect.init(graph.x + graph.w + gap, body_y, side_w, body_h);
            try self.renderFilesystem(scene, collector, fs, render_options);
            try self.renderGraph(scene, collector, graph, render_options);
            try self.renderInspector(scene, collector, side, render_options);
        } else {
            const fs_h = @min(300.0, @max(220.0, body_h * 0.32));
            const graph_h = @max(280.0, (body_h - fs_h - 28.0) * 0.58);
            try self.renderFilesystem(scene, collector, ui.Rect.init(outer.x, body_y, outer.w, fs_h), render_options);
            try self.renderGraph(scene, collector, ui.Rect.init(outer.x, body_y + fs_h + 14.0, outer.w, graph_h), render_options);
            try self.renderInspector(scene, collector, ui.Rect.init(outer.x, body_y + fs_h + graph_h + 28.0, outer.w, @max(1.0, body_h - fs_h - graph_h - 28.0)), render_options);
        }
    }

    fn renderFilesystem(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, options: common.RenderOptions) Error!void {
        try panel(scene, bounds);
        const inner = bounds.insetUniform(14.0);
        try scene.pushStrongText(ui.Rect.init(inner.x, inner.y, inner.w, 20.0), "filesystem", pipeline_text);
        try scene.pushText(ui.Rect.init(inner.x, inner.y + 24.0, inner.w, 16.0), "choose one path to stage into RAM", pipeline_muted);

        const map_h = @min(132.0, @max(86.0, inner.h * 0.24));
        try self.renderDiskMap(scene, collector, ui.Rect.init(inner.x, inner.y + 50.0, inner.w, map_h));

        const row_top = inner.y + 50.0 + map_h + 12.0;
        const available_h = @max(1.0, inner.y + inner.h - row_top);
        const row_gap: f32 = 8.0;
        const row_h = @max(36.0, @min(58.0, (available_h - row_gap * @as(f32, @floatFromInt(fs_path_count - 1))) / @as(f32, @floatFromInt(fs_path_count))));
        for (fs_paths, 0..) |path, index| {
            const row = ui.Rect.init(inner.x, row_top + @as(f32, @floatFromInt(index)) * (row_h + row_gap), inner.w, row_h);
            try self.renderPathRow(scene, collector, row, path, index, options);
        }
    }

    fn renderDiskMap(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect) Error!void {
        try scene.pushRect(bounds, colorWithAlpha(pipeline_row, 120), .fill, 8.0, 0.0);
        try scene.pushRect(bounds, pipeline_border, .border, 8.0, 0.0);
        const inner = bounds.insetUniform(8.0);
        var x = inner.x;
        const gap: f32 = 5.0;
        for (fs_paths, 0..) |path, index| {
            const remaining = @max(1.0, inner.x + inner.w - x);
            const w = if (index == fs_path_count - 1) remaining else @max(18.0, inner.w * path.size_unit * 0.28);
            const h = @max(18.0, inner.h * @max(0.28, path.hotness));
            const y = inner.y + inner.h - h;
            const selected = index == self.selected_path;
            const block = ui.Rect.init(x, y, @max(1.0, @min(w, remaining)), h);
            try scene.pushRect(block, if (selected) path.color() else colorWithAlpha(path.color(), 135), .fill, 5.0, 0.0);
            try scene.pushRect(block, if (selected) pipeline_text else colorWithAlpha(pipeline_border, 180), .border, 5.0, 0.0);
            try collector.addHit(block, .button, path_base_id + @as(u32, @intCast(index)));
            x += w + gap;
            if (x >= inner.x + inner.w) break;
        }
    }

    fn renderPathRow(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, path: FsPath, index: usize, options: common.RenderOptions) Error!void {
        _ = options;
        const selected = index == self.selected_path;
        const fill = if (selected) ui.Color{ .r = 39, .g = 45, .b = 51, .a = 238 } else pipeline_row;
        try scene.pushRect(bounds, fill, .fill, 7.0, 0.0);
        try scene.pushRect(bounds, if (selected) path.color() else pipeline_border, .border, 7.0, 0.0);
        try collector.addHit(bounds, .button, path_base_id + @as(u32, @intCast(index)));

        const marker = ui.Rect.init(bounds.x + 9.0, bounds.y + 9.0, 7.0, bounds.h - 18.0);
        try scene.pushRect(marker, path.color(), .fill, 4.0, 0.0);
        try scene.pushStrongText(ui.Rect.init(bounds.x + 24.0, bounds.y + 7.0, @max(1.0, bounds.w - 92.0), 16.0), shortPath(path.path), pipeline_text);
        try scene.pushText(ui.Rect.init(bounds.x + 24.0, bounds.y + 27.0, @max(1.0, bounds.w - 92.0), 14.0), path.role, pipeline_muted);
        try scene.pushText(ui.Rect.init(bounds.x + bounds.w - 62.0, bounds.y + 8.0, 56.0, 14.0), path.size_label, pipeline_muted);
        try resourceBar(scene, ui.Rect.init(bounds.x + bounds.w - 62.0, bounds.y + bounds.h - 16.0, 50.0, 6.0), path.ram_fit, if (path.ram_fit < 0.5) pipeline_reject else pipeline_ram, .{ .style = pipelineStyle() });
    }

    fn renderGraph(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, options: common.RenderOptions) Error!void {
        try panel(scene, bounds);
        const inner = bounds.insetUniform(16.0);
        try scene.pushStrongText(ui.Rect.init(inner.x, inner.y, inner.w, 20.0), "pipeline graph and timeline", pipeline_text);
        try scene.pushText(ui.Rect.init(inner.x, inner.y + 24.0, inner.w, 16.0), "dependencies, RAM lifetime, tick spend, and durable writes share one time axis", pipeline_muted);

        const canvas_y = inner.y + 58.0;
        const canvas_h = @max(1.0, inner.h - 58.0);
        const graph_h = if (inner.w >= 720.0) @min(280.0, canvas_h * 0.48) else @min(230.0, canvas_h * 0.44);
        const timeline_y = canvas_y + graph_h + 16.0;
        try self.renderDependencyGraph(scene, collector, ui.Rect.init(inner.x, canvas_y, inner.w, graph_h), options);
        try self.renderTimeline(scene, collector, ui.Rect.init(inner.x, timeline_y, inner.w, @max(1.0, inner.y + inner.h - timeline_y)), options);
    }

    fn renderDependencyGraph(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, options: common.RenderOptions) Error!void {
        try scene.pushRect(bounds, colorWithAlpha(pipeline_row, 120), .fill, 8.0, 0.0);
        try scene.pushRect(bounds, pipeline_border, .border, 8.0, 0.0);
        const graph = bounds.insetUniform(14.0);
        var node_bounds: [stage_count]ui.Rect = undefined;
        for (stages, 0..) |stage, index| {
            node_bounds[index] = graphNodeBounds(graph, index);
            try self.renderNode(scene, collector, node_bounds[index], stage, index, options);
        }
        for (edges) |edge| {
            try renderEdge(scene, node_bounds[edge.from], node_bounds[edge.to], if (edge.to == self.selected_stage or edge.from == self.selected_stage) stages[edge.to].accent() else colorWithAlpha(pipeline_border, 180));
        }
        for (stages, 0..) |stage, index| {
            const node = node_bounds[index];
            try self.renderNode(scene, collector, node, stage, index, options);
        }
    }

    fn renderNode(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, stage: Stage, index: usize, options: common.RenderOptions) Error!void {
        _ = options;
        const selected = index == self.selected_stage;
        const fill = if (selected) ui.Color{ .r = 39, .g = 45, .b = 51, .a = 238 } else pipeline_row;
        try scene.pushRect(bounds, fill, .fill, 8.0, 0.0);
        try scene.pushRect(bounds, if (selected) stage.accent() else pipeline_border, .border, 8.0, 0.0);
        try collector.addHit(bounds, .button, base_id + 100 + @as(u32, @intCast(index)));

        const marker = ui.Rect.init(bounds.x + 10.0, bounds.y + 10.0, 8.0, bounds.h - 20.0);
        try scene.pushRect(marker, stage.accent(), .fill, 5.0, 0.0);
        try scene.pushStrongText(ui.Rect.init(bounds.x + 28.0, bounds.y + 10.0, bounds.w - 36.0, 18.0), stage.label, pipeline_text);
        try scene.pushText(ui.Rect.init(bounds.x + 28.0, bounds.y + 32.0, bounds.w - 36.0, 16.0), stage.detail, pipeline_muted);
    }

    fn renderTimeline(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, options: common.RenderOptions) Error!void {
        try scene.pushRect(bounds, colorWithAlpha(pipeline_row, 120), .fill, 8.0, 0.0);
        try scene.pushRect(bounds, pipeline_border, .border, 8.0, 0.0);
        const inner = bounds.insetUniform(14.0);
        const label_w = @min(82.0, inner.w * 0.24);
        const axis = ui.Rect.init(inner.x + label_w, inner.y + 26.0, @max(1.0, inner.w - label_w), @max(1.0, inner.h - 38.0));
        try scene.pushText(ui.Rect.init(inner.x, inner.y, inner.w, 16.0), "resource timeline", pipeline_text);
        try renderTimeAxis(scene, axis);
        try self.renderResourceLane(scene, collector, axis, 0, "RAM", pipeline_ram, .ram, options);
        try self.renderResourceLane(scene, collector, axis, 1, "ticks", pipeline_ticks, .ticks, options);
        try self.renderResourceLane(scene, collector, axis, 2, "storage", pipeline_storage, .storage, options);
        const gate_x = axis.x + axis.w * stages[3].start;
        try scene.pushRect(ui.Rect.init(gate_x, axis.y, 2.0, axis.h), colorWithAlpha(pipeline_model, if (self.model_enabled) 190 else 70), .fill, 0.0, 0.0);
        try scene.pushText(ui.Rect.init(gate_x + 5.0, axis.y, 76.0, 14.0), if (self.model_enabled) "model ok" else "model gate", if (self.model_enabled) pipeline_model else pipeline_muted);
    }

    fn renderResourceLane(self: *State, scene: *ui.Scene, collector: *interaction.Collector, axis: ui.Rect, lane_index: usize, label: []const u8, color: ui.Color, comptime resource: ResourceLane, options: common.RenderOptions) Error!void {
        _ = options;
        const lane_h = @max(1.0, (axis.h - 16.0) / 3.0);
        const y = axis.y + 18.0 + @as(f32, @floatFromInt(lane_index)) * lane_h;
        try scene.pushText(ui.Rect.init(axis.x - 78.0, y + 4.0, 68.0, 16.0), label, pipeline_muted);
        try scene.pushRect(ui.Rect.init(axis.x, y + lane_h - 6.0, axis.w, 1.0), colorWithAlpha(pipeline_border, 130), .fill, 0.0, 0.0);
        for (stages, 0..) |stage, index| {
            const raw = switch (resource) {
                .ram => stage.ram * self.ram_budget,
                .ticks => stage.ticks * self.tick_budget,
                .storage => stage.storage,
            };
            if (raw <= 0.001) continue;
            const start_x = axis.x + axis.w * stage.start;
            const w = @max(4.0, axis.w * @max(0.02, stage.end - stage.start));
            const h = @max(5.0, (lane_h - 18.0) * ui.clampUnit(raw));
            const block = ui.Rect.init(start_x, y + lane_h - 8.0 - h, w, h);
            const fill = if (index == self.selected_stage) color else colorWithAlpha(color, 150);
            try scene.pushRect(block, fill, .fill, 4.0, 0.0);
            try collector.addHit(ui.Rect.init(start_x, y, w, lane_h - 4.0), .button, base_id + 100 + @as(u32, @intCast(index)));
        }
    }

    fn renderInspector(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, options: common.RenderOptions) Error!void {
        try panel(scene, bounds);
        const inner = bounds.insetUniform(16.0);
        const stage = stages[self.selected_stage];
        const path = fs_paths[self.selected_path];
        try scene.pushStrongText(ui.Rect.init(inner.x, inner.y, inner.w, 20.0), "scheduler controls", pipeline_text);
        try scene.pushText(ui.Rect.init(inner.x, inner.y + 24.0, inner.w, 16.0), "stage budgets are explicit before work starts", pipeline_muted);

        var y = inner.y + 58.0;
        try labelValue(scene, "path", shortPath(path.path), inner.x, y, inner.w);
        y += 30.0;
        try labelValue(scene, "selected", stage.label, inner.x, y, inner.w);
        y += 30.0;
        try labelValue(scene, "state", self.stateLabel(), inner.x, y, inner.w);
        y += 42.0;

        try scene.pushText(ui.Rect.init(inner.x, y, inner.w, 16.0), "RAM fit for chosen path", pipeline_muted);
        y += 22.0;
        try resourceBar(scene, ui.Rect.init(inner.x, y, inner.w, 12.0), path.ram_fit * self.ram_budget, if (path.ram_fit < 0.5) pipeline_reject else pipeline_ram, options);
        y += 28.0;
        try scene.pushText(ui.Rect.init(inner.x, y, inner.w, 16.0), if (path.private) "private local path" else "shared or cache path", if (path.private) pipeline_ram else pipeline_storage);
        y += 34.0;

        try (Component{ .slider = .{ .id = ram_slider_id, .label = "RAM grant", .value = self.ram_budget } }).renderInteractive(scene, collector, ui.Rect.init(inner.x, y, inner.w, 44.0), options);
        y += 58.0;
        try (Component{ .slider = .{ .id = tick_slider_id, .label = "Tick budget", .value = self.tick_budget } }).renderInteractive(scene, collector, ui.Rect.init(inner.x, y, inner.w, 44.0), options);
        y += 62.0;

        try scene.pushText(ui.Rect.init(inner.x, y, inner.w, 16.0), "volatile work", pipeline_muted);
        y += 22.0;
        try resourceBar(scene, ui.Rect.init(inner.x, y, inner.w, 12.0), volatileRatio(), pipeline_model, options);
        y += 34.0;

        const model_label = if (self.model_enabled) "model stage on" else "model stage off";
        try (Component{ .button = .{ .id = model_toggle_id, .label = model_label, .variant = .outline, .icon_slot = icon_component.IconSlot.named(.leading, icon.Icon.cpu) } }).renderInteractive(scene, collector, ui.Rect.init(inner.x, y, inner.w, 34.0), options);
        y += 46.0;
        try (Component{ .button = .{ .id = commit_button_id, .label = "Commit useful result", .variant = .primary, .icon_slot = icon_component.IconSlot.named(.leading, icon.Icon.database_export) } }).renderInteractive(scene, collector, ui.Rect.init(inner.x, y, inner.w, 34.0), options);
        y += 42.0;
        try (Component{ .button = .{ .id = discard_button_id, .label = "Discard volatile work", .variant = .outline, .icon_slot = icon_component.IconSlot.named(.leading, icon.Icon.trash) } }).renderInteractive(scene, collector, ui.Rect.init(inner.x, y, inner.w, 34.0), options);
    }

    fn stateLabel(self: State) []const u8 {
        if (self.committed) return "committed receipt";
        if (self.discarded) return "volatile discarded";
        return "RAM only";
    }
};

fn renderHeader(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, state: State, options: common.RenderOptions) Error!void {
    _ = collector;
    try scene.pushStrongText(ui.Rect.init(bounds.x, bounds.y, bounds.w, 26.0), "User-Scheduled Pipeline", pipeline_text);
    try scene.pushText(ui.Rect.init(bounds.x, bounds.y + 32.0, bounds.w, 18.0), "load data, spend RAM and ticks deliberately, commit only useful results", pipeline_muted);
    const chip_y = bounds.y + 56.0;
    try badge(scene, ui.Rect.init(bounds.x, chip_y, 118.0, 24.0), state.stateLabel(), if (state.committed) pipeline_commit else pipeline_ram, options);
    try badge(scene, ui.Rect.init(bounds.x + 128.0, chip_y, 104.0, 24.0), if (state.model_enabled) "model allowed" else "model gated", if (state.model_enabled) pipeline_model else pipeline_muted, options);
}

fn panel(scene: *ui.Scene, bounds: ui.Rect) ui.RenderError!void {
    try scene.pushRect(bounds, pipeline_panel, .fill, 8.0, 0.0);
    try scene.pushRect(bounds, pipeline_border, .border, 8.0, 0.0);
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

fn renderEdge(scene: *ui.Scene, from: ui.Rect, to: ui.Rect, color: ui.Color) ui.RenderError!void {
    const x0 = from.x + from.w;
    const y0 = from.y + from.h * 0.5;
    const x1 = to.x;
    const y1 = to.y + to.h * 0.5;
    const mid_x = x0 + @max(10.0, (x1 - x0) * 0.5);
    try renderLineRect(scene, x0, y0, mid_x, y0, color);
    try renderLineRect(scene, mid_x, y0, mid_x, y1, color);
    try renderLineRect(scene, mid_x, y1, x1, y1, color);
    try scene.pushRect(ui.Rect.init(x1 - 5.0, y1 - 4.0, 8.0, 8.0), color, .fill, 2.0, 0.0);
}

fn renderLineRect(scene: *ui.Scene, x0: f32, y0: f32, x1: f32, y1: f32, color: ui.Color) ui.RenderError!void {
    const thickness: f32 = 2.0;
    if (@abs(x1 - x0) >= @abs(y1 - y0)) {
        const left = @min(x0, x1);
        try scene.pushRect(ui.Rect.init(left, y0 - thickness * 0.5, @max(thickness, @abs(x1 - x0)), thickness), color, .fill, 0.0, 0.0);
    } else {
        const top = @min(y0, y1);
        try scene.pushRect(ui.Rect.init(x0 - thickness * 0.5, top, thickness, @max(thickness, @abs(y1 - y0))), color, .fill, 0.0, 0.0);
    }
}

fn renderTimeAxis(scene: *ui.Scene, axis: ui.Rect) ui.RenderError!void {
    try scene.pushRect(ui.Rect.init(axis.x, axis.y + 12.0, axis.w, 1.0), colorWithAlpha(pipeline_border, 160), .fill, 0.0, 0.0);
    const marks = [_]struct { x: f32, label: []const u8 }{
        .{ .x = 0.0, .label = "load" },
        .{ .x = 0.33, .label = "derive" },
        .{ .x = 0.66, .label = "transform" },
        .{ .x = 1.0, .label = "commit" },
    };
    for (marks) |mark| {
        const x = axis.x + axis.w * mark.x;
        try scene.pushRect(ui.Rect.init(x, axis.y + 7.0, 1.0, 11.0), colorWithAlpha(pipeline_border, 180), .fill, 0.0, 0.0);
        try scene.pushText(ui.Rect.init(x - 22.0, axis.y - 7.0, 64.0, 14.0), mark.label, pipeline_muted);
    }
}

fn badge(scene: *ui.Scene, bounds: ui.Rect, text: []const u8, color: ui.Color, options: common.RenderOptions) ui.RenderError!void {
    var badge_options = options;
    badge_options.style.accent = color;
    try (Component{ .badge = .{ .label = text, .variant = .default } }).render(scene, bounds, badge_options);
}

fn resourceBar(scene: *ui.Scene, bounds: ui.Rect, value: f32, color: ui.Color, options: common.RenderOptions) ui.RenderError!void {
    var bar_options = options;
    bar_options.style.accent = color;
    try (Component{ .progress = .{ .value = value } }).render(scene, bounds, bar_options);
}

fn labelValue(scene: *ui.Scene, label: []const u8, value: []const u8, x: f32, y: f32, w: f32) ui.RenderError!void {
    try scene.pushText(ui.Rect.init(x, y, 92.0, 16.0), label, pipeline_muted);
    try scene.pushStrongText(ui.Rect.init(x + 96.0, y, @max(1.0, w - 96.0), 18.0), value, pipeline_text);
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
}

fn hasText(commands: []const ui.Command, value: []const u8) bool {
    for (commands) |command| {
        if (command == .text and bytes.eql(command.text.value, value)) return true;
    }
    return false;
}
