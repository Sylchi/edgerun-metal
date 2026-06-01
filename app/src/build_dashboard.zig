const std = @import("std");
const mem = std.mem;
const common = @import("ui/component_common.zig");
const renderer_font_atlas = @import("render/font_atlas_weighted.zig");
const renderer_ir = @import("render/ir.zig");
const renderer_pipeline = @import("render/pipeline.zig");
const renderer_software = @import("render/backends/software.zig");
const node_renderer = @import("ui/components/NodeRenderer.zig");
const component_union = @import("ui/components/Component.zig");
const ui = @import("ui/core.zig");
const icon_mod = @import("ui/icon.zig");
const layout_mod = @import("ui/layout.zig");

const W: usize = 1280;
const H: usize = 720;
const max_commands: usize = 4096;
const max_rects: usize = 8192;
const max_image_vertices: usize = 32768;
const max_icon_vertices: usize = 4096;
const max_icon_line_vertices: usize = 32768;
const max_overlay_rects: usize = 0;
const max_overlay_icon_vertices: usize = 0;
const max_overlay_icon_line_vertices: usize = 0;

const IrStorage = renderer_ir.FixedBuffers(
    max_rects,
    max_icon_vertices,
    max_image_vertices,
    max_overlay_rects,
    max_overlay_icon_vertices,
    max_icon_line_vertices,
    max_overlay_icon_line_vertices,
);

const Artifact = struct { name: []const u8, size_bytes: u64 };
const ModuleLoc = struct { name: []const u8, loc: u32 };
const TestSuite = struct { name: []const u8, passed: u32, total: u32 };

const BuildData = struct {
    git_hash: []const u8,
    branch: []const u8,
    commit_count: u32,
    asm_files: u32,
    inc_files: u32,
    total_loc: u32,
    artifacts: []const Artifact,
    modules: []const ModuleLoc,
    tests: []const TestSuite,
    commits: []const []const u8,
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const alloc = std.heap.page_allocator;
    const data = try collectData(alloc, io);
    defer freeData(alloc, data);
    try renderPPM(alloc, io, data);
}

fn freeData(alloc: std.mem.Allocator, data: BuildData) void {
    alloc.free(data.git_hash);
    alloc.free(data.branch);
    for (data.commits) |c| alloc.free(c);
    alloc.free(data.commits);
    alloc.free(data.artifacts);
    alloc.free(data.modules);
    alloc.free(data.tests);
}

fn cmdOutput(alloc: std.mem.Allocator, io: std.Io, argv: []const []const u8, max_size: usize) ![]u8 {
    const result = try std.process.run(alloc, io, .{
        .argv = argv,
        .stdout_limit = std.Io.Limit.limited(max_size),
    });
    defer alloc.free(result.stderr);
    if (result.term != .exited or result.term.exited != 0) return error.CmdFailed;
    const trimmed = mem.trim(u8, result.stdout, " \n\r\t");
    const owned = try alloc.dupe(u8, trimmed);
    alloc.free(result.stdout);
    return owned;
}

fn collectData(alloc: std.mem.Allocator, io: std.Io) !BuildData {
    const git_hash = cmdOutput(alloc, io, &.{ "git", "rev-parse", "--short", "HEAD" }, 64) catch try alloc.dupe(u8, "unknown");
    const branch = cmdOutput(alloc, io, &.{ "git", "branch", "--show-current" }, 64) catch try alloc.dupe(u8, "main");
    const count_str = cmdOutput(alloc, io, &.{ "git", "rev-list", "--count", "HEAD" }, 32) catch try alloc.dupe(u8, "0");
    const commit_count = std.fmt.parseInt(u32, mem.trim(u8, count_str, " \n\r\t"), 10) catch 0;
    alloc.free(count_str);
    const asm_str = cmdOutput(alloc, io, &.{ "sh", "-c", "find kernel -name '*.asm' -o -name '*.S' 2>/dev/null | wc -l" }, 32) catch try alloc.dupe(u8, "0");
    const asm_files = std.fmt.parseInt(u32, mem.trim(u8, asm_str, " \n\r\t"), 10) catch 0;
    alloc.free(asm_str);
    const inc_str = cmdOutput(alloc, io, &.{ "sh", "-c", "find kernel -name '*.inc' 2>/dev/null | wc -l" }, 32) catch try alloc.dupe(u8, "0");
    const inc_files = std.fmt.parseInt(u32, mem.trim(u8, inc_str, " \n\r\t"), 10) catch 0;
    alloc.free(inc_str);
    const loc_str = cmdOutput(alloc, io, &.{ "sh", "-c", "find kernel -name '*.asm' -o -name '*.inc' -o -name '*.S' 2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}'" }, 64) catch try alloc.dupe(u8, "0");
    const total_loc = std.fmt.parseInt(u32, mem.trim(u8, loc_str, " \n\r\t"), 10) catch 0;
    alloc.free(loc_str);

    const mod_names = comptime [_]struct { name: []const u8, dir: []const u8 }{
        .{ .name = "wasm", .dir = "kernel/x86_64/wasm" },
        .{ .name = "driver", .dir = "kernel/x86_64/drv" },
        .{ .name = "crypto", .dir = "kernel/x86_64/crypto" },
        .{ .name = "rt", .dir = "kernel/x86_64/rt" },
        .{ .name = "net", .dir = "kernel/x86_64/net" },
        .{ .name = "tpm", .dir = "kernel/x86_64/tpm" },
        .{ .name = "ui", .dir = "kernel/x86_64/ui" },
        .{ .name = "object", .dir = "kernel/x86_64/object" },
        .{ .name = "pi", .dir = "kernel/arm/pi" },
    };
    const modules = try alloc.alloc(ModuleLoc, mod_names.len);
    for (mod_names, modules) |entry, *m| {
        const dir = entry.dir;
        const sh_cmd = try std.fmt.allocPrint(alloc, "find {s} -name '*.asm' -o -name '*.inc' -o -name '*.S' 2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{{print $1}}'", .{dir});
        defer alloc.free(sh_cmd);
        const result = std.process.run(alloc, io, .{
            .argv = &.{ "sh", "-c", sh_cmd },
            .stdout_limit = std.Io.Limit.limited(32),
        }) catch {
            m.* = .{ .name = entry.name, .loc = 0 };
            continue;
        };
        defer alloc.free(result.stdout);
        defer alloc.free(result.stderr);
        m.* = .{ .name = entry.name, .loc = std.fmt.parseInt(u32, mem.trim(u8, result.stdout, " \n\r\t"), 10) catch 0 };
    }

    const test_names = comptime [_][]const u8{ "ctype", "clock", "sw_fb", "http", "serial", "render_ir", "fe_mul", "acpi" };
    const tests = try alloc.alloc(TestSuite, test_names.len);
    for (test_names, tests) |tname, *t| {
        const sh_cmd = try std.fmt.allocPrint(alloc, "./build.sh test-{s} 2>&1 | tail -3", .{tname});
        defer alloc.free(sh_cmd);
        const result = std.process.run(alloc, io, .{
            .argv = &.{ "sh", "-c", sh_cmd },
            .stdout_limit = std.Io.Limit.limited(256),
        }) catch {
            t.* = .{ .name = tname, .passed = 0, .total = 0 };
            continue;
        };
        defer alloc.free(result.stderr);
        const passed = mem.indexOf(u8, result.stdout, "PASS") != null;
        const failed = mem.indexOf(u8, result.stdout, "FAIL") != null;
        alloc.free(result.stdout);
        t.* = .{ .name = tname, .passed = if (passed) 1 else 0, .total = if (passed or failed) 1 else 0 };
    }

    const cmt_result = std.process.run(alloc, io, .{
        .argv = &.{ "git", "log", "--oneline", "-5" },
        .stdout_limit = std.Io.Limit.limited(512),
    }) catch {
        return BuildData{
            .git_hash = git_hash,
            .branch = branch,
            .commit_count = commit_count,
            .asm_files = asm_files,
            .inc_files = inc_files,
            .total_loc = total_loc,
            .artifacts = try alloc.dupe(Artifact, &.{}),
            .modules = modules,
            .tests = tests,
            .commits = try alloc.dupe([]const u8, &.{}),
        };
    };
    defer alloc.free(cmt_result.stderr);
    var commit_list = try std.ArrayList([]const u8).initCapacity(alloc, 0);
    var rest = cmt_result.stdout;
    while (mem.indexOfScalar(u8, rest, '\n')) |nl| {
        const line = mem.trim(u8, rest[0..nl], " \n\r\t");
        if (mem.indexOf(u8, line, " ")) |sp| {
            const msg = mem.trim(u8, line[sp + 1 ..], " ");
            if (msg.len > 0) {
                commit_list.append(alloc, try alloc.dupe(u8, msg)) catch {};
            }
        }
        rest = rest[nl + 1 ..];
    }
    alloc.free(cmt_result.stdout);

    const cwd = std.Io.Dir.cwd();
    const artifact_entries = comptime [_]struct { name: []const u8, path: []const u8 }{
        .{ .name = "kernel.elf", .path = ".build/kernel/kernel.elf" },
        .{ .name = "kernel.bin", .path = ".build/kernel/kernel.bin" },
        .{ .name = "kernel.efi", .path = ".build/kernel/kernel.efi" },
    };
    const artifacts = try alloc.alloc(Artifact, artifact_entries.len);
    for (artifact_entries, artifacts) |entry, *a| {
        const st = cwd.statFile(io, entry.path, .{}) catch {
            a.* = .{ .name = entry.name, .size_bytes = 0 };
            continue;
        };
        a.* = .{ .name = entry.name, .size_bytes = @intCast(st.size) };
    }

    return BuildData{
        .git_hash = git_hash,
        .branch = branch,
        .commit_count = commit_count,
        .asm_files = asm_files,
        .inc_files = inc_files,
        .total_loc = total_loc,
        .artifacts = artifacts,
        .modules = modules,
        .tests = tests,
        .commits = try commit_list.toOwnedSlice(alloc),
    };
}

fn iconTag(ic: icon_mod.Icon) u16 {
    return common.optionalIconTag(ic);
}

fn sizeLabel(buf: *[128]u8, bytes: u64) []const u8 {
    if (bytes > 1024 * 1024) {
        return std.fmt.bufPrint(buf, "{d:.1} MB", .{@as(f32, @floatFromInt(bytes)) / (1024 * 1024)}) catch "?";
    } else if (bytes > 1024) {
        return std.fmt.bufPrint(buf, "{} KB", .{bytes / 1024}) catch "?";
    } else {
        return std.fmt.bufPrint(buf, "{} B", .{bytes}) catch "?";
    }
}

fn renderPPM(alloc: std.mem.Allocator, io: std.Io, data: BuildData) !void {
    var scene_commands: [max_commands]ui.Command = undefined;
    var scene = ui.Scene.init(&scene_commands);

    try renderLayout(&scene, data);

    const pixels = try alloc.alloc(ui.Color, W * H);
    defer alloc.free(pixels);

    var ir_storage = IrStorage{};
    const buffers = ir_storage.buffers();
    var font_atlas: renderer_font_atlas.Atlas = undefined;
    font_atlas.initUtf8();
    try renderer_pipeline.packScene(buffers, &font_atlas, scene.written());

    const surface = try renderer_software.Framebuffer.init(W, H, pixels);
    surface.clear(.bg);
    const receipt = try surface.renderIr(buffers, renderer_pipeline.softwareResources(&font_atlas, null));
    if (!receipt.valid()) return error.RenderFailed;

    try std.Io.Dir.cwd().createDirPath(io, ".build/app");
    const file = try std.Io.Dir.cwd().createFile(io, ".build/app/build_dashboard.ppm", .{ .truncate = true });
    defer file.close(io);

    var header: [64]u8 = undefined;
    const header_bytes = try std.fmt.bufPrint(&header, "P6\n{} {}\n255\n", .{ W, H });
    try file.writeStreamingAll(io, header_bytes);

    for (pixels) |pixel| {
        try file.writeStreamingAll(io, &.{ pixel.r, pixel.g, pixel.b });
    }
}

fn renderLayout(scene: *ui.Scene, data: BuildData) !void {
    var buf: [128]u8 = undefined;

    const header = ui.Node{
        .stack = .{
            .axis = .row,
            .gap = 8,
            .cross_align = .start,
            .children = &.{
                .{ .icon = .{ .label = "", .icon = iconTag(.dashboard) } },
                component_union.textNode("Build Dashboard"),
                component_union.textNode(data.branch),
                component_union.textNode(data.git_hash),
            },
        },
    };

    const total_files = data.asm_files + data.inc_files;
    const total_str = std.fmt.bufPrint(&buf, "{}", .{total_files}) catch "?";
    const loc_str = std.fmt.bufPrint(&buf, "{}", .{data.total_loc}) catch "?";
    const mod_count_str = std.fmt.bufPrint(&buf, "{}", .{data.modules.len}) catch "?";
    const test_count_str = std.fmt.bufPrint(&buf, "{}", .{data.tests.len}) catch "?";

    const c1 = component_union.cardNode("ASM Files", total_str, .elevated);
    const c2 = component_union.cardNode("Lines of Code", loc_str, .elevated);
    const c3 = component_union.cardNode("Subsystems", mod_count_str, .elevated);
    const c4 = component_union.cardNode("Test Suites", test_count_str, .elevated);

    var max_size: u64 = 0;
    for (data.artifacts) |a| {
        if (a.size_bytes > max_size) max_size = a.size_bytes;
    }
    if (max_size == 0) max_size = 1;

    var art_children: [16]ui.Node = undefined;
    var art_count: usize = 0;
    art_children[art_count] = component_union.textNode("Build Artifacts");
    art_count += 1;
    for (data.artifacts) |a| {
        if (art_count >= art_children.len) break;
        const p = @as(f32, @floatFromInt(a.size_bytes)) / @as(f32, @floatFromInt(max_size));
        const sl = sizeLabel(&buf, a.size_bytes);
        art_children[art_count] = ui.Node{
            .stack = .{
                .axis = .row,
                .gap = 6,
                .cross_align = .center,
                .children = &.{
                    .{ .text = .{ .value = a.name } },
                    .{ .text = .{ .value = sl } },
                    component_union.progressNode(p),
                },
            },
        };
        art_count += 1;
    }

    var max_loc: u32 = 0;
    for (data.modules) |m| {
        if (m.loc > max_loc) max_loc = m.loc;
    }
    if (max_loc == 0) max_loc = 1;

    var mod_children: [16]ui.Node = undefined;
    var mod_count: usize = 0;
    mod_children[mod_count] = component_union.textNode("Subsystem LOC");
    mod_count += 1;
    for (data.modules) |m| {
        if (mod_count >= mod_children.len) break;
        const p = @as(f32, @floatFromInt(m.loc)) / @as(f32, @floatFromInt(max_loc));
        const ml = std.fmt.bufPrint(&buf, "{}", .{m.loc}) catch "?";
        mod_children[mod_count] = ui.Node{
            .stack = .{
                .axis = .row,
                .gap = 6,
                .cross_align = .center,
                .children = &.{
                    .{ .text = .{ .value = m.name } },
                    .{ .text = .{ .value = ml } },
                    component_union.progressNode(p),
                },
            },
        };
        mod_count += 1;
    }

    var test_children: [16]ui.Node = undefined;
    var test_count: usize = 0;
    test_children[test_count] = component_union.textNode("Test Results");
    test_count += 1;
    for (data.tests) |t| {
        if (test_count >= test_children.len) break;
        const pass = t.passed == t.total and t.total > 0;
        const icon_id = if (pass) iconTag(.circle_check) else iconTag(.circle_x);
        const pl = std.fmt.bufPrint(&buf, "{}/{}", .{ t.passed, t.total }) catch "?";
        test_children[test_count] = ui.Node{
            .stack = .{
                .axis = .row,
                .gap = 4,
                .cross_align = .center,
                .children = &.{
                    .{ .icon = .{ .label = "", .icon = icon_id } },
                    .{ .text = .{ .value = t.name } },
                    .{ .text = .{ .value = pl } },
                },
            },
        };
        test_count += 1;
    }

    var cmt_children: [16]ui.Node = undefined;
    var cmt_count: usize = 0;
    cmt_children[cmt_count] = component_union.textNode("Recent Commits");
    cmt_count += 1;
    for (data.commits) |msg| {
        if (cmt_count >= cmt_children.len) break;
        cmt_children[cmt_count] = ui.Node{
            .stack = .{
                .axis = .row,
                .gap = 4,
                .cross_align = .center,
                .children = &.{
                    .{ .icon = .{ .label = "", .icon = iconTag(.git_commit) } },
                    .{ .text = .{ .value = msg } },
                },
            },
        };
        cmt_count += 1;
    }

    const cell_count = 9;
    var layout_nodes: [cell_count]layout_mod.Node = undefined;
    var ui_nodes: [cell_count]ui.Node = undefined;

    layout_nodes[0] = .{ .column_span = 8, .row_span = 1 };
    ui_nodes[0] = header;
    layout_nodes[1] = .{ .column_span = 2, .row_span = 1 };
    ui_nodes[1] = c1;
    layout_nodes[2] = .{ .column_span = 2, .row_span = 1 };
    ui_nodes[2] = c2;
    layout_nodes[3] = .{ .column_span = 2, .row_span = 1 };
    ui_nodes[3] = c3;
    layout_nodes[4] = .{ .column_span = 2, .row_span = 1 };
    ui_nodes[4] = c4;
    layout_nodes[5] = .{ .column_span = 4, .row_span = 3 };
    ui_nodes[5] = .{ .stack = .{ .axis = .column, .gap = 4, .padding = 0, .children = art_children[0..art_count] } };
    layout_nodes[6] = .{ .column_span = 4, .row_span = 3 };
    ui_nodes[6] = .{ .stack = .{ .axis = .column, .gap = 4, .padding = 0, .children = mod_children[0..mod_count] } };
    layout_nodes[7] = .{ .column_span = 8, .row_span = 2 };
    ui_nodes[7] = .{ .stack = .{ .axis = .column, .gap = 4, .padding = 0, .children = test_children[0..test_count] } };
    layout_nodes[8] = .{ .column_span = 8, .row_span = 1 };
    ui_nodes[8] = .{ .stack = .{ .axis = .column, .gap = 4, .padding = 0, .children = cmt_children[0..cmt_count] } };

    const layout_children = [_]*const layout_mod.Node{
        &layout_nodes[0], &layout_nodes[1], &layout_nodes[2],
        &layout_nodes[3], &layout_nodes[4], &layout_nodes[5],
        &layout_nodes[6], &layout_nodes[7], &layout_nodes[8],
    };

    const bento = layout_mod.Node{
        .kind = .bento_grid,
        .selected = 8,
        .gap = 12,
        .padding = 24,
        .children = &layout_children,
    };

    const full_bounds = ui.Rect.init(0, 0, @floatFromInt(W), @floatFromInt(H));

    for (0..cell_count) |i| {
        const cell_bounds = bento.childBounds(i, full_bounds) catch continue;
        if (i >= 5) {
            try scene.pushRect(cell_bounds, ui.Color.panel, .fill, 6, 0);
            try scene.pushRect(cell_bounds, ui.Color.border, .border, 6, 0);
        }
        node_renderer.renderNode(component_union.Component, scene, cell_bounds, ui_nodes[i], .{}) catch |err| {
            return err;
        };
    }
}
