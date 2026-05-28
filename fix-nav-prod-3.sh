#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

python3 - <<'PY'
from pathlib import Path
import re

root = Path("edgerun-zig/src")

def rw(rel, fn):
    p = root / rel
    s = p.read_text()
    ns = fn(s)
    if ns != s:
        p.write_text(ns)

# --------------------------------------------------------------------
# app_chrome: ControlState does not contain control_size.
# RenderOptions owns control_size.
# --------------------------------------------------------------------
def fix_chrome(s: str) -> str:
    s = s.replace(
'''    const control: ui_component_common.ControlState = .{
        .active = props.active,
        .disabled = !props.enabled,
        .control_size = props.control_size orelse .default,
    };''',
'''    const control: ui_component_common.ControlState = .{
        .active = props.active,
        .disabled = !props.enabled,
    };'''
    )

    s = s.replace(
'''    try button.render(scene, props.bounds, .{
        .style = design.style(),
        .control = control,
    });''',
'''    try button.render(scene, props.bounds, .{
        .style = design.style(),
        .control = control,
        .control_size = props.control_size orelse .default,
    });'''
    )
    return s

rw("app_chrome.zig", fix_chrome)

# --------------------------------------------------------------------
# app_source: runtime expects these to exist.
# Keep hit IDs canonical in app_source, not runtime.
# --------------------------------------------------------------------
def fix_source(s: str) -> str:
    if "pub const source_file_hit_base" not in s:
        if "pub const explorer_search_input_id" in s:
            s = re.sub(
                r"(pub const explorer_search_input_id: u32 = [0-9_]+;\n)",
                r"\1pub const source_file_hit_base: u32 = 32_200;\n",
                s,
                count=1,
            )
        else:
            s = s.replace(
                'const ui = @import("ui.zig");\n',
                'const ui = @import("ui.zig");\n\npub const editor_textarea_id: u32 = 32_100;\npub const explorer_search_input_id: u32 = 32_101;\npub const source_file_hit_base: u32 = 32_200;\n',
            )

    if "pub fn sourceIndexFromHit(" not in s:
        s += r'''

pub fn sourceIndexFromHit(hit_id: u32) ?usize {
    if (hit_id < source_file_hit_base) return null;
    return @intCast(hit_id - source_file_hit_base);
}
'''

    if "pub fn cursorFromTextAreaBounds(" not in s:
        s += r'''

pub fn cursorFromTextAreaBounds(bounds: ui.Rect, state: State, x: f32, y: f32) usize {
    return cursorFromPoint(bounds, state, x, y);
}
'''

    if "pub fn cursorFromPoint(" not in s:
        s += r'''

pub fn cursorFromPoint(bounds: ui.Rect, state: State, x: f32, y: f32) usize {
    if (state.source.len == 0) return 0;

    const local_x = @max(0.0, x - bounds.x - code_gutter_w - code_pad);
    const local_y = @max(0.0, y - bounds.y - code_pad);
    const line_index: usize = @intFromFloat(@max(0.0, local_y / code_line_h));
    const column: usize = @intFromFloat(@max(0.0, local_x / code_char_w));

    var line: usize = 0;
    var i: usize = 0;
    while (i < state.source.len and line < line_index) : (i += 1) {
        if (state.source[i] == '\n') line += 1;
    }

    var col: usize = 0;
    while (i < state.source.len and state.source[i] != '\n' and col < column) : ({
        i += 1;
        col += 1;
    }) {}

    return @min(i, state.source.len);
}
'''

    return s

rw("app_source.zig", fix_source)

# --------------------------------------------------------------------
# ui_node: replace bad loose u32 node shape with codec/component shape.
# Important: encoded tags are u16 because component fromNode APIs take u16.
# --------------------------------------------------------------------
(root / "ui_node.zig").write_text(r'''const ui = @import("ui.zig");

pub const Node = union(enum) {
    rect: struct {
        color: ui.Color,
    },
    text: struct {
        value: []const u8,
        color: ?ui.Color = null,
    },
    slot: struct {
        id: u32,
        child: *const Node,
    },
    stack: ui.Layout,

    accordion: struct { id: u32, title: []const u8, detail: []const u8, open: bool = false },
    alert: struct { title: []const u8, detail: []const u8, destructive: bool = false, icon: u16 = 0 },
    alert_dialog: struct { id: u32, title: []const u8, detail: []const u8 },
    aspect_ratio: struct { ratio_w: u16, ratio_h: u16 },
    calendar: struct { id: u32, month: []const u8, selected_day: u16 = 0 },
    carousel: struct { id: u32, label: []const u8 },
    chart: struct { id: u32, label: []const u8 },
    combobox: struct { id: u32, placeholder: []const u8, selected: []const u8 = "" },
    empty: struct { title: []const u8, detail: []const u8, icon: u16 = 0 },

    button: struct { id: u32, label: []const u8, variant: u16 = 0, leading_icon: u16 = 0, trailing_icon: u16 = 0 },
    icon_button: struct { id: u32, label: []const u8, variant: u16 = 0, icon: u16 = 0 },
    button_group: struct { id: u32, first: []const u8, second: []const u8, active: u16 = 0 },
    toggle_group: struct { id: u32, first: []const u8, second: []const u8, active: u16 = 0 },

    input: struct { id: u32, placeholder: []const u8, leading_icon: u16 = 0 },
    input_group: struct { id: u32, addon: []const u8, placeholder: []const u8 },
    input_otp: struct { id: u32, value: []const u8 },
    textarea: struct { id: u32, placeholder: []const u8 },
    select: struct { id: u32, label: []const u8, trailing_icon: u16 = 0 },
    field: struct { id: u32, label: []const u8, placeholder: []const u8 },
    checkbox: struct { id: u32, label: []const u8, checked: bool = false },
    switch_control: struct { id: u32, label: []const u8, checked: bool = false },
    slider: struct { id: u32, label: []const u8, value: f32 = 0.0 },
    radio_group: struct { id: u32, first: []const u8, second: []const u8, selected: u16 = 0 },

    row_item: struct { id: u32, title: []const u8, detail: []const u8 },
    badge: struct { label: []const u8, variant: u16 = 0 },
    card: struct { title: []const u8, detail: []const u8, variant: u16 = 0 },
    avatar: struct { label: []const u8 },
    kbd: struct { label: []const u8 },
    label: struct { value: []const u8 },
    table: struct { id: u32, name: []const u8, role: []const u8 },

    separator: void,
    scroll_area: void,
    skeleton: void,
    spinner: void,
    progress: struct { value: f32 = 0.0 },

    breadcrumb: struct { id: u32, first: []const u8, current: []const u8 },
    menubar: struct { id: u32, first: []const u8, second: []const u8, active: u16 = 0 },
    navigation_menu: struct { id: u32, first: []const u8, second: []const u8, active: u16 = 0 },
    pagination: struct { id: u32, page: u16 = 0 },
    tabs: struct { id: u32, first: []const u8, second: []const u8, active: u16 = 0 },
    direction: struct { id: u32, active: u16 = 0 },

    command: struct { id: u32, placeholder: []const u8, leading_icon: u16 = 0 },
    context_menu: struct { id: u32, first: []const u8, second: []const u8 },
    dialog: struct { id: u32, title: []const u8, detail: []const u8 },
    drawer: struct { id: u32, title: []const u8, detail: []const u8 },
    dropdown_menu: struct { id: u32, first: []const u8, second: []const u8 },
    hover_card: struct { id: u32, trigger: []const u8, content: []const u8 },
    popover: struct { id: u32, trigger: []const u8, content: []const u8 },
    tooltip: struct { id: u32, trigger: []const u8, content: []const u8 },
    toast: struct { id: u32, title: []const u8, detail: []const u8 },
    sheet: struct { id: u32, title: []const u8, detail: []const u8 },
    sidebar: struct { id: u32, title: []const u8, item: []const u8 },

    icon: struct { label: []const u8, icon: u16 = 0 },
    toggle: struct { id: u32, label: []const u8, pressed: bool = false },
    resizable: struct { id: u32, ratio: f32 = 0.5 },
};
''')

# --------------------------------------------------------------------
# ui.zig: ensure Layout exists for stack node rendering.
# --------------------------------------------------------------------
def fix_ui(s: str) -> str:
    if "pub const Layout = struct" not in s:
        marker = "pub const LinearCursor = struct {"
        layout = r'''
pub const Layout = struct {
    axis: Axis = .column,
    gap: f32 = 0.0,
    padding: f32 = 0.0,
    cross_align: Align = .stretch,
    children: []const Node = &.{},
};

'''
        s = s.replace(marker, layout + marker)
    return s

rw("ui.zig", fix_ui)

# --------------------------------------------------------------------
# Nav: make it slot based. It wraps a child node pointer instead of Component.
# This avoids Component <-> Nav dependency loops and matches the model you want.
# --------------------------------------------------------------------
(root / "ui/components/Nav.zig").write_text(r'''const ui = @import("../../ui.zig");
const interaction = @import("../../ui_interaction.zig");
const common = @import("../../ui_component_common.zig");
const node_renderer = @import("NodeRenderer.zig");

pub const Target = union(enum) {
    hit_id: u32,
    path: []const u8,
    slug: []const u8,
};

pub const Nav = struct {
    id: u32,
    target: Target,
    child: *const ui.Node,
    active: bool = false,
    disabled: bool = false,

    pub fn node(self: Nav) ui.Node {
        return .{ .slot = .{ .id = self.id, .child = self.child } };
    }

    pub fn render(self: Nav, comptime Component: type, scene: *ui.Scene, bounds: ui.Rect, options: common.RenderOptions) ui.RenderError!void {
        var resolved = options;
        resolved.control = options.control.merge(.{
            .active = self.active,
            .disabled = self.disabled,
        });
        try node_renderer.renderNode(Component, scene, bounds, self.child.*, resolved);
    }

    pub fn collectInteractions(self: Nav, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        if (self.disabled) return;
        try collector.addHit(bounds, .button, self.id);
    }
};
''')

# Ensure Component does not include Nav as recursive union member.
def fix_component(s: str) -> str:
    s = s.replace('const nav_component = @import("Nav.zig");\n', '')
    s = s.replace('    nav: nav_component.Nav,\n', '')
    return s

rw("ui/components/Component.zig", fix_component)

PY

zig fmt \
  edgerun-zig/src/app_chrome.zig \
  edgerun-zig/src/app_source.zig \
  edgerun-zig/src/ui.zig \
  edgerun-zig/src/ui_node.zig \
  edgerun-zig/src/ui/components/Nav.zig \
  edgerun-zig/src/ui/components/Component.zig

make pages-release
