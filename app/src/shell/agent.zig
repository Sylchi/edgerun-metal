const std = @import("std");
const math = @import("../math.zig");
const bytes = @import("../bytes.zig");
const badge_component = @import("../ui/components/Badge.zig");
const button_component = @import("../ui/components/Button.zig");
const card_component = @import("../ui/components/Card.zig");
const display_component = @import("../ui/components/Display.zig");
const icon_component = @import("../ui/components/Icon.zig");
const interaction = @import("../ui/interaction.zig");
const design = @import("../ui/theme.zig");
const row_item_component = @import("../ui/components/RowItem.zig");
const textarea_component = @import("../ui/components/Textarea.zig");
const text_component = @import("../ui/components/Text.zig");
const ui = @import("../ui/core.zig");

pub const assistant_component_id: u8 = 1;
pub const status_component_id: u8 = 2;
pub const tool_component_id: u8 = 3;
pub const stdout_component_id: u8 = 4;
pub const stderr_component_id: u8 = 5;
pub const diff_component_id: u8 = 6;
pub const input_component_id: u8 = 7;
pub const run_component_id: u8 = 8;

pub const input_hit_id: u32 = 50_007;
pub const run_hit_id: u32 = 50_008;
pub const open_host_binary_button_id: u32 = 50_009;
pub const agent_row_id_base: u32 = 50_100;

const max_text_bytes: usize = 4096;
const max_small_text_bytes: usize = 512;
const max_rows: usize = 6;
const max_agents: usize = 7;
const context_window_tokens: u32 = 32 * 1024;
pub const default_host_api_url: []const u8 = "http://192.168.1.201:5001/v1";
pub const host_not_connected_notice: []const u8 = "Host is not connected. Start host binary at:";
pub const host_launch_requested_notice: []const u8 = "Host launch requested. Make sure host binary is running and retry.";
pub const host_launching_notice: []const u8 = "Starting host binary: codex-host";
pub const host_launch_failed_notice: []const u8 = "Host binary launch failed. Run 'cargo build -p codex-host' in /home/ken/edgerun and retry.";

pub const AgentSlot = struct {
    name: []const u8,
    role: []const u8,
    model: []const u8,
    context_used: u32 = 0,
    active: bool = false,
};

const default_agents = [_]AgentSlot{
    .{ .name = "Dispatcher", .role = "classifies task and selects pipeline", .model = "devstral-20b", .context_used = 2048, .active = true },
    .{ .name = "Codebase", .role = "keeps repo map and relevant files warm", .model = "devstral-20b", .context_used = 8192 },
    .{ .name = "Architect", .role = "compresses plan into minimal change set", .model = "devstral-20b", .context_used = 6144 },
    .{ .name = "Toolsmith", .role = "chooses exact shell/fs/test tools", .model = "devstral-20b", .context_used = 3072 },
    .{ .name = "Executor", .role = "turns plan into one focused patch", .model = "devstral-20b", .context_used = 6144 },
    .{ .name = "Reviewer", .role = "reviews diff and predicts breakage", .model = "devstral-20b", .context_used = 4096 },
    .{ .name = "Summarizer", .role = "returns compact durable memory", .model = "devstral-20b", .context_used = 2048 },
};

pub const State = struct {
    status: TextBuf(max_small_text_bytes) = TextBuf(max_small_text_bytes).init("offline"),
    run_label: TextBuf(64) = TextBuf(64).init("Run pipeline"),
    input: TextBuf(max_small_text_bytes) = TextBuf(max_small_text_bytes).init("Describe the outcome. The pipeline will dispatch, plan, execute, review, and summarize automatically."),
    assistant: TextBuf(max_text_bytes) = TextBuf(max_text_bytes).init("Pipeline mode: Dispatcher → Codebase → Architect → Toolsmith → Executor → Reviewer → Summarizer. Fixed role prompts improve cache locality and keep each step under the 32k context budget."),
    progress: f32 = 0.0,
    connected: bool = false,
    host_url: []const u8 = default_host_api_url,
    host_launch_requested: bool = false,
    host_launch_generation: u32 = 0,
    thinking: bool = false,
    context_used: u32 = 0,
    active_agent_index: usize = 0,
    agents: [max_agents]AgentSlot = default_agents,
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
            8 => try self.applyTwoString(component_id, payload),
            13 => try self.applyString(component_id, payload),
            26 => try self.applyString(component_id, payload),
            42 => try self.applyF32(component_id, payload),
            48 => try self.applyTwoString(component_id, payload),
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

    pub fn contextRatio(self: State) f32 {
        return math.clampF(@as(f32, @floatFromInt(self.context_used)) / @as(f32, @floatFromInt(context_window_tokens)), 0.0, 1.0);
    }

    fn applyString(self: *State, component_id: u8, payload: []const u8) !void {
        const value = try readString(payload, 0);
        switch (component_id) {
            status_component_id => {
                self.status.set(value.value);
                self.connected = !bytes.eql(value.value, "offline");
                self.thinking = bytes.indexOf(value.value, "thinking") != null or bytes.indexOf(value.value, "finalizing") != null or bytes.indexOf(value.value, "pipeline") != null;
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
        if (component_id == status_component_id) self.progress = math.clampF(@as(f32, @bitCast(std.mem.readInt(u32, payload[0..4], .little))), 0.0, 1.0);
    }
};

pub fn contentHeight(width: f32, state: State) f32 {
    _ = width;
    _ = state;
    return 900.0;
}

pub fn render(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, state: State) !void {
    const style = design.appStyle();
    const pad: f32 = 24.0;
    const gap: f32 = 14.0;
    const content = bounds.insetUniform(pad);

    var y = content.y;
    try renderHero(scene, ui.Rect.init(content.x, y, content.w, 112.0), state, style);
    y += 112.0 + gap;

    const status_h: f32 = 118.0;
    const context_h: f32 = 118.0;
    const half_gap: f32 = 12.0;
    const half_w = (content.w - half_gap) * 0.5;
    try renderStatusCard(scene, collector, ui.Rect.init(content.x, y, half_w, status_h), state, style);
    try renderContextCard(scene, ui.Rect.init(content.x + half_w + half_gap, y, half_w, context_h), state, style);
    y += @max(status_h, context_h) + gap;

    const prompt_h: f32 = 96.0;
    const prompt_rect = ui.Rect.init(content.x, y, content.w - 136.0, prompt_h);
    const run_rect = ui.Rect.init(prompt_rect.x + prompt_rect.w + 12.0, y + prompt_h - 40.0, 124.0, 40.0);
    const textarea = textarea_component.Textarea{ .id = input_hit_id, .placeholder = state.input.slice() };
    try textarea.render(scene, prompt_rect, .{ .style = style });
    try textarea.collectInteractions(collector, prompt_rect);
    const run_button = button_component.Button{ .id = run_hit_id, .label = state.run_label.slice(), .variant = .primary, .icon_slot = icon_component.IconSlot.named(.leading, .send) };
    try run_button.render(scene, run_rect, .{ .style = style, .control = .{ .loading = state.thinking } });
    try run_button.collectInteractions(collector, run_rect);
    y += prompt_h + gap;

    const agent_h: f32 = 306.0;
    const transcript_h: f32 = 306.0;
    try renderAgents(scene, collector, ui.Rect.init(content.x, y, half_w, agent_h), state, style);
    try renderTranscript(scene, ui.Rect.init(content.x + half_w + half_gap, y, half_w, transcript_h), state, style);
    y += @max(agent_h, transcript_h) + gap;

    const tool_h: f32 = 220.0;
    try renderRows(scene, ui.Rect.init(content.x, y, half_w, tool_h), "Pipeline events", "fixed prompts, handoffs and tool choices", state.tools, style);
    try renderOutputRows(scene, ui.Rect.init(content.x + half_w + half_gap, y, half_w, tool_h), state, style);
}

fn renderHero(scene: *ui.Scene, bounds: ui.Rect, state: State, style: ui.Style) !void {
    _ = state;
    try (card_component.Card{
        .title = "Owned local agent pipeline",
        .detail = "User gives one request. Dispatcher classifies it; Codebase selects context; Architect compresses the plan; Toolsmith chooses tools; Executor makes one focused patch; Reviewer checks it; Summarizer writes durable memory. Fixed prompts keep devstral-20b cache-friendly on 32k context.",
        .variant = .elevated,
    }).render(scene, bounds, .{ .style = style });
}

fn renderStatusCard(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, state: State, style: ui.Style) !void {
    try (card_component.Card{ .title = "Runtime", .detail = "", .variant = .panel }).render(scene, bounds, .{ .style = style });
    const badge_label = if (state.thinking) "pipeline" else if (state.connected) "ready" else "offline";
    const badge_variant: @TypeOf((badge_component.Badge{ .label = "" }).variant) = if (state.thinking) .default else if (state.connected) .secondary else .outline;
    try (badge_component.Badge{ .label = badge_label, .variant = badge_variant }).render(scene, ui.Rect.init(bounds.x + 16.0, bounds.y + 42.0, 112.0, 24.0), .{ .style = style });
    if (state.thinking) {
        try text_component.Text.renderAligned(scene, ui.Rect.init(bounds.x + 140.0, bounds.y + 44.0, bounds.w - 156.0, 18.0), state.status.slice(), style.text, .start);
        try (display_component.Progress{ .value = state.progress }).render(scene, ui.Rect.init(bounds.x + 16.0, bounds.y + 68.0, bounds.w - 32.0, 12.0), .{ .style = style });
        return;
    }
    if (state.connected) {
        try text_component.Text.renderAligned(scene, ui.Rect.init(bounds.x + 140.0, bounds.y + 44.0, bounds.w - 156.0, 18.0), state.status.slice(), style.text, .start);
        try (display_component.Progress{ .value = state.progress }).render(scene, ui.Rect.init(bounds.x + 16.0, bounds.y + 68.0, bounds.w - 32.0, 12.0), .{ .style = style });
        return;
    }
    const host_notice = if (state.host_launch_requested) host_launch_requested_notice else host_not_connected_notice;
    try text_component.Text.renderAligned(scene, ui.Rect.init(bounds.x + 16.0, bounds.y + 44.0, bounds.w - 32.0, 18.0), host_notice, style.text, .start);
    try text_component.Text.renderAligned(scene, ui.Rect.init(bounds.x + 16.0, bounds.y + 64.0, bounds.w - 32.0, 18.0), state.host_url, style.text, .start);
    const launch_button = button_component.Button{
        .id = open_host_binary_button_id,
        .label = "Open host API",
        .variant = .secondary,
        .icon_slot = icon_component.IconSlot.named(.leading, .network),
    };
    const launch_rect = ui.Rect.init(bounds.x + 16.0, bounds.y + 84.0, bounds.w - 32.0, 22.0);
    try launch_button.render(scene, launch_rect, .{ .style = style });
    try launch_button.collectInteractions(collector, launch_rect);
}

fn renderContextCard(scene: *ui.Scene, bounds: ui.Rect, state: State, style: ui.Style) !void {
    var detail_buf: [128]u8 = undefined;
    const total = pipelineContextUsed(state);
    const detail = std.fmt.bufPrint(&detail_buf, "{d} / {d} tokens across {d} fixed-role prompts", .{ total, context_window_tokens, state.agents.len }) catch "32k context budget";
    try (card_component.Card{ .title = "32k context budget", .detail = detail, .variant = .panel }).render(scene, bounds, .{ .style = style });
    try (display_component.Progress{ .value = math.clampF(@as(f32, @floatFromInt(total)) / @as(f32, @floatFromInt(context_window_tokens)), 0.0, 1.0) }).render(scene, ui.Rect.init(bounds.x + 16.0, bounds.y + 68.0, bounds.w - 32.0, 12.0), .{ .style = style });
}

fn renderAgents(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, state: State, style: ui.Style) !void {
    try (card_component.Card{ .title = "Expert pipeline", .detail = "automatic role chain", .variant = .panel }).render(scene, bounds, .{ .style = style });
    var y = bounds.y + 58.0;
    for (state.agents, 0..) |agent, index| {
        var detail_buf: [176]u8 = undefined;
        const detail = std.fmt.bufPrint(&detail_buf, "{s} · {s} · {d} tokens", .{ agent.role, agent.model, agent.context_used }) catch agent.role;
        const row = row_item_component.RowItem{ .id = agent_row_id_base + @as(u32, @intCast(index)), .title = agent.name, .detail = detail };
        try row.render(scene, ui.Rect.init(bounds.x + 8.0, y, bounds.w - 16.0, 34.0), .{ .style = style, .control = .{ .active = agent.active } });
        try row.collectInteractions(collector, ui.Rect.init(bounds.x + 8.0, y, bounds.w - 16.0, 34.0));
        y += 36.0;
    }
}

fn renderTranscript(scene: *ui.Scene, bounds: ui.Rect, state: State, style: ui.Style) !void {
    try (card_component.Card{ .title = "Result", .detail = state.assistant.slice(), .variant = .elevated }).render(scene, bounds, .{ .style = style });
}

fn renderRows(scene: *ui.Scene, bounds: ui.Rect, title: []const u8, detail: []const u8, rows: RowList, style: ui.Style) !void {
    try (card_component.Card{ .title = title, .detail = detail, .variant = .panel }).render(scene, bounds, .{ .style = style });
    var y = bounds.y + 58.0;
    if (rows.len == 0) {
        try (row_item_component.RowItem{ .id = 0, .title = "No events yet", .detail = "waiting for pipeline stream" }).render(scene, ui.Rect.init(bounds.x + 8.0, y, bounds.w - 16.0, 42.0), .{ .style = style });
        return;
    }
    for (rows.items[0..rows.len]) |row| {
        try (row_item_component.RowItem{ .id = 0, .title = row.title.slice(), .detail = row.detail.slice() }).render(scene, ui.Rect.init(bounds.x + 8.0, y, bounds.w - 16.0, 42.0), .{ .style = style });
        y += 46.0;
    }
}

fn renderOutputRows(scene: *ui.Scene, bounds: ui.Rect, state: State, style: ui.Style) !void {
    try (card_component.Card{ .title = "Output", .detail = "stdout, stderr and diff preview", .variant = .panel }).render(scene, bounds, .{ .style = style });
    var y = bounds.y + 58.0;
    var rendered = false;
    rendered = try renderRowGroup(scene, bounds, &y, state.stdout_rows, rendered, style);
    rendered = try renderRowGroup(scene, bounds, &y, state.stderr_rows, rendered, style);
    rendered = try renderRowGroup(scene, bounds, &y, state.diff_rows, rendered, style);
    if (!rendered) try (row_item_component.RowItem{ .id = 0, .title = "No output yet", .detail = "tool output will appear here" }).render(scene, ui.Rect.init(bounds.x + 8.0, y, bounds.w - 16.0, 42.0), .{ .style = style });
}

fn renderRowGroup(scene: *ui.Scene, bounds: ui.Rect, y: *f32, rows: RowList, rendered: bool, style: ui.Style) !bool {
    var any = rendered;
    for (rows.items[0..rows.len]) |row| {
        try (row_item_component.RowItem{ .id = 0, .title = row.title.slice(), .detail = row.detail.slice() }).render(scene, ui.Rect.init(bounds.x + 8.0, y.*, bounds.w - 16.0, 42.0), .{ .style = style });
        y.* += 46.0;
        any = true;
    }
    return any;
}

fn pipelineContextUsed(state: State) u32 {
    var total: u32 = 0;
    for (state.agents) |agent| total += agent.context_used;
    return total;
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

test "agent render composes native components" {
    var commands: [4096]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [64]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);
    try render(&scene, &collector, ui.Rect.init(0, 0, 1280, 900), .{});
    try std.testing.expect(scene.written().len != 0);
    try std.testing.expect(collector.written().len >= 2);
}
