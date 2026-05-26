const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const icon = @import("../../icon.zig");
const interaction = @import("../../ui_interaction.zig");
const layout = @import("../../layouts/Types.zig");
const object = @import("../../object.zig");
const std = @import("std");
const ui = @import("../../ui.zig");
const text_metrics = @import("../../ui_text_metrics.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;
const constrainPreferredSize = primitives.constrainPreferredSize;
const measureFixed = primitives.measureFixed;

pub const Button = struct {
    id: u32,
    label: []const u8,
    variant: common.ButtonVariant = .primary,
    leading_icon: ?icon.Icon = null,
    trailing_icon: ?icon.Icon = null,

    pub fn node(self: Button) ui.Node {
        return ui.buttonDetailNode(self.id, self.label, variantTag(self.variant), common.optionalIconTag(self.leading_icon), common.optionalIconTag(self.trailing_icon));
    }

    pub fn render(self: Button, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return renderButton(scene, bounds, self, options);
    }

    pub fn collectInteractions(self: Button, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return collectButtonInteractions(collector, bounds, self);
    }

    pub fn measure(self: Button, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        return measureButtonWithSize(self.label, self.leading_icon, self.trailing_icon, options.control_size, constraints);
    }

    pub fn toObject(self: Button, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        var writer = component_codec.Writer.init(ui_out, 1, 1, .column, 0, 0) orelse return null;
        if (!self.writeRecord(&writer, 0)) return null;
        return writer.objectNode(object_out, component_codec.requirements(), epoch);
    }

    pub fn writeRecord(self: Button, writer: *component_codec.Writer, index: usize) bool {
        const label_ref = writer.string(self.label) orelse return false;
        return writer.record(index, .button, self.id, label_ref, .{ .offset = variantTag(self.variant), .len = packIconTags(self.leading_icon, self.trailing_icon) });
    }

    pub fn fromView(view: object.View) Error!Button {
        return switch (try component_codec.singleNode(view)) {
            .button => |button| .{ .id = button.id, .label = button.label, .variant = try variantFromTag(button.variant), .leading_icon = try common.optionalIconFromTag(button.leading_icon), .trailing_icon = try common.optionalIconFromTag(button.trailing_icon) },
            else => error.UnsupportedComponent,
        };
    }
};

pub const IconButton = struct {
    id: u32,
    label: []const u8,
    icon_value: icon.Icon,
    variant: common.ButtonVariant = .outline,

    pub fn node(self: IconButton) ui.Node {
        return ui.iconButtonNode(self.id, self.label, common.optionalIconTag(self.icon_value), variantTag(self.variant));
    }

    pub fn render(self: IconButton, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const paint = buttonPaint(self.variant, options);
        if (paint.fill) |fill| try scene.pushRect(bounds, fill, .fill, radius, 0.0);
        if (paint.border) |border| try scene.pushRect(bounds, border, .border, radius, 0.0);
        try scene.pushIconQuad(.{
            .bounds = iconButtonIconBounds(bounds),
            .icon_id = icon.id(self.icon_value),
            .color = paint.text,
        });
    }

    pub fn collectInteractions(self: IconButton, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try collector.addHit(bounds, .button, self.id);
    }

    pub fn measure(self: IconButton, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        const size = iconButtonSize(options.control_size);
        return measureFixed(.{ .w = size, .h = size }, constraints);
    }

    pub fn toObject(self: IconButton, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        var writer = component_codec.Writer.init(ui_out, 1, 1, .column, 0, 0) orelse return null;
        if (!self.writeRecord(&writer, 0)) return null;
        return writer.objectNode(object_out, component_codec.requirements(), epoch);
    }

    pub fn writeRecord(self: IconButton, writer: *component_codec.Writer, index: usize) bool {
        const label_ref = writer.string(self.label) orelse return false;
        return writer.record(index, .icon_button, self.id, label_ref, .{ .offset = variantTag(self.variant), .len = common.optionalIconTag(self.icon_value) });
    }

    pub fn fromView(view: object.View) Error!IconButton {
        return switch (try component_codec.singleNode(view)) {
            .icon_button => |button| .{ .id = button.id, .label = button.label, .variant = try variantFromTag(button.variant), .icon_value = (try common.optionalIconFromTag(button.icon)) orelse return error.Corrupt },
            else => error.UnsupportedComponent,
        };
    }
};

fn renderButton(scene: *ui.Scene, bounds: ui.Rect, button: Button, options: RenderOptions) ui.RenderError!void {
    const paint = buttonPaint(button.variant, options);
    if (paint.fill) |fill| try scene.pushRect(bounds, fill, .fill, radius, 0.0);
    if (paint.border) |border| try scene.pushRect(bounds, border, .border, radius, 0.0);
    try renderContent(scene, bounds, button.label, paint.text, button.leading_icon, button.trailing_icon, labelPadding(options.control_size));
}

pub fn variantTag(variant: common.ButtonVariant) u16 {
    return switch (variant) {
        .primary => 0,
        .secondary => 1,
        .outline => 2,
        .ghost => 3,
        .destructive => 4,
        .link => 5,
    };
}

pub fn variantFromTag(tag: u16) Error!common.ButtonVariant {
    return switch (tag) {
        0 => .primary,
        1 => .secondary,
        2 => .outline,
        3 => .ghost,
        4 => .destructive,
        5 => .link,
        else => error.Corrupt,
    };
}

fn packIconTags(leading: ?icon.Icon, trailing: ?icon.Icon) u16 {
    return common.optionalIconTag(leading) | (common.optionalIconTag(trailing) << icon_pack_shift);
}

fn collectButtonInteractions(collector: *interaction.Collector, bounds: ui.Rect, button: Button) interaction.Error!void {
    try collector.addHit(bounds, .button, button.id);
}

pub fn preferredWidth(label: []const u8, leading_icon: ?icon.Icon, trailing_icon: ?icon.Icon) f32 {
    return preferredWidthForSize(label, leading_icon, trailing_icon, .default);
}

pub fn preferredWidthForSize(label: []const u8, leading_icon: ?icon.Icon, trailing_icon: ?icon.Icon, size: common.ControlSize) f32 {
    const icon_count: usize = @as(usize, @intFromBool(leading_icon != null)) + @as(usize, @intFromBool(trailing_icon != null));
    return @max(minWidth(size), estimatedLabelWidth(label) + iconClusterWidth(icon_count, label.len != 0) + labelPadding(size) * 2.0);
}

fn measureButton(label: []const u8, leading_icon: ?icon.Icon, trailing_icon: ?icon.Icon, constraints: layout.Constraints) layout.Measurement {
    return measureButtonWithSize(label, leading_icon, trailing_icon, .default, constraints);
}

fn measureButtonWithSize(label: []const u8, leading_icon: ?icon.Icon, trailing_icon: ?icon.Icon, size: common.ControlSize, constraints: layout.Constraints) layout.Measurement {
    const preferred_width = preferredWidthForSize(label, leading_icon, trailing_icon, size);
    const preferred_height = buttonHeight(size);
    const preferred = constrainPreferredSize(.{ .w = preferred_width, .h = preferred_height }, constraints);
    return layout.Measurement.flexible(
        .{ .w = @min(minWidth(size), preferred.w), .h = @min(preferred_height, preferred.h) },
        preferred,
        .{ .w = max_width, .h = preferred_height },
    ).applyExact(constraints);
}

fn renderContent(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, text_color: ui.Color, leading_icon: ?icon.Icon, trailing_icon: ?icon.Icon, padding: f32) ui.RenderError!void {
    const has_leading = leading_icon != null;
    const has_trailing = trailing_icon != null;
    if (!has_leading and !has_trailing) {
        const text_bounds = textBounds(bounds, padding);
        try scene.pushAlignedText(text_bounds, text_metrics.fitPrefix(label, text_metrics.button_label_px, text_bounds.w), text_color, .center);
        return;
    }

    const has_label = label.len != 0;
    const icon_count: usize = @as(usize, @intFromBool(has_leading)) + @as(usize, @intFromBool(has_trailing));
    const margin = if (has_label) @min(padding, bounds.w * 0.5) else 0.0;
    const available_w = @max(1.0, bounds.w - margin * 2.0);
    const icons_w = iconClusterWidth(icon_count, has_label);
    const label_w = if (has_label) @max(1.0, @min(estimatedLabelWidth(label), @max(1.0, available_w - icons_w))) else 0.0;
    const visible_label = text_metrics.fitPrefix(label, text_metrics.button_label_px, label_w);
    const content_w = @min(available_w, label_w + icons_w);
    var cursor_x = bounds.x + margin + @max(0.0, (available_w - content_w) * 0.5);
    const icon_y = bounds.y + (bounds.h - icon_size) * 0.5;
    const text_y = bounds.y + (bounds.h - label_height) * 0.5;

    if (leading_icon) |value| {
        try scene.pushIconQuad(.{
            .bounds = ui.Rect.init(cursor_x, icon_y, icon_size, icon_size),
            .icon_id = icon.id(value),
            .color = text_color,
        });
        cursor_x += icon_size;
        if (has_label or has_trailing) cursor_x += icon_gap;
    }

    if (has_label) {
        try scene.pushAlignedText(ui.Rect.init(cursor_x, text_y, label_w, label_height), visible_label, text_color, .start);
        cursor_x += label_w;
        if (has_trailing) cursor_x += icon_gap;
    }

    if (trailing_icon) |value| {
        try scene.pushIconQuad(.{
            .bounds = ui.Rect.init(cursor_x, icon_y, icon_size, icon_size),
            .icon_id = icon.id(value),
            .color = text_color,
        });
    }
}

fn textBounds(bounds: ui.Rect, padding: f32) ui.Rect {
    const margin = @min(padding, bounds.w * 0.5);
    return ui.Rect.init(bounds.x + margin, bounds.y + (bounds.h - label_height) * 0.5, @max(1.0, bounds.w - margin * 2.0), label_height);
}

fn iconButtonIconBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x + (bounds.w - icon_size) * 0.5, bounds.y + (bounds.h - icon_size) * 0.5, icon_size, icon_size);
}

fn estimatedLabelWidth(label: []const u8) f32 {
    if (label.len == 0) return 0.0;
    return @max(label_min_width, text_metrics.width(label, text_metrics.button_label_px));
}

fn iconClusterWidth(icon_count: usize, has_label: bool) f32 {
    if (icon_count == 0) return 0.0;
    const icons_w = @as(f32, @floatFromInt(icon_count)) * icon_size;
    const internal_gaps = @as(f32, @floatFromInt(icon_count - 1)) * icon_gap;
    const label_gaps = if (has_label) @as(f32, @floatFromInt(icon_count)) * icon_gap else 0.0;
    return icons_w + internal_gaps + label_gaps;
}

const ButtonPaint = struct {
    fill: ?ui.Color = null,
    border: ?ui.Color = null,
    text: ui.Color,
};

fn buttonPaint(variant: common.ButtonVariant, options: RenderOptions) ButtonPaint {
    return switch (variant) {
        .primary => .{ .fill = options.style.accent, .border = options.style.accent, .text = options.style.bg },
        .secondary => .{ .fill = options.style.row, .border = options.style.border, .text = options.style.text },
        .outline => .{ .fill = options.style.panel, .border = options.style.border, .text = options.style.text },
        .ghost => .{ .fill = ui.Color.clear, .text = options.style.muted },
        .destructive => .{ .fill = button_danger, .border = button_danger, .text = button_danger_text },
        .link => .{ .text = options.style.accent },
    };
}

pub const radius: f32 = 7.0;
pub const height: f32 = 36.0;
pub const label_height: f32 = 17.0;
pub const label_padding: f32 = 16.0;

const label_min_width: f32 = 8.0;
const icon_size: f32 = 18.0;
const icon_gap: f32 = 8.0;
const min_width: f32 = 44.0;
const icon_button_size: f32 = 36.0;
const max_width: f32 = 4096.0;
const button_danger = ui.Color{ .r = 225, .g = 29, .b = 72 };
const button_danger_text = ui.Color{ .r = 255, .g = 255, .b = 255 };
const icon_pack_shift: u4 = 8;

fn buttonHeight(size: common.ControlSize) f32 {
    return switch (size) {
        .small => 32.0,
        .default => height,
        .large => 44.0,
    };
}

fn labelPadding(size: common.ControlSize) f32 {
    return switch (size) {
        .small => 12.0,
        .default => label_padding,
        .large => 20.0,
    };
}

fn minWidth(size: common.ControlSize) f32 {
    return switch (size) {
        .small => 36.0,
        .default => min_width,
        .large => 52.0,
    };
}

fn iconButtonSize(size: common.ControlSize) f32 {
    return switch (size) {
        .small => 32.0,
        .default => icon_button_size,
        .large => 44.0,
    };
}

test "button component serializes to canonical object and deserializes" {
    const button = Button{ .id = 7, .label = "Run", .variant = .secondary, .leading_icon = .search, .trailing_icon = .chevron_right };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = button.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Button.fromView(try object.View.decode(canonical));

    try @import("std").testing.expectEqual(@as(u32, 7), decoded.id);
    try @import("std").testing.expectEqualStrings("Run", decoded.label);
    try @import("std").testing.expectEqual(common.ButtonVariant.secondary, decoded.variant);
    try @import("std").testing.expectEqual(icon.Icon.search, decoded.leading_icon.?);
    try @import("std").testing.expectEqual(icon.Icon.chevron_right, decoded.trailing_icon.?);
}

test "icon button component serializes to canonical object and deserializes" {
    const button = IconButton{ .id = 17, .label = "Search", .icon_value = .search, .variant = .ghost };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = button.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try IconButton.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(@as(u32, 17), decoded.id);
    try std.testing.expectEqualStrings("Search", decoded.label);
    try std.testing.expectEqual(common.ButtonVariant.ghost, decoded.variant);
    try std.testing.expectEqual(icon.Icon.search, decoded.icon_value);
}

test "icon button component renders centered icon and hit region" {
    const button = IconButton{ .id = 18, .label = "Search", .icon_value = .search, .variant = .outline };
    var commands: [8]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [1]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);
    const bounds = ui.Rect.init(4, 8, icon_button_size, icon_button_size);

    try button.render(&scene, bounds, .{});
    try button.collectInteractions(&collector, bounds);

    const icon_command = component_test.iconCommand(scene.written(), icon.id(.search)).?;
    try std.testing.expectEqual(bounds.x + (bounds.w - icon_size) * 0.5, icon_command.icon_quad.bounds.x);
    try std.testing.expectEqual(bounds.y + (bounds.h - icon_size) * 0.5, icon_command.icon_quad.bounds.y);
    try std.testing.expectEqual(@as(usize, 1), collector.written().len);
    try std.testing.expectEqual(ui.HitKind.button, collector.written()[0].kind);
    try std.testing.expectEqual(@as(u32, 18), collector.written()[0].id);
}

test "button component measurement follows label width" {
    const short = measureButton("Go", null, null, .{});
    const long = measureButton("Continue lesson", null, null, .{});
    const with_icon = measureButton("Continue lesson", .search, .chevron_right, .{});
    const constrained = measureButton("Continue lesson", null, null, .{ .width = .{ .at_most = 72.0 }, .height = .{ .at_most = 24.0 } });

    try std.testing.expect(long.preferred.w > short.preferred.w);
    try std.testing.expect(with_icon.preferred.w > long.preferred.w);
    try std.testing.expectEqual(height, long.preferred.h);
    try std.testing.expectEqual(@as(f32, 72.0), constrained.preferred.w);
    try std.testing.expectEqual(@as(f32, 24.0), constrained.preferred.h);
}

test "button component size variants adjust preferred height and padding" {
    const button = Button{ .id = 7, .label = "Run" };
    const small = button.measure(.{}, .{ .control_size = .small });
    const regular = button.measure(.{}, .{});
    const large = button.measure(.{}, .{ .control_size = .large });
    const small_icon = (IconButton{ .id = 8, .label = "Search", .icon_value = .search }).measure(.{}, .{ .control_size = .small });
    const large_icon = (IconButton{ .id = 9, .label = "Search", .icon_value = .search }).measure(.{}, .{ .control_size = .large });

    try std.testing.expect(small.preferred.h < regular.preferred.h);
    try std.testing.expect(large.preferred.h > regular.preferred.h);
    try std.testing.expect(preferredWidthForSize("Run", null, null, .small) < preferredWidthForSize("Run", null, null, .large));
    try std.testing.expect(small_icon.preferred.w < large_icon.preferred.w);
    try std.testing.expect(small_icon.preferred.h < large_icon.preferred.h);
}

test "button component measurement uses font glyph widths" {
    const wide = measureButton("WWW", null, null, .{});
    const narrow = measureButton("iii", null, null, .{});

    try std.testing.expect(wide.preferred.w > narrow.preferred.w);
}

test "button component constrains icon label content to button bounds" {
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    const bounds = ui.Rect.init(10, 10, 72, height);

    try renderButton(&scene, bounds, .{ .id = 8, .label = "Impossible label", .variant = .secondary, .leading_icon = .search, .trailing_icon = .chevron_right }, .{});

    for (scene.written()) |command| switch (command) {
        .text => |text_command| {
            try std.testing.expect(text_command.origin.x >= bounds.x);
            try std.testing.expect(text_command.origin.x + text_command.origin.w <= bounds.x + bounds.w);
        },
        .icon_quad => |icon_command| {
            try std.testing.expect(icon_command.bounds.x >= bounds.x);
            try std.testing.expect(icon_command.bounds.x + icon_command.bounds.w <= bounds.x + bounds.w);
        },
        else => {},
    };
}

test "button component truncates overfull plain labels deterministically" {
    var commands: [8]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    const label = "WWWWWWWWWW";

    try renderButton(&scene, ui.Rect.init(0, 0, 72, height), .{ .id = 9, .label = label }, .{});

    const command = component_test.firstTextCommand(scene.written()).?.text;
    try std.testing.expect(command.value.len < label.len);
    try std.testing.expect(std.mem.startsWith(u8, label, command.value));
}

test "button component centers icon only content" {
    var commands: [8]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    const bounds = ui.Rect.init(10, 10, 44, height);

    try renderButton(&scene, bounds, .{ .id = 8, .label = "", .variant = .secondary, .leading_icon = .search }, .{});

    var found = false;
    for (scene.written()) |command| switch (command) {
        .icon_quad => |icon_command| {
            found = true;
            try std.testing.expectEqual(bounds.x + (bounds.w - icon_size) * 0.5, icon_command.bounds.x);
            try std.testing.expectEqual(bounds.y + (bounds.h - icon_size) * 0.5, icon_command.bounds.y);
        },
        .text => return error.UnexpectedText,
        else => {},
    };
    try std.testing.expect(found);
}

test "button component renders extended reference variants" {
    var commands: [32]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try renderButton(&scene, ui.Rect.init(0, 0, 120, height), .{ .id = 1, .label = "Delete", .variant = .destructive }, .{});
    try renderButton(&scene, ui.Rect.init(0, 44, 120, height), .{ .id = 2, .label = "Docs", .variant = .link, .leading_icon = .search }, .{});

    try std.testing.expect(component_test.hasRectColor(scene.written(), button_danger));
    try std.testing.expect(!component_test.hasRectBounds(scene.written(), ui.Rect.init(0, 44, 120, height)));
    try std.testing.expect(component_test.hasTextColor(scene.written(), ui.Color.accent));
    try std.testing.expect(component_test.hasIcon(scene.written(), icon.id(.search)));
}
