const std = @import("std");

const output_file_permissions = std.Io.File.Permissions.default_file.setReadOnly(true);

pub const output_name = "index.html";
pub const wasm_path = "../bin/edgerun-ui-browser.wasm";
pub const immutable_marker = "GENERATED FILE. IMMUTABLE.";

pub const html =
    \\<!doctype html>
    \\<!-- GENERATED FILE. IMMUTABLE. Browser/WASM bootstrap only. -->
    \\<html lang="en">
    \\<head>
    \\  <meta charset="utf-8">
    \\  <meta name="viewport" content="width=device-width, initial-scale=1">
    \\  <title>EdgeRun</title>
    \\</head>
    \\<body>
    \\  <script type="module">
    \\const wasmBuildVersion = "index-eval-1";
    \\const wasmPath = "../bin/edgerun-ui-browser.wasm";
    \\async function main() {
    \\  const response = await fetch(`${wasmPath}?v=${wasmBuildVersion}`, { cache: "no-store" });
    \\  const module = await WebAssembly.instantiateStreaming(response, {});
    \\  const wasm = module.instance.exports;
    \\  globalThis.__edgerunWasm = wasm;
    \\  const ptr = wasm.er_ui_bootstrap_js_ptr();
    \\  const len = wasm.er_ui_bootstrap_js_len();
    \\  const source = new TextDecoder().decode(new Uint8Array(wasm.memory.buffer, ptr, len));
    \\  (0, eval)(source);
    \\}
    \\main().catch((err) => { throw err; });
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
    try std.testing.expect(!contains("<canvas"));
    try std.testing.expect(!contains("<main"));
    try std.testing.expect(!contains("<style"));
}

test "generated entry only loads wasm and evals wasm-owned javascript" {
    try std.testing.expect(std.mem.eql(u8, output_name, "index.html"));
    try std.testing.expect(contains(wasm_path));
    try std.testing.expect(contains("WebAssembly.instantiateStreaming"));
    try std.testing.expect(contains("wasm.er_ui_bootstrap_js_ptr()"));
    try std.testing.expect(contains("wasm.er_ui_bootstrap_js_len()"));
    try std.testing.expect(contains("(0, eval)(source)"));
    try std.testing.expect(!contains("ui.css"));
    try std.testing.expect(!contains("ui.js"));
    try std.testing.expect(!contains("<link rel=\"stylesheet\""));
    try std.testing.expect(!contains("<script type=\"module\" src="));
    try std.testing.expect(!contains("vertexSource"));
    try std.testing.expect(!contains("hostCommandHandlers"));
    try std.testing.expect(!contains("addEventListener(\"keydown\""));
}
