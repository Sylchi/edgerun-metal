pub const Error = error{
    BadAudio,
    UnsupportedAudio,
};

pub const Format = enum {
    webm,
};

pub const Codec = enum {
    opus,
    vorbis,
};

pub const Header = struct {
    format: Format,
    codec: Codec,
    sample_rate_hz: u32,
    channels: u8,
    packet_count: ?usize,
};

pub const Packet = struct {
    header: Header,
    index: usize,
    timestamp: u64,
    payload: []const u8,
};

pub const PacketRecord = struct {
    packet: Packet,
    next_cursor: usize,
};
