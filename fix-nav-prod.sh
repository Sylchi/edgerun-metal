#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

python3 - <<'PY'
from pathlib import Path
import re

root = Path("edgerun-zig/src")

def p(name):
    return root / name

def read(path):
    return path.read_text()

def write(path, text):
    path.write_text(text)

# --------------------------------------------------------------------
# app_navigation.zig: make navigation self-contained and canonical.
# --------------------------------------------------------------------
path = p("app_navigation.zig")
s = read(path)

s = s.replace(
    "return if (index < app_blog.arc_sections.len) index else null;",
    "return app_blogArcFilterIndex(index);",
)

s = s.replace(
    ".docs_detail => .{ .view = .docs, .selected_doc_index = app_docs.indexBySlug(trimmed[RoutePath.docs_detail_prefix.len..]) },",
    ".docs_detail => .{ .view = .docs, .selected_doc_index = docIndexBySlug(trimmed[RoutePath.docs_detail_prefix.len..]) },",
)

s = s.replace(
    ".component_detail => .{ .view = .components, .selected_component_index = component_gallery.indexBySlug(trimmed[RoutePath.component_detail_prefix.len..]) },",
    ".component_detail => .{ .view = .components, .selected_component_index = component_gallery.indexBySlug(trimmed[RoutePath.component_detail_prefix.len..]) },",
)

s = s.replace("const docs_index = app_docs.indexBySlug(\"component-system\") orelse 0;", "const docs_index = docIndexBySlug(\"component-system\") orelse 0;")
s = s.replace("if (app_docs.slugByIndex(docs_index)) |slug|", "if (docSlugByIndex(docs_index)) |slug|")
s = s.replace("return app_blog.postIdFromHit(hit_id) != null;", "return blogPostIdFromHit(hit_id) != null;")
s = s.replace("return app_docs.indexFromHit(hit_id) != null;", "return docIndexFromHit(hit_id) != null;")
s = s.replace("if (app_blog.postIdFromHit(hit_id)) |post_id| {", "if (blogPostIdFromHit(hit_id)) |post_id| {")
s = s.replace("if (app_docs.indexFromHit(hit_id)) |index| {", "if (docIndexFromHit(hit_id)) |index| {")
s = s.replace("if (app_blog.postIdBySlug(slug)) |post_id| return .{ .view = .blog, .selected_blog_post_id = post_id };", "if (blogPostIdBySlug(slug)) |post_id| return .{ .view = .blog, .selected_blog_post_id = post_id };")
s = s.replace("const slug = app_blog.postSlug(post_id) orelse return error.RouteBufferTooSmall;", "const slug = blogPostSlug(post_id) orelse return error.RouteBufferTooSmall;")
s = s.replace("const slug = app_docs.slugByIndex(index) orelse return error.RouteBufferTooSmall;", "const slug = docSlugByIndex(index) orelse return error.RouteBufferTooSmall;")
s = s.replace("const slug = component_gallery.slugByIndex(index) orelse return error.RouteBufferTooSmall;", "const slug = componentSlugByIndex(index) orelse return error.RouteBufferTooSmall;")
s = s.replace("const slug = app_docs.slugByIndex(index) orelse return false;", "const slug = docSlugByIndex(index) orelse return false;")
s = s.replace("for (app_navigation.dynamicRouteFixtures()) |entry| {", "for (dynamicRouteFixtures()) |entry| {")
s = s.replace("@typeInfo(MainButton).Enum.fields", "@typeInfo(MainButton).@\"enum\".fields")
s = s.replace("@typeInfo(Action).Enum.fields", "@typeInfo(Action).@\"enum\".fields")
s = s.replace("const docs_index = app_docs.indexBySlug(\"component-system\").?;", "const docs_index = docIndexBySlug(\"component-system\").?;")

# actionId is used by app_chrome but was missing in build log.
if "pub fn actionId(action: Action) u32" not in s:
    insert_after = """pub fn actionFromHit(hit_id: u32) ?Action {
    for (action_bindings) |binding| {
        if (binding.id == hit_id) return binding.action;
    }
    return null;
}
"""
    addition = insert_after + """
pub fn actionId(action: Action) u32 {
    for (action_bindings) |binding| {
        if (binding.action == action) return binding.id;
    }
    unreachable;
}
"""
    s = s.replace(insert_after, addition)

# Add canonical local adapters before comptime blocks.
if "fn docIndexBySlug(slug: []const u8) ?usize" not in s:
    marker = "fn isComponentDocIndex(index: usize) bool {\n"
    helpers = r'''
fn docIndexBySlug(slug: []const u8) ?usize {
    for (app_docs.doc_pages, 0..) |page, index| {
        if (std.mem.eql(u8, page.slug, slug)) return index;
    }
    return null;
}

fn docIndexFromHit(hit_id: u32) ?usize {
    return docsPageIndexFromButton(hit_id);
}

fn docSlugByIndex(index: usize) ?[]const u8 {
    if (index >= app_docs.doc_pages.len) return null;
    return app_docs.doc_pages[index].slug;
}

fn componentSlugByIndex(index: usize) ?[]const u8 {
    if (index >= component_gallery.component_catalog.len) return null;
    return component_gallery.component_catalog[index].slug;
}

fn app_blogArcFilterIndex(index: usize) ?usize {
    return if (index < app_blogArcSectionCount()) index else null;
}

fn app_blogArcSectionCount() usize {
    return 5;
}

fn blogPostIdFromHit(hit_id: u32) ?u32 {
    return if (blogPostIndexFromId(hit_id) != null) hit_id else null;
}

fn blogPostIndexFromId(post_id: u32) ?usize {
    if (post_id < first_post_button_id) return null;
    const index: usize = @intCast(post_id - first_post_button_id);
    return if (index < app_blog.posts.len) index else null;
}

fn blogPostSlug(post_id: u32) ?[]const u8 {
    const index = blogPostIndexFromId(post_id) orelse return null;
    return blogSlugByIndex(index);
}

fn blogPostIdBySlug(slug: []const u8) ?u32 {
    for (app_blog.posts, 0..) |_, index| {
        if (std.mem.eql(u8, blogSlugByIndex(index), slug)) {
            return blogPostButtonId(index);
        }
    }
    return null;
}

fn blogSlugByIndex(index: usize) []const u8 {
    return switch (index) {
        0 => "device-city",
        1 => "cpu-instructions",
        2 => "ram-desk",
        3 => "storage-long-term",
        4 => "gpu-draws-reality",
        5 => "os-referee",
        6 => "apps-are-guests",
        7 => "drivers-firmware",
        8 => "keys-tpms-secure-boot",
        else => "lesson",
    };
}

'''
    s = s.replace(marker, helpers + marker)

write(path, s)

# --------------------------------------------------------------------
# app_chrome.zig: fix typed runtime controls and keep style in design.
# --------------------------------------------------------------------
path = p("app_chrome.zig")
s = read(path)

s = s.replace(
"""    const control = if (props.active)
        .{ .active = true, .disabled = !props.enabled, .control_size = props.control_size orelse .default }
    else
        .{ .disabled = !props.enabled, .control_size = props.control_size orelse .default };""",
"""    const control = .{
        .active = props.active,
        .disabled = !props.enabled,
        .control_size = props.control_size orelse .default,
    };"""
)

s = s.replace(
"        .variant = props.variant orelse if (props.active) .secondary else .outline,",
"        .variant = props.variant orelse activeVariant(props.active, .secondary, .outline),",
)
s = s.replace(
"        const variant = props.variant orelse if (props.active) .secondary else .ghost;",
"        const variant = props.variant orelse activeVariant(props.active, .secondary, .ghost);",
)
s = s.replace(
"        const variant = props.variant orelse if (props.active) .secondary else .ghost;",
"        const variant = props.variant orelse activeVariant(props.active, .secondary, .ghost);",
)

if "pub fn style() ui.Style" in s:
    s = re.sub(r"\npub fn style\(\) ui\.Style \{\n\s+return design\.style\(\);\n\}\n", "\n", s)

if "fn activeVariant(active: bool" not in s:
    s += """

fn activeVariant(active: bool, on: ui_component_common.ButtonVariant, off: ui_component_common.ButtonVariant) ui_component_common.ButtonVariant {
    return if (active) on else off;
}
"""

write(path, s)

# --------------------------------------------------------------------
# app_blog/app_docs/app_landing: use app_design.style, not app_chrome.style.
# --------------------------------------------------------------------
for name in ["app_blog.zig", "app_docs.zig", "app_landing.zig"]:
    path = p(name)
    s = read(path)
    s = s.replace("app_chrome.style()", "design.style()")
    write(path, s)

# --------------------------------------------------------------------
# app_source.zig: publish canonical source interaction IDs and support path.
# --------------------------------------------------------------------
path = p("app_source.zig")
s = read(path)

if "pub const editor_textarea_id" not in s:
    s = s.replace(
        "const ui = @import(\"ui.zig\");\n",
        "const ui = @import(\"ui.zig\");\n\npub const editor_textarea_id: u32 = 32_100;\npub const explorer_search_input_id: u32 = 32_101;\n",
    )

s = s.replace(
"""pub const FileEntry = struct {
    label: []const u8,
    dirty: bool = false,
};""",
"""pub const FileEntry = struct {
    path: []const u8,
    label: []const u8 = "",
    dirty: bool = false,

    pub fn displayLabel(self: FileEntry) []const u8 {
        if (self.label.len != 0) return self.label;
        return basename(self.path);
    }
};"""
)

if "fn basename(path:" not in s:
    s += r'''

fn basename(path: []const u8) []const u8 {
    var index = path.len;
    while (index > 0) : (index -= 1) {
        if (path[index - 1] == '/') return path[index..];
    }
    return path;
}
'''

# Replace common field access in renderer.
s = s.replace(".label", ".displayLabel()")

# The replacement above can break struct literals/options; undo obvious false positives.
s = s.replace("state.displayLabel()", "state.label")
s = s.replace(".displayLabel() = ", ".label = ")
s = s.replace("FileEntry = struct {\n    path: []const u8,\n    displayLabel()", "FileEntry = struct {\n    path: []const u8,\n    label")
s = s.replace("if (self.displayLabel().len != 0) return self.displayLabel();", "if (self.label.len != 0) return self.label;")

write(path, s)

# --------------------------------------------------------------------
# ui.zig: publish primitive helpers expected by component codec/layout.
# --------------------------------------------------------------------
path = p("ui.zig")
s = read(path)

s = s.replace("fn skipAsciiSpace(value: []const u8, start: usize) usize {", "pub fn skipAsciiSpace(value: []const u8, start: usize) usize {")

if "pub const Node =" not in s:
    insert = """
pub const Node = @import("ui_node.zig").Node;

pub fn clampUnit(value: f32) f32 {
    return geometry.clamp(value, 0.0, 1.0);
}

pub fn encodeUnit(value: f32) u16 {
    return @intFromFloat(@round(clampUnit(value) * 65535.0));
}

pub fn decodeUnit(value: u16) f32 {
    return @as(f32, @floatFromInt(value)) / 65535.0;
}

"""
    s = s.replace("pub const Rect = geometry.Rect;\n", "pub const Rect = geometry.Rect;\n" + insert)

write(path, s)

# --------------------------------------------------------------------
# ui_node.zig: create canonical component node union if missing.
# --------------------------------------------------------------------
node_path = p("ui_node.zig")
if not node_path.exists():
    node_path.write_text(r'''const common = @import("ui_component_common.zig");

pub const Node = union(enum) {
    text: struct { value: []const u8 },
    accordion: struct { id: u32, title: []const u8, detail: []const u8, open: bool = false },
    alert: struct { title: []const u8, detail: []const u8, destructive: bool = false, icon: u32 = 0 },
    alert_dialog: struct { id: u32, title: []const u8, detail: []const u8 },
    aspect_ratio: struct { ratio_w: u16, ratio_h: u16 },
    calendar: struct { id: u32, month: []const u8, selected_day: u16 = 0 },
    carousel: struct { id: u32, label: []const u8 },
    chart: struct { id: u32, label: []const u8 },
    combobox: struct { id: u32, placeholder: []const u8, selected: []const u8 = "" },
    empty: struct { title: []const u8, detail: []const u8, icon: u32 = 0 },
    button: struct { id: u32, label: []const u8, variant: u32 = 0, leading_icon: u32 = 0, trailing_icon: u32 = 0 },
    icon_button: struct { id: u32, label: []const u8, variant: u32 = 0, icon: u32 = 0 },
    button_group: struct { id: u32, first: []const u8, second: []const u8, active: u32 = 0 },
    toggle_group: struct { id: u32, first: []const u8, second: []const u8, active: u32 = 0 },
    input: struct { id: u32, placeholder: []const u8, leading_icon: u32 = 0 },
    input_group: struct { id: u32, addon: []const u8, placeholder: []const u8 },
    row_item: struct { id: u32, title: []const u8, detail: []const u8 },
    badge: struct { label: []const u8, variant: u32 = 0 },
    checkbox: struct { id: u32, label: []const u8, checked: bool = false },
    switch_control: struct { id: u32, label: []const u8, checked: bool = false },
    pagination: struct { id: u32, page: u32 = 0 },
    popover: struct { id: u32, trigger: []const u8, content: []const u8 },
    resizable: struct { id: u32, ratio: f32 = 0.5 },
    progress: struct { value: f32 = 0.0 },
    slider: struct { id: u32, label: []const u8, value: f32 = 0.0 },
    card: struct { title: []const u8, detail: []const u8, variant: u32 = 0 },
    avatar: struct { label: []const u8 },
    kbd: struct { label: []const u8 },
    label: struct { value: []const u8 },
    separator: void,
    scroll_area: void,
    skeleton: void,
    spinner: void,
    breadcrumb: struct { id: u32, first: []const u8, current: []const u8 },
    menubar: struct { id: u32, first: []const u8, second: []const u8, active: u32 = 0 },
    navigation_menu: struct { id: u32, first: []const u8, second: []const u8, active: u32 = 0 },
    command: struct { id: u32, placeholder: []const u8, leading_icon: u32 = 0 },
    context_menu: struct { id: u32, first: []const u8, second: []const u8 },
    dialog: struct { id: u32, title: []const u8, detail: []const u8 },
    direction: struct { id: u32, active: u32 = 0 },
    icon: struct { label: []const u8, icon: u32 = 0 },
    drawer: struct { id: u32, title: []const u8, detail: []const u8 },
    dropdown_menu: struct { id: u32, first: []const u8, second: []const u8 },
    field: struct { id: u32, label: []const u8, placeholder: []const u8 },
    hover_card: struct { id: u32, trigger: []const u8, content: []const u8 },
    input_otp: struct { id: u32, value: []const u8 },
    toggle: struct { id: u32, label: []const u8, pressed: bool = false },
    textarea: struct { id: u32, placeholder: []const u8 },
    select: struct { id: u32, label: []const u8, trailing_icon: u32 = 0 },
    radio_group: struct { id: u32, first: []const u8, second: []const u8, selected: u32 = 0 },
    tabs: struct { id: u32, first: []const u8, second: []const u8, active: u32 = 0 },
    table: struct { id: u32, name: []const u8, role: []const u8 },
    tooltip: struct { id: u32, trigger: []const u8, content: []const u8 },
    toast: struct { id: u32, title: []const u8, detail: []const u8 },
    sheet: struct { id: u32, title: []const u8, detail: []const u8 },
};
''')

# --------------------------------------------------------------------
# ui/components/Nav.zig: real wrapper component for navigation.
# --------------------------------------------------------------------
nav_path = p("ui/components/Nav.zig")
nav_path.write_text(r'''const ui = @import("../../ui.zig");
const interaction = @import("../../ui_interaction.zig");
const common = @import("../../ui_component_common.zig");
const component_union = @import("Component.zig");

pub const Target = union(enum) {
    hit_id: u32,
    path: []const u8,
    slug: []const u8,
};

pub const Nav = struct {
    id: u32,
    target: Target,
    child: component_union.Component,
    active: bool = false,
    disabled: bool = false,

    pub fn node(self: Nav) ui.Node {
        _ = self;
        return .{ .empty = .{ .title = "", .detail = "" } };
    }

    pub fn render(self: Nav, scene: *ui.Scene, bounds: ui.Rect, options: common.RenderOptions) ui.RenderError!void {
        var resolved = options;
        resolved.control = .{
            .active = self.active,
            .disabled = self.disabled,
        };
        try self.child.render(scene, bounds, resolved);
    }

    pub fn measure(self: Nav, constraints: @import("../../layouts.zig").types.Constraints, options: common.RenderOptions) @import("../../layouts.zig").types.Measurement {
        return self.child.measure(constraints, options);
    }

    pub fn collectInteractions(self: Nav, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        if (self.disabled) return;
        try collector.addHit(bounds, .button, self.id);
    }

    pub fn writeRecord(self: Nav, writer: anytype) !void {
        try self.child.writeRecord(writer);
    }

    pub fn fromNode(_: anytype) common.Error!Nav {
        return error.UnsupportedComponent;
    }
};
''')

# Wire Nav into Component.zig.
path = p("ui/components/Component.zig")
s = read(path)
if 'const nav_component = @import("Nav.zig");' not in s:
    s = s.replace('const menubar_component = @import("Menubar.zig");\n', 'const menubar_component = @import("Menubar.zig");\nconst nav_component = @import("Nav.zig");\n')
if "nav: nav_component.Nav," not in s:
    s = s.replace("    navigation_menu: navigation_menu_component.NavigationMenu,\n", "    navigation_menu: navigation_menu_component.NavigationMenu,\n    nav: nav_component.Nav,\n")
write(path, s)

PY

zig fmt \
  edgerun-zig/src/app_navigation.zig \
  edgerun-zig/src/app_chrome.zig \
  edgerun-zig/src/app_blog.zig \
  edgerun-zig/src/app_docs.zig \
  edgerun-zig/src/app_landing.zig \
  edgerun-zig/src/app_source.zig \
  edgerun-zig/src/ui.zig \
  edgerun-zig/src/ui_node.zig \
  edgerun-zig/src/ui/components/Nav.zig \
  edgerun-zig/src/ui/components/Component.zig

echo "Patched. Running build..."
make pages-release
