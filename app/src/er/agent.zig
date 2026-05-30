// EdgeRun WASM agent SDK
//
// Provides helpers to communicate with kernel agents via the cell system.
// Uses the 6 host imports from er/sys.zig.
//
// All functions work with WASM linear memory offsets. The caller must
// allocate cell-sized buffers (256 bytes) in their linear memory and
// pass offsets to these functions.

const er = @import("er");

// -----------------------------------------------------------------
// Agent request payload layout (inside cell payload, 251 bytes)
//
// Byte 0:     msg_type (AGENT_MSG_REQUEST = 1)
// Byte 1:     flags (AGENT_FLAG_END = 2)
// Byte 2-5:   sender_slot_id (u32 LE)
// Byte 6+:    agent-specific request body
// -----------------------------------------------------------------

pub const sender_off: u32 = 2;

// -----------------------------------------------------------------
// HTTP agent request payload layout
//
// Byte 6-9:   dst_ip (u32, network byte order)
// Byte 10-11: dst_port (u16, host byte order)
// Byte 12:    host_len
// Byte 13+:   host string
// ...         url_len + url string
// -----------------------------------------------------------------

pub const http_dst_ip_off: u32 = 6;
pub const http_dst_port_off: u32 = 10;
pub const http_host_len_off: u32 = 12;
pub const http_host_off: u32 = 13;

// -----------------------------------------------------------------
// Agent response payload layout
//
// Byte 0:     msg_type (AGENT_MSG_RESPONSE = 2, AGENT_MSG_ERROR = 3)
// Byte 1:     flags (AGENT_FLAG_END = 2)
// Byte 2-3:   status_code (u16 LE)
// Byte 4+:    body data
// -----------------------------------------------------------------

pub const resp_status_off: u32 = 2;
pub const resp_body_off: u32 = 4;

pub const AgentResponse = struct {
    msg_type: u8,
    status: u16,
    valid: bool,
};

/// Build an HTTP GET request cell at the given offset.
/// The cell_offset must point to 256 bytes of writable linear memory.
pub fn buildHttpRequest(
    cell_offset: u32,
    slot_id: u32,
    dst_ip: u32,
    dst_port: u16,
    host: []const u8,
    path: []const u8,
) void {
    const mem = @as([*]u8, @ptrFromInt(0));

    // Cell header
    mem[cell_offset + er.cell_circ_id + 0 ..][0..4].* = @as(u32, 0);
    mem[cell_offset + er.cell_cmd] = @as(u8, @intCast(er.cell_data));

    // Payload: agent message header
    const p = cell_offset + er.cell_payload;
    mem[p] = @as(u8, @intCast(er.agent_msg_request));
    mem[p + 1] = @as(u8, @intCast(er.agent_flag_end));
    @as(*u32, @ptrFromInt(mem + p + 2)).* = slot_id;

    // dst_ip
    @as(*u32, @ptrFromInt(mem + p + 6)).* = dst_ip;
    // dst_port
    @as(*u16, @ptrFromInt(mem + p + 10)).* = dst_port;
    // host
    mem[p + 12] = @as(u8, @intCast(host.len));
    @memcpy(mem[p + 13 .. p + 13 + host.len], host);
    // path
    const url_off = p + 13 + host.len;
    mem[url_off] = @as(u8, @intCast(path.len));
    @memcpy(mem[url_off + 1 .. url_off + 1 + path.len], path);
}

/// Send a cell to an agent identity and wait for the response.
/// Returns when a response cell is available in the slot's ring buffer.
pub fn sendAndRecv(
    hash_offset: u32,
    cell_offset: u32,
    resp_offset: u32,
    slot_id: u32,
) AgentResponse {
    // Send the request cell
    _ = er.cell_send(hash_offset, cell_offset);

    // Poll for response (the synchronous handler has already placed it)
    // If not ready yet, spin briefly
    var avail = er.cell_available(slot_id);
    var spins: u32 = 0;
    while (avail == 0 and spins < 10000) : (spins += 1) {
        avail = er.cell_available(slot_id);
    }

    if (avail == 0) {
        return .{ .msg_type = 0, .status = 0, .valid = false };
    }

    _ = er.cell_recv(slot_id, resp_offset);

    const mem = @as([*]u8, @ptrFromInt(0));
    const p = resp_offset + er.cell_payload;
    return .{
        .msg_type = mem[p],
        .status = @as(u16, @bitCast(mem[p + 2 .. p + 4].*)),
        .valid = true,
    };
}
