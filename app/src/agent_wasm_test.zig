const er = @import("er/sys.zig");

// Scratch buffers in WASM linear memory
var cell_buf: [256]u8 align(8) = undefined;
var resp_buf: [256]u8 align(8) = undefined;
var test_hash: [32]u8 align(8) = undefined;

export fn f() u32 {
    const cell_off = @intFromPtr(&cell_buf);
    const resp_off = @intFromPtr(&resp_buf);
    const hash_off = @intFromPtr(&test_hash);

    // Zero the hash buffer and set a unique marker
    @memset(test_hash[0..], 0);
    test_hash[0] = 0x01;

    // Register our temporary identity
    const slot_id = er.register(hash_off);
    if (slot_id == 0xFFFFFFFF) return 2;

    // Build cell header
    @as(*u32, @ptrFromInt(cell_off + er.cell_circ_id)).* = 0;
    cell_buf[er.cell_cmd] = @as(u8, @intCast(er.cell_data));

    // Build agent request payload
    const p = er.cell_payload;
    cell_buf[p] = @as(u8, @intCast(er.agent_msg_request));
    cell_buf[p + 1] = @as(u8, @intCast(er.agent_flag_end));
    @as(*u32, @ptrFromInt(cell_off + p + 2)).* = slot_id;

    // HTTP request fields
    @as(*u32, @ptrFromInt(cell_off + p + 6)).* = 0x0202000A; // dst_ip = 10.0.2.2
    @as(*u16, @ptrFromInt(cell_off + p + 10)).* = 80;        // dst_port

    const host = "example.com";
    cell_buf[p + 12] = @as(u8, @intCast(host.len));
    @memcpy(cell_buf[p + 13 .. p + 13 + host.len], host);

    const path = "/";
    const url_off = p + 13 + host.len;
    cell_buf[url_off] = @as(u8, @intCast(path.len));
    @memcpy(cell_buf[url_off + 1 .. url_off + 1 + path.len], path);

    // Send to HTTP agent
    const agent_hash = er.http_agent_hash;
    const agent_hash_off = @intFromPtr(&agent_hash);
    _ = er.send(agent_hash_off, cell_off);

    // Poll for response
    var avail = er.available(slot_id);
    var spins: u32 = 0;
    while (avail == 0 and spins < 50000) : (spins += 1) {
        avail = er.available(slot_id);
    }

    if (avail == 0) return 1; // timeout

    _ = er.recv(slot_id, resp_off);

    // Check response type
    if (resp_buf[er.cell_payload] != er.agent_msg_response) return 3;

    return 0; // success
}
