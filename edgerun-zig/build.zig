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

    const ui_browser_target = b.resolveTargetQuery(std.Target.Query.parse(.{
        .arch_os_abi = "wasm32-freestanding",
    }) catch unreachable);
    const ui_browser = b.addExecutable(.{
        .name = "edgerun-ui-browser",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/ui_browser.zig"),
            .target = ui_browser_target,
            .optimize = .ReleaseSmall,
            .single_threaded = true,
        }),
    });
    ui_browser.entry = .disabled;
    ui_browser.export_memory = true;
    ui_browser.root_module.export_symbol_names = &.{
        "er_ui_max_width",
        "er_ui_max_height",
        "er_ui_gpu_rect_float_stride",
        "er_ui_gpu_rect_buffer_ptr",
        "er_ui_gpu_rect_buffer_len",
        "er_ui_gpu_text_vertex_float_stride",
        "er_ui_gpu_text_vertex_buffer_ptr",
        "er_ui_gpu_text_vertex_buffer_len",
        "er_ui_gpu_icon_vertex_float_stride",
        "er_ui_gpu_icon_vertex_buffer_ptr",
        "er_ui_gpu_icon_vertex_buffer_len",
        "er_ui_gpu_image_vertex_float_stride",
        "er_ui_gpu_image_vertex_buffer_ptr",
        "er_ui_gpu_image_vertex_buffer_len",
        "er_ui_gpu_overlay_rect_buffer_ptr",
        "er_ui_gpu_overlay_rect_buffer_len",
        "er_ui_gpu_overlay_text_vertex_buffer_ptr",
        "er_ui_gpu_overlay_text_vertex_buffer_len",
        "er_ui_gpu_overlay_icon_vertex_buffer_ptr",
        "er_ui_gpu_overlay_icon_vertex_buffer_len",
        "er_ui_post_image_webp_ptr",
        "er_ui_post_image_webp_len",
        "er_ui_font_atlas_width",
        "er_ui_font_atlas_height",
        "er_ui_font_atlas_ptr",
        "er_ui_font_atlas_generation",
        "er_ui_icon_atlas_width",
        "er_ui_icon_atlas_height",
        "er_ui_icon_atlas_ptr",
        "er_ui_width",
        "er_ui_height",
        "er_ui_input_ptr",
        "er_ui_input_capacity",
        "er_ui_last_error",
        "er_ui_set_device_scale",
        "er_ui_hover_hit_kind",
        "er_ui_hover_hit_id",
        "er_ui_last_action_kind",
        "er_ui_last_action_hit_id",
        "er_ui_last_action_scope_id",
        "er_ui_last_action_from_index",
        "er_ui_last_action_to_index",
        "er_ui_pointer_down",
        "er_ui_pointer_move",
        "er_ui_pointer_up",
        "er_ui_component_gallery_layout_masonry_id",
        "er_ui_component_gallery_layout_grid_id",
        "er_ui_component_gallery_gap_compact_id",
        "er_ui_component_gallery_gap_default_id",
        "er_ui_component_gallery_gap_wide_id",
        "er_ui_site_docs_button_id",
        "er_ui_site_apps_button_id",
        "er_ui_site_launch_button_id",
        "er_ui_site_search_button_id",
        "er_ui_site_source_button_id",
        "er_ui_site_blog_button_id",
        "er_ui_blog_back_button_id",
        "er_ui_blog_first_post_button_id",
        "er_ui_blog_post_count",
        "er_ui_site_host_action_kind",
        "er_ui_site_host_action_url_ptr",
        "er_ui_site_host_action_url_len",
        "er_ui_site_route_path_ptr",
        "er_ui_site_route_path_len",
        "er_ui_site_set_route_path",
        "er_ui_site_activate_hit",
        "er_ui_site_search_open",
        "er_ui_site_search_close",
        "er_ui_site_search_is_open",
        "er_ui_site_search_backspace",
        "er_ui_site_search_input_byte",
        "er_ui_site_landing_content_height",
        "er_ui_site_blog_content_height",
        "er_ui_site_blog_post_content_height",
        "er_ui_site_content_height",
        "er_ui_clear",
        "er_ui_build_component_gallery_gpu_frame",
        "er_ui_build_component_gallery_gpu_frame_layout_gap_hover",
        "er_ui_build_site_gpu_frame",
        "er_ui_build_site_landing_gpu_frame",
        "er_ui_build_site_blog_gpu_frame",
        "er_ui_render_input_object",
    };
    const install_ui_browser = b.addInstallArtifact(ui_browser, .{});
    const wasm_entry = b.addExecutable(.{
        .name = "edgerun-wasm-entry",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/wasm_entry.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_wasm_entry = b.addRunArtifact(wasm_entry);
    const wasm_entry_html = run_wasm_entry.addOutputFileArg("wasmentry.html");
    const install_wasm_entry = b.addInstallFile(wasm_entry_html, "web/wasmentry.html");
    const wasm_entry_step = b.step("wasm-entry", "Generate the immutable browser WASM entry point");
    wasm_entry_step.dependOn(&install_wasm_entry.step);

    const ui_browser_step = b.step("ui-browser", "Build browser-renderable Zig UI wasm");
    ui_browser_step.dependOn(&install_ui_browser.step);
    ui_browser_step.dependOn(&install_wasm_entry.step);

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
