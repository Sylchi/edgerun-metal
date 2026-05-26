const icon = @import("icon.zig");
const ui = @import("ui.zig");
const interaction = @import("ui_interaction.zig");
const tokens = @import("ui_tokens.zig");

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

pub const RenderOptions = struct {
    style: ui.Style = .{},
    control: ControlState = .{},
    interaction: InteractionState = .{},

    pub fn withControlId(self: RenderOptions, id: ?u32) RenderOptions {
        const value = id orelse return self;
        var next = self;
        next.control = self.control.merge(self.interaction.controlFor(value));
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

pub const encoded_icon_count: u16 = @typeInfo(icon.Icon).@"enum".fields.len + 1;

pub fn optionalIconTag(value: ?icon.Icon) u16 {
    return if (value) |icon_value| @as(u16, @intFromEnum(icon_value)) + 1 else 0;
}

pub fn optionalIconFromTag(tag: u16) Error!?icon.Icon {
    if (tag == 0) return null;
    const raw = tag - 1;
    if (raw >= @typeInfo(icon.Icon).@"enum".fields.len) return error.Corrupt;
    return @enumFromInt(@as(u8, @intCast(raw)));
}
