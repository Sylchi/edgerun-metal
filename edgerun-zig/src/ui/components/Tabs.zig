const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const interaction = @import("../../ui_interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const component_render = @import("Render.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

pub const Tabs = struct {
    id: u32,
    first: []const u8,
    second: []const u8,
    active: u16 = 0,

    pub fn node(self: Tabs) ui.Node {
        return ui.tabsNode(self.id, self.first, self.second, activeIndex(self.active));
    }

    pub fn render(self: Tabs, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return component_render.renderTabs(scene, bounds, self.first, self.second, activeIndex(self.active), options);
    }

    pub fn collectInteractions(self: Tabs, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        const list = component_render.tabsListBounds(bounds);
        try collector.addHit(component_render.tabsTriggerBounds(list, 0), .button, self.id);
        try collector.addHit(component_render.tabsTriggerBounds(list, 1), .button, self.id + 1);
    }

    pub fn measure(self: Tabs, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return component_render.measureFixed(component_render.preferred_tabs, constraints);
    }

    pub fn toObject(self: Tabs, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        var writer = component_codec.Writer.init(ui_out, 1, 1, .column, 0, 0) orelse return null;
        if (!self.writeRecord(&writer, 0)) return null;
        return writer.objectNode(object_out, req, epoch);
    }

    pub fn writeRecord(self: Tabs, writer: *component_codec.Writer, index: usize) bool {
        const first_ref = writer.string(self.first) orelse return false;
        const second_ref = writer.string(self.second) orelse return false;
        return writer.record(index, .tabs, encodedId(self.id, self.active), first_ref, second_ref);
    }

    pub fn fromView(view: object.View) Error!Tabs {
        return switch (try component_codec.singleNode(view)) {
            .tabs => |tabs| .{ .id = tabs.id, .first = tabs.first, .second = tabs.second, .active = activeIndex(tabs.active) },
            else => error.UnsupportedComponent,
        };
    }
};

fn activeIndex(value: u16) u16 {
    return @min(value, 1);
}

fn encodedId(id: u32, active: u16) u32 {
    return id * tabs_id_stride + activeIndex(active);
}

const tabs_id_stride: u32 = 2;

test "tabs component serializes to canonical object and deserializes" {
    const tabs = Tabs{ .id = 80, .first = "Account", .second = "Password", .active = 1 };
    var ui_raw: [160]u8 = undefined;
    var object_raw: [object.header_size + 160]u8 = undefined;

    const canonical = tabs.toObject(&ui_raw, &object_raw, component_test.req(), component_test.epoch()).?;
    const decoded = try Tabs.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(tabs.id, decoded.id);
    try std.testing.expectEqualStrings(tabs.first, decoded.first);
    try std.testing.expectEqualStrings(tabs.second, decoded.second);
    try std.testing.expectEqual(@as(u16, 1), decoded.active);
}

test "tabs component renders active trigger and trigger hits" {
    const tabs = Tabs{ .id = 80, .first = "Account", .second = "Password", .active = 0 };
    var commands: [20]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [2]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try tabs.render(&scene, ui.Rect.init(0, 0, 220, 84), .{});
    try tabs.collectInteractions(&collector, ui.Rect.init(0, 0, 220, 84));

    try std.testing.expect(component_test.hasText(scene.written(), "Account"));
    try std.testing.expect(component_test.hasText(scene.written(), "Password"));
    try std.testing.expectEqual(@as(usize, 2), collector.written().len);
    try std.testing.expectEqual(@as(u32, 81), collector.written()[1].id);
}
