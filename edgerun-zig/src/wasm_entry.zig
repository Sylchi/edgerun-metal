const std = @import("std");

const output_file_permissions = std.Io.File.Permissions.default_file.setReadOnly(true);

pub const output_name = "index.html";
pub const wasm_path = "../bin/edgerun-app-runtime.wasm";
pub const immutable_marker = "GENERATED FILE. IMMUTABLE.";
pub const viewport_css = "html,body{margin:0;width:100%;height:100%;overflow:hidden;cursor:none}canvas{display:block}";
pub const max_total_js_bytes: usize = 250;
pub const loader_js =
    \\let w=(await WebAssembly.instantiateStreaming(fetch("../bin/edgerun-app-runtime.wasm"))).instance.exports;globalThis.__edgerunWasm=w;w.er_ui_boot()
;
pub const total_js_bytes: usize = loader_js.len + @import("web_host_js.zig").source.len;

pub const html =
    \\<!doctype html>
    \\<!-- GENERATED FILE. IMMUTABLE. Browser/WASM bootstrap only. -->
    \\<html lang="en">
    \\<head>
    \\  <meta charset="utf-8">
    \\  <meta name="viewport" content="width=device-width, initial-scale=1">
    \\  <title>EdgeRun</title>
    \\  <style>html,body{margin:0;width:100%;height:100%;overflow:hidden;cursor:none}canvas{display:block}</style>
    \\</head>
    \\<body>
    \\  <script type="module">
    \\
++ loader_js ++
    \\
    \\  </script>
    \\</body>
    \\</html>
    \\
;

pub fn main(init: std.process.Init) !void {
    var args = std.process.Args.Iterator.init(init.minimal.args);
    defer args.deinit();

    _ = args.next();
    const output_path = args.next() orelse return error.MissingOutputPath;
    if (args.next() != null) return error.TooManyArguments;

    const cwd = std.Io.Dir.cwd();
    cwd.deleteFile(init.io, output_path) catch |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    };
    const file = try cwd.createFile(init.io, output_path, .{ .truncate = true });
    defer file.close(init.io);
    try file.writeStreamingAll(init.io, html);
    try file.setPermissions(init.io, output_file_permissions);
}

fn contains(needle: []const u8) bool {
    return std.mem.indexOf(u8, html, needle) != null;
}

test "generated entry declares itself immutable bootstrap only" {
    try std.testing.expect(contains(immutable_marker));
    try std.testing.expect(contains("Browser/WASM bootstrap only"));
    try std.testing.expect(contains(viewport_css));
    try std.testing.expect(total_js_bytes < max_total_js_bytes);
    try std.testing.expect(!contains("<canvas"));
    try std.testing.expect(!contains("<main"));
}

test "generated entry has the only javascript byte bridge" {
    try std.testing.expect(std.mem.eql(u8, output_name, "index.html"));
    try std.testing.expect(contains(wasm_path));
    try std.testing.expect(contains("WebAssembly.instantiateStreaming"));
    try std.testing.expect(contains("globalThis.__edgerunWasm=w"));
    try std.testing.expect(contains("w.er_ui_boot()"));
    try std.testing.expect(!contains("TextDecoder"));
    try std.testing.expect(!contains("er_ui_bootstrap_js_ptr"));
    try std.testing.expect(!contains("er_ui_bootstrap_js_len"));
    try std.testing.expect(!contains("eval"));
    try std.testing.expect(!contains("ui.css"));
    try std.testing.expect(!contains("ui.js"));
    try std.testing.expect(!contains("<link rel=\"stylesheet\""));
    try std.testing.expect(!contains("<script type=\"module\" src="));
    try std.testing.expect(!contains("vertexSource"));
    try std.testing.expect(!contains("hostCommandHandlers"));
    try std.testing.expect(!contains("addEventListener(\"keydown\""));
}
