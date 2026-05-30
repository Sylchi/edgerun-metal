const std = @import("std");
const mem = std.mem;
const renderer_font_atlas = @import("render/font_atlas_weighted.zig");
const renderer_ir = @import("render/ir.zig");
const renderer_pipeline = @import("render/pipeline.zig");
const renderer_software = @import("render/backends/software.zig");
const ui = @import("ui/core.zig");
const icon_mod = @import("ui/icon.zig");

const W: usize = 1280;
const H: usize = 720;
const max_commands: usize = 1024;
const max_rects: usize = 4096;
const max_text_vertices: usize = 32768;
const max_icon_vertices: usize = 1024;

const SnapshotIrStorage = renderer_ir.FixedBuffers(
    max_rects,
    max_text_vertices,
    max_icon_vertices,
    0, // overlay_rect_instances
    0, // overlay_icon_vertices_count
    0, // icon_line_vertices_count
    0, // overlay_icon_line_vertices_count
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
        .{ .name = "wasm",   .dir = "kernel/x86_64/wasm" },
        .{ .name = "driver", .dir = "kernel/x86_64/drv" },
        .{ .name = "crypto", .dir = "kernel/x86_64/crypto" },
        .{ .name = "rt",     .dir = "kernel/x86_64/rt" },
        .{ .name = "net",    .dir = "kernel/x86_64/net" },
        .{ .name = "tpm",    .dir = "kernel/x86_64/tpm" },
        .{ .name = "ui",     .dir = "kernel/x86_64/ui" },
        .{ .name = "object", .dir = "kernel/x86_64/object" },
        .{ .name = "pi",     .dir = "kernel/arm/pi" },
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
            .git_hash = git_hash, .branch = branch, .commit_count = commit_count,
            .asm_files = asm_files, .inc_files = inc_files, .total_loc = total_loc,
            .artifacts = try alloc.dupe(Artifact, &.{}),
            .modules = modules, .tests = tests, .commits = try alloc.dupe([]const u8, &.{""}),
        };
    };
    defer alloc.free(cmt_result.stderr);
    var commit_list = try std.ArrayList([]const u8).initCapacity(alloc, 0);
    var rest = cmt_result.stdout;
    while (mem.indexOfScalar(u8, rest, '\n')) |nl| {
        const line = mem.trim(u8, rest[0..nl], " \n\r\t");
        if (mem.indexOf(u8, line, " ")) |sp| {
            const msg = mem.trim(u8, line[sp + 1 ..], " ");
            commit_list.append(alloc, try alloc.dupe(u8, msg)) catch {};
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
        .git_hash = git_hash, .branch = branch, .commit_count = commit_count,
        .asm_files = asm_files, .inc_files = inc_files, .total_loc = total_loc,
        .artifacts = artifacts, .modules = modules, .tests = tests,
        .commits = try commit_list.toOwnedSlice(alloc), // Aligned version: toOwnedSlice(self, gpa)
    };
}

fn renderPPM(alloc: std.mem.Allocator, io: std.Io, data: BuildData) !void {
    var commands: [max_commands]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try renderDashboard(&scene, data);

    const pixels = try alloc.alloc(ui.Color, W * H);
    defer alloc.free(pixels);

    var ir_storage = SnapshotIrStorage{};
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

fn renderDashboard(scene: *ui.Scene, data: BuildData) !void {
    const panel = ui.Color.panel;
    const row = ui.Color.row;
    const border = ui.Color.border;
    const text = ui.Color.text;
    const muted = ui.Color.muted;
    const accent = ui.Color.accent;
    const fail_color = ui.Color{ .r = 240, .g = 80, .b = 80, .a = 255 };
    const success_color = ui.Color{ .r = 80, .g = 200, .b = 120, .a = 255 };

    const margin_x: f32 = 40;
    const col_gap: f32 = 16;
    const section_gap: f32 = 20;
    const card_w: f32 = (W - 2 * margin_x - 3 * col_gap) / 4;
    const card_h: f32 = 72;
    const section_header_h: f32 = 28;
    const row_item_h: f32 = 28;
    const progress_h: f32 = 14;

    var buf: [128]u8 = undefined;
    var y: f32 = 32;
    const in_w = @as(f32, @floatFromInt(W));

    // ── Header ──
    {
        try scene.pushIconQuad(.{ .bounds = ui.Rect.init(margin_x, y + 2, 24, 24), .icon_id = icon_mod.id(.dashboard), .color = accent });
        try scene.pushStrongText(ui.Rect.init(margin_x + 34, y, 280, 26), "Build Dashboard", text);

        const badge_x = in_w - margin_x - 380;
        var badge_bg = accent;
        badge_bg.a = 30;
        const b_label = data.branch;
        const b_w = @as(f32, @floatFromInt(b_label.len)) * 7.5 + 20;
        const badge_b = ui.Rect.init(badge_x, y + 2, b_w, 22);
        try scene.pushRect(badge_b, badge_bg, .fill, 11, 0);
        try scene.pushRect(badge_b, accent, .border, 11, 0);
        try scene.pushAlignedText(ui.Rect.init(badge_b.x, badge_b.y + 2, badge_b.w, 18), b_label, accent, .center);

        const hx = badge_x + b_w + 16;
        try scene.pushIconQuad(.{ .bounds = ui.Rect.init(hx, y + 6, 14, 14), .icon_id = icon_mod.id(.git_commit), .color = muted });
        const hash_label = data.git_hash;
        try scene.pushText(ui.Rect.init(hx + 18, y + 4, 100, 18), hash_label, text);
        const cnt_label = std.fmt.bufPrint(&buf, "{} commits", .{data.commit_count}) catch "?";
        try scene.pushText(ui.Rect.init(hx + 110, y + 4, 120, 18), cnt_label, muted);

        y += 32;
        try scene.pushRect(ui.Rect.init(margin_x, y, in_w - 2 * margin_x, 1), border, .fill, 0, 0);
        y += 12;
    }

    // ── Summary Cards ──
    {
        const vals = [_]u32{
            data.asm_files + data.inc_files,
            data.total_loc,
            @intCast(data.modules.len),
            if (data.tests.len > 0) data.tests[0].passed else 0,
        };
        const icons = [_]icon_mod.Icon{ .file_code, .code, .box, .check };
        const titles = [_][]const u8{ "ASM Files", "Lines of Code", "Subsystems", "Tests" };

        for (&titles, &vals, &icons, 0..) |title, val, ic, i| {
            const cx = margin_x + @as(f32, @floatFromInt(i)) * (card_w + col_gap);
            const cb = ui.Rect.init(cx, y, card_w, card_h);
            try scene.pushRect(cb, panel, .fill, 8, 0);
            try scene.pushRect(cb, border, .border, 8, 0);
            try scene.pushIconQuad(.{ .bounds = ui.Rect.init(cx + 12, y + 10, 20, 20), .icon_id = icon_mod.id(ic), .color = accent });
            try scene.pushText(ui.Rect.init(cx + 40, y + 10, card_w - 52, 18), title, muted);
            const vlabel = std.fmt.bufPrint(&buf, "{}", .{val}) catch "?";
            try scene.pushStrongText(ui.Rect.init(cx + 12, y + 36, card_w - 24, 26), vlabel, text);
        }
        y += card_h + section_gap;
    }

    // ── Build Artifacts ──
    {
        try scene.pushText(ui.Rect.init(margin_x, y, 200, section_header_h), "Build Artifacts", muted);
        try scene.pushRect(ui.Rect.init(margin_x, y + section_header_h, in_w - 2 * margin_x, 1), border, .fill, 0, 0);
        y += section_header_h + 10;

        var max_size: u64 = 0;
        for (data.artifacts) |a| {
            if (a.size_bytes > max_size) max_size = a.size_bytes;
        }
        if (max_size == 0) max_size = 1;

        for (data.artifacts) |artifact| {
            const progress = @as(f32, @floatFromInt(artifact.size_bytes)) / @as(f32, @floatFromInt(max_size));
            const ks = if (artifact.size_bytes > 1024 * 1024)
                (std.fmt.bufPrint(&buf, "{d:.1} MB", .{@as(f32, @floatFromInt(artifact.size_bytes)) / (1024 * 1024)}) catch "? B")
            else if (artifact.size_bytes > 1024)
                (std.fmt.bufPrint(&buf, "{} KB", .{artifact.size_bytes / 1024}) catch "? B")
            else
                (std.fmt.bufPrint(&buf, "{} B", .{artifact.size_bytes}) catch "? B");

            try scene.pushText(ui.Rect.init(margin_x, y + 4, 120, row_item_h), artifact.name, text);
            try scene.pushText(ui.Rect.init(margin_x + 130, y + 4, 100, row_item_h), ks, muted);

            const track = ui.Rect.init(margin_x + 240, y + (row_item_h - progress_h) * 0.5, 300, progress_h);
            try scene.pushRect(track, row, .fill, 7, 0);
            if (progress > 0) {
                try scene.pushRect(ui.Rect.init(track.x, track.y, track.w * progress, track.h), accent, .fill, 7, 0);
            }
            const plabel = std.fmt.bufPrint(&buf, "{d:.0}%", .{progress * 100}) catch "?";
            try scene.pushText(ui.Rect.init(margin_x + 240 + 308, y + 4, 50, row_item_h), plabel, text);
            y += row_item_h + 6;
        }
        y += section_gap - 6;
    }

    // ── Module LOC ──
    {
        try scene.pushText(ui.Rect.init(margin_x, y, 200, section_header_h), "Module Lines of Code", muted);
        try scene.pushRect(ui.Rect.init(margin_x, y + section_header_h, in_w - 2 * margin_x, 1), border, .fill, 0, 0);
        y += section_header_h + 10;

        var max_loc: u32 = 0;
        for (data.modules) |m| {
            if (m.loc > max_loc) max_loc = m.loc;
        }
        if (max_loc == 0) max_loc = 1;

        const loc_bar_w: f32 = 400;
        for (data.modules) |mod_item| {
            const progress = @as(f32, @floatFromInt(mod_item.loc)) / @as(f32, @floatFromInt(max_loc));
            const ll = std.fmt.bufPrint(&buf, "{}", .{mod_item.loc}) catch "?";
            try scene.pushText(ui.Rect.init(margin_x, y + 4, 70, row_item_h), mod_item.name, text);
            try scene.pushText(ui.Rect.init(margin_x + 76, y + 4, 70, row_item_h), ll, muted);

            const track = ui.Rect.init(margin_x + 152, y + (row_item_h - progress_h) * 0.5, loc_bar_w, progress_h);
            try scene.pushRect(track, row, .fill, 7, 0);
            if (progress > 0) {
                try scene.pushRect(ui.Rect.init(track.x, track.y, track.w * progress, track.h), accent, .fill, 7, 0);
            }
            const pl = std.fmt.bufPrint(&buf, "{d:.0}%", .{progress * 100}) catch "?";
            try scene.pushText(ui.Rect.init(margin_x + 152 + loc_bar_w + 10, y + 4, 50, row_item_h), pl, muted);
            y += row_item_h + 6;
        }
        y += section_gap - 6;
    }

    // ── Test Results ──
    {
        try scene.pushText(ui.Rect.init(margin_x, y, 200, section_header_h), "Test Results", muted);
        try scene.pushRect(ui.Rect.init(margin_x, y + section_header_h, in_w - 2 * margin_x, 1), border, .fill, 0, 0);
        y += section_header_h + 10;

        const per_row: usize = 3;
        const col_w = (in_w - 2 * margin_x) / @as(f32, @floatFromInt(per_row));

        for (data.tests, 0..) |ts, i| {
            const r = i / per_row;
            const c = i % per_row;
            if (c == 0 and r > 0) y += row_item_h + 6;
            const tx = margin_x + @as(f32, @floatFromInt(c)) * col_w;
            const pass = ts.passed == ts.total and ts.total > 0;
            try scene.pushIconQuad(.{ .bounds = ui.Rect.init(tx, y + 5, 16, 16), .icon_id = icon_mod.id(if (pass) icon_mod.Icon.circle_check else icon_mod.Icon.circle_x), .color = if (pass) success_color else fail_color });
            try scene.pushText(ui.Rect.init(tx + 22, y + 4, 100, row_item_h), ts.name, text);
            const plabel = std.fmt.bufPrint(&buf, "{}/{}", .{ ts.passed, ts.total }) catch "?";
            try scene.pushText(ui.Rect.init(tx + 120, y + 4, 60, row_item_h), plabel, muted);
        }
        y += row_item_h + section_gap;
    }

    // ── Recent Commits ──
    {
        try scene.pushText(ui.Rect.init(margin_x, y, 200, section_header_h), "Recent Commits", muted);
        try scene.pushRect(ui.Rect.init(margin_x, y + section_header_h, in_w - 2 * margin_x, 1), border, .fill, 0, 0);
        y += section_header_h + 10;

        for (data.commits) |msg| {
            try scene.pushIconQuad(.{ .bounds = ui.Rect.init(margin_x, y + 5, 12, 12), .icon_id = icon_mod.id(.git_commit), .color = muted });
            try scene.pushText(ui.Rect.init(margin_x + 20, y + 2, in_w - 2 * margin_x - 28, row_item_h), msg, text);
            y += row_item_h + 4;
        }
    }
}
