const std = @import("std");
const bounded = @import("bounded.zig");
const bytes = @import("bytes.zig");
const clock = @import("clock.zig");
const identity = @import("identity.zig");
const intent = @import("intent.zig");
const preimage = @import("preimage.zig");

pub const id_size = preimage.hash_size;
pub const max_steps = 8;
pub const Steps = bounded.FixedList(Step, max_steps);

pub const StepKind = enum(u16) {
    user_admitted = 1,
    delegated_to_device = 2,
    delegated_to_allocator = 3,
    delegated_to_ui = 4,
    delegated_to_app = 5,
    delegated_to_storage = 6,
};

pub const Step = struct {
    kind: StepKind,
    from: identity.Id,
    to: identity.Id,
    receipt: preimage.Hash,
    epoch: clock.Stamp,

    pub fn valid(self: Step) bool {
        return self.from.valid() and self.to.valid() and bytes.nonzero(&self.receipt) and self.epoch.valid();
    }
};

pub const Chain = struct {
    root: identity.Id,
    terminal: identity.Id,
    steps: Steps = .{},

    pub fn init(root: identity.Identity) Chain {
        return .{
            .root = root.id,
            .terminal = root.id,
        };
    }

    pub fn append(self: *Chain, step: Step) bool {
        if (self.steps.full() or !step.valid()) return false;
        if (!step.from.eql(self.terminal)) return false;

        if (!self.steps.append(step)) return false;
        self.terminal = step.to;
        return true;
    }

    pub fn appendIntent(self: *Chain, to: identity.Identity, kind: StepKind, receipt: intent.Receipt) bool {
        const receipt_id = receipt.id() orelse return false;
        return self.append(.{
            .kind = kind,
            .from = self.terminal,
            .to = to.id,
            .receipt = receipt_id,
            .epoch = receipt.intent.epoch,
        });
    }

    pub fn valid(self: Chain) bool {
        if (!self.root.valid() or !self.terminal.valid()) return false;
        var current = self.root;
        for (self.steps.slice()) |step| {
            if (!step.valid() or !step.from.eql(current)) return false;
            current = step.to;
        }
        return current.eql(self.terminal);
    }

    pub fn id(self: Chain) ?preimage.Hash {
        if (!self.valid()) return null;

        var builder = preimage.Builder.init("edgerun:zig:v1:authority-chain");
        var header: [68]u8 = undefined;
        var writer = preimage.Writer.init(&header);
        if (!writer.id(self.root) or
            !writer.id(self.terminal) or
            !writer.writeU32(@intCast(self.steps.len)))
        {
            return null;
        }
        builder.bytes(writer.written());

        var raw_step: [164]u8 = undefined;
        for (self.steps.slice()) |step| {
            writer = preimage.Writer.init(&raw_step);
            if (!writer.writeU16(@intFromEnum(step.kind)) or
                !writer.id(step.from) or
                !writer.id(step.to) or
                !writer.hash(step.receipt) or
                !writer.epoch(step.epoch))
            {
                return null;
            }
            builder.bytes(writer.written());
        }

        return builder.final();
    }
};

test "authority chain is ordered and deterministic" {
    const keeper = clock.KeeperId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const user = identity.Identity.init(.user, identity.Source.prepare(.hash, &preimage.rawHash("user")).?, epoch).?;
    const device = identity.Identity.init(.device, identity.Source.prepare(.hash, &preimage.rawHash("device")).?, epoch).?;
    const allocator = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("allocator")).?, epoch).?;
    const request = intent.requestId("delegate allocator").?;
    const receipt = intent.admit(user, device, user, allocator, .grant_resource, .delegates_resources, epoch, request).?;

    var chain = Chain.init(user);
    try std.testing.expect(chain.appendIntent(allocator, .delegated_to_allocator, receipt));
    try std.testing.expect(chain.valid());
    try std.testing.expect(bytes.nonzero(&chain.id().?));
}
