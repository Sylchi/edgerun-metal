const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const interaction = @import("../../ui_interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const tokens = @import("../../ui_tokens.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

pub const Pagination = struct {
    id: u32,
    page: u16 = 0,

    pub fn node(self: Pagination) ui.Node {
        return ui.paginationNode(self.id, self.page);
    }

    pub fn render(self: Pagination, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const page = selectedPage(self.page);
        for (0..pagination_item_count) |index| {
            const item = itemBounds(bounds, index);
            const active = index == page + 1;
            const label = itemLabel(index);
            try scene.pushRect(item, if (active) options.style.panel else ui.Color.clear, .fill, control_radius, 0.0);
            try scene.pushRect(item, if (active) options.style.border else ui.Color.clear, .border, control_radius, 0.0);
            if (contentInset(item, pagination_text_padding)) |inner| {
                try scene.pushAlignedText(inner.withHeightCentered(control_label_height), label, if (active) options.style.text else options.style.muted, .center);
            }
        }
    }

    pub fn collectInteractions(self: Pagination, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        for (0..pagination_item_count) |index| {
            try collector.addHit(itemBounds(bounds, index), .button, self.id + @as(u32, @intCast(index)));
        }
    }

    pub fn measure(self: Pagination, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureFixed(preferred_pagination, constraints);
    }

    pub fn toObject(self: Pagination, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.refObject(.pagination, encodedId(self.id, self.page), .{}, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Pagination, writer: *component_codec.Writer, index: usize) bool {
        return writer.record(index, .pagination, encodedId(self.id, self.page), .{}, .{});
    }

    pub fn fromView(view: object.View) Error!Pagination {
        return switch (try component_codec.singleNode(view)) {
            .pagination => |pagination| .{ .id = pagination.id, .page = selectedPage(pagination.page) },
            else => error.UnsupportedComponent,
        };
    }
};

fn selectedPage(page: u16) u16 {
    return @min(page, 2);
}

fn encodedId(id: u32, page: u16) u32 {
    return id * pagination_id_stride + selectedPage(page);
}

const pagination_id_stride: u32 = 3;
const pagination_item_count: usize = 5;

fn itemBounds(bounds: ui.Rect, index: usize) ui.Rect {
    return ui.Rect.init(bounds.x + @as(f32, @floatFromInt(index)) * (pagination_item_w + pagination_gap), bounds.y, pagination_item_w, @min(bounds.h, pagination_item_h));
}

fn itemLabel(index: usize) []const u8 {
    return switch (index) {
        0 => "<",
        1 => "1",
        2 => "2",
        3 => "3",
        else => ">",
    };
}

fn contentInset(bounds: ui.Rect, padding: f32) ?ui.Rect {
    const clamped = @min(@max(padding, 0.0), @min(bounds.w, bounds.h) * 0.5);
    const out = bounds.insetUniform(clamped);
    return if (out.valid()) out else null;
}

fn measureFixed(preferred: ui.Size, constraints: layout.Constraints) layout.Measurement {
    const resolved_preferred = constrainPreferredSize(preferred, constraints);
    return layout.Measurement.flexible(
        .{ .w = @min(preferred.w, resolved_preferred.w), .h = @min(preferred.h, resolved_preferred.h) },
        resolved_preferred,
        .{ .w = measure_max_width, .h = preferred.h },
    ).applyExact(constraints);
}

fn constrainPreferredSize(preferred: ui.Size, constraints: layout.Constraints) ui.Size {
    return .{
        .w = constraints.width.limit(preferred.w),
        .h = constraints.height.limit(preferred.h),
    };
}

const measure_max_width: f32 = 4096.0;
const control_radius: f32 = tokens.Component.control_radius;
const control_label_height: f32 = tokens.Component.control_label_height;
const pagination_item_w: f32 = 36.0;
const pagination_item_h: f32 = 36.0;
const pagination_gap: f32 = 4.0;
const pagination_text_padding: f32 = 2.0;
pub const preferred_pagination = ui.Size{ .w = 240.0, .h = 36.0 };

test "pagination component serializes to canonical object and deserializes" {
    const pagination = Pagination{ .id = 120, .page = 2 };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = pagination.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Pagination.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(pagination.id, decoded.id);
    try std.testing.expectEqual(@as(u16, 2), decoded.page);
}

test "pagination component renders pages and hit regions" {
    const pagination = Pagination{ .id = 120, .page = 1 };
    var commands: [24]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [5]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try pagination.render(&scene, ui.Rect.init(0, 0, 240, 36), .{});
    try pagination.collectInteractions(&collector, ui.Rect.init(0, 0, 240, 36));

    try std.testing.expect(component_test.hasText(scene.written(), "1"));
    try std.testing.expect(component_test.hasText(scene.written(), "2"));
    try std.testing.expect(component_test.hasText(scene.written(), "3"));
    try std.testing.expectEqual(@as(usize, 5), collector.written().len);
    try std.testing.expectEqual(@as(u32, 124), collector.written()[4].id);
}
