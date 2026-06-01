const std = @import("std");
const math = @import("../math.zig");
const bytes = @import("../bytes.zig");
const clock = @import("../clock.zig");
const component = @import("../ui/components/Component.zig");
const grant = @import("../grant.zig");
const identity = @import("../identity.zig");
const intent = @import("../intent.zig");
const object = @import("../object.zig");
const interaction = @import("../ui/interaction.zig");
const design = @import("../ui/theme.zig");
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
const max_events: usize = max_rows * 4;
const max_session_children: usize = max_events + 1;
const max_agents: usize = 7;
const max_tools: usize = 7;
const context_window_tokens: u32 = 32 * 1024;
pub const agent_cell_payload_size: usize = 251;
pub const agent_cell_inline_args_size: usize = 149;
pub const agent_request_body_size: usize = 196;
pub const agent_event_body_size: usize = 198;
pub const stage_transition_body_size: usize = 168;
pub const tool_request_body_size: usize = 132;
pub const tool_result_body_size: usize = 132;
pub const patch_body_size: usize = 164;
pub const review_body_size: usize = 132;
pub const summary_body_size: usize = 132;
pub const default_host_api_url: []const u8 = "http://192.168.1.201:5001/v1";
pub const host_not_connected_notice: []const u8 = "Host is not connected. Start host binary at:";
pub const host_launch_requested_notice: []const u8 = "Host launch requested. Make sure host binary is running and retry.";
pub const host_launching_notice: []const u8 = "Starting host binary: codex-host";
pub const host_launch_failed_notice: []const u8 = "Host binary launch failed. Run 'cargo build -p codex-host' in /home/ken/edgerun and retry.";

pub const AgentSlot = struct {
    name: []const u8,
    role: []const u8,
    model: []const u8,
    identity: identity.Id,
    input_kind: AgentObjectKind,
    output_kind: AgentObjectKind,
    memory_grant: u64,
    tick_grant: u64,
    storage_grant: u64,
    context_used: u32 = 0,
    active: bool = false,

    pub fn admitsSpawnReceipt(self: AgentSlot, receipt: grant.SpawnReceipt) bool {
        return receipt.valid() and
            receipt.child.eql(self.identity) and
            receipt.memory.amount >= self.memory_grant and
            receipt.execution_ticks.amount >= self.tick_grant and
            receipt.storage_bytes.amount >= self.storage_grant;
    }

    pub fn admitsIntentReceipt(self: AgentSlot, receipt: intent.Receipt, subject: identity.Id, action: intent.Action, consequence: intent.Consequence) bool {
        return receipt.permits(self.identity, subject, action, consequence);
    }

    pub fn admitsObjectRequirements(self: AgentSlot, requirements: object.Requirements, consequence: intent.Consequence) bool {
        _ = self;
        return objectRequirementsPermitConsequence(requirements, consequence);
    }

    pub fn admitsExecution(self: AgentSlot, admission: StageAdmission) bool {
        return self.admitsSpawnReceipt(admission.spawn_receipt) and
            self.admitsIntentReceipt(admission.intent_receipt, admission.subject, admission.action, admission.consequence) and
            self.admitsObjectRequirements(admission.requirements, admission.consequence);
    }
};

pub const StageAdmission = struct {
    spawn_receipt: grant.SpawnReceipt,
    intent_receipt: intent.Receipt,
    subject: identity.Id,
    action: intent.Action,
    consequence: intent.Consequence,
    requirements: object.Requirements,
};

pub const AgentObjectKind = enum(u16) {
    request = 1,
    dispatch = 2,
    context = 3,
    plan = 4,
    tool_request = 5,
    tool_result = 6,
    patch = 7,
    review = 8,
    summary = 9,
};

pub const AgentEventKind = enum(u8) {
    stage_start = 1,
    stage_result = 2,
    tool_request = 3,
    tool_result = 4,
    approval_request = 5,
    approval_result = 6,
    receipt = 7,
    output = 8,
    warning = 9,
    artifact = 10,
};

pub const AgentMessageType = enum(u8) {
    request = 1,
    response = 2,
    @"error" = 3,
    stage_start = 4,
    stage_result = 5,
    tool_request = 6,
    tool_result = 7,
    approval_request = 8,
    approval_result = 9,
    receipt = 10,
};

pub const AgentCellEnvelope = struct {
    msg_type: AgentMessageType,
    flags: u8 = 0,
    sender_slot: u32,
    request_object: [object.id_size]u8,
    input_object: [object.id_size]u8,
    grant_or_receipt: [object.id_size]u8,
    inline_args: [agent_cell_inline_args_size]u8 = [_]u8{0} ** agent_cell_inline_args_size,
    inline_len: usize = 0,

    pub fn encode(self: AgentCellEnvelope, out: []u8) bool {
        if (out.len < agent_cell_payload_size or self.sender_slot == 0 or self.inline_len > agent_cell_inline_args_size) return false;
        if (!bytes.nonzero(&self.request_object) or !bytes.nonzero(&self.input_object) or !bytes.nonzero(&self.grant_or_receipt)) return false;
        @memset(out[0..agent_cell_payload_size], 0);
        out[0] = @intFromEnum(self.msg_type);
        out[1] = self.flags;
        return bytes.store32(out[2..6], self.sender_slot) and
            bytes.copy(out[6..38], &self.request_object) and
            bytes.copy(out[38..70], &self.input_object) and
            bytes.copy(out[70..102], &self.grant_or_receipt) and
            bytes.copy(out[102 .. 102 + self.inline_len], self.inline_args[0..self.inline_len]);
    }

    pub fn decode(in: []const u8) ?AgentCellEnvelope {
        if (in.len < agent_cell_payload_size) return null;
        const envelope = AgentCellEnvelope{
            .msg_type = agentMessageTypeFromInt(in[0]) orelse return null,
            .flags = in[1],
            .sender_slot = bytes.load32(in[2..6]) orelse return null,
            .request_object = idFromBytes(in[6..38]),
            .input_object = idFromBytes(in[38..70]),
            .grant_or_receipt = idFromBytes(in[70..102]),
            .inline_args = inlineArgsFromBytes(in[102..251]),
            .inline_len = agent_cell_inline_args_size,
        };
        if (envelope.sender_slot == 0 or !bytes.nonzero(&envelope.request_object) or !bytes.nonzero(&envelope.input_object) or !bytes.nonzero(&envelope.grant_or_receipt)) return null;
        return envelope;
    }
};

pub const AgentToolKind = enum(u16) {
    read_object = 1,
    write_object = 2,
    search_index = 3,
    apply_patch = 4,
    build = 5,
    @"test" = 6,
    render_snapshot = 7,
};

pub const ToolStatus = enum(u16) {
    ok = 1,
    denied = 2,
    failed = 3,
};

pub const StageStatus = enum(u16) {
    completed = 1,
    denied = 2,
    failed = 3,
};

pub const ReviewDecision = enum(u16) {
    accepted = 1,
    rejected = 2,
    needs_work = 3,
};

pub const ToolService = struct {
    label: []const u8,
    kind: AgentToolKind,
    identity: identity.Id,
    input_kind: AgentObjectKind = .tool_request,
    output_kind: AgentObjectKind = .tool_result,
    memory_grant: u64,
    tick_grant: u64,
    storage_grant: u64,
};

const default_agents = [_]AgentSlot{
    stage("Dispatcher", "classifies task and selects pipeline", .request, .dispatch, 2048, true, 1),
    stage("Codebase", "keeps repo map and relevant files warm", .dispatch, .context, 8192, false, 2),
    stage("Architect", "compresses plan into minimal change set", .context, .plan, 6144, false, 3),
    stage("Toolsmith", "chooses exact shell/fs/test tools", .plan, .tool_request, 3072, false, 4),
    stage("Executor", "turns plan into one focused patch", .tool_result, .patch, 6144, false, 5),
    stage("Reviewer", "reviews diff and predicts breakage", .patch, .review, 4096, false, 6),
    stage("Summarizer", "returns compact durable memory", .review, .summary, 2048, false, 7),
};

const default_tools = [_]ToolService{
    toolService("edgerun.tool.read_object", .read_object, 11),
    toolService("edgerun.tool.write_object", .write_object, 12),
    toolService("edgerun.tool.search_index", .search_index, 13),
    toolService("edgerun.tool.apply_patch", .apply_patch, 14),
    toolService("edgerun.tool.build", .build, 15),
    toolService("edgerun.tool.test", .@"test", 16),
    toolService("edgerun.tool.render_snapshot", .render_snapshot, 17),
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
    events: AgentEventList = .{},

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
            tool_component_id => self.events.push(.tool_request, self.active_agent_index, first.value, second.value),
            stdout_component_id => self.events.push(.output, self.active_agent_index, first.value, second.value),
            stderr_component_id => self.events.push(.warning, self.active_agent_index, first.value, second.value),
            diff_component_id => self.events.push(.artifact, self.active_agent_index, first.value, second.value),
            else => {},
        }
    }

    fn applyF32(self: *State, component_id: u8, payload: []const u8) !void {
        if (payload.len < 4) return error.BadUiStreamPatch;
        if (component_id == status_component_id) self.progress = math.clampF(@as(f32, @bitCast(std.mem.readInt(u32, payload[0..4], .little))), 0.0, 1.0);
    }
};

pub fn messageLen(message: []const u8) ?usize {
    if (message.len < 1) return null;
    return switch (message[0]) {
        1 => if (patchLen(message[1..])) |len| 1 + len else null,
        else => 1,
    };
}

fn patchLen(patch: []const u8) ?usize {
    if (patch.len < 2) return null;
    const payload = patch[2..];
    return switch (patch[0]) {
        8, 48 => blk: {
            const first = readString(payload, 0) catch return null;
            const second = readString(payload, first.next) catch return null;
            break :blk 2 + second.next;
        },
        13, 26 => blk: {
            const value = readString(payload, 0) catch return null;
            break :blk 2 + value.next;
        },
        42 => if (payload.len < 4) null else 6,
        else => 2,
    };
}

pub fn contentHeight(width: f32, state: State) f32 {
    _ = width;
    _ = state;
    return 900.0;
}

pub fn render(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, state: State) !void {
    const style = design.appStyle();
    const app = component.renderer(scene, collector, .{ .style = style });
    try renderView(app, bounds, state);
}

pub fn renderView(app: component.View, bounds: ui.Rect, state: State) !void {
    const pad: f32 = 24.0;
    const gap: f32 = 14.0;
    const content = bounds.insetUniform(pad);

    var page = app.column(content, gap);
    try renderHero(app, page.take(112.0), state);

    const status_h: f32 = 118.0;
    const context_h: f32 = 118.0;
    const half_gap: f32 = 12.0;
    const half_w = (content.w - half_gap) * 0.5;
    var summary = app.row(page.take(@max(status_h, context_h)), half_gap);
    try renderStatusCard(app, summary.take(half_w), state);
    try renderContextCard(app, summary.take(half_w), state);

    const prompt_h: f32 = 96.0;
    const prompt_row = page.take(prompt_h);
    const prompt_rect = ui.Rect.init(prompt_row.x, prompt_row.y, prompt_row.w - 136.0, prompt_h);
    const run_rect = ui.Rect.init(prompt_rect.x + prompt_rect.w + 12.0, prompt_row.y + prompt_h - 40.0, 124.0, 40.0);
    try app.textareaPlaceholderAt(prompt_rect, input_hit_id, state.input.slice());
    const run_button = if (state.thinking)
        component.buttonIcon(run_hit_id, state.run_label.slice(), .primary, .send).loading()
    else
        component.buttonIcon(run_hit_id, state.run_label.slice(), .primary, .send);
    try app.interactive(run_button, run_rect);

    const agent_h: f32 = 306.0;
    const transcript_h: f32 = 306.0;
    var agents = app.row(page.take(@max(agent_h, transcript_h)), half_gap);
    try renderAgents(app, agents.take(half_w), state);
    try renderTranscript(app, agents.take(half_w), state);

    const tool_h: f32 = 220.0;
    var tools = app.row(page.take(tool_h), half_gap);
    try renderRows(app, tools.take(half_w), "Pipeline events", "object-backed stage and tool events", state);
    try renderOutputRows(app, tools.take(half_w), state);
}

fn renderHero(app: component.View, bounds: ui.Rect, state: State) !void {
    _ = state;
    try app.elevatedAt(
        bounds,
        "Owned local agent pipeline",
        "User gives one request. Dispatcher classifies it; Codebase selects context; Architect compresses the plan; Toolsmith chooses tools; Executor makes one focused patch; Reviewer checks it; Summarizer writes durable memory. Fixed prompts keep devstral-20b cache-friendly on 32k context.",
    );
}

fn renderStatusCard(app: component.View, bounds: ui.Rect, state: State) !void {
    const body = try app.panelScaffold(bounds, .{
        .title = "Runtime",
        .inset = 16.0,
        .header_gap = 0.0,
    });
    const badge_label = if (state.thinking) "pipeline" else if (state.connected) "ready" else "offline";
    const badge_variant: component.BadgeVariant = if (state.thinking) .default else if (state.connected) .secondary else .outline;
    try app.badgeAt(ui.Rect.init(body.x, body.y, 112.0, 24.0), badge_label, badge_variant);
    if (state.thinking) {
        try app.body(ui.Rect.init(body.x + 124.0, body.y + 2.0, @max(1.0, body.w - 124.0), 18.0), state.status.slice());
        try app.progressAt(ui.Rect.init(body.x, body.y + 26.0, body.w, 12.0), state.progress);
        return;
    }
    if (state.connected) {
        try app.body(ui.Rect.init(body.x + 124.0, body.y + 2.0, @max(1.0, body.w - 124.0), 18.0), state.status.slice());
        try app.progressAt(ui.Rect.init(body.x, body.y + 26.0, body.w, 12.0), state.progress);
        return;
    }
    const host_notice = if (state.host_launch_requested) host_launch_requested_notice else host_not_connected_notice;
    try app.body(ui.Rect.init(body.x, body.y + 2.0, body.w, 18.0), host_notice);
    try app.body(ui.Rect.init(body.x, body.y + 22.0, body.w, 18.0), state.host_url);
    const launch_rect = ui.Rect.init(body.x, body.y + 42.0, body.w, 22.0);
    try app.buttonIconAt(launch_rect, open_host_binary_button_id, "Open host API", .secondary, .network);
}

fn renderContextCard(app: component.View, bounds: ui.Rect, state: State) !void {
    var detail_buf: [128]u8 = undefined;
    const total = pipelineContextUsed(state);
    const detail = std.fmt.bufPrint(&detail_buf, "{d} / {d} tokens across {d} fixed-role prompts", .{ total, context_window_tokens, state.agents.len }) catch "32k context budget";
    const body = try app.panelScaffold(bounds, .{
        .title = "32k context budget",
        .detail = detail,
        .inset = 16.0,
        .header_gap = 10.0,
    });
    try app.progressAt(ui.Rect.init(body.x, body.y, body.w, 12.0), math.clampF(@as(f32, @floatFromInt(total)) / @as(f32, @floatFromInt(context_window_tokens)), 0.0, 1.0));
}

fn renderAgents(app: component.View, bounds: ui.Rect, state: State) !void {
    var items: [max_agents]component.SemanticItem = undefined;
    var detail_bufs: [max_agents][176]u8 = undefined;
    const projected = writeAgentSemanticItems(state, &items, &detail_bufs);
    try app.semanticView(bounds, .{
        .title = "Expert pipeline",
        .detail = "automatic role chain",
        .intent = .{ .mode = .debug, .focus = .general, .density = .compact },
        .items = projected,
    });
}

fn writeAgentSemanticItems(state: State, items: *[max_agents]component.SemanticItem, detail_bufs: *[max_agents][176]u8) []const component.SemanticItem {
    for (state.agents, 0..) |agent, index| {
        const detail = std.fmt.bufPrint(&detail_bufs[index], "{s} · {s} · {d} tokens", .{ agent.role, agent.model, agent.context_used }) catch agent.role;
        items[index] = .{
            .id = agent_row_id_base + @as(u32, @intCast(index)),
            .kind = .identity,
            .label = agent.name,
            .detail = detail,
            .state = if (agent.active) .active else .neutral,
            .progress = math.clampF(@as(f32, @floatFromInt(agent.context_used)) / @as(f32, @floatFromInt(context_window_tokens)), 0.0, 1.0),
            .selected = agent.active,
        };
    }
    return items[0..state.agents.len];
}

fn renderTranscript(app: component.View, bounds: ui.Rect, state: State) !void {
    try app.elevatedAt(bounds, "Result", state.assistant.slice());
}

fn renderRows(app: component.View, bounds: ui.Rect, title: []const u8, detail: []const u8, state: State) !void {
    var items: [max_events]component.SemanticItem = undefined;
    const len = appendSemanticEvents(&items, 0, state, .pipeline);
    try app.semanticView(bounds, .{
        .title = title,
        .detail = detail,
        .intent = .{ .mode = .debug, .focus = .general, .density = .compact },
        .items = items[0..len],
    });
}

fn renderOutputRows(app: component.View, bounds: ui.Rect, state: State) !void {
    var items: [max_events]component.SemanticItem = undefined;
    const len = appendSemanticEvents(&items, 0, state, .output);
    try app.semanticView(bounds, .{
        .title = "Output",
        .detail = "object outputs, warnings and artifacts",
        .intent = .{ .mode = .debug, .focus = .errors, .density = .compact },
        .items = items[0..len],
    });
}

const EventProjection = enum { pipeline, output };

fn appendSemanticEvents(items: []component.SemanticItem, offset: usize, state: State, projection: EventProjection) usize {
    var next = offset;
    for (state.events.items[0..state.events.len]) |event| {
        if (!eventInProjection(event.kind, projection)) continue;
        if (next >= items.len) break;
        items[next] = .{
            .kind = semanticKindForEvent(event.kind),
            .label = event.title.slice(),
            .value = semanticValueForEvent(event),
            .detail = event.detail.slice(),
            .state = semanticStateForEvent(event),
        };
        next += 1;
    }
    return next;
}

fn eventInProjection(kind: AgentEventKind, projection: EventProjection) bool {
    return switch (projection) {
        .pipeline => switch (kind) {
            .stage_start,
            .stage_result,
            .tool_request,
            .tool_result,
            .approval_request,
            .approval_result,
            .receipt,
            => true,
            .output,
            .warning,
            .artifact,
            => false,
        },
        .output => switch (kind) {
            .output,
            .warning,
            .artifact,
            => true,
            .stage_start,
            .stage_result,
            .tool_request,
            .tool_result,
            .approval_request,
            .approval_result,
            .receipt,
            => false,
        },
    };
}

fn semanticKindForEvent(kind: AgentEventKind) component.SemanticKind {
    return switch (kind) {
        .stage_start, .stage_result => .timeline,
        .tool_request, .tool_result, .approval_request, .approval_result => .action,
        .receipt, .output => .event,
        .warning => .warning,
        .artifact => .artifact,
    };
}

fn semanticValueForEvent(event: AgentEvent) []const u8 {
    if (bytes.nonzero(&event.receipt)) return "receipt";
    if (bytes.nonzero(&event.output_object)) return "object";
    if (bytes.nonzero(&event.input_object)) return "input";
    return "pending";
}

fn semanticStateForEvent(event: AgentEvent) component.SemanticState {
    if ((event.kind == .stage_result or event.kind == .tool_result or event.kind == .receipt or event.kind == .artifact) and !bytes.nonzero(&event.receipt)) return .pending;
    if (event.kind == .artifact and bytes.nonzero(&event.receipt)) return .good;
    return switch (event.kind) {
        .stage_start, .tool_request, .approval_request => .active,
        .stage_result, .tool_result, .approval_result, .receipt, .output => .good,
        .warning => .warning,
        .artifact => .pending,
    };
}

fn pipelineContextUsed(state: State) u32 {
    var total: u32 = 0;
    for (state.agents) |agent| total += agent.context_used;
    return total;
}

fn pipelineShapeValid(stages: []const AgentSlot) bool {
    if (stages.len == 0) return false;
    var index: usize = 1;
    while (index < stages.len) : (index += 1) {
        if (!stageOutputFeedsInput(stages[index - 1].output_kind, stages[index].input_kind)) return false;
    }
    return true;
}

fn stageOutputFeedsInput(output_kind: AgentObjectKind, input_kind: AgentObjectKind) bool {
    return output_kind == input_kind or
        (output_kind == .tool_request and input_kind == .tool_result);
}

fn objectRequirementsPermitConsequence(requirements: object.Requirements, consequence: intent.Consequence) bool {
    return switch (consequence) {
        .exports_data => requirements.visibility == .public and requirements.confidentiality == .public,
        .reads_private_state => requirements.access == .explicit_io,
        .writes_private_state => requirements.visibility != .public,
        .delegates_resources,
        .attests_state,
        .creates_secret_material,
        => true,
    };
}

fn stage(name: []const u8, role: []const u8, input_kind: AgentObjectKind, output_kind: AgentObjectKind, context_used: u32, active: bool, comptime identity_byte: u8) AgentSlot {
    return .{
        .name = name,
        .role = role,
        .model = "devstral-20b",
        .identity = stageIdentity(identity_byte),
        .input_kind = input_kind,
        .output_kind = output_kind,
        .memory_grant = 64 * 1024 * 1024,
        .tick_grant = 10_000,
        .storage_grant = 4 * 1024 * 1024,
        .context_used = context_used,
        .active = active,
    };
}

fn stageIdentity(comptime value: u8) identity.Id {
    return .{ .bytes = [_]u8{value} ++ [_]u8{0} ** (identity.id_size - 1) };
}

fn toolService(label: []const u8, kind: AgentToolKind, comptime identity_byte: u8) ToolService {
    return .{
        .label = label,
        .kind = kind,
        .identity = stageIdentity(identity_byte),
        .memory_grant = 16 * 1024 * 1024,
        .tick_grant = 2_000,
        .storage_grant = 2 * 1024 * 1024,
    };
}

fn toolServiceFor(kind: AgentToolKind) ?ToolService {
    for (default_tools) |service| {
        if (service.kind == kind) return service;
    }
    return null;
}

fn encodeStamp(value: clock.Stamp, out: []u8) bool {
    if (out.len < 64) return false;
    return bytes.copy(out[0..32], &value.keeper.bytes) and
        bytes.store64(out[32..40], value.tick) and
        bytes.store64(out[40..48], value.slot) and
        bytes.store64(out[48..56], value.epoch) and
        bytes.store64(out[56..64], value.era);
}

fn decodeStamp(in: []const u8) ?clock.Stamp {
    if (in.len < 64) return null;
    return .{
        .keeper = .{ .bytes = idFromBytes(in[0..32]) },
        .tick = bytes.load64(in[32..40]) orelse return null,
        .slot = bytes.load64(in[40..48]) orelse return null,
        .epoch = bytes.load64(in[48..56]) orelse return null,
        .era = bytes.load64(in[56..64]) orelse return null,
    };
}

fn idFromBytes(in: []const u8) [32]u8 {
    var out: [32]u8 = undefined;
    @memcpy(&out, in[0..32]);
    return out;
}

fn inlineArgsFromBytes(in: []const u8) [agent_cell_inline_args_size]u8 {
    var out = [_]u8{0} ** agent_cell_inline_args_size;
    @memcpy(&out, in[0..agent_cell_inline_args_size]);
    return out;
}

fn agentEventKindFromInt(value: u16) ?AgentEventKind {
    return switch (value) {
        1 => .stage_start,
        2 => .stage_result,
        3 => .tool_request,
        4 => .tool_result,
        5 => .approval_request,
        6 => .approval_result,
        7 => .receipt,
        8 => .output,
        9 => .warning,
        10 => .artifact,
        else => null,
    };
}

fn agentMessageTypeFromInt(value: u8) ?AgentMessageType {
    return switch (value) {
        1 => .request,
        2 => .response,
        3 => .@"error",
        4 => .stage_start,
        5 => .stage_result,
        6 => .tool_request,
        7 => .tool_result,
        8 => .approval_request,
        9 => .approval_result,
        10 => .receipt,
        else => null,
    };
}

fn agentObjectKindFromInt(value: u16) ?AgentObjectKind {
    return switch (value) {
        1 => .request,
        2 => .dispatch,
        3 => .context,
        4 => .plan,
        5 => .tool_request,
        6 => .tool_result,
        7 => .patch,
        8 => .review,
        9 => .summary,
        else => null,
    };
}

fn toolStatusFromInt(value: u16) ?ToolStatus {
    return switch (value) {
        1 => .ok,
        2 => .denied,
        3 => .failed,
        else => null,
    };
}

fn stageStatusFromInt(value: u16) ?StageStatus {
    return switch (value) {
        1 => .completed,
        2 => .denied,
        3 => .failed,
        else => null,
    };
}

fn intentActionFromInt(value: u16) ?intent.Action {
    return switch (value) {
        1 => .spawn_app,
        2 => .grant_resource,
        3 => .seal_data,
        4 => .unseal_data,
        5 => .sync_data,
        6 => .emit_ui_event,
        7 => .sign_data,
        8 => .random_bytes,
        else => null,
    };
}

fn intentConsequenceFromInt(value: u16) ?intent.Consequence {
    return switch (value) {
        1 => .reads_private_state,
        2 => .writes_private_state,
        3 => .delegates_resources,
        4 => .exports_data,
        5 => .attests_state,
        6 => .creates_secret_material,
        else => null,
    };
}

fn testSpawnReceipt(parent: identity.Id, child: identity.Id, epoch: clock.Stamp, memory_amount: u64, tick_amount: u64, storage_amount: u64) grant.SpawnReceipt {
    return .{
        .parent = parent,
        .child = child,
        .memory = .{ .issuer = parent, .subject = child, .resource = .memory, .amount = memory_amount, .epoch = epoch },
        .storage_bytes = .{ .issuer = parent, .subject = child, .resource = .storage_bytes, .amount = storage_amount, .epoch = epoch },
        .storage_slots = .{ .issuer = parent, .subject = child, .resource = .storage_slots, .amount = 0, .epoch = epoch },
        .execution_ticks = .{ .issuer = parent, .subject = child, .resource = .execution_ticks, .amount = tick_amount, .epoch = epoch },
        .route_handles = .{ .issuer = parent, .subject = child, .resource = .route_handles, .amount = 0, .epoch = epoch },
        .device_handles = .{ .issuer = parent, .subject = child, .resource = .device_handles, .amount = 0, .epoch = epoch },
    };
}

fn testIntentReceipt(user: identity.Id, device: identity.Id, actor: identity.Id, subject: identity.Id, action: intent.Action, consequence: intent.Consequence, epoch: clock.Stamp, request: [intent.id_size]u8) intent.Receipt {
    return .{
        .intent = .{
            .user = user,
            .device = device,
            .actor = actor,
            .subject = subject,
            .action = action,
            .consequence = consequence,
            .epoch = epoch,
            .request = request,
        },
        .admitted_by = device,
        .not_before = epoch,
        .not_after = epoch,
    };
}

fn reviewDecisionFromInt(value: u16) ?ReviewDecision {
    return switch (value) {
        1 => .accepted,
        2 => .rejected,
        3 => .needs_work,
        else => null,
    };
}

fn sessionTestRequirements() object.Requirements {
    return .{
        .durability = .memory,
        .confidentiality = .integrity_only,
        .portability = .machine_bound,
        .integrity = .hash_only,
        .lifetime = .session,
        .visibility = .app_namespace,
        .access = .explicit_io,
    };
}

fn publicExportRequirements() object.Requirements {
    return .{
        .durability = .memory,
        .confidentiality = .public,
        .portability = .public_portable,
        .integrity = .hash_only,
        .lifetime = .session,
        .visibility = .public,
        .access = .explicit_io,
    };
}

pub const AgentRequest = struct {
    user: identity.Id,
    device: identity.Id,
    actor: identity.Id,
    subject: identity.Id,
    action: intent.Action,
    consequence: intent.Consequence,
    request_id: [intent.id_size]u8,
    requirements_hash: [object.id_size]u8,

    pub fn init(user: identity.Id, device: identity.Id, actor: identity.Id, subject: identity.Id, action: intent.Action, consequence: intent.Consequence, request_id: [intent.id_size]u8, requirements: object.Requirements) ?AgentRequest {
        if (!user.valid() or !device.valid() or !actor.valid() or !subject.valid() or !bytes.nonzero(&request_id)) return null;
        return .{
            .user = user,
            .device = device,
            .actor = actor,
            .subject = subject,
            .action = action,
            .consequence = consequence,
            .request_id = request_id,
            .requirements_hash = requirements.hash(),
        };
    }

    pub fn encodeBody(self: AgentRequest, out: []u8) bool {
        if (out.len < agent_request_body_size) return false;
        @memset(out[0..agent_request_body_size], 0);
        return bytes.copy(out[0..32], &self.user.bytes) and
            bytes.copy(out[32..64], &self.device.bytes) and
            bytes.copy(out[64..96], &self.actor.bytes) and
            bytes.copy(out[96..128], &self.subject.bytes) and
            bytes.store16(out[128..130], @intFromEnum(self.action)) and
            bytes.store16(out[130..132], @intFromEnum(self.consequence)) and
            bytes.copy(out[132..164], &self.request_id) and
            bytes.copy(out[164..196], &self.requirements_hash);
    }

    pub fn decodeBody(in: []const u8) ?AgentRequest {
        if (in.len < agent_request_body_size) return null;
        const request = AgentRequest{
            .user = .{ .bytes = idFromBytes(in[0..32]) },
            .device = .{ .bytes = idFromBytes(in[32..64]) },
            .actor = .{ .bytes = idFromBytes(in[64..96]) },
            .subject = .{ .bytes = idFromBytes(in[96..128]) },
            .action = intentActionFromInt(bytes.load16(in[128..130]) orelse return null) orelse return null,
            .consequence = intentConsequenceFromInt(bytes.load16(in[130..132]) orelse return null) orelse return null,
            .request_id = idFromBytes(in[132..164]),
            .requirements_hash = idFromBytes(in[164..196]),
        };
        if (!request.user.valid() or !request.device.valid() or !request.actor.valid() or !request.subject.valid() or !bytes.nonzero(&request.request_id) or !bytes.nonzero(&request.requirements_hash)) return null;
        return request;
    }

    pub fn receipt(self: AgentRequest, epoch: clock.Stamp) ?intent.Receipt {
        if (!epoch.valid()) return null;
        return .{
            .intent = .{
                .user = self.user,
                .device = self.device,
                .actor = self.actor,
                .subject = self.subject,
                .action = self.action,
                .consequence = self.consequence,
                .epoch = epoch,
                .request = self.request_id,
            },
            .admitted_by = self.device,
            .not_before = epoch,
            .not_after = epoch,
        };
    }

    pub fn writeObject(self: AgentRequest, requirements: object.Requirements, epoch: clock.Stamp, out: []u8) ![]u8 {
        var body: [agent_request_body_size]u8 = undefined;
        if (!self.encodeBody(&body)) return error.BadUiStreamPatch;
        return try (object.NodeWriter{ .out = out }).bytesNode(requirements, epoch, &body);
    }
};

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

pub const AgentEvent = struct {
    sequence: u32 = 0,
    stage_identity: identity.Id = .{ .bytes = [_]u8{0} ** identity.id_size },
    kind: AgentEventKind = .stage_start,
    clock_stamp: clock.Stamp = .{ .keeper = .{ .bytes = [_]u8{0} ** clock.keeper_id_size } },
    input_object: [object.id_size]u8 = [_]u8{0} ** object.id_size,
    output_object: [object.id_size]u8 = [_]u8{0} ** object.id_size,
    receipt: [object.id_size]u8 = [_]u8{0} ** object.id_size,
    title: TextBuf(128) = TextBuf(128).init(""),
    detail: TextBuf(512) = TextBuf(512).init(""),

    pub fn encodeBody(self: AgentEvent, out: []u8) bool {
        if (out.len < agent_event_body_size) return false;
        @memset(out[0..agent_event_body_size], 0);
        return bytes.store32(out[0..4], self.sequence) and
            bytes.copy(out[4..36], &self.stage_identity.bytes) and
            bytes.store16(out[36..38], @intFromEnum(self.kind)) and
            encodeStamp(self.clock_stamp, out[38..102]) and
            bytes.copy(out[102..134], &self.input_object) and
            bytes.copy(out[134..166], &self.output_object) and
            bytes.copy(out[166..198], &self.receipt);
    }

    pub fn decodeBody(in: []const u8) ?AgentEvent {
        if (in.len < agent_event_body_size) return null;
        return .{
            .sequence = bytes.load32(in[0..4]) orelse return null,
            .stage_identity = .{ .bytes = idFromBytes(in[4..36]) },
            .kind = agentEventKindFromInt(bytes.load16(in[36..38]) orelse return null) orelse return null,
            .clock_stamp = decodeStamp(in[38..102]) orelse return null,
            .input_object = idFromBytes(in[102..134]),
            .output_object = idFromBytes(in[134..166]),
            .receipt = idFromBytes(in[166..198]),
        };
    }

    pub fn writeObject(self: AgentEvent, requirements: object.Requirements, out: []u8) ![]u8 {
        var body: [agent_event_body_size]u8 = undefined;
        if (!self.encodeBody(&body)) return error.BadUiStreamPatch;
        return try (object.NodeWriter{ .out = out }).bytesNode(requirements, self.clock_stamp, &body);
    }
};

pub const AgentSession = struct {
    children: [max_session_children]object.Child = undefined,
    len: usize = 0,
    logical_len: u64 = 0,

    pub fn init(request: object.Child) ?AgentSession {
        if (!request.valid(0)) return null;
        var self = AgentSession{};
        self.children[0] = request;
        self.len = 1;
        self.logical_len = request.logical_len;
        return self;
    }

    pub fn appendEvent(self: *AgentSession, event: object.Child) bool {
        if (self.len == max_session_children) return false;
        if (!event.valid(self.logical_len)) return false;
        self.children[self.len] = event;
        self.len += 1;
        self.logical_len += event.logical_len;
        return true;
    }

    pub fn appendEventView(self: *AgentSession, view: object.View) bool {
        if (view.header.kind != .bytes or view.header.body_len != agent_event_body_size) return false;
        if (AgentEvent.decodeBody(view.body) == null) return false;
        const child = object.Child.fromView(view, self.logical_len) catch return false;
        return self.appendEvent(child);
    }

    pub fn treeChildren(self: *const AgentSession) []const object.Child {
        return self.children[0..self.len];
    }

    pub fn writeObject(self: *const AgentSession, requirements: object.Requirements, epoch: clock.Stamp, out: []u8) ![]u8 {
        if (self.len == 0) return error.BadUiStreamPatch;
        return try (object.NodeWriter{ .out = out }).treeNode(requirements, epoch, self.treeChildren());
    }

    pub fn viewEventCount(view: object.View) ?usize {
        if (view.header.kind != .tree or view.header.child_count == 0) return null;
        return @as(usize, @intCast(view.header.child_count - 1));
    }

    pub fn eventChildAt(view: object.View, event_index: usize) ?object.Child {
        const count = viewEventCount(view) orelse return null;
        if (event_index >= count) return null;
        return view.childAt(event_index + 1) catch null;
    }

    pub fn eventCount(self: AgentSession) usize {
        return if (self.len == 0) 0 else self.len - 1;
    }
};

pub const StageTransition = struct {
    stage_identity: identity.Id,
    input_kind: AgentObjectKind,
    output_kind: AgentObjectKind,
    input_object: [object.id_size]u8,
    grant_or_receipt: [object.id_size]u8,
    output_object: [object.id_size]u8,
    completion_receipt: [object.id_size]u8,
    status: StageStatus,

    pub fn init(stage_slot: AgentSlot, input_object: [object.id_size]u8, grant_or_receipt: [object.id_size]u8, output_object: [object.id_size]u8, completion_receipt: [object.id_size]u8, status: StageStatus) ?StageTransition {
        if (!stage_slot.identity.valid() or
            !bytes.nonzero(&input_object) or
            !bytes.nonzero(&grant_or_receipt) or
            !bytes.nonzero(&output_object) or
            !bytes.nonzero(&completion_receipt)) return null;
        return .{
            .stage_identity = stage_slot.identity,
            .input_kind = stage_slot.input_kind,
            .output_kind = stage_slot.output_kind,
            .input_object = input_object,
            .grant_or_receipt = grant_or_receipt,
            .output_object = output_object,
            .completion_receipt = completion_receipt,
            .status = status,
        };
    }

    pub fn matchesStage(self: StageTransition, stage_slot: AgentSlot) bool {
        return self.stage_identity.eql(stage_slot.identity) and
            self.input_kind == stage_slot.input_kind and
            self.output_kind == stage_slot.output_kind;
    }

    pub fn event(self: StageTransition, sequence: u32, stamp: clock.Stamp) AgentEvent {
        return .{
            .sequence = sequence,
            .stage_identity = self.stage_identity,
            .kind = if (self.status == .completed) .stage_result else .warning,
            .clock_stamp = stamp,
            .input_object = self.input_object,
            .output_object = self.output_object,
            .receipt = self.completion_receipt,
        };
    }

    pub fn envelope(self: StageTransition, sender_slot: u32) ?AgentCellEnvelope {
        if (sender_slot == 0) return null;
        return .{
            .msg_type = if (self.status == .completed) .stage_result else .@"error",
            .sender_slot = sender_slot,
            .request_object = self.output_object,
            .input_object = self.input_object,
            .grant_or_receipt = self.completion_receipt,
        };
    }

    pub fn fromEnvelope(stage_slot: AgentSlot, envelope_value: AgentCellEnvelope) ?StageTransition {
        const status: StageStatus = switch (envelope_value.msg_type) {
            .stage_result => .completed,
            .@"error" => .failed,
            else => return null,
        };
        return init(
            stage_slot,
            envelope_value.input_object,
            envelope_value.grant_or_receipt,
            envelope_value.request_object,
            envelope_value.grant_or_receipt,
            status,
        );
    }

    pub fn encodeBody(self: StageTransition, out: []u8) bool {
        if (out.len < stage_transition_body_size) return false;
        @memset(out[0..stage_transition_body_size], 0);
        return bytes.copy(out[0..32], &self.stage_identity.bytes) and
            bytes.store16(out[32..34], @intFromEnum(self.input_kind)) and
            bytes.store16(out[34..36], @intFromEnum(self.output_kind)) and
            bytes.copy(out[36..68], &self.input_object) and
            bytes.copy(out[68..100], &self.grant_or_receipt) and
            bytes.copy(out[100..132], &self.output_object) and
            bytes.copy(out[132..164], &self.completion_receipt) and
            bytes.store16(out[164..166], @intFromEnum(self.status)) and
            bytes.store16(out[166..168], 0);
    }

    pub fn decodeBody(in: []const u8) ?StageTransition {
        if (in.len < stage_transition_body_size) return null;
        if ((bytes.load16(in[166..168]) orelse return null) != 0) return null;
        const transition = StageTransition{
            .stage_identity = .{ .bytes = idFromBytes(in[0..32]) },
            .input_kind = agentObjectKindFromInt(bytes.load16(in[32..34]) orelse return null) orelse return null,
            .output_kind = agentObjectKindFromInt(bytes.load16(in[34..36]) orelse return null) orelse return null,
            .input_object = idFromBytes(in[36..68]),
            .grant_or_receipt = idFromBytes(in[68..100]),
            .output_object = idFromBytes(in[100..132]),
            .completion_receipt = idFromBytes(in[132..164]),
            .status = stageStatusFromInt(bytes.load16(in[164..166]) orelse return null) orelse return null,
        };
        if (!transition.stage_identity.valid() or
            !bytes.nonzero(&transition.input_object) or
            !bytes.nonzero(&transition.grant_or_receipt) or
            !bytes.nonzero(&transition.output_object) or
            !bytes.nonzero(&transition.completion_receipt)) return null;
        return transition;
    }
};

pub const ToolRequest = struct {
    service_identity: identity.Id,
    request_object: [object.id_size]u8,
    input_object: [object.id_size]u8,
    grant_or_receipt: [object.id_size]u8,
    output_kind: AgentObjectKind = .tool_result,

    pub fn init(service: ToolService, request_object: [object.id_size]u8, input_object: [object.id_size]u8, grant_or_receipt: [object.id_size]u8) ?ToolRequest {
        if (!service.identity.valid() or !bytes.nonzero(&request_object) or !bytes.nonzero(&input_object) or !bytes.nonzero(&grant_or_receipt)) return null;
        return .{
            .service_identity = service.identity,
            .request_object = request_object,
            .input_object = input_object,
            .grant_or_receipt = grant_or_receipt,
            .output_kind = service.output_kind,
        };
    }

    pub fn encodeBody(self: ToolRequest, out: []u8) bool {
        if (out.len < tool_request_body_size) return false;
        @memset(out[0..tool_request_body_size], 0);
        return bytes.copy(out[0..32], &self.service_identity.bytes) and
            bytes.copy(out[32..64], &self.request_object) and
            bytes.copy(out[64..96], &self.input_object) and
            bytes.copy(out[96..128], &self.grant_or_receipt) and
            bytes.store16(out[128..130], @intFromEnum(self.output_kind)) and
            bytes.store16(out[130..132], 0);
    }

    pub fn decodeBody(in: []const u8) ?ToolRequest {
        if (in.len < tool_request_body_size) return null;
        if ((bytes.load16(in[130..132]) orelse return null) != 0) return null;
        const request = ToolRequest{
            .service_identity = .{ .bytes = idFromBytes(in[0..32]) },
            .request_object = idFromBytes(in[32..64]),
            .input_object = idFromBytes(in[64..96]),
            .grant_or_receipt = idFromBytes(in[96..128]),
            .output_kind = agentObjectKindFromInt(bytes.load16(in[128..130]) orelse return null) orelse return null,
        };
        if (!request.service_identity.valid() or !bytes.nonzero(&request.request_object) or !bytes.nonzero(&request.input_object) or !bytes.nonzero(&request.grant_or_receipt)) return null;
        return request;
    }

    pub fn envelope(self: ToolRequest, sender_slot: u32) ?AgentCellEnvelope {
        if (sender_slot == 0) return null;
        return .{
            .msg_type = .tool_request,
            .sender_slot = sender_slot,
            .request_object = self.request_object,
            .input_object = self.input_object,
            .grant_or_receipt = self.grant_or_receipt,
        };
    }

    pub fn fromEnvelope(service: ToolService, envelope_value: AgentCellEnvelope) ?ToolRequest {
        if (envelope_value.msg_type != .tool_request) return null;
        return init(service, envelope_value.request_object, envelope_value.input_object, envelope_value.grant_or_receipt);
    }
};

pub const ToolResult = struct {
    service_identity: identity.Id,
    request_object: [object.id_size]u8,
    output_object: [object.id_size]u8,
    receipt: [object.id_size]u8,
    status: ToolStatus,

    pub fn encodeBody(self: ToolResult, out: []u8) bool {
        if (out.len < tool_result_body_size) return false;
        @memset(out[0..tool_result_body_size], 0);
        return bytes.copy(out[0..32], &self.service_identity.bytes) and
            bytes.copy(out[32..64], &self.request_object) and
            bytes.copy(out[64..96], &self.output_object) and
            bytes.copy(out[96..128], &self.receipt) and
            bytes.store16(out[128..130], @intFromEnum(self.status)) and
            bytes.store16(out[130..132], 0);
    }

    pub fn decodeBody(in: []const u8) ?ToolResult {
        if (in.len < tool_result_body_size) return null;
        if ((bytes.load16(in[130..132]) orelse return null) != 0) return null;
        const result = ToolResult{
            .service_identity = .{ .bytes = idFromBytes(in[0..32]) },
            .request_object = idFromBytes(in[32..64]),
            .output_object = idFromBytes(in[64..96]),
            .receipt = idFromBytes(in[96..128]),
            .status = toolStatusFromInt(bytes.load16(in[128..130]) orelse return null) orelse return null,
        };
        if (!result.service_identity.valid() or !bytes.nonzero(&result.request_object) or !bytes.nonzero(&result.output_object) or !bytes.nonzero(&result.receipt)) return null;
        return result;
    }

    pub fn event(self: ToolResult, sequence: u32, stamp: clock.Stamp) AgentEvent {
        return .{
            .sequence = sequence,
            .stage_identity = self.service_identity,
            .kind = if (self.status == .ok) .tool_result else .warning,
            .clock_stamp = stamp,
            .input_object = self.request_object,
            .output_object = self.output_object,
            .receipt = self.receipt,
        };
    }

    pub fn envelope(self: ToolResult, sender_slot: u32) ?AgentCellEnvelope {
        if (sender_slot == 0) return null;
        return .{
            .msg_type = if (self.status == .ok) .tool_result else .@"error",
            .sender_slot = sender_slot,
            .request_object = self.request_object,
            .input_object = self.output_object,
            .grant_or_receipt = self.receipt,
        };
    }

    pub fn fromEnvelope(service: ToolService, envelope_value: AgentCellEnvelope) ?ToolResult {
        const status: ToolStatus = switch (envelope_value.msg_type) {
            .tool_result => .ok,
            .@"error" => .failed,
            else => return null,
        };
        if (!service.identity.valid() or !bytes.nonzero(&envelope_value.request_object) or !bytes.nonzero(&envelope_value.input_object) or !bytes.nonzero(&envelope_value.grant_or_receipt)) return null;
        return .{
            .service_identity = service.identity,
            .request_object = envelope_value.request_object,
            .output_object = envelope_value.input_object,
            .receipt = envelope_value.grant_or_receipt,
            .status = status,
        };
    }
};

pub const PatchObject = struct {
    plan_object: [object.id_size]u8,
    patch_object: [object.id_size]u8,
    tool_result: [object.id_size]u8,
    receipt: [object.id_size]u8,
    status: StageStatus,

    pub fn encodeBody(self: PatchObject, out: []u8) bool {
        if (out.len < patch_body_size) return false;
        @memset(out[0..patch_body_size], 0);
        return bytes.copy(out[0..32], &self.plan_object) and
            bytes.copy(out[32..64], &self.patch_object) and
            bytes.copy(out[64..96], &self.tool_result) and
            bytes.copy(out[96..128], &self.receipt) and
            bytes.store16(out[128..130], @intFromEnum(self.status)) and
            bytes.store16(out[130..132], 0);
    }

    pub fn decodeBody(in: []const u8) ?PatchObject {
        if (in.len < patch_body_size) return null;
        if ((bytes.load16(in[130..132]) orelse return null) != 0) return null;
        const patch = PatchObject{
            .plan_object = idFromBytes(in[0..32]),
            .patch_object = idFromBytes(in[32..64]),
            .tool_result = idFromBytes(in[64..96]),
            .receipt = idFromBytes(in[96..128]),
            .status = stageStatusFromInt(bytes.load16(in[128..130]) orelse return null) orelse return null,
        };
        if (!bytes.nonzero(&patch.plan_object) or !bytes.nonzero(&patch.patch_object) or !bytes.nonzero(&patch.tool_result) or !bytes.nonzero(&patch.receipt)) return null;
        return patch;
    }

    pub fn event(self: PatchObject, sequence: u32, stamp: clock.Stamp, stage_identity: identity.Id) AgentEvent {
        return .{
            .sequence = sequence,
            .stage_identity = stage_identity,
            .kind = if (self.status == .completed) .artifact else .warning,
            .clock_stamp = stamp,
            .input_object = self.plan_object,
            .output_object = self.patch_object,
            .receipt = self.receipt,
        };
    }
};

pub const ReviewObject = struct {
    patch_object: [object.id_size]u8,
    review_object: [object.id_size]u8,
    receipt: [object.id_size]u8,
    decision: ReviewDecision,

    pub fn encodeBody(self: ReviewObject, out: []u8) bool {
        if (out.len < review_body_size) return false;
        @memset(out[0..review_body_size], 0);
        return bytes.copy(out[0..32], &self.patch_object) and
            bytes.copy(out[32..64], &self.review_object) and
            bytes.copy(out[64..96], &self.receipt) and
            bytes.store16(out[96..98], @intFromEnum(self.decision)) and
            bytes.store16(out[98..100], 0);
    }

    pub fn decodeBody(in: []const u8) ?ReviewObject {
        if (in.len < review_body_size) return null;
        if ((bytes.load16(in[98..100]) orelse return null) != 0) return null;
        const review = ReviewObject{
            .patch_object = idFromBytes(in[0..32]),
            .review_object = idFromBytes(in[32..64]),
            .receipt = idFromBytes(in[64..96]),
            .decision = reviewDecisionFromInt(bytes.load16(in[96..98]) orelse return null) orelse return null,
        };
        if (!bytes.nonzero(&review.patch_object) or !bytes.nonzero(&review.review_object) or !bytes.nonzero(&review.receipt)) return null;
        return review;
    }

    pub fn event(self: ReviewObject, sequence: u32, stamp: clock.Stamp, stage_identity: identity.Id) AgentEvent {
        return .{
            .sequence = sequence,
            .stage_identity = stage_identity,
            .kind = if (self.decision == .accepted) .stage_result else .warning,
            .clock_stamp = stamp,
            .input_object = self.patch_object,
            .output_object = self.review_object,
            .receipt = self.receipt,
        };
    }
};

pub const SummaryObject = struct {
    review_object: [object.id_size]u8,
    summary_object: [object.id_size]u8,
    receipt: [object.id_size]u8,
    retained: bool,

    pub fn encodeBody(self: SummaryObject, out: []u8) bool {
        if (out.len < summary_body_size) return false;
        @memset(out[0..summary_body_size], 0);
        return bytes.copy(out[0..32], &self.review_object) and
            bytes.copy(out[32..64], &self.summary_object) and
            bytes.copy(out[64..96], &self.receipt) and
            bytes.store16(out[96..98], if (self.retained) 1 else 0) and
            bytes.store16(out[98..100], 0);
    }

    pub fn decodeBody(in: []const u8) ?SummaryObject {
        if (in.len < summary_body_size) return null;
        if ((bytes.load16(in[98..100]) orelse return null) != 0) return null;
        const retained_raw = bytes.load16(in[96..98]) orelse return null;
        if (retained_raw > 1) return null;
        const summary = SummaryObject{
            .review_object = idFromBytes(in[0..32]),
            .summary_object = idFromBytes(in[32..64]),
            .receipt = idFromBytes(in[64..96]),
            .retained = retained_raw == 1,
        };
        if (!bytes.nonzero(&summary.review_object) or !bytes.nonzero(&summary.summary_object) or !bytes.nonzero(&summary.receipt)) return null;
        return summary;
    }

    pub fn event(self: SummaryObject, sequence: u32, stamp: clock.Stamp, stage_identity: identity.Id) AgentEvent {
        return .{
            .sequence = sequence,
            .stage_identity = stage_identity,
            .kind = .stage_result,
            .clock_stamp = stamp,
            .input_object = self.review_object,
            .output_object = self.summary_object,
            .receipt = self.receipt,
        };
    }
};

const AgentEventList = struct {
    items: [max_events]AgentEvent = [_]AgentEvent{.{}} ** max_events,
    len: usize = 0,
    next_sequence: u32 = 1,

    fn push(self: *AgentEventList, kind: AgentEventKind, stage_index: usize, title: []const u8, detail: []const u8) void {
        if (self.len == max_events) {
            std.mem.copyForwards(AgentEvent, self.items[0 .. max_events - 1], self.items[1..max_events]);
            self.len = max_events - 1;
        }
        self.items[self.len] = .{
            .sequence = self.next_sequence,
            .stage_identity = if (stage_index < default_agents.len) default_agents[stage_index].identity else .{ .bytes = [_]u8{0} ** identity.id_size },
            .kind = kind,
        };
        self.items[self.len].title.set(title);
        self.items[self.len].detail.set(detail);
        self.len += 1;
        self.next_sequence +%= 1;
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

test "agent default pipeline is deterministic object flow" {
    try std.testing.expect(pipelineShapeValid(&default_agents));
    try std.testing.expect(stageOutputFeedsInput(.dispatch, .dispatch));
    try std.testing.expect(stageOutputFeedsInput(.tool_request, .tool_result));
    try std.testing.expect(!stageOutputFeedsInput(.plan, .review));
}

test "agent request is canonical object and emits intent receipt" {
    const req = sessionTestRequirements();
    const epoch = clock.Stamp{ .keeper = .{ .bytes = [_]u8{10} ++ [_]u8{0} ** 31 } };
    const user = stageIdentity(81);
    const device = stageIdentity(82);
    const actor = default_agents[0].identity;
    const subject = stageIdentity(83);
    const request_id = intent.requestId("agent request object").?;
    const request = AgentRequest.init(user, device, actor, subject, .emit_ui_event, .attests_state, request_id, req).?;

    var body: [agent_request_body_size]u8 = undefined;
    try std.testing.expect(request.encodeBody(&body));
    const decoded = AgentRequest.decodeBody(&body).?;
    try std.testing.expect(decoded.user.eql(user));
    try std.testing.expect(decoded.device.eql(device));
    try std.testing.expect(decoded.actor.eql(actor));
    try std.testing.expect(decoded.subject.eql(subject));
    try std.testing.expectEqual(intent.Action.emit_ui_event, decoded.action);
    try std.testing.expectEqual(intent.Consequence.attests_state, decoded.consequence);
    try std.testing.expect(bytes.eql(&request_id, &decoded.request_id));
    try std.testing.expect(bytes.eql(&req.hash(), &decoded.requirements_hash));

    const receipt = decoded.receipt(epoch).?;
    try std.testing.expect(receipt.permits(actor, subject, .emit_ui_event, .attests_state));
    try std.testing.expect(bytes.nonzero(&receipt.id().?));

    var raw: [512]u8 = undefined;
    const canonical = try decoded.writeObject(req, epoch, &raw);
    const view = try object.View.decode(canonical);
    try std.testing.expectEqual(object.Kind.bytes, view.header.kind);
    try std.testing.expectEqual(@as(u64, agent_request_body_size), view.header.body_len);
    try std.testing.expect(AgentRequest.decodeBody(view.body) != null);
}

test "agent stage admits only sufficient spawn receipts" {
    const stage_slot = default_agents[0];
    const parent = stageIdentity(88);
    const other_child = stageIdentity(89);
    const epoch = clock.Stamp{ .keeper = .{ .bytes = [_]u8{6} ++ [_]u8{0} ** 31 } };

    const admitted = testSpawnReceipt(parent, stage_slot.identity, epoch, stage_slot.memory_grant, stage_slot.tick_grant, stage_slot.storage_grant);
    try std.testing.expect(stage_slot.admitsSpawnReceipt(admitted));

    const wrong_child = testSpawnReceipt(parent, other_child, epoch, stage_slot.memory_grant, stage_slot.tick_grant, stage_slot.storage_grant);
    try std.testing.expect(!stage_slot.admitsSpawnReceipt(wrong_child));

    const underfunded = testSpawnReceipt(parent, stage_slot.identity, epoch, stage_slot.memory_grant - 1, stage_slot.tick_grant, stage_slot.storage_grant);
    try std.testing.expect(!stage_slot.admitsSpawnReceipt(underfunded));
}

test "agent stage admits only matching intent receipts" {
    const stage_slot = default_agents[2];
    const user = stageIdentity(91);
    const device = stageIdentity(92);
    const subject = stageIdentity(93);
    const other_subject = stageIdentity(94);
    const epoch = clock.Stamp{ .keeper = .{ .bytes = [_]u8{5} ++ [_]u8{0} ** 31 } };
    const request = [_]u8{4} ++ [_]u8{0} ** 31;

    const receipt = testIntentReceipt(user, device, stage_slot.identity, subject, .emit_ui_event, .attests_state, epoch, request);
    try std.testing.expect(stage_slot.admitsIntentReceipt(receipt, subject, .emit_ui_event, .attests_state));
    try std.testing.expect(!stage_slot.admitsIntentReceipt(receipt, other_subject, .emit_ui_event, .attests_state));
    try std.testing.expect(!stage_slot.admitsIntentReceipt(receipt, subject, .grant_resource, .delegates_resources));

    const wrong_actor = testIntentReceipt(user, device, default_agents[3].identity, subject, .emit_ui_event, .attests_state, epoch, request);
    try std.testing.expect(!stage_slot.admitsIntentReceipt(wrong_actor, subject, .emit_ui_event, .attests_state));
}

test "agent stage checks object requirements before export" {
    const stage_slot = default_agents[1];
    const private_req = sessionTestRequirements();
    const public_req = publicExportRequirements();

    try std.testing.expect(!stage_slot.admitsObjectRequirements(private_req, .exports_data));
    try std.testing.expect(stage_slot.admitsObjectRequirements(public_req, .exports_data));
    try std.testing.expect(stage_slot.admitsObjectRequirements(private_req, .reads_private_state));
    try std.testing.expect(!stage_slot.admitsObjectRequirements(public_req, .writes_private_state));
}

test "agent stage execution requires grant intent and object policy" {
    const stage_slot = default_agents[1];
    const parent = stageIdentity(95);
    const user = stageIdentity(96);
    const device = stageIdentity(97);
    const subject = stageIdentity(98);
    const epoch = clock.Stamp{ .keeper = .{ .bytes = [_]u8{8} ++ [_]u8{0} ** 31 } };
    const request = [_]u8{9} ++ [_]u8{0} ** 31;
    const spawn_receipt = testSpawnReceipt(parent, stage_slot.identity, epoch, stage_slot.memory_grant, stage_slot.tick_grant, stage_slot.storage_grant);
    const intent_receipt = testIntentReceipt(user, device, stage_slot.identity, subject, .emit_ui_event, .attests_state, epoch, request);
    const admission = StageAdmission{
        .spawn_receipt = spawn_receipt,
        .intent_receipt = intent_receipt,
        .subject = subject,
        .action = .emit_ui_event,
        .consequence = .attests_state,
        .requirements = sessionTestRequirements(),
    };
    try std.testing.expect(stage_slot.admitsExecution(admission));

    var wrong_spawn = admission;
    wrong_spawn.spawn_receipt = testSpawnReceipt(parent, stageIdentity(99), epoch, stage_slot.memory_grant, stage_slot.tick_grant, stage_slot.storage_grant);
    try std.testing.expect(!stage_slot.admitsExecution(wrong_spawn));

    var wrong_intent = admission;
    wrong_intent.subject = stageIdentity(100);
    try std.testing.expect(!stage_slot.admitsExecution(wrong_intent));

    var denied_export = admission;
    denied_export.consequence = .exports_data;
    denied_export.intent_receipt = testIntentReceipt(user, device, stage_slot.identity, subject, .emit_ui_event, .exports_data, epoch, request);
    try std.testing.expect(!stage_slot.admitsExecution(denied_export));
}

test "agent stream records object-native events" {
    var state = State{};
    try state.applyMessage(&.{ 1, 48, tool_component_id, 6, 's', 'e', 'a', 'r', 'c', 'h', 5, 'i', 'n', 'd', 'e', 'x' });
    try state.applyMessage(&.{ 1, 48, stderr_component_id, 4, 't', 'e', 's', 't', 7, 'f', 'a', 'i', 'l', 'e', 'd', '!' });

    try std.testing.expectEqual(@as(usize, 2), state.events.len);
    try std.testing.expectEqual(AgentEventKind.tool_request, state.events.items[0].kind);
    try std.testing.expect(state.events.items[0].stage_identity.eql(default_agents[0].identity));
    try std.testing.expectEqual(@as(u32, 1), state.events.items[0].sequence);
    try std.testing.expectEqual(AgentEventKind.warning, state.events.items[1].kind);
    try std.testing.expectEqual(@as(u32, 2), state.events.items[1].sequence);
}

test "agent events project into semantic pipeline and output views" {
    var state = State{};
    state.events.push(.tool_request, 0, "search", "index");
    state.events.push(.artifact, 0, "patch", "object id pending");

    var items: [max_events]component.SemanticItem = undefined;
    const pipeline_len = appendSemanticEvents(&items, 0, state, .pipeline);
    try std.testing.expectEqual(@as(usize, 1), pipeline_len);
    try std.testing.expectEqual(component.SemanticKind.action, items[0].kind);
    try std.testing.expectEqual(component.SemanticState.active, items[0].state);

    const output_len = appendSemanticEvents(&items, 0, state, .output);
    try std.testing.expectEqual(@as(usize, 1), output_len);
    try std.testing.expectEqual(component.SemanticKind.artifact, items[0].kind);
    try std.testing.expectEqual(component.SemanticState.pending, items[0].state);

    state.events.items[1].output_object = [_]u8{1} ++ [_]u8{0} ** 31;
    state.events.items[1].receipt = [_]u8{2} ++ [_]u8{0} ** 31;
    const receipted_output_len = appendSemanticEvents(&items, 0, state, .output);
    try std.testing.expectEqual(@as(usize, 1), receipted_output_len);
    try std.testing.expectEqualStrings("receipt", items[0].value);
    try std.testing.expectEqual(component.SemanticState.good, items[0].state);
}

test "agent event has fixed canonical object body" {
    const event = AgentEvent{
        .sequence = 42,
        .stage_identity = default_agents[3].identity,
        .kind = .tool_result,
        .clock_stamp = .{
            .keeper = .{ .bytes = [_]u8{9} ++ [_]u8{0} ** 31 },
            .tick = 1,
            .slot = 2,
            .epoch = 3,
            .era = 4,
        },
        .input_object = [_]u8{1} ++ [_]u8{0} ** 31,
        .output_object = [_]u8{2} ++ [_]u8{0} ** 31,
        .receipt = [_]u8{3} ++ [_]u8{0} ** 31,
    };

    var raw: [agent_event_body_size]u8 = undefined;
    try std.testing.expect(event.encodeBody(&raw));
    const decoded = AgentEvent.decodeBody(&raw).?;
    try std.testing.expectEqual(event.sequence, decoded.sequence);
    try std.testing.expect(event.stage_identity.eql(decoded.stage_identity));
    try std.testing.expectEqual(event.kind, decoded.kind);
    try std.testing.expectEqual(event.clock_stamp.tick, decoded.clock_stamp.tick);
    try std.testing.expect(bytes.eql(&event.input_object, &decoded.input_object));
    try std.testing.expect(bytes.eql(&event.output_object, &decoded.output_object));
    try std.testing.expect(bytes.eql(&event.receipt, &decoded.receipt));
}

test "agent session is an ordered object tree" {
    const req = sessionTestRequirements();
    const request_child = object.Child{
        .object_id = [_]u8{1} ++ [_]u8{0} ** 31,
        .logical_offset = 0,
        .logical_len = 12,
        .kind = .bytes,
        .requirements_hash = req.hash(),
    };
    const event_child = object.Child{
        .object_id = [_]u8{2} ++ [_]u8{0} ** 31,
        .logical_offset = request_child.logical_len,
        .logical_len = agent_event_body_size,
        .kind = .bytes,
        .requirements_hash = req.hash(),
    };
    var session = AgentSession.init(request_child).?;
    try std.testing.expect(session.appendEvent(event_child));
    try std.testing.expectEqual(@as(usize, 1), session.eventCount());

    const epoch = clock.Stamp{ .keeper = .{ .bytes = [_]u8{7} ++ [_]u8{0} ** 31 } };
    var raw: [object.header_size + object.child_size * 2]u8 = undefined;
    const canonical = try session.writeObject(req, epoch, &raw);
    const view = try object.View.decode(canonical);

    try std.testing.expectEqual(object.Kind.tree, view.header.kind);
    try std.testing.expectEqual(@as(u32, 2), view.header.child_count);
    try std.testing.expectEqual(request_child.logical_len + event_child.logical_len, view.header.logical_len);
    const decoded_request = try view.childAt(0);
    const decoded_event = try view.childAt(1);
    try std.testing.expect(bytes.eql(&request_child.object_id, &decoded_request.object_id));
    try std.testing.expect(bytes.eql(&event_child.object_id, &decoded_event.object_id));
    try std.testing.expectEqual(@as(?usize, 1), AgentSession.viewEventCount(view));
    const projected_event = AgentSession.eventChildAt(view, 0).?;
    try std.testing.expect(bytes.eql(&event_child.object_id, &projected_event.object_id));
    try std.testing.expect(AgentSession.eventChildAt(view, 1) == null);
}

test "agent session appends only canonical event objects" {
    const req = sessionTestRequirements();
    const epoch = clock.Stamp{ .keeper = .{ .bytes = [_]u8{7} ++ [_]u8{0} ** 31 } };
    const request_child = object.Child{
        .object_id = [_]u8{1} ++ [_]u8{0} ** 31,
        .logical_offset = 0,
        .logical_len = 12,
        .kind = .bytes,
        .requirements_hash = req.hash(),
    };
    var session = AgentSession.init(request_child).?;

    const event = AgentEvent{
        .sequence = 1,
        .stage_identity = default_agents[0].identity,
        .kind = .stage_result,
        .clock_stamp = epoch,
        .input_object = [_]u8{2} ++ [_]u8{0} ** 31,
        .output_object = [_]u8{3} ++ [_]u8{0} ** 31,
        .receipt = [_]u8{4} ++ [_]u8{0} ** 31,
    };
    var event_raw: [object.header_size + agent_event_body_size]u8 = undefined;
    const event_canonical = try event.writeObject(req, &event_raw);
    const event_view = try object.View.decode(event_canonical);
    try std.testing.expect(session.appendEventView(event_view));
    try std.testing.expectEqual(@as(usize, 1), session.eventCount());

    var not_event_raw: [object.header_size + 4]u8 = undefined;
    const not_event_canonical = try (object.NodeWriter{ .out = &not_event_raw }).bytesNode(req, epoch, &.{ 1, 2, 3, 4 });
    const not_event_view = try object.View.decode(not_event_canonical);
    try std.testing.expect(!session.appendEventView(not_event_view));
}

test "agent stage transition binds grants receipts and object kinds" {
    const stage_slot = default_agents[4];
    const transition = StageTransition.init(
        stage_slot,
        [_]u8{1} ++ [_]u8{0} ** 31,
        [_]u8{2} ++ [_]u8{0} ** 31,
        [_]u8{3} ++ [_]u8{0} ** 31,
        [_]u8{4} ++ [_]u8{0} ** 31,
        .completed,
    ).?;

    try std.testing.expect(transition.matchesStage(stage_slot));
    try std.testing.expect(!transition.matchesStage(default_agents[5]));

    var raw: [stage_transition_body_size]u8 = undefined;
    try std.testing.expect(transition.encodeBody(&raw));
    const decoded = StageTransition.decodeBody(&raw).?;
    try std.testing.expect(decoded.matchesStage(stage_slot));
    try std.testing.expect(bytes.eql(&transition.grant_or_receipt, &decoded.grant_or_receipt));
    try std.testing.expect(bytes.eql(&transition.completion_receipt, &decoded.completion_receipt));
    try std.testing.expectEqual(StageStatus.completed, decoded.status);

    const event = decoded.event(9, clock.Stamp{ .keeper = .{ .bytes = [_]u8{5} ++ [_]u8{0} ** 31 } });
    try std.testing.expectEqual(@as(u32, 9), event.sequence);
    try std.testing.expect(event.stage_identity.eql(stage_slot.identity));
    try std.testing.expectEqual(AgentEventKind.stage_result, event.kind);
    try std.testing.expect(bytes.eql(&transition.input_object, &event.input_object));
    try std.testing.expect(bytes.eql(&transition.output_object, &event.output_object));
    try std.testing.expect(bytes.eql(&transition.completion_receipt, &event.receipt));

    const envelope = decoded.envelope(55).?;
    try std.testing.expectEqual(AgentMessageType.stage_result, envelope.msg_type);
    try std.testing.expectEqual(@as(u32, 55), envelope.sender_slot);
    try std.testing.expect(bytes.eql(&transition.output_object, &envelope.request_object));
    try std.testing.expect(bytes.eql(&transition.input_object, &envelope.input_object));
    try std.testing.expect(bytes.eql(&transition.completion_receipt, &envelope.grant_or_receipt));

    const transition_from_envelope = StageTransition.fromEnvelope(stage_slot, envelope).?;
    try std.testing.expect(transition_from_envelope.matchesStage(stage_slot));
    try std.testing.expect(bytes.eql(&transition.input_object, &transition_from_envelope.input_object));
    try std.testing.expect(bytes.eql(&transition.output_object, &transition_from_envelope.output_object));
    try std.testing.expect(bytes.eql(&transition.completion_receipt, &transition_from_envelope.completion_receipt));
    try std.testing.expectEqual(StageStatus.completed, transition_from_envelope.status);
}

test "agent cell envelope matches kernel payload offsets" {
    var inline_args = [_]u8{0} ** agent_cell_inline_args_size;
    inline_args[0] = 0xaa;
    inline_args[1] = 0xbb;
    const envelope = AgentCellEnvelope{
        .msg_type = .tool_request,
        .flags = 3,
        .sender_slot = 77,
        .request_object = [_]u8{1} ++ [_]u8{0} ** 31,
        .input_object = [_]u8{2} ++ [_]u8{0} ** 31,
        .grant_or_receipt = [_]u8{3} ++ [_]u8{0} ** 31,
        .inline_args = inline_args,
        .inline_len = 2,
    };

    var payload: [agent_cell_payload_size]u8 = undefined;
    try std.testing.expect(envelope.encode(&payload));
    try std.testing.expectEqual(@as(u8, 6), payload[0]);
    try std.testing.expectEqual(@as(u8, 3), payload[1]);
    try std.testing.expectEqual(@as(?u32, 77), bytes.load32(payload[2..6]));
    try std.testing.expectEqual(@as(u8, 1), payload[6]);
    try std.testing.expectEqual(@as(u8, 2), payload[38]);
    try std.testing.expectEqual(@as(u8, 3), payload[70]);
    try std.testing.expectEqual(@as(u8, 0xaa), payload[102]);
    try std.testing.expectEqual(@as(u8, 0xbb), payload[103]);

    const decoded = AgentCellEnvelope.decode(&payload).?;
    try std.testing.expectEqual(AgentMessageType.tool_request, decoded.msg_type);
    try std.testing.expectEqual(@as(u32, 77), decoded.sender_slot);
    try std.testing.expect(bytes.eql(&envelope.request_object, &decoded.request_object));
    try std.testing.expect(bytes.eql(&envelope.input_object, &decoded.input_object));
    try std.testing.expect(bytes.eql(&envelope.grant_or_receipt, &decoded.grant_or_receipt));
}

test "agent tools are object addressed services" {
    try std.testing.expectEqual(@as(usize, max_tools), default_tools.len);
    const service = toolServiceFor(.apply_patch).?;
    try std.testing.expect(service.identity.valid());
    try std.testing.expectEqual(AgentObjectKind.tool_request, service.input_kind);
    try std.testing.expectEqual(AgentObjectKind.tool_result, service.output_kind);

    const request = ToolRequest.init(
        service,
        [_]u8{1} ++ [_]u8{0} ** 31,
        [_]u8{2} ++ [_]u8{0} ** 31,
        [_]u8{3} ++ [_]u8{0} ** 31,
    ).?;
    var request_raw: [tool_request_body_size]u8 = undefined;
    try std.testing.expect(request.encodeBody(&request_raw));
    const decoded_request = ToolRequest.decodeBody(&request_raw).?;
    try std.testing.expect(decoded_request.service_identity.eql(service.identity));
    try std.testing.expect(bytes.eql(&request.input_object, &decoded_request.input_object));
    try std.testing.expect(bytes.eql(&request.grant_or_receipt, &decoded_request.grant_or_receipt));
    try std.testing.expectEqual(AgentObjectKind.tool_result, decoded_request.output_kind);
    const envelope = decoded_request.envelope(44).?;
    try std.testing.expectEqual(AgentMessageType.tool_request, envelope.msg_type);
    try std.testing.expectEqual(@as(u32, 44), envelope.sender_slot);
    try std.testing.expect(bytes.eql(&request.request_object, &envelope.request_object));
    try std.testing.expect(bytes.eql(&request.input_object, &envelope.input_object));
    try std.testing.expect(bytes.eql(&request.grant_or_receipt, &envelope.grant_or_receipt));

    const request_from_envelope = ToolRequest.fromEnvelope(service, envelope).?;
    try std.testing.expect(request_from_envelope.service_identity.eql(service.identity));
    try std.testing.expect(bytes.eql(&request.request_object, &request_from_envelope.request_object));
    try std.testing.expect(bytes.eql(&request.input_object, &request_from_envelope.input_object));
    try std.testing.expect(bytes.eql(&request.grant_or_receipt, &request_from_envelope.grant_or_receipt));
}

test "agent tool result binds output object and receipt" {
    const service = toolServiceFor(.@"test").?;
    const result = ToolResult{
        .service_identity = service.identity,
        .request_object = [_]u8{1} ++ [_]u8{0} ** 31,
        .output_object = [_]u8{2} ++ [_]u8{0} ** 31,
        .receipt = [_]u8{3} ++ [_]u8{0} ** 31,
        .status = .ok,
    };

    var raw: [tool_result_body_size]u8 = undefined;
    try std.testing.expect(result.encodeBody(&raw));
    const decoded = ToolResult.decodeBody(&raw).?;
    try std.testing.expect(decoded.service_identity.eql(service.identity));
    try std.testing.expect(bytes.eql(&result.output_object, &decoded.output_object));
    try std.testing.expect(bytes.eql(&result.receipt, &decoded.receipt));
    try std.testing.expectEqual(ToolStatus.ok, decoded.status);

    const event = decoded.event(12, clock.Stamp{ .keeper = .{ .bytes = [_]u8{8} ++ [_]u8{0} ** 31 } });
    try std.testing.expectEqual(@as(u32, 12), event.sequence);
    try std.testing.expect(event.stage_identity.eql(service.identity));
    try std.testing.expectEqual(AgentEventKind.tool_result, event.kind);
    try std.testing.expect(bytes.eql(&result.request_object, &event.input_object));
    try std.testing.expect(bytes.eql(&result.output_object, &event.output_object));
    try std.testing.expect(bytes.eql(&result.receipt, &event.receipt));

    const envelope = decoded.envelope(66).?;
    try std.testing.expectEqual(AgentMessageType.tool_result, envelope.msg_type);
    try std.testing.expectEqual(@as(u32, 66), envelope.sender_slot);
    try std.testing.expect(bytes.eql(&result.request_object, &envelope.request_object));
    try std.testing.expect(bytes.eql(&result.output_object, &envelope.input_object));
    try std.testing.expect(bytes.eql(&result.receipt, &envelope.grant_or_receipt));

    const result_from_envelope = ToolResult.fromEnvelope(service, envelope).?;
    try std.testing.expect(result_from_envelope.service_identity.eql(service.identity));
    try std.testing.expect(bytes.eql(&result.request_object, &result_from_envelope.request_object));
    try std.testing.expect(bytes.eql(&result.output_object, &result_from_envelope.output_object));
    try std.testing.expect(bytes.eql(&result.receipt, &result_from_envelope.receipt));
    try std.testing.expectEqual(ToolStatus.ok, result_from_envelope.status);
}

test "agent patch review and summary objects bind receipts" {
    const patch = PatchObject{
        .plan_object = [_]u8{1} ++ [_]u8{0} ** 31,
        .patch_object = [_]u8{2} ++ [_]u8{0} ** 31,
        .tool_result = [_]u8{3} ++ [_]u8{0} ** 31,
        .receipt = [_]u8{4} ++ [_]u8{0} ** 31,
        .status = .completed,
    };
    var patch_raw: [patch_body_size]u8 = undefined;
    try std.testing.expect(patch.encodeBody(&patch_raw));
    const decoded_patch = PatchObject.decodeBody(&patch_raw).?;
    try std.testing.expect(bytes.eql(&patch.patch_object, &decoded_patch.patch_object));
    try std.testing.expect(bytes.eql(&patch.receipt, &decoded_patch.receipt));
    try std.testing.expectEqual(StageStatus.completed, decoded_patch.status);
    const patch_event = decoded_patch.event(20, clock.Stamp{ .keeper = .{ .bytes = [_]u8{9} ++ [_]u8{0} ** 31 } }, default_agents[4].identity);
    try std.testing.expectEqual(AgentEventKind.artifact, patch_event.kind);
    try std.testing.expect(bytes.eql(&patch.plan_object, &patch_event.input_object));
    try std.testing.expect(bytes.eql(&patch.patch_object, &patch_event.output_object));
    try std.testing.expect(bytes.eql(&patch.receipt, &patch_event.receipt));

    const review = ReviewObject{
        .patch_object = decoded_patch.patch_object,
        .review_object = [_]u8{5} ++ [_]u8{0} ** 31,
        .receipt = [_]u8{6} ++ [_]u8{0} ** 31,
        .decision = .accepted,
    };
    var review_raw: [review_body_size]u8 = undefined;
    try std.testing.expect(review.encodeBody(&review_raw));
    const decoded_review = ReviewObject.decodeBody(&review_raw).?;
    try std.testing.expect(bytes.eql(&review.patch_object, &decoded_review.patch_object));
    try std.testing.expect(bytes.eql(&review.receipt, &decoded_review.receipt));
    try std.testing.expectEqual(ReviewDecision.accepted, decoded_review.decision);
    const review_event = decoded_review.event(21, clock.Stamp{ .keeper = .{ .bytes = [_]u8{9} ++ [_]u8{0} ** 31 } }, default_agents[5].identity);
    try std.testing.expectEqual(AgentEventKind.stage_result, review_event.kind);
    try std.testing.expect(bytes.eql(&review.patch_object, &review_event.input_object));
    try std.testing.expect(bytes.eql(&review.review_object, &review_event.output_object));
    try std.testing.expect(bytes.eql(&review.receipt, &review_event.receipt));

    const summary = SummaryObject{
        .review_object = decoded_review.review_object,
        .summary_object = [_]u8{7} ++ [_]u8{0} ** 31,
        .receipt = [_]u8{8} ++ [_]u8{0} ** 31,
        .retained = true,
    };
    var summary_raw: [summary_body_size]u8 = undefined;
    try std.testing.expect(summary.encodeBody(&summary_raw));
    const decoded_summary = SummaryObject.decodeBody(&summary_raw).?;
    try std.testing.expect(bytes.eql(&summary.summary_object, &decoded_summary.summary_object));
    try std.testing.expect(bytes.eql(&summary.receipt, &decoded_summary.receipt));
    try std.testing.expect(decoded_summary.retained);
    const summary_event = decoded_summary.event(22, clock.Stamp{ .keeper = .{ .bytes = [_]u8{9} ++ [_]u8{0} ** 31 } }, default_agents[6].identity);
    try std.testing.expectEqual(AgentEventKind.stage_result, summary_event.kind);
    try std.testing.expect(bytes.eql(&summary.review_object, &summary_event.input_object));
    try std.testing.expect(bytes.eql(&summary.summary_object, &summary_event.output_object));
    try std.testing.expect(bytes.eql(&summary.receipt, &summary_event.receipt));
}

test "agent stream reports complete patch lengths" {
    try std.testing.expectEqual(@as(?usize, 9), messageLen(&.{ 1, 13, status_component_id, 5, 'r', 'e', 'a', 'd', 'y' }));
    try std.testing.expectEqual(@as(?usize, null), messageLen(&.{ 1, 13, status_component_id, 5, 'r', 'e' }));
    try std.testing.expectEqual(@as(?usize, 16), messageLen(&.{ 1, 8, assistant_component_id, 9, 'a', 's', 's', 'i', 's', 't', 'a', 'n', 't', 2, 'o', 'k' }));
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
