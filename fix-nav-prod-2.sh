#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

python3 - <<'PY'
from pathlib import Path
import re

root = Path("edgerun-zig/src")

def patch(path, fn):
    p = root / path
    s = p.read_text()
    ns = fn(s)
    if ns != s:
        p.write_text(ns)

# 1. app_navigation: remove unused locals in test.
patch("app_navigation.zig", lambda s:
    s.replace('''    const post_id = app_blog.postIdAt(0);
    const docs_index = docIndexBySlug("component-system").?;
    for (dynamicRouteFixtures()) |entry| {''',
'''    for (dynamicRouteFixtures()) |entry| {''')
)

# 2. app_chrome: ControlState must be the actual named type.
def fix_chrome(s):
    if 'const control: ui_component_common.ControlState = .{' not in s:
        s = s.replace(
'''    const control = .{
        .active = props.active,
        .disabled = !props.enabled,
        .control_size = props.control_size orelse .default,
    };''',
'''    const control: ui_component_common.ControlState = .{
        .active = props.active,
        .disabled = !props.enabled,
        .control_size = props.control_size orelse .default,
    };'''
        )
    return s
patch("app_chrome.zig", fix_chrome)

# 3. ui.zig: wrappedLine and WrappedLine are part of text layout API now.
def fix_ui(s):
    s = s.replace("const WrappedLine = struct", "pub const WrappedLine = struct")
    s = s.replace("fn wrappedLine(value: []const u8, start: usize, char_capacity: usize) WrappedLine {",
                  "pub fn wrappedLine(value: []const u8, start: usize, char_capacity: usize) WrappedLine {")
    return s
patch("ui.zig", fix_ui)

# 4. app_source: publish the runtime adapters it is already being asked for.
def fix_source(s):
    if "pub fn cursorFromPoint(" not in s:
        s += r'''

pub fn sourceIndexFromHit(hit_id: u32) ?usize {
    if (hit_id < source_file_hit_base) return null;
    const index: usize = @intCast(hit_id - source_file_hit_base);
    return index;
}

pub fn cursorFromPoint(bounds: ui.Rect, state: State, x: f32, y: f32) usize {
    if (state.source.len == 0) return 0;
    const local_x = @max(0.0, x - bounds.x - code_gutter_w - code_pad);
    const local_y = @max(0.0, y - bounds.y - toolbar_h - code_pad);
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
    if "source_file_hit_base" not in s:
        # Keep source explorer IDs in the source module, not runtime.
        insert_after = "pub const explorer_search_input_id: u32 = 32_101;\n"
        s = s.replace(insert_after, insert_after + "pub const source_file_hit_base: u32 = 32_200;\n")
    return s
patch("app_source.zig", fix_source)

# 5. Component/Nav recursion: Nav must not be a Component union payload if it stores Component.
# Keep Nav as a wrapper helper module, not inside the recursive component object union.
def fix_component(s):
    s = s.replace('const nav_component = @import("Nav.zig");\n', '')
    s = s.replace('    nav: nav_component.Nav,\n', '')
    return s
patch("ui/components/Component.zig", fix_component)

# 6. ui_node: match actual users. NodeRenderer expects rect. ui_codec expects sidebar.
node = root / "ui_node.zig"
if node.exists():
    s = node.read_text()
    if "rect:" not in s:
        s = s.replace("pub const Node = union(enum) {\n", "pub const Node = union(enum) {\n    rect: struct { color: @import(\"ui.zig\").Color },\n")
    if "sidebar:" not in s:
        s = s.replace("    sheet: struct { id: u32, title: []const u8, detail: []const u8 },\n",
                      "    sheet: struct { id: u32, title: []const u8, detail: []const u8 },\n    sidebar: struct { id: u32, title: []const u8, item: []const u8 },\n")
    node.write_text(s)

PY

zig fmt \
  edgerun-zig/src/app_navigation.zig \
  edgerun-zig/src/app_chrome.zig \
  edgerun-zig/src/app_source.zig \
  edgerun-zig/src/ui.zig \
  edgerun-zig/src/ui_node.zig \
  edgerun-zig/src/ui/components/Component.zig \
  edgerun-zig/src/ui/components/Nav.zig

make pages-release
