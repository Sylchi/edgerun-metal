const icon = @import("icon.zig");
const ui = @import("ui.zig");
const interaction = @import("ui_interaction.zig");

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

pub const RenderOptions = struct {
    style: ui.Style = .{},
    button_variant: ButtonVariant = .primary,
    button_leading_icon: ?icon.Icon = null,
    button_trailing_icon: ?icon.Icon = null,
    badge_variant: BadgeVariant = .default,
    surface_variant: SurfaceVariant = .panel,
};

pub fn collectHit(collector: *interaction.Collector, bounds: ui.Rect, kind: ui.HitKind, id: u32) interaction.Error!void {
    return collector.addHit(bounds, kind, id);
}
