const clock = @import("../../clock.zig");
const interaction = @import("../../ui_interaction.zig");
const layouts = @import("../../layouts.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const common = @import("../../ui_component_common.zig");
const component_codec = @import("Codec.zig");
const component_io = @import("ComponentIO.zig");
const primitives = @import("Primitives.zig");
const registry = @import("ComponentRegistry.zig");

pub const Error = common.Error;
pub const RenderOptions = common.RenderOptions;
pub const Accessibility = common.Accessibility;
pub const AccessibilityTree = common.AccessibilityTree;

pub const Component = union(enum) {
    text: registry.Payload("text"),
    accordion: registry.Payload("accordion"),
    alert: registry.Payload("alert"),
    alert_dialog: registry.Payload("alert_dialog"),
    aspect_ratio: registry.Payload("aspect_ratio"),
    calendar: registry.Payload("calendar"),
    carousel: registry.Payload("carousel"),
    chart: registry.Payload("chart"),
    combobox: registry.Payload("combobox"),
    card: registry.Payload("card"),
    empty: registry.Payload("empty"),
    badge: registry.Payload("badge"),
    avatar: registry.Payload("avatar"),
    kbd: registry.Payload("kbd"),
    label: registry.Payload("label"),
    separator: registry.Payload("separator"),
    scroll_area: registry.Payload("scroll_area"),
    skeleton: registry.Payload("skeleton"),
    spinner: registry.Payload("spinner"),
    breadcrumb: registry.Payload("breadcrumb"),
    menubar: registry.Payload("menubar"),
    navigation_menu: registry.Payload("navigation_menu"),
    command: registry.Payload("command"),
    context_menu: registry.Payload("context_menu"),
    dialog: registry.Payload("dialog"),
    direction: registry.Payload("direction"),
    drawer: registry.Payload("drawer"),
    dropdown_menu: registry.Payload("dropdown_menu"),
    field: registry.Payload("field"),
    hover_card: registry.Payload("hover_card"),
    input_otp: registry.Payload("input_otp"),
    icon: registry.Payload("icon"),
    button: registry.Payload("button"),
    icon_button: registry.Payload("icon_button"),
    button_group: registry.Payload("button_group"),
    toggle_group: registry.Payload("toggle_group"),
    toggle: registry.Payload("toggle"),
    input: registry.Payload("input"),
    input_group: registry.Payload("input_group"),
    textarea: registry.Payload("textarea"),
    select: registry.Payload("select"),
    checkbox: registry.Payload("checkbox"),
    radio_group: registry.Payload("radio_group"),
    switch_control: registry.Payload("switch_control"),
    pagination: registry.Payload("pagination"),
    popover: registry.Payload("popover"),
    resizable: registry.Payload("resizable"),
    sheet: registry.Payload("sheet"),
    sidebar: registry.Payload("sidebar"),
    progress: registry.Payload("progress"),
    slider: registry.Payload("slider"),
    tabs: registry.Payload("tabs"),
    table: registry.Payload("table"),
    tooltip: registry.Payload("tooltip"),
    toast: registry.Payload("toast"),
    row_item: registry.Payload("row_item"),

    pub fn node(self: Component) ui.Node {
        return switch (self) {
            inline else => |component| component.node(),
        };
    }

    pub fn render(self: Component, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const resolved_options = options.withControlId(self.controlId());
        switch (self) {
            inline else => |component| try component.render(scene, bounds, resolved_options),
        }
        try primitives.renderControlStateOverlay(scene, bounds, resolved_options, primitives.control_radius);
    }

    pub fn collectInteractions(self: Component, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        switch (self) {
            inline else => |component| {
                if (comptime @hasDecl(@TypeOf(component), "collectInteractions")) {
                    try component.collectInteractions(collector, bounds);
                }
            },
        }
    }

    pub fn measure(self: Component, constraints: layouts.types.Constraints, options: RenderOptions) layouts.types.Measurement {
        return switch (self) {
            inline else => |component| component.measure(constraints, options),
        };
    }

    pub fn accessibility(self: Component) Accessibility {
        return switch (self) {
            inline else => |component| if (comptime @hasDecl(@TypeOf(component), "accessibility")) component.accessibility() else .{ .role = .generic },
        };
    }

    pub fn collectAccessibility(self: Component, tree: *AccessibilityTree, bounds: ui.Rect, options: RenderOptions) common.AccessibilityError!void {
        _ = options;
        const metadata = self.accessibility();
        if (metadata.role == .generic and metadata.label.len == 0 and metadata.control_id == null) return;
        try tree.append(.{ .metadata = metadata, .bounds = bounds });
    }

    fn controlId(self: Component) ?u32 {
        return self.accessibility().control_id;
    }

    pub fn toObject(self: Component, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_io.writeObject(Component, self, ui_out, object_out, epoch);
    }

    pub fn fromObject(canonical: []const u8) Error!Component {
        const view = object.View.decode(canonical) catch return error.Corrupt;
        return fromView(view);
    }

    pub fn fromView(view: object.View) Error!Component {
        return fromNode(try component_codec.singleNode(view));
    }

    pub fn fromNode(node_value: ui.Node) Error!Component {
        return switch (node_value) {
            inline else => |payload, tag| {
                if (comptime @hasField(Component, @tagName(tag))) {
                    return @unionInit(Component, @tagName(tag), try componentFromNode(@FieldType(Component, @tagName(tag)), payload));
                }
                return error.UnsupportedComponent;
            },
        };
    }
};

fn componentFromNode(comptime ComponentPayload: type, node_payload: anytype) Error!ComponentPayload {
    if (comptime !@hasDecl(ComponentPayload, "fromNode")) @compileError(@typeName(ComponentPayload) ++ " must own fromNode");
    return ComponentPayload.fromNode(node_payload);
}

comptime {
    registry.assertMatches(Component);
}
