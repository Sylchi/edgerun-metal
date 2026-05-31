// EdgeRun system-call library — host-side import declarations and constants.
//
// This module declares WASM imports from the host's "er" module and exposes
// them as plain Zig functions.  It has zero dependencies on the UI runtime
// (no state.zig, no app_frame, no render).  Any WASM target — whether the
// compiled .er module or standalone Zig WASM binary can import this file to
// call host syscalls.
//
// Host-side implementation lives in asm/x86_64/crypto/ (local_cell.asm,
// local_route.asm).  The kernel wires the import table into the WASM
// interpreter at boot; these externs resolve against that table.

// -----------------------------------------------------------------
// Local cell layout  (matches local_constants.inc)
// -----------------------------------------------------------------

pub const cell_circ_id: u32 = 0;
pub const cell_cmd: u32 = 4;
pub const cell_payload: u32 = 5;
pub const cell_size: u32 = 256;
pub const cell_payload_len: u32 = 251;
pub const cell_header_len: u32 = 5;

pub const cell_data: u32 = 1;
pub const cell_open: u32 = 2;
pub const cell_close: u32 = 3;

// -----------------------------------------------------------------
// SPSC ring buffer layout  (local_constants.inc)
// -----------------------------------------------------------------

pub const ring_slots: u32 = 64;
pub const ring_head: u32 = 0;
pub const ring_tail: u32 = 4;
pub const ring_cells: u32 = 8;
pub const ring_size: u32 = 8 + ring_slots * cell_size;

// -----------------------------------------------------------------
// Identity routing table entry layout
// -----------------------------------------------------------------

pub const id_hash: u32 = 0;
pub const id_ring: u32 = 32;
pub const id_slot_size: u32 = 32 + ring_size;
pub const max_identities: u32 = 16;

// -----------------------------------------------------------------
// Error codes returned via edx  (local_constants.inc)
// -----------------------------------------------------------------

pub const err_full: u32 = 80;
pub const err_empty: u32 = 81;
pub const err_not_found: u32 = 82;
pub const err_exists: u32 = 83;
pub const err_busy: u32 = 84;

// -----------------------------------------------------------------
// Agent protocol constants
// -----------------------------------------------------------------

/// Agent message types (byte 0 of agent cell payload)
pub const agent_msg_request: u32 = 1;
pub const agent_msg_response: u32 = 2;
pub const agent_msg_error: u32 = 3;

/// Agent message flags (byte 1 of agent cell payload)
pub const agent_flag_more: u32 = 1;
pub const agent_flag_end: u32 = 2;

/// Offset of sender_slot_id in agent request payload
pub const agent_sender_off: u32 = 2;

/// Agent identity labels (well-known)
pub const http_agent_label: []const u8 = "edgerun.agent.http";

/// Precomputed BLAKE3 hash of "edgerun.agent.http"
pub const http_agent_hash = [32]u8{
    0x0e, 0x7f, 0xd9, 0x95, 0x8e, 0x6b, 0xb9, 0x9f,
    0x09, 0xc9, 0x11, 0x09, 0xa5, 0x60, 0x9a, 0x71,
    0x5d, 0x94, 0x85, 0x3d, 0x17, 0x8b, 0x72, 0x32,
    0xdd, 0x91, 0x2f, 0xf8, 0x06, 0x4e, 0xba, 0xb4,
};

// -----------------------------------------------------------------
// Host import declarations
//
// These are resolved by the WASM interpreter at module load time
// against the import table in the kernel's WASM runtime config.
// All pointer-like parameters are WASM linear-memory offsets (u32).
// Return values follow the two-register convention:
//   eax = primary value (or -1 on error)
//   edx = 0 on success, error code on failure
// -----------------------------------------------------------------

extern "er" fn cell_send(dest_hash_ptr: u32, cell_ptr: u32) u32;
extern "er" fn cell_recv(slot_id: u32, out_cell_ptr: u32) u32;
extern "er" fn route_register(identity_hash: u32) u32;
extern "er" fn route_lookup(identity_hash: u32) u32;
extern "er" fn route_unregister(slot_id: u32) u32;
extern "er" fn cell_available(slot_id: u32) u32;

// -----------------------------------------------------------------
// Zig-side convenience wrappers
//
// These take explicit WASM linear-memory offsets as u32 values.
// They do not reference any global state.  Callers must provide
// the offset into their own linear memory where data lives.
// -----------------------------------------------------------------

/// Register an identity for local cell delivery.
/// Returns slot_id on success, or an error constant.
pub inline fn register(hash_offset: u32) u32 {
    return route_register(hash_offset);
}

/// Look up the slot_id for a given identity hash.
/// Returns slot_id, or err_not_found (-1 via edx).
pub inline fn lookup(hash_offset: u32) u32 {
    return route_lookup(hash_offset);
}

/// Unregister a previously registered identity slot.
pub inline fn unregister(slot_id: u32) u32 {
    return route_unregister(slot_id);
}

/// Send a cell to the identity identified by hash.
/// Both hash and cell must already be in WASM linear memory.
pub inline fn send(hash_offset: u32, cell_offset: u32) u32 {
    return cell_send(hash_offset, cell_offset);
}

/// Receive a cell from a slot's incoming ring buffer.
/// The cell data is written into the caller-provided buffer offset.
pub inline fn recv(slot_id: u32, out_offset: u32) u32 {
    return cell_recv(slot_id, out_offset);
}

/// Return the number of cells waiting in a slot's ring buffer.
pub inline fn available(slot_id: u32) u32 {
    return cell_available(slot_id);
}
