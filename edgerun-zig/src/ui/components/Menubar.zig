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

pub const Menubar = struct {
    id: u32,
    first: []const u8,
    second: []const u8,
    active: u16 = 0,

    pub fn node(self: Menubar) ui.Node {
        return ui.menubarNode(self.id, self.first, self.second, activeIndex(self.active));
    }

    pub fn render(self: Menubar, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return component_render.renderMenubar(scene, bounds, self.first, self.second, activeIndex(self.active), options);
    }

    pub fn collectInteractions(self: Menubar, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        for (0..component_render.menubar_item_count) |index| {
            try collector.addHit(component_render.menubarItemBounds(bounds, index), .button, self.id + @as(u32, @intCast(index)));
        }
    }

    pub fn measure(self: Menubar, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return component_render.measureFixed(component_render.preferred_menubar, constraints);
    }

    pub fn toObject(self: Menubar, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        var writer = component_codec.Writer.init(ui_out, 1, 1, .column, 0, 0) orelse return null;
        if (!self.writeRecord(&writer, 0)) return null;
        return writer.objectNode(object_out, req, epoch);
    }

    pub fn writeRecord(self: Menubar, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .menubar, encodedId(self.id, self.active), self.first, self.second);
    }

    pub fn fromView(view: object.View) Error!Menubar {
        return switch (try component_codec.singleNode(view)) {
            .menubar => |menubar| .{ .id = menubar.id, .first = menubar.first, .second = menubar.second, .active = activeIndex(menubar.active) },
            else => error.UnsupportedComponent,
        };
    }
};

fn activeIndex(value: u16) u16 {
    return @min(value, component_render.menubar_item_count - 1);
}

fn encodedId(id: u32, active: u16) u32 {
    return id * menubar_id_stride + activeIndex(active);
}

pub const menubar_id_stride: u32 = component_render.menubar_item_count;

test "menubar component serializes to canonical object and deserializes" {
    const menubar = Menubar{ .id = 120, .first = "File", .second = "Edit", .active = 2 };
    var ui_raw: [160]u8 = undefined;
    var object_raw: [object.header_size + 160]u8 = undefined;

    const canonical = menubar.toObject(&ui_raw, &object_raw, component_test.req(), component_test.epoch()).?;
    const decoded = try Menubar.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(menubar.id, decoded.id);
    try std.testing.expectEqualStrings(menubar.first, decoded.first);
    try std.testing.expectEqualStrings(menubar.second, decoded.second);
    try std.testing.expectEqual(@as(u16, 2), decoded.active);
}

test "menubar component renders items and hit regions" {
    const menubar = Menubar{ .id = 120, .first = "File", .second = "Edit", .active = 1 };
    var commands: [24]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [component_render.menubar_item_count]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try menubar.render(&scene, ui.Rect.init(0, 0, 170, 36), .{});
    try menubar.collectInteractions(&collector, ui.Rect.init(0, 0, 170, 36));

    try std.testing.expect(component_test.hasText(scene.written(), "File"));
    try std.testing.expect(component_test.hasText(scene.written(), "Edit"));
    try std.testing.expect(component_test.hasText(scene.written(), "View"));
    try std.testing.expectEqual(@as(usize, component_render.menubar_item_count), collector.written().len);
    try std.testing.expectEqual(@as(u32, 122), collector.written()[2].id);
}
