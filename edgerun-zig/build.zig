const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run Zig prototype tests");
    test_step.dependOn(&run_tests.step);

    const ui_snapshot = b.addExecutable(.{
        .name = "edgerun-ui-snapshot-zig",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/ui_snapshot.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_ui_snapshot = b.addRunArtifact(ui_snapshot);
    const ui_snapshot_step = b.step("ui-snapshot", "Render the Zig UI prototype snapshot");
    ui_snapshot_step.dependOn(&run_ui_snapshot.step);
}
