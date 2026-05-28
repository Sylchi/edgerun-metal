const ui = @import("../../ui.zig");
const interaction = @import("../../ui_interaction.zig");
const common = @import("../../ui_component_common.zig");
const component_union = @import("Component.zig");

pub const Target = union(enum) {
    hit_id: u32,
    path: []const u8,
    slug: []const u8,
};

pub const Nav = struct {
    id: u32,
    target: Target,
    child: component_union.Component,
    active: bool = false,
    disabled: bool = false,

    pub fn node(self: Nav) ui.Node {
        _ = self;
        return .{ .empty = .{ .title = "", .detail = "" } };
    }

    pub fn render(self: Nav, scene: *ui.Scene, bounds: ui.Rect, options: common.RenderOptions) ui.RenderError!void {
        var resolved = options;
        resolved.control = .{
            .active = self.active,
            .disabled = self.disabled,
        };
        try self.child.render(scene, bounds, resolved);
    }

    pub fn measure(self: Nav, constraints: @import("../../layouts.zig").types.Constraints, options: common.RenderOptions) @import("../../layouts.zig").types.Measurement {
        return self.child.measure(constraints, options);
    }

    pub fn collectInteractions(self: Nav, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        if (self.disabled) return;
        try collector.addHit(bounds, .button, self.id);
    }

    pub fn writeRecord(self: Nav, writer: anytype) !void {
        try self.child.writeRecord(writer);
    }

    pub fn fromNode(_: anytype) common.Error!Nav {
        return error.UnsupportedComponent;
    }
};
