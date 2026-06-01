const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const strip_release = optimize != .Debug;

    const is_x86_64 = target.result.cpu.arch == .x86_64;

    var math_obj: ?std.Build.LazyPath = null;
    var runtime_obj: ?std.Build.LazyPath = null;
    if (is_x86_64) {
        {
            const cmd = b.addSystemCommand(&.{ "yasm", "-f", "elf64", "-I", "../kernel", "../kernel/x86_64/rt/math.asm", "-o" });
            math_obj = cmd.addOutputFileArg("math.o");
        }
        {
            const cmd = b.addSystemCommand(&.{ "yasm", "-f", "elf64", "-I", "../kernel", "../kernel/x86_64/rt/runtime.asm", "-o" });
            runtime_obj = cmd.addOutputFileArg("runtime.o");
        }
    }

    const test_step = b.step("test", "Run Zig prototype tests");

    const pi_usb_boot_host_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/pi_usb_boot_host.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    if (math_obj) |obj| pi_usb_boot_host_tests.root_module.addObjectFile(obj);
    if (runtime_obj) |obj| pi_usb_boot_host_tests.root_module.addObjectFile(obj);

    const run_pi_usb_boot_host_tests = b.addRunArtifact(pi_usb_boot_host_tests);
    test_step.dependOn(&run_pi_usb_boot_host_tests.step);

    const pi_usb_control_host_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/pi_usb_control_host.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    if (math_obj) |obj| pi_usb_control_host_tests.root_module.addObjectFile(obj);
    if (runtime_obj) |obj| pi_usb_control_host_tests.root_module.addObjectFile(obj);

    const run_pi_usb_control_host_tests = b.addRunArtifact(pi_usb_control_host_tests);
    test_step.dependOn(&run_pi_usb_control_host_tests.step);

    const clock_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/clock.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    if (math_obj) |obj| clock_tests.root_module.addObjectFile(obj);
    if (runtime_obj) |obj| clock_tests.root_module.addObjectFile(obj);

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
    if (math_obj) |obj| identity_tests.root_module.addObjectFile(obj);
    if (runtime_obj) |obj| identity_tests.root_module.addObjectFile(obj);

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
    if (math_obj) |obj| object_tests.root_module.addObjectFile(obj);
    if (runtime_obj) |obj| object_tests.root_module.addObjectFile(obj);

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
    if (math_obj) |obj| storage_tests.root_module.addObjectFile(obj);
    if (runtime_obj) |obj| storage_tests.root_module.addObjectFile(obj);

    const run_storage_tests = b.addRunArtifact(storage_tests);
    const storage_test_step = b.step("storage-test", "Run Zig storage tests");
    storage_test_step.dependOn(&run_storage_tests.step);

    const chat_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/encrypted_chat.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    if (math_obj) |obj| chat_tests.root_module.addObjectFile(obj);
    if (runtime_obj) |obj| chat_tests.root_module.addObjectFile(obj);

    const run_chat_tests = b.addRunArtifact(chat_tests);
    const chat_test_step = b.step("chat-test", "Run encrypted chat app state tests");
    chat_test_step.dependOn(&run_chat_tests.step);
    test_step.dependOn(&run_chat_tests.step);

    const chat_ui_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/app_encrypted_chat.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    if (math_obj) |obj| chat_ui_tests.root_module.addObjectFile(obj);
    if (runtime_obj) |obj| chat_ui_tests.root_module.addObjectFile(obj);

    const run_chat_ui_tests = b.addRunArtifact(chat_ui_tests);
    const chat_ui_test_step = b.step("chat-ui-test", "Run encrypted chat app UI tests");
    chat_ui_test_step.dependOn(&run_chat_ui_tests.step);
    test_step.dependOn(&run_chat_ui_tests.step);

    const pipeline_ui_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/app_pipeline_dashboard.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    if (math_obj) |obj| pipeline_ui_tests.root_module.addObjectFile(obj);
    if (runtime_obj) |obj| pipeline_ui_tests.root_module.addObjectFile(obj);

    const run_pipeline_ui_tests = b.addRunArtifact(pipeline_ui_tests);
    const pipeline_ui_test_step = b.step("pipeline-ui-test", "Run user-scheduled pipeline UI tests");
    pipeline_ui_test_step.dependOn(&run_pipeline_ui_tests.step);
    test_step.dependOn(&run_pipeline_ui_tests.step);

    const sdk_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/sdk.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    if (math_obj) |obj| sdk_tests.root_module.addObjectFile(obj);
    if (runtime_obj) |obj| sdk_tests.root_module.addObjectFile(obj);

    const run_sdk_tests = b.addRunArtifact(sdk_tests);
    const sdk_test_step = b.step("sdk-test", "Run Zig SDK tests");
    sdk_test_step.dependOn(&run_sdk_tests.step);

    const sdk_cli = b.addExecutable(.{
        .name = "edgerun-sdk",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/sdk_cli.zig"),
            .target = target,
            .optimize = optimize,
            .strip = strip_release,
        }),
    });
    if (math_obj) |obj| sdk_cli.root_module.addObjectFile(obj);
    if (runtime_obj) |obj| sdk_cli.root_module.addObjectFile(obj);

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
            .strip = strip_release,
        }),
    });
    if (math_obj) |obj| sdk_bench.root_module.addObjectFile(obj);
    if (runtime_obj) |obj| sdk_bench.root_module.addObjectFile(obj);

    const run_sdk_bench = b.addRunArtifact(sdk_bench);
    const sdk_bench_step = b.step("sdk-bench", "Benchmark deterministic Edgerun SDK setup and simulation");
    sdk_bench_step.dependOn(&run_sdk_bench.step);

    const media_video_dump = b.addExecutable(.{
        .name = "edgerun-media-video-dump",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/media_video_dump.zig"),
            .target = target,
            .optimize = optimize,
            .strip = strip_release,
        }),
    });
    if (math_obj) |obj| media_video_dump.root_module.addObjectFile(obj);
    if (runtime_obj) |obj| media_video_dump.root_module.addObjectFile(obj);

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
    if (math_obj) |obj| media_video_dump_tests.root_module.addObjectFile(obj);
    if (runtime_obj) |obj| media_video_dump_tests.root_module.addObjectFile(obj);

    const run_media_video_dump_tests = b.addRunArtifact(media_video_dump_tests);
    const media_video_dump_test_step = b.step("media-video-dump-test", "Run media video dump host-tool tests");
    media_video_dump_test_step.dependOn(&run_media_video_dump_tests.step);

    const ui_core_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/ui/core_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    if (math_obj) |obj| ui_core_tests.root_module.addObjectFile(obj);
    if (runtime_obj) |obj| ui_core_tests.root_module.addObjectFile(obj);

    const run_ui_core_tests = b.addRunArtifact(ui_core_tests);
    const ui_core_test_step = b.step("ui-core-test", "Run Zig UI core tests");
    ui_core_test_step.dependOn(&run_ui_core_tests.step);

    const ui_codec_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/ui_codec_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    if (math_obj) |obj| ui_codec_tests.root_module.addObjectFile(obj);
    if (runtime_obj) |obj| ui_codec_tests.root_module.addObjectFile(obj);

    const run_ui_codec_tests = b.addRunArtifact(ui_codec_tests);
    const ui_codec_test_step = b.step("ui-codec-test", "Run Zig UI codec and stream tests");
    ui_codec_test_step.dependOn(&run_ui_codec_tests.step);
    test_step.dependOn(&run_ui_codec_tests.step);

    const component_gallery_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/ui/component_gallery.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    if (math_obj) |obj| component_gallery_tests.root_module.addObjectFile(obj);
    if (runtime_obj) |obj| component_gallery_tests.root_module.addObjectFile(obj);

    const run_component_gallery_tests = b.addRunArtifact(component_gallery_tests);
    const component_gallery_test_step = b.step("component-gallery-test", "Run canonical component gallery tests");
    component_gallery_test_step.dependOn(&run_component_gallery_tests.step);

    const build_dashboard = b.addExecutable(.{
        .name = "edgerun-build-dashboard",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/build_dashboard.zig"),
            .target = target,
            .optimize = optimize,
            .strip = strip_release,
        }),
    });
    if (math_obj) |obj| build_dashboard.root_module.addObjectFile(obj);
    if (runtime_obj) |obj| build_dashboard.root_module.addObjectFile(obj);

    const run_build_dashboard = b.addRunArtifact(build_dashboard);
    const build_dashboard_step = b.step("build-dashboard", "Render the build dashboard PPM");
    build_dashboard_step.dependOn(&run_build_dashboard.step);

    const chat_preview = b.addExecutable(.{
        .name = "edgerun-chat-preview",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/encrypted_chat_preview.zig"),
            .target = target,
            .optimize = optimize,
            .strip = strip_release,
        }),
    });
    if (math_obj) |obj| chat_preview.root_module.addObjectFile(obj);
    if (runtime_obj) |obj| chat_preview.root_module.addObjectFile(obj);

    const run_chat_preview = b.addRunArtifact(chat_preview);
    const chat_preview_step = b.step("chat-preview", "Render encrypted chat UI preview PPM");
    chat_preview_step.dependOn(&run_chat_preview.step);

    const wayland_window = b.addExecutable(.{
        .name = "edgerun-wayland-window",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/wayland_window_host.zig"),
            .target = target,
            .optimize = optimize,
            .strip = strip_release,
        }),
    });
    if (math_obj) |obj| wayland_window.root_module.addObjectFile(obj);
    if (runtime_obj) |obj| wayland_window.root_module.addObjectFile(obj);

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
    if (math_obj) |obj| wayland_window_tests.root_module.addObjectFile(obj);
    if (runtime_obj) |obj| wayland_window_tests.root_module.addObjectFile(obj);
    const run_wayland_window_tests = b.addRunArtifact(wayland_window_tests);
    const wayland_window_test_step = b.step("wayland-window-test", "Run native Wayland host protocol tests");
    wayland_window_test_step.dependOn(&run_wayland_window_tests.step);
    test_step.dependOn(&run_wayland_window_tests.step);

    const xdg_shell_header_cmd = b.addSystemCommand(&.{
        "wayland-scanner",
        "client-header",
        "/usr/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml",
    });
    _ = &xdg_shell_header_cmd;
    const xdg_shell_code_cmd = b.addSystemCommand(&.{
        "wayland-scanner",
        "private-code",
        "/usr/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml",
    });
    _ = &xdg_shell_code_cmd;
    const drm_gbm_window = b.addExecutable(.{
        .name = "edgerun-drm-gbm-window",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/drm_gbm_host.zig"),
            .target = target,
            .optimize = optimize,
            .strip = strip_release,
        }),
    });
    if (math_obj) |obj| drm_gbm_window.root_module.addObjectFile(obj);
    if (runtime_obj) |obj| drm_gbm_window.root_module.addObjectFile(obj);
    const run_drm_gbm_window = b.addRunArtifact(drm_gbm_window);
    if (b.args) |args| run_drm_gbm_window.addArgs(args);
    const drm_gbm_window_step = b.step("drm-gbm-window", "Render canonical UI IR through EGL/GLES to a DRM/GBM scanout surface (DynLib, no @cImport, no libdrm/libc linkage)");
    drm_gbm_window_step.dependOn(&run_drm_gbm_window.step);

    const drm_gbm_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/drm_gbm_host.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    if (math_obj) |obj| drm_gbm_tests.root_module.addObjectFile(obj);
    if (runtime_obj) |obj| drm_gbm_tests.root_module.addObjectFile(obj);
    const run_drm_gbm_tests = b.addRunArtifact(drm_gbm_tests);
    const drm_gbm_test_step = b.step("drm-gbm-test", "Run DRM/GBM host tests");
    drm_gbm_test_step.dependOn(&run_drm_gbm_tests.step);
    test_step.dependOn(&run_drm_gbm_tests.step);

    const wasm32_freestanding_target = b.resolveTargetQuery(std.Target.Query.parse(.{
        .arch_os_abi = "wasm32-freestanding",
    }) catch unreachable);

    const ui_wasm = b.addExecutable(.{
        .name = "edgerun-ui-components",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/ui_wasm_root.zig"),
            .target = wasm32_freestanding_target,
            .optimize = optimize,
            .single_threaded = true,
            .strip = strip_release,
        }),
    });
    ui_wasm.entry = .disabled;
    ui_wasm.export_memory = true;
    ui_wasm.root_module.export_symbol_names = &.{
        "er_ui_wasm_version",
        "er_ui_wasm_max_slots",
        "er_ui_wasm_slot_count",
        "er_ui_wasm_alloc",
        "er_ui_wasm_free",
        "er_ui_wasm_clear",
        "er_ui_wasm_deserialize",
        "er_ui_wasm_serialize",
        "er_ui_wasm_render",
        "er_ui_wasm_measure",
        "er_ui_wasm_new_text",
        "er_ui_wasm_new_button",
        "er_ui_wasm_new_row_item",
        "er_ui_wasm_new_badge",
        "er_ui_wasm_new_separator",
        "er_ui_wasm_new_icon",
        "er_ui_wasm_new_checkbox",
        "er_ui_wasm_new_input",
        "er_ui_wasm_new_slider",
        "er_ui_wasm_new_card",
    };
    const install_ui_wasm = b.addInstallArtifact(ui_wasm, .{});
    const ui_wasm_step = b.step("ui-components-wasm", "Build the standalone UI component library wasm");
    ui_wasm_step.dependOn(&install_ui_wasm.step);

    const uefi_target = b.resolveTargetQuery(std.Target.Query.parse(.{
        .arch_os_abi = "x86_64-uefi",
    }) catch unreachable);
    const immutable_kernel_gop_smoke = b.addExecutable(.{
        .name = "BOOTX64.EFI",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/immutable_kernel_gop_smoke_uefi.zig"),
            .target = uefi_target,
            // This image runs the native renderer and virtio-gpu path inside QEMU.
            // ReleaseSmall keeps the EFI smaller, but makes frame rendering dramatically slower.
            .optimize = .ReleaseFast,
            .strip = true,
        }),
    });
    const install_immutable_kernel_gop_smoke = b.addInstallArtifact(immutable_kernel_gop_smoke, .{
        .dest_dir = .{ .override = .{ .custom = "immutable-kernel-gop-smoke" } },
    });
    const immutable_kernel_gop_smoke_step = b.step("immutable-kernel-gop-smoke-efi", "Build the UEFI native renderer GOP smoke");
    immutable_kernel_gop_smoke_step.dependOn(&install_immutable_kernel_gop_smoke.step);

    const tpm_real_check = b.addExecutable(.{
        .name = "edgerun-tpm-real-check-zig",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tpm_real_check.zig"),
            .target = target,
            .optimize = optimize,
            .strip = strip_release,
        }),
    });
    if (math_obj) |obj| tpm_real_check.root_module.addObjectFile(obj);
    if (runtime_obj) |obj| tpm_real_check.root_module.addObjectFile(obj);

    const run_tpm_real_check = b.addRunArtifact(tpm_real_check);
    const tpm_real_check_step = b.step("real-tpm", "Run TPM checks against /dev/tpmrm0");
    tpm_real_check_step.dependOn(&run_tpm_real_check.step);

    const ifstatus = b.addExecutable(.{
        .name = "edgerun-ifstatus",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/ifstatus.zig"),
            .target = target,
            .optimize = optimize,
            .strip = strip_release,
        }),
    });
    if (math_obj) |obj| ifstatus.root_module.addObjectFile(obj);
    if (runtime_obj) |obj| ifstatus.root_module.addObjectFile(obj);

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
            .strip = strip_release,
        }),
    });
    if (math_obj) |obj| pi_usb_boot_host.root_module.addObjectFile(obj);
    if (runtime_obj) |obj| pi_usb_boot_host.root_module.addObjectFile(obj);

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
            .strip = strip_release,
        }),
    });
    if (math_obj) |obj| pi_usb_control_host.root_module.addObjectFile(obj);
    if (runtime_obj) |obj| pi_usb_control_host.root_module.addObjectFile(obj);

    const pi_usb_control = b.addRunArtifact(pi_usb_control_host);
    if (b.args) |args| pi_usb_control.addArgs(args);
    const pi_usb_control_step = b.step("pi-usb-control", "Send Edgerun Pi USB control commands over Linux usbfs without external dependencies");
    pi_usb_control_step.dependOn(&pi_usb_control.step);

    const gen_icon_objects = b.addExecutable(.{
        .name = "gen-icon-objects",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/gen_icon_objects.zig"),
            .target = b.graph.host,
            .optimize = optimize,
            .strip = strip_release,
        }),
    });
    const run_gen_icon_objects = b.addRunArtifact(gen_icon_objects);

    const gen_icon_objects_step = b.step("gen-icon-objects", "Convert Tabler SVG icons to pre-compiled IR canonical objects");
    gen_icon_objects_step.dependOn(&run_gen_icon_objects.step);
    // Test compilation needs the generated files in src/gen/
    drm_gbm_tests.step.dependOn(&run_gen_icon_objects.step);
    wayland_window_tests.step.dependOn(&run_gen_icon_objects.step);
    test_step.dependOn(&run_gen_icon_objects.step);
}
