const std = @import("std");
const icon = @import("icon.zig");
const ui = @import("ui.zig");
const interaction = @import("ui_interaction.zig");
const layout = @import("layouts/Types.zig");

pub const Error = error{
    Corrupt,
    UnsupportedComponent,
    ComponentBudgetExceeded,
    ChildMismatch,
};

pub const HtmlError = error{
    HtmlBudgetExceeded,
    InvalidHtml,
    UnsupportedHtml,
};

pub const MarkdownError = error{
    MarkdownBudgetExceeded,
    InvalidMarkdown,
    UnsupportedMarkdown,
};

pub const RegistryError = error{
    ComponentRegistryFull,
    DuplicateComponent,
    UnknownComponent,
};

pub const ButtonVariant = enum {
    primary,
    outline,
    ghost,
};

pub const BadgeVariant = enum {
    accent,
    neutral,
    danger,
};

pub const SurfaceVariant = enum {
    panel,
    elevated,
    subtle,
};

pub const RenderOptions = struct {
    style: ui.Style = .{},
    button_variant: ButtonVariant = .primary,
    button_leading_icon: ?icon.Icon = null,
    button_trailing_icon: ?icon.Icon = null,
    badge_variant: BadgeVariant = .accent,
    surface_variant: SurfaceVariant = .panel,
};

pub const ComponentDescriptor = struct {
    name: []const u8,
    html_prefix: []const u8,
    markdown_prefix: []const u8,
    render: *const fn (component: *const anyopaque, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void,
    collect_interactions: ?*const fn (component: *const anyopaque, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void = null,
    write_html: *const fn (component: *const anyopaque, out: []u8) HtmlError![]u8,
    write_markdown: *const fn (component: *const anyopaque, out: []u8) MarkdownError![]u8,
};

pub const ComponentRegistry = struct {
    entries: []ComponentDescriptor,
    len: usize = 0,

    pub fn init(entries: []ComponentDescriptor) ComponentRegistry {
        return .{ .entries = entries };
    }

    pub fn register(self: *ComponentRegistry, descriptor: ComponentDescriptor) RegistryError!void {
        if (self.findIndex(descriptor.name) != null) return error.DuplicateComponent;
        if (self.len == self.entries.len) return error.ComponentRegistryFull;
        self.entries[self.len] = descriptor;
        self.len += 1;
    }

    pub fn update(self: *ComponentRegistry, descriptor: ComponentDescriptor) RegistryError!void {
        const index = self.findIndex(descriptor.name) orelse return error.UnknownComponent;
        self.entries[index] = descriptor;
    }

    pub fn get(self: ComponentRegistry, name: []const u8) RegistryError!ComponentDescriptor {
        const index = self.findIndex(name) orelse return error.UnknownComponent;
        return self.entries[index];
    }

    pub fn render(self: ComponentRegistry, name: []const u8, component: *const anyopaque, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) (RegistryError || ui.RenderError)!void {
        const descriptor = try self.get(name);
        return descriptor.render(component, scene, bounds, options);
    }

    pub fn collectInteractions(self: ComponentRegistry, name: []const u8, component: *const anyopaque, collector: *interaction.Collector, bounds: ui.Rect) (RegistryError || interaction.Error)!void {
        const descriptor = try self.get(name);
        if (descriptor.collect_interactions) |collect| {
            return collect(component, collector, bounds);
        }
    }

    pub fn writeHtml(self: ComponentRegistry, name: []const u8, component: *const anyopaque, out: []u8) (RegistryError || HtmlError)![]u8 {
        const descriptor = try self.get(name);
        return descriptor.write_html(component, out);
    }

    pub fn writeMarkdown(self: ComponentRegistry, name: []const u8, component: *const anyopaque, out: []u8) (RegistryError || MarkdownError)![]u8 {
        const descriptor = try self.get(name);
        return descriptor.write_markdown(component, out);
    }

    pub fn matchHtml(self: ComponentRegistry, html: []const u8) ?ComponentDescriptor {
        for (self.entries[0..self.len]) |descriptor| {
            if (std.mem.startsWith(u8, html, descriptor.html_prefix)) return descriptor;
        }
        return null;
    }

    pub fn matchMarkdown(self: ComponentRegistry, markdown: []const u8) ?ComponentDescriptor {
        for (self.entries[0..self.len]) |descriptor| {
            if (std.mem.startsWith(u8, markdown, descriptor.markdown_prefix)) return descriptor;
        }
        return null;
    }

    fn findIndex(self: ComponentRegistry, name: []const u8) ?usize {
        for (self.entries[0..self.len], 0..) |descriptor, index| {
            if (std.mem.eql(u8, descriptor.name, name)) return index;
        }
        return null;
    }
};

pub fn registerDescriptor(registry: *ComponentRegistry, descriptor: ComponentDescriptor) RegistryError!void {
    return registry.register(descriptor);
}

pub fn renderNode(scene: *ui.Scene, bounds: ui.Rect, node: ui.Node, options: RenderOptions) ui.RenderError!void {
    return ui.render(scene, node, bounds, options.style);
}

pub fn measureNode(node: ui.Node, constraints: layout.Constraints) layout.Measurement {
    const size = node.preferredSize();
    return layout.Measurement.flexible(
        .{ .w = @min(size.w, constraints.width.limit(size.w)), .h = @min(size.h, constraints.height.limit(size.h)) },
        size,
        .{ .w = node_measure_max_width, .h = size.h },
    ).applyExact(constraints);
}

pub fn collectHit(collector: *interaction.Collector, bounds: ui.Rect, kind: ui.HitKind, id: u32) interaction.Error!void {
    return collector.addHit(bounds, kind, id);
}

const node_measure_max_width: f32 = 4096.0;

pub fn renderAdapter(
    comptime Component: type,
    comptime renderFn: fn (Component, *ui.Scene, ui.Rect, RenderOptions) ui.RenderError!void,
) *const fn (*const anyopaque, *ui.Scene, ui.Rect, RenderOptions) ui.RenderError!void {
    return struct {
        fn call(component: *const anyopaque, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
            const typed: *const Component = @ptrCast(@alignCast(component));
            return renderFn(typed.*, scene, bounds, options);
        }
    }.call;
}

pub fn collectAdapter(
    comptime Component: type,
    comptime collectFn: fn (Component, *interaction.Collector, ui.Rect) interaction.Error!void,
) *const fn (*const anyopaque, *interaction.Collector, ui.Rect) interaction.Error!void {
    return struct {
        fn call(component: *const anyopaque, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
            const typed: *const Component = @ptrCast(@alignCast(component));
            return collectFn(typed.*, collector, bounds);
        }
    }.call;
}

pub fn writeHtmlAdapter(
    comptime Component: type,
    comptime writeFn: fn (Component, []u8) HtmlError![]u8,
) *const fn (*const anyopaque, []u8) HtmlError![]u8 {
    return struct {
        fn call(component: *const anyopaque, out: []u8) HtmlError![]u8 {
            const typed: *const Component = @ptrCast(@alignCast(component));
            return writeFn(typed.*, out);
        }
    }.call;
}

pub fn writeMarkdownAdapter(
    comptime Component: type,
    comptime writeFn: fn (Component, []u8) MarkdownError![]u8,
) *const fn (*const anyopaque, []u8) MarkdownError![]u8 {
    return struct {
        fn call(component: *const anyopaque, out: []u8) MarkdownError![]u8 {
            const typed: *const Component = @ptrCast(@alignCast(component));
            return writeFn(typed.*, out);
        }
    }.call;
}

pub const HtmlWriter = struct {
    out: []u8,
    len: usize = 0,

    pub fn init(out: []u8) HtmlWriter {
        return .{ .out = out };
    }

    pub fn written(self: HtmlWriter) []u8 {
        return self.out[0..self.len];
    }

    pub fn writeAll(self: *HtmlWriter, value: []const u8) HtmlError!void {
        if (self.len + value.len > self.out.len) return error.HtmlBudgetExceeded;
        @memcpy(self.out[self.len .. self.len + value.len], value);
        self.len += value.len;
    }

    pub fn writeInt(self: *HtmlWriter, value: u32) HtmlError!void {
        var buf: [10]u8 = undefined;
        const text = std.fmt.bufPrint(&buf, "{d}", .{value}) catch unreachable;
        try self.writeAll(text);
    }

    pub fn writeBool(self: *HtmlWriter, value: bool) HtmlError!void {
        try self.writeAll(boolName(value));
    }

    pub fn writeAttrInt(self: *HtmlWriter, name: []const u8, value: u32) HtmlError!void {
        try self.writeAttrPrefix(name);
        try self.writeInt(value);
        try self.writeByte('"');
    }

    pub fn writeAttrBool(self: *HtmlWriter, name: []const u8, value: bool) HtmlError!void {
        try self.writeAttrPrefix(name);
        try self.writeBool(value);
        try self.writeByte('"');
    }

    pub fn writeAttrText(self: *HtmlWriter, name: []const u8, value: []const u8) HtmlError!void {
        try self.writeAttrPrefix(name);
        try self.writeEscapedAttr(value);
        try self.writeByte('"');
    }

    pub fn writeAttrRaw(self: *HtmlWriter, name: []const u8, value: []const u8) HtmlError!void {
        try self.writeAttrPrefix(name);
        try self.writeAll(value);
        try self.writeByte('"');
    }

    pub fn writeEscapedText(self: *HtmlWriter, value: []const u8) HtmlError!void {
        for (value) |byte| {
            switch (byte) {
                '&' => try self.writeAll("&amp;"),
                '<' => try self.writeAll("&lt;"),
                '>' => try self.writeAll("&gt;"),
                else => try self.writeByte(byte),
            }
        }
    }

    pub fn writeEscapedAttr(self: *HtmlWriter, value: []const u8) HtmlError!void {
        for (value) |byte| {
            switch (byte) {
                '&' => try self.writeAll("&amp;"),
                '<' => try self.writeAll("&lt;"),
                '>' => try self.writeAll("&gt;"),
                '"' => try self.writeAll("&quot;"),
                else => try self.writeByte(byte),
            }
        }
    }

    pub fn writeByte(self: *HtmlWriter, byte: u8) HtmlError!void {
        if (self.len == self.out.len) return error.HtmlBudgetExceeded;
        self.out[self.len] = byte;
        self.len += 1;
    }

    fn writeAttrPrefix(self: *HtmlWriter, name: []const u8) HtmlError!void {
        try self.writeByte(' ');
        try self.writeAll(name);
        try self.writeAll("=\"");
    }
};

pub const HtmlTextArena = struct {
    out: []u8,
    len: usize = 0,

    pub fn init(out: []u8) HtmlTextArena {
        return .{ .out = out };
    }

    pub fn unescape(self: *HtmlTextArena, value: []const u8) HtmlError![]const u8 {
        const start = self.len;
        var index: usize = 0;
        while (index < value.len) {
            if (value[index] != '&') {
                try self.append(value[index]);
                index += 1;
                continue;
            }
            if (std.mem.startsWith(u8, value[index..], "&amp;")) {
                try self.append('&');
                index += "&amp;".len;
            } else if (std.mem.startsWith(u8, value[index..], "&lt;")) {
                try self.append('<');
                index += "&lt;".len;
            } else if (std.mem.startsWith(u8, value[index..], "&gt;")) {
                try self.append('>');
                index += "&gt;".len;
            } else if (std.mem.startsWith(u8, value[index..], "&quot;")) {
                try self.append('"');
                index += "&quot;".len;
            } else {
                return error.InvalidHtml;
            }
        }
        return self.out[start..self.len];
    }

    fn append(self: *HtmlTextArena, byte: u8) HtmlError!void {
        if (self.len == self.out.len) return error.HtmlBudgetExceeded;
        self.out[self.len] = byte;
        self.len += 1;
    }
};

pub const HtmlCursor = struct {
    body: []const u8,
    cursor: usize = 0,

    pub fn init(body: []const u8) HtmlCursor {
        return .{ .body = body };
    }

    pub fn done(self: HtmlCursor) bool {
        return self.cursor >= self.body.len;
    }

    pub fn requirePrefix(self: HtmlCursor, prefix: []const u8) HtmlError!usize {
        if (!std.mem.startsWith(u8, self.body[self.cursor..], prefix)) return error.InvalidHtml;
        return self.cursor + prefix.len;
    }

    pub fn fieldBetween(self: *HtmlCursor, prefix: []const u8, next_prefix: []const u8) HtmlError![]const u8 {
        const value_start = try self.requirePrefix(prefix);
        const value_end_relative = std.mem.indexOf(u8, self.body[value_start..], next_prefix) orelse return error.InvalidHtml;
        self.cursor = value_start + value_end_relative;
        return self.body[value_start..self.cursor];
    }

    pub fn consume(self: *HtmlCursor, value: []const u8) HtmlError!void {
        self.cursor = try self.requirePrefix(value);
    }
};

pub const MarkdownWriter = struct {
    out: []u8,
    len: usize = 0,

    pub fn init(out: []u8) MarkdownWriter {
        return .{ .out = out };
    }

    pub fn written(self: MarkdownWriter) []u8 {
        return self.out[0..self.len];
    }

    pub fn writeAll(self: *MarkdownWriter, value: []const u8) MarkdownError!void {
        if (self.len + value.len > self.out.len) return error.MarkdownBudgetExceeded;
        @memcpy(self.out[self.len .. self.len + value.len], value);
        self.len += value.len;
    }

    pub fn writeInt(self: *MarkdownWriter, value: u32) MarkdownError!void {
        var buf: [10]u8 = undefined;
        const text = std.fmt.bufPrint(&buf, "{d}", .{value}) catch unreachable;
        try self.writeAll(text);
    }

    pub fn beginDirective(self: *MarkdownWriter, name: []const u8) MarkdownError!void {
        try self.writeAll(":::");
        try self.writeAll(name);
    }

    pub fn endDirective(self: *MarkdownWriter) MarkdownError!void {
        try self.writeAll("\n:::");
    }

    pub fn fieldInt(self: *MarkdownWriter, name: []const u8, value: u32) MarkdownError!void {
        try self.fieldPrefix(name);
        try self.writeInt(value);
    }

    pub fn fieldBool(self: *MarkdownWriter, name: []const u8, value: bool) MarkdownError!void {
        try self.fieldPrefix(name);
        try self.writeAll(boolName(value));
    }

    pub fn fieldText(self: *MarkdownWriter, name: []const u8, value: []const u8) MarkdownError!void {
        try self.fieldPrefix(name);
        try self.writeEscapedInline(value);
    }

    pub fn fieldRaw(self: *MarkdownWriter, name: []const u8, value: []const u8) MarkdownError!void {
        try self.fieldPrefix(name);
        try self.writeAll(value);
    }

    pub fn fieldPrefix(self: *MarkdownWriter, name: []const u8) MarkdownError!void {
        try self.writeByte('\n');
        try self.writeAll(name);
        try self.writeAll(": ");
    }

    pub fn writeEscapedInline(self: *MarkdownWriter, value: []const u8) MarkdownError!void {
        for (value) |byte| {
            switch (byte) {
                '\n', '\r' => return error.InvalidMarkdown,
                '\\', '`', '*', '_', '{', '}', '[', ']', '(', ')', '#', '+', '-', '.', '!', '>', '|', ':' => {
                    try self.writeByte('\\');
                    try self.writeByte(byte);
                },
                else => try self.writeByte(byte),
            }
        }
    }

    pub fn writeByte(self: *MarkdownWriter, byte: u8) MarkdownError!void {
        if (self.len == self.out.len) return error.MarkdownBudgetExceeded;
        self.out[self.len] = byte;
        self.len += 1;
    }
};

pub const MarkdownTextArena = struct {
    out: []u8,
    len: usize = 0,

    pub fn init(out: []u8) MarkdownTextArena {
        return .{ .out = out };
    }

    pub fn unescapeInline(self: *MarkdownTextArena, value: []const u8) MarkdownError![]const u8 {
        const start = self.len;
        var index: usize = 0;
        while (index < value.len) {
            const byte = value[index];
            if (byte == '\n' or byte == '\r') return error.InvalidMarkdown;
            if (byte != '\\') {
                try self.append(byte);
                index += 1;
                continue;
            }
            index += 1;
            if (index == value.len or !markdownEscapable(value[index])) return error.InvalidMarkdown;
            try self.append(value[index]);
            index += 1;
        }
        return self.out[start..self.len];
    }

    fn append(self: *MarkdownTextArena, byte: u8) MarkdownError!void {
        if (self.len == self.out.len) return error.MarkdownBudgetExceeded;
        self.out[self.len] = byte;
        self.len += 1;
    }
};

pub const MarkdownCursor = struct {
    body: []const u8,
    cursor: usize = 0,

    pub fn init(body: []const u8) MarkdownCursor {
        return .{ .body = body };
    }

    pub fn done(self: MarkdownCursor) bool {
        return self.cursor >= self.body.len;
    }

    pub fn requirePrefix(self: MarkdownCursor, prefix: []const u8) MarkdownError!usize {
        if (!std.mem.startsWith(u8, self.body[self.cursor..], prefix)) return error.InvalidMarkdown;
        return self.cursor + prefix.len;
    }

    pub fn lineAfter(self: *MarkdownCursor, prefix: []const u8) MarkdownError![]const u8 {
        const value_start = try self.requirePrefix(prefix);
        const value_end_relative = std.mem.indexOfScalar(u8, self.body[value_start..], '\n') orelse return error.InvalidMarkdown;
        self.cursor = value_start + value_end_relative;
        return self.body[value_start..self.cursor];
    }

    pub fn fieldBetween(self: *MarkdownCursor, prefix: []const u8, next_prefix: []const u8) MarkdownError![]const u8 {
        const value_start = try self.requirePrefix(prefix);
        const value_end_relative = std.mem.indexOf(u8, self.body[value_start..], next_prefix) orelse return error.InvalidMarkdown;
        self.cursor = value_start + value_end_relative;
        return self.body[value_start..self.cursor];
    }

    pub fn finalField(self: *MarkdownCursor, prefix: []const u8, next_record_prefix: []const u8) MarkdownError![]const u8 {
        const value_start = try self.requirePrefix(prefix);
        const value_end_relative = std.mem.indexOf(u8, self.body[value_start..], next_record_prefix) orelse self.body[value_start..].len;
        self.cursor = value_start + value_end_relative;
        return self.body[value_start..self.cursor];
    }

    pub fn tailField(self: *MarkdownCursor, prefix: []const u8) MarkdownError![]const u8 {
        const value_start = try self.requirePrefix(prefix);
        self.cursor = self.body.len;
        return self.body[value_start..];
    }

    pub fn skipNewline(self: *MarkdownCursor) MarkdownError!void {
        if (self.cursor == self.body.len) return;
        if (self.body[self.cursor] != '\n') return error.InvalidMarkdown;
        self.cursor += 1;
    }
};

pub fn takeWrapped(value: []const u8, prefix: []const u8, suffix: []const u8) ?[]const u8 {
    if (!std.mem.startsWith(u8, value, prefix)) return null;
    if (!std.mem.endsWith(u8, value, suffix)) return null;
    return value[prefix.len .. value.len - suffix.len];
}

pub fn readDirectiveBody(markdown: []const u8, prefix: []const u8) MarkdownError![]const u8 {
    if (!std.mem.endsWith(u8, markdown, "\n:::")) return error.InvalidMarkdown;
    const body_end = markdown.len - "\n:::".len;
    if (body_end < prefix.len) return error.InvalidMarkdown;
    return markdown[prefix.len..body_end];
}

pub fn readMarkdownDirectiveBody(markdown: []const u8, directive: []const u8, prefix: []const u8) MarkdownError![]const u8 {
    if (!std.mem.startsWith(u8, markdown, prefix)) {
        if (std.mem.startsWith(u8, markdown, directive)) return error.InvalidMarkdown;
        return error.UnsupportedMarkdown;
    }
    return readDirectiveBody(markdown, prefix);
}

pub fn alignName(alignment: ui.TextAlign) []const u8 {
    return switch (alignment) {
        .start => "start",
        .center => "center",
        .end => "end",
    };
}

pub fn parseAlignName(value: []const u8) ?ui.TextAlign {
    if (std.mem.eql(u8, value, "start")) return .start;
    if (std.mem.eql(u8, value, "center")) return .center;
    if (std.mem.eql(u8, value, "end")) return .end;
    return null;
}

pub fn boolName(value: bool) []const u8 {
    return switch (value) {
        true => "true",
        false => "false",
    };
}

pub fn parseHtmlU32(value: []const u8) HtmlError!u32 {
    return std.fmt.parseUnsigned(u32, value, 10) catch error.InvalidHtml;
}

pub fn parseHtmlU16(value: []const u8) HtmlError!u16 {
    return std.fmt.parseUnsigned(u16, value, 10) catch error.InvalidHtml;
}

pub fn parseHtmlBool(value: []const u8) HtmlError!bool {
    if (std.mem.eql(u8, value, "true")) return true;
    if (std.mem.eql(u8, value, "false")) return false;
    return error.InvalidHtml;
}

pub fn parseMarkdownU32(value: []const u8) MarkdownError!u32 {
    return std.fmt.parseUnsigned(u32, value, 10) catch error.InvalidMarkdown;
}

pub fn parseMarkdownU16(value: []const u8) MarkdownError!u16 {
    return std.fmt.parseUnsigned(u16, value, 10) catch error.InvalidMarkdown;
}

pub fn parseMarkdownBool(value: []const u8) MarkdownError!bool {
    if (std.mem.eql(u8, value, "true")) return true;
    if (std.mem.eql(u8, value, "false")) return false;
    return error.InvalidMarkdown;
}

pub fn axisName(axis: ui.Axis) []const u8 {
    return switch (axis) {
        .column => "column",
        .row => "row",
    };
}

pub fn parseAxisName(value: []const u8) ?ui.Axis {
    if (std.mem.eql(u8, value, "column")) return .column;
    if (std.mem.eql(u8, value, "row")) return .row;
    return null;
}

pub fn percentFromUnit(value: f32) u32 {
    return @intFromFloat(@round(ui.clampUnit(value) * 100.0));
}

pub fn parseHtmlPercent(value: []const u8) HtmlError!f32 {
    const parsed = try parseHtmlU32(value);
    if (parsed > 100) return error.InvalidHtml;
    return @as(f32, @floatFromInt(parsed)) / 100.0;
}

pub fn parseMarkdownPercent(value: []const u8) MarkdownError!f32 {
    const parsed = try parseMarkdownU32(value);
    if (parsed > 100) return error.InvalidMarkdown;
    return @as(f32, @floatFromInt(parsed)) / 100.0;
}

fn markdownEscapable(byte: u8) bool {
    return switch (byte) {
        '\\', '`', '*', '_', '{', '}', '[', ']', '(', ')', '#', '+', '-', '.', '!', '>', '|', ':' => true,
        else => false,
    };
}
