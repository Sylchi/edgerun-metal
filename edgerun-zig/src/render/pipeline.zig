const std = @import("std");
const renderer_font_atlas = @import("font_atlas.zig");
const renderer_ir = @import("ir.zig");
const renderer_present = @import("present.zig");
const renderer_software = @import("software.zig");
const ui = @import("../ui.zig");

pub const FontSource = enum {
    atlas,
    object,
};

pub fn sources(font_atlas: *renderer_font_atlas.Atlas, font_source: FontSource) renderer_ir.Sources {
    return .{
        .font = switch (font_source) {
            .atlas => font_atlas.source(),
            .object => font_atlas.objectSource(),
        },
    };
}

pub fn packScene(
    buffers: renderer_ir.Buffers,
    font_atlas: *renderer_font_atlas.Atlas,
    font_source: FontSource,
    commands: []const ui.Command,
) renderer_ir.Error!void {
    try packSceneWithSources(buffers, sources(font_atlas, font_source), commands);
}

pub fn packSceneWithSources(
    buffers: renderer_ir.Buffers,
    source_set: renderer_ir.Sources,
    commands: []const ui.Command,
) renderer_ir.Error!void {
    try renderer_ir.packScene(buffers, source_set, commands);
}

pub fn softwareResources(font_atlas: *const renderer_font_atlas.Atlas, image: ?renderer_software.RgbaTexture) renderer_software.Resources {
    return softwareResourcesFromAlphaAtlas(.{
        .width = renderer_font_atlas.width,
        .height = renderer_font_atlas.height,
        .alpha = font_atlas.alphaSlice(),
    }, image);
}

pub fn softwareResourcesFromAlphaAtlas(font: renderer_software.AlphaAtlas, image: ?renderer_software.RgbaTexture) renderer_software.Resources {
    return .{
        .font = font,
        .image = image,
    };
}

pub fn presentationResources(font_atlas_ready: bool, image_ready: bool) renderer_present.Resources {
    return .{
        .font_atlas = font_atlas_ready,
        .image_texture = image_ready,
    };
}

pub fn renderSoftwareFrame(
    surface: renderer_software.Framebuffer,
    buffers: renderer_ir.Buffers,
    resources: renderer_software.Resources,
    background: ui.Color,
) renderer_software.Error!renderer_present.Receipt {
    surface.clear(background);
    return surface.renderIr(buffers, resources);
}

pub fn presentPackedFrame(
    width: u32,
    height: u32,
    buffers: renderer_ir.Buffers,
    resource_set: renderer_present.Resources,
) renderer_present.Error!renderer_present.Receipt {
    return renderer_present.present(.{
        .target = .{
            .destination = .packed_frame,
            .width = width,
            .height = height,
        },
        .buffers = buffers,
        .resources = resource_set,
    });
}

test "render pipeline builds atlas and object font sources" {
    var font_atlas = renderer_font_atlas.Atlas.init();
    var commands: [1]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try scene.push(.{ .text = .{
        .origin = ui.Rect.init(0, 0, 80, 24),
        .value = "A",
        .color = .text,
    } });

    var atlas_storage = renderer_ir.FixedBuffers(0, renderer_ir.textured_quad_vertex_count, 0, 0, 0, 0, 0){};
    try packScene(atlas_storage.buffers(), &font_atlas, .atlas, scene.written());
    try std.testing.expect(atlas_storage.text_vertex_len != 0);

    const object_sources = sources(&font_atlas, .object);
    try std.testing.expectEqual(@intFromPtr(&font_atlas), @intFromPtr(object_sources.font.context));
}

test "render pipeline owns packed presentation and software resources" {
    var font_atlas = renderer_font_atlas.Atlas.init();
    var commands: [1]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try scene.push(.{ .rect = .{
        .bounds = ui.Rect.init(0, 0, 8, 8),
        .color = .text,
    } });

    var storage = renderer_ir.FixedBuffers(1, 0, 0, 0, 0, 0, 0){};
    const buffers = storage.buffers();
    try packScene(buffers, &font_atlas, .atlas, scene.written());

    const packed_receipt = try presentPackedFrame(8, 8, buffers, presentationResources(false, false));
    try std.testing.expectEqual(renderer_present.Destination.packed_frame, packed_receipt.destination);

    var pixels: [64]ui.Color = undefined;
    const surface = try renderer_software.Framebuffer.init(8, 8, &pixels);
    const software_receipt = try renderSoftwareFrame(
        surface,
        buffers,
        softwareResources(&font_atlas, null),
        .bg,
    );
    try std.testing.expectEqual(renderer_present.Destination.pixel_frame, software_receipt.destination);
}
