const bytes = @import("bytes.zig");

pub const page_size: u64 = 4096;
pub const memory_resource_id_prefix = "boot-memory-";

pub const Error = error{
    NoSpace,
};

pub const MemoryKind = enum(u8) {
    usable = 1,
    firmware = 2,
    runtime = 3,
    acpi_reclaim = 4,
    acpi_nvs = 5,
    mmio = 6,
    persistent = 7,
    unusable = 8,
    unknown = 9,
};

pub const VerifierKind = enum(u8) {
    software_p256_sha256 = 1,
    tpm_p256_sha256 = 2,
};

pub const MemoryRegion = struct {
    kind: MemoryKind,
    physical_start: u64,
    page_count: u64,

    pub fn init(kind: MemoryKind, physical_start: u64, page_count: u64) MemoryRegion {
        return .{
            .kind = kind,
            .physical_start = physical_start,
            .page_count = page_count,
        };
    }

    pub fn valid(self: MemoryRegion) bool {
        if (self.page_count == 0) return false;
        return self.byteLength() != null;
    }

    pub fn byteLength(self: MemoryRegion) ?u64 {
        return checkedMulU64(self.page_count, page_size);
    }

    pub fn usable(self: MemoryRegion) bool {
        return self.kind == .usable and self.valid();
    }
};

pub const Map = struct {
    memory_regions: []const MemoryRegion,
    verifier_kind: VerifierKind,
};

pub const ResourceIdStorage = [memory_resource_id_prefix.len + @sizeOf(usize) * 2]u8;

pub fn writeMemoryResourceId(index: usize, out: []u8) ?[]const u8 {
    const prefix_len = memory_resource_id_prefix.len;
    const hex_digits = @sizeOf(usize) * 2;
    const needed = prefix_len + hex_digits;
    if (out.len < needed) return null;
    _ = bytes.copy(out[0..prefix_len], memory_resource_id_prefix);
    var shift: u6 = @intCast(@bitSizeOf(usize) - 4);
    var cursor = prefix_len;
    while (true) {
        const nibble: u8 = @truncate((index >> shift) & 0xf);
        out[cursor] = if (nibble < 10) '0' + nibble else 'a' + (nibble - 10);
        cursor += 1;
        if (shift == 0) break;
        shift -= 4;
    }
    return out[0..needed];
}

fn checkedMulU64(left: u64, right: u64) ?u64 {
    if (left != 0 and right > max_u64 / left) return null;
    return left * right;
}

const max_u64: u64 = 0xffff_ffff_ffff_ffff;

test "boot resource map writes stable memory resource ids" {
    var raw: ResourceIdStorage = undefined;

    const id = writeMemoryResourceId(3, &raw) orelse return error.NoSpace;

    if (!bytes.eql("boot-memory-0000000000000003", id)) return error.TestExpectedEqual;
}

test "boot resource map carries explicit verifier kind" {
    const regions = [_]MemoryRegion{
        MemoryRegion.init(.usable, 0x100000, 1),
    };
    const pi_map = Map{
        .memory_regions = &regions,
        .verifier_kind = .software_p256_sha256,
    };
    const tpm_map = Map{
        .memory_regions = &regions,
        .verifier_kind = .tpm_p256_sha256,
    };

    if (pi_map.verifier_kind != .software_p256_sha256) return error.TestExpectedEqual;
    if (tpm_map.verifier_kind != .tpm_p256_sha256) return error.TestExpectedEqual;
}

test "boot resource map accepts only non-overflowing memory regions" {
    if (!MemoryRegion.init(.usable, 0x100000, 2).valid()) return error.TestExpectedTrue;
    if (MemoryRegion.init(.usable, 0x100000, 2).byteLength().? != page_size * 2) return error.TestExpectedEqual;
    if (MemoryRegion.init(.usable, 0x100000, 0).valid()) return error.TestExpectedFalse;
    if (MemoryRegion.init(.usable, 0, max_u64).valid()) return error.TestExpectedFalse;
}
