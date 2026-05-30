const std = @import("std");
const clock = @import("clock.zig");
const component_union = @import("ui/components/Component.zig");
const RowItem = @import("ui/components/RowItem.zig").RowItem;
const Stack = @import("ui/components/Stack.zig").Stack;
const linux = std.os.linux;

const Component = component_union.Component;

fn writeFrame(title: []const u8, rows: []const RowItem, ui_buf: []u8, object_buf: []u8, epoch: clock.Stamp) ![]const u8 {
    var children: [1 + 6]Component = undefined;
    children[0] = .{ .text = .{ .value = title } };
    for (rows, 0..) |item, i| children[i + 1] = .{ .row_item = item };
    const n_children: u16 = @intCast(1 + rows.len);
    const stack = Stack(Component){
        .axis = .column,
        .gap = 4,
        .padding = 8,
        .children = children[0..n_children],
    };
    return stack.toObject(ui_buf, object_buf, epoch) orelse return error.ObjectFailed;
}

pub fn main(init: std.process.Init) !void {
    _ = init;

    const hw_rows = [_]RowItem{
        .{ .id = 1, .title = "System Summary", .detail = "OK \xe2\x80\x94 all subsystems nominal" },
        .{ .id = 2, .title = "CPU", .detail = "3.2 GHz \xe2\x80\x94 8 cores" },
        .{ .id = 3, .title = "Memory", .detail = "16 GB \xe2\x80\x94 8.2 GB free" },
        .{ .id = 4, .title = "Disk", .detail = "512 GB \xe2\x80\x94 234 GB used" },
        .{ .id = 5, .title = "Network", .detail = "eth0 \xe2\x80\x94 192.168.1.42" },
        .{ .id = 6, .title = "Temperature", .detail = "65 \xc2\xb0C \xe2\x80\x94 normal" },
    };

    const net_rows = [_]RowItem{
        .{ .id = 1, .title = "eth0", .detail = "192.168.1.42  up  1.2 GB rx  340 MB tx" },
        .{ .id = 2, .title = "wlan0", .detail = "10.0.0.5  up  4.5 GB rx  890 MB tx" },
        .{ .id = 3, .title = "lo", .detail = "127.0.0.1  up  12 MB rx  12 MB tx" },
    };

    var ui_buf: [8192]u8 = undefined;
    var object_buf: [8192]u8 = undefined;
    const epoch = clock.Stamp{ .keeper = .{ .bytes = [_]u8{1} ** 32 } };

    {
        const canonical = try writeFrame("Hardware Status", &hw_rows, &ui_buf, &object_buf, epoch);
        const len: u32 = @intCast(canonical.len);
        _ = linux.write(1, &std.mem.toBytes(len), 4);
        _ = linux.write(1, canonical.ptr, canonical.len);
    }

    {
        const canonical = try writeFrame("Network Interfaces", &net_rows, &ui_buf, &object_buf, epoch);
        const len: u32 = @intCast(canonical.len);
        _ = linux.write(1, &std.mem.toBytes(len), 4);
        _ = linux.write(1, canonical.ptr, canonical.len);
    }
}
