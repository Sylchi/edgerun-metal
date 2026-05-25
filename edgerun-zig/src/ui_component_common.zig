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
};

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
