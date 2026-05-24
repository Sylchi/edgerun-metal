const std = @import("std");
const common = @import("../../ui_component_common.zig");
const ui = @import("../../ui.zig");
const ui_input = @import("../../input.zig");
const layout = @import("../../layouts/Types.zig");
const base_text_block = @import("base/TextBlock.zig");

const RenderOptions = common.RenderOptions;

pub const ArticleListItem = struct {
    id: u32,
    category: []const u8,
    meta: []const u8,
    title: []const u8,
    summary: []const u8,

    pub fn height(self: ArticleListItem, width: f32) f32 {
        return articleListItemHeight(width, self);
    }

    pub fn measure(self: ArticleListItem, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        return measureArticleListItem(self, constraints);
    }

    pub fn render(self: ArticleListItem, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return renderArticleListItem(self, scene, bounds, options);
    }
};

pub fn articleListItemHeight(width: f32, article: ArticleListItem) f32 {
    const text_width = articleListTextWidth(width);
    const text_constraints = articleListTextConstraints(text_width);
    const title = base_text_block.measure(article.title, text_constraints, article_list_title_metrics);
    const summary = base_text_block.measure(article.summary, text_constraints, article_list_summary_metrics);
    const text_height = article_list_meta_height +
        article_list_meta_gap +
        title.preferred.h +
        article_list_title_summary_gap +
        summary.preferred.h;
    return @max(article_list_min_height, article_list_padding_y * 2.0 + text_height);
}

pub fn measureArticleListItem(article: ArticleListItem, constraints: layout.Constraints) layout.Measurement {
    const width = constraints.width.exactValue() orelse constraints.width.limit(article_list_default_width);
    const height = articleListItemHeight(width, article);
    return layout.Measurement.flexible(
        .{ .w = @min(article_list_min_width, width), .h = @min(article_list_min_height, height) },
        .{ .w = width, .h = constraints.height.exactValue() orelse height },
        .{ .w = @max(width, article_list_min_width), .h = height },
    );
}

pub fn renderArticleListItem(article: ArticleListItem, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
    const text_width = articleListTextWidth(bounds.w);
    const text_x = bounds.x + article_list_padding_x;
    const text_top = bounds.y + article_list_padding_y;
    const meta_bounds = ui.Rect.init(text_x, text_top, text_width, article_list_meta_height);
    const meta = if (article.meta.len != 0) article.meta else article.category;
    try scene.pushAlignedText(meta_bounds, article.category, options.style.accent, .start);
    try scene.pushAlignedText(meta_bounds, meta, options.style.muted, .end);

    const title_y = text_top + article_list_meta_height + article_list_meta_gap;
    const text_constraints = articleListTextConstraints(text_width);
    const title = base_text_block.measure(article.title, text_constraints, article_list_title_metrics);
    try base_text_block.render(scene, ui.Rect.init(text_x, title_y, text_width, title.preferred.h), article.title, options.style.text, article_list_title_metrics);

    const summary_y = title_y + title.preferred.h + article_list_title_summary_gap;
    const summary = base_text_block.measure(article.summary, text_constraints, article_list_summary_metrics);
    try base_text_block.render(scene, ui.Rect.init(text_x, summary_y, text_width, summary.preferred.h), article.summary, options.style.muted, article_list_summary_metrics);

    const divider = ui.Rect.init(bounds.x, bounds.y + bounds.h - article_list_divider_height, bounds.w, article_list_divider_height);
    try scene.pushRect(divider, options.style.border, .fill, 0.0, 0.0);
    try scene.pushHit(.{ .slot = 0, .kind = .button, .id = article.id, .bounds = bounds });
}

const article_list_padding_x: f32 = 6.0;
const article_list_padding_y: f32 = 16.0;
const article_list_arrow_slot: f32 = 34.0;
const article_list_min_height: f32 = 104.0;
const article_list_meta_height: f32 = 14.0;
const article_list_meta_gap: f32 = 10.0;
const article_list_title_line_height: f32 = 25.0;
const article_list_title_average_char_width: f32 = 10.5;
const article_list_title_max_lines: usize = 3;
const article_list_title_summary_gap: f32 = 8.0;
const article_list_summary_line_height: f32 = 18.0;
const article_list_summary_average_char_width: f32 = 9.0;
const article_list_summary_max_lines: usize = 3;
const article_list_divider_height: f32 = 1.0;
const article_list_min_width: f32 = 180.0;
const article_list_default_width: f32 = 420.0;
const article_list_title_metrics = base_text_block.Metrics{
    .line_height = article_list_title_line_height,
    .average_char_width = article_list_title_average_char_width,
    .max_lines = article_list_title_max_lines,
};
const article_list_summary_metrics = base_text_block.Metrics{
    .line_height = article_list_summary_line_height,
    .average_char_width = article_list_summary_average_char_width,
    .max_lines = article_list_summary_max_lines,
};

fn articleListTextWidth(width: f32) f32 {
    return @max(1.0, width - article_list_padding_x * 2.0 - article_list_arrow_slot);
}

fn articleListTextConstraints(width: f32) layout.Constraints {
    return .{ .width = .{ .exact = width }, .text_wrap = .wrap };
}

test "article list item expands around wrapped titles and summaries" {
    const short_article = ArticleListItem{
        .id = 4201,
        .category = "System",
        .meta = "Tiny",
        .title = "Short title",
        .summary = "Short summary.",
    };
    const long_article = ArticleListItem{
        .id = 4202,
        .category = "Security",
        .meta = "Long",
        .title = "A very long lesson title that needs more than one line in a normal academy list",
        .summary = "A longer summary explains why the phone, operating system, and cloud account all participate in the user's security boundary.",
    };
    const short_height = short_article.height(420.0);
    const long_height = long_article.height(420.0);
    var commands: [32]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try std.testing.expect(long_height > short_height);
    try long_article.render(&scene, ui.Rect.init(0.0, 0.0, 420.0, long_height), .{});

    const hit = ui_input.hitTest(scene.written(), 20.0, 20.0).?;
    try std.testing.expectEqual(@as(u32, 4202), hit.id);
    try std.testing.expect(hasTextContaining(scene.written(), "very long lesson"));
    try std.testing.expect(hasTextContaining(scene.written(), "operating system"));
}

test "article list item measurement follows exact width" {
    const article = ArticleListItem{
        .id = 4202,
        .category = "Security",
        .meta = "Long",
        .title = "A very long lesson title that needs more than one line in a normal academy list",
        .summary = "A longer summary explains why the phone, operating system, and cloud account all participate in the user's security boundary.",
    };

    const wide = article.measure(.{ .width = .{ .exact = 420 }, .text_wrap = .wrap }, .{});
    const narrow = article.measure(.{ .width = .{ .exact = 140 }, .text_wrap = .wrap }, .{});

    try std.testing.expectEqual(@as(f32, 420), wide.preferred.w);
    try std.testing.expectEqual(@as(f32, 140), narrow.preferred.w);
    try std.testing.expect(narrow.preferred.h >= wide.preferred.h);
}

fn hasTextContaining(commands: []const ui.Command, value: []const u8) bool {
    for (commands) |command| {
        if (command == .text and std.mem.indexOf(u8, command.text.value, value) != null) return true;
    }
    return false;
}
