const ui = @import("../core.zig");
const interaction = @import("../interaction.zig");
const common = @import("../component_common.zig");
const node_renderer = @import("NodeRenderer.zig");

pub const Target = union(enum) {
    hit_id: u32,
    path: []const u8,
    slug: []const u8,
};

pub const Nav = struct {
    id: u32,
    target: Target,
    child: *const ui.Node,
    active: bool = false,
    disabled: bool = false,

    pub fn node(self: Nav) ui.Node {
        return .{ .slot = .{ .id = self.id, .child = self.child } };
    }

    pub fn render(self: Nav, comptime Component: type, scene: *ui.Scene, bounds: ui.Rect, options: common.RenderOptions) ui.RenderError!void {
        var resolved = options;
        resolved.control = options.control.merge(.{
            .active = self.active,
            .disabled = self.disabled,
        });
        try node_renderer.renderNode(Component, scene, bounds, self.child.*, resolved);
    }

    pub fn collectInteractions(self: Nav, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        if (self.disabled) return;
        try collector.addHit(bounds, .button, self.id);
    }
};
