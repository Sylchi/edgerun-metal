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

pub const Size = struct { w: f32, h: f32 };
pub const Axis = enum { row, column };
pub const Align = enum { start, center, end, stretch };

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

pub const HitKind = enum(u8) { button, input, row_item, checkbox, switch_control, slider, textarea, select };
pub const RectMode = enum(u8) { fill, shadow, border, linear_gradient, pie_slice };
pub const TextAlign = enum(u8) { start, center, end };
pub const FontWeight = enum(u8) { regular = 0, semibold = 1, bold = 2 };

pub const DragSource = struct { scope_id: u32, item_id: u32, index: usize, bounds: Rect };
pub const DropTarget = struct { scope_id: u32, index: usize, bounds: Rect };

pub const Quad = struct {
    bounds: Rect,
    u0: f32 = 0.0,
    v0: f32 = 0.0,
    u1: f32 = 1.0,
    v1: f32 = 1.0,
    atlas_id: u32 = 0,
    color: Color,
};

pub const IconQuad = struct { bounds: Rect, icon_id: u32, color: Color };
pub const TransitionProperty = enum(u8) { opacity, translate_x, translate_y };
pub const Easing = enum(u8) { linear, ease_in, ease_out, ease_in_out };

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
    text: struct { origin: Rect, value: []const u8, color: Color, alignment: TextAlign = .start, weight: FontWeight = .regular },
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
    weight: FontWeight = .regular,
};

pub const Cursor = struct { commands: usize = 0 };
pub const Stats = struct { rects: usize = 0, drag_sources: usize = 0, drop_targets: usize = 0, transitions: usize = 0, clips: usize = 0, icon_quads: usize = 0, text_quads: usize = 0, image_quads: usize = 0 };
pub const Budget = struct { rects: usize = 2000, drag_sources: usize = 240, drop_targets: usize = 240, transitions: usize = 1200, icon_quads: usize = 160, text_quads: usize = 900, image_quads: usize = 16 };
pub const BudgetViolation = struct { name: []const u8, actual: usize, limit: usize };
pub const RenderError = error{ CommandBudgetExceeded, InvalidBounds, ClipBudgetExceeded, UnsupportedComponent };
pub const PatchError = error{ WrongNodeKind };

pub const CommandList = bounded.SliceList(Command);
pub const ClipList = bounded.SliceList(Rect);

pub const Scene = struct {
    commands: CommandList,
    clips: ClipList,

    pub fn init(commands: []Command) Scene { return .{ .commands = CommandList.from(commands), .clips = ClipList.from(&.{}) }; }
    pub fn initWithClips(commands: []Command, clips: []Rect) Scene { return .{ .commands = CommandList.from(commands), .clips = ClipList.from(clips) }; }
    pub fn clear(self: *Scene) void { self.commands.clear(); self.clips.clear(); }
    pub fn push(self: *Scene, command: Command) RenderError!void { if (!self.commands.append(command)) return error.CommandBudgetExceeded; }

    pub fn pushRect(self: *Scene, bounds: Rect, color: Color, mode: RectMode, radius: f32, shadow: f32) RenderError!void { try self.pushRectPair(bounds, color, .clear, mode, radius, shadow); }
    pub fn pushGradientRect(self: *Scene, bounds: Rect, top_color: Color, bottom_color: Color, radius: f32) RenderError!void { try self.pushRectPair(bounds, top_color, bottom_color, .linear_gradient, radius, 0.0); }

    pub fn pushPieSlice(self: *Scene, bounds: Rect, color: Color, start_turn: f32, end_turn: f32) RenderError!void {
        if (!geometry.finite(start_turn) or !geometry.finite(end_turn)) return;
        if (end_turn <= start_turn) return;
        const encoded_angles = Color{ .r = unitByte(start_turn), .g = unitByte(end_turn), .b = 0, .a = 255 };
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
        if (self.clipRect(source.bounds)) |clipped| try self.push(.{ .drag_source = .{ .scope_id = source.scope_id, .item_id = source.item_id, .index = source.index, .bounds = clipped } });
    }

    pub fn pushDropTarget(self: *Scene, target: DropTarget) RenderError!void {
        if (self.clipRect(target.bounds)) |clipped| try self.push(.{ .drop_target = .{ .scope_id = target.scope_id, .index = target.index, .bounds = clipped } });
    }

    pub fn pushTransition(self: *Scene, value: Transition) RenderError!void { if (!value.valid()) return; try self.push(.{ .transition = value }); }

    pub fn pushIconQuad(self: *Scene, quad: IconQuad) RenderError!void {
        if (quad.icon_id == 0) return;
        if (self.clipRect(quad.bounds)) |clipped| try self.push(.{ .icon_quad = .{ .bounds = clipped, .icon_id = quad.icon_id, .color = quad.color } });
    }

    pub fn pushTextQuad(self: *Scene, quad: Quad) RenderError!void { if (self.clipQuad(quad)) |clipped| try self.push(.{ .text_quad = clipped }); }
    pub fn pushImageQuad(self: *Scene, quad: Quad) RenderError!void { if (self.clipQuad(quad)) |clipped| try self.push(.{ .image_quad = clipped }); }

    pub fn pushText(self: *Scene, origin: Rect, value: []const u8, color: Color) RenderError!void { try self.pushAlignedText(origin, value, color, .start); }
    pub fn pushStrongText(self: *Scene, origin: Rect, value: []const u8, color: Color) RenderError!void { try self.pushAlignedTextWeight(origin, value, color, .start, .semibold); }
    pub fn pushBoldText(self: *Scene, origin: Rect, value: []const u8, color: Color) RenderError!void { try self.pushAlignedTextWeight(origin, value, color, .start, .bold); }
    pub fn pushAlignedText(self: *Scene, origin: Rect, value: []const u8, color: Color, alignment: TextAlign) RenderError!void { try self.pushAlignedTextWeight(origin, value, color, alignment, .regular); }

    pub fn pushAlignedTextWeight(self: *Scene, origin: Rect, value: []const u8, color: Color, alignment: TextAlign, weight: FontWeight) RenderError!void {
        if (value.len == 0) return;
        if (self.clipRect(origin)) |clipped| try self.push(.{ .text = .{ .origin = clipped, .value = value, .color = color, .alignment = alignment, .weight = weight } });
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
            if (split.end > split.start) try self.pushAlignedTextWeight(.{ .x = bounds.x, .y = bounds.y + @as(f32, @floatFromInt(line_index)) * wrap.line_height, .w = bounds.w, .h = wrap.line_height }, value[split.start..split.end], color, .start, wrap.weight);
            byte_cursor = split.next;
        }
    }

    pub fn pushClip(self: *Scene, clip: Rect) RenderError!bool {
        if (!clip.valid()) return false;
        const next = if (self.currentClip()) |current| current.intersect(clip) orelse return false else clip;
        if (!self.clips.append(next)) return error.ClipBudgetExceeded;
        return true;
    }

    pub fn popClip(self: *Scene) void { _ = self.clips.pop(); }
    pub fn cursor(self: Scene) Cursor { return .{ .commands = self.commands.len }; }

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

    fn currentClip(self: Scene) ?Rect { if (self.clips.len == 0) return null; return self.clips.items[self.clips.len - 1]; }
    fn clipRect(self: Scene, bounds: Rect) ?Rect { if (!bounds.valid()) return null; return if (self.currentClip()) |clip| bounds.intersect(clip) else bounds; }

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
        return .{ .bounds = clipped_bounds, .u0 = quad.u0 + u_span * left, .v0 = quad.v0 + v_span * top, .u1 = quad.u0 + u_span * right, .v1 = quad.v0 + v_span * bottom, .atlas_id = quad.atlas_id, .color = quad.color };
    }

    pub fn written(self: Scene) []const Command { return self.commands.slice(); }
    pub fn commandCount(self: Scene) usize { return self.commands.len; }
    pub fn commandAt(self: Scene, index: usize) ?Command { return self.commands.at(index); }
};

pub fn frameBudget() Budget { return .{}; }

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
    for (entries) |entry| if (entry.actual > entry.limit) return entry;
    return null;
}

pub fn statsFitBudget(stats_value: Stats, budget: Budget) bool { return firstBudgetViolation(stats_value, budget) == null; }

fn normalizeRect(bounds: *Rect, radius: *f32, shadow: *f32) bool {
    if (!bounds.valid() or !geometry.finite(radius.*) or !geometry.finite(shadow.*)) return false;
    radius.* = geometry.clamp(radius.*, 0.0, @min(bounds.w * 0.5, bounds.h * 0.5));
    shadow.* = geometry.max(shadow.*, 0.0);
    return true;
}

fn translateRect(bounds: *Rect, dx: f32, dy: f32) void { bounds.x += dx; bounds.y += dy; }
fn scaleAlpha(alpha: u8, factor: f32) u8 { return @intFromFloat(@round(@as(f32, @floatFromInt(alpha)) * factor)); }

fn unitByte(value: f32) u8 { return @intFromFloat(@round(geometry.clamp(value, 0.0, 1.0) * 255.0)); }

fn skipAsciiSpace(value: []const u8, start: usize) usize {
    var index = start;
    while (index < value.len and value[index] == ' ') : (index += 1) {}
    return index;
}

const WrappedLine = struct { start: usize, end: usize, next: usize };

fn wrappedLine(value: []const u8, start: usize, char_capacity: usize) WrappedLine {
    var index = start;
    var chars: usize = 0;
    var last_space: ?usize = null;
    while (index < value.len and value[index] != '\n' and chars < char_capacity) : (index += 1) {
        if (value[index] == ' ') last_space = index;
        chars += 1;
    }
    if (index >= value.len or value[index] == '\n') return .{ .start = start, .end = index, .next = @min(value.len, index + 1) };
    if (last_space) |space| return .{ .start = start, .end = space, .next = space + 1 };
    return .{ .start = start, .end = index, .next = index };
}

pub fn utf8CodepointCount(value: []const u8) usize {
    var count: usize = 0;
    var index: usize = 0;
    while (index < value.len) : (count += 1) {
        const len = std.unicode.utf8ByteSequenceLength(value[index]) catch 1;
        index += @min(len, value.len - index);
    }
    return count;
}
