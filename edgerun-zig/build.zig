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

    const identity_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/identity.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_identity_tests = b.addRunArtifact(identity_tests);
    const identity_test_step = b.step("identity-test", "Run Zig identity tests");
    identity_test_step.dependOn(&run_identity_tests.step);

    const object_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/object.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_object_tests = b.addRunArtifact(object_tests);
    const object_test_step = b.step("object-test", "Run Zig object tests");
    object_test_step.dependOn(&run_object_tests.step);

    const storage_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/store.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_storage_tests = b.addRunArtifact(storage_tests);
    const storage_test_step = b.step("storage-test", "Run Zig storage tests");
    storage_test_step.dependOn(&run_storage_tests.step);

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

    const tpm_real_check = b.addExecutable(.{
        .name = "edgerun-tpm-real-check-zig",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tpm_real_check.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_tpm_real_check = b.addRunArtifact(tpm_real_check);
    const tpm_real_check_step = b.step("real-tpm", "Run TPM checks against /dev/tpmrm0");
    tpm_real_check_step.dependOn(&run_tpm_real_check.step);
}
