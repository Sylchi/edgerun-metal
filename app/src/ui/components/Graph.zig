const primitives = @import("Primitives.zig");
const ui = @import("../core.zig");

pub fn lineRect(view: anytype, x0: f32, y0: f32, x1: f32, y1: f32, color: ui.Color, thickness: f32) ui.RenderError!void {
    const resolved_thickness = @max(primitives.min_extent, thickness);
    if (@abs(x1 - x0) >= @abs(y1 - y0)) {
        const left = @min(x0, x1);
        try view.fill(ui.Rect.init(left, y0 - resolved_thickness * 0.5, @max(resolved_thickness, @abs(x1 - x0)), resolved_thickness), color, 0.0);
    } else {
        const top = @min(y0, y1);
        try view.fill(ui.Rect.init(x0 - resolved_thickness * 0.5, top, resolved_thickness, @max(resolved_thickness, @abs(y1 - y0))), color, 0.0);
    }
}

pub fn elbowEdge(view: anytype, from: ui.Rect, to: ui.Rect, color: ui.Color, thickness: f32) ui.RenderError!void {
    const x0 = from.x + from.w;
    const y0 = from.y + from.h * 0.5;
    const x1 = to.x;
    const y1 = to.y + to.h * 0.5;
    const mid_x = x0 + @max(10.0, (x1 - x0) * 0.5);
    try lineRect(view, x0, y0, mid_x, y0, color, thickness);
    try lineRect(view, mid_x, y0, mid_x, y1, color, thickness);
    try lineRect(view, mid_x, y1, x1, y1, color, thickness);
    try view.fill(ui.Rect.init(x1 - 5.0, y1 - 4.0, 8.0, 8.0), color, 2.0);
}
