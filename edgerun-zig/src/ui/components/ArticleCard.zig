const std = @import("std");
const common = @import("../../ui_component_common.zig");
const interaction = @import("../../ui_interaction.zig");
const ui = @import("../../ui.zig");
const ui_input = @import("../../input.zig");
const layout = @import("../../layouts/Types.zig");
const base_badge = @import("base/Badge.zig");
const base_surface = @import("base/Surface.zig");
const base_text_block = @import("base/TextBlock.zig");

const RenderOptions = common.RenderOptions;

pub const ArticleCard = struct {
    id: u32,
    category: []const u8,
    meta: []const u8,
    title: []const u8,
    summary: []const u8,

    pub fn render(self: ArticleCard, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return renderArticleCard(self, scene, bounds, options);
    }

    pub fn collectInteractions(self: ArticleCard, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return collectArticleCardInteractions(self, collector, bounds);
    }

    pub fn measure(self: ArticleCard, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        return measureArticleCard(self, constraints);
    }
};

pub fn renderArticleCard(article: ArticleCard, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
    var frame_options = options;
    frame_options.surface_variant = .elevated;
    try base_surface.renderFrame(scene, bounds, frame_options);
    const inset = bounds.insetUniform(article_padding);
    const badge_width = @min(article_badge_max_width, @max(article_badge_min_width, inset.w * article_badge_width_ratio));
    try renderCategoryBadge(scene, ui.Rect.init(inset.x, inset.y, badge_width, article_badge_height), article.category, options);
    try scene.pushAlignedText(ui.Rect.init(inset.x + badge_width + article_gap, inset.y + article_meta_y, @max(1.0, inset.w - badge_width - article_gap), article_meta_height), article.meta, options.style.muted, .end);
    try base_text_block.render(scene, ui.Rect.init(inset.x, inset.y + article_title_y, inset.w - article_arrow_slot, article_title_h), article.title, options.style.text, article_title_metrics);
    try base_text_block.render(scene, ui.Rect.init(inset.x, bounds.y + bounds.h - article_summary_bottom_offset, inset.w - article_arrow_slot, article_summary_h), article.summary, options.style.muted, article_summary_metrics);
}

pub fn collectArticleCardInteractions(article: ArticleCard, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
    try collector.add(.{ .kind = .button, .id = article.id, .bounds = bounds });
}

pub fn measureArticleCard(article: ArticleCard, constraints: layout.Constraints) layout.Measurement {
    const content = constraints.inner(layout.Insets.uniform(article_padding));
    const title = base_text_block.measure(article.title, content, article_title_metrics);
    const summary = base_text_block.measure(article.summary, content, article_summary_metrics);
    const preferred = ui.Size{
        .w = constraints.width.exactValue() orelse @max(article_min_width, @max(title.preferred.w, summary.preferred.w) + article_padding * 2.0),
        .h = article_padding * 2.0 + article_badge_height + article_gap + title.preferred.h + article_gap + summary.preferred.h,
    };
    return layout.Measurement.flexible(
        .{ .w = @min(article_min_width, preferred.w), .h = @min(article_min_height, preferred.h) },
        preferred,
        .{ .w = @max(preferred.w, constraints.width.limit(preferred.w)), .h = preferred.h },
    );
}

fn renderCategoryBadge(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, options: RenderOptions) ui.RenderError!void {
    return base_badge.render(scene, bounds, label, options);
}

const article_padding: f32 = 18.0;
const article_gap: f32 = 12.0;
const article_badge_min_width: f32 = 96.0;
const article_badge_max_width: f32 = 140.0;
const article_badge_height: f32 = 24.0;
const article_badge_width_ratio: f32 = 0.28;
const article_meta_y: f32 = 6.0;
const article_meta_height: f32 = 12.0;
const article_arrow_slot: f32 = 24.0;
const article_title_y: f32 = 42.0;
const article_title_h: f32 = 50.0;
const article_title_line_h: f32 = 22.0;
const article_title_avg_w: f32 = 10.5;
const article_title_max_lines: usize = 2;
const article_summary_bottom_offset: f32 = 58.0;
const article_summary_h: f32 = 44.0;
const article_summary_line_h: f32 = 18.0;
const article_summary_avg_w: f32 = 10.0;
const article_summary_max_lines: usize = 2;
const article_min_width: f32 = 180.0;
const article_min_height: f32 = 96.0;
const article_title_metrics = base_text_block.Metrics{
    .line_height = article_title_line_h,
    .average_char_width = article_title_avg_w,
    .max_lines = article_title_max_lines,
};
const article_summary_metrics = base_text_block.Metrics{
    .line_height = article_summary_line_h,
    .average_char_width = article_summary_avg_w,
    .max_lines = article_summary_max_lines,
};

test "article card renders category title and collects hit target" {
    const article = ArticleCard{
        .id = 801,
        .category = "Architecture",
        .meta = "May 23, 2026",
        .title = "EdgeRun Apps Run Where The User Is",
        .summary = "A short introduction to identity-routed apps and local execution.",
    };
    var commands: [64]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [2]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try article.render(&scene, ui.Rect.init(0, 0, 360, 172), .{});
    try article.collectInteractions(&collector, ui.Rect.init(0, 0, 360, 172));

    try std.testing.expect(ui_input.hitTest(scene.written(), 20, 20) == null);
    const hit = ui_input.regionHitTest(collector.written(), 20, 20).?;
    try std.testing.expectEqual(@as(u32, 801), hit.id);
    try std.testing.expect(hasText(scene.written(), "Architecture"));
    try std.testing.expect(hasTextContaining(scene.written(), "EdgeRun Apps"));
}

test "article card measurement uses assigned card width" {
    const article = ArticleCard{
        .id = 801,
        .category = "Architecture",
        .meta = "May 23, 2026",
        .title = "EdgeRun Apps Run Where The User Is",
        .summary = "A short introduction to identity-routed apps and local execution.",
    };

    const measured = article.measure(.{ .width = .{ .exact = 260 }, .text_wrap = .wrap }, .{});

    try std.testing.expectEqual(@as(f32, 260), measured.preferred.w);
    try std.testing.expect(measured.preferred.h >= article_min_height);
}

fn hasText(commands: []const ui.Command, value: []const u8) bool {
    for (commands) |command| {
        if (command == .text and std.mem.eql(u8, command.text.value, value)) return true;
    }
    return false;
}

fn hasTextContaining(commands: []const ui.Command, value: []const u8) bool {
    for (commands) |command| {
        if (command == .text and std.mem.indexOf(u8, command.text.value, value) != null) return true;
    }
    return false;
}
