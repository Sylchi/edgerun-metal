const std = @import("std");
const bytes = @import("../bytes.zig");
const arena = @import("../arena.zig");
const codec = @import("codec.zig");
const ui = @import("core.zig");
const ui_stream = @import("codec.zig");

pub const Error = error{
    Corrupt,
    NodeNotFound,
    OutOfMemory,
};

pub const DeviceTree = struct {
    id: u8,
    name: []const u8,
    root: ui.Node,
    arena: arena.BoundedArena,

    pub fn init(id: u8, name: []const u8, root: ui.Node, memory: []u8) DeviceTree {
        return .{ .id = id, .name = name, .root = root, .arena = arena.BoundedArena.init(.{ .base = memory }) };
    }

    pub fn initFromCodec(id: u8, name: []const u8, codec_bytes: []const u8, memory: []u8) Error!DeviceTree {
        var region = arena.BoundedArena.init(.{ .base = memory });
        const arena_copy = region.allocSlice(u8, codec_bytes.len) orelse return error.OutOfMemory;
        @memcpy(arena_copy, codec_bytes);

        if (codec_bytes.len < codec.header_size) return error.Corrupt;
        const node_count = std.mem.readInt(u16, codec_bytes[16..18], .little);

        const nodes = region.allocSlice(ui.Node, node_count) orelse return error.OutOfMemory;
        const root = codec.decodeBytes(arena_copy, nodes) catch return error.Corrupt;
        return DeviceTree{ .id = id, .name = name, .root = root, .arena = region };
    }

    pub fn findNode(self: *DeviceTree, component_id: u8) ?*ui.Node {
        switch (self.root) {
            .stack => |*layout| {
                if (component_id < layout.children.len) {
                    return @constCast(&layout.children[component_id]);
                }
            },
            else => {},
        }
        return null;
    }

    fn copyString(self: *DeviceTree, value: []const u8) ?[]u8 {
        const allocator = self.arena.allocator();
        const copy = allocator.alloc(u8, value.len) catch return null;
        @memcpy(copy, value);
        return copy;
    }

    fn allocatePatchStrings(self: *DeviceTree, patch: *ui.Patch) Error!void {
        switch (patch.*) {
            .text_value => |*v| v.* = self.copyString(v.*) orelse return error.OutOfMemory,
            .accordion_open => {},
            .alert => |*v| {
                v.title = self.copyString(v.title) orelse return error.OutOfMemory;
                v.detail = self.copyString(v.detail) orelse return error.OutOfMemory;
            },
            .alert_dialog => |*v| {
                v.title = self.copyString(v.title) orelse return error.OutOfMemory;
                v.detail = self.copyString(v.detail) orelse return error.OutOfMemory;
            },
            .calendar_selected_day => {},
            .carousel_label => |*v| v.* = self.copyString(v.*) orelse return error.OutOfMemory,
            .chart_label => |*v| v.* = self.copyString(v.*) orelse return error.OutOfMemory,
            .combobox_selected => |*v| v.* = self.copyString(v.*) orelse return error.OutOfMemory,
            .card_text => |*v| {
                v.title = self.copyString(v.title) orelse return error.OutOfMemory;
                v.detail = self.copyString(v.detail) orelse return error.OutOfMemory;
            },
            .empty_text => |*v| {
                v.title = self.copyString(v.title) orelse return error.OutOfMemory;
                v.detail = self.copyString(v.detail) orelse return error.OutOfMemory;
            },
            .badge_label => |*v| v.* = self.copyString(v.*) orelse return error.OutOfMemory,
            .avatar_label => |*v| v.* = self.copyString(v.*) orelse return error.OutOfMemory,
            .kbd_label => |*v| v.* = self.copyString(v.*) orelse return error.OutOfMemory,
            .label_value => |*v| v.* = self.copyString(v.*) orelse return error.OutOfMemory,
            .breadcrumb_current => |*v| v.* = self.copyString(v.*) orelse return error.OutOfMemory,
            .menubar_active => {},
            .navigation_menu_active => {},
            .command_placeholder => |*v| v.* = self.copyString(v.*) orelse return error.OutOfMemory,
            .context_menu => |*v| {
                v.first = self.copyString(v.first) orelse return error.OutOfMemory;
                v.second = self.copyString(v.second) orelse return error.OutOfMemory;
            },
            .dialog => |*v| {
                v.title = self.copyString(v.title) orelse return error.OutOfMemory;
                v.detail = self.copyString(v.detail) orelse return error.OutOfMemory;
            },
            .direction_active => {},
            .drawer => |*v| {
                v.title = self.copyString(v.title) orelse return error.OutOfMemory;
                v.detail = self.copyString(v.detail) orelse return error.OutOfMemory;
            },
            .dropdown_menu => |*v| {
                v.first = self.copyString(v.first) orelse return error.OutOfMemory;
                v.second = self.copyString(v.second) orelse return error.OutOfMemory;
            },
            .field_placeholder => |*v| v.* = self.copyString(v.*) orelse return error.OutOfMemory,
            .hover_card_content => |*v| v.* = self.copyString(v.*) orelse return error.OutOfMemory,
            .input_otp_value => |*v| v.* = self.copyString(v.*) orelse return error.OutOfMemory,
            .button_label => |*v| v.* = self.copyString(v.*) orelse return error.OutOfMemory,
            .button_group_active => {},
            .toggle_group_active => {},
            .toggle_pressed => {},
            .input_placeholder => |*v| v.* = self.copyString(v.*) orelse return error.OutOfMemory,
            .input_group_placeholder => |*v| v.* = self.copyString(v.*) orelse return error.OutOfMemory,
            .textarea_placeholder => |*v| v.* = self.copyString(v.*) orelse return error.OutOfMemory,
            .select_label => |*v| v.* = self.copyString(v.*) orelse return error.OutOfMemory,
            .checkbox_checked => {},
            .radio_selected => {},
            .switch_checked => {},
            .pagination_page => {},
            .popover_content => |*v| v.* = self.copyString(v.*) orelse return error.OutOfMemory,
            .resizable_ratio => {},
            .sheet => |*v| {
                v.title = self.copyString(v.title) orelse return error.OutOfMemory;
                v.detail = self.copyString(v.detail) orelse return error.OutOfMemory;
            },
            .sidebar_item => |*v| v.* = self.copyString(v.*) orelse return error.OutOfMemory,
            .progress_value => {},
            .slider_value => {},
            .tabs_active => {},
            .table_row => |*v| {
                v.name = self.copyString(v.name) orelse return error.OutOfMemory;
                v.role = self.copyString(v.role) orelse return error.OutOfMemory;
            },
            .tooltip_content => |*v| v.* = self.copyString(v.*) orelse return error.OutOfMemory,
            .toast => |*v| {
                v.title = self.copyString(v.title) orelse return error.OutOfMemory;
                v.detail = self.copyString(v.detail) orelse return error.OutOfMemory;
            },
            .row_item => |*v| {
                v.title = self.copyString(v.title) orelse return error.OutOfMemory;
                v.detail = self.copyString(v.detail) orelse return error.OutOfMemory;
            },
            .rect_color => {},
            .style_color => {},
        }
    }

    pub fn applyWirePatch(self: *DeviceTree, wire_bytes: []const u8) Error!void {
        const decoded = ui_stream.decodePatch(wire_bytes) orelse return error.Corrupt;
        var patch = decoded.patch;
        try self.allocatePatchStrings(&patch);
        const node = self.findNode(decoded.component_id) orelse return error.NodeNotFound;
        ui.applyPatch(node, patch) catch return error.NodeNotFound;
    }

    pub fn render(self: *DeviceTree, scene: *ui.Scene, bounds: ui.Rect, style: ui.Style) Error!void {
        ui.render(scene, self.root, bounds, style) catch |err| switch (err) {
            error.CommandBudgetExceeded, error.InvalidBounds, error.ClipBudgetExceeded => return error.Corrupt,
            error.UnsupportedComponent => return error.Corrupt,
        };
    }
};

test "device tree applies f32 wire patch and re-renders" {
    // Build tree manually: column stack with ["Temperature", "22.5°C"]
    var arena_mem: [2048]u8 = undefined;
    var nodes = [_]ui.Node{
        ui.textNode("Temperature", null),
        ui.textNode("22.5°C", null),
    };
    const root = ui.columnStack(4, 0, &nodes);

    var tree = DeviceTree.init(1, "sensor-1", root, &arena_mem);
    try std.testing.expectEqualStrings("22.5°C", tree.root.stack.children[1].text.value);

    // Apply BLE-sized wire patch: component_id=1, text_value="28.3°C" (8 bytes wire)
    var patch_buf: [16]u8 = undefined;
    const wire = ui_stream.encodePatch(&patch_buf, 1, ui.Patch{ .text_value = "28.3°C" }).?;
    try std.testing.expect(wire.len <= 12); // fits in BLE advertisement
    try tree.applyWirePatch(wire);

    // Verify tree updated in-place
    try std.testing.expectEqualStrings("28.3°C", tree.root.stack.children[1].text.value);

    // Render and verify scene contains updated text
    var cmds: [32]ui.Command = undefined;
    var scene = ui.Scene.init(&cmds);
    try tree.render(&scene, ui.Rect.init(0, 0, 200, 100), .{});
    try std.testing.expect(scene.commandCount() > 0);

    var found = false;
    for (scene.written()) |cmd| switch (cmd) {
        .text => |t| {
            if (bytes.eql(t.value, "28.3°C")) found = true;
        },
        else => {},
    };
    try std.testing.expect(found);
}

test "device tree from codec decodes cleanly" {
    var raw: [256]u8 = undefined;
    var w = codec.Writer.init(&raw, 2, 2, .column, 0, 0).?;
    _ = w.record(0, .text, 0, .{}, .{});
    const label = w.string("Hello").?;
    _ = w.record(1, .text, 1, label, .{});
    const written = w.written();

    var arena_mem: [2048]u8 = undefined;
    const tree = try DeviceTree.initFromCodec(2, "sensor-2", written, &arena_mem);
    try std.testing.expect(tree.root == .stack);
    try std.testing.expectEqual(@as(usize, 2), tree.root.stack.children.len);
    try std.testing.expectEqualStrings("Hello", tree.root.stack.children[1].text.value);
}
