const std = @import("std");
const bounded = @import("bounded.zig");
const geometry = @import("geometry.zig");

pub const Color = packed struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,

    pub const clear = Color{ .r = 0, .g = 0, .b = 0, .a = 0 };
    pub const bg = Color{ .r = 10, .g = 14, .b = 20 };
    pub const panel = Color{ .r = 24, .g = 31, .b = 42 };
    pub const row = Color{ .r = 35, .g = 44, .b = 58 };
    pub const border = Color{ .r = 80, .g = 96, .b = 118 };
    pub const text = Color{ .r = 232, .g = 238, .b = 247 };
    pub const muted = Color{ .r = 148, .g = 163, .b = 184 };
    pub const accent = Color{ .r = 34, .g = 211, .b = 238 };
};

pub const Rect = geometry.Rect;

pub const Size = struct {
    w: f32,
    h: f32,
};

pub const Axis = enum {
    row,
    column,
};

pub const Align = enum {
    start,
    center,
    end,
    stretch,
};

pub const Style = struct {
    bg: Color = .bg,
    panel: Color = .panel,
    row: Color = .row,
    border: Color = .border,
    text: Color = .text,
    muted: Color = .muted,
    accent: Color = .accent,
};

pub const HitKind = enum(u8) {
    button,
    input,
    row_item,
};

pub const RectMode = enum(u8) {
    fill,
    shadow,
    border,
    linear_gradient,
};

pub const Hit = struct {
    slot: u32,
    kind: HitKind,
    id: u32,
    bounds: Rect,
};

pub const DragSource = struct {
    scope_id: u32,
    item_id: u32,
    index: usize,
    bounds: Rect,
};

pub const DropTarget = struct {
    scope_id: u32,
    index: usize,
    bounds: Rect,
};

pub const Quad = struct {
    bounds: Rect,
    u0: f32 = 0.0,
    v0: f32 = 0.0,
    u1: f32 = 1.0,
    v1: f32 = 1.0,
    atlas_id: u32 = 0,
    color: Color,
};

pub const TransitionProperty = enum(u8) {
    opacity,
    translate_x,
    translate_y,
};

pub const Easing = enum(u8) {
    linear,
    ease_in,
    ease_out,
    ease_in_out,
};

pub const Transition = struct {
    id: u32,
    property: TransitionProperty,
    from: f32,
    to: f32,
    duration_ms: u32,
    delay_ms: u32 = 0,
    easing: Easing = .linear,

    pub fn valid(self: Transition) bool {
        return geometry.finite(self.from) and geometry.finite(self.to) and self.duration_ms > 0 and self.duration_ms <= 60000;
    }
};

pub fn transition(id: u32, property: TransitionProperty, from: f32, to: f32, duration_ms: u32, delay_ms: u32, easing: Easing) Transition {
    return .{ .id = id, .property = property, .from = from, .to = to, .duration_ms = duration_ms, .delay_ms = delay_ms, .easing = easing };
}

pub fn transitionOpacity(id: u32, from: f32, to: f32, duration_ms: u32) Transition {
    return transition(id, .opacity, from, to, duration_ms, 0, .ease_out);
}

pub fn transitionTranslateX(id: u32, from: f32, to: f32, duration_ms: u32) Transition {
    return transition(id, .translate_x, from, to, duration_ms, 0, .ease_out);
}

pub fn transitionTranslateY(id: u32, from: f32, to: f32, duration_ms: u32) Transition {
    return transition(id, .translate_y, from, to, duration_ms, 0, .ease_out);
}

pub fn easingSample(easing: Easing, value: f32) f32 {
    const clamped = geometry.clamp(value, 0.0, 1.0);
    return switch (easing) {
        .linear => clamped,
        .ease_in => clamped * clamped,
        .ease_out => 1.0 - (1.0 - clamped) * (1.0 - clamped),
        .ease_in_out => if (clamped < 0.5) 2.0 * clamped * clamped else 1.0 - (-2.0 * clamped + 2.0) * (-2.0 * clamped + 2.0) * 0.5,
    };
}

pub const Command = union(enum) {
    rect: struct { bounds: Rect, color: Color, color2: Color = .clear, mode: RectMode = .fill, radius: f32 = 0.0, shadow: f32 = 0.0 },
    border: struct { bounds: Rect, color: Color },
    text: struct { origin: Rect, value: []const u8, color: Color },
    hit: Hit,
    drag_source: DragSource,
    drop_target: DropTarget,
    icon_quad: Quad,
    text_quad: Quad,
    transition: Transition,
};

pub const Cursor = struct {
    commands: usize = 0,
};

pub const Stats = struct {
    rects: usize = 0,
    hits: usize = 0,
    drag_sources: usize = 0,
    drop_targets: usize = 0,
    transitions: usize = 0,
    clips: usize = 0,
    icon_quads: usize = 0,
    text_quads: usize = 0,
};

pub const Budget = struct {
    rects: usize = 2000,
    hits: usize = 240,
    drag_sources: usize = 240,
    drop_targets: usize = 240,
    transitions: usize = 1200,
    icon_quads: usize = 160,
    text_quads: usize = 900,
};

pub const BudgetViolation = struct {
    name: []const u8,
    actual: usize,
    limit: usize,
};

pub const RenderError = error{
    CommandBudgetExceeded,
    InvalidBounds,
    ClipBudgetExceeded,
};

pub const PatchError = error{
    WrongNodeKind,
};

pub const CommandList = bounded.SliceList(Command);
pub const ClipList = bounded.SliceList(Rect);

pub const Scene = struct {
    commands: CommandList,
    clips: ClipList,

    pub fn init(commands: []Command) Scene {
        return .{ .commands = CommandList.from(commands), .clips = ClipList.from(&.{}) };
    }

    pub fn initWithClips(commands: []Command, clips: []Rect) Scene {
        return .{ .commands = CommandList.from(commands), .clips = ClipList.from(clips) };
    }

    pub fn clear(self: *Scene) void {
        self.commands.clear();
        self.clips.clear();
    }

    pub fn push(self: *Scene, command: Command) RenderError!void {
        if (!self.commands.append(command)) return error.CommandBudgetExceeded;
    }

    pub fn pushRect(self: *Scene, bounds: Rect, color: Color, mode: RectMode, radius: f32, shadow: f32) RenderError!void {
        try self.pushRectPair(bounds, color, .clear, mode, radius, shadow);
    }

    pub fn pushGradientRect(self: *Scene, bounds: Rect, top_color: Color, bottom_color: Color, radius: f32) RenderError!void {
        try self.pushRectPair(bounds, top_color, bottom_color, .linear_gradient, radius, 0.0);
    }

    fn pushRectPair(self: *Scene, bounds: Rect, color: Color, color2: Color, mode: RectMode, radius: f32, shadow: f32) RenderError!void {
        var normalized_bounds = bounds;
        var normalized_radius = radius;
        var normalized_shadow = shadow;
        if (!normalizeRect(&normalized_bounds, &normalized_radius, &normalized_shadow)) return;
        if (self.clipRect(normalized_bounds)) |clipped| {
            normalized_bounds = clipped;
            normalized_radius = @min(normalized_radius, @min(clipped.w * 0.5, clipped.h * 0.5));
        } else return;
        try self.push(.{ .rect = .{ .bounds = normalized_bounds, .color = color, .color2 = color2, .mode = mode, .radius = normalized_radius, .shadow = normalized_shadow } });
    }

    pub fn pushHit(self: *Scene, hit: Hit) RenderError!void {
        if (self.clipRect(hit.bounds)) |clipped| {
            try self.push(.{ .hit = .{ .slot = hit.slot, .kind = hit.kind, .id = hit.id, .bounds = clipped } });
        }
    }

    pub fn pushDragSource(self: *Scene, source: DragSource) RenderError!void {
        if (self.clipRect(source.bounds)) |clipped| {
            try self.push(.{ .drag_source = .{ .scope_id = source.scope_id, .item_id = source.item_id, .index = source.index, .bounds = clipped } });
        }
    }

    pub fn pushDropTarget(self: *Scene, target: DropTarget) RenderError!void {
        if (self.clipRect(target.bounds)) |clipped| {
            try self.push(.{ .drop_target = .{ .scope_id = target.scope_id, .index = target.index, .bounds = clipped } });
        }
    }

    pub fn pushTransition(self: *Scene, value: Transition) RenderError!void {
        if (!value.valid()) return;
        try self.push(.{ .transition = value });
    }

    pub fn pushIconQuad(self: *Scene, quad: Quad) RenderError!void {
        if (self.clipQuad(quad)) |clipped| try self.push(.{ .icon_quad = clipped });
    }

    pub fn pushTextQuad(self: *Scene, quad: Quad) RenderError!void {
        if (self.clipQuad(quad)) |clipped| try self.push(.{ .text_quad = clipped });
    }

    pub fn pushClip(self: *Scene, clip: Rect) RenderError!bool {
        if (!clip.valid()) return false;
        const next = if (self.currentClip()) |current| current.intersect(clip) orelse return false else clip;
        if (!self.clips.append(next)) return error.ClipBudgetExceeded;
        return true;
    }

    pub fn popClip(self: *Scene) void {
        _ = self.clips.pop();
    }

    pub fn cursor(self: Scene) Cursor {
        return .{ .commands = self.commands.len };
    }

    pub fn stats(self: Scene) Stats {
        var out = Stats{ .clips = self.clips.len };
        for (self.written()) |command| switch (command) {
            .rect, .border => out.rects += 1,
            .hit => out.hits += 1,
            .drag_source => out.drag_sources += 1,
            .drop_target => out.drop_targets += 1,
            .transition => out.transitions += 1,
            .icon_quad => out.icon_quads += 1,
            .text_quad, .text => out.text_quads += 1,
        };
        return out;
    }

    pub fn applyOpacitySince(self: *Scene, mark: Cursor, opacity: f32) void {
        const alpha = geometry.clamp(opacity, 0.0, 1.0);
        for (self.commands.mutableSlice()[mark.commands..]) |*command| switch (command.*) {
            .rect => |*rect_cmd| rect_cmd.color.a = scaleAlpha(rect_cmd.color.a, alpha),
            .border => |*border| border.color.a = scaleAlpha(border.color.a, alpha),
            .text => |*text_cmd| text_cmd.color.a = scaleAlpha(text_cmd.color.a, alpha),
            .icon_quad => |*quad| quad.color.a = scaleAlpha(quad.color.a, alpha),
            .text_quad => |*quad| quad.color.a = scaleAlpha(quad.color.a, alpha),
            else => {},
        };
    }

    pub fn translateSince(self: *Scene, mark: Cursor, dx: f32, dy: f32) void {
        if (!geometry.finite(dx) or !geometry.finite(dy)) return;
        for (self.commands.mutableSlice()[mark.commands..]) |*command| switch (command.*) {
            .rect => |*rect_cmd| translateRect(&rect_cmd.bounds, dx, dy),
            .border => |*border| translateRect(&border.bounds, dx, dy),
            .text => |*text_cmd| translateRect(&text_cmd.origin, dx, dy),
            .hit => |*hit| translateRect(&hit.bounds, dx, dy),
            .drag_source => |*source| translateRect(&source.bounds, dx, dy),
            .drop_target => |*target| translateRect(&target.bounds, dx, dy),
            .icon_quad => |*quad| translateRect(&quad.bounds, dx, dy),
            .text_quad => |*quad| translateRect(&quad.bounds, dx, dy),
            else => {},
        };
    }

    fn currentClip(self: Scene) ?Rect {
        if (self.clips.len == 0) return null;
        return self.clips.items[self.clips.len - 1];
    }

    fn clipRect(self: Scene, bounds: Rect) ?Rect {
        if (!bounds.valid()) return null;
        return if (self.currentClip()) |clip| bounds.intersect(clip) else bounds;
    }

    fn clipQuad(self: Scene, quad: Quad) ?Quad {
        const clipped_bounds = self.clipRect(quad.bounds) orelse return null;
        const x0 = quad.bounds.x;
        const y0 = quad.bounds.y;
        const x1 = quad.bounds.x + quad.bounds.w;
        const y1 = quad.bounds.y + quad.bounds.h;
        const u_span = quad.u1 - quad.u0;
        const v_span = quad.v1 - quad.v0;
        const left = geometry.clamp((clipped_bounds.x - x0) / (x1 - x0), 0.0, 1.0);
        const top = geometry.clamp((clipped_bounds.y - y0) / (y1 - y0), 0.0, 1.0);
        const right = geometry.clamp((clipped_bounds.x + clipped_bounds.w - x0) / (x1 - x0), 0.0, 1.0);
        const bottom = geometry.clamp((clipped_bounds.y + clipped_bounds.h - y0) / (y1 - y0), 0.0, 1.0);
        return .{
            .bounds = clipped_bounds,
            .u0 = quad.u0 + u_span * left,
            .v0 = quad.v0 + v_span * top,
            .u1 = quad.u0 + u_span * right,
            .v1 = quad.v0 + v_span * bottom,
            .atlas_id = quad.atlas_id,
            .color = quad.color,
        };
    }

    pub fn written(self: Scene) []const Command {
        return self.commands.slice();
    }

    pub fn commandCount(self: Scene) usize {
        return self.commands.len;
    }

    pub fn commandAt(self: Scene, index: usize) ?Command {
        return self.commands.at(index);
    }
};

pub fn frameBudget() Budget {
    return .{};
}

pub fn firstBudgetViolation(stats_value: Stats, budget: Budget) ?BudgetViolation {
    const entries = [_]BudgetViolation{
        .{ .name = "rects", .actual = stats_value.rects, .limit = budget.rects },
        .{ .name = "hits", .actual = stats_value.hits, .limit = budget.hits },
        .{ .name = "drag_sources", .actual = stats_value.drag_sources, .limit = budget.drag_sources },
        .{ .name = "drop_targets", .actual = stats_value.drop_targets, .limit = budget.drop_targets },
        .{ .name = "transitions", .actual = stats_value.transitions, .limit = budget.transitions },
        .{ .name = "icon_quads", .actual = stats_value.icon_quads, .limit = budget.icon_quads },
        .{ .name = "text_quads", .actual = stats_value.text_quads, .limit = budget.text_quads },
    };
    for (entries) |entry| {
        if (entry.actual > entry.limit) return entry;
    }
    return null;
}

pub fn statsFitBudget(stats_value: Stats, budget: Budget) bool {
    return firstBudgetViolation(stats_value, budget) == null;
}

fn normalizeRect(bounds: *Rect, radius: *f32, shadow: *f32) bool {
    if (!bounds.valid() or !geometry.finite(radius.*) or !geometry.finite(shadow.*)) return false;
    radius.* = geometry.clamp(radius.*, 0.0, @min(bounds.w * 0.5, bounds.h * 0.5));
    shadow.* = geometry.max(shadow.*, 0.0);
    return true;
}

fn translateRect(bounds: *Rect, dx: f32, dy: f32) void {
    bounds.x += dx;
    bounds.y += dy;
}

fn scaleAlpha(alpha: u8, factor: f32) u8 {
    return @intFromFloat(@round(@as(f32, @floatFromInt(alpha)) * factor));
}

pub const Layout = struct {
    axis: Axis,
    gap: f32 = 8,
    padding: f32 = 0,
    cross_align: Align = .stretch,
    children: []const Node,
};

pub const Slot = struct {
    id: u32,
    child: *const Node,
};

pub const Node = union(enum) {
    rect: struct { color: Color },
    text: struct { value: []const u8, color: ?Color = null },
    button: struct { id: u32, label: []const u8 },
    input: struct { id: u32, placeholder: []const u8 },
    row_item: struct { id: u32, title: []const u8, detail: []const u8 },
    slot: Slot,
    stack: Layout,

    pub fn preferredSize(self: Node) Size {
        return switch (self) {
            .rect => .{ .w = 32, .h = 32 },
            .text => .{ .w = 96, .h = 22 },
            .button => .{ .w = 112, .h = 36 },
            .input => .{ .w = 220, .h = 40 },
            .row_item => .{ .w = 260, .h = 48 },
            .slot => |slot_node| slot_node.child.preferredSize(),
            .stack => |layout| stackPreferredSize(layout),
        };
    }
};

pub fn rectNode(color: Color) Node {
    return .{ .rect = .{ .color = color } };
}

pub fn textNode(value: []const u8, color: ?Color) Node {
    return .{ .text = .{ .value = value, .color = color } };
}

pub fn buttonNode(id: u32, label: []const u8) Node {
    return .{ .button = .{ .id = id, .label = label } };
}

pub fn inputNode(id: u32, placeholder: []const u8) Node {
    return .{ .input = .{ .id = id, .placeholder = placeholder } };
}

pub fn rowItemNode(id: u32, title: []const u8, detail: []const u8) Node {
    return .{ .row_item = .{ .id = id, .title = title, .detail = detail } };
}

pub fn slotNode(id: u32, child: *const Node) Node {
    return .{ .slot = .{ .id = id, .child = child } };
}

pub fn stackNode(axis: Axis, gap: f32, padding: f32, cross_align: Align, children: []const Node) Node {
    return .{ .stack = .{ .axis = axis, .gap = gap, .padding = padding, .cross_align = cross_align, .children = children } };
}

pub fn columnStack(gap: f32, padding: f32, children: []const Node) Node {
    return stackNode(.column, gap, padding, .stretch, children);
}

pub fn rowStack(gap: f32, padding: f32, children: []const Node) Node {
    return stackNode(.row, gap, padding, .stretch, children);
}

pub fn alignedColumn(gap: f32, padding: f32, cross_align: Align, children: []const Node) Node {
    return stackNode(.column, gap, padding, cross_align, children);
}

pub fn alignedRow(gap: f32, padding: f32, cross_align: Align, children: []const Node) Node {
    return stackNode(.row, gap, padding, cross_align, children);
}

pub const Patch = union(enum) {
    text_value: []const u8,
    button_label: []const u8,
    input_placeholder: []const u8,
    row_item: struct { title: []const u8, detail: []const u8 },
    rect_color: Color,
    style_color: Color,
};

pub fn applyPatch(node: *Node, patch: Patch) PatchError!void {
    switch (patch) {
        .text_value => |value| switch (node.*) {
            .text => |*text_node| text_node.value = value,
            else => return error.WrongNodeKind,
        },
        .button_label => |label| switch (node.*) {
            .button => |*button| button.label = label,
            else => return error.WrongNodeKind,
        },
        .input_placeholder => |placeholder| switch (node.*) {
            .input => |*input| input.placeholder = placeholder,
            else => return error.WrongNodeKind,
        },
        .row_item => |row_patch| switch (node.*) {
            .row_item => |*row| {
                row.title = row_patch.title;
                row.detail = row_patch.detail;
            },
            else => return error.WrongNodeKind,
        },
        .rect_color => |color| switch (node.*) {
            .rect => |*rect_node| rect_node.color = color,
            else => return error.WrongNodeKind,
        },
        .style_color => |color| switch (node.*) {
            .text => |*text_node| text_node.color = color,
            else => return error.WrongNodeKind,
        },
    }
}

pub fn render(scene: *Scene, node: Node, bounds: Rect, style: Style) RenderError!void {
    try renderInSlot(scene, node, bounds, style, 0);
}

fn renderInSlot(scene: *Scene, node: Node, bounds: Rect, style: Style, slot_id: u32) RenderError!void {
    if (!bounds.valid()) return error.InvalidBounds;
    switch (node) {
        .rect => |rect_node| try scene.push(.{ .rect = .{ .bounds = bounds, .color = rect_node.color } }),
        .text => |text_node| try scene.push(.{ .text = .{ .origin = bounds, .value = text_node.value, .color = text_node.color orelse style.text } }),
        .button => |button| {
            try scene.pushRect(bounds, surface_shadow, .shadow, control_radius, control_shadow);
            try scene.pushGradientRect(bounds, style.accent, accent_bottom, control_radius);
            try scene.pushRect(bounds, style.border, .border, control_radius, 0.0);
            if (contentInset(bounds, button_text_padding)) |label_bounds| {
                try scene.push(.{ .text = .{ .origin = label_bounds, .value = button.label, .color = style.bg } });
            }
            try scene.push(.{ .hit = .{ .slot = slot_id, .kind = .button, .id = button.id, .bounds = bounds } });
        },
        .input => |input| {
            try scene.pushRect(bounds, style.panel, .fill, control_radius, 0.0);
            try scene.pushRect(bounds, style.border, .border, control_radius, 0.0);
            if (contentInset(bounds, input_text_padding)) |placeholder_bounds| {
                try scene.push(.{ .text = .{ .origin = placeholder_bounds, .value = input.placeholder, .color = style.muted } });
            }
            try scene.push(.{ .hit = .{ .slot = slot_id, .kind = .input, .id = input.id, .bounds = bounds } });
        },
        .row_item => |row| {
            try scene.pushRect(bounds, style.row, .fill, row_radius, 0.0);
            if (rowTitleBounds(bounds, row.detail.len == 0)) |title_bounds| {
                try scene.push(.{ .text = .{ .origin = title_bounds, .value = row.title, .color = style.text } });
            }
            if (row.detail.len != 0) {
                if (rowDetailBounds(bounds)) |detail_bounds| {
                    try scene.push(.{ .text = .{ .origin = detail_bounds, .value = row.detail, .color = style.muted } });
                }
            }
            try scene.push(.{ .hit = .{ .slot = slot_id, .kind = .row_item, .id = row.id, .bounds = bounds } });
        },
        .slot => |slot_node| try renderInSlot(scene, slot_node.child.*, bounds, style, slot_node.id),
        .stack => |layout| try renderStack(scene, layout, bounds, style, slot_id),
    }
}

const control_radius: f32 = 6.0;
const control_shadow: f32 = 5.0;
const row_radius: f32 = 4.0;
const surface_shadow = Color{ .r = 0, .g = 0, .b = 0, .a = 96 };
const accent_bottom = Color{ .r = 15, .g = 183, .b = 210 };
const button_text_padding: f32 = 10.0;
const input_text_padding: f32 = 12.0;
const row_text_padding_x: f32 = 12.0;
const row_title_offset_y: f32 = 8.0;
const row_detail_offset_y: f32 = 26.0;
const row_title_height: f32 = 18.0;
const row_detail_height: f32 = 16.0;

fn contentInset(bounds: Rect, padding: f32) ?Rect {
    const clamped = geometry.clamp(padding, 0.0, @min(bounds.w, bounds.h) * 0.5);
    const out = bounds.insetUniform(clamped);
    return if (out.valid()) out else null;
}

fn rowTitleBounds(bounds: Rect, centered: bool) ?Rect {
    const row_bounds = if (centered) bounds.withHeightCentered(row_title_height) else Rect.init(bounds.x, bounds.y + row_title_offset_y, bounds.w, row_title_height);
    return rowTextBounds(row_bounds);
}

fn rowDetailBounds(bounds: Rect) ?Rect {
    return rowTextBounds(Rect.init(bounds.x, bounds.y + row_detail_offset_y, bounds.w, row_detail_height));
}

fn rowTextBounds(bounds: Rect) ?Rect {
    const out = bounds.insetLtrb(row_text_padding_x, 0.0, row_text_padding_x, 0.0);
    return if (out.valid()) out else null;
}

fn renderStack(scene: *Scene, layout: Layout, bounds: Rect, style: Style, slot_id: u32) RenderError!void {
    if (layout.children.len == 0) return;
    const inner = insetResponsive(bounds, layout.padding);
    if (!inner.valid()) return;
    const available_main = mainSize(layout.axis, inner);
    const total_preferred_main = stackPreferredMain(layout);
    const requested_gap = responsiveGap(layout.gap, layout.children.len, available_main);
    const gap_slots = if (layout.children.len > 1) layout.children.len - 1 else 0;
    const total_requested_gap = requested_gap * @as(f32, @floatFromInt(gap_slots));
    const overflow = total_preferred_main + total_requested_gap > available_main;
    const gap: f32 = if (overflow) 0.0 else requested_gap;
    const child_scale: f32 = if (overflow and total_preferred_main > 0.0) available_main / total_preferred_main else 1.0;
    var cursor: f32 = switch (layout.axis) {
        .row => inner.x,
        .column => inner.y,
    };
    var used: f32 = 0.0;

    for (layout.children, 0..) |child, index| {
        const preferred = child.preferredSize();
        const remaining_children = layout.children.len - index - 1;
        const remaining_gap = gap * @as(f32, @floatFromInt(remaining_children));
        const remaining_main = @max(0.0, mainSize(layout.axis, inner) - used - remaining_gap);
        const preferred_main = preferredMain(layout.axis, preferred);
        const child_main = @min(preferred_main * child_scale, remaining_main);
        if (child_main <= 0.0) break;
        const child_bounds = childBounds(layout.axis, inner, cursor, child_main, preferredCross(layout.axis, preferred), layout.cross_align);
        try renderInSlot(scene, child, child_bounds, style, slot_id);
        cursor += child_main + gap;
        used += child_main + if (remaining_children > 0) gap else 0.0;
    }
}

fn insetResponsive(bounds: Rect, requested_padding: f32) Rect {
    const max_padding = geometry.max(0.0, (@min(bounds.w, bounds.h) - min_layout_extent) * 0.5);
    const padding = geometry.clamp(requested_padding, 0.0, max_padding);
    return bounds.insetUniform(padding);
}

fn responsiveGap(requested_gap: f32, child_count: usize, available_main: f32) f32 {
    if (child_count < 2) return 0.0;
    const gap = geometry.max(requested_gap, 0.0);
    const slots = @as(f32, @floatFromInt(child_count - 1));
    return @min(gap, available_main / slots);
}

fn stackPreferredMain(layout: Layout) f32 {
    var total: f32 = 0.0;
    for (layout.children) |child| total += preferredMain(layout.axis, child.preferredSize());
    return total;
}

fn mainSize(axis: Axis, bounds: Rect) f32 {
    return switch (axis) {
        .row => bounds.w,
        .column => bounds.h,
    };
}

fn preferredMain(axis: Axis, size: Size) f32 {
    return switch (axis) {
        .row => size.w,
        .column => size.h,
    };
}

fn preferredCross(axis: Axis, size: Size) f32 {
    return switch (axis) {
        .row => size.h,
        .column => size.w,
    };
}

fn childBounds(axis: Axis, inner: Rect, cursor: f32, child_main: f32, preferred_cross: f32, cross_align: Align) Rect {
    return switch (axis) {
        .row => .{
            .x = cursor,
            .y = alignedCrossStart(inner.y, inner.h, preferred_cross, cross_align),
            .w = child_main,
            .h = alignedCrossSize(inner.h, preferred_cross, cross_align),
        },
        .column => .{
            .x = alignedCrossStart(inner.x, inner.w, preferred_cross, cross_align),
            .y = cursor,
            .w = alignedCrossSize(inner.w, preferred_cross, cross_align),
            .h = child_main,
        },
    };
}

const min_layout_extent: f32 = 1.0;

fn alignedCrossSize(available: f32, preferred: f32, cross_align: Align) f32 {
    return switch (cross_align) {
        .stretch => available,
        .start, .center, .end => @min(available, preferred),
    };
}

fn alignedCrossStart(origin: f32, available: f32, preferred: f32, cross_align: Align) f32 {
    const size = alignedCrossSize(available, preferred, cross_align);
    return switch (cross_align) {
        .start, .stretch => origin,
        .center => origin + (available - size) * 0.5,
        .end => origin + available - size,
    };
}

fn stackPreferredSize(layout: Layout) Size {
    var main: f32 = 0;
    var cross: f32 = 0;
    for (layout.children, 0..) |child, index| {
        const size = child.preferredSize();
        if (index != 0) main += layout.gap;
        switch (layout.axis) {
            .row => {
                main += size.w;
                cross = @max(cross, size.h);
            },
            .column => {
                main += size.h;
                cross = @max(cross, size.w);
            },
        }
    }
    return switch (layout.axis) {
        .row => .{ .w = main + layout.padding * 2, .h = cross + layout.padding * 2 },
        .column => .{ .w = cross + layout.padding * 2, .h = main + layout.padding * 2 },
    };
}

fn sampleRoot(children: []Node) Node {
    std.debug.assert(children.len >= 5);
    children[0] = .{ .text = .{ .value = "edgerun ui", .color = .accent } };
    children[1] = .{ .input = .{ .id = 10, .placeholder = "search objects" } };
    children[2] = .{ .row_item = .{ .id = 20, .title = "object graph", .detail = "canonical data in, scene commands out" } };
    children[3] = .{ .slot = .{ .id = 7, .child = &children[4] } };
    children[4] = .{ .button = .{ .id = 30, .label = "Render" } };
    return .{ .stack = .{ .axis = .column, .gap = 10, .padding = 16, .children = children[0..4] } };
}

test "ui renderer emits commands and structural hits without allocation" {
    var nodes: [5]Node = undefined;
    const root = sampleRoot(&nodes);

    var commands: [32]Command = undefined;
    var scene = Scene.init(&commands);
    try render(&scene, root, .{ .x = 0, .y = 0, .w = 320, .h = 240 }, .{});

    try std.testing.expect(scene.commandCount() > 0);

    var hits: usize = 0;
    for (scene.written()) |command| {
        if (command == .hit) hits += 1;
    }
    try std.testing.expectEqual(@as(usize, 3), hits);
}

test "stack layout stays inside small responsive bounds" {
    var nodes = [_]Node{
        textNode("status", .accent),
        inputNode(10, "search canonical objects"),
        rowItemNode(20, "object graph renderer", ""),
        buttonNode(30, "Render"),
    };
    const root = columnStack(18.0, 48.0, &nodes);
    const viewport = Rect.init(0.0, 0.0, 160.0, 96.0);

    var commands: [32]Command = undefined;
    var scene = Scene.init(&commands);
    try render(&scene, root, viewport, .{});

    var hits: usize = 0;
    for (scene.written()) |command| switch (command) {
        .rect => |rect_cmd| try expectRectInside(rect_cmd.bounds, viewport),
        .border => |border_cmd| try expectRectInside(border_cmd.bounds, viewport),
        .text => |text_cmd| try expectRectInside(text_cmd.origin, viewport),
        .hit => |hit| {
            hits += 1;
            try expectRectInside(hit.bounds, viewport);
        },
        else => {},
    };
    try std.testing.expectEqual(@as(usize, 3), hits);
}

test "row layout proportionally shrinks overflowing children" {
    var nodes = [_]Node{
        buttonNode(1, "One"),
        inputNode(2, "Two"),
        buttonNode(3, "Three"),
    };
    const root = rowStack(24.0, 16.0, &nodes);
    const viewport = Rect.init(0.0, 0.0, 180.0, 48.0);

    var commands: [32]Command = undefined;
    var scene = Scene.init(&commands);
    try render(&scene, root, viewport, .{});

    var hits: usize = 0;
    var previous_end: f32 = 0.0;
    for (scene.written()) |command| switch (command) {
        .hit => |hit| {
            hits += 1;
            try expectRectInside(hit.bounds, viewport);
            try std.testing.expect(hit.bounds.x >= previous_end);
            previous_end = hit.bounds.x + hit.bounds.w;
        },
        else => {},
    };
    try std.testing.expectEqual(@as(usize, 3), hits);
}

test "stack cross-axis alignment keeps children at preferred size" {
    var nodes = [_]Node{
        buttonNode(1, "One"),
        buttonNode(2, "Two"),
    };
    const root = alignedRow(8.0, 4.0, .center, &nodes);
    const viewport = Rect.init(0.0, 0.0, 320.0, 96.0);

    var commands: [32]Command = undefined;
    var scene = Scene.init(&commands);
    try render(&scene, root, viewport, .{});

    var hits: usize = 0;
    for (scene.written()) |command| switch (command) {
        .hit => |hit| {
            hits += 1;
            try std.testing.expectEqual(@as(f32, 36.0), hit.bounds.h);
            try std.testing.expect(hit.bounds.y > viewport.y);
            try std.testing.expect(hit.bounds.y + hit.bounds.h < viewport.y + viewport.h);
        },
        else => {},
    };
    try std.testing.expectEqual(@as(usize, 2), hits);
}

test "patches mutate only the matching node variant" {
    var button_node = Node{ .button = .{ .id = 9, .label = "Before" } };
    try applyPatch(&button_node, .{ .button_label = "After" });
    try std.testing.expectEqualStrings("After", button_node.button.label);

    try std.testing.expectError(error.WrongNodeKind, applyPatch(&button_node, .{ .input_placeholder = "Nope" }));
}

test "patches change rendered output without changing structural hit ids" {
    var node = Node{ .button = .{ .id = 42, .label = "Before" } };
    var commands: [8]Command = undefined;
    var scene = Scene.init(&commands);

    try render(&scene, node, .{ .x = 0, .y = 0, .w = 120, .h = 40 }, .{});
    try std.testing.expectEqual(@as(u32, 42), firstHitId(scene.written()).?);

    try applyPatch(&node, .{ .button_label = "After" });
    scene.clear();
    try render(&scene, node, .{ .x = 0, .y = 0, .w = 120, .h = 40 }, .{});

    var saw_after_text = false;
    for (scene.written()) |command| switch (command) {
        .text => |text_cmd| {
            if (std.mem.eql(u8, text_cmd.value, "After")) saw_after_text = true;
        },
        else => {},
    };
    try std.testing.expect(saw_after_text);
    try std.testing.expectEqual(@as(u32, 42), firstHitId(scene.written()).?);
}

test "scene typed pushes validate clip and query topmost commands" {
    var commands: [16]Command = undefined;
    var clips: [4]Rect = undefined;
    var scene = Scene.initWithClips(&commands, &clips);

    try scene.pushRect(Rect.init(0.0, 0.0, 0.0, 10.0), .text, .fill, 0.0, 0.0);
    try scene.pushRect(Rect.init(0.0, 0.0, 20.0, 10.0), .text, .fill, 999.0, -8.0);
    try std.testing.expectEqual(@as(usize, 1), scene.commandCount());
    try std.testing.expectEqual(@as(f32, 5.0), scene.commandAt(0).?.rect.radius);
    try std.testing.expectEqual(@as(f32, 0.0), scene.commandAt(0).?.rect.shadow);

    scene.clear();
    try std.testing.expect(try scene.pushClip(Rect.init(5.0, 0.0, 10.0, 10.0)));
    try scene.pushRect(Rect.init(0.0, 0.0, 20.0, 20.0), .text, .shadow, 12.0, 6.0);
    try scene.pushHit(.{ .slot = 0, .kind = .button, .id = 7, .bounds = Rect.init(0.0, 0.0, 20.0, 20.0) });
    try scene.pushTextQuad(.{ .bounds = Rect.init(0.0, 0.0, 20.0, 10.0), .color = .text });
    try std.testing.expectEqual(@as(f32, 5.0), scene.commandAt(0).?.rect.bounds.x);
    try std.testing.expectEqual(@as(f32, 10.0), scene.commandAt(0).?.rect.bounds.w);
    try std.testing.expectEqual(@as(f32, 5.0), scene.commandAt(0).?.rect.radius);
    try std.testing.expectEqual(@as(f32, 5.0), scene.commandAt(1).?.hit.bounds.x);
    try std.testing.expectEqual(@as(f32, 10.0), scene.commandAt(1).?.hit.bounds.w);
    try std.testing.expectEqual(@as(f32, 0.25), scene.commandAt(2).?.text_quad.u0);
    try std.testing.expectEqual(@as(f32, 0.75), scene.commandAt(2).?.text_quad.u1);
    scene.popClip();

    scene.clear();
    try scene.pushHit(.{ .slot = 0, .kind = .button, .id = 1, .bounds = Rect.init(0.0, 0.0, 10.0, 10.0) });
    try scene.pushHit(.{ .slot = 0, .kind = .button, .id = 2, .bounds = Rect.init(0.0, 0.0, 10.0, 10.0) });
    try scene.pushDragSource(.{ .scope_id = 9, .item_id = 1, .index = 0, .bounds = Rect.init(0.0, 0.0, 10.0, 10.0) });
    try scene.pushDragSource(.{ .scope_id = 9, .item_id = 2, .index = 1, .bounds = Rect.init(0.0, 0.0, 10.0, 10.0) });
    try scene.pushDropTarget(.{ .scope_id = 9, .index = 0, .bounds = Rect.init(0.0, 0.0, 10.0, 10.0) });
    try scene.pushDropTarget(.{ .scope_id = 9, .index = 1, .bounds = Rect.init(0.0, 0.0, 10.0, 10.0) });
    try std.testing.expectEqual(@as(u32, 2), scene.commandAt(1).?.hit.id);
    try std.testing.expectEqual(@as(u32, 2), scene.commandAt(3).?.drag_source.item_id);
    try std.testing.expectEqual(@as(usize, 1), scene.commandAt(5).?.drop_target.index);
}

fn firstHitId(commands: []const Command) ?u32 {
    for (commands) |command| switch (command) {
        .hit => |hit| return hit.id,
        else => {},
    };
    return null;
}

fn expectRectInside(inner: Rect, outer: Rect) !void {
    try std.testing.expect(inner.valid());
    try std.testing.expect(inner.x >= outer.x);
    try std.testing.expect(inner.y >= outer.y);
    try std.testing.expect(inner.x + inner.w <= outer.x + outer.w);
    try std.testing.expect(inner.y + inner.h <= outer.y + outer.h);
}

test "scene cursor mutation transition easing and budget contracts" {
    var commands: [16]Command = undefined;
    var scene = Scene.init(&commands);

    try scene.pushRect(Rect.init(0.0, 0.0, 4.0, 4.0), .text, .fill, 0.0, 0.0);
    const mark = scene.cursor();
    try scene.pushRect(Rect.init(1.0, 2.0, 4.0, 4.0), .text, .fill, 0.0, 0.0);
    try scene.pushHit(.{ .slot = 0, .kind = .button, .id = 8, .bounds = Rect.init(1.0, 2.0, 4.0, 4.0) });
    try scene.pushIconQuad(.{ .bounds = Rect.init(1.0, 2.0, 4.0, 4.0), .color = .text });

    scene.applyOpacitySince(mark, 0.5);
    scene.translateSince(mark, 3.0, 4.0);

    try std.testing.expectEqual(@as(f32, 0.0), scene.commandAt(0).?.rect.bounds.x);
    try std.testing.expectEqual(@as(u8, 255), scene.commandAt(0).?.rect.color.a);
    try std.testing.expectEqual(@as(f32, 4.0), scene.commandAt(1).?.rect.bounds.x);
    try std.testing.expectEqual(@as(f32, 6.0), scene.commandAt(1).?.rect.bounds.y);
    try std.testing.expectEqual(@as(u8, 128), scene.commandAt(1).?.rect.color.a);
    try std.testing.expectEqual(@as(f32, 4.0), scene.commandAt(2).?.hit.bounds.x);
    try std.testing.expectEqual(@as(u8, 128), scene.commandAt(3).?.icon_quad.color.a);

    try std.testing.expectEqual(@as(f32, 0.25), easingSample(.linear, 0.25));
    try std.testing.expectEqual(@as(f32, 0.25), easingSample(.ease_in, 0.5));
    try std.testing.expectEqual(@as(f32, 0.75), easingSample(.ease_out, 0.5));
    try std.testing.expectEqual(@as(f32, 0.5), easingSample(.ease_in_out, 0.5));

    try scene.pushTransition(transitionOpacity(1, 0.0, 1.0, 0));
    try scene.pushTransition(transitionTranslateY(2, -8.0, 0.0, 120));
    try std.testing.expectEqual(@as(usize, 1), scene.stats().transitions);

    const violation = firstBudgetViolation(.{ .rects = 10, .hits = 2 }, .{ .rects = 8, .hits = 1 }).?;
    try std.testing.expectEqualStrings("rects", violation.name);
    try std.testing.expectEqual(@as(usize, 10), violation.actual);
    try std.testing.expectEqual(@as(usize, 8), violation.limit);
    try std.testing.expect(!statsFitBudget(.{ .rects = 10 }, .{ .rects = 8 }));
    try std.testing.expect(statsFitBudget(.{ .rects = 10 }, frameBudget()));
}
