const std = @import("std");
const renderer_ir = @import("ir.zig");

pub const Error = renderer_ir.Error || error{
    InvalidTarget,
    MissingFontAtlas,
    MissingImageTexture,
};

pub const Destination = enum {
    pixel_frame,
    packed_frame,
    command_frame,
    native_surface,
};

pub const PrimitiveFormat = enum {
    canonical_ir,
};

pub const Transport = enum {
    pixel_bytes,
    packed_buffers,
    command_stream,
    surface_commit,
};

pub const Target = struct {
    destination: Destination,
    width: u32,
    height: u32,
    scale: u32 = 1,

    pub fn validate(self: Target) Error!void {
        if (self.width == 0 or self.height == 0 or self.scale == 0) return error.InvalidTarget;
    }

    pub fn primitiveFormat(self: Target) PrimitiveFormat {
        return switch (self.destination) {
            .pixel_frame,
            .packed_frame,
            .command_frame,
            .native_surface,
            => .canonical_ir,
        };
    }

    pub fn transport(self: Target) Transport {
        return switch (self.destination) {
            .pixel_frame => .pixel_bytes,
            .packed_frame => .packed_buffers,
            .command_frame => .command_stream,
            .native_surface => .surface_commit,
        };
    }
};

pub const Resources = struct {
    font_atlas: bool = false,
    image_texture: bool = false,
};

pub const Requirements = struct {
    font_atlas: bool,
    image_texture: bool,
};

pub const Receipt = struct {
    destination: Destination,
    primitive_format: PrimitiveFormat,
    transport: Transport,
    primitive_count: usize,
    requirements: Requirements,

    pub fn valid(self: Receipt) bool {
        return self.primitive_format == .canonical_ir and self.primitive_count != 0;
    }
};

pub const Frame = struct {
    target: Target,
    buffers: renderer_ir.Buffers,
    resources: Resources,

    pub fn validate(self: Frame) Error!void {
        try self.target.validate();
        try renderer_ir.validateBuffers(self.buffers);
        try validateResources(self.buffers, self.resources);
    }

    pub fn primitiveFormat(self: Frame) PrimitiveFormat {
        return self.target.primitiveFormat();
    }

    pub fn transport(self: Frame) Transport {
        return self.target.transport();
    }

    pub fn primitiveCount(self: Frame) renderer_ir.Error!usize {
        return renderer_ir.primitiveCount(self.buffers);
    }

    pub fn requirements(self: Frame) Requirements {
        return bufferRequirements(self.buffers);
    }
};

pub fn validateResources(buffers: renderer_ir.Buffers, resources: Resources) Error!void {
    const required = bufferRequirements(buffers);
    if (required.font_atlas and !resources.font_atlas) return error.MissingFontAtlas;
    if (required.image_texture and !resources.image_texture) return error.MissingImageTexture;
}

pub fn bufferRequirements(buffers: renderer_ir.Buffers) Requirements {
    return .{
        .font_atlas = buffers.text_vertex_len.* != 0 or buffers.overlay_text_vertex_len.* != 0,
        .image_texture = buffers.image_vertex_len.* != 0,
    };
}

pub fn present(frame: Frame) Error!Receipt {
    try frame.validate();
    return .{
        .destination = frame.target.destination,
        .primitive_format = frame.primitiveFormat(),
        .transport = frame.transport(),
        .primitive_count = try frame.primitiveCount(),
        .requirements = frame.requirements(),
    };
}

test "presentation targets use one canonical primitive format" {
    const destinations = [_]Destination{ .pixel_frame, .packed_frame, .command_frame, .native_surface };
    for (destinations) |destination| {
        const target = Target{ .destination = destination, .width = 320, .height = 240 };
        try target.validate();
        try std.testing.expectEqual(PrimitiveFormat.canonical_ir, target.primitiveFormat());
    }
}

test "presentation target transport is explicit" {
    try std.testing.expectEqual(Transport.pixel_bytes, (Target{ .destination = .pixel_frame, .width = 1, .height = 1 }).transport());
    try std.testing.expectEqual(Transport.packed_buffers, (Target{ .destination = .packed_frame, .width = 1, .height = 1 }).transport());
    try std.testing.expectEqual(Transport.command_stream, (Target{ .destination = .command_frame, .width = 1, .height = 1 }).transport());
    try std.testing.expectEqual(Transport.surface_commit, (Target{ .destination = .native_surface, .width = 1, .height = 1 }).transport());
}

test "presentation frame validates canonical ir buffers for every target" {
    var storage = renderer_ir.FixedBuffers(1, 0, 0, 0, 0, 0, 0, 0, 0){};
    const buffers = storage.buffers();
    try renderer_ir.pushRect(buffers, .base, .{ .x = 2, .y = 3, .w = 10, .h = 12 }, .text, .clear, 4, 0, 0);

    const destinations = [_]Destination{ .pixel_frame, .packed_frame, .command_frame, .native_surface };
    for (destinations) |destination| {
        const frame = Frame{
            .target = .{ .destination = destination, .width = 64, .height = 48 },
            .buffers = buffers,
            .resources = .{},
        };
        try frame.validate();
        try std.testing.expectEqual(PrimitiveFormat.canonical_ir, frame.primitiveFormat());
        try std.testing.expectEqual(@as(usize, 1), try frame.primitiveCount());
        const receipt = try present(frame);
        try std.testing.expect(receipt.valid());
        try std.testing.expectEqual(destination, receipt.destination);
        try std.testing.expectEqual(frame.transport(), receipt.transport);
    }
}

test "presentation frame rejects invalid dimensions and missing texture resources" {
    var text_storage = renderer_ir.FixedBuffers(0, renderer_ir.textured_quad_vertex_count, 0, 0, 0, 0, 0, 0, 0){};
    text_storage.text_vertex_len = renderer_ir.textured_quad_vertex_count * renderer_ir.text_vertex_float_stride;
    const text_frame = Frame{
        .target = .{ .destination = .pixel_frame, .width = 64, .height = 48 },
        .buffers = text_storage.buffers(),
        .resources = .{},
    };
    try std.testing.expectError(error.MissingFontAtlas, text_frame.validate());

    var icon_storage = renderer_ir.FixedBuffers(0, 0, 1, 0, 0, 0, 0, 0, 0){};
    icon_storage.icon_vertex_len = renderer_ir.icon_instance_float_stride;
    const icon_frame = Frame{
        .target = .{ .destination = .packed_frame, .width = 64, .height = 48 },
        .buffers = icon_storage.buffers(),
        .resources = .{ .font_atlas = true },
    };
    try icon_frame.validate();

    var image_storage = renderer_ir.FixedBuffers(0, 0, 0, renderer_ir.textured_quad_vertex_count, 0, 0, 0, 0, 0){};
    image_storage.image_vertex_len = renderer_ir.textured_quad_vertex_count * renderer_ir.image_vertex_float_stride;
    const image_frame = Frame{
        .target = .{ .destination = .native_surface, .width = 64, .height = 48 },
        .buffers = image_storage.buffers(),
        .resources = .{ .font_atlas = true },
    };
    try std.testing.expectError(error.MissingImageTexture, image_frame.validate());

    const invalid_target = Frame{
        .target = .{ .destination = .native_surface, .width = 0, .height = 48 },
        .buffers = image_storage.buffers(),
        .resources = .{ .font_atlas = true, .image_texture = true },
    };
    try std.testing.expectError(error.InvalidTarget, invalid_target.validate());
}

test "presentation receipt records canonical resource requirements" {
    var storage = renderer_ir.FixedBuffers(0, renderer_ir.textured_quad_vertex_count, 1, renderer_ir.textured_quad_vertex_count, 0, 0, 0, 0, 0){};
    storage.text_vertex_len = renderer_ir.textured_quad_vertex_count * renderer_ir.text_vertex_float_stride;
    storage.icon_vertex_len = renderer_ir.icon_instance_float_stride;
    storage.image_vertex_len = renderer_ir.textured_quad_vertex_count * renderer_ir.image_vertex_float_stride;

    const frame = Frame{
        .target = .{ .destination = .command_frame, .width = 320, .height = 240 },
        .buffers = storage.buffers(),
        .resources = .{ .font_atlas = true, .image_texture = true },
    };
    const receipt = try present(frame);
    try std.testing.expectEqual(PrimitiveFormat.canonical_ir, receipt.primitive_format);
    try std.testing.expectEqual(Transport.command_stream, receipt.transport);
    try std.testing.expect(receipt.requirements.font_atlas);
    try std.testing.expect(receipt.requirements.image_texture);
    try std.testing.expectEqual(@as(usize, 3), receipt.primitive_count);
}
