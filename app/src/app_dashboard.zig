const std = @import("er_std");
const codec = @import("ui/codec.zig");
const dashboard = @import("ui/dashboard.zig");
const device_tree = @import("ui/device_tree.zig");
const ui = @import("ui/core.zig");
const component = @import("ui/components/Component.zig");

const Error = dashboard.Error || error{ IfstatusFailed, CodecReadFailed };

const max_codec_bytes: usize = 4096;
const arena_size: usize = 8192;

pub const State = struct {
    device_memory: [arena_size]u8 = undefined,
    device_tree: device_tree.DeviceTree = undefined,
    tree_valid: bool = false,

    pub fn refresh(self: *State) Error!void {
        const codec_bytes = readIfstatusBytes(self.device_memory[0..]) catch |err| {
            self.tree_valid = false;
            return err;
        };
        self.device_tree = try device_tree.DeviceTree.initFromCodec(0, "Network", codec_bytes, &self.device_memory);
        self.tree_valid = true;
    }

    pub fn render(self: *State, scene: *ui.Scene, bounds: ui.Rect, style: ui.Style) Error!void {
        const app = component.renderer(scene, null, .{ .style = style });
        try self.renderView(app, bounds);
    }

    pub fn renderView(self: *State, app: component.View, bounds: ui.Rect) Error!void {
        if (!self.tree_valid) {
            try app.muted(bounds, "ifstatus unavailable");
            return;
        }
        try self.device_tree.renderView(app, bounds);
    }
};

const linux = std.os.linux;

const ifstatus_buffer_size: usize = max_codec_bytes;

pub fn readIfstatusBytes(output: []u8) Error![]const u8 {
    return runIfstatus(output);
}

fn runIfstatus(output: []u8) ![]const u8 {
    if (output.len < ifstatus_buffer_size) return error.CodecReadFailed;
    var codec_buf: []u8 = output[0..ifstatus_buffer_size];

    var pipe_fds: [2]i32 = undefined;
    const pipe_rc = linux.pipe2(&pipe_fds, .{});
    if (linux.errno(pipe_rc) != .SUCCESS)
        return error.IfstatusFailed;
    const rfd = pipe_fds[0];
    const wfd = pipe_fds[1];

    const fork_rc = linux.fork();
    if (linux.errno(fork_rc) != .SUCCESS) {
        _ = linux.close(rfd);
        _ = linux.close(wfd);
        return error.IfstatusFailed;
    }

    if (fork_rc == 0) {
        _ = linux.close(rfd);
        _ = linux.dup2(wfd, 1);
        _ = linux.close(wfd);
        const exe_path: [*:0]const u8 = ".build/app/edgerun-ifstatus";
        const argv: [*:null]const ?[*:0]const u8 = &.{ exe_path, null };
        const envp: [*:null]const ?[*:0]const u8 = &.{null};
        _ = linux.execve(exe_path, argv, envp);
        linux.exit(1);
    }

    const child_pid: i32 = @intCast(fork_rc);
    _ = linux.close(wfd);

    var total: usize = 0;
    while (total < codec_buf.len) {
        const n = linux.read(rfd, codec_buf[total..].ptr, codec_buf.len - total);
        if (linux.errno(n) != .SUCCESS) break;
        if (n == 0) break;
        total += n;
    }
    _ = linux.close(rfd);

    var status: u32 = 0;
    _ = linux.wait4(child_pid, &status, 0, null);

    if (status & 0x7f != 0) return error.IfstatusFailed;
    const exit_code = (status >> 8) & 0xff;
    if (exit_code != 0) return error.IfstatusFailed;
    return codec_buf[0..total];
}
