const icon = @import("icon.zig");
const ui = @import("core.zig");
const interaction = @import("interaction.zig");
const tokens = @import("theme.zig");

pub const Error = error{
    Corrupt,
    UnsupportedComponent,
    ComponentBudgetExceeded,
    ChildMismatch,
};

pub const ButtonVariant = enum {
    primary,
    secondary,
    outline,
    ghost,
    destructive,
    link,
};

pub const BadgeVariant = enum {
    default,
    secondary,
    destructive,
    outline,
    ghost,
    link,
};

pub const SurfaceVariant = enum {
    panel,
    elevated,
    subtle,
};

pub const ControlSize = enum {
    small,
    default,
    large,
};

pub const AccessibilityRole = enum {
    text,
    button,
    input,
    checkbox,
    switch_control,
    slider,
    tab,
    table,
    dialog,
    menu,
    image,
    status,
    generic,
};

pub const Accessibility = struct {
    role: AccessibilityRole,
    label: []const u8 = "",
    control_id: ?u32 = null,
};

pub const ValidationState = enum {
    helper,
    invalid,
};

pub const Validation = struct {
    state: ValidationState = .helper,
    message: []const u8,
};

pub const ScrollState = struct {
    viewport_h: f32,
    content_h: f32,
    offset_y: f32 = 0.0,
};

pub const TableColumn = enum {
    name,
    role,
};

pub const SortDirection = enum {
    ascending,
    descending,
};

pub const TableSort = struct {
    column: TableColumn,
    direction: SortDirection,
};

pub const CommandItem = struct {
    label: []const u8,
    detail: []const u8 = "",
    shortcut: []const u8 = "",
};

pub const CommandPalette = struct {
    query: []const u8 = "",
    items: []const CommandItem = &.{},
    selected_index: usize = 0,
};

pub const AccessibilityNode = struct {
    metadata: Accessibility,
    bounds: ui.Rect,
};

pub const AccessibilityError = error{
    AccessibilityBudgetExceeded,
    InvalidAccessibilityBounds,
};

pub const AccessibilityTree = struct {
    nodes: []AccessibilityNode,
    len: usize = 0,

    pub fn init(nodes: []AccessibilityNode) AccessibilityTree {
        return .{ .nodes = nodes };
    }

    pub fn append(self: *AccessibilityTree, node: AccessibilityNode) AccessibilityError!void {
        if (!node.bounds.valid()) return error.InvalidAccessibilityBounds;
        if (self.len == self.nodes.len) return error.AccessibilityBudgetExceeded;
        self.nodes[self.len] = node;
        self.len += 1;
    }

    pub fn written(self: AccessibilityTree) []const AccessibilityNode {
        return self.nodes[0..self.len];
    }
};

pub const OverlayState = struct {
    open_ids: []const u32 = &.{},

    pub fn isOpen(self: OverlayState, id: u32) bool {
        for (self.open_ids) |oid| {
            if (oid == id) return true;
        }
        return false;
    }
};

pub const RenderOptions = struct {
    style: ui.Style = .{},
    control: ControlState = .{},
    interaction: InteractionState = .{},
    validation: ?Validation = null,
    scroll: ?ScrollState = null,
    table_sort: ?TableSort = null,
    command_palette: ?CommandPalette = null,
    control_size: ControlSize = .default,
    overlay: OverlayState = .{},
    drag_value: ?f32 = null,

    pub fn withControlId(self: RenderOptions, id: ?u32) RenderOptions {
        const value = id orelse return self;
        var next = self;
        next.control = self.control.merge(self.interaction.controlFor(value));
        return next;
    }

    pub fn withStyle(self: RenderOptions, style: ui.Style) RenderOptions {
        var next = self;
        next.style = style;
        return next;
    }

    pub fn withAccent(self: RenderOptions, color: ui.Color) RenderOptions {
        var next = self;
        next.style.accent = color;
        return next;
    }

    pub fn withTextColor(self: RenderOptions, color: ui.Color) RenderOptions {
        var next = self;
        next.style.text = color;
        return next;
    }

    pub fn withControl(self: RenderOptions, control: ControlState) RenderOptions {
        var next = self;
        next.control = control;
        return next;
    }

    pub fn withMergedControl(self: RenderOptions, control: ControlState) RenderOptions {
        var next = self;
        next.control = self.control.merge(control);
        return next;
    }

    pub fn withControlSize(self: RenderOptions, size: ControlSize) RenderOptions {
        var next = self;
        next.control_size = size;
        return next;
    }
};

pub const ControlState = struct {
    hovered: bool = false,
    active: bool = false,
    focused: bool = false,
    disabled: bool = false,
    loading: bool = false,
    invalid: bool = false,

    pub fn any(self: ControlState) bool {
        return self.hovered or self.active or self.focused or self.disabled or self.loading or self.invalid;
    }

    pub fn merge(self: ControlState, other: ControlState) ControlState {
        return .{
            .hovered = self.hovered or other.hovered,
            .active = self.active or other.active,
            .focused = self.focused or other.focused,
            .disabled = self.disabled or other.disabled,
            .loading = self.loading or other.loading,
            .invalid = self.invalid or other.invalid,
        };
    }
};

pub const ComponentFlags = struct {
    disabled: bool = false,
    readonly: bool = false,
    invalid: bool = false,
    loading: bool = false,

    pub fn merge(self: ComponentFlags, other: ComponentFlags) ComponentFlags {
        return .{
            .disabled = self.disabled or other.disabled,
            .readonly = self.readonly or other.readonly,
            .invalid = self.invalid or other.invalid,
            .loading = self.loading or other.loading,
        };
    }

    pub fn apply(self: ComponentFlags, options: RenderOptions) RenderOptions {
        var next = options;
        next.control.disabled = next.control.disabled or self.disabled;
        next.control.invalid = next.control.invalid or self.invalid;
        next.control.loading = next.control.loading or self.loading;
        return next;
    }
};

pub const ComponentContract = struct {
    requires_id: bool = true,
    requires_flags: bool = true,
    requires_accessibility: bool = true,
    requires_interactions: bool = false,
};

pub fn assertComponentContract(comptime T: type, comptime contract: ComponentContract) void {
    if (!@hasDecl(T, "node")) @compileError(@typeName(T) ++ " must define node");
    if (!@hasDecl(T, "render")) @compileError(@typeName(T) ++ " must define render");
    if (!@hasDecl(T, "measure")) @compileError(@typeName(T) ++ " must define measure");
    if (contract.requires_interactions and !@hasDecl(T, "collectInteractions")) @compileError(@typeName(T) ++ " must define collectInteractions");
    if (!@hasDecl(T, "writeRecord")) @compileError(@typeName(T) ++ " must define writeRecord");
    if (!@hasDecl(T, "fromNode")) @compileError(@typeName(T) ++ " must define fromNode");
    if (contract.requires_accessibility and !@hasDecl(T, "accessibility")) @compileError(@typeName(T) ++ " must define accessibility");
    if (contract.requires_id and !@hasField(T, "id")) @compileError(@typeName(T) ++ " must define id field");
    if (contract.requires_flags and !@hasField(T, "flags")) @compileError(@typeName(T) ++ " must define flags field");
}

pub const InteractionState = struct {
    hovered_id: ?u32 = null,
    active_id: ?u32 = null,
    focused_id: ?u32 = null,
    disabled_id: ?u32 = null,
    loading_id: ?u32 = null,
    invalid_id: ?u32 = null,

    pub fn controlFor(self: InteractionState, id: u32) ControlState {
        return .{
            .hovered = matchesId(self.hovered_id, id),
            .active = matchesId(self.active_id, id),
            .focused = matchesId(self.focused_id, id),
            .disabled = matchesId(self.disabled_id, id),
            .loading = matchesId(self.loading_id, id),
            .invalid = matchesId(self.invalid_id, id),
        };
    }
};

pub const state_hover_border = tokens.State.hover_border;
pub const state_active_border = tokens.State.active_border;
pub const state_focus_border = tokens.State.focus_border;
pub const state_invalid_border = tokens.State.invalid_border;
pub const state_disabled_tint = tokens.State.disabled_tint;
pub const state_loading_fill = tokens.State.loading_fill;

fn matchesId(value: ?u32, id: u32) bool {
    return if (value) |candidate| candidate == id else false;
}

pub fn collectHit(collector: *interaction.Collector, bounds: ui.Rect, kind: ui.HitKind, id: u32) interaction.Error!void {
    return collector.addHit(bounds, kind, id);
}

pub fn offsetId(id: u32, offset: u32) u32 {
    return id + offset;
}

pub const encoded_icon_count: u16 = icon.icon_count + 1;

pub fn optionalIconTag(value: ?icon.Icon) u16 {
    return if (value) |icon_value| @as(u16, @intFromEnum(icon_value)) + 1 else 0;
}

pub fn optionalIconFromTag(tag: u16) Error!?icon.Icon {
    if (tag == 0) return null;
    return icon.fromId(tag) orelse error.Corrupt;
}
