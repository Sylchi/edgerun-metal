const common = @import("../../ui_component_common.zig");
const component_render = @import("Render.zig");
const interaction = @import("../../ui_interaction.zig");
const layouts = @import("../../layouts.zig");
const region_io = @import("RegionIO.zig");
const ui = @import("../../ui.zig");

const HtmlError = common.HtmlError;
const MarkdownError = common.MarkdownError;
const RenderOptions = common.RenderOptions;

pub const RegionTag = enum {
    header,
    main,
    footer,
    section,
    article,
};

pub fn Region(comptime Component: type) type {
    return struct {
        tag: RegionTag,
        label: []const u8 = "",
        children: []const Component,

        const Self = @This();

        pub fn measure(self: Self, constraints: layouts.types.Constraints, options: RenderOptions) layouts.types.Measurement {
            return component_render.measureRegion(Component, self, constraints, options);
        }

        pub fn render(self: Self, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
            return component_render.renderRegion(Component, scene, bounds, self, options);
        }

        pub fn collectInteractions(self: Self, collector: *interaction.Collector, bounds: ui.Rect, options: RenderOptions) interaction.Error!void {
            return component_render.collectRegionInteractions(Component, collector, bounds, self, options);
        }

        pub fn toHtml(self: Self, out: []u8) HtmlError![]u8 {
            return region_io.writeHtml(Component, self, out);
        }

        pub fn fromHtml(html: []const u8, out_components: []Component, text_out: []u8) HtmlError!Self {
            return region_io.readHtml(Self, RegionTag, Component, html, out_components, text_out);
        }

        pub fn toMarkdown(self: Self, out: []u8) MarkdownError![]u8 {
            return region_io.writeMarkdown(Component, self, out);
        }

        pub fn fromMarkdown(markdown: []const u8, out_components: []Component, text_out: []u8) MarkdownError!Self {
            return region_io.readMarkdown(Self, RegionTag, Component, markdown, out_components, text_out);
        }
    };
}
