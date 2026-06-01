const std = @import("build_std.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const strip_release = optimize != .Debug;

    const is_x86_64 = target.result.cpu.arch == .x86_64;

    var asm_std_obj: ?std.Build.LazyPath = null;
    if (is_x86_64) {
        const host_asm = hostAssembler(b);
        const cmd = b.addSystemCommand(&.{ host_asm, "-f", "elf64", "-I", "../kernel", "../kernel/x86_64/rt/std.asm", "-o" });
        asm_std_obj = cmd.addOutputFileArg("asm_std.o");
    }

    const test_step = b.step("test", "Run Zig prototype tests");
    const ui_test_step = b.step("ui-test", "Run all UI tests");
    const media_test_step = b.step("media-test", "Run media codec and container tests");
    const host_test_step = b.step("host-test", "Run host integration tests");

    _ = addZigTest(b, target, optimize, .{
        .root = "src/pi_usb_boot_host.zig",
        .step = "pi-usb-boot-host-test",
        .description = "Run Pi USB boot host tests",
        .default_step = test_step,
        .suite_step = host_test_step,
    });
    _ = addZigTest(b, target, optimize, .{
        .root = "src/pi_usb_control_host.zig",
        .step = "pi-usb-control-host-test",
        .description = "Run Pi USB control host tests",
        .default_step = test_step,
        .suite_step = host_test_step,
    });
    _ = addZigTest(b, target, optimize, .{
        .root = "src/clock.zig",
        .step = "clock-test",
        .description = "Run Zig clock tests",
    });
    _ = addZigTest(b, target, optimize, .{
        .root = "src/bytes.zig",
        .step = "bytes-test",
        .description = "Run project byte helper tests",
        .default_step = test_step,
    });
    _ = addZigTest(b, target, optimize, .{
        .root = "src/math.zig",
        .step = "math-test",
        .description = "Run project math helper tests",
        .default_step = test_step,
    });
    _ = addZigTest(b, target, optimize, .{
        .root = "src/crypto.zig",
        .step = "crypto-test",
        .description = "Run project crypto tests",
        .default_step = test_step,
    });
    _ = addZigTest(b, target, optimize, .{
        .root = "src/preimage.zig",
        .step = "preimage-test",
        .description = "Run project preimage tests",
        .default_step = test_step,
    });
    _ = addZigTest(b, target, optimize, .{
        .root = "src/identity.zig",
        .step = "identity-test",
        .description = "Run Zig identity tests",
    });
    _ = addZigTest(b, target, optimize, .{
        .root = "src/seal.zig",
        .step = "seal-test",
        .description = "Run seal policy tests",
        .default_step = test_step,
    });
    _ = addZigTest(b, target, optimize, .{
        .root = "src/kernel_authority_test.zig",
        .step = "kernel-authority-test",
        .description = "Run kernel authority action tests",
        .default_step = test_step,
    });
    _ = addZigTest(b, target, optimize, .{
        .root = "src/object.zig",
        .step = "object-test",
        .description = "Run Zig object tests",
    });
    _ = addZigTest(b, target, optimize, .{
        .root = "src/store.zig",
        .step = "storage-test",
        .description = "Run Zig storage tests",
    });
    _ = addZigTest(b, target, optimize, .{
        .root = "src/encrypted_chat.zig",
        .step = "chat-test",
        .description = "Run encrypted chat app state tests",
        .default_step = test_step,
    });
    _ = addZigTest(b, target, optimize, .{
        .root = "src/app_encrypted_chat.zig",
        .step = "chat-ui-test",
        .description = "Run encrypted chat app UI tests",
        .default_step = test_step,
        .suite_step = ui_test_step,
    });
    _ = addZigTest(b, target, optimize, .{
        .root = "src/app_pipeline_dashboard.zig",
        .step = "pipeline-ui-test",
        .description = "Run user-scheduled pipeline UI tests",
        .default_step = test_step,
        .suite_step = ui_test_step,
    });
    _ = addZigTest(b, target, optimize, .{
        .root = "src/sdk.zig",
        .step = "sdk-test",
        .description = "Run Zig SDK tests",
    });

    const sdk_cli = b.addExecutable(.{
        .name = "edgerun-sdk",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/sdk_cli.zig"),
            .target = target,
            .optimize = optimize,
            .strip = strip_release,
        }),
    });
    addBootstrapStd(b, sdk_cli, asm_std_obj);

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
    addBootstrapStd(b, sdk_bench, asm_std_obj);

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
    addBootstrapStd(b, media_video_dump, asm_std_obj);

    const run_media_video_dump = b.addRunArtifact(media_video_dump);
    if (b.args) |args| run_media_video_dump.addArgs(args);
    const media_video_dump_step = b.step("media-video-dump", "Decode a VP8 IVF/WebM file to PPM frames");
    media_video_dump_step.dependOn(&run_media_video_dump.step);

    const project_intro_video = b.addExecutable(.{
        .name = "edgerun-project-intro-video",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/project_intro_video.zig"),
            .target = target,
            .optimize = optimize,
            .strip = strip_release,
        }),
    });
    addBootstrapStd(b, project_intro_video, asm_std_obj);

    const run_project_intro_video = b.addRunArtifact(project_intro_video);
    const project_intro_video_step = b.step("project-intro-video", "Render project intro video frames through the UI renderer");
    project_intro_video_step.dependOn(&run_project_intro_video.step);

    _ = addZigTest(b, target, optimize, .{
        .root = "src/project_intro_video.zig",
        .step = "project-intro-video-test",
        .description = "Run project intro video frame generator tests",
    });

    _ = addZigTest(b, target, optimize, .{
        .root = "src/media_video_dump.zig",
        .step = "media-video-dump-test",
        .description = "Run media video dump host-tool tests",
    });
    _ = addZigTest(b, target, optimize, .{
        .root = "src/media_test.zig",
        .step = "media-codec-test",
        .description = "Run media codec and container tests",
        .default_step = test_step,
        .suite_step = media_test_step,
    });
    _ = addZigTest(b, target, optimize, .{
        .root = "src/ui_core_test.zig",
        .step = "ui-core-test",
        .description = "Run Zig UI core tests",
        .suite_step = ui_test_step,
    });
    _ = addZigTest(b, target, optimize, .{
        .root = "src/ui_codec_test.zig",
        .step = "ui-codec-test",
        .description = "Run Zig UI codec and stream tests",
        .default_step = test_step,
        .suite_step = ui_test_step,
    });
    _ = addZigTest(b, target, optimize, .{
        .root = "src/svg_path_parser.zig",
        .step = "svg-path-parser-test",
        .description = "Run SVG path parser tests",
        .default_step = test_step,
        .suite_step = ui_test_step,
    });
    _ = addZigTest(b, target, optimize, .{
        .root = "src/component_gallery_test.zig",
        .step = "component-gallery-test",
        .description = "Run canonical component gallery tests",
        .suite_step = ui_test_step,
    });

    const build_dashboard = b.addExecutable(.{
        .name = "edgerun-build-dashboard",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/build_dashboard.zig"),
            .target = target,
            .optimize = optimize,
            .strip = strip_release,
        }),
    });
    addBootstrapStd(b, build_dashboard, asm_std_obj);

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
    addBootstrapStd(b, chat_preview, asm_std_obj);

    const run_chat_preview = b.addRunArtifact(chat_preview);
    const chat_preview_step = b.step("chat-preview", "Render encrypted chat UI preview PPM");
    chat_preview_step.dependOn(&run_chat_preview.step);

    const jc3248_frame = b.addExecutable(.{
        .name = "edgerun-jc3248-frame",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/jc3248_display_frame.zig"),
            .target = target,
            .optimize = optimize,
            .strip = strip_release,
        }),
    });
    addBootstrapStd(b, jc3248_frame, asm_std_obj);

    const run_jc3248_frame = b.addRunArtifact(jc3248_frame);
    const jc3248_frame_step = b.step("jc3248-frame", "Render JC3248W535 UI frame as raw RGB565");
    jc3248_frame_step.dependOn(&run_jc3248_frame.step);

    _ = addZigTest(b, target, optimize, .{
        .root = "src/jc3248_display_frame.zig",
        .step = "jc3248-frame-test",
        .description = "Run JC3248W535 UI frame renderer tests",
        .suite_step = ui_test_step,
    });

    const wayland_window = b.addExecutable(.{
        .name = "edgerun-wayland-window",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/wayland_window_host.zig"),
            .target = target,
            .optimize = optimize,
            .strip = strip_release,
        }),
    });
    addBootstrapStd(b, wayland_window, asm_std_obj);

    const run_wayland_window = b.addRunArtifact(wayland_window);
    if (b.args) |args| run_wayland_window.addArgs(args);
    const wayland_window_step = b.step("wayland-window", "Open a native Wayland shm window using canonical UI IR");
    wayland_window_step.dependOn(&run_wayland_window.step);

    _ = addZigTest(b, target, optimize, .{
        .root = "src/wayland_window_host.zig",
        .step = "wayland-window-test",
        .description = "Run native Wayland host protocol tests",
        .default_step = test_step,
        .suite_step = ui_test_step,
    });

    const drm_gbm_window = b.addExecutable(.{
        .name = "edgerun-drm-gbm-window",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/drm_gbm_host.zig"),
            .target = target,
            .optimize = optimize,
            .strip = strip_release,
        }),
    });
    addBootstrapStd(b, drm_gbm_window, asm_std_obj);
    const run_drm_gbm_window = b.addRunArtifact(drm_gbm_window);
    if (b.args) |args| run_drm_gbm_window.addArgs(args);
    const drm_gbm_window_step = b.step("drm-gbm-window", "Render canonical UI IR through EGL/GLES to a DRM/GBM scanout surface (DynLib, no @cImport, no libdrm/libc linkage)");
    drm_gbm_window_step.dependOn(&run_drm_gbm_window.step);

    _ = addZigTest(b, target, optimize, .{
        .root = "src/drm_gbm_host.zig",
        .step = "drm-gbm-test",
        .description = "Run DRM/GBM host tests",
        .default_step = test_step,
        .suite_step = ui_test_step,
    });

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
    addOwnedStd(b, ui_wasm);
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
    ui_wasm_step.dependOn(&addNoStdProductionCheck(b).step);
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
    addOwnedStd(b, immutable_kernel_gop_smoke);
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
    addBootstrapStd(b, tpm_real_check, asm_std_obj);

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
    addBootstrapStd(b, ifstatus, asm_std_obj);

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
    addBootstrapStd(b, pi_usb_boot_host, asm_std_obj);

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
    addBootstrapStd(b, pi_usb_control_host, asm_std_obj);

    const pi_usb_control = b.addRunArtifact(pi_usb_control_host);
    if (b.args) |args| pi_usb_control.addArgs(args);
    const pi_usb_control_step = b.step("pi-usb-control", "Send Edgerun Pi USB control commands over Linux usbfs without external dependencies");
    pi_usb_control_step.dependOn(&pi_usb_control.step);
}

fn addNoStdProductionCheck(b: *std.Build) *std.Build.Step.Run {
    const script =
        \\failed=0
        \\for f in src/bytes.zig src/math.zig src/clock.zig src/crypto.zig src/preimage.zig src/identity.zig src/seal.zig src/content/kernel_authority.zig src/media/video.zig src/render/vector_raster.zig src/render/wasm_gl.zig src/tpm.zig src/tls_tpm.zig src/ui/components/Component.zig src/ui/components/Direction.zig src/ui/components/TreeCodec.zig src/ui/components/AlertDialog.zig src/ui/components/Breadcrumb.zig src/ui/components/Carousel.zig src/ui/components/Combobox.zig src/ui/components/Dialog.zig src/ui/components/Drawer.zig src/ui/components/DropdownMenu.zig src/ui/components/HoverCard.zig src/ui/components/Popover.zig src/ui/components/RadioGroup.zig src/ui/components/Sheet.zig src/ui/components/Toggle.zig src/ui/components/ButtonGroup.zig src/ui/components/Chart.zig src/ui/components/InputGroup.zig src/ui/components/Pagination.zig src/ui/components/Toast.zig src/ui/components/ToggleGroup.zig src/ui/components/Tooltip.zig; do
        \\  [ -f "$f" ] || continue
        \\  awk '/std\.|@import\("std"\)/ { print FILENAME ":" FNR ":" $0; bad = 1 } END { exit bad }' "$f" || failed=1
        \\done
        \\for f in src/arena.zig src/object.zig src/bytes.zig src/math.zig src/clock.zig src/crypto.zig src/boot_resource_map.zig src/pi_usb_control.zig src/app_encrypted_chat.zig src/app_pipeline_dashboard.zig src/content/kernel.zig src/content/resource_contract.zig src/content/resource_inventory.zig src/media/common.zig src/media/runtime_image.zig src/media/video_common.zig src/media/video_ivf.zig src/media/video_webm.zig src/media/audio_webm.zig src/media/jpeg.zig src/render/font.zig src/render/font_atlas_weighted.zig src/render/ir.zig src/render/pipeline.zig src/render/surface.zig src/shell/agent.zig src/shell/frame.zig src/svg_path_parser.zig src/ui/*.zig src/ui/layouts/*.zig src/ui/components/*.zig; do
        \\  [ -f "$f" ] || continue
        \\  case "$f" in */TestSupport.zig|*/ComponentApiTest.zig) continue ;; esac
        \\  awk 'BEGIN { bad = 0; test_block = 0 } /^test "/ { test_block = 1 } !test_block && /std\./ && $0 !~ /std\.testing/ { print FILENAME ":" FNR ":" $0; bad = 1 } END { exit bad }' "$f" || failed=1
        \\done
        \\exit "$failed"
    ;
    return b.addSystemCommand(&.{ "sh", "-c", script });
}

fn addBootstrapStd(b: *std.Build, compile: *std.Build.Step.Compile, asm_std_obj: ?std.Build.LazyPath) void {
    addOwnedStd(b, compile);
    if (asm_std_obj) |obj| compile.root_module.addObjectFile(obj);
}

fn addOwnedStd(b: *std.Build, compile: *std.Build.Step.Compile) void {
    compile.root_module.addImport("er_std", b.createModule(.{
        .root_source_file = b.path("src/std.zig"),
    }));
}

fn hostAssembler(b: *std.Build) []const u8 {
    if (b.option([]const u8, "host-asm", "Assembler for host bootstrap ASM objects")) |value| return value;
    if (envNonEmpty(b, "ER_ASM")) |value| return value;
    if (envNonEmpty(b, "YASM")) |value| return value;
    return "yasm";
}

fn envNonEmpty(b: *std.Build, name: []const u8) ?[]const u8 {
    const value = b.graph.environ_map.get(name) orelse return null;
    if (value.len == 0) return null;
    return value;
}

const ZigTestOptions = struct {
    root: []const u8,
    step: []const u8,
    description: []const u8,
    default_step: ?*std.Build.Step = null,
    suite_step: ?*std.Build.Step = null,
};

fn addZigTest(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    options: ZigTestOptions,
) *std.Build.Step.Compile {
    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path(options.root),
            .target = target,
            .optimize = optimize,
        }),
    });
    addOwnedStd(b, tests);

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step(options.step, options.description);
    test_step.dependOn(&run_tests.step);
    if (options.default_step) |step| step.dependOn(&run_tests.step);
    if (options.suite_step) |step| step.dependOn(&run_tests.step);
    return tests;
}
