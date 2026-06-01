const ui = @import("../ui/core.zig");
const image_common = @import("common.zig");
const webp = @import("webp/root.zig");

const color_byte_len: usize = @sizeOf(ui.Color);
const vp8_stored_reference_count: usize = 3;
const vp8_yuv_scratch_count: usize = vp8_stored_reference_count + 1;

pub const Error = error{
    BadVideo,
    UnsupportedVideo,
    PixelBudget,
};

pub const Format = enum {
    webm,
    ivf,
};

pub const Codec = enum {
    vp8,
};

pub const Header = struct {
    format: Format,
    codec: Codec,
    width: usize,
    height: usize,
    frame_count: ?usize,
};

pub const Frame = struct {
    header: Header,
    index: usize,
    timestamp: u64,
    payload: []const u8,
};

pub const FrameRecord = struct {
    frame: Frame,
    next_cursor: usize,
};

pub const FrameDecodeState = struct {
    has_vp8_reference: bool = false,
    has_vp8_golden_reference: bool = false,
    has_vp8_alternate_reference: bool = false,
    vp8_entropy: webp.Vp8EntropyState = .{},

    pub fn reset(self: *FrameDecodeState) void {
        self.has_vp8_reference = false;
        self.has_vp8_golden_reference = false;
        self.has_vp8_alternate_reference = false;
        self.vp8_entropy.reset();
    }
};

pub fn mapImageDecodeError(err: image_common.DecodeError) Error {
    return switch (err) {
        error.BadImage => error.BadVideo,
        error.UnsupportedImage => error.UnsupportedVideo,
        error.PixelBudget => error.PixelBudget,
    };
}

pub fn referenceScratchByteLen(header: Header) Error!usize {
    const count = image_common.pixelCount(.{ .width = header.width, .height = header.height }) catch |err| return mapImageDecodeError(err);
    const rgba_len = image_common.checkedMul(count, color_byte_len) catch return error.PixelBudget;
    const yuv_len = webp.vp8VideoReferenceByteLen(.{ .width = header.width, .height = header.height }) catch |err| return mapImageDecodeError(err);
    return image_common.checkedAdd(rgba_len, image_common.checkedMul(yuv_len, vp8_yuv_scratch_count) catch return error.PixelBudget) catch return error.PixelBudget;
}

pub fn decodeFramePayload(frame: Frame, out: []ui.Color, scratch: []u8) Error!void {
    var state = FrameDecodeState{};
    try decodeFramePayloadStateful(frame, out, scratch, &state);
}

pub fn decodeFramePayloadStateful(frame: Frame, out: []ui.Color, scratch: []u8, state: *FrameDecodeState) Error!void {
    switch (frame.header.codec) {
        .vp8 => {
            const references = vp8ReferenceSlices(frame.header, scratch, state);
            const result = webp.decodeVp8VideoFrameWithReferencesAndEntropy(
                frame.payload,
                .{ .width = frame.header.width, .height = frame.header.height },
                out,
                .{
                    .last = references.last,
                    .golden = references.golden,
                    .alternate = references.alternate,
                },
                vp8CurrentYuvReference(frame.header, scratch),
                &state.vp8_entropy,
            ) catch |err| return mapImageDecodeError(err);
            try storeVp8References(frame.header, out, scratch, state, result.reference_update);
        },
    }
}

const Vp8ReferenceSlices = struct {
    last: ?[]const u8,
    golden: ?[]const u8,
    alternate: ?[]const u8,
};

fn vp8ReferenceSlices(header: Header, scratch: []u8, state: *const FrameDecodeState) Vp8ReferenceSlices {
    const yuv_refs = vp8StoredYuvReferences(header, scratch) catch return .{ .last = null, .golden = null, .alternate = null };
    return .{
        .last = if (state.has_vp8_reference) yuv_refs.last else null,
        .golden = if (state.has_vp8_golden_reference) yuv_refs.golden else null,
        .alternate = if (state.has_vp8_alternate_reference) yuv_refs.alternate else null,
    };
}

fn storeVp8References(header: Header, out: []const ui.Color, scratch: []u8, state: *FrameDecodeState, update: webp.Vp8ReferenceUpdate) Error!void {
    const rgba_len = try vp8RgbaReferenceByteLen(header);
    const byte_len = try referenceScratchByteLen(header);
    if (scratch.len < byte_len) {
        state.has_vp8_reference = false;
        state.has_vp8_golden_reference = false;
        state.has_vp8_alternate_reference = false;
        return;
    }
    const pixel_count = rgba_len / color_byte_len;
    if (out.len < pixel_count) return error.PixelBudget;
    @memcpy(scratch[0..rgba_len], colorBytes(out[0..pixel_count]));

    const refs = try vp8StoredYuvReferences(header, scratch);
    const current = try vp8CurrentYuvReferenceRequired(header, scratch);
    if (update.copy_to_golden != .none and !update.refresh_golden) {
        if (vp8ReferenceCopySource(update.copy_to_golden, refs, state)) |source| {
            @memcpy(refs.golden, source);
            state.has_vp8_golden_reference = true;
        } else {
            state.has_vp8_golden_reference = false;
        }
    }
    if (update.copy_to_alternate != .none and !update.refresh_alternate) {
        if (vp8ReferenceCopySource(update.copy_to_alternate, refs, state)) |source| {
            @memcpy(refs.alternate, source);
            state.has_vp8_alternate_reference = true;
        } else {
            state.has_vp8_alternate_reference = false;
        }
    }
    if (update.refresh_golden) {
        @memcpy(refs.golden, current);
        state.has_vp8_golden_reference = true;
    }
    if (update.refresh_alternate) {
        @memcpy(refs.alternate, current);
        state.has_vp8_alternate_reference = true;
    }
    if (update.refresh_last) {
        @memcpy(refs.last, current);
        state.has_vp8_reference = true;
    }
}

fn vp8CurrentYuvReference(header: Header, scratch: []u8) ?[]u8 {
    return vp8CurrentYuvReferenceRequired(header, scratch) catch null;
}

fn vp8CurrentYuvReferenceRequired(header: Header, scratch: []u8) Error![]u8 {
    const rgba_len = try vp8RgbaReferenceByteLen(header);
    const yuv_len = webp.vp8VideoReferenceByteLen(.{ .width = header.width, .height = header.height }) catch |err| return mapImageDecodeError(err);
    const total_len = try referenceScratchByteLen(header);
    if (scratch.len < total_len) return error.PixelBudget;
    return scratch[rgba_len + yuv_len * vp8_stored_reference_count ..][0..yuv_len];
}

fn vp8RgbaReferenceByteLen(header: Header) Error!usize {
    const count = image_common.pixelCount(.{ .width = header.width, .height = header.height }) catch |err| return mapImageDecodeError(err);
    return image_common.checkedMul(count, color_byte_len) catch return error.PixelBudget;
}

fn colorBytes(value: []const ui.Color) []const u8 {
    return @as([*]const u8, @ptrCast(value.ptr))[0 .. value.len * @sizeOf(ui.Color)];
}

const Vp8StoredYuvReferences = struct {
    last: []u8,
    golden: []u8,
    alternate: []u8,
};

fn vp8StoredYuvReferences(header: Header, scratch: []u8) Error!Vp8StoredYuvReferences {
    const rgba_len = try vp8RgbaReferenceByteLen(header);
    const yuv_len = webp.vp8VideoReferenceByteLen(.{ .width = header.width, .height = header.height }) catch |err| return mapImageDecodeError(err);
    const total_len = try referenceScratchByteLen(header);
    if (scratch.len < total_len) return error.PixelBudget;
    const yuv = scratch[rgba_len..][0 .. yuv_len * vp8_stored_reference_count];
    return .{
        .last = yuv[0..yuv_len],
        .golden = yuv[yuv_len..][0..yuv_len],
        .alternate = yuv[yuv_len * 2 ..][0..yuv_len],
    };
}

fn vp8ReferenceCopySource(copy: webp.Vp8ReferenceCopy, refs: Vp8StoredYuvReferences, state: *const FrameDecodeState) ?[]const u8 {
    return switch (copy) {
        .none => null,
        .last => if (state.has_vp8_reference) refs.last else null,
        .golden => if (state.has_vp8_golden_reference) refs.golden else null,
        .alternate => if (state.has_vp8_alternate_reference) refs.alternate else null,
    };
}
