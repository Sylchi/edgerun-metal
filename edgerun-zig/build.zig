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

    const pi_usb_boot_host_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/pi_usb_boot_host.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_pi_usb_boot_host_tests = b.addRunArtifact(pi_usb_boot_host_tests);
    test_step.dependOn(&run_pi_usb_boot_host_tests.step);

    const pi_usb_control_host_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/pi_usb_control_host.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_pi_usb_control_host_tests = b.addRunArtifact(pi_usb_control_host_tests);
    test_step.dependOn(&run_pi_usb_control_host_tests.step);

    const clock_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/clock.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_clock_tests = b.addRunArtifact(clock_tests);
    const clock_test_step = b.step("clock-test", "Run Zig clock tests");
    clock_test_step.dependOn(&run_clock_tests.step);

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

    const ui_core_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/ui.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_ui_core_tests = b.addRunArtifact(ui_core_tests);
    const ui_core_test_step = b.step("ui-core-test", "Run Zig UI core tests");
    ui_core_test_step.dependOn(&run_ui_core_tests.step);

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

    const ui_bench = b.addExecutable(.{
        .name = "edgerun-ui-bench-zig",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/ui_bench.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_ui_bench = b.addRunArtifact(ui_bench);
    const ui_bench_step = b.step("ui-bench", "Benchmark the Zig UI software renderer");
    ui_bench_step.dependOn(&run_ui_bench.step);

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

    const pi_usb_boot_host = b.addExecutable(.{
        .name = "edgerun-pi-usb-boot-host",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/pi_usb_boot_host.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const pi_usb_load = b.addRunArtifact(pi_usb_boot_host);
    if (b.args) |args| pi_usb_load.addArgs(args);
    const pi_usb_load_step = b.step("pi-usb-load", "Load the Pi Zero W v1.1 bootcode over Linux usbfs without external dependencies");
    pi_usb_load_step.dependOn(&pi_usb_load.step);

    const pi_usb_control_host = b.addExecutable(.{
        .name = "edgerun-pi-usb-control-host",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/pi_usb_control_host.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const pi_usb_control = b.addRunArtifact(pi_usb_control_host);
    if (b.args) |args| pi_usb_control.addArgs(args);
    const pi_usb_control_step = b.step("pi-usb-control", "Send Edgerun Pi USB control commands over Linux usbfs without external dependencies");
    pi_usb_control_step.dependOn(&pi_usb_control.step);
}
