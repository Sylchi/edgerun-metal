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

    const sdk_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/sdk.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_sdk_tests = b.addRunArtifact(sdk_tests);
    const sdk_test_step = b.step("sdk-test", "Run Zig SDK tests");
    sdk_test_step.dependOn(&run_sdk_tests.step);

    const sdk_cli = b.addExecutable(.{
        .name = "edgerun-sdk",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/sdk_cli.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_sdk_cli = b.addRunArtifact(sdk_cli);
    if (b.args) |args| run_sdk_cli.addArgs(args);
    const sdk_cli_step = b.step("sdk-cli", "Run the deterministic Edgerun SDK configuration CLI");
    sdk_cli_step.dependOn(&run_sdk_cli.step);

    const sdk_bench = b.addExecutable(.{
        .name = "edgerun-sdk-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/sdk_bench.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_sdk_bench = b.addRunArtifact(sdk_bench);
    const sdk_bench_step = b.step("sdk-bench", "Benchmark deterministic Edgerun SDK setup and simulation");
    sdk_bench_step.dependOn(&run_sdk_bench.step);

    const media_video_dump = b.addExecutable(.{
        .name = "edgerun-media-video-dump",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/media_video_dump.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_media_video_dump = b.addRunArtifact(media_video_dump);
    if (b.args) |args| run_media_video_dump.addArgs(args);
    const media_video_dump_step = b.step("media-video-dump", "Decode a VP8 IVF/WebM file to PPM frames");
    media_video_dump_step.dependOn(&run_media_video_dump.step);

    const media_video_dump_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/media_video_dump.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_media_video_dump_tests = b.addRunArtifact(media_video_dump_tests);
    const media_video_dump_test_step = b.step("media-video-dump-test", "Run media video dump host-tool tests");
    media_video_dump_test_step.dependOn(&run_media_video_dump_tests.step);

    const ui_core_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/ui_core_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_ui_core_tests = b.addRunArtifact(ui_core_tests);
    const ui_core_test_step = b.step("ui-core-test", "Run Zig UI core tests");
    ui_core_test_step.dependOn(&run_ui_core_tests.step);

    const wasm_compiler_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("compiler/zig/src/edgerun_wasm_compiler.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_wasm_compiler_tests = b.addRunArtifact(wasm_compiler_tests);
    const wasm_compiler_test_step = b.step("wasm-compiler-test", "Run EdgeRun freestanding compiler ABI tests");
    wasm_compiler_test_step.dependOn(&run_wasm_compiler_tests.step);
    test_step.dependOn(&run_wasm_compiler_tests.step);

    const component_gallery_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/component_gallery.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_component_gallery_tests = b.addRunArtifact(component_gallery_tests);
    const component_gallery_test_step = b.step("component-gallery-test", "Run canonical component gallery tests");
    component_gallery_test_step.dependOn(&run_component_gallery_tests.step);

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

    const wayland_window = b.addExecutable(.{
        .name = "edgerun-wayland-window",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/wayland_window_host.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_wayland_window = b.addRunArtifact(wayland_window);
    if (b.args) |args| run_wayland_window.addArgs(args);
    const wayland_window_step = b.step("wayland-window", "Open a native Wayland shm window using canonical UI IR");
    wayland_window_step.dependOn(&run_wayland_window.step);

    const wayland_window_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/wayland_window_host.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_wayland_window_tests = b.addRunArtifact(wayland_window_tests);
    const wayland_window_test_step = b.step("wayland-window-test", "Run native Wayland host protocol tests");
    wayland_window_test_step.dependOn(&run_wayland_window_tests.step);
    test_step.dependOn(&run_wayland_window_tests.step);

    const xdg_shell_header_cmd = b.addSystemCommand(&.{
        "wayland-scanner",
        "client-header",
        "/usr/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml",
    });
    const xdg_shell_header = xdg_shell_header_cmd.addOutputFileArg("xdg-shell-client-protocol.h");
    const xdg_shell_code_cmd = b.addSystemCommand(&.{
        "wayland-scanner",
        "private-code",
        "/usr/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml",
    });
    const xdg_shell_code = xdg_shell_code_cmd.addOutputFileArg("xdg-shell-protocol.c");
    const wayland_egl_window = b.addExecutable(.{
        .name = "edgerun-wayland-egl-window",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/wayland_egl_host.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    wayland_egl_window.root_module.addIncludePath(xdg_shell_header.dirname());
    wayland_egl_window.root_module.addCSourceFile(.{ .file = xdg_shell_code });
    wayland_egl_window.root_module.linkSystemLibrary("c", .{});
    wayland_egl_window.root_module.linkSystemLibrary("wayland-client", .{});
    wayland_egl_window.root_module.linkSystemLibrary("wayland-egl", .{});
    wayland_egl_window.root_module.linkSystemLibrary("EGL", .{});
    wayland_egl_window.root_module.linkSystemLibrary("GLESv2", .{});
    wayland_egl_window.step.dependOn(&xdg_shell_header_cmd.step);
    wayland_egl_window.step.dependOn(&xdg_shell_code_cmd.step);
    const run_wayland_egl_window = b.addRunArtifact(wayland_egl_window);
    if (b.args) |args| run_wayland_egl_window.addArgs(args);
    const wayland_egl_window_step = b.step("wayland-egl-window", "Open a native Wayland EGL/GLES window using canonical UI IR");
    wayland_egl_window_step.dependOn(&run_wayland_egl_window.step);

    const drm_gbm_window = b.addExecutable(.{
        .name = "edgerun-drm-gbm-window",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/drm_gbm_host.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    drm_gbm_window.root_module.addIncludePath(.{ .cwd_relative = "/usr/include/libdrm" });
    drm_gbm_window.root_module.linkSystemLibrary("c", .{});
    drm_gbm_window.root_module.linkSystemLibrary("gbm", .{});
    drm_gbm_window.root_module.linkSystemLibrary("drm", .{});
    drm_gbm_window.root_module.linkSystemLibrary("EGL", .{});
    drm_gbm_window.root_module.linkSystemLibrary("GLESv2", .{});
    const run_drm_gbm_window = b.addRunArtifact(drm_gbm_window);
    if (b.args) |args| run_drm_gbm_window.addArgs(args);
    const drm_gbm_window_step = b.step("drm-gbm-window", "Render canonical UI IR through EGL/GLES to a DRM/GBM scanout surface");
    drm_gbm_window_step.dependOn(&run_drm_gbm_window.step);

    const drm_gbm_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/drm_gbm_host.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    drm_gbm_tests.root_module.addIncludePath(.{ .cwd_relative = "/usr/include/libdrm" });
    drm_gbm_tests.root_module.linkSystemLibrary("c", .{});
    drm_gbm_tests.root_module.linkSystemLibrary("gbm", .{});
    drm_gbm_tests.root_module.linkSystemLibrary("drm", .{});
    drm_gbm_tests.root_module.linkSystemLibrary("EGL", .{});
    drm_gbm_tests.root_module.linkSystemLibrary("GLESv2", .{});
    const run_drm_gbm_tests = b.addRunArtifact(drm_gbm_tests);
    const drm_gbm_test_step = b.step("drm-gbm-test", "Run DRM/GBM host tests");
    drm_gbm_test_step.dependOn(&run_drm_gbm_tests.step);
    test_step.dependOn(&run_drm_gbm_tests.step);

    const app_runtime_target = b.resolveTargetQuery(std.Target.Query.parse(.{
        .arch_os_abi = "wasm32-freestanding",
    }) catch unreachable);
    const wasm_compiler = b.addExecutable(.{
        .name = "edgerun-wasm-compiler",
        .root_module = b.createModule(.{
            .root_source_file = b.path("compiler/zig/src/edgerun_wasm_compiler.zig"),
            .target = app_runtime_target,
            .optimize = optimize,
            .single_threaded = true,
        }),
    });
    wasm_compiler.entry = .disabled;
    wasm_compiler.export_memory = true;
    wasm_compiler.root_module.export_symbol_names = &.{
        "er_wasm_compiler_abi_version",
        "er_wasm_compiler_init",
        "er_wasm_compiler_status",
        "er_wasm_compiler_compile_wasm",
        "er_wasm_compiler_compile_wasm_metadata",
        "er_wasm_compiler_output_ptr",
        "er_wasm_compiler_output_len",
        "er_wasm_compiler_diagnostic_ptr",
        "er_wasm_compiler_diagnostic_len",
    };
    const install_wasm_compiler = b.addInstallArtifact(wasm_compiler, .{});
    const embed_file_zig_module = b.createModule(.{
        .root_source_file = b.path("src/embed_file_zig.zig"),
        .target = b.graph.host,
        .optimize = optimize,
    });
    const embed_file_zig = b.addExecutable(.{
        .name = "edgerun-embed-file-zig",
        .root_module = embed_file_zig_module,
    });
    const run_embed_wasm_compiler = b.addRunArtifact(embed_file_zig);
    run_embed_wasm_compiler.addArg("file");
    run_embed_wasm_compiler.addFileArg(wasm_compiler.getEmittedBin());
    const embedded_wasm_compiler = run_embed_wasm_compiler.addOutputFileArg("embedded_wasm_compiler.zig");
    const run_embed_source_object = b.addRunArtifact(embed_file_zig);
    run_embed_source_object.addArg("workspace");
    run_embed_source_object.addDirectoryArg(b.path("."));
    run_embed_source_object.addFileArg(wasm_compiler.getEmittedBin());
    const embedded_source_object = run_embed_source_object.addOutputFileArg("embedded_source_object.zig");
    const app_runtime = b.addExecutable(.{
        .name = "edgerun-app-runtime",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/app_runtime.zig"),
            .target = app_runtime_target,
            .optimize = optimize,
            .single_threaded = true,
        }),
    });
    app_runtime.root_module.addAnonymousImport("embedded_wasm_compiler", .{
        .root_source_file = embedded_wasm_compiler,
    });
    app_runtime.root_module.addAnonymousImport("embedded_source_object", .{
        .root_source_file = embedded_source_object,
    });
    const wasm_compiler_runner_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/wasm_compiler_runner_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    wasm_compiler_runner_tests.root_module.addAnonymousImport("embedded_wasm_compiler", .{
        .root_source_file = embedded_wasm_compiler,
    });
    wasm_compiler_runner_tests.root_module.addAnonymousImport("embedded_source_object", .{
        .root_source_file = embedded_source_object,
    });
    const run_wasm_compiler_runner_tests = b.addRunArtifact(wasm_compiler_runner_tests);
    const wasm_compiler_runner_test_step = b.step("wasm-compiler-runner-test", "Run embedded compiler through the EdgeRun wasm interpreter");
    wasm_compiler_runner_test_step.dependOn(&run_wasm_compiler_runner_tests.step);
    test_step.dependOn(&run_wasm_compiler_runner_tests.step);
    const wasm_compiler_probe = b.addExecutable(.{
        .name = "edgerun-wasm-compiler-probe",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/wasm_compiler_probe.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    wasm_compiler_probe.root_module.addAnonymousImport("embedded_wasm_compiler", .{
        .root_source_file = embedded_wasm_compiler,
    });
    wasm_compiler_probe.root_module.addAnonymousImport("embedded_source_object", .{
        .root_source_file = embedded_source_object,
    });
    const run_wasm_compiler_probe = b.addRunArtifact(wasm_compiler_probe);
    if (b.args) |args| run_wasm_compiler_probe.addArgs(args);
    const wasm_compiler_probe_step = b.step("wasm-compiler-probe", "Print embedded compiler runtime metrics");
    wasm_compiler_probe_step.dependOn(&run_wasm_compiler_probe.step);
    app_runtime.entry = .disabled;
    app_runtime.export_memory = true;
    app_runtime.stack_size = 8 * 1024 * 1024;
    app_runtime.root_module.export_symbol_names = &.{
        "er_ui_max_width",
        "er_ui_max_height",
        "er_ui_pixels_ptr",
        "er_ui_pixels_len",
        "er_ui_packed_rect_float_stride",
        "er_ui_packed_rect_buffer_ptr",
        "er_ui_packed_rect_buffer_len",
        "er_ui_packed_text_vertex_float_stride",
        "er_ui_packed_text_vertex_buffer_ptr",
        "er_ui_packed_text_vertex_buffer_len",
        "er_ui_packed_icon_vertex_float_stride",
        "er_ui_packed_icon_vertex_buffer_ptr",
        "er_ui_packed_icon_vertex_buffer_len",
        "er_ui_packed_icon_line_vertex_float_stride",
        "er_ui_packed_icon_line_vertex_buffer_ptr",
        "er_ui_packed_icon_line_vertex_buffer_len",
        "er_ui_packed_image_vertex_float_stride",
        "er_ui_packed_image_vertex_buffer_ptr",
        "er_ui_packed_image_vertex_buffer_len",
        "er_ui_packed_overlay_rect_buffer_ptr",
        "er_ui_packed_overlay_rect_buffer_len",
        "er_ui_packed_overlay_text_vertex_buffer_ptr",
        "er_ui_packed_overlay_text_vertex_buffer_len",
        "er_ui_packed_overlay_icon_vertex_buffer_ptr",
        "er_ui_packed_overlay_icon_vertex_buffer_len",
        "er_ui_packed_overlay_icon_line_vertex_buffer_ptr",
        "er_ui_packed_overlay_icon_line_vertex_buffer_len",
        "er_ui_post_image_rgba_ptr",
        "er_ui_post_image_rgba_len",
        "er_ui_post_image_width",
        "er_ui_post_image_height",
        "er_ui_font_atlas_width",
        "er_ui_font_atlas_height",
        "er_ui_font_atlas_ptr",
        "er_ui_font_atlas_generation",
        "er_ui_width",
        "er_ui_height",
        "er_ui_input_ptr",
        "er_ui_input_capacity",
        "er_ui_last_error",
        "er_ui_set_device_scale",
        "er_ui_boot",
        "er_ui_event",
        "er_ui_event_bytes",
        "er_ui_outbox_count",
        "er_ui_outbox_kind",
        "er_ui_outbox_id",
        "er_ui_outbox_target_ptr",
        "er_ui_outbox_target_len",
        "er_ui_outbox_payload_ptr",
        "er_ui_outbox_payload_len",
        "er_ui_outbox_clear",
        "er_ui_bootstrap_js_ptr",
        "er_ui_bootstrap_js_len",
        "er_ui_request_release_artifact_download",
        "er_ui_request_release_artifact_launch",
        "er_ui_build_frame",
        "er_ui_render_frame",
        "er_ui_render_frame_hd",
        "er_ui_render_icon_svg_test",
        "er_ui_render_icon_svg_tuning_test",
    };
    const install_app_runtime = b.addInstallArtifact(app_runtime, .{});
    const install_web_app_runtime = b.addInstallFile(app_runtime.getEmittedBin(), "web/a.wasm");
    const wasm_entry = b.addExecutable(.{
        .name = "edgerun-wasm-entry",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/wasm_entry.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_wasm_entry = b.addRunArtifact(wasm_entry);
    const wasm_entry_html = run_wasm_entry.addOutputFileArg("index.html");
    const install_wasm_entry = b.addInstallFile(wasm_entry_html, "web/index.html");
    const wasm_entry_step = b.step("wasm-entry", "Generate the minimal web host entry point");
    wasm_entry_step.dependOn(&install_wasm_entry.step);
    wasm_entry_step.dependOn(&install_web_app_runtime.step);

    const app_runtime_step = b.step("app-runtime", "Build the host-agnostic app runtime wasm");
    app_runtime_step.dependOn(&install_app_runtime.step);
    app_runtime_step.dependOn(&install_web_app_runtime.step);
    app_runtime_step.dependOn(&install_wasm_compiler.step);
    app_runtime_step.dependOn(&install_wasm_entry.step);

    const uefi_target = b.resolveTargetQuery(std.Target.Query.parse(.{
        .arch_os_abi = "x86_64-uefi",
    }) catch unreachable);
    const immutable_kernel_app_runtime = b.addExecutable(.{
        .name = "BOOTX64.EFI",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/immutable_kernel_app_runtime_uefi.zig"),
            .target = uefi_target,
            // This image runs the native renderer and virtio-gpu path inside QEMU.
            // ReleaseSmall keeps the EFI smaller, but makes frame rendering dramatically slower.
            .optimize = .ReleaseFast,
        }),
    });
    const install_immutable_kernel_app_runtime = b.addInstallArtifact(immutable_kernel_app_runtime, .{
        .dest_dir = .{ .override = .{ .custom = "immutable-kernel-app-runtime" } },
    });
    const immutable_kernel_app_runtime_step = b.step("immutable-kernel-app-runtime-efi", "Build the UEFI app-runtime GOP smoke");
    immutable_kernel_app_runtime_step.dependOn(&install_immutable_kernel_app_runtime.step);

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

    const ifstatus = b.addExecutable(.{
        .name = "edgerun-ifstatus",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/ifstatus.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_ifstatus = b.addRunArtifact(ifstatus);
    if (b.args) |args| run_ifstatus.addArgs(args);
    const ifstatus_step = b.step("ifstatus", "Publish network interface status as codec bytes to stdout");
    ifstatus_step.dependOn(&run_ifstatus.step);

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
