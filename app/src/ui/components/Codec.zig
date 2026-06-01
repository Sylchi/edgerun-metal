const common = @import("../component_common.zig");
const clock = @import("../../clock.zig");
const codec = @import("../codec.zig");
const object = @import("../../object.zig");
const ui = @import("../core.zig");

const Error = common.Error;
pub const Writer = codec.Writer;

pub fn requirements() object.Requirements {
    return .{
        .durability = .memory,
        .confidentiality = .app_private,
        .portability = .app_portable,
        .integrity = .hash_only,
        .lifetime = .session,
        .visibility = .app_namespace,
        .access = .hot_memory_allowed,
    };
}

pub fn validateView(view: object.View) Error!void {
    if (view.header.kind != .bytes) return error.Corrupt;
    if (!view.header.requirements.eql(requirements())) return error.Corrupt;
}

pub fn validateTreeView(view: object.View) Error!void {
    if (view.header.kind != .tree) return error.Corrupt;
    if (!view.header.requirements.eql(requirements())) return error.Corrupt;
}

pub fn singleNode(view: object.View) Error!ui.Node {
    try validateView(view);
    var nodes: [1]ui.Node = undefined;
    const root = codec.decodeView(view, &nodes) catch return error.Corrupt;
    return switch (root) {
        .stack => |stack| {
            if (stack.children.len != 1) return error.Corrupt;
            return stack.children[0];
        },
        else => error.UnsupportedComponent,
    };
}

pub fn nodeView(view: object.View, comptime tag: @typeInfo(ui.Node).@"union".tag_type.?) Error!@FieldType(ui.Node, @tagName(tag)) {
    const node = try singleNode(view);
    return switch (node) {
        tag => |payload| payload,
        else => error.UnsupportedComponent,
    };
}

pub fn decodeFromView(comptime ComponentType: type, comptime tag: @typeInfo(ui.Node).@"union".tag_type.?, view: object.View) Error!ComponentType {
    return ComponentType.fromNode(try nodeView(view, tag));
}

pub fn emptyObject(kind: codec.RecordKind, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
    return recordObject(kind, 0, .{}, .{}, ui_out, object_out, epoch);
}

pub fn refObject(kind: codec.RecordKind, id: u32, value: codec.StringRef, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
    return recordObject(kind, id, .{}, value, ui_out, object_out, epoch);
}

pub fn oneStringObject(kind: codec.RecordKind, id: u32, value: []const u8, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
    var writer = singleWriter(ui_out) orelse return null;
    if (!oneStringRecord(&writer, 0, kind, id, value)) return null;
    return writer.objectNode(object_out, requirements(), epoch);
}

pub fn stringAndRefObject(kind: codec.RecordKind, id: u32, value: []const u8, b: codec.StringRef, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
    var writer = singleWriter(ui_out) orelse return null;
    if (!stringAndRefRecord(&writer, 0, kind, id, value, b)) return null;
    return writer.objectNode(object_out, requirements(), epoch);
}

pub fn twoStringObject(kind: codec.RecordKind, id: u32, first: []const u8, second: []const u8, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
    var writer = singleWriter(ui_out) orelse return null;
    if (!twoStringRecord(&writer, 0, kind, id, first, second)) return null;
    return writer.objectNode(object_out, requirements(), epoch);
}

pub fn emptyRecord(writer: *Writer, index: usize, kind: codec.RecordKind) bool {
    return writer.record(index, kind, 0, .{}, .{});
}

pub fn EmptyComponent(comptime ComponentType: type, comptime tag_name: []const u8) type {
    return struct {
        pub fn toObject(self: ComponentType, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
            _ = self;
            return emptyObject(@field(codec.RecordKind, tag_name), ui_out, object_out, epoch);
        }

        pub fn writeRecord(self: ComponentType, writer: *Writer, index: usize) bool {
            _ = self;
            return emptyRecord(writer, index, @field(codec.RecordKind, tag_name));
        }

        pub fn fromView(view: object.View) Error!ComponentType {
            return ComponentType.fromNode(try nodeView(view, @field(@typeInfo(ui.Node).@"union".tag_type.?, tag_name)));
        }
    };
}

pub fn refRecord(writer: *Writer, index: usize, kind: codec.RecordKind, id: u32, value: codec.StringRef) bool {
    return writer.record(index, kind, id, .{}, value);
}

pub fn oneStringRecord(writer: *Writer, index: usize, kind: codec.RecordKind, id: u32, value: []const u8) bool {
    const a = writer.string(value) orelse return false;
    return writer.record(index, kind, id, a, .{});
}

pub fn OneStringComponent(comptime ComponentType: type, comptime tag_name: []const u8, comptime value_field: []const u8) type {
    return struct {
        pub fn toObject(self: ComponentType, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
            return oneStringObject(@field(codec.RecordKind, tag_name), self.id, @field(self, value_field), ui_out, object_out, epoch);
        }

        pub fn writeRecord(self: ComponentType, writer: *Writer, index: usize) bool {
            return oneStringRecord(writer, index, @field(codec.RecordKind, tag_name), self.id, @field(self, value_field));
        }

        pub fn fromView(view: object.View) Error!ComponentType {
            return decodeFromView(ComponentType, @field(@typeInfo(ui.Node).@"union".tag_type.?, tag_name), view);
        }
    };
}

pub fn OneStringFixedIdComponent(comptime ComponentType: type, comptime tag_name: []const u8, comptime id: u32, comptime value_field: []const u8) type {
    return struct {
        pub fn toObject(self: ComponentType, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
            return oneStringObject(@field(codec.RecordKind, tag_name), id, @field(self, value_field), ui_out, object_out, epoch);
        }

        pub fn writeRecord(self: ComponentType, writer: *Writer, index: usize) bool {
            return oneStringRecord(writer, index, @field(codec.RecordKind, tag_name), id, @field(self, value_field));
        }

        pub fn fromView(view: object.View) Error!ComponentType {
            return decodeFromView(ComponentType, @field(@typeInfo(ui.Node).@"union".tag_type.?, tag_name), view);
        }
    };
}

pub fn stringAndRefRecord(writer: *Writer, index: usize, kind: codec.RecordKind, id: u32, value: []const u8, b: codec.StringRef) bool {
    const a = writer.string(value) orelse return false;
    return writer.record(index, kind, id, a, b);
}

pub fn twoStringRecord(writer: *Writer, index: usize, kind: codec.RecordKind, id: u32, first: []const u8, second: []const u8) bool {
    const a = writer.string(first) orelse return false;
    const b = writer.string(second) orelse return false;
    return writer.record(index, kind, id, a, b);
}

pub fn TwoStringComponent(comptime ComponentType: type, comptime tag_name: []const u8, comptime first_field: []const u8, comptime second_field: []const u8) type {
    return struct {
        pub fn toObject(self: ComponentType, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
            return twoStringObject(@field(codec.RecordKind, tag_name), self.id, @field(self, first_field), @field(self, second_field), ui_out, object_out, epoch);
        }

        pub fn writeRecord(self: ComponentType, writer: *Writer, index: usize) bool {
            return twoStringRecord(writer, index, @field(codec.RecordKind, tag_name), self.id, @field(self, first_field), @field(self, second_field));
        }

        pub fn fromView(view: object.View) Error!ComponentType {
            return decodeFromView(ComponentType, @field(@typeInfo(ui.Node).@"union".tag_type.?, tag_name), view);
        }
    };
}

pub fn boolRef(value: bool) codec.StringRef {
    return .{ .offset = if (value) 1 else 0, .len = 0 };
}

pub fn unitRef(value: f32) codec.StringRef {
    return .{ .offset = ui.encodeUnit(value), .len = 0 };
}

fn recordObject(kind: codec.RecordKind, id: u32, a: codec.StringRef, b: codec.StringRef, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
    var writer = singleWriter(ui_out) orelse return null;
    return recordObjectWithWriter(&writer, kind, id, a, b, object_out, epoch);
}

fn recordObjectWithWriter(writer: *Writer, kind: codec.RecordKind, id: u32, a: codec.StringRef, b: codec.StringRef, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
    if (!writer.record(0, kind, id, a, b)) return null;
    return writer.objectNode(object_out, requirements(), epoch);
}

pub fn singleWriter(ui_out: []u8) ?Writer {
    return codec.Writer.init(ui_out, 1, 1, .column, 0, 0);
}

pub fn writeObject(comptime Component: type, component: Component, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
    var writer = codec.Writer.init(ui_out, 1, 1, .column, 0, 0) orelse return null;
    if (!writeRecord(Component, &writer, 0, component)) return null;
    return writer.objectNode(object_out, requirements(), epoch);
}

pub fn singleObjectFromRecord(comptime T: type, value: T, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
    var writer = singleWriter(ui_out) orelse return null;
    if (!value.writeRecord(&writer, 0)) return null;
    return writer.objectNode(object_out, requirements(), epoch);
}

pub fn writeRecord(comptime Component: type, writer: *codec.Writer, index: usize, component: Component) bool {
    return switch (component) {
        inline else => |payload| payload.writeRecord(writer, index),
    };
}
