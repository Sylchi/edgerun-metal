const clock = @import("../../clock.zig");
const common = @import("../component_common.zig");
const text_component = @import("Text.zig");
const interaction = @import("../interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../core.zig");
const layout = @import("../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

pub const Dialog = struct {
    id: u32,
    title: []const u8,
    detail: []const u8,
    flags: common.ComponentFlags = .{},

    const serialization = component_codec.TwoStringComponent(Dialog, "dialog", "title", "detail");

    pub fn node(self: Dialog) ui.Node {
        return ui.dialogNode(self.id, self.title, self.detail);
    }

    pub fn accessibility(self: Dialog) common.Accessibility {
        return .{ .role = .dialog, .label = self.title, .control_id = self.id };
    }

    pub fn render(self: Dialog, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        try primitives.renderSidePanelTitleDetail(scene, bounds, self.id, options, dialog_layout, options.style.accent, options.style.border, dialog_trigger_padding, dialog_open_label, options.style.bg, dialog_panel, self.title, self.detail, options.style.text);
    }

    pub fn collectInteractions(self: Dialog, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try primitives.collectSidePanelLayoutHits(collector, bounds, dialog_layout, self.id);
    }

    pub fn measure(self: Dialog, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        return primitives.measureSidePanelTitleDetail(dialog_open_label, self.title, self.detail, constraints, dialog_layout, dialog_trigger_padding, dialog_panel);
    }
    pub const toObject = serialization.toObject;
    pub const writeRecord = serialization.writeRecord;
    pub const fromView = serialization.fromView;

    pub fn fromNode(dialog: @FieldType(ui.Node, "dialog")) Error!Dialog {
        return .{ .id = dialog.id, .title = dialog.title, .detail = dialog.detail };
    }
};

const dialog_layout = primitives.SidePanelLayout{ .trigger_y = 6.0, .trigger_w = 66.0, .trigger_h = 30.0, .gap = 12.0 };
const dialog_panel = primitives.TitleDetailPanel{ .radius = 10.0, .padding = 10.0, .title_y = 6.0, .title_h = 14.0, .detail_y = 22.0, .detail_h = 12.0 };
const dialog_trigger_padding: f32 = 8.0;
const dialog_open_label = "Open";

test "dialog component renders trigger content and hit regions" {
    const dialog = Dialog{ .id = 996, .title = "Edit profile", .detail = "Modal content" };
    var h = component_test.InteractiveHarness(24, 2){};
    h.init();

    try h.render(dialog, ui.Rect.init(0, 0, 240, 52), .{ .overlay = .{ .open_ids = &.{dialog.id} } });
    try dialog.collectInteractions(&h.collector, ui.Rect.init(0, 0, 240, 52));

    try h.expectText("Edit profile");
    try h.expectText("Modal content");
    try h.expectHitCount(2);
    try h.expectHitId(1, 997);
}

test "dialog measurement follows title and detail text" {
    const short = Dialog{ .id = 996, .title = "Edit", .detail = "Body" };
    const long = Dialog{ .id = 996, .title = "Edit runtime authority", .detail = "Modal content with receipts" };

    try component_test.expect(long.measure(.{}, .{}).preferred.w > short.measure(.{}, .{}).preferred.w);
}
