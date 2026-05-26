const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const component_contract = @import("ComponentContract.zig");
const interaction = @import("../../ui_interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const icon_component = @import("Icon.zig");
const primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

pub const registration = component_contract.registration("breadcrumb", Breadcrumb);
const measureFixed = primitives.measureFixed;
const Icon = icon_component.Icon;

pub const Breadcrumb = struct {
    id: u32,
    first: []const u8,
    current: []const u8,

    pub fn node(self: Breadcrumb) ui.Node {
        return ui.breadcrumbNode(self.id, self.first, self.current);
    }

    pub fn render(self: Breadcrumb, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const first_bounds = itemBounds(bounds, 0);
        const middle_bounds = itemBounds(bounds, 1);
        const current_bounds = itemBounds(bounds, 2);
        try scene.pushText(first_bounds.withHeightCentered(primitives.control_label_height), self.first, options.style.muted);
        try Icon.named(.chevron_right).renderColor(scene, separatorBounds(bounds, 0), options.style.muted);
        try scene.pushText(middle_bounds.withHeightCentered(primitives.control_label_height), breadcrumb_middle_label, options.style.muted);
        try Icon.named(.chevron_right).renderColor(scene, separatorBounds(bounds, 1), options.style.muted);
        try scene.pushText(current_bounds.withHeightCentered(primitives.control_label_height), self.current, options.style.text);
    }

    pub fn collectInteractions(self: Breadcrumb, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try collector.addHit(itemBounds(bounds, 0), .button, self.id);
        try collector.addHit(itemBounds(bounds, 1), .button, self.id + 1);
    }

    pub fn measure(self: Breadcrumb, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureFixed(preferred_breadcrumb, constraints);
    }

    pub fn toObject(self: Breadcrumb, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.breadcrumb, self.id, self.first, self.current, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Breadcrumb, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .breadcrumb, self.id, self.first, self.current);
    }

    pub fn fromView(view: object.View) Error!Breadcrumb {
        const breadcrumb = try component_codec.nodeView(view, .breadcrumb);
        return fromNode(breadcrumb);
    }

    pub fn fromNode(breadcrumb: @FieldType(ui.Node, "breadcrumb")) Error!Breadcrumb {
        return .{ .id = breadcrumb.id, .first = breadcrumb.first, .current = breadcrumb.current };
    }
};

fn itemBounds(bounds: ui.Rect, index: usize) ui.Rect {
    return switch (index) {
        0 => ui.Rect.init(bounds.x, bounds.y, breadcrumb_first_w, bounds.h),
        1 => ui.Rect.init(bounds.x + breadcrumb_first_w + breadcrumb_separator_w, bounds.y, breadcrumb_middle_w, bounds.h),
        else => ui.Rect.init(bounds.x + breadcrumb_first_w + breadcrumb_middle_w + breadcrumb_separator_w * 2.0, bounds.y, @max(primitives.min_extent, bounds.w - breadcrumb_first_w - breadcrumb_middle_w - breadcrumb_separator_w * 2.0), bounds.h),
    };
}

fn separatorBounds(bounds: ui.Rect, index: usize) ui.Rect {
    const x = switch (index) {
        0 => bounds.x + breadcrumb_first_w,
        else => bounds.x + breadcrumb_first_w + breadcrumb_separator_w + breadcrumb_middle_w,
    };
    return ui.Rect.init(x + breadcrumb_icon_inset, bounds.y + (bounds.h - breadcrumb_icon_size) * 0.5, breadcrumb_icon_size, breadcrumb_icon_size);
}

const preferred_breadcrumb = ui.Size{ .w = 220.0, .h = 36.0 };
const breadcrumb_first_w: f32 = 44.0;
const breadcrumb_middle_w: f32 = 42.0;
const breadcrumb_separator_w: f32 = 18.0;
const breadcrumb_icon_size: f32 = 12.0;
const breadcrumb_icon_inset: f32 = 3.0;
const breadcrumb_middle_label = "Docs";

test "breadcrumb component serializes to canonical object and deserializes" {
    const breadcrumb = Breadcrumb{ .id = 130, .first = "Home", .current = "Button" };
    var ui_raw: [160]u8 = undefined;
    var object_raw: [object.header_size + 160]u8 = undefined;

    const canonical = breadcrumb.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Breadcrumb.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(breadcrumb.id, decoded.id);
    try std.testing.expectEqualStrings(breadcrumb.first, decoded.first);
    try std.testing.expectEqualStrings(breadcrumb.current, decoded.current);
}

test "breadcrumb component renders links current page and link hits" {
    const breadcrumb = Breadcrumb{ .id = 130, .first = "Home", .current = "Button" };
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [2]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try breadcrumb.render(&scene, ui.Rect.init(0, 0, 220, 36), .{});
    try breadcrumb.collectInteractions(&collector, ui.Rect.init(0, 0, 220, 36));

    try std.testing.expect(component_test.hasText(scene.written(), "Home"));
    try std.testing.expect(component_test.hasText(scene.written(), "Docs"));
    try std.testing.expect(component_test.hasText(scene.written(), "Button"));
    try std.testing.expectEqual(@as(usize, 2), collector.written().len);
    try std.testing.expectEqual(@as(u32, 131), collector.written()[1].id);
}
