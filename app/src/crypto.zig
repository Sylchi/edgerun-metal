const bytes = @import("bytes.zig");

pub const blake3 = struct {
    const Self = @This();

    pub const Options = struct {};

    const out_len: usize = 32;
    const block_len: usize = 64;
    const chunk_len: usize = 1024;
    const blocks_per_chunk: usize = chunk_len / block_len;
    const max_stack_len: usize = 54;

    const flag_chunk_start: u32 = 1 << 0;
    const flag_chunk_end: u32 = 1 << 1;
    const flag_parent: u32 = 1 << 2;
    const flag_root: u32 = 1 << 3;

    const iv = [8]u32{
        0x6A09E667,
        0xBB67AE85,
        0x3C6EF372,
        0xA54FF53A,
        0x510E527F,
        0x9B05688C,
        0x1F83D9AB,
        0x5BE0CD19,
    };

    const message_permutation = [16]usize{
        2, 6,  3,  10, 7, 0,  4,  13,
        1, 11, 12, 5,  9, 14, 15, 8,
    };

    chunk_cv: [8]u32 = iv,
    chunk_counter: u64 = 0,
    block: [block_len]u8 = [_]u8{0} ** block_len,
    block_used: usize = 0,
    blocks_compressed: usize = 0,
    cv_stack: [max_stack_len][8]u32 = undefined,
    cv_stack_len: usize = 0,

    pub fn init(_: Options) Self {
        return .{};
    }

    pub fn hash(input: []const u8, out: *[out_len]u8, options: Options) void {
        var hasher = init(options);
        hasher.update(input);
        hasher.final(out);
    }

    pub fn update(self: *Self, input: []const u8) void {
        var cursor: usize = 0;
        while (cursor < input.len) {
            if (self.block_used == block_len) self.compressBufferedBlock(false);
            const take = @min(block_len - self.block_used, input.len - cursor);
            _ = bytes.copy(self.block[self.block_used..][0..take], input[cursor..][0..take]);
            self.block_used += take;
            cursor += take;
        }
    }

    pub fn final(self: *Self, out: *[out_len]u8) void {
        const chunk_flags = self.chunkFlags() | flag_chunk_end;
        if (self.cv_stack_len == 0) {
            const root_words = compress(
                self.chunk_cv,
                blockWords(&self.block),
                self.chunk_counter,
                @intCast(self.block_used),
                chunk_flags | flag_root,
            );
            storeWords(out, root_words[0..8]);
            return;
        }

        var right_cv = compressCv(
            self.chunk_cv,
            blockWords(&self.block),
            self.chunk_counter,
            @intCast(self.block_used),
            chunk_flags,
        );
        while (self.cv_stack_len > 1) {
            self.cv_stack_len -= 1;
            right_cv = parentCv(self.cv_stack[self.cv_stack_len], right_cv);
        }
        self.cv_stack_len -= 1;
        const root_words = parentOutput(self.cv_stack[self.cv_stack_len], right_cv, true);
        storeWords(out, root_words[0..8]);
    }

    fn chunkFlags(self: Self) u32 {
        return if (self.blocks_compressed == 0) flag_chunk_start else 0;
    }

    fn compressBufferedBlock(self: *Self, force_end: bool) void {
        const end_chunk = force_end or self.blocks_compressed + 1 == blocks_per_chunk;
        const flags = self.chunkFlags() | if (end_chunk) flag_chunk_end else 0;
        self.chunk_cv = compressCv(
            self.chunk_cv,
            blockWords(&self.block),
            self.chunk_counter,
            block_len,
            flags,
        );
        self.blocks_compressed += 1;
        self.block_used = 0;
        bytes.zero(&self.block);
        if (end_chunk) self.completeChunk();
    }

    fn completeChunk(self: *Self) void {
        var new_cv = self.chunk_cv;
        var completed_chunks = self.chunk_counter + 1;
        while ((completed_chunks & 1) == 0) : (completed_chunks >>= 1) {
            self.cv_stack_len -= 1;
            new_cv = parentCv(self.cv_stack[self.cv_stack_len], new_cv);
        }
        self.cv_stack[self.cv_stack_len] = new_cv;
        self.cv_stack_len += 1;
        self.chunk_counter += 1;
        self.chunk_cv = iv;
        self.blocks_compressed = 0;
        self.block_used = 0;
        bytes.zero(&self.block);
    }

    fn parentCv(left: [8]u32, right: [8]u32) [8]u32 {
        const words = parentOutput(left, right, false);
        return words[0..8].*;
    }

    fn parentOutput(left: [8]u32, right: [8]u32, root: bool) [16]u32 {
        var block_words: [16]u32 = undefined;
        block_words[0..8].* = left;
        block_words[8..16].* = right;
        return compress(iv, block_words, 0, block_len, flag_parent | if (root) flag_root else 0);
    }

    fn compressCv(cv: [8]u32, block_words: [16]u32, counter: u64, block_length: u32, flags: u32) [8]u32 {
        const words = compress(cv, block_words, counter, block_length, flags);
        return words[0..8].*;
    }

    fn compress(cv: [8]u32, block_words: [16]u32, counter: u64, block_length: u32, flags: u32) [16]u32 {
        var state = [16]u32{
            cv[0],
            cv[1],
            cv[2],
            cv[3],
            cv[4],
            cv[5],
            cv[6],
            cv[7],
            iv[0],
            iv[1],
            iv[2],
            iv[3],
            @truncate(counter),
            @truncate(counter >> 32),
            block_length,
            flags,
        };
        var message = block_words;

        var round: usize = 0;
        while (round < 7) : (round += 1) {
            roundCompress(&state, message);
            message = permute(message);
        }

        var out: [16]u32 = undefined;
        var index: usize = 0;
        while (index < 8) : (index += 1) {
            out[index] = state[index] ^ state[index + 8];
            out[index + 8] = state[index + 8] ^ cv[index];
        }
        return out;
    }

    fn roundCompress(state: *[16]u32, message: [16]u32) void {
        g(state, 0, 4, 8, 12, message[0], message[1]);
        g(state, 1, 5, 9, 13, message[2], message[3]);
        g(state, 2, 6, 10, 14, message[4], message[5]);
        g(state, 3, 7, 11, 15, message[6], message[7]);
        g(state, 0, 5, 10, 15, message[8], message[9]);
        g(state, 1, 6, 11, 12, message[10], message[11]);
        g(state, 2, 7, 8, 13, message[12], message[13]);
        g(state, 3, 4, 9, 14, message[14], message[15]);
    }

    fn g(state: *[16]u32, a: usize, b: usize, c: usize, d: usize, mx: u32, my: u32) void {
        state[a] = state[a] +% state[b] +% mx;
        state[d] = rotr32(state[d] ^ state[a], 16);
        state[c] = state[c] +% state[d];
        state[b] = rotr32(state[b] ^ state[c], 12);
        state[a] = state[a] +% state[b] +% my;
        state[d] = rotr32(state[d] ^ state[a], 8);
        state[c] = state[c] +% state[d];
        state[b] = rotr32(state[b] ^ state[c], 7);
    }

    fn rotr32(value: u32, shift: u5) u32 {
        return (value >> shift) | (value << @as(u5, @intCast(32 - @as(u6, shift))));
    }

    fn permute(input: [16]u32) [16]u32 {
        var out: [16]u32 = undefined;
        var index: usize = 0;
        while (index < out.len) : (index += 1) {
            out[index] = input[message_permutation[index]];
        }
        return out;
    }

    fn blockWords(block_bytes: *const [block_len]u8) [16]u32 {
        var out: [16]u32 = undefined;
        var index: usize = 0;
        while (index < out.len) : (index += 1) {
            out[index] = bytes.load32(block_bytes[index * 4 ..][0..4]).?;
        }
        return out;
    }

    fn storeWords(out: *[out_len]u8, words: []const u32) void {
        var index: usize = 0;
        while (index < words.len) : (index += 1) {
            _ = bytes.store32(out[index * 4 ..][0..4], words[index]);
        }
    }
};

test "project blake3 matches fixed vectors" {
    var out: [32]u8 = undefined;

    blake3.hash("", &out, .{});
    try expectEqualSlices(&hexToBytes("af1349b9f5f9a1a6a0404dea36dcc9499bcb25c9adc112b7cc9a93cae41f3262"), &out);

    blake3.hash("abc", &out, .{});
    try expectEqualSlices(&hexToBytes("6437b3ac38465133ffb63b75273a8db548c558465d79db03fd359c6cd5bd9d85"), &out);

    var data: [1500]u8 = undefined;
    for (&data, 0..) |*byte, index| byte.* = @truncate(index *% 31 +% 7);
    blake3.hash(&data, &out, .{});
    try expectEqualSlices(&hexToBytes("f39bf6cbbf1da8ee9d126346f72350101792ed2d8e0c01c53995ebc3f476123c"), &out);
}

test "project blake3 streaming matches one shot" {
    var data: [1500]u8 = undefined;
    for (&data, 0..) |*byte, index| byte.* = @truncate(index *% 13 +% 19);

    var one_shot: [32]u8 = undefined;
    blake3.hash(&data, &one_shot, .{});

    var hasher = blake3.init(.{});
    hasher.update(data[0..17]);
    hasher.update(data[17..1024]);
    hasher.update(data[1024..]);
    var streamed: [32]u8 = undefined;
    hasher.final(&streamed);

    try expectEqualSlices(&one_shot, &streamed);
}

fn expectEqualSlices(expected: []const u8, actual: []const u8) !void {
    if (!bytes.eql(expected, actual)) return error.TestExpectedEqual;
}

fn hexToBytes(comptime hex: []const u8) [hex.len / 2]u8 {
    var out: [hex.len / 2]u8 = undefined;
    var index: usize = 0;
    while (index < out.len) : (index += 1) {
        out[index] = (hexNibble(hex[index * 2]) << 4) | hexNibble(hex[index * 2 + 1]);
    }
    return out;
}

fn hexNibble(byte: u8) u8 {
    return switch (byte) {
        '0'...'9' => byte - '0',
        'a'...'f' => byte - 'a' + 10,
        else => unreachable,
    };
}
