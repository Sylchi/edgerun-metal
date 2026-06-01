const clock = @import("../../clock.zig");
const common = @import("../component_common.zig");
const interaction = @import("../interaction.zig");
const layout = @import("../layouts/Types.zig");
const object = @import("../../object.zig");
const std = @import("std");
const ui = @import("../core.zig");
const text_component = @import("Text.zig");
const text_metrics = @import("../text_metrics.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const icon_component = @import("Icon.zig");
const icon_pack = @import("../icon_pack.zig");
const primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

const constrainPreferredSize = primitives.constrainPreferredSize;
const Icon = icon_component.Icon;
const IconSlot = icon_component.IconSlot;

pub const Button = struct {
    id: u32,
    label: []const u8,
    variant: common.ButtonVariant = .primary,
    icon_slot: IconSlot = .none,
    flags: common.ComponentFlags = .{},

    pub fn node(self: Button) ui.Node {
        const tags = iconSlotTags(self.icon_slot);
        return ui.buttonDetailNode(self.id, self.label, variantTag(self.variant), tags.leading, tags.trailing);
    }

    pub fn accessibility(self: Button) common.Accessibility {
        return .{ .role = .button, .label = self.label, .control_id = self.id };
    }

    pub fn render(self: Button, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return renderButton(scene, bounds, self, options);
    }

    pub fn collectInteractions(self: Button, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return collectButtonInteractions(collector, bounds, self);
    }

    pub fn measure(self: Button, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        return measureButtonWithSize(self.label, self.icon_slot, options.control_size, constraints);
    }

    pub fn toObject(self: Button, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.singleObjectFromRecord(@TypeOf(self), self, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Button, writer: *component_codec.Writer, index: usize) bool {
        const label_ref = writer.string(self.label) orelse return false;
        const tag = packIconSlot(self.icon_slot);
        const trailing: u16 = switch (self.icon_slot) {
            .trailing => trailing_button_flag,
            else => 0,
        };
        return writer.record(index, .button, self.id, label_ref, .{ .offset = tag, .len = variantTag(self.variant) | trailing });
    }

    pub fn fromView(view: object.View) Error!Button {
        return component_codec.decodeFromView(Button, .button, view);
    }

    pub fn fromNode(button: @FieldType(ui.Node, "button")) Error!Button {
        return .{ .id = button.id, .label = button.label, .variant = try variantFromTag(button.variant), .icon_slot = try iconSlotFromTags(button.leading_icon, button.trailing_icon) };
    }
};

fn packIconSlot(slot: IconSlot) u16 {
    return switch (slot) {
        .none, .status, .media => 0,
        .leading, .trailing => |value| common.optionalIconTag(value.value),
    };
}

fn iconSlotTags(slot: IconSlot) struct { leading: u16, trailing: u16 } {
    const tag = packIconSlot(slot);
    return switch (slot) {
        .none, .status, .media => .{ .leading = 0, .trailing = 0 },
        .leading => .{ .leading = tag, .trailing = 0 },
        .trailing => .{ .leading = 0, .trailing = tag },
    };
}

fn iconSlotFromTags(leading_tag: u16, trailing_tag: u16) Error!IconSlot {
    const leading = try common.optionalIconFromTag(leading_tag);
    const trailing = try common.optionalIconFromTag(trailing_tag);
    if (leading != null and trailing != null) return error.Corrupt;
    if (leading) |value| return IconSlot.named(.leading, value);
    if (trailing) |value| return IconSlot.named(.trailing, value);
    return .none;
}

fn iconSlotCount(slot: IconSlot) usize {
    return switch (slot) {
        .none => 0,
        .leading, .trailing, .status, .media => 1,
    };
}

pub const IconButton = struct {
    id: u32,
    label: []const u8,
    icon: Icon,
    variant: common.ButtonVariant = .outline,
    flags: common.ComponentFlags = .{},

    pub fn node(self: IconButton) ui.Node {
        return ui.iconButtonNode(self.id, self.label, common.optionalIconTag(self.icon.value), variantTag(self.variant));
    }

    pub fn accessibility(self: IconButton) common.Accessibility {
        return .{ .role = .button, .label = self.label, .control_id = self.id };
    }

    pub fn render(self: IconButton, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const paint = buttonPaint(self.variant, options);
        try renderButtonFrame(scene, bounds, paint);
        try self.icon.renderColor(scene, iconButtonIconBounds(bounds), paint.text);
    }

    pub fn collectInteractions(self: IconButton, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try collector.addHit(bounds, .button, self.id);
    }

    pub fn measure(self: IconButton, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        const size = iconButtonSize(options.control_size);
        return measureIconButton(size, constraints);
    }

    pub fn toObject(self: IconButton, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.singleObjectFromRecord(@TypeOf(self), self, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: IconButton, writer: *component_codec.Writer, index: usize) bool {
        const label_ref = writer.string(self.label) orelse return false;
        return writer.record(index, .icon_button, self.id, label_ref, .{ .offset = variantTag(self.variant), .len = common.optionalIconTag(self.icon.value) });
    }

    pub fn fromView(view: object.View) Error!IconButton {
        return component_codec.decodeFromView(IconButton, .icon_button, view);
    }

    pub fn fromNode(button: @FieldType(ui.Node, "icon_button")) Error!IconButton {
        return .{ .id = button.id, .label = button.label, .variant = try variantFromTag(button.variant), .icon = Icon.named((try common.optionalIconFromTag(button.icon)) orelse return error.Corrupt) };
    }
};

fn renderButton(scene: *ui.Scene, bounds: ui.Rect, button: Button, options: RenderOptions) ui.RenderError!void {
    const paint = buttonPaint(button.variant, options);
    try renderButtonFrame(scene, bounds, paint);
    try renderContent(scene, bounds, button.label, paint.text, button.icon_slot, labelPadding(options.control_size));
}

fn renderButtonFrame(scene: *ui.Scene, bounds: ui.Rect, paint: ButtonPaint) ui.RenderError!void {
    if (paint.fill) |fill| {
        try scene.pushRect(bounds.insetUniform(-button_shadow_inset), button_shadow, .shadow, radius, button_shadow_size);
        try scene.pushGradientRect(bounds, fill, button_floor, radius);
        try scene.pushRect(bounds.insetLtrb(1.0, 1.0, 1.0, bounds.h - button_rim_height), button_rim, .fill, radius, 0.0);
    }
    if (paint.border) |border| try scene.pushRect(bounds, border, .border, radius, 0.0);
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

fn collectButtonInteractions(collector: *interaction.Collector, bounds: ui.Rect, button: Button) interaction.Error!void {
    try collector.addHit(bounds, .button, button.id);
}

pub fn preferredWidth(label: []const u8, icon_slot: IconSlot) f32 {
    return preferredWidthForSize(label, icon_slot, .default);
}

pub fn preferredWidthForSize(label: []const u8, icon_slot: IconSlot, size: common.ControlSize) f32 {
    const icon_count = iconSlotCount(icon_slot);
    return @max(minWidth(size), estimatedLabelWidth(label) + iconClusterWidth(icon_count, label.len != 0) + labelPadding(size) * 2.0);
}

fn measureButton(label: []const u8, icon_slot: IconSlot, constraints: layout.Constraints) layout.Measurement {
    return measureButtonWithSize(label, icon_slot, .default, constraints);
}

fn measureButtonWithSize(label: []const u8, icon_slot: IconSlot, size: common.ControlSize, constraints: layout.Constraints) layout.Measurement {
    const preferred_width = preferredWidthForSize(label, icon_slot, size);
    const preferred_height = buttonHeight(size);
    const preferred = constrainPreferredSize(.{ .w = preferred_width, .h = preferred_height }, constraints);
    return layout.Measurement.flexible(
        .{ .w = @min(minWidth(size), preferred.w), .h = @min(preferred_height, preferred.h) },
        preferred,
        .{ .w = primitives.maxMeasuredWidth(constraints, preferred.w), .h = preferred_height },
    ).applyExact(constraints);
}

fn measureIconButton(size: f32, constraints: layout.Constraints) layout.Measurement {
    const preferred = constrainPreferredSize(.{ .w = size, .h = size }, constraints);
    return layout.Measurement.flexible(preferred, preferred, preferred).applyExact(constraints);
}

fn renderContent(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, text_color: ui.Color, icon_slot: IconSlot, padding: f32) ui.RenderError!void {
    switch (icon_slot) {
        .none => {
            const text_bounds = textBounds(bounds, padding);
            try text_component.Text.renderAligned(scene, text_bounds, text_metrics.fitPrefix(label, text_metrics.button_label_px, text_bounds.w), text_color, .center);
            return;
        },
        .leading, .trailing => {},
        .status, .media => return error.UnsupportedComponent,
    }

    const has_label = label.len != 0;
    const icon_count = iconSlotCount(icon_slot);
    const margin = if (has_label) @min(padding, bounds.w * 0.5) else 0.0;
    const available_w = @max(1.0, bounds.w - margin * 2.0);
    const icons_w = iconClusterWidth(icon_count, has_label);
    const label_w = if (has_label) @max(1.0, @min(estimatedLabelWidth(label), @max(1.0, available_w - icons_w))) else 0.0;
    const visible_label = text_metrics.fitPrefix(label, text_metrics.button_label_px, label_w);
    const content_w = @min(available_w, label_w + icons_w);
    var cursor_x = bounds.x + margin + @max(0.0, (available_w - content_w) * 0.5);
    const icon_y = bounds.y + (bounds.h - icon_size) * 0.5;
    const text_y = labelY(bounds);

    switch (icon_slot) {
        .leading => |value| {
            try value.renderColor(scene, ui.Rect.init(cursor_x, icon_y, icon_size, icon_size), text_color);
            cursor_x += icon_size;
            if (has_label) cursor_x += icon_gap;
        },
        .none, .trailing => {},
        .status, .media => return error.UnsupportedComponent,
    }

    if (has_label) {
        try text_component.Text.renderAligned(scene, ui.Rect.init(cursor_x, text_y, label_w, label_height), visible_label, text_color, .start);
        cursor_x += label_w;
        switch (icon_slot) {
            .trailing => cursor_x += icon_gap,
            .none, .leading => {},
            .status, .media => return error.UnsupportedComponent,
        }
    }

    switch (icon_slot) {
        .trailing => |value| {
            try value.renderColor(scene, ui.Rect.init(cursor_x, icon_y, icon_size, icon_size), text_color);
        },
        .none, .leading => {},
        .status, .media => return error.UnsupportedComponent,
    }
}

fn textBounds(bounds: ui.Rect, padding: f32) ui.Rect {
    const margin = @min(padding, bounds.w * 0.5);
    return ui.Rect.init(bounds.x + margin, labelY(bounds), @max(1.0, bounds.w - margin * 2.0), label_height);
}

fn labelY(bounds: ui.Rect) f32 {
    return bounds.y + (bounds.h - label_line_height) * 0.5;
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
        .primary => .{ .fill = options.style.accent, .border = options.style.accent, .text = button_primary_text },
        .secondary => .{ .fill = options.style.row, .border = options.style.border, .text = options.style.text },
        .outline => .{ .fill = options.style.panel, .border = options.style.border, .text = options.style.text },
        .ghost => .{ .fill = ui.Color.clear, .text = options.style.muted },
        .destructive => .{ .fill = button_danger, .border = button_danger, .text = button_danger_text },
        .link => .{ .text = options.style.accent },
    };
}

pub const radius: f32 = 8.0;
pub const height: f32 = 36.0;
pub const label_height: f32 = 17.0;
pub const label_padding: f32 = 16.0;

const label_min_width: f32 = 8.0;
const label_line_height: f32 = 20.0;
const icon_size: f32 = 18.0;
const icon_gap: f32 = 8.0;
const min_width: f32 = 44.0;
const icon_button_size: f32 = 36.0;
const button_danger = ui.Color{ .r = 225, .g = 48, .b = 72 };
const button_danger_text = ui.Color{ .r = 255, .g = 255, .b = 255 };
const button_primary_text = ui.Color{ .r = 5, .g = 20, .b = 18 };
const button_shadow = ui.Color{ .r = 0, .g = 0, .b = 0, .a = 42 };
const button_floor = ui.Color{ .r = 3, .g = 8, .b = 10, .a = 22 };
const button_rim = ui.Color{ .r = 255, .g = 255, .b = 255, .a = 9 };
const button_shadow_inset: f32 = 1.0;
const button_shadow_size: f32 = 3.0;
const button_rim_height: f32 = 1.0;
const trailing_button_flag: u16 = 0x0100;

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
    const button = Button{ .id = 7, .label = "Run", .variant = .secondary, .icon_slot = IconSlot.named(.leading, .search) };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = button.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Button.fromView(try object.View.decode(canonical));

    try @import("std").testing.expectEqual(@as(u32, 7), decoded.id);
    try @import("std").testing.expectEqualStrings("Run", decoded.label);
    try @import("std").testing.expectEqual(common.ButtonVariant.secondary, decoded.variant);
    try @import("std").testing.expectEqual(Icon.named(.search).value, decoded.icon_slot.leading.value);
}

test "button component rejects ambiguous dual icon slots" {
    const node = ui.buttonDetailNode(7, "Run", variantTag(.secondary), Icon.named(.search).tag(), Icon.named(.chevron_right).tag());

    try std.testing.expectError(error.Corrupt, Button.fromNode(node.button));
}

test "icon button component serializes to canonical object and deserializes" {
    const button = IconButton{ .id = 17, .label = "Search", .icon = Icon.named(.search), .variant = .ghost };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = button.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try IconButton.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(@as(u32, 17), decoded.id);
    try std.testing.expectEqualStrings("Search", decoded.label);
    try std.testing.expectEqual(common.ButtonVariant.ghost, decoded.variant);
    try std.testing.expectEqual(Icon.named(.search).value, decoded.icon.value);
}

test "icon button component renders centered icon and hit region" {
    const button = IconButton{ .id = 18, .label = "Search", .icon = Icon.named(.search), .variant = .outline };
    var h = component_test.InteractiveHarness(8, 1){};
    h.init();
    const bounds = ui.Rect.init(4, 8, icon_button_size, icon_button_size);

    try h.render(button, bounds, .{});
    try button.collectInteractions(&h.collector, bounds);

    const icon_command = component_test.iconCommand(h.written(), icon_pack.iconId(.search)).?;
    try std.testing.expectEqual(bounds.x + (bounds.w - icon_size) * 0.5, icon_command.icon_quad.bounds.x);
    try std.testing.expectEqual(bounds.y + (bounds.h - icon_size) * 0.5, icon_command.icon_quad.bounds.y);
    try h.expectHitCount(1);
    try h.expectHitKind(0, .button);
    try h.expectHitId(0, 18);
}

test "button component measurement follows label width" {
    const short = measureButton("Go", .none, .{});
    const long = measureButton("Continue lesson", .none, .{});
    const with_icon = measureButton("Continue lesson", .{ .leading = Icon.named(.search) }, .{});
    const constrained = measureButton("Continue lesson", .none, .{ .width = .{ .at_most = 72.0 }, .height = .{ .at_most = 24.0 } });

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
    const small_icon = (IconButton{ .id = 8, .label = "Search", .icon = Icon.named(.search) }).measure(.{}, .{ .control_size = .small });
    const large_icon = (IconButton{ .id = 9, .label = "Search", .icon = Icon.named(.search) }).measure(.{}, .{ .control_size = .large });

    try std.testing.expect(small.preferred.h < regular.preferred.h);
    try std.testing.expect(large.preferred.h > regular.preferred.h);
    try std.testing.expect(preferredWidthForSize("Run", .none, .small) < preferredWidthForSize("Run", .none, .large));
    try std.testing.expect(small_icon.preferred.w < large_icon.preferred.w);
    try std.testing.expect(small_icon.preferred.h < large_icon.preferred.h);
}

test "button component measurement uses font glyph widths" {
    const wide = measureButton("WWW", .none, .{});
    const narrow = measureButton("iii", .none, .{});

    try std.testing.expect(wide.preferred.w > narrow.preferred.w);
}

test "button component constrains icon label content to button bounds" {
    var h = component_test.SceneHarness(16){};
    h.init();
    const bounds = ui.Rect.init(10, 10, 72, height);

    try renderButton(&h.scene, bounds, .{ .id = 8, .label = "Impossible label", .variant = .secondary, .icon_slot = IconSlot.named(.leading, .search) }, .{});

    for (h.written()) |command| switch (command) {
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

test "button component aligns icon slot and label centers" {
    var h = component_test.SceneHarness(8){};
    h.init();
    const bounds = ui.Rect.init(10, 10, 132, height);

    try renderButton(&h.scene, bounds, .{ .id = 8, .label = "Compile", .variant = .secondary, .icon_slot = IconSlot.named(.leading, .cpu) }, .{});

    const icon_command = component_test.iconCommand(h.written(), Icon.named(.cpu).tag()).?.icon_quad;
    const text_command = component_test.textCommand(h.written(), "Compile").?.text;
    try std.testing.expectEqual(bounds.y + (bounds.h - label_line_height) * 0.5, text_command.origin.y);
    try std.testing.expect(text_command.origin.y + text_command.origin.h * 0.5 < icon_command.bounds.y + icon_command.bounds.h * 0.5);
    try std.testing.expect(icon_command.bounds.x + icon_command.bounds.w <= text_command.origin.x);
}

test "button component truncates overfull plain labels deterministically" {
    var h = component_test.SceneHarness(8){};
    h.init();
    const label = "WWWWWWWWWW";

    try renderButton(&h.scene, ui.Rect.init(0, 0, 72, height), .{ .id = 9, .label = label }, .{});

    const command = component_test.firstTextCommand(h.written()).?.text;
    try std.testing.expect(command.value.len < label.len);
    try std.testing.expect(std.mem.startsWith(u8, label, command.value));
}

test "button component centers icon only content" {
    var h = component_test.SceneHarness(8){};
    h.init();
    const bounds = ui.Rect.init(10, 10, 44, height);

    try renderButton(&h.scene, bounds, .{ .id = 8, .label = "", .variant = .secondary, .icon_slot = IconSlot.named(.leading, .search) }, .{});

    var found = false;
    for (h.written()) |command| switch (command) {
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
    var h = component_test.SceneHarness(32){};
    h.init();

    try renderButton(&h.scene, ui.Rect.init(0, 0, 120, height), .{ .id = 1, .label = "Delete", .variant = .destructive }, .{});
    try renderButton(&h.scene, ui.Rect.init(0, 44, 120, height), .{ .id = 2, .label = "Docs", .variant = .link, .icon_slot = IconSlot.named(.leading, .search) }, .{});

    try h.expectRectColor(button_danger);
    try std.testing.expect(!component_test.hasRectBounds(h.written(), ui.Rect.init(0, 44, 120, height)));
    try std.testing.expect(component_test.hasTextColor(h.written(), ui.Color.accent));
    try h.expectIcon(icon_pack.iconId(.search));
}

test "button deserializer rejects wrong component kind" {
    const text = text_component.Text{ .value = "not a button" };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = text.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const view = try object.View.decode(canonical);

    try std.testing.expectError(error.UnsupportedComponent, Button.fromView(view));
}
