const bounded = @import("../bounded.zig");
const geometry = @import("geometry.zig");

pub const Color = packed struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,

    pub const clear = Color{ .r = 0, .g = 0, .b = 0, .a = 0 };
    pub const bg = Color{ .r = 10, .g = 14, .b = 20 };
    pub const panel = Color{ .r = 24, .g = 31, .b = 42 };
    pub const row = Color{ .r = 35, .g = 44, .b = 58 };
    pub const border = Color{ .r = 80, .g = 96, .b = 118 };
    pub const text = Color{ .r = 232, .g = 238, .b = 247 };
    pub const muted = Color{ .r = 148, .g = 163, .b = 184 };
    pub const accent = Color{ .r = 34, .g = 211, .b = 238 };
};

pub const Rect = geometry.Rect;

pub const Node = @import("node.zig").Node;

pub fn accordionNode(id: u32, title: []const u8, detail: []const u8, open: bool) Node {
    return .{ .accordion = .{ .id = id, .title = title, .detail = detail, .open = open } };
}
pub fn alertNode(title: []const u8, detail: []const u8, destructive: bool, icon: u16) Node {
    return .{ .alert = .{ .title = title, .detail = detail, .destructive = destructive, .icon = icon } };
}
pub fn alertDialogNode(id: u32, title: []const u8, detail: []const u8) Node {
    return .{ .alert_dialog = .{ .id = id, .title = title, .detail = detail } };
}
pub fn aspectRatioNode(ratio_w: u16, ratio_h: u16) Node {
    return .{ .aspect_ratio = .{ .ratio_w = ratio_w, .ratio_h = ratio_h } };
}
pub fn avatarNode(label: []const u8) Node {
    return .{ .avatar = .{ .label = label } };
}
pub fn badgeVariantNode(label: []const u8, variant: u16) Node {
    return .{ .badge = .{ .label = label, .variant = variant } };
}
pub fn breadcrumbNode(id: u32, first: []const u8, current: []const u8) Node {
    return .{ .breadcrumb = .{ .id = id, .first = first, .current = current } };
}
pub fn buttonDetailNode(id: u32, label: []const u8, variant: u16, leading_icon: u16, trailing_icon: u16) Node {
    return .{ .button = .{ .id = id, .label = label, .variant = variant, .leading_icon = leading_icon, .trailing_icon = trailing_icon } };
}
pub fn buttonGroupNode(id: u32, first: []const u8, second: []const u8, active: u16) Node {
    return .{ .button_group = .{ .id = id, .first = first, .second = second, .active = active } };
}
pub fn calendarNode(id: u32, month: []const u8, selected_day: u16) Node {
    return .{ .calendar = .{ .id = id, .month = month, .selected_day = selected_day } };
}
pub fn cardVariantNode(title: []const u8, detail: []const u8, variant: u16) Node {
    return .{ .card = .{ .title = title, .detail = detail, .variant = variant } };
}
pub fn carouselNode(id: u32, label: []const u8) Node {
    return .{ .carousel = .{ .id = id, .label = label } };
}
pub fn chartNode(id: u32, label: []const u8) Node {
    return .{ .chart = .{ .id = id, .label = label } };
}
pub fn checkboxNode(id: u32, label: []const u8, checked: bool) Node {
    return .{ .checkbox = .{ .id = id, .label = label, .checked = checked } };
}
pub fn comboboxNode(id: u32, placeholder: []const u8, selected: []const u8) Node {
    return .{ .combobox = .{ .id = id, .placeholder = placeholder, .selected = selected } };
}
pub fn commandNode(id: u32, placeholder: []const u8, leading_icon: u16) Node {
    return .{ .command = .{ .id = id, .placeholder = placeholder, .leading_icon = leading_icon } };
}
pub fn contextMenuNode(id: u32, first: []const u8, second: []const u8) Node {
    return .{ .context_menu = .{ .id = id, .first = first, .second = second } };
}
pub fn dialogNode(id: u32, title: []const u8, detail: []const u8) Node {
    return .{ .dialog = .{ .id = id, .title = title, .detail = detail } };
}
pub fn directionNode(id: u32, active: u16) Node {
    return .{ .direction = .{ .id = id, .active = active } };
}
pub fn drawerNode(id: u32, title: []const u8, detail: []const u8) Node {
    return .{ .drawer = .{ .id = id, .title = title, .detail = detail } };
}
pub fn dropdownMenuNode(id: u32, first: []const u8, second: []const u8) Node {
    return .{ .dropdown_menu = .{ .id = id, .first = first, .second = second } };
}
pub fn emptyNode(title: []const u8, detail: []const u8, icon: u16) Node {
    return .{ .empty = .{ .title = title, .detail = detail, .icon = icon } };
}
pub fn fieldNode(id: u32, label: []const u8, placeholder: []const u8) Node {
    return .{ .field = .{ .id = id, .label = label, .placeholder = placeholder } };
}
pub fn hoverCardNode(id: u32, trigger: []const u8, content: []const u8) Node {
    return .{ .hover_card = .{ .id = id, .trigger = trigger, .content = content } };
}
pub fn iconButtonNode(id: u32, label: []const u8, icon: u16, variant: u16) Node {
    return .{ .icon_button = .{ .id = id, .label = label, .icon = icon, .variant = variant } };
}
pub fn iconNode(label: []const u8, icon_tag: u16) Node {
    return .{ .icon = .{ .label = label, .icon = icon_tag } };
}
pub fn inputDetailNode(id: u32, placeholder: []const u8, leading_icon: u16) Node {
    return .{ .input = .{ .id = id, .placeholder = placeholder, .leading_icon = leading_icon } };
}
pub fn inputGroupNode(id: u32, addon: []const u8, placeholder: []const u8) Node {
    return .{ .input_group = .{ .id = id, .addon = addon, .placeholder = placeholder } };
}
pub fn inputNode(id: u32, placeholder: []const u8) Node {
    return .{ .input = .{ .id = id, .placeholder = placeholder } };
}
pub fn inputOtpNode(id: u32, value: []const u8) Node {
    return .{ .input_otp = .{ .id = id, .value = value } };
}
pub fn kbdNode(label: []const u8) Node {
    return .{ .kbd = .{ .label = label } };
}
pub fn labelNode(value: []const u8) Node {
    return .{ .label = .{ .value = value } };
}
pub fn menubarNode(id: u32, first: []const u8, second: []const u8, active: u16) Node {
    return .{ .menubar = .{ .id = id, .first = first, .second = second, .active = active } };
}
pub fn navigationMenuNode(id: u32, first: []const u8, second: []const u8, active: u16) Node {
    return .{ .navigation_menu = .{ .id = id, .first = first, .second = second, .active = active } };
}
pub fn paginationNode(id: u32, page: u16) Node {
    return .{ .pagination = .{ .id = id, .page = page } };
}
pub fn popoverNode(id: u32, trigger: []const u8, content: []const u8) Node {
    return .{ .popover = .{ .id = id, .trigger = trigger, .content = content } };
}
pub fn progressNode(value: f32) Node {
    return .{ .progress = .{ .value = value } };
}
pub fn radioGroupNode(id: u32, first: []const u8, second: []const u8, selected: u16) Node {
    return .{ .radio_group = .{ .id = id, .first = first, .second = second, .selected = selected } };
}
pub fn resizableNode(id: u32, ratio: f32) Node {
    return .{ .resizable = .{ .id = id, .ratio = ratio } };
}
pub fn scrollAreaNode() Node {
    return .{ .scroll_area = {} };
}
pub fn selectNode(id: u32, label: []const u8, trailing_icon: u16) Node {
    return .{ .select = .{ .id = id, .label = label, .trailing_icon = trailing_icon } };
}
pub fn separatorNode() Node {
    return .{ .separator = {} };
}
pub fn sheetNode(id: u32, title: []const u8, detail: []const u8) Node {
    return .{ .sheet = .{ .id = id, .title = title, .detail = detail } };
}
pub fn sidebarNode(id: u32, title: []const u8, item: []const u8) Node {
    return .{ .sidebar = .{ .id = id, .title = title, .item = item } };
}
pub fn skeletonNode() Node {
    return .{ .skeleton = {} };
}
pub fn sliderNode(id: u32, label: []const u8, value: f32) Node {
    return .{ .slider = .{ .id = id, .label = label, .value = value } };
}
pub fn spinnerNode() Node {
    return .{ .spinner = {} };
}
pub fn switchNode(id: u32, label: []const u8, checked: bool) Node {
    return .{ .switch_control = .{ .id = id, .label = label, .checked = checked } };
}
pub fn tableNode(id: u32, name: []const u8, role: []const u8) Node {
    return .{ .table = .{ .id = id, .name = name, .role = role } };
}
pub fn tabsNode(id: u32, first: []const u8, second: []const u8, active: u16) Node {
    return .{ .tabs = .{ .id = id, .first = first, .second = second, .active = active } };
}
pub fn textNode(value: []const u8, color: ?Color) Node {
    return .{ .text = .{ .value = value, .color = color } };
}
pub fn textareaNode(id: u32, placeholder: []const u8) Node {
    return .{ .textarea = .{ .id = id, .placeholder = placeholder } };
}
pub fn toastNode(id: u32, title: []const u8, detail: []const u8) Node {
    return .{ .toast = .{ .id = id, .title = title, .detail = detail } };
}
pub fn toggleNode(id: u32, label: []const u8, pressed: bool) Node {
    return .{ .toggle = .{ .id = id, .label = label, .pressed = pressed } };
}
pub fn toggleGroupNode(id: u32, first: []const u8, second: []const u8, active: u16) Node {
    return .{ .toggle_group = .{ .id = id, .first = first, .second = second, .active = active } };
}
pub fn tooltipNode(id: u32, trigger: []const u8, content: []const u8) Node {
    return .{ .tooltip = .{ .id = id, .trigger = trigger, .content = content } };
}
pub fn columnStack(gap: f32, padding: f32, children: []const Node) Node {
    return .{ .stack = .{ .axis = .column, .gap = gap, .padding = padding, .children = children } };
}

pub const Patch = union(enum) {
    text_value: []const u8,
    accordion_open: bool,
    alert: struct { title: []const u8, detail: []const u8, destructive: bool },
    alert_dialog: struct { title: []const u8, detail: []const u8 },
    calendar_selected_day: u16,
    carousel_label: []const u8,
    chart_label: []const u8,
    combobox_selected: []const u8,
    card_text: struct { title: []const u8, detail: []const u8 },
    empty_text: struct { title: []const u8, detail: []const u8 },
    badge_label: []const u8,
    avatar_label: []const u8,
    kbd_label: []const u8,
    label_value: []const u8,
    breadcrumb_current: []const u8,
    menubar_active: u16,
    navigation_menu_active: u16,
    command_placeholder: []const u8,
    context_menu: struct { first: []const u8, second: []const u8 },
    dialog: struct { title: []const u8, detail: []const u8 },
    direction_active: u16,
    drawer: struct { title: []const u8, detail: []const u8 },
    dropdown_menu: struct { first: []const u8, second: []const u8 },
    field_placeholder: []const u8,
    hover_card_content: []const u8,
    input_otp_value: []const u8,
    button_label: []const u8,
    button_group_active: u16,
    toggle_group_active: u16,
    toggle_pressed: bool,
    input_placeholder: []const u8,
    input_group_placeholder: []const u8,
    textarea_placeholder: []const u8,
    select_label: []const u8,
    checkbox_checked: bool,
    radio_selected: u16,
    switch_checked: bool,
    pagination_page: u16,
    popover_content: []const u8,
    resizable_ratio: f32,
    sheet: struct { title: []const u8, detail: []const u8 },
    sidebar_item: []const u8,
    progress_value: f32,
    slider_value: f32,
    tabs_active: u16,
    table_row: struct { name: []const u8, role: []const u8 },
    tooltip_content: []const u8,
    toast: struct { title: []const u8, detail: []const u8 },
    row_item: struct { title: []const u8, detail: []const u8, icon: u16 = 0 },
    rect_color: Color,
    style_color: Color,
};

pub fn render(scene: *Scene, root: Node, bounds: Rect, style: Style) RenderError!void {
    switch (root) {
        .rect => |r| try scene.pushRect(bounds, r.color, .fill, 0.0, 0.0),
        .text => |t| try scene.pushText(bounds, t.value, t.color orelse style.text),
        .slot => |s| try render(scene, s.child.*, bounds, style),
        .stack => |s| {
            const gap = s.gap;
            const pad = s.padding;
            var offset: f32 = 0.0;
            for (s.children) |child| {
                const pref = child.preferredSize();
                const child_bounds = switch (s.axis) {
                    .column => Rect.init(bounds.x + pad, bounds.y + pad + offset, bounds.w - 2.0 * pad, pref.h),
                    .row => Rect.init(bounds.x + pad + offset, bounds.y + pad, pref.w, bounds.h - 2.0 * pad),
                };
                if (child_bounds.valid()) try render(scene, child, child_bounds, style);
                offset += switch (s.axis) {
                    .column => pref.h,
                    .row => pref.w,
                } + gap;
            }
        },
        .separator, .scroll_area, .skeleton, .spinner => {},
        else => return error.UnsupportedComponent,
    }
}

pub fn applyPatch(node: *Node, patch: Patch) RenderError!void {
    switch (patch) {
        .text_value => |v| {
            if (node.* != .text) return error.UnsupportedComponent;
            node.text.value = v;
        },
        .accordion_open => |v| {
            if (node.* != .accordion) return error.UnsupportedComponent;
            node.accordion.open = v;
        },
        .alert => |v| {
            if (node.* != .alert) return error.UnsupportedComponent;
            node.alert.title = v.title;
            node.alert.detail = v.detail;
            node.alert.destructive = v.destructive;
        },
        .alert_dialog => |v| {
            if (node.* != .alert_dialog) return error.UnsupportedComponent;
            node.alert_dialog.title = v.title;
            node.alert_dialog.detail = v.detail;
        },
        .calendar_selected_day => |v| {
            if (node.* != .calendar) return error.UnsupportedComponent;
            node.calendar.selected_day = v;
        },
        .carousel_label => |v| {
            if (node.* != .carousel) return error.UnsupportedComponent;
            node.carousel.label = v;
        },
        .chart_label => |v| {
            if (node.* != .chart) return error.UnsupportedComponent;
            node.chart.label = v;
        },
        .combobox_selected => |v| {
            if (node.* != .combobox) return error.UnsupportedComponent;
            node.combobox.selected = v;
        },
        .card_text => |v| {
            if (node.* != .card) return error.UnsupportedComponent;
            node.card.title = v.title;
            node.card.detail = v.detail;
        },
        .empty_text => |v| {
            if (node.* != .empty) return error.UnsupportedComponent;
            node.empty.title = v.title;
            node.empty.detail = v.detail;
        },
        .badge_label => |v| {
            if (node.* != .badge) return error.UnsupportedComponent;
            node.badge.label = v;
        },
        .avatar_label => |v| {
            if (node.* != .avatar) return error.UnsupportedComponent;
            node.avatar.label = v;
        },
        .kbd_label => |v| {
            if (node.* != .kbd) return error.UnsupportedComponent;
            node.kbd.label = v;
        },
        .label_value => |v| {
            if (node.* != .label) return error.UnsupportedComponent;
            node.label.value = v;
        },
        .breadcrumb_current => |v| {
            if (node.* != .breadcrumb) return error.UnsupportedComponent;
            node.breadcrumb.current = v;
        },
        .menubar_active => |v| {
            if (node.* != .menubar) return error.UnsupportedComponent;
            node.menubar.active = v;
        },
        .navigation_menu_active => |v| {
            if (node.* != .navigation_menu) return error.UnsupportedComponent;
            node.navigation_menu.active = v;
        },
        .command_placeholder => |v| {
            if (node.* != .command) return error.UnsupportedComponent;
            node.command.placeholder = v;
        },
        .context_menu => |v| {
            if (node.* != .context_menu) return error.UnsupportedComponent;
            node.context_menu.first = v.first;
            node.context_menu.second = v.second;
        },
        .dialog => |v| {
            if (node.* != .dialog) return error.UnsupportedComponent;
            node.dialog.title = v.title;
            node.dialog.detail = v.detail;
        },
        .direction_active => |v| {
            if (node.* != .direction) return error.UnsupportedComponent;
            node.direction.active = v;
        },
        .drawer => |v| {
            if (node.* != .drawer) return error.UnsupportedComponent;
            node.drawer.title = v.title;
            node.drawer.detail = v.detail;
        },
        .dropdown_menu => |v| {
            if (node.* != .dropdown_menu) return error.UnsupportedComponent;
            node.dropdown_menu.first = v.first;
            node.dropdown_menu.second = v.second;
        },
        .field_placeholder => |v| {
            if (node.* != .field) return error.UnsupportedComponent;
            node.field.placeholder = v;
        },
        .hover_card_content => |v| {
            if (node.* != .hover_card) return error.UnsupportedComponent;
            node.hover_card.content = v;
        },
        .input_otp_value => |v| {
            if (node.* != .input_otp) return error.UnsupportedComponent;
            node.input_otp.value = v;
        },
        .button_label => |v| {
            if (node.* != .button) return error.UnsupportedComponent;
            node.button.label = v;
        },
        .button_group_active => |v| {
            if (node.* != .button_group) return error.UnsupportedComponent;
            node.button_group.active = v;
        },
        .toggle_group_active => |v| {
            if (node.* != .toggle_group) return error.UnsupportedComponent;
            node.toggle_group.active = v;
        },
        .toggle_pressed => |v| {
            if (node.* != .toggle) return error.UnsupportedComponent;
            node.toggle.pressed = v;
        },
        .input_placeholder => |v| {
            if (node.* != .input) return error.UnsupportedComponent;
            node.input.placeholder = v;
        },
        .input_group_placeholder => |v| {
            if (node.* != .input_group) return error.UnsupportedComponent;
            node.input_group.placeholder = v;
        },
        .textarea_placeholder => |v| {
            if (node.* != .textarea) return error.UnsupportedComponent;
            node.textarea.placeholder = v;
        },
        .select_label => |v| {
            if (node.* != .select) return error.UnsupportedComponent;
            node.select.label = v;
        },
        .checkbox_checked => |v| {
            if (node.* != .checkbox) return error.UnsupportedComponent;
            node.checkbox.checked = v;
        },
        .radio_selected => |v| {
            if (node.* != .radio_group) return error.UnsupportedComponent;
            node.radio_group.selected = v;
        },
        .switch_checked => |v| {
            if (node.* != .switch_control) return error.UnsupportedComponent;
            node.switch_control.checked = v;
        },
        .pagination_page => |v| {
            if (node.* != .pagination) return error.UnsupportedComponent;
            node.pagination.page = v;
        },
        .popover_content => |v| {
            if (node.* != .popover) return error.UnsupportedComponent;
            node.popover.content = v;
        },
        .resizable_ratio => |v| {
            if (node.* != .resizable) return error.UnsupportedComponent;
            node.resizable.ratio = v;
        },
        .sheet => |v| {
            if (node.* != .sheet) return error.UnsupportedComponent;
            node.sheet.title = v.title;
            node.sheet.detail = v.detail;
        },
        .sidebar_item => |v| {
            if (node.* != .sidebar) return error.UnsupportedComponent;
            node.sidebar.item = v;
        },
        .progress_value => |v| {
            if (node.* != .progress) return error.UnsupportedComponent;
            node.progress.value = v;
        },
        .slider_value => |v| {
            if (node.* != .slider) return error.UnsupportedComponent;
            node.slider.value = v;
        },
        .tabs_active => |v| {
            if (node.* != .tabs) return error.UnsupportedComponent;
            node.tabs.active = v;
        },
        .table_row => |v| {
            if (node.* != .table) return error.UnsupportedComponent;
            node.table.name = v.name;
            node.table.role = v.role;
        },
        .tooltip_content => |v| {
            if (node.* != .tooltip) return error.UnsupportedComponent;
            node.tooltip.content = v;
        },
        .toast => |v| {
            if (node.* != .toast) return error.UnsupportedComponent;
            node.toast.title = v.title;
            node.toast.detail = v.detail;
        },
        .row_item => |v| {
            if (node.* != .row_item) return error.UnsupportedComponent;
            node.row_item.title = v.title;
            node.row_item.detail = v.detail;
            node.row_item.icon = v.icon;
        },
        .rect_color => |v| {
            if (node.* != .rect) return error.UnsupportedComponent;
            node.rect.color = v;
        },
        .style_color => {},
    }
}

pub fn clampUnit(value: f32) f32 {
    return geometry.clamp(value, 0.0, 1.0);
}

pub fn encodeUnit(value: f32) u16 {
    return @intFromFloat(@round(clampUnit(value) * 65535.0));
}

pub fn decodeUnit(value: u16) f32 {
    return @as(f32, @floatFromInt(value)) / 65535.0;
}

pub const Size = struct { w: f32, h: f32 };
pub const Axis = enum { row, column };
pub const Align = enum { start, center, end, stretch };

pub const Layout = struct {
    axis: Axis = .column,
    gap: f32 = 0.0,
    padding: f32 = 0.0,
    cross_align: Align = .stretch,
    children: []const Node = &.{},
};

pub const LinearCursor = struct {
    bounds: Rect,
    axis: Axis,
    gap: f32,
    offset: f32 = 0.0,

    pub fn init(bounds: Rect, axis: Axis, gap: f32) LinearCursor {
        return .{ .bounds = bounds, .axis = axis, .gap = @max(0.0, gap) };
    }

    pub fn take(self: *LinearCursor, main_size: f32) Rect {
        const size = @max(0.0, main_size);
        const out = switch (self.axis) {
            .row => Rect.init(self.bounds.x + self.offset, self.bounds.y, size, self.bounds.h),
            .column => Rect.init(self.bounds.x, self.bounds.y + self.offset, self.bounds.w, size),
        };
        self.offset += size + self.gap;
        return out;
    }

    pub fn skip(self: *LinearCursor, main_size: f32) void {
        self.offset += @max(0.0, main_size) + self.gap;
    }

    pub fn remaining(self: LinearCursor) Rect {
        return switch (self.axis) {
            .row => Rect.init(self.bounds.x + self.offset, self.bounds.y, @max(0.0, self.bounds.w - self.offset), self.bounds.h),
            .column => Rect.init(self.bounds.x, self.bounds.y + self.offset, self.bounds.w, @max(0.0, self.bounds.h - self.offset)),
        };
    }
};

pub const Style = struct {
    bg: Color = .bg,
    panel: Color = .panel,
    row: Color = .row,
    border: Color = .border,
    text: Color = .text,
    muted: Color = .muted,
    accent: Color = .accent,
};

pub const HitKind = enum(u8) { button, input, row_item, checkbox, switch_control, slider, textarea, select, overlay_trigger };
pub const RectMode = enum(u8) { fill, shadow, border, linear_gradient, pie_slice };
pub const TextAlign = enum(u8) { start, center, end };
pub const FontWeight = enum(u8) { regular = 0, semibold = 1, bold = 2 };

pub const DragSource = struct { scope_id: u32, item_id: u32, index: usize, bounds: Rect };
pub const DropTarget = struct { scope_id: u32, index: usize, bounds: Rect };

pub const Quad = struct {
    bounds: Rect,
    u0: f32 = 0.0,
    v0: f32 = 0.0,
    u1: f32 = 1.0,
    v1: f32 = 1.0,
    atlas_id: u32 = 0,
    color: Color,
};

pub const IconQuad = struct { bounds: Rect, icon_id: u32, color: Color };

/// First-class SVG quad using pre-compiled icon IR data.
/// Analogous to image quads (Quad + atlas_id), SVG quads carry an icon_id for pack lookup.
pub const SvgQuad = IconQuad;

pub const TransitionProperty = enum(u8) { opacity, translate_x, translate_y };
pub const Easing = enum(u8) { linear, ease_in, ease_out, ease_in_out };

pub const Transition = struct {
    id: u32,
    property: TransitionProperty,
    from: f32,
    to: f32,
    duration_ms: u32,
    delay_ms: u32 = 0,
    easing: Easing = .linear,

    pub fn valid(self: Transition) bool {
        return geometry.finite(self.from) and geometry.finite(self.to) and self.duration_ms > 0 and self.duration_ms <= 60000;
    }
};

pub fn transition(id: u32, property: TransitionProperty, from: f32, to: f32, duration_ms: u32, delay_ms: u32, easing: Easing) Transition {
    return .{ .id = id, .property = property, .from = from, .to = to, .duration_ms = duration_ms, .delay_ms = delay_ms, .easing = easing };
}

pub fn transitionOpacity(id: u32, from: f32, to: f32, duration_ms: u32) Transition {
    return transition(id, .opacity, from, to, duration_ms, 0, .ease_out);
}

pub fn transitionTranslateX(id: u32, from: f32, to: f32, duration_ms: u32) Transition {
    return transition(id, .translate_x, from, to, duration_ms, 0, .ease_out);
}

pub fn transitionTranslateY(id: u32, from: f32, to: f32, duration_ms: u32) Transition {
    return transition(id, .translate_y, from, to, duration_ms, 0, .ease_out);
}

pub fn easingSample(easing: Easing, value: f32) f32 {
    const clamped = geometry.clamp(value, 0.0, 1.0);
    return switch (easing) {
        .linear => clamped,
        .ease_in => clamped * clamped,
        .ease_out => 1.0 - (1.0 - clamped) * (1.0 - clamped),
        .ease_in_out => if (clamped < 0.5) 2.0 * clamped * clamped else 1.0 - (-2.0 * clamped + 2.0) * (-2.0 * clamped + 2.0) * 0.5,
    };
}

pub const Command = union(enum) {
    rect: struct { bounds: Rect, color: Color, color2: Color = .clear, mode: RectMode = .fill, radius: f32 = 0.0, shadow: f32 = 0.0 },
    overlay_rect: struct { bounds: Rect, color: Color, color2: Color = .clear, mode: RectMode = .fill, radius: f32 = 0.0, shadow: f32 = 0.0 },
    border: struct { bounds: Rect, color: Color },
    text: struct { origin: Rect, value: []const u8, color: Color, alignment: TextAlign = .start, weight: FontWeight = .regular },
    overlay_text: struct { origin: Rect, value: []const u8, color: Color, alignment: TextAlign = .start, weight: FontWeight = .regular },
    drag_source: DragSource,
    drop_target: DropTarget,
    icon_quad: IconQuad,
    overlay_icon_quad: IconQuad,
    svg_quad: SvgQuad,
    text_quad: Quad,
    image_quad: Quad,
    transition: Transition,
};

pub const TextWrap = struct {
    line_height: f32 = 22.0,
    average_char_width: f32 = 9.0,
    max_lines: usize = 8,
    weight: FontWeight = .regular,
};

pub const Cursor = struct { commands: usize = 0 };
pub const Stats = struct { rects: usize = 0, drag_sources: usize = 0, drop_targets: usize = 0, transitions: usize = 0, clips: usize = 0, icon_quads: usize = 0, svg_quads: usize = 0, text_quads: usize = 0, image_quads: usize = 0 };
pub const Budget = struct { rects: usize = 2000, drag_sources: usize = 240, drop_targets: usize = 240, transitions: usize = 1200, icon_quads: usize = 160, svg_quads: usize = 160, text_quads: usize = 900, image_quads: usize = 16 };
pub const BudgetViolation = struct { name: []const u8, actual: usize, limit: usize };
pub const RenderError = error{ CommandBudgetExceeded, InvalidBounds, ClipBudgetExceeded, UnsupportedComponent };
pub const PatchError = error{WrongNodeKind};

pub const CommandList = bounded.SliceList(Command);
pub const ClipList = bounded.SliceList(Rect);

pub const Scene = struct {
    commands: CommandList,
    clips: ClipList,

    pub fn init(commands: []Command) Scene {
        return .{ .commands = CommandList.from(commands), .clips = ClipList.from(&.{}) };
    }
    pub fn initWithClips(commands: []Command, clips: []Rect) Scene {
        return .{ .commands = CommandList.from(commands), .clips = ClipList.from(clips) };
    }
    pub fn clear(self: *Scene) void {
        self.commands.clear();
        self.clips.clear();
    }
    pub fn push(self: *Scene, command: Command) RenderError!void {
        if (!self.commands.append(command)) return error.CommandBudgetExceeded;
    }

    pub fn pushRect(self: *Scene, bounds: Rect, color: Color, mode: RectMode, radius: f32, shadow: f32) RenderError!void {
        try self.pushRectPair(bounds, color, .clear, mode, radius, shadow);
    }
    pub fn pushGradientRect(self: *Scene, bounds: Rect, top_color: Color, bottom_color: Color, radius: f32) RenderError!void {
        try self.pushRectPair(bounds, top_color, bottom_color, .linear_gradient, radius, 0.0);
    }

    pub fn pushOverlayRect(self: *Scene, bounds: Rect, color: Color, mode: RectMode, radius: f32, shadow: f32) RenderError!void {
        try self.pushOverlayRectPair(bounds, color, .clear, mode, radius, shadow);
    }

    pub fn pushOverlayGradientRect(self: *Scene, bounds: Rect, top_color: Color, bottom_color: Color, radius: f32) RenderError!void {
        try self.pushOverlayRectPair(bounds, top_color, bottom_color, .linear_gradient, radius, 0.0);
    }

    pub fn pushPieSlice(self: *Scene, bounds: Rect, color: Color, start_turn: f32, end_turn: f32) RenderError!void {
        if (!geometry.finite(start_turn) or !geometry.finite(end_turn)) return;
        if (end_turn <= start_turn) return;
        const encoded_angles = Color{ .r = unitByte(start_turn), .g = unitByte(end_turn), .b = 0, .a = 255 };
        try self.pushRectPair(bounds, color, encoded_angles, .pie_slice, 0.0, 0.0);
    }

    fn pushRectPair(self: *Scene, bounds: Rect, color: Color, color2: Color, mode: RectMode, radius: f32, shadow: f32) RenderError!void {
        const normalized = normalizePair(self.*, bounds, radius, shadow) orelse return;
        try self.push(.{ .rect = .{ .bounds = normalized.bounds, .color = color, .color2 = color2, .mode = mode, .radius = normalized.radius, .shadow = normalized.shadow } });
    }

    fn pushOverlayRectPair(self: *Scene, bounds: Rect, color: Color, color2: Color, mode: RectMode, radius: f32, shadow: f32) RenderError!void {
        const normalized = normalizePair(self.*, bounds, radius, shadow) orelse return;
        try self.push(.{ .overlay_rect = .{ .bounds = normalized.bounds, .color = color, .color2 = color2, .mode = mode, .radius = normalized.radius, .shadow = normalized.shadow } });
    }

    fn normalizePair(self: Scene, bounds: Rect, radius: f32, shadow: f32) ?struct { bounds: Rect, radius: f32, shadow: f32 } {
        var normalized_bounds = bounds;
        var normalized_radius = radius;
        var normalized_shadow = shadow;
        if (!normalizeRect(&normalized_bounds, &normalized_radius, &normalized_shadow)) return null;
        if (self.clipRect(normalized_bounds)) |clipped| {
            normalized_bounds = clipped;
            normalized_radius = @min(normalized_radius, @min(clipped.w * 0.5, clipped.h * 0.5));
        } else return null;
        return .{ .bounds = normalized_bounds, .radius = normalized_radius, .shadow = normalized_shadow };
    }

    pub fn pushDragSource(self: *Scene, source: DragSource) RenderError!void {
        if (self.clipRect(source.bounds)) |clipped| try self.push(.{ .drag_source = .{ .scope_id = source.scope_id, .item_id = source.item_id, .index = source.index, .bounds = clipped } });
    }

    pub fn pushDropTarget(self: *Scene, target: DropTarget) RenderError!void {
        if (self.clipRect(target.bounds)) |clipped| try self.push(.{ .drop_target = .{ .scope_id = target.scope_id, .index = target.index, .bounds = clipped } });
    }

    pub fn pushTransition(self: *Scene, value: Transition) RenderError!void {
        if (!value.valid()) return;
        try self.push(.{ .transition = value });
    }

    pub fn pushIconQuad(self: *Scene, quad: IconQuad) RenderError!void {
        if (quad.icon_id == 0) return;
        if (self.clipRect(quad.bounds)) |clipped| try self.push(.{ .icon_quad = .{ .bounds = clipped, .icon_id = quad.icon_id, .color = quad.color } });
    }

    pub fn pushOverlayIconQuad(self: *Scene, quad: IconQuad) RenderError!void {
        if (quad.icon_id == 0) return;
        if (self.clipRect(quad.bounds)) |clipped| try self.push(.{ .overlay_icon_quad = .{ .bounds = clipped, .icon_id = quad.icon_id, .color = quad.color } });
    }

    pub fn pushSvgQuad(self: *Scene, quad: SvgQuad) RenderError!void {
        try self.pushIconQuad(quad);
    }

    pub fn pushTextQuad(self: *Scene, quad: Quad) RenderError!void {
        if (self.clipQuad(quad)) |clipped| try self.push(.{ .text_quad = clipped });
    }
    pub fn pushImageQuad(self: *Scene, quad: Quad) RenderError!void {
        if (self.clipQuad(quad)) |clipped| try self.push(.{ .image_quad = clipped });
    }

    pub fn pushText(self: *Scene, origin: Rect, value: []const u8, color: Color) RenderError!void {
        try self.pushAlignedText(origin, value, color, .start);
    }
    pub fn pushStrongText(self: *Scene, origin: Rect, value: []const u8, color: Color) RenderError!void {
        try self.pushAlignedTextWeight(origin, value, color, .start, .semibold);
    }
    pub fn pushBoldText(self: *Scene, origin: Rect, value: []const u8, color: Color) RenderError!void {
        try self.pushAlignedTextWeight(origin, value, color, .start, .bold);
    }
    pub fn pushOverlayText(self: *Scene, origin: Rect, value: []const u8, color: Color) RenderError!void {
        try self.pushAlignedOverlayTextWeight(origin, value, color, .start, .regular);
    }
    pub fn pushOverlayStrongText(self: *Scene, origin: Rect, value: []const u8, color: Color) RenderError!void {
        try self.pushAlignedOverlayTextWeight(origin, value, color, .start, .semibold);
    }
    pub fn pushOverlayBoldText(self: *Scene, origin: Rect, value: []const u8, color: Color) RenderError!void {
        try self.pushAlignedOverlayTextWeight(origin, value, color, .start, .bold);
    }
    pub fn pushAlignedText(self: *Scene, origin: Rect, value: []const u8, color: Color, alignment: TextAlign) RenderError!void {
        try self.pushAlignedTextWeight(origin, value, color, alignment, .regular);
    }

    pub fn pushAlignedTextWeight(self: *Scene, origin: Rect, value: []const u8, color: Color, alignment: TextAlign, weight: FontWeight) RenderError!void {
        if (value.len == 0) return;
        if (self.clipRect(origin)) |clipped| try self.push(.{ .text = .{ .origin = clipped, .value = value, .color = color, .alignment = alignment, .weight = weight } });
    }

    pub fn pushAlignedOverlayTextWeight(self: *Scene, origin: Rect, value: []const u8, color: Color, alignment: TextAlign, weight: FontWeight) RenderError!void {
        if (value.len == 0) return;
        if (self.clipRect(origin)) |clipped| try self.push(.{ .overlay_text = .{ .origin = clipped, .value = value, .color = color, .alignment = alignment, .weight = weight } });
    }

    pub fn pushWrappedText(self: *Scene, bounds: Rect, value: []const u8, color: Color, wrap: TextWrap) RenderError!void {
        if (value.len == 0 or !bounds.valid() or wrap.max_lines == 0) return;
        if (!geometry.finite(wrap.line_height) or !geometry.finite(wrap.average_char_width)) return;
        if (wrap.line_height <= 0.0 or wrap.average_char_width <= 0.0) return;
        const max_lines_by_height = @max(@as(usize, 1), @as(usize, @intFromFloat(@max(1.0, bounds.h / wrap.line_height))));
        const max_lines = @min(wrap.max_lines, max_lines_by_height);
        const char_capacity = @max(@as(usize, 1), @as(usize, @intFromFloat(@max(1.0, bounds.w / wrap.average_char_width))));
        var byte_cursor: usize = 0;
        var line_index: usize = 0;
        while (line_index < max_lines) : (line_index += 1) {
            byte_cursor = skipAsciiSpace(value, byte_cursor);
            if (byte_cursor >= value.len) break;
            const split = wrappedLine(value, byte_cursor, char_capacity);
            if (split.end > split.start) try self.pushAlignedTextWeight(.{ .x = bounds.x, .y = bounds.y + @as(f32, @floatFromInt(line_index)) * wrap.line_height, .w = bounds.w, .h = wrap.line_height }, value[split.start..split.end], color, .start, wrap.weight);
            byte_cursor = split.next;
        }
    }

    pub fn pushClip(self: *Scene, clip: Rect) RenderError!bool {
        if (!clip.valid()) return false;
        const next = if (self.currentClip()) |current| current.intersect(clip) orelse return false else clip;
        if (!self.clips.append(next)) return error.ClipBudgetExceeded;
        return true;
    }

    pub fn popClip(self: *Scene) void {
        _ = self.clips.pop();
    }
    pub fn cursor(self: Scene) Cursor {
        return .{ .commands = self.commands.len };
    }

    pub fn stats(self: Scene) Stats {
        var out = Stats{ .clips = self.clips.len };
        for (self.written()) |command| switch (command) {
            .rect, .overlay_rect, .border => out.rects += 1,
            .drag_source => out.drag_sources += 1,
            .drop_target => out.drop_targets += 1,
            .transition => out.transitions += 1,
            .icon_quad, .overlay_icon_quad => out.icon_quads += 1,
            .svg_quad => out.svg_quads += 1,
            .text_quad, .text, .overlay_text => out.text_quads += 1,
            .image_quad => out.image_quads += 1,
        };
        return out;
    }

    pub fn applyOpacitySince(self: *Scene, mark: Cursor, opacity: f32) void {
        const alpha = geometry.clamp(opacity, 0.0, 1.0);
        for (self.commands.mutableSlice()[mark.commands..]) |*command| switch (command.*) {
            .rect => |*rect_cmd| rect_cmd.color.a = scaleAlpha(rect_cmd.color.a, alpha),
            .overlay_rect => |*rect_cmd| rect_cmd.color.a = scaleAlpha(rect_cmd.color.a, alpha),
            .border => |*border| border.color.a = scaleAlpha(border.color.a, alpha),
            .text => |*text_cmd| text_cmd.color.a = scaleAlpha(text_cmd.color.a, alpha),
            .overlay_text => |*text_cmd| text_cmd.color.a = scaleAlpha(text_cmd.color.a, alpha),
            .icon_quad, .overlay_icon_quad => |*quad| quad.color.a = scaleAlpha(quad.color.a, alpha),
            .svg_quad => |*quad| quad.color.a = scaleAlpha(quad.color.a, alpha),
            .text_quad => |*quad| quad.color.a = scaleAlpha(quad.color.a, alpha),
            .image_quad => |*quad| quad.color.a = scaleAlpha(quad.color.a, alpha),
            else => {},
        };
    }

    pub fn translateSince(self: *Scene, mark: Cursor, dx: f32, dy: f32) void {
        if (!geometry.finite(dx) or !geometry.finite(dy)) return;
        for (self.commands.mutableSlice()[mark.commands..]) |*command| switch (command.*) {
            .rect => |*rect_cmd| translateRect(&rect_cmd.bounds, dx, dy),
            .overlay_rect => |*rect_cmd| translateRect(&rect_cmd.bounds, dx, dy),
            .border => |*border| translateRect(&border.bounds, dx, dy),
            .text => |*text_cmd| translateRect(&text_cmd.origin, dx, dy),
            .overlay_text => |*text_cmd| translateRect(&text_cmd.origin, dx, dy),
            .drag_source => |*source| translateRect(&source.bounds, dx, dy),
            .drop_target => |*target| translateRect(&target.bounds, dx, dy),
            .icon_quad, .overlay_icon_quad => |*quad| translateRect(&quad.bounds, dx, dy),
            .svg_quad => |*quad| translateRect(&quad.bounds, dx, dy),
            .text_quad => |*quad| translateRect(&quad.bounds, dx, dy),
            .image_quad => |*quad| translateRect(&quad.bounds, dx, dy),
            else => {},
        };
    }

    pub fn promoteSinceToOverlay(self: *Scene, mark: Cursor) void {
        for (self.commands.mutableSlice()[mark.commands..]) |*command| {
            command.* = switch (command.*) {
                .rect => |rect| .{ .overlay_rect = .{ .bounds = rect.bounds, .color = rect.color, .color2 = rect.color2, .mode = rect.mode, .radius = rect.radius, .shadow = rect.shadow } },
                .text => |text| .{ .overlay_text = .{ .origin = text.origin, .value = text.value, .color = text.color, .alignment = text.alignment, .weight = text.weight } },
                .icon_quad => |quad| .{ .overlay_icon_quad = .{ .bounds = quad.bounds, .icon_id = quad.icon_id, .color = quad.color } },
                else => command.*,
            };
        }
    }

    fn currentClip(self: Scene) ?Rect {
        if (self.clips.len == 0) return null;
        return self.clips.items[self.clips.len - 1];
    }
    fn clipRect(self: Scene, bounds: Rect) ?Rect {
        if (!bounds.valid()) return null;
        return if (self.currentClip()) |clip| bounds.intersect(clip) else bounds;
    }

    fn clipQuad(self: Scene, quad: Quad) ?Quad {
        const clipped_bounds = self.clipRect(quad.bounds) orelse return null;
        const x0 = quad.bounds.x;
        const y0 = quad.bounds.y;
        const x1 = quad.bounds.x + quad.bounds.w;
        const y1 = quad.bounds.y + quad.bounds.h;
        const u_span = quad.u1 - quad.u0;
        const v_span = quad.v1 - quad.v0;
        const left = geometry.clamp((clipped_bounds.x - x0) / (x1 - x0), 0.0, 1.0);
        const top = geometry.clamp((clipped_bounds.y - y0) / (y1 - y0), 0.0, 1.0);
        const right = geometry.clamp((clipped_bounds.x + clipped_bounds.w - x0) / (x1 - x0), 0.0, 1.0);
        const bottom = geometry.clamp((clipped_bounds.y + clipped_bounds.h - y0) / (y1 - y0), 0.0, 1.0);
        return .{ .bounds = clipped_bounds, .u0 = quad.u0 + u_span * left, .v0 = quad.v0 + v_span * top, .u1 = quad.u0 + u_span * right, .v1 = quad.v0 + v_span * bottom, .atlas_id = quad.atlas_id, .color = quad.color };
    }

    pub fn written(self: Scene) []const Command {
        return self.commands.slice();
    }
    pub fn commandCount(self: Scene) usize {
        return self.commands.len;
    }
    pub fn commandAt(self: Scene, index: usize) ?Command {
        return self.commands.at(index);
    }
};

pub fn frameBudget() Budget {
    return .{};
}

pub fn firstBudgetViolation(stats_value: Stats, budget: Budget) ?BudgetViolation {
    const entries = [_]BudgetViolation{
        .{ .name = "rects", .actual = stats_value.rects, .limit = budget.rects },
        .{ .name = "drag_sources", .actual = stats_value.drag_sources, .limit = budget.drag_sources },
        .{ .name = "drop_targets", .actual = stats_value.drop_targets, .limit = budget.drop_targets },
        .{ .name = "transitions", .actual = stats_value.transitions, .limit = budget.transitions },
        .{ .name = "icon_quads", .actual = stats_value.icon_quads, .limit = budget.icon_quads },
        .{ .name = "svg_quads", .actual = stats_value.svg_quads, .limit = budget.svg_quads },
        .{ .name = "text_quads", .actual = stats_value.text_quads, .limit = budget.text_quads },
        .{ .name = "image_quads", .actual = stats_value.image_quads, .limit = budget.image_quads },
    };
    for (entries) |entry| if (entry.actual > entry.limit) return entry;
    return null;
}

pub fn statsFitBudget(stats_value: Stats, budget: Budget) bool {
    return firstBudgetViolation(stats_value, budget) == null;
}

fn normalizeRect(bounds: *Rect, radius: *f32, shadow: *f32) bool {
    if (!bounds.valid() or !geometry.finite(radius.*) or !geometry.finite(shadow.*)) return false;
    radius.* = geometry.clamp(radius.*, 0.0, @min(bounds.w * 0.5, bounds.h * 0.5));
    shadow.* = geometry.max(shadow.*, 0.0);
    return true;
}

fn translateRect(bounds: *Rect, dx: f32, dy: f32) void {
    bounds.x += dx;
    bounds.y += dy;
}
fn scaleAlpha(alpha: u8, factor: f32) u8 {
    return @intFromFloat(@round(@as(f32, @floatFromInt(alpha)) * factor));
}

fn unitByte(value: f32) u8 {
    return @intFromFloat(@round(geometry.clamp(value, 0.0, 1.0) * 255.0));
}

pub fn skipAsciiSpace(value: []const u8, start: usize) usize {
    var index = start;
    while (index < value.len and value[index] == ' ') : (index += 1) {}
    return index;
}

pub const WrappedLine = struct { start: usize, end: usize, next: usize };

pub fn wrappedLine(value: []const u8, start: usize, char_capacity: usize) WrappedLine {
    var index = start;
    var chars: usize = 0;
    var last_space: ?usize = null;
    while (index < value.len and value[index] != '\n' and chars < char_capacity) : (index += 1) {
        if (value[index] == ' ') last_space = index;
        chars += 1;
    }
    if (index >= value.len or value[index] == '\n') return .{ .start = start, .end = index, .next = @min(value.len, index + 1) };
    if (last_space) |space| return .{ .start = start, .end = space, .next = space + 1 };
    return .{ .start = start, .end = index, .next = index };
}

pub fn utf8CodepointCount(value: []const u8) usize {
    var count: usize = 0;
    var index: usize = 0;
    while (index < value.len) : (count += 1) {
        const len = utf8ByteSequenceLength(value[index]) orelse 1;
        index += @min(len, value.len - index);
    }
    return count;
}

pub fn nextCodepoint(value: []const u8, index: *usize) ?u21 {
    if (index.* >= value.len) return null;
    const start = index.*;
    const codepoint_len = utf8ByteSequenceLength(value[start]) orelse {
        index.* = start + 1;
        return unicode_replacement_character;
    };
    const end = start + codepoint_len;
    if (end > value.len) {
        index.* = value.len;
        return unicode_replacement_character;
    }
    const codepoint = utf8Decode(value[start..end]) orelse {
        index.* = start + 1;
        return unicode_replacement_character;
    };
    index.* = end;
    return codepoint;
}

const unicode_replacement_character: u21 = 0xfffd;

pub fn utf8ByteSequenceLength(first: u8) ?usize {
    return switch (first) {
        0x00...0x7f => 1,
        0xc2...0xdf => 2,
        0xe0...0xef => 3,
        0xf0...0xf4 => 4,
        else => null,
    };
}

pub fn utf8Decode(value: []const u8) ?u21 {
    if (value.len == 0) return null;
    const len = utf8ByteSequenceLength(value[0]) orelse return null;
    if (value.len != len) return null;
    var index: usize = 1;
    var codepoint: u21 = switch (len) {
        1 => value[0],
        2 => value[0] & 0x1f,
        3 => value[0] & 0x0f,
        4 => value[0] & 0x07,
        else => return null,
    };
    while (index < len) : (index += 1) {
        const byte = value[index];
        if ((byte & 0xc0) != 0x80) return null;
        codepoint = (codepoint << 6) | @as(u21, byte & 0x3f);
    }
    if (len == 2 and codepoint < 0x80) return null;
    if (len == 3 and codepoint < 0x800) return null;
    if (len == 4 and codepoint < 0x10000) return null;
    if (codepoint > 0x10ffff or (codepoint >= 0xd800 and codepoint <= 0xdfff)) return null;
    return codepoint;
}
