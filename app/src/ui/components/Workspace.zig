const ui = @import("../core.zig");
const primitives = @import("Primitives.zig");

pub const ShellProps = struct {
    rail_w: f32 = 48.0,
    sidebar_w: f32 = 260.0,
    top_h: f32 = 56.0,
    status_h: f32 = 24.0,
};

pub const Shell = struct {
    rail: ui.Rect,
    top: ui.Rect,
    sidebar: ui.Rect,
    main: ui.Rect,
    status: ui.Rect,
};

pub const TopBarProps = struct {
    title: []const u8,
    detail: []const u8 = "",
    trailing_top: []const u8 = "",
    trailing_bottom: []const u8 = "",
    fill: ?ui.Color = null,
    detail_color: ?ui.Color = null,
    trailing_w: f32 = 210.0,
    inset_x: f32 = 16.0,
};

pub const StatusBarProps = struct {
    text: []const u8,
    fill: ui.Color,
    color: ui.Color = .{ .r = 255, .g = 255, .b = 255 },
    inset_x: f32 = 12.0,
};

pub const SurfaceProps = struct {
    shell: ShellProps = .{},
    background: ui.Color,
    top: TopBarProps,
    status: StatusBarProps,
};

pub fn shell(bounds: ui.Rect, props: ShellProps) Shell {
    const rail_w = @min(bounds.w, @max(0.0, props.rail_w));
    const status_h = @min(bounds.h, @max(0.0, props.status_h));
    const top_h = @min(@max(0.0, bounds.h - status_h), @max(0.0, props.top_h));
    const body_h = @max(primitives.min_extent, bounds.h - top_h - status_h);
    const body_y = bounds.y + top_h;
    const rail_h = @max(primitives.min_extent, bounds.h - status_h);
    const content_x = bounds.x + rail_w;
    const content_w = @max(primitives.min_extent, bounds.w - rail_w);
    const sidebar_w = @min(content_w, @max(0.0, props.sidebar_w));
    return .{
        .rail = ui.Rect.init(bounds.x, bounds.y, rail_w, rail_h),
        .top = ui.Rect.init(content_x, bounds.y, content_w, top_h),
        .sidebar = ui.Rect.init(content_x, body_y, sidebar_w, body_h),
        .main = ui.Rect.init(content_x + sidebar_w, body_y, @max(primitives.min_extent, content_w - sidebar_w), body_h),
        .status = ui.Rect.init(bounds.x, bounds.y + bounds.h - status_h, bounds.w, status_h),
    };
}
