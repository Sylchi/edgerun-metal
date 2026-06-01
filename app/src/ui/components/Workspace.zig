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

pub const ResponsivePanesProps = struct {
    breakpoint: f32 = 980.0,
    gap: f32 = 14.0,
    first_w: f32,
    third_w: f32,
    first_stack_h: f32,
    second_stack_h: f32,
};

pub const ResponsivePanes = struct {
    first: ui.Rect,
    second: ui.Rect,
    third: ui.Rect,
    stacked: bool,
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

pub fn surface(view: anytype, bounds: ui.Rect, props: SurfaceProps) ui.RenderError!Shell {
    try view.fill(bounds, props.background, 0.0);
    const shell_value = shell(bounds, props.shell);
    try topBar(view, shell_value.top, props.top);
    try statusBar(view, shell_value.status, props.status);
    return shell_value;
}

pub fn topBar(view: anytype, bounds: ui.Rect, props: TopBarProps) ui.RenderError!void {
    try view.fill(bounds, props.fill orelse view.options.style.panel, 0.0);
    try view.line(ui.Rect.init(bounds.x, bounds.y + bounds.h - 1.0, bounds.w, 1.0));
    const trailing_w = if (props.trailing_top.len != 0 or props.trailing_bottom.len != 0) @min(bounds.w, @max(1.0, props.trailing_w)) else 0.0;
    const trailing_gap: f32 = if (trailing_w > 0.0) 20.0 else 0.0;
    const text_w = @max(primitives.min_extent, bounds.w - trailing_w - props.inset_x * 2.0 - trailing_gap);
    try view.title(ui.Rect.init(bounds.x + props.inset_x, bounds.y + 13.0, text_w, 18.0), props.title);
    if (props.detail.len != 0) {
        try view.text(ui.Rect.init(bounds.x + props.inset_x, bounds.y + 34.0, text_w, 14.0), props.detail, props.detail_color orelse view.options.style.muted);
    }
    if (trailing_w > 0.0) {
        const trailing_x = bounds.x + bounds.w - trailing_w - props.inset_x;
        if (props.trailing_top.len != 0) try view.muted(ui.Rect.init(trailing_x, bounds.y + 13.0, trailing_w, 14.0), props.trailing_top);
        if (props.trailing_bottom.len != 0) try view.muted(ui.Rect.init(trailing_x, bounds.y + 32.0, trailing_w, 14.0), props.trailing_bottom);
    }
}

pub fn statusBar(view: anytype, bounds: ui.Rect, props: StatusBarProps) ui.RenderError!void {
    try view.fill(bounds, props.fill, 0.0);
    try view.text(ui.Rect.init(bounds.x + props.inset_x, bounds.y + 5.0, @max(primitives.min_extent, bounds.w - props.inset_x * 2.0), 14.0), props.text, props.color);
}

pub fn responsivePanes(bounds: ui.Rect, props: ResponsivePanesProps) ResponsivePanes {
    if (bounds.w >= props.breakpoint) {
        const gap = @max(0.0, props.gap);
        const first_w = @min(bounds.w, @max(primitives.min_extent, props.first_w));
        const third_w = @min(bounds.w, @max(primitives.min_extent, props.third_w));
        const second_x = bounds.x + first_w + gap;
        const third_x = bounds.x + bounds.w - third_w;
        return .{
            .first = ui.Rect.init(bounds.x, bounds.y, first_w, bounds.h),
            .second = ui.Rect.init(second_x, bounds.y, @max(primitives.min_extent, third_x - gap - second_x), bounds.h),
            .third = ui.Rect.init(third_x, bounds.y, third_w, bounds.h),
            .stacked = false,
        };
    }

    const gap = @max(0.0, props.gap);
    const first_h = @min(bounds.h, @max(primitives.min_extent, props.first_stack_h));
    const second_y = bounds.y + first_h + gap;
    const second_h = @min(@max(primitives.min_extent, bounds.y + bounds.h - second_y), @max(primitives.min_extent, props.second_stack_h));
    const third_y = second_y + second_h + gap;
    return .{
        .first = ui.Rect.init(bounds.x, bounds.y, bounds.w, first_h),
        .second = ui.Rect.init(bounds.x, second_y, bounds.w, second_h),
        .third = ui.Rect.init(bounds.x, third_y, bounds.w, @max(primitives.min_extent, bounds.y + bounds.h - third_y)),
        .stacked = true,
    };
}
