pub const data_chunk = @import("content/data_chunk.zig");
pub const data_definition = @import("content/data_definition.zig");
pub const data_object = @import("content/data_object.zig");
pub const metadata_object = @import("content/metadata_object.zig");
pub const kernel = @import("content/kernel.zig");
pub const kernel_authority = @import("content/kernel_authority.zig");
pub const kernel_runtime = @import("content/kernel_runtime.zig");
pub const registry_app = @import("content/registry_app.zig");
pub const resource_contract = @import("content/resource_contract.zig");
pub const resource_inventory = @import("content/resource_inventory.zig");
pub const tpm_verifier = @import("content/tpm_verifier.zig");

test {
    _ = data_chunk;
    _ = data_definition;
    _ = data_object;
    _ = metadata_object;
    _ = kernel;
    _ = kernel_authority;
    _ = kernel_runtime;
    _ = registry_app;
    _ = resource_contract;
    _ = resource_inventory;
    _ = tpm_verifier;
}
