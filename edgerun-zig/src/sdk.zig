const std = @import("std");
const app_mod = @import("app.zig");
const arena = @import("arena.zig");
const bytes = @import("bytes.zig");
const clock = @import("clock.zig");
const grant = @import("grant.zig");
const identity = @import("identity.zig");
const intent = @import("intent.zig");
const object = @import("object.zig");
const preimage = @import("preimage.zig");
const store = @import("store.zig");

pub const identity_hash_size = identity.id_size;
pub const profile_minimal_parent_memory: usize = 4096;
pub const profile_minimal_parent_storage: usize = 4096;
pub const profile_minimal_parent_slots: usize = 16;
pub const profile_minimal_child_memory: usize = 1024;
pub const profile_minimal_child_storage: usize = 1024;
pub const profile_minimal_child_slots: usize = 4;

pub const profile_standard_parent_memory: usize = 16384;
pub const profile_standard_parent_storage: usize = 32768;
pub const profile_standard_parent_slots: usize = 64;
pub const profile_standard_child_memory: usize = 4096;
pub const profile_standard_child_storage: usize = 8192;
pub const profile_standard_child_slots: usize = 16;

pub const profile_ui_parent_memory: usize = 32768;
pub const profile_ui_parent_storage: usize = 65536;
pub const profile_ui_parent_slots: usize = 128;
pub const profile_ui_child_memory: usize = 8192;
pub const profile_ui_child_storage: usize = 16384;
pub const profile_ui_child_slots: usize = 32;

pub const max_parent_memory_bytes = profile_ui_parent_memory;
pub const max_parent_storage_bytes = profile_ui_parent_storage;
pub const max_parent_slots = profile_ui_parent_slots;
pub const canonical_object_buffer_bytes = 512;
pub const max_state_body_bytes = canonical_object_buffer_bytes - object.header_size - object.owner_size;
pub const benchmark_iterations: usize = 2_000;

const default_keeper_material = "edgerun-sdk keeper";
const default_user_material = "edgerun-sdk user";
const default_device_material = "edgerun-sdk device";
const default_allocator_material = "edgerun-sdk allocator";
const default_parent_app_material = "edgerun-sdk root app";
const default_child_app_material = "edgerun-sdk child app";
const default_child_scope_material = "edgerun-sdk child scope";
const default_state_body = "edgerun-sdk state";

pub const Error = error{
    BadConfiguration,
    NoMemory,
    NoStorage,
    Unauthorized,
    NoSpace,
    Corrupt,
};

pub const Profile = enum {
    minimal,
    standard,
    ui,
};

pub const profiles = [_]Profile{ .minimal, .standard, .ui };
pub const operation_matrix = [_]identity.InstantiationOperation{ .verify, .sign, .verify_and_sign };

pub const ResourcePlan = struct {
    parent_memory_bytes: usize,
    parent_storage_bytes: usize,
    parent_storage_slots: usize,
    child_memory_bytes: usize,
    child_storage_bytes: usize,
    child_storage_slots: usize,

    pub fn valid(self: ResourcePlan) bool {
        return self.parent_memory_bytes != 0 and
            self.parent_storage_bytes != 0 and
            self.parent_storage_slots != 0 and
            self.child_memory_bytes != 0 and
            self.child_storage_bytes != 0 and
            self.child_storage_slots != 0 and
            self.child_memory_bytes <= self.parent_memory_bytes and
            self.child_storage_bytes <= self.parent_storage_bytes and
            self.child_storage_slots <= self.parent_storage_slots;
    }
};

pub const Config = struct {
    resources: ResourcePlan,
    keeper_material: []const u8 = default_keeper_material,
    user_material: []const u8 = default_user_material,
    device_material: []const u8 = default_device_material,
    allocator_material: []const u8 = default_allocator_material,
    parent_app_material: []const u8 = default_parent_app_material,
    child_app_material: []const u8 = default_child_app_material,
    child_scope_material: []const u8 = default_child_scope_material,
    state_body: []const u8 = default_state_body,
    required_parent_operations: identity.InstantiationOperation = .verify_and_sign,

    pub fn valid(self: Config) bool {
        return self.resources.valid() and
            bytes.nonzero(self.keeper_material) and
            bytes.nonzero(self.user_material) and
            bytes.nonzero(self.device_material) and
            bytes.nonzero(self.allocator_material) and
            bytes.nonzero(self.parent_app_material) and
            bytes.nonzero(self.child_app_material) and
            bytes.nonzero(self.child_scope_material) and
            bytes.nonzero(self.state_body);
    }
};

pub const Workspace = struct {
    memory: []u8,
    storage: []u8,
    slots: []store.Blob,
    object: []u8,

    pub fn validFor(self: Workspace, resources: ResourcePlan) bool {
        return self.memory.len >= resources.parent_memory_bytes and
            self.storage.len >= resources.parent_storage_bytes and
            self.slots.len >= resources.parent_storage_slots and
            self.object.len >= canonical_object_buffer_bytes;
    }
};

pub const Identities = struct {
    user: identity.Identity,
    device: identity.Identity,
    allocator: identity.Identity,
    root_app: identity.Identity,
    app: identity.Identity,

    pub fn valid(self: Identities) bool {
        return self.user.valid() and
            self.device.valid() and
            self.allocator.valid() and
            self.root_app.valid() and
            self.app.valid();
    }
};

pub const Node = struct {
    clock: clock.Clock,
    ids: Identities,

    pub fn valid(self: Node) bool {
        return self.clock.now.valid() and self.ids.valid();
    }
};

pub const Simulation = struct {
    node: Node,
    authorization: intent.Receipt,
    spawn_receipt: grant.SpawnReceipt,
    object_id: preimage.Hash,
    app_storage: store.Stats,

    pub fn valid(self: Simulation) bool {
        return self.node.valid() and
            self.authorization.valid() and
            self.spawn_receipt.valid() and
            bytes.nonzero(&self.object_id) and
            self.app_storage.valid();
    }
};

pub fn configForProfile(profile: Profile) Config {
    return .{ .resources = switch (profile) {
        .minimal => .{
            .parent_memory_bytes = profile_minimal_parent_memory,
            .parent_storage_bytes = profile_minimal_parent_storage,
            .parent_storage_slots = profile_minimal_parent_slots,
            .child_memory_bytes = profile_minimal_child_memory,
            .child_storage_bytes = profile_minimal_child_storage,
            .child_storage_slots = profile_minimal_child_slots,
        },
        .standard => .{
            .parent_memory_bytes = profile_standard_parent_memory,
            .parent_storage_bytes = profile_standard_parent_storage,
            .parent_storage_slots = profile_standard_parent_slots,
            .child_memory_bytes = profile_standard_child_memory,
            .child_storage_bytes = profile_standard_child_storage,
            .child_storage_slots = profile_standard_child_slots,
        },
        .ui => .{
            .parent_memory_bytes = profile_ui_parent_memory,
            .parent_storage_bytes = profile_ui_parent_storage,
            .parent_storage_slots = profile_ui_parent_slots,
            .child_memory_bytes = profile_ui_child_memory,
            .child_storage_bytes = profile_ui_child_storage,
            .child_storage_slots = profile_ui_child_slots,
        },
    } };
}

pub fn profileName(profile: Profile) []const u8 {
    return switch (profile) {
        .minimal => "minimal",
        .standard => "standard",
        .ui => "ui",
    };
}

pub fn instantiate(kind: identity.Kind, source_kind: identity.SourceKind, material: []const u8, epoch: clock.Stamp) Error!identity.Identity {
    return identity.Identity.instantiate(.{
        .kind = kind,
        .source_kind = source_kind,
        .material = material,
        .epoch = epoch,
    }) orelse error.BadConfiguration;
}

pub fn instantiateApp(parent: identity.Identity, material: []const u8, scope: []const u8, epoch: clock.Stamp, required_operations: identity.InstantiationOperation) Error!identity.Identity {
    const app_material = preimage.rawHash(material);
    const scope_hash = preimage.hash("edgerun:zig:v1:sdk-app-scope", scope);
    return identity.Identity.instantiateApp(.{
        .parent = parent,
        .app_material = &app_material,
        .scope_hash = &scope_hash,
        .epoch = epoch,
        .required_parent_operations = required_operations,
    }) orelse error.BadConfiguration;
}

pub fn setupNode(config: Config) Error!Node {
    if (!config.valid()) return error.BadConfiguration;
    const keeper = clock.KeeperId{ .bytes = preimage.rawHash(config.keeper_material) };
    var local_clock = clock.Clock.init(keeper, .{}) orelse return error.BadConfiguration;
    _ = local_clock.advanceDefault() orelse return error.BadConfiguration;
    const epoch = local_clock.now;
    const user = try instantiate(.user, .hash, &preimage.rawHash(config.user_material), epoch);
    const device = try instantiate(.device, .hash, &preimage.rawHash(config.device_material), epoch);
    const allocator = try instantiate(.app, .hash, &preimage.rawHash(config.allocator_material), epoch);
    const root_app = try instantiate(.app, .hash, &preimage.rawHash(config.parent_app_material), epoch);
    const child_app = try instantiateApp(root_app, config.child_app_material, config.child_scope_material, epoch, config.required_parent_operations);
    return .{
        .clock = local_clock,
        .ids = .{
            .user = user,
            .device = device,
            .allocator = allocator,
            .root_app = root_app,
            .app = child_app,
        },
    };
}

pub fn simulate(config: Config, workspace: Workspace) Error!Simulation {
    if (!config.valid() or !workspace.validFor(config.resources)) return error.BadConfiguration;
    const node = try setupNode(config);
    const resources = config.resources;
    var root_app = app_mod.App.init(
        node.ids.root_app,
        arena.BoundedArena.init(.{ .base = workspace.memory[0..resources.parent_memory_bytes] }),
        store.Store.init(.{ .base = workspace.storage[0..resources.parent_storage_bytes] }, workspace.slots[0..resources.parent_storage_slots]),
    );
    const request = intent.requestId("edgerun-sdk spawn app") orelse return error.BadConfiguration;
    const authorization = intent.admit(
        node.ids.user,
        node.ids.device,
        node.ids.allocator,
        node.ids.app,
        .spawn_app,
        .delegates_resources,
        node.clock.now,
        request,
    ) orelse return error.BadConfiguration;
    const spawned = root_app.spawn(
        node.ids.allocator,
        node.ids.app,
        node.clock.now,
        authorization,
        resources.child_memory_bytes,
        resources.child_storage_bytes,
        resources.child_storage_slots,
    ) catch |err| return switch (err) {
        error.NoMemory => error.NoMemory,
        error.NoStorage => error.NoStorage,
        error.Unauthorized => error.Unauthorized,
    };
    var child_app = spawned.app;
    const canonical = writeAppObject(node.ids.app, node.clock.now, config.state_body, workspace.object[0..canonical_object_buffer_bytes]) catch |err| return switch (err) {
        error.BadArgument => error.BadConfiguration,
        error.Corrupt => error.Corrupt,
        error.NoSpace => error.NoSpace,
        error.Unsupported => error.BadConfiguration,
    };
    const object_id = child_app.storage.putObject(node.ids.app.id, canonical) orelse return error.NoStorage;
    const view = child_app.storage.getObject(node.ids.app.id, object_id) orelse return error.Corrupt;
    if (!bytes.eql(&view.id(), &object_id)) return error.Corrupt;
    return .{
        .node = node,
        .authorization = authorization,
        .spawn_receipt = spawned.receipt,
        .object_id = object_id,
        .app_storage = child_app.storage.stats(),
    };
}

fn writeAppObject(owner: identity.Identity, epoch: clock.Stamp, body: []const u8, out: []u8) object.Error![]u8 {
    const object_owner = object.Owner{
        .kind = .app,
        .node_id = owner.id.bytes,
    };
    return try (object.NodeWriter{ .out = out }).bytesNodeOwned(appObjectRequirements(), epoch, &.{object_owner}, &.{}, body);
}

fn appObjectRequirements() object.Requirements {
    return .{
        .durability = .durable,
        .confidentiality = .app_private,
        .portability = .machine_bound,
        .integrity = .signed,
        .lifetime = .retained,
        .visibility = .app_namespace,
        .access = .explicit_io,
    };
}

test "sdk simulation wires clock identity app object and store" {
    var memory: [max_parent_memory_bytes]u8 = undefined;
    var storage_bytes: [max_parent_storage_bytes]u8 = undefined;
    var slots: [max_parent_slots]store.Blob = undefined;
    var object_bytes: [canonical_object_buffer_bytes]u8 = undefined;
    const result = try simulate(configForProfile(.minimal), .{
        .memory = &memory,
        .storage = &storage_bytes,
        .slots = &slots,
        .object = &object_bytes,
    });

    try std.testing.expect(result.valid());
    try std.testing.expectEqual(identity.Kind.delegated, result.node.ids.app.kind);
    try std.testing.expect(result.authorization.permitsAt(result.node.clock.now, result.node.ids.allocator.id, result.node.ids.app.id, .spawn_app, .delegates_resources));
    try std.testing.expectEqual(@as(usize, 1), result.app_storage.slot_count);
}

test "sdk simulation matrix covers profiles operations materials and body sizes" {
    const bodies = [_][]const u8{
        "s",
        default_state_body,
        "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
    };
    const material_prefixes = [_][]const u8{
        "alpha",
        "beta",
        "gamma",
    };
    var memory: [max_parent_memory_bytes]u8 = undefined;
    var storage_bytes: [max_parent_storage_bytes]u8 = undefined;
    var slots: [max_parent_slots]store.Blob = undefined;
    var object_bytes: [canonical_object_buffer_bytes]u8 = undefined;

    for (profiles) |profile| {
        for (operation_matrix) |operation| {
            for (bodies) |body| {
                for (material_prefixes, 0..) |prefix, index| {
                    var config = configForProfile(profile);
                    config.required_parent_operations = operation;
                    config.keeper_material = prefix;
                    config.user_material = matrixMaterial(.user, index);
                    config.device_material = matrixMaterial(.device, index);
                    config.allocator_material = matrixMaterial(.allocator, index);
                    config.parent_app_material = matrixMaterial(.parent, index);
                    config.child_app_material = matrixMaterial(.child, index);
                    config.child_scope_material = matrixMaterial(.scope, index);
                    config.state_body = body;
                    const result = try simulate(config, .{
                        .memory = &memory,
                        .storage = &storage_bytes,
                        .slots = &slots,
                        .object = &object_bytes,
                    });
                    try std.testing.expect(result.valid());
                    try std.testing.expectEqual(identity.Kind.delegated, result.node.ids.app.kind);
                    try std.testing.expectEqual(@as(usize, 1), result.app_storage.slot_count);
                }
            }
        }
    }
}

const MatrixMaterialKind = enum {
    user,
    device,
    allocator,
    parent,
    child,
    scope,
};

fn matrixMaterial(kind: MatrixMaterialKind, index: usize) []const u8 {
    return switch (kind) {
        .user => switch (index) {
            0 => "matrix user alpha",
            1 => "matrix user beta",
            else => "matrix user gamma",
        },
        .device => switch (index) {
            0 => "matrix device alpha",
            1 => "matrix device beta",
            else => "matrix device gamma",
        },
        .allocator => switch (index) {
            0 => "matrix allocator alpha",
            1 => "matrix allocator beta",
            else => "matrix allocator gamma",
        },
        .parent => switch (index) {
            0 => "matrix parent alpha",
            1 => "matrix parent beta",
            else => "matrix parent gamma",
        },
        .child => switch (index) {
            0 => "matrix child alpha",
            1 => "matrix child beta",
            else => "matrix child gamma",
        },
        .scope => switch (index) {
            0 => "matrix scope alpha",
            1 => "matrix scope beta",
            else => "matrix scope gamma",
        },
    };
}

test "sdk rejects impossible child resource plan" {
    var config = configForProfile(.minimal);
    config.resources.child_storage_slots = config.resources.parent_storage_slots + 1;
    var memory: [max_parent_memory_bytes]u8 = undefined;
    var storage_bytes: [max_parent_storage_bytes]u8 = undefined;
    var slots: [max_parent_slots]store.Blob = undefined;
    var object_bytes: [canonical_object_buffer_bytes]u8 = undefined;

    try std.testing.expectError(error.BadConfiguration, simulate(config, .{
        .memory = &memory,
        .storage = &storage_bytes,
        .slots = &slots,
        .object = &object_bytes,
    }));
}

test "sdk rejects empty identity material and undersized workspace" {
    var config = configForProfile(.minimal);
    config.user_material = "";
    var memory: [max_parent_memory_bytes]u8 = undefined;
    var storage_bytes: [max_parent_storage_bytes]u8 = undefined;
    var slots: [max_parent_slots]store.Blob = undefined;
    var object_bytes: [canonical_object_buffer_bytes]u8 = undefined;

    try std.testing.expectError(error.BadConfiguration, simulate(config, .{
        .memory = &memory,
        .storage = &storage_bytes,
        .slots = &slots,
        .object = &object_bytes,
    }));

    config = configForProfile(.minimal);
    try std.testing.expectError(error.BadConfiguration, simulate(config, .{
        .memory = memory[0 .. profile_minimal_parent_memory - 1],
        .storage = &storage_bytes,
        .slots = &slots,
        .object = &object_bytes,
    }));
}

test "sdk reports object buffer exhaustion at canonical object boundary" {
    var memory: [max_parent_memory_bytes]u8 = undefined;
    var storage_bytes: [max_parent_storage_bytes]u8 = undefined;
    var slots: [max_parent_slots]store.Blob = undefined;
    var object_bytes: [canonical_object_buffer_bytes]u8 = undefined;
    var oversized_body: [max_state_body_bytes + 1]u8 = [_]u8{'x'} ** (max_state_body_bytes + 1);
    var config = configForProfile(.minimal);
    config.state_body = &oversized_body;

    try std.testing.expectError(error.NoSpace, simulate(config, .{
        .memory = &memory,
        .storage = &storage_bytes,
        .slots = &slots,
        .object = &object_bytes,
    }));
}
