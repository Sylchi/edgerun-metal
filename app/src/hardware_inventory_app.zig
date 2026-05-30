const std = @import("std");
const acpi = @import("acpi.zig");
const bytes = @import("bytes.zig");
const hardware_inventory = @import("hardware_inventory.zig");
const tpm_acpi = @import("tpm_acpi.zig");
const component_union = @import("ui/components/Component.zig");
const stack_component = @import("ui/components/Stack.zig");
const ui = @import("ui/core.zig");

const Component = component_union.Component;
const Stack = stack_component.Stack(Component);

pub const max_rows = 8;
pub const component_count = max_rows + 1;
pub const detail_bytes = 64;

const magic = "ERHI001\x00";
const magic_offset = 0;
const sequence_offset = magic_offset + magic.len;
const flags_offset = sequence_offset + 8;
const table_count_offset = flags_offset + 2;
const pci_count_offset = table_count_offset + 2;
const row_count_offset = pci_count_offset + 2;
const header_size = row_count_offset + 2;
const details_offset = header_size;

pub const state_size = header_size + max_rows * detail_bytes;

const flag_collected: u16 = 1 << 0;
const flag_rsdp: u16 = 1 << 1;
const flag_interrupt_topology: u16 = 1 << 2;
const flag_pci_ecam: u16 = 1 << 3;
const flag_hpet: u16 = 1 << 4;
const flag_fadt: u16 = 1 << 5;
const flag_tpm2_crb: u16 = 1 << 6;
const flag_pci_scanned: u16 = 1 << 7;
const flag_pci_overflow: u16 = 1 << 8;

const row_boot = 0;
const row_acpi_root = 1;
const row_tables = 2;
const row_interrupts = 3;
const row_pci_ecam = 4;
const row_tpm = 5;
const row_pci_devices = 6;
const row_status = 7;
const title_index = 0;
const row_id_base = 1;
const stack_gap: u16 = 6;
const stack_padding: u16 = 16;

const row_titles = [_][]const u8{
    "Boot services",
    "ACPI root",
    "ACPI tables",
    "Interrupts",
    "PCI ECAM",
    "TPM2",
    "PCI devices",
    "Status",
};

pub const WriteError = error{
    NoSpace,
    InvalidState,
};

pub const ViewError = error{
    Corrupt,
};

pub fn writeState(out: []u8, inventory: hardware_inventory.Inventory, sequence: u64) WriteError![]u8 {
    if (out.len < state_size) return error.NoSpace;
    const state = out[0..state_size];
    bytes.zero(state);
    _ = bytes.copy(state[magic_offset..][0..magic.len], magic);
    if (!bytes.store64(state[sequence_offset..][0..8], sequence) or
        !bytes.store16(state[flags_offset..][0..2], flagsFromInventory(inventory)) or
        !bytes.store16(state[table_count_offset..][0..2], countToU16(inventory.tables.table_count)) or
        !bytes.store16(state[pci_count_offset..][0..2], countToU16(inventory.pci.device_count)) or
        !bytes.store16(state[row_count_offset..][0..2], max_rows))
    {
        return error.InvalidState;
    }

    writeDetail(state, row_boot, if (inventory.collected_before_exit_boot_services) "collected before ExitBootServices" else "not collected");
    writeDetail(state, row_acpi_root, if (inventory.rsdp.found and inventory.rsdp.checksum_valid) "RSDP checksum valid" else "RSDP missing or invalid");
    try writeDetailFmt(state, row_tables, "{d} table(s), {s}", .{ inventory.tables.table_count, if (inventory.tables.found) "root valid" else "root missing" });

    if (inventory.madt) |madt| {
        try writeDetailFmt(state, row_interrupts, "{d} LAPIC, {d} IOAPIC, {d} override", .{ madt.lapic_count, madt.ioapic_count, madt.interrupt_source_override_count });
    } else {
        writeDetail(state, row_interrupts, "not detected");
    }

    if (inventory.mcfg) |mcfg| {
        try writeDetailFmt(state, row_pci_ecam, "{d} allocation(s)", .{mcfg.allocation_count});
    } else {
        writeDetail(state, row_pci_ecam, "not detected");
    }

    if (inventory.tpm2) |tpm2| {
        try writeDetailFmt(state, row_tpm, "method {d}, control 0x{x}", .{ tpm2.start_method, tpm2.control_area });
    } else {
        writeDetail(state, row_tpm, "not detected");
    }

    try writeDetailFmt(state, row_pci_devices, "{d} device(s), overflow {s}", .{ inventory.pci.device_count, if (inventory.pci.overflowed) "yes" else "no" });
    writeDetail(state, row_status, if (ready(inventory)) "ready for UI render" else "partial inventory");
    return state;
}

pub fn view(state: []const u8) ViewError!View {
    if (state.len < state_size or !bytes.eql(state[magic_offset..][0..magic.len], magic)) return error.Corrupt;
    const row_count_value = bytes.load16(state[row_count_offset..][0..2]) orelse return error.Corrupt;
    if (row_count_value != max_rows) return error.Corrupt;
    return .{ .state = state[0..state_size] };
}

pub const View = struct {
    state: []const u8,

    pub fn sequence(self: View) u64 {
        return bytes.load64(self.state[sequence_offset..][0..8]) orelse 0;
    }

    pub fn flags(self: View) u16 {
        return bytes.load16(self.state[flags_offset..][0..2]) orelse 0;
    }

    pub fn tableCount(self: View) u16 {
        return bytes.load16(self.state[table_count_offset..][0..2]) orelse 0;
    }

    pub fn pciCount(self: View) u16 {
        return bytes.load16(self.state[pci_count_offset..][0..2]) orelse 0;
    }

    pub fn detail(self: View, row: usize) []const u8 {
        if (row >= max_rows) return "";
        const raw = self.state[detailOffset(row)..][0..detail_bytes];
        var len: usize = 0;
        while (len < raw.len and raw[len] != 0) : (len += 1) {}
        return raw[0..len];
    }

    pub fn componentStack(self: View, out_components: []Component) ?Stack {
        if (out_components.len < component_count) return null;

        var index: usize = 0;
        while (index < component_count) : (index += 1) {
            out_components[index] = self.componentAt(index) orelse return null;
        }
        return .{
            .axis = .column,
            .gap = stack_gap,
            .padding = stack_padding,
            .children = out_components[0..component_count],
        };
    }

    fn componentAt(self: View, index: usize) ?Component {
        return switch (index) {
            title_index => .{ .text = .{ .value = "Hardware inventory" } },
            row_id_base...max_rows => |component_index| blk: {
                const row = component_index - row_id_base;
                break :blk .{ .row_item = .{
                    .id = @intCast(component_index),
                    .title = row_titles[row],
                    .detail = self.detail(row),
                } };
            },
            else => null,
        };
    }
};

fn flagsFromInventory(inventory: hardware_inventory.Inventory) u16 {
    var flags: u16 = 0;
    if (inventory.collected_before_exit_boot_services) flags |= flag_collected;
    if (inventory.rsdp.found and inventory.rsdp.checksum_valid) flags |= flag_rsdp;
    if (inventory.hasInterruptTopology()) flags |= flag_interrupt_topology;
    if (inventory.hasPciEcam()) flags |= flag_pci_ecam;
    if (inventory.hpet != null and inventory.hpet.?.found and inventory.hpet.?.checksum_valid) flags |= flag_hpet;
    if (inventory.fadt != null and inventory.fadt.?.found and inventory.fadt.?.checksum_valid) flags |= flag_fadt;
    if (inventory.hasTpm2Crb()) flags |= flag_tpm2_crb;
    if (inventory.pci.scanned) flags |= flag_pci_scanned;
    if (inventory.pci.overflowed) flags |= flag_pci_overflow;
    return flags;
}

fn ready(inventory: hardware_inventory.Inventory) bool {
    return inventory.collected_before_exit_boot_services and
        inventory.rsdp.found and
        inventory.tables.found and
        inventory.hasInterruptTopology() and
        inventory.hasPciEcam() and
        inventory.hasTpm2Crb();
}

fn countToU16(value: usize) u16 {
    return @intCast(@min(value, 0xFFFF));
}

fn detailOffset(row: usize) usize {
    return details_offset + row * detail_bytes;
}

fn writeDetail(state: []u8, row: usize, value: []const u8) void {
    const out = state[detailOffset(row)..][0..detail_bytes];
    bytes.zero(out);
    const len = @min(value.len, detail_bytes - 1);
    _ = bytes.copy(out[0..len], value[0..len]);
}

fn writeDetailFmt(state: []u8, row: usize, comptime fmt: []const u8, args: anytype) WriteError!void {
    const out = state[detailOffset(row)..][0..detail_bytes];
    bytes.zero(out);
    _ = std.fmt.bufPrint(out[0 .. detail_bytes - 1], fmt, args) catch return error.InvalidState;
}

pub fn sampleInventory(pci_count: usize) hardware_inventory.Inventory {
    var inventory = hardware_inventory.Inventory{
        .collected_before_exit_boot_services = true,
        .rsdp = .{
            .found = true,
            .revision = 2,
            .checksum_valid = true,
            .xsdt_checksum_valid = true,
            .rsdp_address = 0x1000,
            .xsdt_address = 0x2000,
        },
        .tables = .{
            .found = true,
            .table_kind = .xsdt,
            .table_count = 5,
        },
        .madt = .{
            .found = true,
            .checksum_valid = true,
            .lapic_address = 0xfee0_0000,
            .lapic_count = 1,
        },
        .mcfg = .{
            .found = true,
            .checksum_valid = true,
            .allocation_count = 1,
        },
        .hpet = .{
            .found = true,
            .checksum_valid = true,
        },
        .fadt = .{
            .found = true,
            .checksum_valid = true,
        },
        .tpm2 = tpm_acpi.Tpm2Info{
            .found = true,
            .checksum_valid = true,
            .platform_class = 1,
            .control_area = 0xfed4_0000,
            .start_method = 6,
        },
        .pci = .{
            .scanned = true,
        },
    };

    inventory.pci.device_count = @min(pci_count, inventory.pci.devices.len);
    if (pci_count > inventory.pci.devices.len) inventory.pci.overflowed = true;
    var index: usize = 0;
    while (index < inventory.pci.device_count) : (index += 1) {
        inventory.pci.devices[index] = .{
            .vendor_id = 0x8086,
            .device_id = @intCast(0x1000 + index),
            .class_code = 0x02,
        };
    }
    return inventory;
}

test "hardware inventory state maps shared bytes into ui rows" {
    var state_bytes: [state_size]u8 = undefined;
    _ = try writeState(&state_bytes, sampleInventory(1), 7);
    const state_view = try view(&state_bytes);

    try std.testing.expectEqual(@as(u64, 7), state_view.sequence());
    try std.testing.expectEqual(@as(u16, 5), state_view.tableCount());
    try std.testing.expectEqual(@as(u16, 1), state_view.pciCount());
    try std.testing.expect(bytes.eql(state_view.detail(row_status), "ready for UI render"));

    var components: [component_count]Component = undefined;
    const stack = state_view.componentStack(&components).?;
    var commands: [48]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try stack.render(&scene, .{ .x = 0, .y = 0, .w = 360, .h = 520 }, .{});
    try std.testing.expect(scene.commandCount() > max_rows);
}

test "hardware inventory view publishes canonical ui stack through app storage" {
    const app_mod = @import("app.zig");
    const BoundedArena = @import("arena.zig").BoundedArena;
    const clock = @import("clock.zig");
    const identity = @import("identity.zig");
    const object = @import("object.zig");
    const preimage = @import("preimage.zig");

    var state_bytes: [state_size]u8 = undefined;
    _ = try writeState(&state_bytes, sampleInventory(2), 11);
    const state_view = try view(&state_bytes);

    var stack_components: [component_count]Component = undefined;
    const stack = state_view.componentStack(&stack_components).?;
    try std.testing.expectEqual(@as(usize, component_count), stack.children.len);
    try std.testing.expectEqualStrings("Hardware inventory", stack.children[title_index].text.value);
    try std.testing.expectEqualStrings("2 device(s), overflow no", stack.children[row_pci_devices + row_id_base].row_item.detail);

    var host_memory: [8192]u8 = undefined;
    const epoch = clock.Stamp{ .keeper = .{ .bytes = [_]u8{7} ++ [_]u8{0} ** 31 } };
    const app_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("hardware inventory ui app")).?, epoch).?;
    var app = app_mod.App.initFromHostSlice(app_id, BoundedArena.init(.{ .base = &host_memory }), 4096, 8).?;

    var codec_raw: [1024]u8 = undefined;
    var object_raw: [object.header_size + 1024]u8 = undefined;
    var resolved: [1]object.View = undefined;
    var render_components: [component_count]Component = undefined;
    var nodes: [component_count]ui.Node = undefined;
    const scratch = app_mod.App.UiScratch{
        .codec = &codec_raw,
        .object = &object_raw,
        .resolved = &resolved,
        .components = &render_components,
        .nodes = &nodes,
    };

    const published = try app.publishUiStack(stack, epoch, scratch);
    const stored = app.storedObject(published.object_id).?;
    try std.testing.expectEqual(object.Kind.bytes, stored.header.kind);
    try std.testing.expectEqual(object.Visibility.app_namespace, stored.header.requirements.visibility);

    var commands: [64]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try app.renderPublishedUi(published, scratch, &scene, .{ .x = 0, .y = 0, .w = 360, .h = 520 }, .{});

    try std.testing.expect(scene.commandCount() != 0);
}

test "hardware inventory view observes in-place producer updates" {
    var state_bytes: [state_size]u8 = undefined;
    _ = try writeState(&state_bytes, sampleInventory(1), 1);
    const state_view = try view(&state_bytes);
    try std.testing.expect(bytes.eql(state_view.detail(row_pci_devices), "1 device(s), overflow no"));

    _ = try writeState(&state_bytes, sampleInventory(2), 2);
    try std.testing.expectEqual(@as(u64, 2), state_view.sequence());
    try std.testing.expect(bytes.eql(state_view.detail(row_pci_devices), "2 device(s), overflow no"));
}
