const std = @import("std");
const math = @import("../math.zig");
const interaction = @import("../ui/interaction.zig");
const app_frame = @import("../app_frame.zig");
const app_images = @import("../app_images.zig");
const app_cursor = @import("../ui/cursor.zig");
const state = @import("state.zig");
const input = @import("input/hit.zig");

pub fn packedBuffers() state.renderer_pipeline.Buffers {
    return .{
        .rects = state.packed_rect_floats[0..],
        .rect_len = &state.packed_rect_float_len,
        .icon_vertices = state.packed_icon_vertex_floats[0..],
        .icon_vertex_len = &state.packed_icon_vertex_float_len,
        .icon_line_vertices = state.packed_icon_line_vertex_floats[0..],
        .icon_line_vertex_len = &state.packed_icon_line_vertex_float_len,
        .image_vertices = state.packed_image_vertex_floats[0..],
        .image_vertex_len = &state.packed_image_vertex_float_len,
        .overlay_rects = state.packed_overlay_rect_floats[0..],
        .overlay_rect_len = &state.packed_overlay_rect_float_len,
        .overlay_icon_vertices = state.packed_overlay_icon_vertex_floats[0..],
        .overlay_icon_vertex_len = &state.packed_overlay_icon_vertex_float_len,
        .overlay_icon_line_vertices = state.packed_overlay_icon_line_vertex_floats[0..],
        .overlay_icon_line_vertex_len = &state.packed_overlay_icon_line_vertex_float_len,
    };
}

pub fn renderAppPixels(surface: state.renderer_pipeline.SoftwareFramebuffer, hover_x: f32, hover_y: f32, frame_ms: f32) u32 {
    var scene = state.ui.Scene.initWithClips(&state.commands, &state.clips);
    var frame_regions: [state.max_interaction_regions]interaction.Region = undefined;
    var collector = interaction.Collector.init(&frame_regions);
    app_frame.render(&scene, &collector, frameBounds(), input.currentAppFrameState(hover_x, hover_y, frame_ms)) catch return finishError(.render_failed);
    return finishCpuSceneFrame(surface, scene, collector.written(), .{ .enabled = true, .x = hover_x, .y = hover_y }, state.ui.Color.bg);
}

pub fn renderAppPixelsScaled(surface: state.renderer_pipeline.SoftwareFramebuffer, logical_width: u32, logical_height: u32, scale: f32, hover_x: f32, hover_y: f32, frame_ms: f32) u32 {
    const physical_width = state.frame_width;
    const physical_height = state.frame_height;
    state.frame_width = @intCast(logical_width);
    state.frame_height = @intCast(logical_height);
    defer {
        state.frame_width = physical_width;
        state.frame_height = physical_height;
    }

    var scene = state.ui.Scene.initWithClips(&state.commands, &state.clips);
    var frame_regions: [state.max_interaction_regions]interaction.Region = undefined;
    var collector = interaction.Collector.init(&frame_regions);
    app_frame.render(&scene, &collector, frameBounds(), input.currentAppFrameState(hover_x, hover_y, frame_ms)) catch return finishError(.render_failed);
    const frame_scene = prepareFrameScene(scene, collector.written(), .{ .enabled = true, .x = hover_x, .y = hover_y }) catch return finishError(.render_failed);
    scaleSceneCommands(state.commands[0..frame_scene.commandCount()], scale);
    renderSceneIr(surface, frame_scene.written()) catch return finishError(.render_failed);
    state.last_error = .ok;
    return @intFromEnum(state.ErrorCode.ok);
}

pub fn finishPackedFrame(scene: state.ui.Scene, regions: []const interaction.Region, hover_x: f32, hover_y: f32) u32 {
    const frame_scene = prepareFrameScene(scene, regions, .{ .enabled = true, .x = hover_x, .y = hover_y }) catch return finishError(.render_failed);
    ensureFontAtlas() catch return finishError(.font_atlas);
    const buffers = packedBuffers();
    state.renderer_pipeline.packScene(buffers, &state.font_atlas, frame_scene.written()) catch return finishError(.packed_budget);
    presentPackedBuffers(buffers) catch return finishError(.render_failed);
    state.last_error = .ok;
    return @intFromEnum(state.ErrorCode.ok);
}

pub fn finishCpuSceneFrame(surface: state.renderer_pipeline.SoftwareFramebuffer, scene: state.ui.Scene, regions: []const interaction.Region, hover: state.HoverUpdate, background: state.ui.Color) u32 {
    _ = background;
    const frame_scene = prepareFrameScene(scene, regions, hover) catch return finishError(.render_failed);
    renderSceneIr(surface, frame_scene.written()) catch return finishError(.render_failed);
    state.last_error = .ok;
    return @intFromEnum(state.ErrorCode.ok);
}

pub fn prepareFrameScene(scene: state.ui.Scene, regions: []const interaction.Region, hover: state.HoverUpdate) !state.ui.Scene {
    try storeLastRegions(regions);
    if (hover.enabled) state.runtime_state.refreshHover(lastRegions(), hover.x, hover.y);
    var frame_scene = scene;
    state.runtime_state.refreshFocus(lastRegions());
    try renderRuntimeFocusRing(&frame_scene);
    if (hover.enabled) try app_cursor.render(&frame_scene, hover.x, hover.y, currentCursorKind());
    state.last_command_count = frame_scene.written().len;
    return frame_scene;
}

fn renderRuntimeFocusRing(scene: *state.ui.Scene) state.ui.RenderError!void {
    if (state.runtime_state.focused) |hit| {
        try scene.pushRect(hit.bounds.insetUniform(-state.focus_ring_outset), state.ui_component_common.state_focus_border, .border, state.focus_ring_radius, 0.0);
    }
}

fn scaleSceneCommands(scene_commands: []state.ui.Command, scale: f32) void {
    if (@abs(scale - 1.0) <= 0.001) return;
    for (scene_commands) |*command| scaleSceneCommand(command, scale);
}

fn scaleSceneCommand(command: *state.ui.Command, scale: f32) void {
    switch (command.*) {
        .rect => |*rect| {
            scaleRect(&rect.bounds, scale);
            rect.radius *= scale;
            rect.shadow *= scale;
        },
        .border => |*border| scaleRect(&border.bounds, scale),
        .text => |*text| scaleRect(&text.origin, scale),
        .drag_source => |*source| scaleRect(&source.bounds, scale),
        .drop_target => |*target| scaleRect(&target.bounds, scale),
        .icon_quad => |*quad| scaleRect(&quad.bounds, scale),
        .text_quad => |*quad| scaleRect(&quad.bounds, scale),
        .image_quad => |*quad| scaleRect(&quad.bounds, scale),
        .svg_quad => |*quad| scaleRect(&quad.bounds, scale),
        .transition => {},
    }
}

fn scaleRect(rect: *state.ui.Rect, scale: f32) void {
    rect.x *= scale;
    rect.y *= scale;
    rect.w *= scale;
    rect.h *= scale;
}

pub fn beginFrame(width_raw: u32, height_raw: u32) ?state.renderer_pipeline.SoftwareFramebuffer {
    const width: usize = width_raw;
    const height: usize = height_raw;
    if (!setFrameSize(width, height)) return null;
    return state.renderer_pipeline.softwareFramebuffer(width, height, state.pixels[0 .. width * height]) catch null;
}

fn renderSceneIr(surface: state.renderer_pipeline.SoftwareFramebuffer, scene_commands: []const state.ui.Command) !void {
    try ensureFontAtlas();
    const buffers = packedBuffers();
    try state.renderer_pipeline.packScene(buffers, &state.font_atlas, scene_commands);
    try state.renderer_pipeline.packTextQuads(buffers, &state.font_atlas, scene_commands);
    const image_texture = try app_images.cloudMeme();
    const resources = state.renderer_pipeline.softwareResourcesFromAlphaAtlas(.{
        .width = state.font_atlas_width,
        .height = state.font_atlas_height,
        .alpha = state.font_atlas.alphaSlice(),
    }, image_texture);
    const receipt = try surface.renderIr(buffers, resources);
    state.last_present_primitive_count = receipt.primitive_count;
    state.last_present_transport = receipt.transport;
}

fn presentPackedBuffers(buffers: state.renderer_pipeline.Buffers) state.renderer_pipeline.Error!void {
    const receipt = try state.renderer_pipeline.presentPackedFrame(
        @intCast(state.frame_width),
        @intCast(state.frame_height),
        buffers,
        state.renderer_pipeline.presentationResources(true, true),
    );
    recordPresentation(receipt);
}

fn recordPresentation(receipt: state.renderer_pipeline.Receipt) void {
    state.last_present_primitive_count = receipt.primitive_count;
    state.last_present_transport = receipt.transport;
}

pub fn setFrameSize(width: usize, height: usize) bool {
    if (width == 0 or height == 0 or width > state.max_width or height > state.max_height) return false;
    state.frame_width = width;
    state.frame_height = height;
    return true;
}

pub fn finishError(code: state.ErrorCode) u32 {
    state.last_error = code;
    return @intFromEnum(code);
}

pub fn ensureFontAtlas() !void {
    if (state.font_atlas_ready) return;
    state.font_atlas.initUtf8();
    state.font_atlas.setDeviceScale(state.font_device_scale);
    state.font_atlas_ready = true;
}

pub fn normalizedDeviceScale(scale: f32) f32 {
    if (!math.isFiniteF(scale)) return state.default_device_scale;
    return math.clampF(scale, state.min_device_scale, state.max_device_scale);
}

pub fn framebufferDeviceScale(width: u32, height: u32, scale_raw: f32) f32 {
    const requested = normalizedDeviceScale(scale_raw);
    if (width == 0 or height == 0) return requested;
    const width_limit = @as(f32, @floatFromInt(state.max_width)) / @as(f32, @floatFromInt(width));
    const height_limit = @as(f32, @floatFromInt(state.max_height)) / @as(f32, @floatFromInt(height));
    return math.clampF(@min(requested, width_limit, height_limit), state.min_device_scale, state.max_device_scale);
}

pub fn scaledFrameDimension(value: u32, scale: f32) ?u32 {
    if (value == 0 or !math.isFiniteF(scale)) return null;
    const scaled = @ceil(@as(f32, @floatFromInt(value)) * scale);
    if (scaled < 1.0 or scaled > @as(f32, @floatFromInt(~@as(u32, 0)))) return null;
    return @intFromFloat(scaled);
}

pub fn buildPackedAppFrameFromPreparedSize(app_frame_state: anytype) u32 {
    var scene = state.ui.Scene.initWithClips(&state.commands, &state.clips);
    var frame_regions: [state.max_interaction_regions]interaction.Region = undefined;
    var collector = interaction.Collector.init(&frame_regions);
    app_frame.render(&scene, &collector, frameBounds(), app_frame_state) catch return finishError(.render_failed);
    return finishPackedFrame(scene, collector.written(), app_frame_state.hover_x, app_frame_state.hover_y);
}

fn lastCommands() []const state.ui.Command {
    return state.commands[0..state.last_command_count];
}

fn lastRegions() []const interaction.Region {
    return state.interaction_regions[0..state.last_region_count];
}

fn storeLastRegions(regions: []const interaction.Region) error{InteractionBudgetExceeded}!void {
    if (regions.len > state.interaction_regions.len) return error.InteractionBudgetExceeded;
    @memcpy(state.interaction_regions[0..regions.len], regions);
    state.last_region_count = regions.len;
}

pub fn frameBounds() state.ui.Rect {
    return state.ui.Rect.init(0, 0, @floatFromInt(state.frame_width), @floatFromInt(state.frame_height));
}

pub fn currentWasmImageTexture() ?state.renderer_ir.RgbaTexture {
    return app_images.cloudMeme() catch return null;
}

fn currentCursorKind() state.CursorKind {
    const action_kind: state.ui_runtime.ActionKind = @enumFromInt(@as(u8, @intCast(state.last_action_kind)));
    return app_cursor.fromState(action_kind, state.runtime_state.hoverKind());
}

fn appScrollLimit(width: f32, height: f32) f32 {
    return @max(0.0, er_ui_app_content_height(width) - height);
}

fn er_ui_app_content_height(width: f32) f32 {
    return app_frame.contentHeight(width, input.currentAppFrameState(state.pointer_hover_x, state.pointer_hover_y, 0.0));
}

pub fn clampAppScrollToViewport(width: u32, height: u32) void {
    state.native_input_state.scroll_y = @min(state.native_input_state.scroll_y, appScrollLimit(@floatFromInt(width), @floatFromInt(height)));
}

pub fn refreshRoutePath() void {
    state.route_len = state.app_navigation.writePath(&state.route_bytes, state.native_input_state.route) catch unreachable;
}

pub fn refreshRouteHash() void {
    state.route_hash_len = state.app_navigation.writeHash(&state.route_hash_bytes, state.native_input_state.route) catch unreachable;
}

pub fn recordAction(action: state.ui_runtime.Action) void {
    state.last_action_kind = @intFromEnum(action.kind);
    state.last_action_hit_id = if (action.hit) |hit| hit.id else 0;
    state.last_action_scope_id = if (action.source) |source| source.scope_id else 0;
    state.last_action_from_index = if (action.source) |source| @intCast(source.index) else 0;
    state.last_action_to_index = if (action.target) |target| @intCast(target.index) else 0;
    if (action.kind == .activated) {
        if (action.hit) |hit| {
            if (hit.kind == .overlay_trigger) {
                state.runtime_state.overlays.toggle(hit.id);
            } else {
                state.runtime_state.overlays.dismissAll();
            }
        }
    }
}

pub fn hasRectColor(items: []const state.ui.Command, color: state.ui.Color) bool {
    for (items) |command| switch (command) {
        .rect => |rect| if (std.meta.eql(rect.color, color)) return true,
        else => {},
    };
    return false;
}

pub fn hasIconId(items: []const state.ui.Command, icon_id: u32) bool {
    for (items) |command| switch (command) {
        .icon_quad => |quad| if (quad.icon_id == icon_id) return true,
        else => {},
    };
    return false;
}

pub fn sourceLabelForHit(route: state.app_navigation.Route, hit_id: u32, out: []u8) ?[]const u8 {
    if (hit_id == 0) return null;
    const component_gallery = @import("../component_gallery.zig");
    const index = switch (route.view) {
        .frontend => component_gallery.indexByCatalogHit(hit_id) orelse component_gallery.indexByPreviewHit(hit_id),
        .backend => null,
    } orelse return null;
    return component_gallery.sourcePathForIndex(index, out);
}

pub fn isAsciiDigit(byte: u8) bool {
    return byte >= '0' and byte <= '9';
}
