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

pub const LinearCursor = struct {
    bounds: Rect,
    axis: Axis,
    gap: f32,
    offset: f32 = 0.0,

    pub fn init(bounds: Rect, axis: Axis, gap: f32) LinearCursor {
        return .{ .bounds = bounds, .axis = axis, .gap = @max(0.0, gap) };
    }

    pub fn take(self: *LinearCursor, main_size: f32) Rect {
        const size = @max(0.0, main_size);
        const out = switch (self.axis) {
            .row => Rect.init(self.bounds.x + self.offset, self.bounds.y, size, self.bounds.h),
            .column => Rect.init(self.bounds.x, self.bounds.y + self.offset, self.bounds.w, size),
        };
        self.offset += size + self.gap;
        return out;
    }

    pub fn skip(self: *LinearCursor, main_size: f32) void {
        self.offset += @max(0.0, main_size) + self.gap;
    }

    pub fn remaining(self: LinearCursor) Rect {
        return switch (self.axis) {
            .row => Rect.init(self.bounds.x + self.offset, self.bounds.y, @max(0.0, self.bounds.w - self.offset), self.bounds.h),
            .column => Rect.init(self.bounds.x, self.bounds.y + self.offset, self.bounds.w, @max(0.0, self.bounds.h - self.offset)),
        };
    }
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
    checkbox,
    switch_control,
    slider,
    textarea,
    select,
};

pub const RectMode = enum(u8) {
    fill,
    shadow,
    border,
    linear_gradient,
    pie_slice,
};

pub const TextAlign = enum(u8) {
    start,
    center,
    end,
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

pub const IconQuad = struct {
    bounds: Rect,
    icon_id: u32,
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
    text: struct { origin: Rect, value: []const u8, color: Color, alignment: TextAlign = .start },
    drag_source: DragSource,
    drop_target: DropTarget,
    icon_quad: IconQuad,
    text_quad: Quad,
    image_quad: Quad,
    transition: Transition,
};

pub const TextWrap = struct {
    line_height: f32 = 22.0,
    average_char_width: f32 = 9.0,
    max_lines: usize = 8,
};

pub const Cursor = struct {
    commands: usize = 0,
};

pub const Stats = struct {
    rects: usize = 0,
    drag_sources: usize = 0,
    drop_targets: usize = 0,
    transitions: usize = 0,
    clips: usize = 0,
    icon_quads: usize = 0,
    text_quads: usize = 0,
    image_quads: usize = 0,
};

pub const Budget = struct {
    rects: usize = 2000,
    drag_sources: usize = 240,
    drop_targets: usize = 240,
    transitions: usize = 1200,
    icon_quads: usize = 160,
    text_quads: usize = 900,
    image_quads: usize = 16,
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

    pub fn pushPieSlice(self: *Scene, bounds: Rect, color: Color, start_turn: f32, end_turn: f32) RenderError!void {
        if (!geometry.finite(start_turn) or !geometry.finite(end_turn)) return;
        if (end_turn <= start_turn) return;
        const encoded_angles = Color{
            .r = unitByte(start_turn),
            .g = unitByte(end_turn),
            .b = 0,
            .a = 255,
        };
        try self.pushRectPair(bounds, color, encoded_angles, .pie_slice, 0.0, 0.0);
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

    pub fn pushIconQuad(self: *Scene, quad: IconQuad) RenderError!void {
        if (quad.icon_id == 0) return;
        if (self.clipRect(quad.bounds)) |clipped| {
            try self.push(.{ .icon_quad = .{
                .bounds = clipped,
                .icon_id = quad.icon_id,
                .color = quad.color,
            } });
        }
    }

    pub fn pushTextQuad(self: *Scene, quad: Quad) RenderError!void {
        if (self.clipQuad(quad)) |clipped| try self.push(.{ .text_quad = clipped });
    }

    pub fn pushImageQuad(self: *Scene, quad: Quad) RenderError!void {
        if (self.clipQuad(quad)) |clipped| try self.push(.{ .image_quad = clipped });
    }

    pub fn pushText(self: *Scene, origin: Rect, value: []const u8, color: Color) RenderError!void {
        try self.pushAlignedText(origin, value, color, .start);
    }

    pub fn pushAlignedText(self: *Scene, origin: Rect, value: []const u8, color: Color, alignment: TextAlign) RenderError!void {
        if (value.len == 0) return;
        if (self.clipRect(origin)) |clipped| {
            try self.push(.{ .text = .{ .origin = clipped, .value = value, .color = color, .alignment = alignment } });
        }
    }

    pub fn pushWrappedText(self: *Scene, bounds: Rect, value: []const u8, color: Color, wrap: TextWrap) RenderError!void {
        if (value.len == 0 or !bounds.valid() or wrap.max_lines == 0) return;
        if (!geometry.finite(wrap.line_height) or !geometry.finite(wrap.average_char_width)) return;
        if (wrap.line_height <= 0.0 or wrap.average_char_width <= 0.0) return;

        const max_lines_by_height = @max(@as(usize, 1), @as(usize, @intFromFloat(@max(1.0, bounds.h / wrap.line_height))));
        const max_lines = @min(wrap.max_lines, max_lines_by_height);
        const char_capacity = @max(@as(usize, 1), @as(usize, @intFromFloat(@max(1.0, bounds.w / wrap.average_char_width))));
        var byte_cursor: usize = 0;
        var line_index: usize = 0;
        while (line_index < max_lines) : (line_index += 1) {
            byte_cursor = skipAsciiSpace(value, byte_cursor);
            if (byte_cursor >= value.len) break;
            const split = wrappedLine(value, byte_cursor, char_capacity);
            if (split.end > split.start) {
                try self.pushText(.{
                    .x = bounds.x,
                    .y = bounds.y + @as(f32, @floatFromInt(line_index)) * wrap.line_height,
                    .w = bounds.w,
                    .h = wrap.line_height,
                }, value[split.start..split.end], color);
            }
            byte_cursor = split.next;
        }
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
            .drag_source => out.drag_sources += 1,
            .drop_target => out.drop_targets += 1,
            .transition => out.transitions += 1,
            .icon_quad => out.icon_quads += 1,
            .text_quad, .text => out.text_quads += 1,
            .image_quad => out.image_quads += 1,
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
            .image_quad => |*quad| quad.color.a = scaleAlpha(quad.color.a, alpha),
            else => {},
        };
    }

    pub fn translateSince(self: *Scene, mark: Cursor, dx: f32, dy: f32) void {
        if (!geometry.finite(dx) or !geometry.finite(dy)) return;
        for (self.commands.mutableSlice()[mark.commands..]) |*command| switch (command.*) {
            .rect => |*rect_cmd| translateRect(&rect_cmd.bounds, dx, dy),
            .border => |*border| translateRect(&border.bounds, dx, dy),
            .text => |*text_cmd| translateRect(&text_cmd.origin, dx, dy),
            .drag_source => |*source| translateRect(&source.bounds, dx, dy),
            .drop_target => |*target| translateRect(&target.bounds, dx, dy),
            .icon_quad => |*quad| translateRect(&quad.bounds, dx, dy),
            .text_quad => |*quad| translateRect(&quad.bounds, dx, dy),
            .image_quad => |*quad| translateRect(&quad.bounds, dx, dy),
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
        .{ .name = "drag_sources", .actual = stats_value.drag_sources, .limit = budget.drag_sources },
        .{ .name = "drop_targets", .actual = stats_value.drop_targets, .limit = budget.drop_targets },
        .{ .name = "transitions", .actual = stats_value.transitions, .limit = budget.transitions },
        .{ .name = "icon_quads", .actual = stats_value.icon_quads, .limit = budget.icon_quads },
        .{ .name = "text_quads", .actual = stats_value.text_quads, .limit = budget.text_quads },
        .{ .name = "image_quads", .actual = stats_value.image_quads, .limit = budget.image_quads },
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

fn unitByte(value: f32) u8 {
    return @intFromFloat(@round(geometry.clamp(value, 0.0, 1.0) * 255.0));
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
    card: struct { title: []const u8, detail: []const u8 },
    badge: struct { label: []const u8 },
    avatar: struct { label: []const u8 },
    kbd: struct { label: []const u8 },
    separator: void,
    button: struct { id: u32, label: []const u8 },
    input: struct { id: u32, placeholder: []const u8 },
    textarea: struct { id: u32, placeholder: []const u8 },
    select: struct { id: u32, label: []const u8 },
    checkbox: struct { id: u32, label: []const u8, checked: bool },
    switch_control: struct { id: u32, label: []const u8, checked: bool },
    progress: struct { value: f32 },
    slider: struct { id: u32, label: []const u8, value: f32 },
    row_item: struct { id: u32, title: []const u8, detail: []const u8 },
    slot: Slot,
    stack: Layout,

    pub fn preferredSize(self: Node) Size {
        return switch (self) {
            .rect => .{ .w = 32, .h = 32 },
            .text => .{ .w = 96, .h = 22 },
            .card => .{ .w = 260, .h = 96 },
            .badge => .{ .w = 96, .h = 24 },
            .avatar => .{ .w = 40, .h = 40 },
            .kbd => .{ .w = 48, .h = 24 },
            .separator => .{ .w = 220, .h = 1 },
            .button => .{ .w = 112, .h = 36 },
            .input => .{ .w = 220, .h = 40 },
            .textarea => .{ .w = 220, .h = 88 },
            .select => .{ .w = 220, .h = 40 },
            .checkbox => .{ .w = 220, .h = 28 },
            .switch_control => .{ .w = 220, .h = 32 },
            .progress => .{ .w = 220, .h = 10 },
            .slider => .{ .w = 220, .h = 42 },
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

pub fn cardNode(title: []const u8, detail: []const u8) Node {
    return .{ .card = .{ .title = title, .detail = detail } };
}

pub fn badgeNode(label: []const u8) Node {
    return .{ .badge = .{ .label = label } };
}

pub fn avatarNode(label: []const u8) Node {
    return .{ .avatar = .{ .label = label } };
}

pub fn kbdNode(label: []const u8) Node {
    return .{ .kbd = .{ .label = label } };
}

pub fn separatorNode() Node {
    return .{ .separator = {} };
}

pub fn buttonNode(id: u32, label: []const u8) Node {
    return .{ .button = .{ .id = id, .label = label } };
}

pub fn inputNode(id: u32, placeholder: []const u8) Node {
    return .{ .input = .{ .id = id, .placeholder = placeholder } };
}

pub fn textareaNode(id: u32, placeholder: []const u8) Node {
    return .{ .textarea = .{ .id = id, .placeholder = placeholder } };
}

pub fn selectNode(id: u32, label: []const u8) Node {
    return .{ .select = .{ .id = id, .label = label } };
}

pub fn checkboxNode(id: u32, label: []const u8, checked: bool) Node {
    return .{ .checkbox = .{ .id = id, .label = label, .checked = checked } };
}

pub fn switchNode(id: u32, label: []const u8, checked: bool) Node {
    return .{ .switch_control = .{ .id = id, .label = label, .checked = checked } };
}

pub fn progressNode(value: f32) Node {
    return .{ .progress = .{ .value = value } };
}

pub fn sliderNode(id: u32, label: []const u8, value: f32) Node {
    return .{ .slider = .{ .id = id, .label = label, .value = value } };
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
    card_text: struct { title: []const u8, detail: []const u8 },
    badge_label: []const u8,
    avatar_label: []const u8,
    kbd_label: []const u8,
    button_label: []const u8,
    input_placeholder: []const u8,
    textarea_placeholder: []const u8,
    select_label: []const u8,
    checkbox_checked: bool,
    switch_checked: bool,
    progress_value: f32,
    slider_value: f32,
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
        .card_text => |card_patch| switch (node.*) {
            .card => |*card| {
                card.title = card_patch.title;
                card.detail = card_patch.detail;
            },
            else => return error.WrongNodeKind,
        },
        .badge_label => |label| switch (node.*) {
            .badge => |*badge| badge.label = label,
            else => return error.WrongNodeKind,
        },
        .avatar_label => |label| switch (node.*) {
            .avatar => |*avatar| avatar.label = label,
            else => return error.WrongNodeKind,
        },
        .kbd_label => |label| switch (node.*) {
            .kbd => |*kbd| kbd.label = label,
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
        .textarea_placeholder => |placeholder| switch (node.*) {
            .textarea => |*textarea| textarea.placeholder = placeholder,
            else => return error.WrongNodeKind,
        },
        .select_label => |label| switch (node.*) {
            .select => |*select| select.label = label,
            else => return error.WrongNodeKind,
        },
        .checkbox_checked => |checked| switch (node.*) {
            .checkbox => |*checkbox| checkbox.checked = checked,
            else => return error.WrongNodeKind,
        },
        .switch_checked => |checked| switch (node.*) {
            .switch_control => |*switch_control| switch_control.checked = checked,
            else => return error.WrongNodeKind,
        },
        .progress_value => |value| switch (node.*) {
            .progress => |*progress| progress.value = clampUnit(value),
            else => return error.WrongNodeKind,
        },
        .slider_value => |value| switch (node.*) {
            .slider => |*slider| slider.value = clampUnit(value),
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
    try renderNode(scene, node, bounds, style);
}

fn renderNode(scene: *Scene, node: Node, bounds: Rect, style: Style) RenderError!void {
    if (!bounds.valid()) return error.InvalidBounds;
    switch (node) {
        .rect => |rect_node| try scene.push(.{ .rect = .{ .bounds = bounds, .color = rect_node.color } }),
        .text => |text_node| try scene.push(.{ .text = .{ .origin = bounds, .value = text_node.value, .color = text_node.color orelse style.text } }),
        .card => |card| try renderCard(scene, bounds, card.title, card.detail, style),
        .badge => |badge| try renderBadge(scene, bounds, badge.label, style),
        .avatar => |avatar| try renderAvatar(scene, bounds, avatar.label, style),
        .kbd => |kbd| try renderKbd(scene, bounds, kbd.label, style),
        .separator => try renderSeparator(scene, bounds, style),
        .button => |button| {
            try scene.pushRect(bounds, surface_shadow, .shadow, control_radius, control_shadow);
            try scene.pushGradientRect(bounds, style.accent, accent_bottom, control_radius);
            try scene.pushRect(bounds, style.border, .border, control_radius, 0.0);
            try scene.push(.{ .text = .{ .origin = buttonLabelBounds(bounds), .value = button.label, .color = style.bg, .alignment = .center } });
        },
        .input => |input| {
            try scene.pushRect(bounds, style.panel, .fill, control_radius, 0.0);
            try scene.pushRect(bounds, style.border, .border, control_radius, 0.0);
            if (contentInset(bounds, input_text_padding)) |placeholder_bounds| {
                try scene.push(.{ .text = .{ .origin = placeholder_bounds, .value = input.placeholder, .color = style.muted } });
            }
        },
        .textarea => |textarea| try renderTextarea(scene, bounds, textarea.placeholder, style),
        .select => |select| try renderSelect(scene, bounds, select.label, style),
        .checkbox => |checkbox| try renderCheckbox(scene, bounds, checkbox.label, checkbox.checked, style),
        .switch_control => |switch_control| try renderSwitch(scene, bounds, switch_control.label, switch_control.checked, style),
        .progress => |progress| try renderProgress(scene, bounds, progress.value, style),
        .slider => |slider| try renderSlider(scene, bounds, slider.label, slider.value, style),
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
        },
        .slot => |slot_node| try renderNode(scene, slot_node.child.*, bounds, style),
        .stack => |layout| try renderStack(scene, layout, bounds, style),
    }
}

const control_radius: f32 = 6.0;
const control_shadow: f32 = 5.0;
const row_radius: f32 = 4.0;
const surface_shadow = Color{ .r = 0, .g = 0, .b = 0, .a = 96 };
const accent_bottom = Color{ .r = 15, .g = 183, .b = 210 };
const button_label_height: f32 = 14.0;
const button_label_horizontal_padding: f32 = 16.0;
const input_text_padding: f32 = 12.0;
const row_text_padding_x: f32 = 12.0;
const row_title_offset_y: f32 = 8.0;
const row_detail_offset_y: f32 = 26.0;
const row_title_height: f32 = 18.0;
const row_detail_height: f32 = 16.0;
const badge_height: f32 = 24.0;
const badge_text_height: f32 = 13.0;
const badge_padding_x: f32 = 10.0;
const card_padding: f32 = 14.0;
const card_title_height: f32 = 18.0;
const card_detail_height: f32 = 16.0;
const card_detail_gap: f32 = 8.0;
const avatar_size: f32 = 40.0;
const avatar_text_height: f32 = 14.0;
const kbd_height: f32 = 24.0;
const kbd_text_height: f32 = 12.0;
const separator_height: f32 = 1.0;
const checkbox_box_size: f32 = 18.0;
const checkbox_mark_inset: f32 = 5.0;
const checkbox_text_gap: f32 = 10.0;
const control_label_height: f32 = 16.0;
const switch_width: f32 = 42.0;
const switch_height: f32 = 24.0;
const switch_knob_size: f32 = 18.0;
const switch_knob_inset: f32 = 3.0;
const progress_height: f32 = 8.0;
const slider_label_height: f32 = 14.0;
const slider_track_height: f32 = 6.0;
const slider_thumb_size: f32 = 16.0;
const slider_track_top: f32 = 26.0;
const textarea_padding: f32 = 12.0;
const select_arrow_w: f32 = 18.0;
const codec_unit_scale: f32 = 1000.0;

fn renderCard(scene: *Scene, bounds: Rect, title: []const u8, detail: []const u8, style: Style) RenderError!void {
    try scene.pushRect(bounds, surface_shadow, .shadow, control_radius + 2.0, control_shadow);
    try scene.pushRect(bounds, style.panel, .fill, control_radius + 2.0, 0.0);
    try scene.pushRect(bounds, style.border, .border, control_radius + 2.0, 0.0);
    const title_bounds = Rect.init(bounds.x + card_padding, bounds.y + card_padding, @max(1.0, bounds.w - card_padding * 2.0), card_title_height);
    try scene.push(.{ .text = .{ .origin = title_bounds, .value = title, .color = style.text } });
    if (detail.len != 0) {
        const detail_y = title_bounds.y + title_bounds.h + card_detail_gap;
        const detail_bounds = Rect.init(title_bounds.x, detail_y, title_bounds.w, @max(1.0, bounds.y + bounds.h - detail_y - card_padding));
        try scene.pushWrappedText(detail_bounds, detail, style.muted, .{
            .line_height = card_detail_height,
            .average_char_width = 8.5,
            .max_lines = 3,
        });
    }
}

fn renderBadge(scene: *Scene, bounds: Rect, label: []const u8, style: Style) RenderError!void {
    const height = geometry.clamp(badge_height, 1.0, bounds.h);
    const badge_bounds = Rect.init(bounds.x, bounds.y + (bounds.h - height) * 0.5, bounds.w, height);
    var fill = style.accent;
    fill.a = 42;
    try scene.pushRect(badge_bounds, fill, .fill, height * 0.5, 0.0);
    if (contentInset(badge_bounds, badge_padding_x)) |label_bounds| {
        try scene.push(.{ .text = .{ .origin = label_bounds.withHeightCentered(badge_text_height), .value = label, .color = style.accent, .alignment = .center } });
    }
}

fn renderAvatar(scene: *Scene, bounds: Rect, label: []const u8, style: Style) RenderError!void {
    const size = geometry.clamp(avatar_size, 1.0, @min(bounds.w, bounds.h));
    const avatar_bounds = Rect.init(bounds.x + (bounds.w - size) * 0.5, bounds.y + (bounds.h - size) * 0.5, size, size);
    try scene.pushRect(avatar_bounds, style.row, .fill, size * 0.5, 0.0);
    try scene.pushRect(avatar_bounds, style.border, .border, size * 0.5, 0.0);
    const label_bounds = avatar_bounds.insetUniform(6.0).withHeightCentered(avatar_text_height);
    try scene.push(.{ .text = .{ .origin = label_bounds, .value = label, .color = style.text, .alignment = .center } });
}

fn renderKbd(scene: *Scene, bounds: Rect, label: []const u8, style: Style) RenderError!void {
    const height = geometry.clamp(kbd_height, 1.0, bounds.h);
    const kbd_bounds = Rect.init(bounds.x, bounds.y + (bounds.h - height) * 0.5, bounds.w, height);
    try scene.pushRect(kbd_bounds, style.row, .fill, control_radius, 0.0);
    try scene.pushRect(kbd_bounds, style.border, .border, control_radius, 0.0);
    if (contentInset(kbd_bounds, 8.0)) |label_bounds| {
        try scene.push(.{ .text = .{ .origin = label_bounds.withHeightCentered(kbd_text_height), .value = label, .color = style.text, .alignment = .center } });
    }
}

fn renderSeparator(scene: *Scene, bounds: Rect, style: Style) RenderError!void {
    const line = Rect.init(bounds.x, bounds.y + (bounds.h - separator_height) * 0.5, bounds.w, separator_height);
    try scene.pushRect(line, style.border, .fill, 0.0, 0.0);
}

fn renderCheckbox(scene: *Scene, bounds: Rect, label: []const u8, checked: bool, style: Style) RenderError!void {
    const box = Rect.init(bounds.x, bounds.y + (bounds.h - checkbox_box_size) * 0.5, checkbox_box_size, checkbox_box_size);
    try scene.pushRect(box, if (checked) style.accent else style.panel, .fill, control_radius, 0.0);
    try scene.pushRect(box, if (checked) style.accent else style.border, .border, control_radius, 0.0);
    if (checked) {
        try scene.pushRect(box.insetUniform(checkbox_mark_inset), style.bg, .fill, 2.0, 0.0);
    }
    const label_x = box.x + box.w + checkbox_text_gap;
    const label_bounds = Rect.init(label_x, bounds.y + (bounds.h - control_label_height) * 0.5, @max(1.0, bounds.x + bounds.w - label_x), control_label_height);
    try scene.push(.{ .text = .{ .origin = label_bounds, .value = label, .color = style.text } });
}

fn renderSwitch(scene: *Scene, bounds: Rect, label: []const u8, checked: bool, style: Style) RenderError!void {
    const pill = Rect.init(bounds.x + bounds.w - switch_width, bounds.y + (bounds.h - switch_height) * 0.5, switch_width, switch_height);
    try scene.pushRect(pill, if (checked) style.accent else style.row, .fill, switch_height * 0.5, 0.0);
    try scene.pushRect(pill, style.border, .border, switch_height * 0.5, 0.0);
    const knob_x = if (checked) pill.x + pill.w - switch_knob_size - switch_knob_inset else pill.x + switch_knob_inset;
    const knob = Rect.init(knob_x, pill.y + switch_knob_inset, switch_knob_size, switch_knob_size);
    try scene.pushRect(knob, style.text, .fill, switch_knob_size * 0.5, 0.0);
    const label_bounds = Rect.init(bounds.x, bounds.y + (bounds.h - control_label_height) * 0.5, @max(1.0, pill.x - bounds.x - checkbox_text_gap), control_label_height);
    try scene.push(.{ .text = .{ .origin = label_bounds, .value = label, .color = style.text } });
}

fn renderTextarea(scene: *Scene, bounds: Rect, placeholder: []const u8, style: Style) RenderError!void {
    try scene.pushRect(bounds, style.panel, .fill, control_radius, 0.0);
    try scene.pushRect(bounds, style.border, .border, control_radius, 0.0);
    const text_bounds = bounds.insetUniform(textarea_padding);
    if (text_bounds.valid()) {
        try scene.pushWrappedText(text_bounds, placeholder, style.muted, .{
            .line_height = control_label_height,
            .average_char_width = 8.5,
            .max_lines = 4,
        });
    }
}

fn renderSelect(scene: *Scene, bounds: Rect, label: []const u8, style: Style) RenderError!void {
    try scene.pushRect(bounds, style.panel, .fill, control_radius, 0.0);
    try scene.pushRect(bounds, style.border, .border, control_radius, 0.0);
    if (contentInset(bounds, input_text_padding)) |label_bounds| {
        const text_bounds = Rect.init(label_bounds.x, label_bounds.y, @max(1.0, label_bounds.w - select_arrow_w), label_bounds.h);
        try scene.push(.{ .text = .{ .origin = text_bounds, .value = label, .color = style.text } });
        const arrow_bounds = Rect.init(label_bounds.x + label_bounds.w - select_arrow_w, label_bounds.y, select_arrow_w, label_bounds.h);
        try scene.push(.{ .text = .{ .origin = arrow_bounds, .value = "v", .color = style.muted, .alignment = .center } });
    }
}

fn renderProgress(scene: *Scene, bounds: Rect, value: f32, style: Style) RenderError!void {
    const track = Rect.init(bounds.x, bounds.y + (bounds.h - progress_height) * 0.5, bounds.w, progress_height);
    try scene.pushRect(track, style.row, .fill, progress_height * 0.5, 0.0);
    try scene.pushRect(Rect.init(track.x, track.y, track.w * clampUnit(value), track.h), style.accent, .fill, progress_height * 0.5, 0.0);
}

fn renderSlider(scene: *Scene, bounds: Rect, label: []const u8, value: f32, style: Style) RenderError!void {
    const clamped = clampUnit(value);
    try scene.push(.{ .text = .{ .origin = Rect.init(bounds.x, bounds.y, bounds.w, slider_label_height), .value = label, .color = style.text } });
    const track_y = bounds.y + @min(slider_track_top, @max(0.0, bounds.h - slider_track_height));
    const track = Rect.init(bounds.x, track_y, bounds.w, slider_track_height);
    try scene.pushRect(track, style.row, .fill, slider_track_height * 0.5, 0.0);
    try scene.pushRect(Rect.init(track.x, track.y, track.w * clamped, track.h), style.accent, .fill, slider_track_height * 0.5, 0.0);
    const thumb_center = track.x + track.w * clamped;
    const thumb = Rect.init(thumb_center - slider_thumb_size * 0.5, track.y + (track.h - slider_thumb_size) * 0.5, slider_thumb_size, slider_thumb_size);
    try scene.pushRect(thumb, style.text, .fill, slider_thumb_size * 0.5, 0.0);
}

pub fn clampUnit(value: f32) f32 {
    if (!geometry.finite(value)) return 0.0;
    return geometry.clamp(value, 0.0, 1.0);
}

pub fn encodeUnit(value: f32) u16 {
    return @intFromFloat(@round(clampUnit(value) * codec_unit_scale));
}

pub fn decodeUnit(value: u16) f32 {
    return geometry.clamp(@as(f32, @floatFromInt(value)) / codec_unit_scale, 0.0, 1.0);
}

fn contentInset(bounds: Rect, padding: f32) ?Rect {
    const clamped = geometry.clamp(padding, 0.0, @min(bounds.w, bounds.h) * 0.5);
    const out = bounds.insetUniform(clamped);
    return if (out.valid()) out else null;
}

fn buttonLabelBounds(bounds: Rect) Rect {
    const label_margin = geometry.clamp(button_label_horizontal_padding, 0.0, bounds.w * 0.5);
    const label_height = geometry.clamp(button_label_height, 1.0, bounds.h);
    return Rect.init(
        bounds.x + label_margin,
        bounds.y + (bounds.h - label_height) * 0.5,
        @max(1.0, bounds.w - label_margin * 2.0),
        label_height,
    );
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

fn renderStack(scene: *Scene, layout: Layout, bounds: Rect, style: Style) RenderError!void {
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
        try renderNode(scene, child, child_bounds, style);
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

pub const WrappedLine = struct {
    start: usize,
    end: usize,
    next: usize,
};

pub fn skipAsciiSpace(value: []const u8, start: usize) usize {
    var index = start;
    while (index < value.len and isAsciiSpace(value[index])) : (index += 1) {}
    return index;
}

pub fn wrappedLine(value: []const u8, start: usize, char_capacity: usize) WrappedLine {
    const limit = @min(value.len, start + char_capacity);
    var index = start;
    var last_space: ?usize = null;
    while (index < limit) : (index += 1) {
        if (value[index] == '\n') return .{ .start = start, .end = index, .next = index + 1 };
        if (isAsciiSpace(value[index])) last_space = index;
    }
    if (limit >= value.len) return .{ .start = start, .end = value.len, .next = value.len };
    if (value[limit] == '\n') return .{ .start = start, .end = limit, .next = limit + 1 };
    if (isAsciiSpace(value[limit])) return .{ .start = start, .end = limit, .next = limit + 1 };
    if (last_space) |space| {
        if (space > start) return .{ .start = start, .end = space, .next = space + 1 };
    }
    return .{ .start = start, .end = limit, .next = limit };
}

fn isAsciiSpace(value: u8) bool {
    return switch (value) {
        ' ', '\t', '\n', '\r' => true,
        else => false,
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

test "ui renderer emits paint commands without allocation" {
    var nodes: [5]Node = undefined;
    const root = sampleRoot(&nodes);

    var commands: [32]Command = undefined;
    var scene = Scene.init(&commands);
    try render(&scene, root, .{ .x = 0, .y = 0, .w = 320, .h = 240 }, .{});

    try std.testing.expect(scene.commandCount() > 0);
    try std.testing.expectEqual(@as(usize, 0), scene.stats().drag_sources);
    try std.testing.expectEqual(@as(usize, 0), scene.stats().drop_targets);
}

test "button node centers label in core renderer" {
    const bounds = Rect.init(10.0, 20.0, 140.0, 36.0);
    var commands: [8]Command = undefined;
    var scene = Scene.init(&commands);
    try render(&scene, buttonNode(7, "Launch"), bounds, .{});

    const label = firstText(scene.written()).?.text;
    const label_center_x = label.origin.x + label.origin.w * 0.5;
    const button_center_x = bounds.x + bounds.w * 0.5;
    const label_center_y = label.origin.y + label.origin.h * 0.5;
    const button_center_y = bounds.y + bounds.h * 0.5;

    try std.testing.expectEqual(TextAlign.center, label.alignment);
    try std.testing.expect(@abs(label_center_x - button_center_x) < 0.01);
    try std.testing.expect(@abs(label_center_y - button_center_y) < 0.01);
}

test "core renderer exposes dev-ready form and feedback primitives" {
    var nodes = [_]Node{
        badgeNode("Ready"),
        checkboxNode(11, "Enable sync", true),
        switchNode(12, "Public statistics", false),
        progressNode(0.64),
        sliderNode(13, "Brightness", 0.72),
    };
    const root = columnStack(8.0, 12.0, &nodes);

    var commands: [64]Command = undefined;
    var scene = Scene.init(&commands);
    try render(&scene, root, Rect.init(0.0, 0.0, 320.0, 180.0), .{});

    try std.testing.expect(hasText(scene.written(), "Ready"));
    try std.testing.expect(hasText(scene.written(), "Enable sync"));
    try std.testing.expect(hasText(scene.written(), "Public statistics"));
    try std.testing.expect(hasText(scene.written(), "Brightness"));
}

test "core renderer exposes dev-ready layout and display primitives" {
    var nodes = [_]Node{
        cardNode("Project", "Interactive docs and app surfaces."),
        separatorNode(),
        avatarNode("ER"),
        kbdNode("⌘K"),
        textareaNode(21, "Describe this app"),
        selectNode(22, "Production"),
    };
    const root = columnStack(8.0, 12.0, &nodes);

    var commands: [96]Command = undefined;
    var scene = Scene.init(&commands);
    try render(&scene, root, Rect.init(0.0, 0.0, 340.0, 340.0), .{});

    try std.testing.expect(hasText(scene.written(), "Project"));
    try std.testing.expect(hasText(scene.written(), "ER"));
    try std.testing.expect(hasText(scene.written(), "⌘K"));
    try std.testing.expect(hasText(scene.written(), "Describe this app"));
    try std.testing.expect(hasText(scene.written(), "Production"));
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

    for (scene.written()) |command| switch (command) {
        .rect => |rect_cmd| try expectRectInside(rect_cmd.bounds, viewport),
        .border => |border_cmd| try expectRectInside(border_cmd.bounds, viewport),
        .text => |text_cmd| try expectRectInside(text_cmd.origin, viewport),
        else => {},
    };
}

fn hasText(commands: []const Command, value: []const u8) bool {
    for (commands) |command| switch (command) {
        .text => |text_command| if (std.mem.eql(u8, text_command.value, value)) return true,
        else => {},
    };
    return false;
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

    for (scene.written()) |command| switch (command) {
        .rect => |rect_cmd| try expectRectInside(rect_cmd.bounds, viewport),
        .border => |border_cmd| try expectRectInside(border_cmd.bounds, viewport),
        .text => |text_cmd| try expectRectInside(text_cmd.origin, viewport),
        else => {},
    };
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

    var label_count: usize = 0;
    for (scene.written()) |command| switch (command) {
        .text => |text_cmd| {
            label_count += 1;
            try std.testing.expectEqual(@as(f32, 14.0), text_cmd.origin.h);
            try std.testing.expect(text_cmd.origin.y > viewport.y);
            try std.testing.expect(text_cmd.origin.y + text_cmd.origin.h < viewport.y + viewport.h);
        },
        else => {},
    };
    try std.testing.expectEqual(@as(usize, 2), label_count);
}

test "patches mutate only the matching node variant" {
    var button_node = Node{ .button = .{ .id = 9, .label = "Before" } };
    try applyPatch(&button_node, .{ .button_label = "After" });
    try std.testing.expectEqualStrings("After", button_node.button.label);

    try std.testing.expectError(error.WrongNodeKind, applyPatch(&button_node, .{ .input_placeholder = "Nope" }));
}

test "patches change rendered output without changing paint command shape" {
    var node = Node{ .button = .{ .id = 42, .label = "Before" } };
    var commands: [8]Command = undefined;
    var scene = Scene.init(&commands);

    try render(&scene, node, .{ .x = 0, .y = 0, .w = 120, .h = 40 }, .{});
    const before_count = scene.commandCount();

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
    try std.testing.expectEqual(before_count, scene.commandCount());
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
    try scene.pushTextQuad(.{ .bounds = Rect.init(0.0, 0.0, 20.0, 10.0), .color = .text });
    try std.testing.expectEqual(@as(f32, 5.0), scene.commandAt(0).?.rect.bounds.x);
    try std.testing.expectEqual(@as(f32, 10.0), scene.commandAt(0).?.rect.bounds.w);
    try std.testing.expectEqual(@as(f32, 5.0), scene.commandAt(0).?.rect.radius);
    try std.testing.expectEqual(@as(f32, 0.25), scene.commandAt(1).?.text_quad.u0);
    try std.testing.expectEqual(@as(f32, 0.75), scene.commandAt(1).?.text_quad.u1);
    scene.popClip();

    scene.clear();
    try scene.pushDragSource(.{ .scope_id = 9, .item_id = 1, .index = 0, .bounds = Rect.init(0.0, 0.0, 10.0, 10.0) });
    try scene.pushDragSource(.{ .scope_id = 9, .item_id = 2, .index = 1, .bounds = Rect.init(0.0, 0.0, 10.0, 10.0) });
    try scene.pushDropTarget(.{ .scope_id = 9, .index = 0, .bounds = Rect.init(0.0, 0.0, 10.0, 10.0) });
    try scene.pushDropTarget(.{ .scope_id = 9, .index = 1, .bounds = Rect.init(0.0, 0.0, 10.0, 10.0) });
    try std.testing.expectEqual(@as(u32, 2), scene.commandAt(1).?.drag_source.item_id);
    try std.testing.expectEqual(@as(usize, 1), scene.commandAt(3).?.drop_target.index);
}

test "scene wrapped text emits bounded deterministic lines" {
    var commands: [8]Command = undefined;
    var scene = Scene.init(&commands);
    try scene.pushWrappedText(Rect.init(0.0, 0.0, 72.0, 72.0), "identity routed apps render their own docs", .text, .{
        .line_height = 18.0,
        .average_char_width = 9.0,
        .max_lines = 4,
    });

    try std.testing.expectEqual(@as(usize, 4), scene.commandCount());
    try std.testing.expectEqualStrings("identity", scene.commandAt(0).?.text.value);
    try std.testing.expectEqualStrings("routed", scene.commandAt(1).?.text.value);
    try std.testing.expectEqualStrings("apps", scene.commandAt(2).?.text.value);
    try std.testing.expectEqual(@as(f32, 54.0), scene.commandAt(3).?.text.origin.y);
}

test "scene wrapped text splits long words and clips line count to height" {
    var commands: [8]Command = undefined;
    var scene = Scene.init(&commands);
    try scene.pushWrappedText(Rect.init(0.0, 0.0, 36.0, 36.0), "superlongword", .text, .{
        .line_height = 18.0,
        .average_char_width = 9.0,
        .max_lines = 8,
    });

    try std.testing.expectEqual(@as(usize, 2), scene.commandCount());
    try std.testing.expectEqualStrings("supe", scene.commandAt(0).?.text.value);
    try std.testing.expectEqualStrings("rlon", scene.commandAt(1).?.text.value);
}

test "linear cursor lays out row and column slots" {
    var row = LinearCursor.init(Rect.init(10.0, 20.0, 100.0, 30.0), .row, 4.0);
    const first = row.take(20.0);
    const second = row.take(30.0);
    const remaining = row.remaining();

    try std.testing.expectEqual(Rect.init(10.0, 20.0, 20.0, 30.0), first);
    try std.testing.expectEqual(Rect.init(34.0, 20.0, 30.0, 30.0), second);
    try std.testing.expectEqual(Rect.init(68.0, 20.0, 42.0, 30.0), remaining);

    var column = LinearCursor.init(Rect.init(4.0, 8.0, 40.0, 80.0), .column, 6.0);
    const top = column.take(18.0);
    column.skip(10.0);
    const bottom = column.take(12.0);

    try std.testing.expectEqual(Rect.init(4.0, 8.0, 40.0, 18.0), top);
    try std.testing.expectEqual(Rect.init(4.0, 48.0, 40.0, 12.0), bottom);
}

fn firstText(commands: []const Command) ?Command {
    for (commands) |command| switch (command) {
        .text => return command,
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
    try scene.pushIconQuad(.{ .bounds = Rect.init(1.0, 2.0, 4.0, 4.0), .icon_id = 1, .color = .text });

    scene.applyOpacitySince(mark, 0.5);
    scene.translateSince(mark, 3.0, 4.0);

    try std.testing.expectEqual(@as(f32, 0.0), scene.commandAt(0).?.rect.bounds.x);
    try std.testing.expectEqual(@as(u8, 255), scene.commandAt(0).?.rect.color.a);
    try std.testing.expectEqual(@as(f32, 4.0), scene.commandAt(1).?.rect.bounds.x);
    try std.testing.expectEqual(@as(f32, 6.0), scene.commandAt(1).?.rect.bounds.y);
    try std.testing.expectEqual(@as(u8, 128), scene.commandAt(1).?.rect.color.a);
    try std.testing.expectEqual(@as(f32, 4.0), scene.commandAt(2).?.icon_quad.bounds.x);
    try std.testing.expectEqual(@as(u8, 128), scene.commandAt(2).?.icon_quad.color.a);

    try std.testing.expectEqual(@as(f32, 0.25), easingSample(.linear, 0.25));
    try std.testing.expectEqual(@as(f32, 0.25), easingSample(.ease_in, 0.5));
    try std.testing.expectEqual(@as(f32, 0.75), easingSample(.ease_out, 0.5));
    try std.testing.expectEqual(@as(f32, 0.5), easingSample(.ease_in_out, 0.5));

    try scene.pushTransition(transitionOpacity(1, 0.0, 1.0, 0));
    try scene.pushTransition(transitionTranslateY(2, -8.0, 0.0, 120));
    try std.testing.expectEqual(@as(usize, 1), scene.stats().transitions);

    const violation = firstBudgetViolation(.{ .rects = 10 }, .{ .rects = 8 }).?;
    try std.testing.expectEqualStrings("rects", violation.name);
    try std.testing.expectEqual(@as(usize, 10), violation.actual);
    try std.testing.expectEqual(@as(usize, 8), violation.limit);
    try std.testing.expect(!statsFitBudget(.{ .rects = 10 }, .{ .rects = 8 }));
    try std.testing.expect(statsFitBudget(.{ .rects = 10 }, frameBudget()));
}
