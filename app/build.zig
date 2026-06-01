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
