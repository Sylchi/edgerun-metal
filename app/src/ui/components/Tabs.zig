const std = @import("er_std");
const clock = @import("../../clock.zig");
const common = @import("../component_common.zig");
const interaction = @import("../interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../core.zig");
const text_component = @import("Text.zig");
const layout = @import("../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const primitives = @import("Primitives.zig");
const list_layout = @import("ListLayout.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

const renderControlText = primitives.renderControlText;

pub const Tabs = struct {
    id: u32,
    first: []const u8,
    second: []const u8,
    active: ?u16 = null,
    default_active: u16 = 0,
    flags: common.ComponentFlags = .{},

    pub fn node(self: Tabs) ui.Node {
        return ui.tabsNode(self.id, self.first, self.second, self.activeIndexResolved());
    }

    pub fn accessibility(self: Tabs) common.Accessibility {
        return .{ .role = .tab, .label = self.first, .control_id = self.id };
    }

    pub fn render(self: Tabs, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const active = self.activeIndexResolved();
        const list = listBounds(bounds);
        try scene.pushRect(list, options.style.row, .fill, tabs_list_radius, 0.0);
        try renderTrigger(scene, triggerBounds(list, 0), self.first, active == 0, options);
        try renderTrigger(scene, triggerBounds(list, 1), self.second, active == 1, options);
        const panel = panelBounds(bounds, list);
        try scene.pushRect(panel, options.style.panel, .fill, primitives.control_radius, 0.0);
        try scene.pushRect(panel, options.style.border, .border, primitives.control_radius, 0.0);
        const label = if (active == 1) self.second else self.first;
        if (primitives.contentInset(panel, tabs_panel_padding)) |content| {
            const text_h = @min(content.h, primitives.measuredTextHeight(label, content.w, primitives.control_label_height, tabs_panel_max_lines));
            try text_component.Text.renderWrapped(scene, content.withHeightCentered(text_h), label, options.style.muted, primitives.textWrap(label, primitives.control_label_height, tabs_panel_max_lines));
        }
    }

    pub fn collectInteractions(self: Tabs, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try list_layout.collectPaddedEqualSegmentHits(collector, listBounds(bounds), self.id, tabs_item_count, tabs_list_padding);
    }

    pub fn measure(self: Tabs, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        const labels = [_][]const u8{ self.first, self.second };
        const list = list_layout.measureSegments(&labels, constraints, .{
            .item_count = tabs_item_count,
            .padding = tabs_trigger_padding + tabs_list_padding,
        });
        const panel_label = if (self.activeIndexResolved() == 1) self.second else self.first;
        const panel = text_component.Text.measureValue(
            panel_label,
            constraints.inner(.{ .left = tabs_panel_padding, .right = tabs_panel_padding, .top = tabs_panel_padding, .bottom = tabs_panel_padding }),
            primitives.textMetrics(panel_label, primitives.control_label_height, tabs_panel_max_lines),
        ).withInsets(.{ .left = tabs_panel_padding, .right = tabs_panel_padding, .top = tabs_panel_padding, .bottom = tabs_panel_padding });
        const preferred = primitives.constrainPreferredSize(.{
            .w = @max(list.preferred.w, panel.preferred.w),
            .h = list.preferred.h + tabs_gap + panel.preferred.h,
        }, constraints);
        return layout.Measurement.flexible(
            .{
                .w = @max(list.min.w, panel.min.w),
                .h = list.min.h + tabs_gap + panel.min.h,
            },
            preferred,
            .{ .w = primitives.maxMeasuredWidth(constraints, preferred.w), .h = @max(preferred.h, list.max.h + tabs_gap + panel.max.h) },
        ).applyExact(constraints);
    }

    pub fn toObject(self: Tabs, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.singleObjectFromRecord(@TypeOf(self), self, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Tabs, writer: *component_codec.Writer, index: usize) bool {
        const first_ref = writer.string(self.first) orelse return false;
        const second_ref = writer.string(self.second) orelse return false;
        return writer.record(index, .tabs, list_layout.encodedIndexedId(self.id, self.activeIndexResolved(), tabs_item_count), first_ref, second_ref);
    }

    pub fn fromView(view: object.View) Error!Tabs {
        return component_codec.decodeFromView(Tabs, .tabs, view);
    }

    pub fn fromNode(tabs: @FieldType(ui.Node, "tabs")) Error!Tabs {
        return .{ .id = tabs.id, .first = tabs.first, .second = tabs.second, .active = list_layout.clampedIndex(tabs.active, tabs_item_count) };
    }

    fn activeIndexResolved(self: Tabs) u16 {
        return list_layout.resolveIndex(self.active, self.default_active, tabs_item_count);
    }
};

fn listBounds(bounds: ui.Rect) ui.Rect {
    const height = @min(bounds.h, primitives.control_label_height + (tabs_trigger_padding + tabs_list_padding) * 2.0);
    return ui.Rect.init(bounds.x, bounds.y, bounds.w, height);
}

fn panelBounds(bounds: ui.Rect, list: ui.Rect) ui.Rect {
    const y = list.y + list.h + tabs_gap;
    return ui.Rect.init(bounds.x, y, bounds.w, @max(primitives.min_extent, bounds.y + bounds.h - y));
}

fn triggerBounds(list: ui.Rect, index: usize) ui.Rect {
    return list_layout.paddedEqualSegmentBounds(list, index, tabs_item_count, tabs_list_padding);
}

fn renderTrigger(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, active: bool, options: RenderOptions) ui.RenderError!void {
    if (active) {
        try scene.pushRect(bounds, options.style.panel, .fill, primitives.control_radius, 0.0);
        try scene.pushRect(bounds, options.style.border, .border, primitives.control_radius, 0.0);
    }
    try renderControlText(scene, bounds, tabs_trigger_padding, primitives.control_label_height, label, if (active) options.style.text else options.style.muted, .center);
}

const tabs_item_count: u16 = 2;
const tabs_list_padding: f32 = 3.0;
const tabs_list_radius: f32 = 8.0;
const tabs_gap: f32 = 8.0;
const tabs_panel_padding: f32 = 10.0;
const tabs_trigger_padding: f32 = 8.0;
const tabs_panel_max_lines: usize = 2;

test "tabs component renders active trigger and trigger hits" {
    const tabs = Tabs{ .id = 80, .first = "Account", .second = "Password", .active = 0 };
    var commands: [20]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [2]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try tabs.render(&scene, ui.Rect.init(0, 0, 220, 84), .{});
    try tabs.collectInteractions(&collector, ui.Rect.init(0, 0, 220, 84));

    try std.testing.expect(component_test.hasText(scene.written(), "Account"));
    try std.testing.expect(component_test.hasText(scene.written(), "Password"));
    try std.testing.expectEqual(@as(usize, 2), collector.written().len);
    try std.testing.expectEqual(@as(u32, 81), collector.written()[1].id);
}

test "tabs measurement follows tab and panel labels" {
    const short = Tabs{ .id = 80, .first = "A", .second = "B", .active = 0 };
    const long = Tabs{ .id = 80, .first = "Runtime", .second = "Authority Model", .active = 1 };

    const short_measured = short.measure(.{}, .{});
    const long_measured = long.measure(.{}, .{});

    try std.testing.expect(long_measured.preferred.w > short_measured.preferred.w);
    try std.testing.expect(long_measured.preferred.h >= short_measured.preferred.h);
}
