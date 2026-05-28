const std = @import("std");
const button_component = @import("ui/components/Button.zig");
const card_component = @import("ui/components/Card.zig");
const icon_component = @import("ui/components/Icon.zig");
const interaction = @import("ui_interaction.zig");
const design = @import("app_design.zig");
const row_item_component = @import("ui/components/RowItem.zig");
const text_component = @import("ui/components/Text.zig");
const ui = @import("ui.zig");

pub const status_component_id: u8 = 2;
pub const assistant_component_id: u8 = 1;
pub const tool_component_id: u8 = 3;
pub const stdout_component_id: u8 = 4;
pub const stderr_component_id: u8 = 5;
pub const diff_component_id: u8 = 6;
pub const input_component_id: u8 = 7;
pub const run_component_id: u8 = 8;

pub const input_hit_id: u32 = 50_007;
pub const run_hit_id: u32 = 50_008;

const max_text_bytes: usize = 4096;
const max_small_text_bytes: usize = 512;
const max_rows: usize = 6;

pub const State = struct {
    status: TextBuf(max_small_text_bytes) = TextBuf(max_small_text_bytes).init("offline"),
    run_label: TextBuf(64) = TextBuf(64).init("Run"),
    input: TextBuf(max_small_text_bytes) = TextBuf(max_small_text_bytes).init("Tell the local agent what to do…"),
    assistant: TextBuf(max_text_bytes) = TextBuf(max_text_bytes).init("Start the local Codex host to stream model/tool state here. The UI reads the existing ui_stream patch bytes directly; there is no JSON side protocol."),
    progress: f32 = 0.0,
    connected: bool = false,
    thinking: bool = false,
    tools: RowList = .{},
    stdout_rows: RowList = .{},
    stderr_rows: RowList = .{},
    diff_rows: RowList = .{},

    pub fn applyPatch(self: *State, patch: []const u8) !void {
        if (patch.len < 2) return error.BadUiStreamPatch;
        const kind = patch[0];
        const component_id = patch[1];
        const payload = patch[2..];
        switch (kind) {
            8 => try self.applyTwoString(component_id, payload), // card_text
            13 => try self.applyString(component_id, payload), // label_value
            26 => try self.applyString(component_id, payload), // button_label
            42 => try self.applyF32(component_id, payload), // progress_value
            48 => try self.applyTwoString(component_id, payload), // row_item
            else => {},
        }
    }

    pub fn applyMessage(self: *State, message: []const u8) !void {
        if (message.len < 1) return error.BadUiStreamMessage;
        switch (message[0]) {
            1 => try self.applyPatch(message[1..]),
            else => {},
        }
    }

    fn applyString(self: *State, component_id: u8, payload: []const u8) !void {
        const value = try readString(payload, 0);
        switch (component_id) {
            status_component_id => {
                self.status.set(value.value);
                self.connected = !std.mem.eql(u8, value.value, "offline");
                self.thinking = std.mem.indexOf(u8, value.value, "thinking") != null or std.mem.indexOf(u8, value.value, "finalizing") != null;
            },
            run_component_id => self.run_label.set(value.value),
            input_component_id => self.input.set(value.value),
            else => {},
        }
    }

    fn applyTwoString(self: *State, component_id: u8, payload: []const u8) !void {
        const first = try readString(payload, 0);
        const second = try readString(payload, first.next);
        switch (component_id) {
            assistant_component_id => self.assistant.set(second.value),
            tool_component_id => self.tools.push(first.value, second.value),
            stdout_component_id => self.stdout_rows.push(first.value, second.value),
            stderr_component_id => self.stderr_rows.push(first.value, second.value),
            diff_component_id => self.diff_rows.push(first.value, second.value),
            else => {},
        }
    }

    fn applyF32(self: *State, component_id: u8, payload: []const u8) !void {
        if (payload.len < 4) return error.BadUiStreamPatch;
        if (component_id == status_component_id) self.progress = std.math.clamp(@as(f32, @bitCast(std.mem.readInt(u32, payload[0..4], .little))), 0.0, 1.0);
    }
};

pub fn contentHeight(width: f32, state: State) f32 {
    _ = width;
    _ = state;
    return 760.0;
}

pub fn render(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, state: State) !void {
    const palette = design.palette;
    const style = design.style();
    const pad: f32 = 24.0;
    const gap: f32 = 14.0;
    const content = bounds.insetUniform(pad);

    try scene.pushRect(bounds, palette.bg, .fill, 0.0, 0.0);

    const hero = ui.Rect.init(content.x, content.y, content.w, 112.0);
    try scene.pushRect(hero, ui.Color{ .r = 13, .g = 18, .b = 28 }, .fill, design.surface_radius, 0.0);
    try scene.pushRect(hero, palette.border, .border, design.surface_radius, 0.0);
    try icon_component.Icon.named(.sparkles).renderColor(scene, ui.Rect.init(hero.x + 18.0, hero.y + 18.0, 28.0, 28.0), palette.primary);
    try text_component.Text.renderAligned(scene, ui.Rect.init(hero.x + 58.0, hero.y + 18.0, hero.w - 76.0, 22.0), "Owned local agent", palette.text, .start);
    try text_component.Text.renderWrapped(scene, ui.Rect.init(hero.x + 58.0, hero.y + 48.0, hero.w - 76.0, 44.0), "Runs from your own executable, talks to your local TabbyAPI-compatible model, streams binary ui_stream patches into this native app, and uses the existing work/executor path for tools.", palette.muted, .{ .line_height = 18.0, .average_char_width = 8.0, .max_lines = 3 });

    var y = hero.y + hero.h + gap;
    const status_row = ui.Rect.init(content.x, y, content.w, 48.0);
    try renderStatus(scene, status_row, state);
    y += status_row.h + gap;

    const input_h: f32 = 92.0;
    const input_rect = ui.Rect.init(content.x, y, content.w - 112.0, input_h);
    const run_rect = ui.Rect.init(input_rect.x + input_rect.w + 12.0, y + input_h - 40.0, 100.0, 40.0);
    try renderInput(scene, collector, input_rect, state);
    const run_button = button_component.Button{ .id = run_hit_id, .label = state.run_label.slice(), .variant = .primary, .icon_slot = icon_component.IconSlot.named(.leading, .send) };
    try run_button.render(scene, run_rect, .{ .style = style });
    try run_button.collectInteractions(collector, run_rect);
    y += input_h + gap;

    const assistant_h: f32 = 190.0;
    try (card_component.Card{ .title = "Assistant", .detail = state.assistant.slice(), .variant = .elevated }).render(scene, ui.Rect.init(content.x, y, content.w, assistant_h), .{ .style = style });
    y += assistant_h + gap;

    const columns_gap: f32 = 12.0;
    const col_w = (content.w - columns_gap) * 0.5;
    const tool_panel = ui.Rect.init(content.x, y, col_w, 210.0);
    const output_panel = ui.Rect.init(content.x + col_w + columns_gap, y, col_w, 210.0);
    try renderRows(scene, tool_panel, "Tools", "executor and model actions", state.tools, palette);
    try renderOutputRows(scene, output_panel, state, palette);
}

fn renderStatus(scene: *ui.Scene, bounds: ui.Rect, state: State) !void {
    const palette = design.palette;
    try scene.pushRect(bounds, ui.Color{ .r = 18, .g = 24, .b = 34 }, .fill, design.surface_radius, 0.0);
    try scene.pushRect(bounds, palette.border, .border, design.surface_radius, 0.0);
    const dot = ui.Rect.init(bounds.x + 16.0, bounds.y + 16.0, 14.0, 14.0);
    const dot_color = if (state.thinking) palette.primary else if (state.connected) ui.Color{ .r = 34, .g = 197, .b = 94 } else palette.dim;
    try scene.pushRect(dot, dot_color, .fill, 7.0, 0.0);
    try text_component.Text.renderAligned(scene, ui.Rect.init(bounds.x + 40.0, bounds.y + 10.0, bounds.w * 0.42, 18.0), state.status.slice(), palette.text, .start);
    const progress_bounds = ui.Rect.init(bounds.x + bounds.w * 0.52, bounds.y + 18.0, bounds.w * 0.42, 10.0);
    try scene.pushRect(progress_bounds, ui.Color{ .r = 31, .g = 41, .b = 55 }, .fill, 5.0, 0.0);
    try scene.pushRect(ui.Rect.init(progress_bounds.x, progress_bounds.y, progress_bounds.w * state.progress, progress_bounds.h), palette.primary, .fill, 5.0, 0.0);
}

fn renderInput(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, state: State) !void {
    const palette = design.palette;
    try scene.pushRect(bounds, ui.Color{ .r = 15, .g = 23, .b = 42 }, .fill, design.surface_radius, 0.0);
    try scene.pushRect(bounds, palette.border, .border, design.surface_radius, 0.0);
    try text_component.Text.renderWrapped(scene, bounds.insetUniform(14.0), state.input.slice(), palette.text, .{ .line_height = 19.0, .average_char_width = 8.0, .max_lines = 3 });
    try collector.addHit(bounds, .textarea, input_hit_id);
}

fn renderRows(scene: *ui.Scene, bounds: ui.Rect, title: []const u8, detail: []const u8, rows: RowList, palette: anytype) !void {
    try scene.pushRect(bounds, ui.Color{ .r = 13, .g = 18, .b = 28 }, .fill, design.surface_radius, 0.0);
    try scene.pushRect(bounds, palette.border, .border, design.surface_radius, 0.0);
    try text_component.Text.renderAligned(scene, ui.Rect.init(bounds.x + 14.0, bounds.y + 12.0, bounds.w - 28.0, 18.0), title, palette.text, .start);
    try text_component.Text.renderAligned(scene, ui.Rect.init(bounds.x + 14.0, bounds.y + 34.0, bounds.w - 28.0, 14.0), detail, palette.muted, .start);
    var y = bounds.y + 58.0;
    if (rows.len == 0) {
        try text_component.Text.renderAligned(scene, ui.Rect.init(bounds.x + 14.0, y, bounds.w - 28.0, 18.0), "No events yet", palette.dim, .start);
        return;
    }
    for (rows.items[0..rows.len]) |row| {
        try (row_item_component.RowItem{ .id = 0, .title = row.title.slice(), .detail = row.detail.slice() }).render(scene, ui.Rect.init(bounds.x + 8.0, y, bounds.w - 16.0, 42.0), .{ .style = design.style() });
        y += 46.0;
    }
}

fn renderOutputRows(scene: *ui.Scene, bounds: ui.Rect, state: State, palette: anytype) !void {
    try scene.pushRect(bounds, ui.Color{ .r = 13, .g = 18, .b = 28 }, .fill, design.surface_radius, 0.0);
    try scene.pushRect(bounds, palette.border, .border, design.surface_radius, 0.0);
    try text_component.Text.renderAligned(scene, ui.Rect.init(bounds.x + 14.0, bounds.y + 12.0, bounds.w - 28.0, 18.0), "Output", palette.text, .start);
    try text_component.Text.renderAligned(scene, ui.Rect.init(bounds.x + 14.0, bounds.y + 34.0, bounds.w - 28.0, 14.0), "stdout, stderr and diff preview", palette.muted, .start);
    var y = bounds.y + 58.0;
    var rendered = false;
    rendered = try renderRowGroup(scene, bounds, &y, state.stdout_rows, rendered, palette);
    rendered = try renderRowGroup(scene, bounds, &y, state.stderr_rows, rendered, palette);
    rendered = try renderRowGroup(scene, bounds, &y, state.diff_rows, rendered, palette);
    if (!rendered) try text_component.Text.renderAligned(scene, ui.Rect.init(bounds.x + 14.0, y, bounds.w - 28.0, 18.0), "No output yet", palette.dim, .start);
}

fn renderRowGroup(scene: *ui.Scene, bounds: ui.Rect, y: *f32, rows: RowList, rendered: bool, palette: anytype) !bool {
    _ = palette;
    var any = rendered;
    for (rows.items[0..rows.len]) |row| {
        try (row_item_component.RowItem{ .id = 0, .title = row.title.slice(), .detail = row.detail.slice() }).render(scene, ui.Rect.init(bounds.x + 8.0, y.*, bounds.w - 16.0, 42.0), .{ .style = design.style() });
        y.* += 46.0;
        any = true;
    }
    return any;
}

fn TextBuf(comptime capacity: usize) type {
    return struct {
        buf: [capacity]u8 = undefined,
        len: usize = 0,

        pub fn init(value: []const u8) @This() {
            var self = @This(){};
            self.set(value);
            return self;
        }

        pub fn set(self: *@This(), value: []const u8) void {
            const len = @min(capacity, value.len);
            @memcpy(self.buf[0..len], value[0..len]);
            self.len = len;
        }

        pub fn slice(self: @This()) []const u8 {
            return self.buf[0..self.len];
        }
    };
}

const Row = struct {
    title: TextBuf(128) = TextBuf(128).init(""),
    detail: TextBuf(512) = TextBuf(512).init(""),
};

const RowList = struct {
    items: [max_rows]Row = [_]Row{.{}} ** max_rows,
    len: usize = 0,

    fn push(self: *RowList, title: []const u8, detail: []const u8) void {
        if (self.len == max_rows) {
            std.mem.copyForwards(Row, self.items[0 .. max_rows - 1], self.items[1..max_rows]);
            self.len = max_rows - 1;
        }
        self.items[self.len].title.set(title);
        self.items[self.len].detail.set(detail);
        self.len += 1;
    }
};

const StringRead = struct { value: []const u8, next: usize };

fn readString(payload: []const u8, offset: usize) !StringRead {
    if (offset >= payload.len) return error.BadUiStreamPatch;
    const len: usize = payload[offset];
    const start = offset + 1;
    const end = start + len;
    if (end > payload.len) return error.BadUiStreamPatch;
    return .{ .value = payload[start..end], .next = end };
}

test "agent state applies existing ui_stream patch bytes" {
    var state = State{};
    try state.applyMessage(&.{ 1, 13, status_component_id, 5, 'r', 'e', 'a', 'd', 'y' });
    try std.testing.expectEqualStrings("ready", state.status.slice());
    try state.applyMessage(&.{ 1, 8, assistant_component_id, 9, 'a', 's', 's', 'i', 's', 't', 'a', 'n', 't', 2, 'o', 'k' });
    try std.testing.expectEqualStrings("ok", state.assistant.slice());
}
