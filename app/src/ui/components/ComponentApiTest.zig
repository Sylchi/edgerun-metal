const std = @import("std");
const component = @import("Component.zig");
const ui_input = @import("../../input.zig");
const object = @import("../../object.zig");
const ui = @import("../core.zig");
const common = @import("../component_common.zig");
const component_codec = @import("Codec.zig");
const component_test = @import("TestSupport.zig");
const icon_pack = @import("../icon_pack.zig");
const card_component = @import("Card.zig");
const badge_component = @import("Badge.zig");
const ui_tokens = @import("../theme.zig");

const ActionToolbarProps = component.ActionToolbarProps;
const BadgeVariant = component.BadgeVariant;
const Component = component.Component;
const Icon = component.Icon;
const IconButtonSpec = component.IconButtonSpec;
const IconSlot = component.IconSlot;
const PanelListItem = component.PanelListItem;
const RenderOptions = component.RenderOptions;
const Segment = component.Segment;
const SemanticItem = component.SemanticItem;
const SurfaceVariant = component.SurfaceVariant;
const TimelineBlock = component.TimelineBlock;
const TimelineMark = component.TimelineMark;
const TimelineViewportAction = component.TimelineViewportAction;
const TimelineViewportControls = component.TimelineViewportControls;
const TimelineViewportLane = component.TimelineViewportLane;
const TimelineViewportMark = component.TimelineViewportMark;
const TimelineViewportState = component.TimelineViewportState;
const alert = component.alert;
const applyTimelineViewportAction = component.applyTimelineViewportAction;
const badge = component.badge;
const button = component.button;
const buttonIcon = component.buttonIcon;
const buttonText = component.buttonText;
const card = component.card;
const cardNode = component.cardNode;
const chart = component.chart;
const checkbox = component.checkbox;
const command = component.command;
const destructiveAlert = component.destructiveAlert;
const elevated = component.elevated;
const icon = component.icon;
const iconButtonNamed = component.iconButtonNamed;
const input = component.input;
const inputIcon = component.inputIcon;
const inputValue = component.inputValue;
const panel = component.panel;
const progress = component.progress;
const progressNode = component.progressNode;
const registrations = component.registrations;
const renderer = component.renderer;
const rowItem = component.rowItem;
const rowItemIcon = component.rowItemIcon;
const selectIcon = component.selectIcon;
const selectableCard = component.selectableCard;
const selectableElevated = component.selectableElevated;
const selectablePanel = component.selectablePanel;
const selectableSubtle = component.selectableSubtle;
const subtle = component.subtle;
const tabs = component.tabs;
const textarea = component.textarea;
const textareaValue = component.textareaValue;
const timelineViewportActionForHit = component.timelineViewportActionForHit;
const toast = component.toast;
const toggle = component.toggle;
const tooltip = component.tooltip;

test "component union is the component list source of truth" {
    const fields = @typeInfo(Component).@"union".fields;
    try std.testing.expectEqual(registrations.len, fields.len);
    inline for (registrations, 0..) |entry, index| {
        const field = fields[index];
        try std.testing.expectEqualStrings(entry.name, field.name);
        try std.testing.expect(field.type == entry.type);
        try std.testing.expect(comptime @hasDecl(entry.type, "node"));
        try std.testing.expect(comptime @hasDecl(entry.type, "render"));
        try std.testing.expect(comptime @hasDecl(entry.type, "measure"));
        try std.testing.expect(comptime @hasDecl(entry.type, "writeRecord"));
        try std.testing.expect(comptime @hasDecl(entry.type, "fromNode"));
    }
}

test "component union roundtrips concrete component objects" {
    const icon_button_component = Component{ .icon_button = .{ .id = 14, .label = "Search", .icon = Icon.named(.search) } };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = icon_button_component.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Component.fromObject(canonical);

    try std.testing.expectEqual(@as(u32, 14), decoded.icon_button.id);
    try std.testing.expectEqualStrings("Search", decoded.icon_button.label);
    try std.testing.expectEqual(Icon.named(.search).value, decoded.icon_button.icon.value);
}

test "component constructors provide app-facing composition helpers" {
    try std.testing.expectEqualStrings("Runtime", card("Runtime", "ready", .panel).card.title);
    try std.testing.expectEqual(SurfaceVariant.panel, card("Runtime", "ready", .panel).card.variant);
    try std.testing.expectEqual(@as(u32, 70), selectableCard(70, "Runtime", "ready", .panel).card.id.?);
    try std.testing.expectEqual(SurfaceVariant.panel, panel("Runtime", "ready").card.variant);
    try std.testing.expectEqual(@as(u32, 71), selectablePanel(71, "Runtime", "ready").card.id.?);
    try std.testing.expectEqual(SurfaceVariant.elevated, elevated("Runtime", "ready").card.variant);
    try std.testing.expectEqual(@as(u32, 72), selectableElevated(72, "Runtime", "ready").card.id.?);
    try std.testing.expectEqual(SurfaceVariant.subtle, subtle("Runtime", "ready").card.variant);
    try std.testing.expectEqual(@as(u32, 73), selectableSubtle(73, "Runtime", "ready").card.id.?);
    try std.testing.expectEqual(@as(f32, 0.42), progress(0.42).progress.value);
    try std.testing.expectEqual(BadgeVariant.secondary, badge("ready", .secondary).badge.variant);
    try std.testing.expectEqual(Icon.named(.sparkles).tag(), icon(.sparkles).icon.tag());
    try std.testing.expectEqual(@as(u32, 74), input(74, "Search").input.id);
    try std.testing.expectEqualStrings("needle", inputValue(74, "Search", "needle").input.value);
    try std.testing.expectEqual(IconSlot.named(.leading, .search).tag(), inputIcon(74, "Search", .search).input.icon_slot.tag());
    try std.testing.expectEqual(@as(u32, 77), rowItem(77, "Task", "Ready").row_item.id);
    try std.testing.expectEqual(IconSlot.named(.leading, .message_2).tag(), rowItemIcon(77, "Task", "Ready", .message_2).row_item.leading_icon.tag());
    try std.testing.expectEqual(@as(u32, 78), button(78, "Run", .primary, IconSlot.named(.leading, .send)).button.id);
    try std.testing.expectEqual(IconSlot.named(.leading, .send).tag(), buttonIcon(78, "Run", .primary, .send).button.icon_slot.tag());
    try std.testing.expectEqual(Icon.named(.send).value, iconButtonNamed(79, "Send", .send, .outline).icon_button.icon.value);
    try std.testing.expectEqual(IconSlot.named(.trailing, .adjustments).tag(), selectIcon(80, "Profile", .adjustments).select.icon_slot.tag());
    try std.testing.expectEqualStrings("Describe", textarea(79, "Describe").textarea.placeholder);
    try std.testing.expectEqualStrings("Live", textareaValue(79, "Describe", "Live").textarea.value);
    try std.testing.expect(checkbox(80, "Enabled", true).checkbox.checked);
    try std.testing.expect(toggle(80, "Bold", true).toggle.pressed);
    try std.testing.expectEqual(@as(u16, 1), tabs(80, "Graph", "Timeline", 1).tabs.active.?);
    try std.testing.expectEqual(@as(u32, 81), chart(81, "Activity").chart.id);
    try std.testing.expectEqualStrings("Heads up", alert("Heads up", "Detail").alert.title);
    try std.testing.expect(destructiveAlert("Delete", "Danger").alert.destructive);
    try std.testing.expectEqual(@as(u32, 82), command(82, "Run command").command.id);
    try std.testing.expectEqualStrings("Saved", toast(83, "Saved", "Complete").toast.title);
    try std.testing.expectEqualStrings("Help", tooltip(84, "?", "Help").tooltip.content);

    try std.testing.expectEqualStrings("Runtime", cardNode("Runtime", "ready", .panel).card.title);
    try std.testing.expectEqual(@as(f32, 0.42), progressNode(0.42).progress.value);
}

test "component flag helpers attach state to components that support flags" {
    try std.testing.expect(buttonText(91, "Run", .primary).loading().button.flags.loading);
    try std.testing.expect(input(92, "Email").invalid().input.flags.invalid);
    try std.testing.expect(rowItem(93, "Task", "Ready").disabled().row_item.flags.disabled);
    try std.testing.expectEqualStrings("Passive", panel("Passive", "No flags").disabled().card.title);
}

test "component view binds scene collector and options for app rendering" {
    var h = component_test.InteractiveHarness(80, 16){};
    h.init();
    const app = renderer(&h.scene, &h.collector, .{});

    try app.draw(panel("Runtime", "ready"), ui.Rect.init(0, 0, 120, 64));
    try app.interactive(buttonIcon(81, "Run", .primary, .send), ui.Rect.init(0, 72, 120, 36));
    try app.line(ui.Rect.init(0, 116, 120, 1));
    try app.icon(ui.Rect.init(4, 122, 16, 16), .send, ui.Color.accent);
    try app.buttonHit(ui.Rect.init(0, 144, 120, 24), 82);
    try app.interactive(selectablePanel(83, "Selectable", "card owns hit"), ui.Rect.init(0, 176, 120, 48));
    try app.buttonAt(ui.Rect.init(0, 232, 120, 36), 84, "Apply", .secondary);
    try app.buttonIconAt(ui.Rect.init(0, 276, 120, 36), 85, "Send", .primary, .send);
    try app.iconButtonAt(ui.Rect.init(0, 320, 36, 36), 86, "Search", .search, .outline);
    try app.switchAt(ui.Rect.init(0, 364, 160, 32), 87, "Enabled", true);
    try app.sliderAt(ui.Rect.init(0, 404, 160, 32), 88, "Value", 0.5);
    try app.badgeAt(ui.Rect.init(0, 444, 80, 24), "Ready", .secondary);
    try app.progressAt(ui.Rect.init(0, 476, 120, 12), 0.5);
    try app.emptyAt(ui.Rect.init(0, 496, 160, 64), "Empty", "Nothing here");
    try app.rowItemAt(ui.Rect.init(0, 568, 160, 42), 0, "Row", "Detail");

    try h.expectText("Runtime");
    try h.expectText("Run");
    try h.expectText("Ready");
    try h.expectText("Empty");
    try h.expectIcon(icon_pack.iconId(.send));
    try h.expectHitIds(&.{ 81, 82, 83, 84, 85, 86, 87, 88 });
}

test "component renderer reports missing collector for interactive calls" {
    var h = component_test.SceneHarness(8){};
    h.init();
    const app = renderer(&h.scene, null, .{});

    try std.testing.expect(!app.hasCollector());
    try std.testing.expectError(error.MissingInteractionCollector, app.interactive(buttonText(90, "Run", .primary), ui.Rect.init(0, 0, 100, 36)));
    try std.testing.expectError(error.MissingInteractionCollector, app.buttonHit(ui.Rect.init(0, 40, 100, 24), 91));
}

test "component renderer provides higher level app surfaces" {
    var h = component_test.InteractiveHarness(96, 12){};
    h.init();
    const app = renderer(&h.scene, &h.collector, .{});

    try app.section(ui.Rect.init(0, 0, 240, 42), .{
        .title = "Controls",
        .detail = "Runtime knobs",
        .icon = .adjustments,
    });
    try app.labelValue(ui.Rect.init(0, 42, 240, 18), "path", "repo", 64.0);
    try app.metricCard(ui.Rect.init(0, 52, 240, 112), .{
        .id = 99,
        .title = "Memory",
        .detail = "Live pressure",
        .value = "42%",
        .icon = .database,
        .progress = 0.42,
    });
    const segments = [_]Segment{
        .{ .id = 100, .weight = 0.7, .height = 1.0, .color = ui.Color.accent, .selected = true },
        .{ .id = 101, .weight = 0.3, .height = 0.4, .color = ui.Color.muted },
    };
    try app.segmentMap(ui.Rect.init(0, 174, 240, 64), .{
        .segments = &segments,
        .background = ui.Color.panel,
        .border = ui.Color.border,
        .selected_border = ui.Color.text,
    });
    const blocks = [_]TimelineBlock{
        .{ .id = 102, .start = 0.1, .end = 0.6, .value = 0.8, .color = ui.Color.accent },
    };
    try app.timelineLane(ui.Rect.init(82, 248, 158, 56), .{
        .label = "RAM",
        .lane_index = 0,
        .lane_count = 1,
        .blocks = &blocks,
        .border = ui.Color.border,
        .label_color = ui.Color.muted,
    });
    try app.controlGroup(ui.Rect.init(0, 314, 240, 112), .{
        .id = 103,
        .title = "Screen",
        .value = "42%",
        .slider_id = 104,
        .slider_value = 0.42,
        .down_id = 105,
        .down_label = "Screen -",
        .down_icon = .brightness_down,
        .up_id = 106,
        .up_label = "Screen +",
        .up_icon = .brightness_up,
    });
    try app.pathRow(ui.Rect.init(0, 436, 240, 58), .{
        .id = 107,
        .title = "repo/app",
        .detail = "UI source",
        .trailing = "42 MB",
        .progress = 0.6,
        .accent = ui.Color.accent,
        .progress_color = ui.Color.accent,
    });
    try app.pipelineNode(ui.Rect.init(0, 504, 240, 64), .{
        .id = 108,
        .title = "index",
        .detail = "extract relationships",
        .accent = ui.Color.accent,
    });
    _ = try app.floatingPanel(ui.Rect.init(0, 578, 160, 80), .{
        .scrim = ui.Color.accent,
        .scrim_height = 24.0,
    });

    try h.expectText("Controls");
    try h.expectText("repo");
    try h.expectText("Memory");
    try h.expectText("42%");
    try h.expectText("index");
    try h.expectHitIds(&.{ 99, 100, 101, 102, 103, 104, 105, 106, 107, 108 });
}

test "semantic view renders meaning through deterministic components" {
    var h = component_test.InteractiveHarness(160, 16){};
    h.init();
    const app = renderer(&h.scene, &h.collector, .{});
    const items = [_]SemanticItem{
        .{ .kind = .resource, .label = "RAM fit", .value = "53%", .detail = "selected path x grant", .importance = .primary, .state = .warning, .progress = 0.53, .id = 210 },
        .{ .kind = .path, .label = "app/src", .value = "41 MB", .detail = "UI and app graph", .state = .private, .id = 211 },
        .{ .kind = .action, .label = "Commit useful result", .detail = "write durable output", .state = .good, .id = 212 },
    };

    try app.semanticView(ui.Rect.init(0, 0, 360, 260), .{
        .title = "scheduler controls",
        .detail = "stage budgets are explicit",
        .intent = .{ .mode = .schedule, .focus = .resources, .density = .compact },
        .items = &items,
    });

    try h.expectText("scheduler controls");
    try h.expectText("RAM fit");
    try h.expectText("app/src");
    try h.expectText("Commit useful result");
    try std.testing.expect(h.hits().len >= 3);
}

test "component renderer provides layout cursors and message bubbles" {
    var h = component_test.SceneHarness(48){};
    h.init();
    const app = renderer(&h.scene, null, .{});

    var column_cursor = app.column(ui.Rect.init(10, 20, 120, 100), 6.0);
    try std.testing.expectEqual(ui.Rect.init(10, 20, 120, 24), column_cursor.take(24.0));
    try std.testing.expectEqual(ui.Rect.init(10, 50, 120, 30), column_cursor.take(30.0));
    try std.testing.expect(column_cursor.takeIfFits(80.0) == null);
    try std.testing.expectEqual(ui.Rect.init(10, 86, 120, 34), column_cursor.remaining());

    var row_cursor = app.row(ui.Rect.init(0, 0, 100, 20), 5.0);
    try std.testing.expectEqual(ui.Rect.init(0, 0, 30, 20), row_cursor.take(30.0));
    try std.testing.expectEqual(ui.Rect.init(35, 0, 65, 20), row_cursor.remaining());

    const split = app.splitLeft(ui.Rect.init(0, 0, 100, 20), 30.0, 5.0);
    try std.testing.expectEqual(ui.Rect.init(0, 0, 30, 20), split.first);
    try std.testing.expectEqual(ui.Rect.init(35, 0, 65, 20), split.second);

    const grid_layout = app.grid(ui.Rect.init(0, 0, 105, 200), 2, 5.0, 20.0);
    try std.testing.expectEqual(ui.Rect.init(0, 0, 50, 20), grid_layout.item(0));
    try std.testing.expectEqual(ui.Rect.init(55, 0, 50, 20), grid_layout.item(1));
    try std.testing.expectEqual(ui.Rect.init(0, 25, 50, 20), grid_layout.item(2));
    try std.testing.expectEqual(@as(f32, 45.0), grid_layout.height(4));

    const shell = app.workspaceShell(ui.Rect.init(0, 0, 1000, 700), .{
        .rail_w = 48.0,
        .sidebar_w = 260.0,
        .top_h = 56.0,
        .status_h = 24.0,
    });
    try std.testing.expectEqual(ui.Rect.init(0, 0, 48, 676), shell.rail);
    try std.testing.expectEqual(ui.Rect.init(48, 0, 952, 56), shell.top);
    try std.testing.expectEqual(ui.Rect.init(48, 56, 260, 620), shell.sidebar);
    try std.testing.expectEqual(ui.Rect.init(308, 56, 692, 620), shell.main);
    try std.testing.expectEqual(ui.Rect.init(0, 676, 1000, 24), shell.status);

    var surface_h = component_test.SceneHarness(128){};
    surface_h.init();
    const surface_app = renderer(&surface_h.scene, null, .{});
    const surface = try surface_app.workspaceSurface(ui.Rect.init(0, 0, 1000, 700), .{
        .background = ui.Color{ .r = 1, .g = 2, .b = 3 },
        .top = .{
            .title = "Workspace",
            .detail = "semantic shell",
            .trailing_top = "mode",
            .trailing_bottom = "agent",
            .fill = ui.Color{ .r = 4, .g = 5, .b = 6 },
        },
        .status = .{
            .text = "ready",
            .fill = ui.Color{ .r = 7, .g = 8, .b = 9 },
        },
    });
    try std.testing.expectEqual(shell.rail, surface.rail);
    try surface_h.expectText("Workspace");
    try surface_h.expectText("semantic shell");
    try surface_h.expectText("ready");

    const wide_panes = app.responsivePanes(ui.Rect.init(0, 0, 1000, 300), .{
        .first_w = 200.0,
        .third_w = 220.0,
        .first_stack_h = 90.0,
        .second_stack_h = 120.0,
        .gap = 10.0,
    });
    try std.testing.expect(!wide_panes.stacked);
    try std.testing.expectEqual(ui.Rect.init(0, 0, 200, 300), wide_panes.first);
    try std.testing.expectEqual(ui.Rect.init(210, 0, 560, 300), wide_panes.second);
    try std.testing.expectEqual(ui.Rect.init(780, 0, 220, 300), wide_panes.third);

    const stacked_panes = app.responsivePanes(ui.Rect.init(0, 0, 700, 400), .{
        .first_w = 200.0,
        .third_w = 220.0,
        .first_stack_h = 100.0,
        .second_stack_h = 160.0,
        .gap = 10.0,
    });
    try std.testing.expect(stacked_panes.stacked);
    try std.testing.expectEqual(ui.Rect.init(0, 0, 700, 100), stacked_panes.first);
    try std.testing.expectEqual(ui.Rect.init(0, 110, 700, 160), stacked_panes.second);
    try std.testing.expectEqual(ui.Rect.init(0, 280, 700, 120), stacked_panes.third);

    try app.messageBubble(ui.Rect.init(0, 130, 220, 112), .{
        .body = "Image received",
        .media_label = "image",
        .media_detail = "object://image/8f21",
        .media_icon = .photo,
    });
    try h.expectText("Image received");
    try h.expectText("image");
    try h.expectIcon(icon_pack.iconId(.photo));
}

test "component renderer provides action toolbar and panel list" {
    var h = component_test.InteractiveHarness(128, 16){};
    h.init();
    const app = renderer(&h.scene, &h.collector, .{});

    const actions = [_]IconButtonSpec{
        .{ .id = 701, .label = "Photo", .icon = .photo },
        .{ .id = 702, .label = "Send", .icon = .send, .variant = .primary },
    };
    try app.actionToolbar(ui.Rect.init(0, 0, 84, 36), .{ .specs = &actions, .button_w = 34.0, .gap = 8.0 });
    try app.actionToolbar(ui.Rect.init(90, 0, 40, 84), .{ .specs = &actions, .direction = .column, .button_h = 36.0, .gap = 8.0 });

    const rows = [_]PanelListItem{
        .{ .id = 711, .title = "Runtime", .detail = "ready", .icon = .cpu },
        .{ .title = "Output", .detail = "none" },
    };
    try app.panelList(ui.Rect.init(0, 100, 260, 170), .{
        .title = "Events",
        .detail = "stream",
        .items = &rows,
        .empty_title = "No events",
    });

    try h.expectText("Events");
    try h.expectText("Runtime");
    try h.expectIcon(icon_pack.iconId(.send));
    try h.expectIcon(icon_pack.iconId(.cpu));
    try h.expectHitIds(&.{ 701, 702, 701, 702, 711 });
}

test "component renderer provides graph and timeline primitives" {
    var h = component_test.InteractiveHarness(96, 8){};
    h.init();
    const app = renderer(&h.scene, &h.collector, .{});
    const marks = [_]TimelineMark{
        .{ .x = 0.0, .label = "load" },
        .{ .x = 0.5, .label = "work" },
        .{ .x = 1.0, .label = "commit" },
    };
    const viewport_marks = [_]TimelineViewportMark{
        .{ .at = 0.0, .label = "start" },
        .{ .at = 0.5, .label = "middle" },
        .{ .at = 1.0, .label = "end" },
    };
    const blocks = [_]TimelineBlock{
        .{ .id = 801, .start = 0.25, .end = 0.75, .value = 0.8, .color = ui.Color.accent },
    };
    const lanes = [_]TimelineViewportLane{
        .{ .label = "RAM", .blocks = &blocks },
    };

    try app.lineRect(0.0, 10.0, 40.0, 10.0, ui.Color.accent, 2.0);
    try app.elbowEdge(ui.Rect.init(0, 24, 40, 20), ui.Rect.init(120, 54, 40, 20), ui.Color.accent, 2.0);
    try app.timelineAxis(ui.Rect.init(0, 100, 180, 40), &marks, ui.Color.border, ui.Color.muted);
    try app.timelineViewport(ui.Rect.init(0, 144, 260, 110), .{
        .title = "Events",
        .lanes = &lanes,
        .marks = &viewport_marks,
        .viewport = .{ .offset = 0.2, .scale = 1.5 },
        .controls = .{
            .pan_left_id = 811,
            .pan_right_id = 812,
            .zoom_out_id = 813,
            .zoom_in_id = 814,
            .reset_id = 815,
        },
    });

    try h.expectText("load");
    try h.expectText("work");
    try h.expectText("commit");
    try h.expectText("Events");
    try h.expectText("RAM");
    try h.expectHitIds(&.{ 811, 813, 815, 814, 812, 801 });
}

test "timeline viewport actions update shared viewport state" {
    const controls = TimelineViewportControls{
        .pan_left_id = 901,
        .pan_right_id = 902,
        .zoom_out_id = 903,
        .zoom_in_id = 904,
        .reset_id = 905,
    };
    var state = TimelineViewportState{};

    try std.testing.expectEqual(TimelineViewportAction.zoom_in, timelineViewportActionForHit(904, controls).?);
    applyTimelineViewportAction(&state, .zoom_in);
    try std.testing.expect(state.scale > 1.0);
    applyTimelineViewportAction(&state, .pan_right);
    try std.testing.expect(state.offset > 0.0);
    applyTimelineViewportAction(&state, .reset);
    try std.testing.expectEqual(@as(f32, 0.0), state.offset);
    try std.testing.expectEqual(@as(f32, 1.0), state.scale);
    try std.testing.expect(timelineViewportActionForHit(999, controls) == null);
}

test "component render options helpers preserve immutable call style" {
    const options = (RenderOptions{})
        .withStyle(ui.Style{ .accent = ui.Color.accent })
        .withAccent(ui.Color.text)
        .withTextColor(ui.Color.muted)
        .withControl(.{ .active = true })
        .withMergedControl(.{ .loading = true })
        .withControlSize(.large);

    try std.testing.expectEqual(ui.Color.text, options.style.accent);
    try std.testing.expectEqual(ui.Color.muted, options.style.text);
    try std.testing.expect(options.control.active);
    try std.testing.expect(options.control.loading);
    try std.testing.expectEqual(common.ControlSize.large, options.control_size);
}

test "component union decodes only canonical component objects" {
    const candidate = Component{ .badge = .{ .label = "Object", .variant = .secondary } };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = candidate.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const view = try object.View.decode(canonical);

    try std.testing.expectEqual(object.Kind.bytes, view.header.kind);
    try std.testing.expect(std.meta.eql(component_codec.requirements(), view.header.requirements));
    try std.testing.expectError(error.Corrupt, Component.fromObject(view.body));
}

test "component union rejects objects without component requirements" {
    const candidate = Component{ .button = .{ .id = 7, .label = "Wrong req" } };
    var req = component_codec.requirements();
    req.visibility = .private;
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    var writer = component_codec.Writer.init(&ui_raw, 1, 1, .column, 0, 0).?;
    try std.testing.expect(component_codec.writeRecord(Component, &writer, 0, candidate));
    const canonical = writer.objectNode(&object_raw, req, component_test.epoch()).?;

    try std.testing.expectError(error.Corrupt, Component.fromObject(canonical));
}

test "component union dispatches button variants and collects hit targets" {
    var h = component_test.InteractiveHarness(16, 4){};
    h.init();

    const primary = Component{ .button = .{ .id = 501, .label = "Primary" } };
    const outline = Component{ .button = .{ .id = 502, .label = "Outline", .variant = .outline, .icon_slot = IconSlot.named(.leading, .search) } };
    try primary.render(&h.scene, ui.Rect.init(0, 0, 120, 36), .{});
    try primary.collectInteractions(&h.collector, ui.Rect.init(0, 0, 120, 36), .{});
    try outline.render(&h.scene, ui.Rect.init(0, 44, 120, 36), .{});
    try outline.collectInteractions(&h.collector, ui.Rect.init(0, 44, 120, 36), .{});

    try std.testing.expectEqual(@as(u32, 501), ui_input.hitTest(h.hits(), 12, 12).?.id);
    try std.testing.expectEqual(@as(u32, 502), ui_input.hitTest(h.hits(), 12, 56).?.id);
    try h.expectText("Primary");
    try h.expectText("Outline");
    try h.expectIcon(icon_pack.iconId(.search));
}

test "component renderInteractive renders and collects through one canonical path" {
    var h = component_test.InteractiveHarness(16, 2){};
    h.init();

    const launch_button = Component{ .button = .{ .id = 510, .label = "Launch" } };
    try launch_button.renderInteractive(&h.scene, &h.collector, ui.Rect.init(0, 0, 120, 36), .{});

    try h.expectText("Launch");
    try h.expectHitCount(1);
    try h.expectHitKind(0, .button);
    try h.expectHitId(0, 510);
}

test "component renderInteractive honors disabled interaction state" {
    var h = component_test.InteractiveHarness(16, 2){};
    h.init();

    const disabled_button = Component{ .button = .{ .id = 511, .label = "Disabled" } };
    try disabled_button.renderInteractive(&h.scene, &h.collector, ui.Rect.init(0, 0, 120, 36), .{
        .interaction = .{ .disabled_id = 511 },
    });

    try h.expectText("Disabled");
    try h.expectFillColor(common.state_disabled_tint);
    try h.expectHitCount(0);
}

test "component renderer exports shared sizing tokens for measurements" {
    try std.testing.expectEqual(ui_tokens.Component.surface_radius, card_component.surface_radius);
    try std.testing.expectEqual(ui_tokens.Component.surface_padding, card_component.surface_padding);
    try std.testing.expectEqual(ui_tokens.Component.surface_detail_gap, card_component.surface_detail_gap);
    try std.testing.expectEqual(ui_tokens.Component.badge_height, badge_component.badge_height);
    try std.testing.expectEqual(ui_tokens.Component.badge_padding_x, badge_component.badge_padding_x);
}

test "component accessibility metadata comes from component identity and labels" {
    const button_meta = (Component{ .button = .{ .id = 91, .label = "Save" } }).accessibility();
    try std.testing.expectEqual(common.AccessibilityRole.button, button_meta.role);
    try std.testing.expectEqual(@as(u32, 91), button_meta.control_id.?);
    try std.testing.expectEqualStrings("Save", button_meta.label);

    const input_meta = (Component{ .input = .{ .id = 92, .placeholder = "Email" } }).accessibility();
    try std.testing.expectEqual(common.AccessibilityRole.input, input_meta.role);
    try std.testing.expectEqual(@as(u32, 92), input_meta.control_id.?);
    try std.testing.expectEqualStrings("Email", input_meta.label);

    const table_meta = (Component{ .table = .{ .id = 93, .name = "Ada", .role = "Engineer" } }).accessibility();
    try std.testing.expectEqual(common.AccessibilityRole.table, table_meta.role);
    try std.testing.expectEqual(@as(u32, 93), table_meta.control_id.?);
    try std.testing.expectEqualStrings("Ada", table_meta.label);
}

test "component union applies shared interactive states by component id" {
    var h = component_test.SceneHarness(32){};
    h.init();
    const save_button = Component{ .button = .{ .id = 701, .label = "Save" } };
    try save_button.render(&h.scene, ui.Rect.init(10, 12, 120, 36), .{
        .interaction = .{
            .hovered_id = 701,
            .active_id = 701,
            .focused_id = 701,
            .disabled_id = 701,
            .loading_id = 701,
            .invalid_id = 701,
        },
    });

    try h.expectRectColor(common.state_hover_border);
    try h.expectRectColor(common.state_active_border);
    try h.expectRectColor(common.state_focus_border);
    try h.expectRectColor(common.state_invalid_border);
    try h.expectFillColor(common.state_disabled_tint);
    try h.expectFillColor(common.state_loading_fill);
}

test "component union does not leak interactive state to other ids" {
    var h = component_test.SceneHarness(16){};
    h.init();
    const save_button = Component{ .button = .{ .id = 702, .label = "Save" } };
    try save_button.render(&h.scene, ui.Rect.init(10, 12, 120, 36), .{
        .interaction = .{ .focused_id = 701 },
    });

    try std.testing.expect(!component_test.hasRectColor(h.written(), common.state_focus_border));
}

test "component interaction collection covers primitive controls" {
    const controls = [_]Component{
        .{ .input = .{ .id = 601, .placeholder = "Filter" } },
        .{ .textarea = .{ .id = 602, .placeholder = "Explain" } },
        .{ .select = .{ .id = 603, .label = "Mode" } },
        .{ .checkbox = .{ .id = 604, .label = "Receipts", .checked = true } },
        .{ .switch_control = .{ .id = 605, .label = "Public", .checked = false } },
        .{ .slider = .{ .id = 606, .label = "Brightness", .value = 0.5 } },
        .{ .row_item = .{ .id = 607, .title = "DNS", .detail = "Lookup" } },
    };
    const expected = [_]ui.HitKind{ .input, .textarea, .select, .checkbox, .switch_control, .slider, .row_item };
    var h = component_test.InteractionHarness(controls.len){};
    h.init();

    for (controls, 0..) |control, index| {
        const y = @as(f32, @floatFromInt(index)) * 48.0;
        try control.collectInteractions(&h.collector, ui.Rect.init(0, y, 240, 40), .{});
    }

    try h.expectHitCount(controls.len);
    for (expected, 0..) |kind, index| {
        try h.expectHitId(index, 601 + @as(u32, @intCast(index)));
        try h.expectHitKind(index, kind);
    }
}
