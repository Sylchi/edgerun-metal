const std = @import("std");
const icon = @import("icon.zig");
const ui = @import("ui.zig");

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

pub fn parseHtmlBool(value: []const u8) HtmlError!bool {
    if (std.mem.eql(u8, value, "true")) return true;
    if (std.mem.eql(u8, value, "false")) return false;
    return error.InvalidHtml;
}

pub fn parseMarkdownU32(value: []const u8) MarkdownError!u32 {
    return std.fmt.parseUnsigned(u32, value, 10) catch error.InvalidMarkdown;
}

pub fn parseMarkdownBool(value: []const u8) MarkdownError!bool {
    if (std.mem.eql(u8, value, "true")) return true;
    if (std.mem.eql(u8, value, "false")) return false;
    return error.InvalidMarkdown;
}

fn markdownEscapable(byte: u8) bool {
    return switch (byte) {
        '\\', '`', '*', '_', '{', '}', '[', ']', '(', ')', '#', '+', '-', '.', '!', '>', '|', ':' => true,
        else => false,
    };
}
