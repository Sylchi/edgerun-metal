const image = @import("../media/image.zig");
const renderer_software = @import("../render/backends/software.zig");
const ui = @import("core.zig");

pub const cloud_meme_width: usize = 680;
pub const cloud_meme_height: usize = 383;
pub const cloud_meme_pixel_count: usize = cloud_meme_width * cloud_meme_height;
pub const cloud_meme_runtime_len: usize = image.runtimeImageHeaderSize + cloud_meme_pixel_count * @sizeOf(ui.Color);

pub const cloud_meme_png = @embedFile("assets/old-man-yells-at-cloud.png");

var cloud_meme_pixels: [cloud_meme_pixel_count]ui.Color = undefined;
var cloud_meme_runtime: [cloud_meme_runtime_len]u8 = undefined;
var cloud_meme_scratch: [image.importScratchByteLen(cloud_meme_png, cloud_meme_width, cloud_meme_height)]u8 = undefined;
var cloud_meme_ready = false;

pub fn cloudMeme() image.RuntimeImageError!renderer_software.RgbaTexture {
    try ensureCloudMemeRuntime();
    return .{
        .width = cloud_meme_width,
        .height = cloud_meme_height,
        .pixels = &cloud_meme_pixels,
    };
}

pub fn cloudMemeRuntime() image.RuntimeImageError![]const u8 {
    try ensureCloudMemeRuntime();
    return cloud_meme_runtime[0..];
}

fn ensureCloudMemeRuntime() image.RuntimeImageError!void {
    if (cloud_meme_ready) return;
    const encoded = try image.importToRuntimeDefaultTiledWithScratch(cloud_meme_png, &cloud_meme_pixels, &cloud_meme_scratch, &cloud_meme_runtime);
    if (encoded.len != cloud_meme_runtime_len) return error.BadImage;
    const header = try image.decodeRuntimeRgba(encoded, &cloud_meme_pixels);
    if (header.width != cloud_meme_width or header.height != cloud_meme_height) return error.BadImage;
    cloud_meme_ready = true;
}

pub fn cloudMemeRgbaPtr() usize {
    const texture = cloudMeme() catch return 0;
    return @intFromPtr(texture.pixels.ptr);
}

pub fn cloudMemeRgbaLen() usize {
    const texture = cloudMeme() catch return 0;
    return texture.pixels.len * @sizeOf(ui.Color);
}

pub fn cloudMemeRuntimePtr() usize {
    const runtime = cloudMemeRuntime() catch return 0;
    return @intFromPtr(runtime.ptr);
}

pub fn cloudMemeRuntimeLen() usize {
    const runtime = cloudMemeRuntime() catch return 0;
    return runtime.len;
}

test "cloud meme imports to tiled runtime image and rgba texture" {
    try @import("std").testing.expectEqual(image.ImportFormat.png, try image.importDetectFormat(cloud_meme_png));
    const runtime = try cloudMemeRuntime();
    try @import("std").testing.expectEqual(image.Format.erimg, try image.detectFormat(runtime));
    try @import("std").testing.expectEqual(cloud_meme_runtime_len, runtime.len);
    const view = try image.decodeRuntimeImage(runtime);
    try @import("std").testing.expect(view.header.tile_count > 1);
    const texture = try cloudMeme();
    try @import("std").testing.expectEqual(cloud_meme_width, texture.width);
    try @import("std").testing.expectEqual(cloud_meme_height, texture.height);
    try @import("std").testing.expect(texture.pixels[0].a != 0);
}
