const std = @import("src/std.zig");
const fb = @import("src/font_builtin.zig");
const fv = @import("src/font_vector.zig");

pub fn main() !void {
    std.debug.print("regular: glyphs={} kerns={} commands={}\n", .{ fb.regular_counts.glyphs, fb.regular_counts.kerns, fb.regular_counts.commands });
    std.debug.print("semibold: glyphs={} kerns={} commands={}\n", .{ fb.semibold_counts.glyphs, fb.semibold_counts.kerns, fb.semibold_counts.commands });
    std.debug.print("bold: glyphs={} kerns={} commands={}\n", .{ fb.bold_counts.glyphs, fb.bold_counts.kerns, fb.bold_counts.commands });
    std.debug.print("sizeof(fv.GlyphRecord)={} sizeof(fv.KernRecord)={} sizeof(fv.Command)={}\n", .{ @sizeOf(fv.GlyphRecord), @sizeOf(fv.KernRecord), @sizeOf(fv.Command) });
    std.debug.print("sizeof(fb.regular.commands)={} sizeof(fb.regular.kerns)={} sizeof(fb.regular.glyphs)={}\n", .{ @sizeOf(@TypeOf(fb.regular.commands)), @sizeOf(@TypeOf(fb.regular.kerns)), @sizeOf(@TypeOf(fb.regular.glyphs)) });
    std.debug.print("sizeof(regular struct)={} semibold struct={} bold struct={}\n", .{ @sizeOf(fb.RegularCompiled), @sizeOf(fb.SemiboldCompiled), @sizeOf(fb.BoldCompiled) });
    std.debug.print("atlas alpha bytes={} (1024*1024)\n", .{fb.atlas_width * fb.atlas_height});
    const total_regular = @as(u64, @sizeOf(fb.RegularCompiled));
    const total_semibold = @as(u64, @sizeOf(fb.SemiboldCompiled));
    const total_bold = @as(u64, @sizeOf(fb.BoldCompiled));
    std.debug.print("compiled body total bytes regular+semibold+bold={}\n", .{total_regular + total_semibold + total_bold});
}
