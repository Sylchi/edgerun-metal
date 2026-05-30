// EdgeRun system-call library — host-side import declarations and constants.
//
// This module declares WASM imports from the host's "er" module and exposes
// them as plain Zig functions.  It has zero dependencies on the UI runtime
// (no state.zig, no app_frame, no render).  Any WASM target — whether the
// built-in app_runtime, a compiled .er module, or a standalone Zig WASM
// binary — can import this file to call host syscalls.
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
