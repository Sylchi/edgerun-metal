const std = @import("std");
const uefi = std.os.uefi;

const GraphicsOutput = uefi.protocol.GraphicsOutput;

pub const Error = error{
    NoGraphicsOutput,
    UnsupportedPixelFormat,
};

pub const PixelFormat = enum(u8) {
    rgbx8888,
    bgrx8888,
    bit_mask,
};

pub const Framebuffer = struct {
    physical_base: u64,
    byte_len: u64,
    width: u32,
    height: u32,
    pixels_per_scan_line: u32,
    format: PixelFormat,
    red_mask: u32 = 0,
    green_mask: u32 = 0,
    blue_mask: u32 = 0,

    pub fn valid(self: Framebuffer) bool {
        return self.physical_base != 0 and
            self.byte_len != 0 and
            self.width != 0 and
            self.height != 0 and
            self.pixels_per_scan_line >= self.width;
    }

    pub fn strideBytes(self: Framebuffer) u64 {
        return @as(u64, self.pixels_per_scan_line) * 4;
    }

    pub fn drawDebugScreen(self: Framebuffer, stage: Stage) void {
        if (!self.valid()) return;
        self.clear(rgb(9, 11, 18));
        self.drawVerticalBands();
        self.drawBorder(rgb(235, 244, 255));
        self.fillRect(24, 24, self.width -| 48, 18, stage.color());
        self.fillRect(24, 52, stage.width(self.width -| 48), 12, rgb(255, 255, 255));
        self.drawCornerBlocks(stage);
    }

    pub fn drawWasmResult(self: Framebuffer, value: i64) void {
        if (!self.valid()) return;
        self.drawDebugScreen(.checks_passed);

        const panel_width: u32 = @min(self.width -| 48, 360);
        const x: u32 = 24;
        const y: u32 = 88;
        self.fillRect(x, y, panel_width, 56, rgb(21, 26, 38));
        self.fillRect(x + 4, y + 4, panel_width -| 8, 6, rgb(91, 219, 134));

        const encoded: u64 = @bitCast(value);
        var bit: u6 = 0;
        while (bit < 16) : (bit += 1) {
            const on = ((encoded >> bit) & 1) == 1;
            const bx = x + 12 + (@as(u32, bit % 8) * 20);
            const by = y + 18 + (@as(u32, bit / 8) * 18);
            self.fillRect(bx, by, 14, 12, if (on) rgb(91, 219, 134) else rgb(52, 62, 82));
        }
    }

    pub fn blitUiColorBytes(self: Framebuffer, width: u32, height: u32, pixels: []const u8) void {
        if (!self.valid()) return;
        const copy_width = @min(width, self.width);
        const copy_height = @min(height, self.height);
        if (pixels.len < @as(usize, width) * height * 4) return;
        var y: u32 = 0;
        while (y < copy_height) : (y += 1) {
            var x: u32 = 0;
            while (x < copy_width) : (x += 1) {
                const index = (@as(usize, y) * width + x) * 4;
                self.putPixel(x, y, rgb(pixels[index + 0], pixels[index + 1], pixels[index + 2]));
            }
        }
    }

    fn clear(self: Framebuffer, color: Rgb) void {
        var y: u32 = 0;
        while (y < self.height) : (y += 1) {
            var x: u32 = 0;
            while (x < self.width) : (x += 1) {
                self.putPixel(x, y, color);
            }
        }
    }

    fn drawVerticalBands(self: Framebuffer) void {
        var y: u32 = 0;
        while (y < self.height) : (y += 1) {
            const shade: u8 = @intCast(18 + ((@as(u64, y) * 42) / @max(@as(u32, 1), self.height)));
            self.fillRect(0, y, self.width, 1, rgb(shade, 22, 32));
        }
    }

    fn drawBorder(self: Framebuffer, color: Rgb) void {
        self.fillRect(8, 8, self.width -| 16, 4, color);
        self.fillRect(8, self.height -| 12, self.width -| 16, 4, color);
        self.fillRect(8, 8, 4, self.height -| 16, color);
        self.fillRect(self.width -| 12, 8, 4, self.height -| 16, color);
    }

    fn drawCornerBlocks(self: Framebuffer, stage: Stage) void {
        const color = stage.color();
        self.fillRect(32, self.height -| 72, 40, 40, color);
        self.fillRect(84, self.height -| 72, 40, 40, rgb(86, 190, 255));
        self.fillRect(136, self.height -| 72, 40, 40, rgb(255, 206, 92));
    }

    fn fillRect(self: Framebuffer, x: u32, y: u32, width: u32, height: u32, color: Rgb) void {
        if (x >= self.width or y >= self.height) return;
        const end_x = @min(self.width, x +| width);
        const end_y = @min(self.height, y +| height);
        var yy = y;
        while (yy < end_y) : (yy += 1) {
            var xx = x;
            while (xx < end_x) : (xx += 1) {
                self.putPixel(xx, yy, color);
            }
        }
    }

    fn putPixel(self: Framebuffer, x: u32, y: u32, color: Rgb) void {
        const offset = (@as(u64, y) * self.strideBytes()) + (@as(u64, x) * 4);
        if (offset + 4 > self.byte_len) return;
        const pixel: [*]volatile u8 = @ptrFromInt(self.physical_base + offset);
        switch (self.format) {
            .rgbx8888 => {
                pixel[0] = color.r;
                pixel[1] = color.g;
                pixel[2] = color.b;
                pixel[3] = 0;
            },
            .bgrx8888 => {
                pixel[0] = color.b;
                pixel[1] = color.g;
                pixel[2] = color.r;
                pixel[3] = 0;
            },
            .bit_mask => {
                const pixel_value = packMasked(color, self.red_mask, self.green_mask, self.blue_mask);
                pixel[0] = @truncate(pixel_value);
                pixel[1] = @truncate(pixel_value >> 8);
                pixel[2] = @truncate(pixel_value >> 16);
                pixel[3] = @truncate(pixel_value >> 24);
            },
        }
    }
};

pub const Stage = enum(u8) {
    pre_exit,
    post_exit,
    checks_passed,

    fn color(self: Stage) Rgb {
        return switch (self) {
            .pre_exit => rgb(86, 190, 255),
            .post_exit => rgb(255, 206, 92),
            .checks_passed => rgb(91, 219, 134),
        };
    }

    fn width(self: Stage, max_width: u32) u32 {
        return switch (self) {
            .pre_exit => max_width / 3,
            .post_exit => (max_width * 2) / 3,
            .checks_passed => max_width,
        };
    }
};

const Rgb = struct {
    r: u8,
    g: u8,
    b: u8,
};

pub fn collect(boot_services: *const uefi.tables.BootServices) Error!Framebuffer {
    const gop = (boot_services.locateProtocol(GraphicsOutput, null) catch null) orelse return error.NoGraphicsOutput;
    const mode = gop.mode;
    const info = mode.info;
    const mapped_format = mapPixelFormat(info.pixel_format) orelse return error.UnsupportedPixelFormat;
    return .{
        .physical_base = mode.frame_buffer_base,
        .byte_len = mode.frame_buffer_size,
        .width = info.horizontal_resolution,
        .height = info.vertical_resolution,
        .pixels_per_scan_line = info.pixels_per_scan_line,
        .format = mapped_format,
        .red_mask = info.pixel_information.red_mask,
        .green_mask = info.pixel_information.green_mask,
        .blue_mask = info.pixel_information.blue_mask,
    };
}

fn mapPixelFormat(format: GraphicsOutput.PixelFormat) ?PixelFormat {
    return switch (format) {
        .red_green_blue_reserved_8_bit_per_color => .rgbx8888,
        .blue_green_red_reserved_8_bit_per_color => .bgrx8888,
        .bit_mask => .bit_mask,
        .blt_only => null,
    };
}

fn rgb(r: u8, g: u8, b: u8) Rgb {
    return .{ .r = r, .g = g, .b = b };
}

fn packMasked(color: Rgb, red_mask: u32, green_mask: u32, blue_mask: u32) u32 {
    return packChannel(color.r, red_mask) |
        packChannel(color.g, green_mask) |
        packChannel(color.b, blue_mask);
}

fn packChannel(value: u8, mask: u32) u32 {
    if (mask == 0) return 0;
    const shift: u5 = @intCast(@ctz(mask));
    const width: u5 = @intCast(32 - @clz(mask >> shift));
    const max_value = (@as(u32, 1) << width) - 1;
    return ((@as(u32, value) * max_value) / 255) << shift;
}

test "masked packing supports common xrgb8888 masks" {
    const pixel_value = packMasked(rgb(0x12, 0x34, 0x56), 0x00ff0000, 0x0000ff00, 0x000000ff);
    try std.testing.expectEqual(@as(u32, 0x00123456), pixel_value);
}
