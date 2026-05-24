const image = @import("image.zig");
const renderer_software = @import("renderer_software.zig");
const ui = @import("ui.zig");

pub const cloud_meme_width: usize = 680;
pub const cloud_meme_height: usize = 383;
pub const cloud_meme_pixel_count: usize = cloud_meme_width * cloud_meme_height;

pub const cloud_meme_png = @embedFile("assets/old-man-yells-at-cloud.png");

var cloud_meme_pixels: [cloud_meme_pixel_count]ui.Color = undefined;
var cloud_meme_scratch: [image.pngScratchByteLen(cloud_meme_png.len, cloud_meme_width, cloud_meme_height)]u8 = undefined;
var cloud_meme_ready = false;

pub fn cloudMeme() image.DecodeError!renderer_software.RgbaTexture {
    if (!cloud_meme_ready) {
        const header = try image.decodeWithScratch(cloud_meme_png, &cloud_meme_pixels, &cloud_meme_scratch);
        if (header.width != cloud_meme_width or header.height != cloud_meme_height) return error.BadImage;
        cloud_meme_ready = true;
    }
    return .{
        .width = cloud_meme_width,
        .height = cloud_meme_height,
        .pixels = &cloud_meme_pixels,
    };
}

pub fn cloudMemeRgbaPtr() usize {
    const texture = cloudMeme() catch return 0;
    return @intFromPtr(texture.pixels.ptr);
}

pub fn cloudMemeRgbaLen() usize {
    const texture = cloudMeme() catch return 0;
    return texture.pixels.len * @sizeOf(ui.Color);
}

test "cloud meme decodes to canonical rgba texture" {
    try @import("std").testing.expectEqual(image.Format.png, try image.detectFormat(cloud_meme_png));
    const texture = try cloudMeme();
    try @import("std").testing.expectEqual(cloud_meme_width, texture.width);
    try @import("std").testing.expectEqual(cloud_meme_height, texture.height);
    try @import("std").testing.expect(texture.pixels[0].a != 0);
}
