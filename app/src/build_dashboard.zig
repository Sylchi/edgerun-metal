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

const SourceStats = struct {
    asm_files: u32 = 0,
    inc_files: u32 = 0,
    loc: u32 = 0,
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
    for (data.tests) |t| alloc.free(t.name);
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

fn countLines(bytes: []const u8) u32 {
    var lines: u32 = 0;
    for (bytes) |c| {
        if (c == '\n') lines += 1;
    }
    if (bytes.len > 0 and bytes[bytes.len - 1] != '\n') lines += 1;
    return lines;
}

fn collectSourceStats(alloc: std.mem.Allocator, io: std.Io, root_path: []const u8) !SourceStats {
    const cwd = std.Io.Dir.cwd();
    const root = try cwd.openDir(io, root_path, .{ .iterate = true });
    defer root.close(io);

    var walker = try root.walk(alloc);
    defer walker.deinit();

    var stats: SourceStats = .{};
    while (try walker.next(io)) |entry| {
        if (entry.kind != .file) continue;

        const is_asm = mem.endsWith(u8, entry.basename, ".asm") or mem.endsWith(u8, entry.basename, ".S");
        const is_inc = mem.endsWith(u8, entry.basename, ".inc");
        if (!is_asm and !is_inc) continue;

        if (is_asm) stats.asm_files += 1;
        if (is_inc) stats.inc_files += 1;

        const source = try root.readFileAlloc(io, entry.path, alloc, .limited(16 * 1024 * 1024));
        defer alloc.free(source);
        stats.loc += countLines(source);
    }

    return stats;
}

fn nextField(line: *[]const u8) []const u8 {
    const value = line.*;
    if (mem.indexOfScalar(u8, value, '\t')) |idx| {
        line.* = value[idx + 1 ..];
        return value[0..idx];
    }
    line.* = "";
    return value;
}

fn collectDashboardTestTargets(alloc: std.mem.Allocator, io: std.Io) ![]const []const u8 {
    const raw = try cmdOutput(alloc, io, &.{ "../build.sh", "test-list" }, 16 * 1024);
    defer alloc.free(raw);

    var targets: std.ArrayList([]const u8) = .empty;
    var rest = raw;
    var line_index: usize = 0;
    while (mem.indexOfScalar(u8, rest, '\n')) |nl| {
        defer line_index += 1;
        var line: []const u8 = rest[0..nl];
        rest = rest[nl + 1 ..];
        if (line_index == 0 or line.len == 0) continue;

        const target = nextField(&line);
        const category = nextField(&line);
        _ = nextField(&line); // subsystem
        const default = nextField(&line);
        if (!mem.eql(u8, default, "yes")) continue;
        if (mem.eql(u8, category, "emulator")) continue;
        try targets.append(alloc, try alloc.dupe(u8, target));
        if (targets.items.len == 8) break;
    }

    return targets.toOwnedSlice(alloc);
}

fn collectDashboardTestResults(alloc: std.mem.Allocator, io: std.Io) ![]TestSuite {
    const targets = try collectDashboardTestTargets(alloc, io);
    defer {
        for (targets) |target| alloc.free(target);
        alloc.free(targets);
    }

    var argv: std.ArrayList([]const u8) = .empty;
    try argv.append(alloc, "../build.sh");
    try argv.append(alloc, "test-status");
    for (targets) |target| try argv.append(alloc, target);
    const args = try argv.toOwnedSlice(alloc);
    defer alloc.free(args);

    const result = try std.process.run(alloc, io, .{
        .argv = args,
        .stdout_limit = std.Io.Limit.limited(64 * 1024),
    });
    defer alloc.free(result.stderr);
    defer alloc.free(result.stdout);

    var tests: std.ArrayList(TestSuite) = .empty;
    var rest = result.stdout;
    var line_index: usize = 0;
    while (mem.indexOfScalar(u8, rest, '\n')) |nl| {
        defer line_index += 1;
        var line: []const u8 = rest[0..nl];
        rest = rest[nl + 1 ..];
        if (line_index == 0 or line.len == 0) continue;

        const target = nextField(&line);
        _ = nextField(&line); // category
        _ = nextField(&line); // subsystem
        const status = nextField(&line);
        const pass = mem.eql(u8, status, "pass");
        try tests.append(alloc, .{
            .name = try alloc.dupe(u8, target),
            .passed = if (pass) 1 else 0,
            .total = 1,
        });
    }

    return tests.toOwnedSlice(alloc);
}

fn collectData(alloc: std.mem.Allocator, io: std.Io) !BuildData {
    const git_hash = cmdOutput(alloc, io, &.{ "git", "rev-parse", "--short", "HEAD" }, 64) catch try alloc.dupe(u8, "unknown");
    const branch = cmdOutput(alloc, io, &.{ "git", "branch", "--show-current" }, 64) catch try alloc.dupe(u8, "main");
    const count_str = cmdOutput(alloc, io, &.{ "git", "rev-list", "--count", "HEAD" }, 32) catch try alloc.dupe(u8, "0");
    const commit_count = std.fmt.parseInt(u32, mem.trim(u8, count_str, " \n\r\t"), 10) catch 0;
    alloc.free(count_str);
    const kernel_stats = try collectSourceStats(alloc, io, "../kernel");
    const asm_files = kernel_stats.asm_files;
    const inc_files = kernel_stats.inc_files;
    const total_loc = kernel_stats.loc;

    const mod_names = comptime [_]struct { name: []const u8, dir: []const u8 }{
        .{ .name = "wasm", .dir = "../kernel/x86_64/wasm" },
        .{ .name = "driver", .dir = "../kernel/driver" },
        .{ .name = "crypto", .dir = "../kernel/x86_64/crypto" },
        .{ .name = "rt", .dir = "../kernel/x86_64/rt" },
        .{ .name = "net", .dir = "../kernel/x86_64/net" },
        .{ .name = "tpm", .dir = "../kernel/x86_64/tpm" },
        .{ .name = "ui", .dir = "../kernel/x86_64/ui" },
        .{ .name = "object", .dir = "../kernel/x86_64/object" },
        .{ .name = "pi", .dir = "../kernel/arm/pi" },
    };
    const modules = try alloc.alloc(ModuleLoc, mod_names.len);
    for (mod_names, modules) |entry, *m| {
        m.* = .{ .name = entry.name, .loc = (try collectSourceStats(alloc, io, entry.dir)).loc };
    }

    const tests = try collectDashboardTestResults(alloc, io);

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
        .{ .name = "kernel.elf", .path = "../.build/kernel/kernel.elf" },
        .{ .name = "kernel.bin", .path = "../.build/kernel/kernel.bin" },
        .{ .name = "kernel.efi", .path = "../.build/kernel/kernel.efi" },
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
