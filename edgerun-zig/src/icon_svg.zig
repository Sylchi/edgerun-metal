const std = @import("std");
const icon = @import("icon.zig");
const icon_vector = @import("icon_vector.zig");

const default_view_box = ViewBox{ .min_x = 0.0, .min_y = 0.0, .width = 24.0, .height = 24.0 };

pub const ViewBox = struct {
    min_x: f32,
    min_y: f32,
    width: f32,
    height: f32,
};

const Transform = struct {
    a: f32 = 1.0,
    b: f32 = 0.0,
    c: f32 = 0.0,
    d: f32 = 1.0,
    e: f32 = 0.0,
    f: f32 = 0.0,

    fn apply(self: Transform, value: icon_vector.Point) icon_vector.Point {
        return .{
            .x = value.x * self.a + value.y * self.c + self.e,
            .y = value.x * self.b + value.y * self.d + self.f,
        };
    }

    fn scaleX(self: Transform, value: f32) f32 {
        return value * @sqrt(self.a * self.a + self.b * self.b);
    }

    fn scaleY(self: Transform, value: f32) f32 {
        return value * @sqrt(self.c * self.c + self.d * self.d);
    }

    fn isAxisAligned(self: Transform) bool {
        return @abs(self.b) <= transform_epsilon and @abs(self.c) <= transform_epsilon;
    }

    fn isAxisAlignedPositive(self: Transform) bool {
        return self.isAxisAligned() and self.a > 0.0 and self.d > 0.0;
    }

    fn isUniformRotationScale(self: Transform) bool {
        const sx = self.scaleX(1.0);
        const sy = self.scaleY(1.0);
        const dot = self.a * self.c + self.b * self.d;
        return sx > transform_epsilon and sy > transform_epsilon and @abs(sx - sy) <= transform_epsilon and @abs(dot) <= transform_epsilon;
    }

    fn rotationDegrees(self: Transform) f32 {
        return radiansToDegrees(std.math.atan2(self.b, self.a));
    }
};

const Presentation = struct {
    fill_paint: bool = true,
    stroke_paint: bool = false,
    fill_color: SvgPaint = .{ .solid = .{ .r = 0, .g = 0, .b = 0, .a = 255 } },
    stroke_color: SvgPaint = .current_color,
    stroke_width: bool = false,
    stroke_linecap: bool = false,
    stroke_linejoin: bool = false,
    fill_visible: bool = true,
    stroke_visible: bool = true,
    fill_rule: FillRule = .nonzero,

    fn isSupportedStrokeIcon(self: Presentation) bool {
        return !self.fill_paint and
            self.isSupportedStrokePaint();
    }

    fn isSupportedStrokePaint(self: Presentation) bool {
        return self.stroke_paint and
            self.stroke_width and
            self.stroke_linecap and
            self.stroke_linejoin and
            self.stroke_visible;
    }

    fn paintMode(self: Presentation, kind: SvgElementKind) ?PaintMode {
        const can_fill = switch (kind) {
            .path, .circle, .ellipse, .polyline, .polygon, .rect => true,
            .line => false,
        };
        const fill_active = self.fill_paint and self.fill_visible;
        const stroke_active = self.stroke_paint and self.stroke_visible;
        if (fill_active and stroke_active and can_fill and self.isSupportedStrokePaint()) return .fill_then_stroke;
        if (stroke_active and !can_fill and self.isSupportedStrokePaint()) return .stroke;
        if (fill_active and !stroke_active and can_fill) return .fill;
        if (!fill_active and stroke_active and self.isSupportedStrokePaint()) return .stroke;
        if (!fill_active and !stroke_active) return null;
        return null;
    }

    fn hasVisiblePaint(self: Presentation) bool {
        return (self.fill_paint and self.fill_visible) or (self.stroke_paint and self.stroke_visible);
    }
};

const PaintMode = enum {
    stroke,
    fill,
    fill_then_stroke,
};

const FillRule = enum {
    nonzero,
    evenodd,
};

const SvgPaint = union(enum) {
    current_color,
    solid: icon_vector.Paint,
};

const SvgRoot = struct {
    view_box: ViewBox,
    presentation: Presentation,
    render_state: RenderState,
};

const RenderState = struct {
    subtree_hidden: bool = false,
    visibility_hidden: bool = false,
    stroke_hidden: bool = false,

    fn hidesSelf(self: RenderState) bool {
        return self.subtree_hidden or self.visibility_hidden;
    }
};

const CssRules = struct {
    rules: [max_css_rules]CssRule = undefined,
    len: usize = 0,

    fn empty() CssRules {
        return .{};
    }

    fn append(self: *CssRules, rule: CssRule) Error!void {
        if (self.len >= self.rules.len) return error.UnsupportedSvgElement;
        self.rules[self.len] = rule;
        self.len += 1;
    }

    fn items(self: *const CssRules) []const CssRule {
        return self.rules[0..self.len];
    }
};

const empty_css_rules = CssRules.empty();

const CssRule = struct {
    selector: CssSelector,
    declarations: []const u8,
};

const CssSelector = union(enum) {
    element: []const u8,
    class: []const u8,
    id: []const u8,
};

const ReferenceFrame = struct {
    search_index: usize,
    scan_end: usize,
    transform_depth: usize,
};

const ReferencedElement = struct {
    tag: []const u8,
    content_start: usize,
    content_end: usize,
};

pub const Error = error{
    InvalidSvg,
    InvalidPath,
    UnsupportedSvgElement,
    UnsupportedSvgStroke,
};

pub fn sourceForIconId(icon_id: u32) []const u8 {
    const value = icon.fromId(icon_id) orelse return "";
    return source(value);
}

pub fn source(value: icon.Icon) []const u8 {
    return switch (value) {
        .activity => @embedFile("icons/tabler/activity.svg"),
        .app => @embedFile("icons/tabler/apps.svg"),
        .bell => @embedFile("icons/tabler/bell.svg"),
        .chat => @embedFile("icons/tabler/message-circle.svg"),
        .check => @embedFile("icons/tabler/check.svg"),
        .chevron_right => @embedFile("icons/tabler/chevron-right.svg"),
        .code => @embedFile("icons/tabler/code.svg"),
        .cpu => @embedFile("icons/tabler/cpu.svg"),
        .database, .storage => @embedFile("icons/tabler/database.svg"),
        .eye => @embedFile("icons/tabler/eye.svg"),
        .file => @embedFile("icons/tabler/file.svg"),
        .key => @embedFile("icons/tabler/key.svg"),
        .lock => @embedFile("icons/tabler/lock.svg"),
        .menu => @embedFile("icons/tabler/menu-2.svg"),
        .message_plus => @embedFile("icons/tabler/message-plus.svg"),
        .network => @embedFile("icons/tabler/network.svg"),
        .route => @embedFile("icons/tabler/route.svg"),
        .search => @embedFile("icons/tabler/search.svg"),
        .send => @embedFile("icons/tabler/arrow-up.svg"),
        .server => @embedFile("icons/tabler/server.svg"),
        .settings => @embedFile("icons/tabler/settings.svg"),
        .shield, .trust => @embedFile("icons/tabler/shield-check.svg"),
        .sparkles => @embedFile("icons/tabler/sparkles.svg"),
        .terminal => @embedFile("icons/tabler/terminal-2.svg"),
        .trash => @embedFile("icons/tabler/trash.svg"),
        .user => @embedFile("icons/tabler/user.svg"),
        .wallet => @embedFile("icons/tabler/wallet.svg"),
        .warning => @embedFile("icons/tabler/alert-triangle.svg"),
        .x => @embedFile("icons/tabler/x.svg"),
        .github => @embedFile("icons/tabler/brand-github.svg"),
    };
}

pub const Iterator = struct {
    svg: []const u8,
    search_index: usize = 0,
    scan_end: usize = 0,
    path: ?PathIterator = null,
    path_replay: ?PathIterator = null,
    path_paint_mode: ?PaintMode = null,
    path_stroke_color: SvgPaint = .current_color,
    view_box: ViewBox = default_view_box,
    invalid_svg: bool = false,
    init_error: ?Error = null,
    line_points: [4]f32 = .{ 0.0, 0.0, 0.0, 0.0 },
    pending_ops: [max_pending_ops]icon_vector.Op = undefined,
    pending_start: usize = 0,
    pending_len: usize = 0,
    transform_stack: [max_transform_depth]Transform = undefined,
    presentation_stack: [max_transform_depth]Presentation = undefined,
    render_state_stack: [max_transform_depth]RenderState = undefined,
    transform_depth: usize = 0,
    reference_stack: [max_reference_depth]ReferenceFrame = undefined,
    reference_depth: usize = 0,
    root_presentation: Presentation = .{},
    root_render_state: RenderState = .{},
    css_rules: CssRules = CssRules.empty(),
    output_paint: SvgPaint = .current_color,

    pub fn init(svg: []const u8) Iterator {
        const root = parseSvgRoot(svg) catch |err| return .{ .svg = svg, .invalid_svg = true, .init_error = err };
        const css_rules = parseCssRules(svg) catch |err| return .{ .svg = svg, .invalid_svg = true, .init_error = err };
        return .{
            .svg = svg,
            .scan_end = svg.len,
            .view_box = root.view_box,
            .root_presentation = root.presentation,
            .root_render_state = root.render_state,
            .css_rules = css_rules,
        };
    }

    pub fn next(self: *Iterator) Error!?icon_vector.Op {
        if (self.invalid_svg) return self.init_error orelse error.InvalidSvg;
        while (true) {
            if (self.takePending()) |op| return op;
            if (self.path) |*path| {
                if (try path.next()) |op| return op;
                self.path = null;
                if (self.path_paint_mode == .fill_then_stroke) {
                    self.path = self.path_replay;
                    self.path_replay = null;
                    self.path_paint_mode = .stroke;
                    self.pushPaint(self.path_stroke_color);
                    return .end_fill_path;
                }
                if (self.path_paint_mode == .fill) {
                    self.path_paint_mode = null;
                    return .end_fill_path;
                }
                self.path_paint_mode = null;
            }
            const element = try self.nextElement() orelse return null;
            switch (element.kind) {
                .path => {
                    const d = try attrValue(element.tag, "d");
                    const path_transform = try combineElementTransform(element.transform, element.tag);
                    self.path = PathIterator.initWithViewBoxTransform(d, self.view_box, path_transform);
                    self.path_paint_mode = element.paint_mode;
                    if (element.paint_mode == .fill_then_stroke) {
                        self.path_replay = PathIterator.initWithViewBoxTransform(d, self.view_box, path_transform);
                        self.path_stroke_color = element.stroke_color;
                        self.pushPaint(element.fill_color);
                        self.pushPending(beginFillPathOp(element.fill_rule));
                        return self.takePending().?;
                    }
                    if (element.paint_mode == .fill) {
                        self.pushPaint(element.fill_color);
                        self.pushPending(beginFillPathOp(element.fill_rule));
                        return self.takePending().?;
                    }
                    if (element.paint_mode == .stroke) {
                        self.pushPaint(element.stroke_color);
                        if (self.takePending()) |op| return op;
                    }
                },
                .circle => return try self.circleOp(element),
                .ellipse => return try self.ellipseOp(element),
                .line => return try self.lineOp(element),
                .polyline => {
                    try self.enqueuePointList(element.tag, element.transform, false, element.paint_mode, element.fill_rule, element.fill_color, element.stroke_color);
                    return self.takePending();
                },
                .polygon => {
                    try self.enqueuePointList(element.tag, element.transform, true, element.paint_mode, element.fill_rule, element.fill_color, element.stroke_color);
                    return self.takePending();
                },
                .rect => return try self.rectOp(element),
            }
        }
    }

    pub fn nextPathData(self: *Iterator) Error!?[]const u8 {
        const element = try self.nextElement() orelse return null;
        if (element.kind != .path) return error.InvalidSvg;
        const value = try attrValue(element.tag, "d");
        return value;
    }

    fn nextElement(self: *Iterator) Error!?SvgElement {
        while (true) {
            if (self.search_index >= self.scan_end) {
                if (!self.popReferenceFrame()) {
                    if (self.transform_depth != 0) return error.InvalidSvg;
                    return null;
                }
                continue;
            }
            const tag_start_offset = std.mem.indexOfScalar(u8, self.svg[self.search_index..], '<') orelse {
                if (!self.popReferenceFrame()) {
                    if (self.transform_depth != 0) return error.InvalidSvg;
                    return null;
                }
                continue;
            };
            const tag_start = self.search_index + tag_start_offset;
            if (tag_start >= self.scan_end) {
                if (!self.popReferenceFrame()) {
                    if (self.transform_depth != 0) return error.InvalidSvg;
                    return null;
                }
                continue;
            }
            if (try skipSpecialMarkup(self.svg, tag_start, &self.search_index)) continue;
            const tag_end = try svgTagEnd(self.svg, tag_start);
            if (tag_end > self.scan_end) return error.InvalidSvg;
            const tag = self.svg[tag_start..tag_end];
            self.search_index = tag_end + 1;

            if (isIgnorableTag(tag)) continue;
            if (isGroupCloseTag(tag)) {
                if (self.transform_depth == 0) return error.InvalidSvg;
                self.transform_depth -= 1;
                continue;
            }
            if (isGroupOpenTag(tag)) {
                const group_render_state = try renderStateForTag(self.currentRenderState(), tag, &self.css_rules);
                if (!group_render_state.hidesSelf()) try validateSupportedPresentationTag(tag);
                const group_presentation = if (group_render_state.hidesSelf()) self.currentPresentation() else try presentationForTag(self.currentPresentation(), tag, &self.css_rules);
                const group_transform = if (group_render_state.subtree_hidden) self.currentTransform() else try combineElementTransform(self.currentTransform(), tag);
                try self.pushTransform(group_transform);
                self.presentation_stack[self.transform_depth - 1] = group_presentation;
                self.render_state_stack[self.transform_depth - 1] = group_render_state;
                if (isSelfClosingTag(tag)) self.popTransform();
                continue;
            }
            if (isMetadataTag(tag)) continue;
            if (isStyleTag(tag)) {
                self.search_index = try styleCloseEnd(self.svg, self.search_index);
                continue;
            }
            if (isDefsOpenTag(tag)) {
                if (!isSelfClosingTag(tag)) self.search_index = try containerCloseEnd(self.svg, self.search_index, "defs");
                continue;
            }
            if (isDefsCloseTag(tag)) return error.InvalidSvg;
            if (isSupportedElementCloseTag(tag)) continue;
            const render_state = try renderStateForTag(self.currentRenderState(), tag, &self.css_rules);
            if (render_state.hidesSelf()) continue;
            if (isUseTag(tag)) {
                if (try self.useElement(tag)) |element| return element;
                continue;
            }
            if (unsupportedElementTag(tag)) return error.UnsupportedSvgElement;
            if (supportedElementKind(tag)) |kind| {
                try validateSupportedPresentationTag(tag);
                const presentation = try presentationForTag(self.currentPresentation(), tag, &self.css_rules);
                const paint_mode = presentation.paintMode(kind) orelse {
                    if (presentation.hasVisiblePaint()) return error.UnsupportedSvgStroke;
                    continue;
                };
                return .{ .kind = kind, .tag = tag, .transform = self.currentTransform(), .paint_mode = paint_mode, .fill_rule = presentation.fill_rule, .fill_color = presentation.fill_color, .stroke_color = presentation.stroke_color };
            }
            return error.UnsupportedSvgElement;
        }
    }

    fn useElement(self: *Iterator, use_tag: []const u8) Error!?SvgElement {
        try validateUseReferenceTag(use_tag);
        const reference_id = try useReferenceId(use_tag);
        const referenced = try findReferencedElement(self.svg, reference_id);
        const reference_tag = referenced.tag;
        if (isUseTag(reference_tag)) return error.UnsupportedSvgElement;
        if (unsupportedElementTag(reference_tag)) return error.UnsupportedSvgElement;
        if (supportedElementKind(reference_tag)) |kind| return try self.useGraphicElement(use_tag, reference_tag, kind);
        if (isReusableContainerOpenTag(reference_tag)) {
            try self.useContainerElement(use_tag, referenced);
            return null;
        }
        return error.UnsupportedSvgElement;
    }

    fn useGraphicElement(self: *Iterator, use_tag: []const u8, reference_tag: []const u8, kind: SvgElementKind) Error!?SvgElement {
        const use_render_state = try renderStateForTag(self.currentRenderState(), use_tag, &self.css_rules);
        if (use_render_state.hidesSelf()) return null;
        const use_presentation = try presentationForTag(self.currentPresentation(), use_tag, &self.css_rules);
        const reference_render_state = try renderStateForTag(use_render_state, reference_tag, &self.css_rules);
        if (reference_render_state.hidesSelf()) return null;
        try validateSupportedPresentationTag(reference_tag);
        const presentation = try presentationForTag(use_presentation, reference_tag, &self.css_rules);
        const paint_mode = presentation.paintMode(kind) orelse {
            if (presentation.hasVisiblePaint()) return error.UnsupportedSvgStroke;
            return null;
        };
        const use_transform = try combineElementTransform(self.currentTransform(), use_tag);
        const translated = appendTransform(use_transform, try useTranslation(use_tag));
        return .{
            .kind = kind,
            .tag = reference_tag,
            .transform = translated,
            .paint_mode = paint_mode,
            .fill_rule = presentation.fill_rule,
            .fill_color = presentation.fill_color,
            .stroke_color = presentation.stroke_color,
        };
    }

    fn useContainerElement(self: *Iterator, use_tag: []const u8, referenced: ReferencedElement) Error!void {
        const use_render_state = try renderStateForTag(self.currentRenderState(), use_tag, &self.css_rules);
        if (use_render_state.hidesSelf()) return;
        const use_presentation = try presentationForTag(self.currentPresentation(), use_tag, &self.css_rules);
        const reference_render_state = try renderStateForTag(use_render_state, referenced.tag, &self.css_rules);
        if (reference_render_state.hidesSelf()) return;
        try validateSupportedPresentationTag(referenced.tag);
        const presentation = try presentationForTag(use_presentation, referenced.tag, &self.css_rules);
        const use_transform = try combineElementTransform(self.currentTransform(), use_tag);
        const translated = appendTransform(use_transform, try useTranslation(use_tag));
        const reference_transform = try combineElementTransform(translated, referenced.tag);
        try self.pushReferenceFrame(referenced.content_start, referenced.content_end, reference_transform, presentation, reference_render_state);
    }

    fn circleOp(self: *Iterator, element: SvgElement) Error!icon_vector.Op {
        const tag = element.tag;
        const paint_mode = element.paint_mode;
        const transform = try combineElementTransform(element.transform, tag);
        if (!transform.isAxisAligned() and !transform.isUniformRotationScale()) return error.UnsupportedSvgElement;
        const center = try self.normalizePoint(transform.apply(.{ .x = try attrNumberDefault(tag, "cx", 0.0), .y = try attrNumberDefault(tag, "cy", 0.0) }));
        const rx = try self.normalizeWidth(transform.scaleX(try attrNumber(tag, "r")));
        const ry = try self.normalizeHeight(transform.scaleY(try attrNumber(tag, "r")));
        const cx = center.x;
        const cy = center.y;
        const fill_op = if (rx == ry) icon_vector.Op{ .filled_circle = .{ .cx = cx, .cy = cy, .radius = rx } } else icon_vector.Op{ .filled_ellipse = .{ .cx = cx, .cy = cy, .rx = rx, .ry = ry, .full = true } };
        const stroke_op = if (rx == ry) icon_vector.Op{ .circle = .{ .cx = cx, .cy = cy, .radius = rx } } else icon_vector.Op{ .ellipse = .{ .cx = cx, .cy = cy, .rx = rx, .ry = ry, .full = true } };
        return self.opForPaintMode(paint_mode, element.fill_color, element.stroke_color, fill_op, stroke_op);
    }

    fn ellipseOp(self: *Iterator, element: SvgElement) Error!icon_vector.Op {
        const tag = element.tag;
        const paint_mode = element.paint_mode;
        const transform = try combineElementTransform(element.transform, tag);
        if (!transform.isAxisAlignedPositive()) return error.UnsupportedSvgElement;
        const center = try self.normalizePoint(transform.apply(.{ .x = try attrNumberDefault(tag, "cx", 0.0), .y = try attrNumberDefault(tag, "cy", 0.0) }));
        const ellipse = icon_vector.Ellipse{
            .cx = center.x,
            .cy = center.y,
            .rx = try self.normalizeWidth(transform.scaleX(try attrNumber(tag, "rx"))),
            .ry = try self.normalizeHeight(transform.scaleY(try attrNumber(tag, "ry"))),
            .full = true,
        };
        return self.opForPaintMode(paint_mode, element.fill_color, element.stroke_color, .{ .filled_ellipse = ellipse }, .{ .ellipse = ellipse });
    }

    fn lineOp(self: *Iterator, element: SvgElement) Error!icon_vector.Op {
        const tag = element.tag;
        const transform = try combineElementTransform(element.transform, tag);
        const start = try self.normalizePoint(transform.apply(.{ .x = try attrNumberDefault(tag, "x1", 0.0), .y = try attrNumberDefault(tag, "y1", 0.0) }));
        const end = try self.normalizePoint(transform.apply(.{ .x = try attrNumberDefault(tag, "x2", 0.0), .y = try attrNumberDefault(tag, "y2", 0.0) }));
        self.line_points = .{
            start.x,
            start.y,
            end.x,
            end.y,
        };
        self.pushPaint(element.stroke_color);
        self.pushPending(.{ .polyline = self.line_points[0..] });
        return self.takePending().?;
    }

    fn rectOp(self: *Iterator, element: SvgElement) Error!icon_vector.Op {
        const tag = element.tag;
        const paint_mode = element.paint_mode;
        const transform = try combineElementTransform(element.transform, tag);
        if (!transform.isAxisAlignedPositive()) return error.UnsupportedSvgElement;
        const width = try attrNumber(tag, "width");
        const height = try attrNumber(tag, "height");
        const radius = try rectCornerRadius(tag, width, height);
        const x = (try attrNumberOptional(tag, "x")) orelse 0.0;
        const y = (try attrNumberOptional(tag, "y")) orelse 0.0;
        const origin = try self.normalizePoint(transform.apply(.{ .x = x, .y = y }));
        const rect = icon_vector.RoundRect{
            .x = origin.x,
            .y = origin.y,
            .w = try self.normalizeWidth(transform.scaleX(width)),
            .h = try self.normalizeHeight(transform.scaleY(height)),
            .radius = try self.normalizeWidth(transform.scaleX(radius)),
        };
        return self.opForPaintMode(paint_mode, element.fill_color, element.stroke_color, .{ .filled_round_rect = rect }, .{ .round_rect = rect });
    }

    fn paintModeForCurrentTag(self: Iterator, tag: []const u8, kind: SvgElementKind) Error!PaintMode {
        const presentation = try presentationForTag(self.currentPresentation(), tag, &self.css_rules);
        return presentation.paintMode(kind) orelse error.UnsupportedSvgStroke;
    }

    fn opForPaintMode(self: *Iterator, paint_mode: PaintMode, fill_color: SvgPaint, stroke_color: SvgPaint, fill_op: icon_vector.Op, stroke_op: icon_vector.Op) Error!icon_vector.Op {
        switch (paint_mode) {
            .fill => {
                self.pushPaint(fill_color);
                self.pushPending(fill_op);
                return self.takePending().?;
            },
            .stroke => {
                self.pushPaint(stroke_color);
                self.pushPending(stroke_op);
                return self.takePending().?;
            },
            .fill_then_stroke => {
                self.pushPaint(fill_color);
                self.pushPending(fill_op);
                self.pushPaint(stroke_color);
                self.pushPending(stroke_op);
                return self.takePending().?;
            },
        }
    }

    fn beginFillPathOp(fill_rule: FillRule) icon_vector.Op {
        return switch (fill_rule) {
            .nonzero => .begin_fill_path,
            .evenodd => .begin_evenodd_fill_path,
        };
    }

    fn enqueuePointList(self: *Iterator, tag: []const u8, inherited_transform: Transform, close: bool, paint_mode: PaintMode, fill_rule: FillRule, fill_color: SvgPaint, stroke_color: SvgPaint) Error!void {
        if (self.pending_len != 0) return error.InvalidSvg;
        const points = try attrValue(tag, "points");
        var values = NumberList.init(points);
        const first_x = try values.next();
        const first_y = try values.next();
        const transform = try combineElementTransform(inherited_transform, tag);
        const first = try self.normalizePoint(transform.apply(.{ .x = first_x, .y = first_y }));
        if (paint_mode == .fill or paint_mode == .fill_then_stroke) {
            self.pushPaint(fill_color);
            self.pushPending(beginFillPathOp(fill_rule));
        }
        if (paint_mode == .stroke) self.pushPaint(stroke_color);
        self.pushPending(.{ .move_to = first });
        while (try values.hasMore()) {
            const next_x = try values.next();
            const next_y = try values.next();
            const normalized = try self.normalizePoint(transform.apply(.{ .x = next_x, .y = next_y }));
            const next_point = icon_vector.Point{
                .x = normalized.x,
                .y = normalized.y,
            };
            self.pushPending(.{ .line_to = next_point });
        }
        if (close or paint_mode == .fill or paint_mode == .fill_then_stroke) self.pushPending(.close_path);
        if (paint_mode == .fill or paint_mode == .fill_then_stroke) self.pushPending(.end_fill_path);
        if (paint_mode == .fill_then_stroke) {
            self.pushPaint(stroke_color);
            self.pushPending(.{ .move_to = first });
            var stroke_values = NumberList.init(points);
            _ = try stroke_values.next();
            _ = try stroke_values.next();
            while (try stroke_values.hasMore()) {
                const next_x = try stroke_values.next();
                const next_y = try stroke_values.next();
                const normalized = try self.normalizePoint(transform.apply(.{ .x = next_x, .y = next_y }));
                self.pushPending(.{ .line_to = .{ .x = normalized.x, .y = normalized.y } });
            }
            if (close) self.pushPending(.close_path);
        }
    }

    fn pushPending(self: *Iterator, op: icon_vector.Op) void {
        if (self.pending_len >= max_pending_ops) unreachable;
        self.pending_ops[self.pending_len] = op;
        self.pending_len += 1;
    }

    fn pushPaint(self: *Iterator, paint: SvgPaint) void {
        if (svgPaintsEqual(self.output_paint, paint)) return;
        switch (paint) {
            .current_color => self.pushPending(.paint_current_color),
            .solid => |color| self.pushPending(.{ .paint_rgba = color }),
        }
        self.output_paint = paint;
    }

    fn takePending(self: *Iterator) ?icon_vector.Op {
        if (self.pending_start >= self.pending_len) {
            self.pending_start = 0;
            self.pending_len = 0;
            return null;
        }
        const op = self.pending_ops[self.pending_start];
        self.pending_start += 1;
        return op;
    }

    fn normalizeX(self: Iterator, value: f32) Error!f32 {
        return (value - self.view_box.min_x) / self.view_box.width;
    }

    fn normalizeY(self: Iterator, value: f32) Error!f32 {
        return (value - self.view_box.min_y) / self.view_box.height;
    }

    fn normalizePoint(self: Iterator, value: icon_vector.Point) Error!icon_vector.Point {
        return .{ .x = try self.normalizeX(value.x), .y = try self.normalizeY(value.y) };
    }

    fn normalizeWidth(self: Iterator, value: f32) Error!f32 {
        if (value < 0.0) return error.InvalidSvg;
        return value / self.view_box.width;
    }

    fn normalizeHeight(self: Iterator, value: f32) Error!f32 {
        if (value < 0.0) return error.InvalidSvg;
        return value / self.view_box.height;
    }

    fn currentTransform(self: Iterator) Transform {
        if (self.transform_depth == 0) return .{};
        return self.transform_stack[self.transform_depth - 1];
    }

    fn currentPresentation(self: Iterator) Presentation {
        if (self.transform_depth == 0) return self.root_presentation;
        return self.presentation_stack[self.transform_depth - 1];
    }

    fn currentRenderState(self: Iterator) RenderState {
        if (self.transform_depth == 0) return self.root_render_state;
        return self.render_state_stack[self.transform_depth - 1];
    }

    fn pushTransform(self: *Iterator, transform: Transform) Error!void {
        if (self.transform_depth >= max_transform_depth) return error.InvalidSvg;
        self.transform_stack[self.transform_depth] = transform;
        self.transform_depth += 1;
    }

    fn popTransform(self: *Iterator) void {
        self.transform_depth -= 1;
    }

    fn pushReferenceFrame(self: *Iterator, content_start: usize, content_end: usize, transform: Transform, presentation: Presentation, render_state: RenderState) Error!void {
        if (self.reference_depth >= max_reference_depth) return error.UnsupportedSvgElement;
        self.reference_stack[self.reference_depth] = .{
            .search_index = self.search_index,
            .scan_end = self.scan_end,
            .transform_depth = self.transform_depth,
        };
        self.reference_depth += 1;
        try self.pushTransform(transform);
        self.presentation_stack[self.transform_depth - 1] = presentation;
        self.render_state_stack[self.transform_depth - 1] = render_state;
        self.search_index = content_start;
        self.scan_end = content_end;
    }

    fn popReferenceFrame(self: *Iterator) bool {
        if (self.reference_depth == 0) return false;
        self.reference_depth -= 1;
        const frame = self.reference_stack[self.reference_depth];
        self.search_index = frame.search_index;
        self.scan_end = frame.scan_end;
        self.transform_depth = frame.transform_depth;
        return true;
    }
};

pub fn validateSupportedTablerStroke(svg: []const u8) Error!void {
    for (unsupported_svg_elements) |element| {
        if (svgContainsElementTag(svg, element)) return error.UnsupportedSvgElement;
    }
    var iter = Iterator.init(svg);
    var count: usize = 0;
    while (try iter.next()) |_| count += 1;
    if (count == 0) return error.InvalidSvg;
}

pub const PathIterator = struct {
    data: []const u8,
    index: usize = 0,
    command: u8 = 0,
    view_box: ViewBox = default_view_box,
    current: icon_vector.Point = .{ .x = 0.0, .y = 0.0 },
    subpath_start: icon_vector.Point = .{ .x = 0.0, .y = 0.0 },
    previous_cubic_control: ?icon_vector.Point = null,
    previous_quadratic_control: ?icon_vector.Point = null,
    transform: Transform = .{},
    started: bool = false,

    pub fn init(data: []const u8) PathIterator {
        return .{ .data = data };
    }

    pub fn initWithViewBox(data: []const u8, view_box: ViewBox) PathIterator {
        return .{ .data = data, .view_box = view_box };
    }

    pub fn initWithViewBoxTransform(data: []const u8, view_box: ViewBox, transform: Transform) PathIterator {
        return .{ .data = data, .view_box = view_box, .transform = transform };
    }

    pub fn next(self: *PathIterator) Error!?icon_vector.Op {
        try self.skipSeparators();
        if (self.index >= self.data.len) return null;
        if (isCommand(self.data[self.index])) {
            self.command = self.data[self.index];
            self.index += 1;
        }
        if (!self.started and self.command != 'M' and self.command != 'm') return error.InvalidPath;
        return switch (self.command) {
            'M', 'm' => self.moveTo(),
            'L', 'l' => self.lineTo(),
            'H', 'h' => self.horizontalLineTo(),
            'V', 'v' => self.verticalLineTo(),
            'C', 'c' => self.cubicTo(),
            'S', 's' => self.smoothCubicTo(),
            'Q', 'q' => self.quadraticTo(),
            'T', 't' => self.smoothQuadraticTo(),
            'A', 'a' => self.arcTo(),
            'Z', 'z' => self.closePath(),
            else => error.InvalidPath,
        };
    }

    fn moveTo(self: *PathIterator) Error!?icon_vector.Op {
        const relative = self.command == 'm';
        const target = try self.point(relative);
        self.current = target;
        self.subpath_start = target;
        self.previous_cubic_control = null;
        self.previous_quadratic_control = null;
        self.started = true;
        self.command = if (relative) 'l' else 'L';
        return .{ .move_to = self.normalizePoint(target) };
    }

    fn lineTo(self: *PathIterator) Error!?icon_vector.Op {
        const target = try self.point(self.command == 'l');
        self.current = target;
        self.previous_cubic_control = null;
        self.previous_quadratic_control = null;
        return .{ .line_to = self.normalizePoint(target) };
    }

    fn horizontalLineTo(self: *PathIterator) Error!?icon_vector.Op {
        const x = try self.number();
        const next_x = if (self.command == 'h') self.current.x + x else x;
        self.current = .{ .x = next_x, .y = self.current.y };
        self.previous_cubic_control = null;
        self.previous_quadratic_control = null;
        return .{ .line_to = self.normalizePoint(self.current) };
    }

    fn verticalLineTo(self: *PathIterator) Error!?icon_vector.Op {
        const y = try self.number();
        const next_y = if (self.command == 'v') self.current.y + y else y;
        self.current = .{ .x = self.current.x, .y = next_y };
        self.previous_cubic_control = null;
        self.previous_quadratic_control = null;
        return .{ .line_to = self.normalizePoint(self.current) };
    }

    fn cubicTo(self: *PathIterator) Error!?icon_vector.Op {
        const relative = self.command == 'c';
        const c0 = try self.point(relative);
        const c1 = try self.point(relative);
        const end = try self.point(relative);
        self.current = end;
        self.previous_cubic_control = c1;
        self.previous_quadratic_control = null;
        return .{ .cubic_to = .{ .control0 = self.normalizePoint(c0), .control1 = self.normalizePoint(c1), .end = self.normalizePoint(end) } };
    }

    fn smoothCubicTo(self: *PathIterator) Error!?icon_vector.Op {
        const relative = self.command == 's';
        const reflected = if (self.previous_cubic_control) |control| icon_vector.Point{
            .x = self.current.x * 2.0 - control.x,
            .y = self.current.y * 2.0 - control.y,
        } else self.current;
        const c1 = try self.point(relative);
        const end = try self.point(relative);
        self.current = end;
        self.previous_cubic_control = c1;
        self.previous_quadratic_control = null;
        return .{ .cubic_to = .{ .control0 = self.normalizePoint(reflected), .control1 = self.normalizePoint(c1), .end = self.normalizePoint(end) } };
    }

    fn quadraticTo(self: *PathIterator) Error!?icon_vector.Op {
        const relative = self.command == 'q';
        const control = try self.point(relative);
        const end = try self.point(relative);
        self.current = end;
        self.previous_cubic_control = null;
        self.previous_quadratic_control = control;
        return .{ .quad_to = .{ .control = self.normalizePoint(control), .end = self.normalizePoint(end) } };
    }

    fn smoothQuadraticTo(self: *PathIterator) Error!?icon_vector.Op {
        const relative = self.command == 't';
        const reflected = if (self.previous_quadratic_control) |control| icon_vector.Point{
            .x = self.current.x * 2.0 - control.x,
            .y = self.current.y * 2.0 - control.y,
        } else self.current;
        const end = try self.point(relative);
        self.current = end;
        self.previous_cubic_control = null;
        self.previous_quadratic_control = reflected;
        return .{ .quad_to = .{ .control = self.normalizePoint(reflected), .end = self.normalizePoint(end) } };
    }

    fn arcTo(self: *PathIterator) Error!?icon_vector.Op {
        const relative = self.command == 'a';
        const rx = @abs(try self.number());
        const ry = @abs(try self.number());
        const rotation = try self.number();
        const large_arc = try self.flag();
        const sweep = try self.flag();
        const end = try self.point(relative);
        if (rx <= transform_epsilon or ry <= transform_epsilon) {
            self.current = end;
            self.previous_cubic_control = null;
            self.previous_quadratic_control = null;
            return .{ .line_to = self.normalizePoint(end) };
        }
        if (!self.transform.isAxisAligned() and !self.transform.isUniformRotationScale()) return error.UnsupportedSvgElement;
        self.current = end;
        self.previous_cubic_control = null;
        self.previous_quadratic_control = null;
        const transformed_rx = self.transform.scaleX(rx);
        const transformed_ry = self.transform.scaleY(ry);
        if (transformed_rx <= transform_epsilon or transformed_ry <= transform_epsilon) return .{ .line_to = self.normalizePoint(end) };
        const transformed_rotation = if (self.transform.isUniformRotationScale()) rotation + self.transform.rotationDegrees() else rotation;
        return .{ .arc_to = .{
            .rx = transformed_rx / self.view_box.width,
            .ry = transformed_ry / self.view_box.height,
            .x_axis_rotation = transformed_rotation,
            .large_arc = large_arc,
            .sweep = sweep,
            .end = self.normalizePoint(end),
        } };
    }

    fn closePath(self: *PathIterator) Error!?icon_vector.Op {
        self.current = self.subpath_start;
        self.previous_cubic_control = null;
        self.previous_quadratic_control = null;
        self.command = 0;
        return .close_path;
    }

    fn point(self: *PathIterator, relative: bool) Error!icon_vector.Point {
        const x = try self.number();
        const y = try self.number();
        if (relative) return .{ .x = self.current.x + x, .y = self.current.y + y };
        return .{ .x = x, .y = y };
    }

    fn flag(self: *PathIterator) Error!bool {
        try self.skipSeparators();
        if (self.index >= self.data.len) return error.InvalidPath;
        const value = self.data[self.index];
        if (value == '0') {
            self.index += 1;
            return false;
        }
        if (value == '1') {
            self.index += 1;
            return true;
        }
        return error.InvalidPath;
    }

    fn number(self: *PathIterator) Error!f32 {
        return parseSvgNumber(self.data, &self.index, error.InvalidPath);
    }

    fn skipSeparators(self: *PathIterator) Error!void {
        try skipSvgNumberSeparators(self.data, &self.index, error.InvalidPath);
    }

    fn normalizePoint(self: PathIterator, value: icon_vector.Point) icon_vector.Point {
        const transformed = self.transform.apply(value);
        return .{
            .x = (transformed.x - self.view_box.min_x) / self.view_box.width,
            .y = (transformed.y - self.view_box.min_y) / self.view_box.height,
        };
    }
};

fn isCommand(value: u8) bool {
    return switch (value) {
        'M', 'm', 'L', 'l', 'H', 'h', 'V', 'v', 'C', 'c', 'S', 's', 'Q', 'q', 'T', 't', 'A', 'a', 'Z', 'z' => true,
        else => false,
    };
}

const SvgElementKind = enum {
    path,
    circle,
    ellipse,
    line,
    polyline,
    polygon,
    rect,
};

const SvgElement = struct {
    kind: SvgElementKind,
    tag: []const u8,
    transform: Transform,
    paint_mode: PaintMode,
    fill_rule: FillRule,
    fill_color: SvgPaint,
    stroke_color: SvgPaint,
};

fn parseSvgRoot(svg: []const u8) Error!SvgRoot {
    const tag = try svgRootTag(svg);
    const raw = try attrValue(tag, "viewBox");
    var values = NumberList.init(raw);
    const min_x = try values.next();
    const min_y = try values.next();
    const width = try values.next();
    const height = try values.next();
    if (try values.hasMore()) return error.InvalidSvg;
    if (width <= 0.0 or height <= 0.0) return error.InvalidSvg;
    try validateSupportedPresentationTag(tag);
    return .{
        .view_box = .{ .min_x = min_x, .min_y = min_y, .width = width, .height = height },
        .presentation = try presentationForTag(.{}, tag, &empty_css_rules),
        .render_state = try renderStateForTag(.{}, tag, &empty_css_rules),
    };
}

fn svgRootTag(svg: []const u8) Error![]const u8 {
    var search_index: usize = 0;
    while (search_index < svg.len) {
        const tag_start_offset = std.mem.indexOfScalar(u8, svg[search_index..], '<') orelse return error.InvalidSvg;
        const tag_start = search_index + tag_start_offset;
        if (try skipSpecialMarkup(svg, tag_start, &search_index)) continue;
        const tag_end = try svgTagEnd(svg, tag_start);
        const tag = svg[tag_start..tag_end];
        search_index = tag_end + 1;
        if (std.mem.startsWith(u8, tag, "<?") or std.mem.startsWith(u8, tag, "<!")) continue;
        if (tagHasName(tag, "svg")) return tag;
        return error.InvalidSvg;
    }
    return error.InvalidSvg;
}

fn parseCssRules(svg: []const u8) Error!CssRules {
    var rules = CssRules.empty();
    var search_index: usize = 0;
    while (search_index < svg.len) {
        const tag_start_offset = std.mem.indexOfScalar(u8, svg[search_index..], '<') orelse return rules;
        const tag_start = search_index + tag_start_offset;
        if (try skipSpecialMarkup(svg, tag_start, &search_index)) continue;
        const tag_end = try svgTagEnd(svg, tag_start);
        const tag = svg[tag_start..tag_end];
        search_index = tag_end + 1;
        if (!isStyleTag(tag)) continue;
        try validateSupportedStyleTag(tag);
        const close_start = styleCloseStart(svg, search_index) orelse return error.InvalidSvg;
        try parseCssRuleBlock(svg[search_index..close_start], &rules);
        search_index = try styleCloseEnd(svg, search_index);
    }
    return rules;
}

fn validateSupportedStyleTag(tag: []const u8) Error!void {
    if (try attrValueOptional(tag, "type")) |value| {
        if (!supportedKeyword(value, "text/css")) return error.UnsupportedSvgElement;
    }
}

fn parseCssRuleBlock(css: []const u8, rules: *CssRules) Error!void {
    var index: usize = 0;
    while (true) {
        try skipCssWhitespaceAndComments(css, &index);
        if (index >= css.len) return;
        if (css[index] == '@') return error.UnsupportedSvgElement;
        const selector_start = index;
        while (index < css.len and css[index] != '{') : (index += 1) {}
        if (index >= css.len) return error.InvalidSvg;
        const selectors = trimAscii(css[selector_start..index]);
        index += 1;
        const declarations_start = index;
        while (index < css.len and css[index] != '}') : (index += 1) {}
        if (index >= css.len) return error.InvalidSvg;
        const declarations = css[declarations_start..index];
        index += 1;
        try appendCssSelectors(selectors, declarations, rules);
    }
}

fn appendCssSelectors(selectors: []const u8, declarations: []const u8, rules: *CssRules) Error!void {
    var start: usize = 0;
    while (start < selectors.len) {
        const end = if (std.mem.indexOfScalar(u8, selectors[start..], ',')) |offset| start + offset else selectors.len;
        const selector = trimAscii(selectors[start..end]);
        start = end + 1;
        if (selector.len == 0) return error.InvalidSvg;
        try rules.append(.{ .selector = try parseCssSelector(selector), .declarations = declarations });
    }
}

fn parseCssSelector(selector: []const u8) Error!CssSelector {
    if (selector[0] == '.') {
        const name = selector[1..];
        if (!validCssSimpleName(name)) return error.UnsupportedSvgElement;
        return .{ .class = name };
    }
    if (selector[0] == '#') {
        const name = selector[1..];
        if (!validCssSimpleName(name)) return error.UnsupportedSvgElement;
        return .{ .id = name };
    }
    if (!validCssSimpleName(selector)) return error.UnsupportedSvgElement;
    return .{ .element = selector };
}

fn validCssSimpleName(value: []const u8) bool {
    if (value.len == 0) return false;
    for (value) |byte| {
        if (std.ascii.isAlphanumeric(byte) or byte == '-' or byte == '_') continue;
        return false;
    }
    return true;
}

fn skipCssWhitespaceAndComments(css: []const u8, index: *usize) Error!void {
    while (index.* < css.len) {
        while (index.* < css.len and std.ascii.isWhitespace(css[index.*])) : (index.* += 1) {}
        if (index.* + css_comment_open.len <= css.len and std.mem.eql(u8, css[index.* .. index.* + css_comment_open.len], css_comment_open)) {
            const close_offset = std.mem.indexOf(u8, css[index.* + css_comment_open.len ..], css_comment_close) orelse return error.InvalidSvg;
            index.* = index.* + css_comment_open.len + close_offset + css_comment_close.len;
            continue;
        }
        return;
    }
}

fn attrNumber(tag: []const u8, name: []const u8) Error!f32 {
    return parseLengthPx(try attrValue(tag, name));
}

fn attrNumberOptional(tag: []const u8, name: []const u8) Error!?f32 {
    const value = (try attrValueOptional(tag, name)) orelse return null;
    return try parseLengthPx(value);
}

fn attrNumberDefault(tag: []const u8, name: []const u8, default: f32) Error!f32 {
    return (try attrNumberOptional(tag, name)) orelse default;
}

fn rectCornerRadius(tag: []const u8, width: f32, height: f32) Error!f32 {
    const maybe_rx = try attrNumberOptional(tag, "rx");
    const maybe_ry = try attrNumberOptional(tag, "ry");
    const raw_rx = maybe_rx orelse maybe_ry orelse 0.0;
    const raw_ry = maybe_ry orelse maybe_rx orelse 0.0;
    if (raw_rx < 0.0 or raw_ry < 0.0) return error.InvalidSvg;
    const rx = @min(raw_rx, width * half_unit);
    const ry = @min(raw_ry, height * half_unit);
    if (@abs(rx - ry) > transform_epsilon) return error.UnsupportedSvgElement;
    return rx;
}

fn attrValue(tag: []const u8, name: []const u8) Error![]const u8 {
    return (try attrValueOptional(tag, name)) orelse error.InvalidSvg;
}

fn attrValueOptional(tag: []const u8, name: []const u8) Error!?[]const u8 {
    var index = tagAttributeStart(tag) orelse return error.InvalidSvg;
    while (true) {
        skipAttributeWhitespace(tag, &index);
        if (index >= tag.len) return null;
        if (tag[index] == '/') {
            index += 1;
            skipAttributeWhitespace(tag, &index);
            if (index == tag.len) return null;
            return error.InvalidSvg;
        }
        const attr_name_start = index;
        while (index < tag.len and !attributeNameEnd(tag[index])) : (index += 1) {}
        if (attr_name_start == index) return error.InvalidSvg;
        const attr_name = tag[attr_name_start..index];
        skipAttributeWhitespace(tag, &index);
        if (index >= tag.len or tag[index] != '=') return error.InvalidSvg;
        index += 1;
        skipAttributeWhitespace(tag, &index);
        if (index >= tag.len) return error.InvalidSvg;
        const quote = tag[index];
        if (quote != '"' and quote != '\'') return error.InvalidSvg;
        index += 1;
        const value_start = index;
        while (index < tag.len and tag[index] != quote) : (index += 1) {}
        if (index >= tag.len) return error.InvalidSvg;
        const value = tag[value_start..index];
        index += 1;
        if (std.mem.eql(u8, attr_name, name)) return value;
    }
}

fn tagAttributeStart(tag: []const u8) ?usize {
    if (tag.len < 2 or tag[0] != '<') return null;
    var index: usize = if (tag[1] == '/') 2 else 1;
    while (index < tag.len and !attributeNameEnd(tag[index])) : (index += 1) {}
    return index;
}

fn attributeNameEnd(byte: u8) bool {
    return std.ascii.isWhitespace(byte) or byte == '=' or byte == '/';
}

fn skipAttributeWhitespace(tag: []const u8, index: *usize) void {
    while (index.* < tag.len and std.ascii.isWhitespace(tag[index.*])) : (index.* += 1) {}
}

fn validateSupportedPresentationTag(tag: []const u8) Error!void {
    if (try attrValueOptional(tag, "style")) |value| try validateSupportedStyle(value);
    if (try attrValueOptional(tag, "opacity")) |value| {
        if (!try supportedOpacity(value)) return error.UnsupportedSvgStroke;
    }
    if (try attrValueOptional(tag, "fill-opacity")) |value| {
        if (!try supportedFillOpacity(value)) return error.UnsupportedSvgStroke;
    }
    if (try attrValueOptional(tag, "stroke-opacity")) |value| {
        if (!try supportedOpacity(value)) return error.UnsupportedSvgStroke;
    }
    if (try attrValueOptional(tag, "display")) |value| {
        if (!supportedDisplay(value)) return error.UnsupportedSvgStroke;
    }
    if (try attrValueOptional(tag, "visibility")) |value| {
        if (!supportedKeyword(value, "visible") and !isHiddenVisibility(value)) return error.UnsupportedSvgStroke;
    }
    if (try attrValueOptional(tag, "fill")) |value| {
        if (!supportedKeyword(value, "none") and !isSupportedSolidPaint(value)) return error.UnsupportedSvgStroke;
    }
    if (try attrValueOptional(tag, "fill-rule")) |value| {
        _ = parseFillRule(value) orelse return error.UnsupportedSvgStroke;
    }
    if (try attrValueOptional(tag, "stroke")) |value| {
        if (!supportedKeyword(value, "none") and !isSupportedStrokePaint(value)) return error.UnsupportedSvgStroke;
    }
    if (try attrValueOptional(tag, "stroke-width")) |value| {
        if (!try supportedStrokeWidth(value)) return error.UnsupportedSvgStroke;
    }
    if (try attrValueOptional(tag, "stroke-linecap")) |value| {
        if (!supportedKeyword(value, "round")) return error.UnsupportedSvgStroke;
    }
    if (try attrValueOptional(tag, "stroke-linejoin")) |value| {
        if (!supportedKeyword(value, "round")) return error.UnsupportedSvgStroke;
    }
}

fn validateUseReferenceTag(tag: []const u8) Error!void {
    try validateSupportedPresentationTag(tag);
    if (try attrValueOptional(tag, "width")) |value| {
        if (!supportedKeyword(value, "auto")) _ = try parseLengthPx(value);
    }
    if (try attrValueOptional(tag, "height")) |value| {
        if (!supportedKeyword(value, "auto")) _ = try parseLengthPx(value);
    }
}

fn validateSupportedStyle(style: []const u8) Error!void {
    var start: usize = 0;
    while (start < style.len) {
        const end = if (std.mem.indexOfScalar(u8, style[start..], ';')) |offset| start + offset else style.len;
        const declaration = trimAscii(style[start..end]);
        start = end + 1;
        if (declaration.len == 0) continue;
        const colon = std.mem.indexOfScalar(u8, declaration, ':') orelse return error.InvalidSvg;
        const property = trimAscii(declaration[0..colon]);
        const value = try styleValue(declaration[colon + 1 ..]);
        try validateSupportedStyleDeclaration(property, value);
    }
}

fn presentationForTag(inherited: Presentation, tag: []const u8, css_rules: *const CssRules) Error!Presentation {
    var result = inherited;
    if (try attrValueOptional(tag, "fill")) |value| {
        result.fill_paint = isSupportedSolidPaint(value);
        if (result.fill_paint) result.fill_color = parseSvgPaint(value) orelse return error.UnsupportedSvgStroke;
    }
    if (try attrValueOptional(tag, "stroke")) |value| {
        result.stroke_paint = isSupportedStrokePaint(value);
        if (result.stroke_paint) result.stroke_color = parseSvgStrokePaint(value) orelse return error.UnsupportedSvgStroke;
    }
    if (try attrValueOptional(tag, "fill-opacity")) |value| result.fill_visible = !(try opacityZero(value));
    if (try attrValueOptional(tag, "stroke-opacity")) |value| result.stroke_visible = !(try opacityZero(value));
    if (try attrValueOptional(tag, "fill-rule")) |value| result.fill_rule = parseFillRule(value) orelse return error.UnsupportedSvgStroke;
    if (try attrValueOptional(tag, "stroke-width")) |value| result.stroke_width = try supportedStrokeWidth(value);
    if (try attrValueOptional(tag, "stroke-linecap")) |value| result.stroke_linecap = supportedKeyword(value, "round");
    if (try attrValueOptional(tag, "stroke-linejoin")) |value| result.stroke_linejoin = supportedKeyword(value, "round");
    try applyMatchingPresentationRules(&result, tag, css_rules);
    if (try attrValueOptional(tag, "style")) |style| try applyPresentationStyle(&result, style);
    return result;
}

fn applyMatchingPresentationRules(result: *Presentation, tag: []const u8, css_rules: *const CssRules) Error!void {
    for (css_rules.items()) |rule| {
        if (!try cssRuleMatchesTag(rule.selector, tag)) continue;
        try validateSupportedStyle(rule.declarations);
        try applyPresentationStyle(result, rule.declarations);
    }
}

fn applyPresentationStyle(result: *Presentation, style: []const u8) Error!void {
    var start: usize = 0;
    while (start < style.len) {
        const end = if (std.mem.indexOfScalar(u8, style[start..], ';')) |offset| start + offset else style.len;
        const declaration = trimAscii(style[start..end]);
        start = end + 1;
        if (declaration.len == 0) continue;
        const colon = std.mem.indexOfScalar(u8, declaration, ':') orelse return error.InvalidSvg;
        const property = trimAscii(declaration[0..colon]);
        const value = try styleValue(declaration[colon + 1 ..]);
        if (asciiEqlIgnoreCase(property, "fill")) {
            result.fill_paint = isSupportedSolidPaint(value);
            if (result.fill_paint) result.fill_color = parseSvgPaint(value) orelse return error.UnsupportedSvgStroke;
        } else if (asciiEqlIgnoreCase(property, "fill-rule")) {
            result.fill_rule = parseFillRule(value) orelse return error.UnsupportedSvgStroke;
        } else if (asciiEqlIgnoreCase(property, "stroke")) {
            result.stroke_paint = isSupportedStrokePaint(value);
            if (result.stroke_paint) result.stroke_color = parseSvgStrokePaint(value) orelse return error.UnsupportedSvgStroke;
        } else if (asciiEqlIgnoreCase(property, "fill-opacity")) {
            result.fill_visible = !(try opacityZero(value));
        } else if (asciiEqlIgnoreCase(property, "stroke-opacity")) {
            result.stroke_visible = !(try opacityZero(value));
        } else if (asciiEqlIgnoreCase(property, "stroke-width")) {
            result.stroke_width = try supportedStrokeWidth(value);
        } else if (asciiEqlIgnoreCase(property, "stroke-linecap")) {
            result.stroke_linecap = supportedKeyword(value, "round");
        } else if (asciiEqlIgnoreCase(property, "stroke-linejoin")) {
            result.stroke_linejoin = supportedKeyword(value, "round");
        }
    }
}

fn validateSupportedStyleDeclaration(property: []const u8, value: []const u8) Error!void {
    if (asciiEqlIgnoreCase(property, "fill")) {
        if (!supportedKeyword(value, "none") and !isSupportedSolidPaint(value)) return error.UnsupportedSvgStroke;
        return;
    }
    if (asciiEqlIgnoreCase(property, "fill-rule")) {
        _ = parseFillRule(value) orelse return error.UnsupportedSvgStroke;
        return;
    }
    if (asciiEqlIgnoreCase(property, "stroke")) {
        if (!supportedKeyword(value, "none") and !isSupportedStrokePaint(value)) return error.UnsupportedSvgStroke;
        return;
    }
    if (asciiEqlIgnoreCase(property, "stroke-width")) {
        if (!try supportedStrokeWidth(value)) return error.UnsupportedSvgStroke;
        return;
    }
    if (asciiEqlIgnoreCase(property, "stroke-linecap")) {
        if (!supportedKeyword(value, "round")) return error.UnsupportedSvgStroke;
        return;
    }
    if (asciiEqlIgnoreCase(property, "stroke-linejoin")) {
        if (!supportedKeyword(value, "round")) return error.UnsupportedSvgStroke;
        return;
    }
    if (asciiEqlIgnoreCase(property, "display")) {
        if (!supportedDisplay(value)) return error.UnsupportedSvgStroke;
        return;
    }
    if (asciiEqlIgnoreCase(property, "visibility")) {
        if (!supportedKeyword(value, "visible") and !isHiddenVisibility(value)) return error.UnsupportedSvgStroke;
        return;
    }
    if (asciiEqlIgnoreCase(property, "opacity")) {
        if (!try supportedOpacity(value)) return error.UnsupportedSvgStroke;
        return;
    }
    if (asciiEqlIgnoreCase(property, "stroke-opacity")) {
        if (!try supportedOpacity(value)) return error.UnsupportedSvgStroke;
        return;
    }
    if (asciiEqlIgnoreCase(property, "fill-opacity")) {
        if (!try supportedFillOpacity(value)) return error.UnsupportedSvgStroke;
        return;
    }
    return error.UnsupportedSvgStroke;
}

fn renderStateForTag(inherited: RenderState, tag: []const u8, css_rules: *const CssRules) Error!RenderState {
    var result = inherited;
    var display_none: ?bool = null;
    var opacity_zero_value: ?bool = null;
    var visibility_hidden_value: ?bool = null;
    var stroke_hidden_value: ?bool = null;
    if (try attrValueOptional(tag, "display")) |value| {
        display_none = supportedKeyword(value, "none");
    }
    if (try attrValueOptional(tag, "opacity")) |value| {
        opacity_zero_value = try opacityZero(value);
    }
    if (try attrValueOptional(tag, "stroke-opacity")) |value| {
        stroke_hidden_value = try opacityZero(value);
    }
    if (try attrValueOptional(tag, "visibility")) |value| visibility_hidden_value = visibilityHiddenValue(value);
    try applyMatchingRenderStateRules(&display_none, &opacity_zero_value, &visibility_hidden_value, &stroke_hidden_value, tag, css_rules);
    if (try attrValueOptional(tag, "style")) |style| try applyRenderStateStyle(&display_none, &opacity_zero_value, &visibility_hidden_value, &stroke_hidden_value, style);
    if (display_none == true or opacity_zero_value == true) result.subtree_hidden = true;
    if (visibility_hidden_value) |hidden| result.visibility_hidden = hidden;
    if (stroke_hidden_value) |hidden| result.stroke_hidden = hidden;
    return result;
}

fn applyMatchingRenderStateRules(display_none: *?bool, opacity_zero_value: *?bool, visibility_hidden_value: *?bool, stroke_hidden_value: *?bool, tag: []const u8, css_rules: *const CssRules) Error!void {
    for (css_rules.items()) |rule| {
        if (!try cssRuleMatchesTag(rule.selector, tag)) continue;
        try validateSupportedStyle(rule.declarations);
        try applyRenderStateStyle(display_none, opacity_zero_value, visibility_hidden_value, stroke_hidden_value, rule.declarations);
    }
}

fn applyRenderStateStyle(display_none: *?bool, opacity_zero_value: *?bool, visibility_hidden_value: *?bool, stroke_hidden_value: *?bool, style: []const u8) Error!void {
    var start: usize = 0;
    while (start < style.len) {
        const end = if (std.mem.indexOfScalar(u8, style[start..], ';')) |offset| start + offset else style.len;
        const declaration = trimAscii(style[start..end]);
        start = end + 1;
        if (declaration.len == 0) continue;
        const colon = std.mem.indexOfScalar(u8, declaration, ':') orelse return error.InvalidSvg;
        const property = trimAscii(declaration[0..colon]);
        const value = try styleValue(declaration[colon + 1 ..]);
        if (asciiEqlIgnoreCase(property, "opacity")) opacity_zero_value.* = try opacityZero(value);
        if (asciiEqlIgnoreCase(property, "stroke-opacity")) stroke_hidden_value.* = try opacityZero(value);
        if (asciiEqlIgnoreCase(property, "display")) display_none.* = supportedKeyword(value, "none");
        if (asciiEqlIgnoreCase(property, "visibility")) visibility_hidden_value.* = visibilityHiddenValue(value);
    }
}

fn visibilityHiddenValue(value: []const u8) bool {
    return isHiddenVisibility(value);
}

fn isHiddenVisibility(value: []const u8) bool {
    return supportedKeyword(value, "hidden") or supportedKeyword(value, "collapse");
}

fn supportedDisplay(value: []const u8) bool {
    inline for (supported_display_values) |supported| {
        if (supportedKeyword(value, supported)) return true;
    }
    return false;
}

fn opacityZero(value: []const u8) Error!bool {
    const parsed = try parseOpacity(value);
    return @abs(parsed) <= transform_epsilon;
}

fn supportedOpacity(value: []const u8) Error!bool {
    const parsed = try parseOpacity(value);
    return @abs(parsed) <= transform_epsilon or @abs(parsed - opacity_opaque) <= transform_epsilon;
}

fn supportedFillOpacity(value: []const u8) Error!bool {
    const parsed = try parseOpacity(value);
    return parsed >= 0.0 and parsed <= opacity_opaque;
}

fn parseOpacity(value: []const u8) Error!f32 {
    const trimmed = trimAscii(value);
    if (std.mem.indexOfAny(u8, trimmed, svg_length_unit_letters) != null) return error.InvalidSvg;
    return parseFiniteSvgFloat(trimmed, error.InvalidSvg);
}

fn isSupportedStrokePaint(value: []const u8) bool {
    const trimmed = trimAscii(value);
    return !supportedKeyword(trimmed, "none") and parseSvgPaint(trimmed) != null;
}

fn isSupportedSolidPaint(value: []const u8) bool {
    const trimmed = trimAscii(value);
    if (supportedKeyword(trimmed, "none")) return false;
    return parseSvgPaint(trimmed) != null;
}

fn parseSvgPaint(value: []const u8) ?SvgPaint {
    const trimmed = trimAscii(value);
    if (asciiEqlIgnoreCase(trimmed, "currentColor")) return .current_color;
    if (parseHexColor(trimmed)) |color| return .{ .solid = color };
    if (parseFunctionalColor(trimmed)) |color| return .{ .solid = color };
    inline for (supported_named_solid_paints) |paint| {
        if (asciiEqlIgnoreCase(trimmed, paint.name)) return .{ .solid = paint.color };
    }
    return null;
}

fn parseSvgStrokePaint(value: []const u8) ?SvgPaint {
    const trimmed = trimAscii(value);
    if (asciiEqlIgnoreCase(trimmed, "currentColor") or asciiEqlIgnoreCase(trimmed, "white") or asciiEqlIgnoreCase(trimmed, "#fff") or asciiEqlIgnoreCase(trimmed, "#ffffff")) return .current_color;
    return parseSvgPaint(trimmed);
}

fn svgPaintsEqual(left: SvgPaint, right: SvgPaint) bool {
    return switch (left) {
        .current_color => switch (right) {
            .current_color => true,
            .solid => false,
        },
        .solid => |left_color| switch (right) {
            .current_color => false,
            .solid => |right_color| left_color.r == right_color.r and left_color.g == right_color.g and left_color.b == right_color.b and left_color.a == right_color.a,
        },
    };
}

fn parseHexColor(value: []const u8) ?icon_vector.Paint {
    if (value.len == 4 and value[0] == '#') {
        const r = hexNibble(value[1]) orelse return null;
        const g = hexNibble(value[2]) orelse return null;
        const b = hexNibble(value[3]) orelse return null;
        return .{ .r = r * hex_short_multiplier, .g = g * hex_short_multiplier, .b = b * hex_short_multiplier, .a = color_component_max };
    }
    if (value.len == 5 and value[0] == '#') {
        const r = hexNibble(value[1]) orelse return null;
        const g = hexNibble(value[2]) orelse return null;
        const b = hexNibble(value[3]) orelse return null;
        const a = hexNibble(value[4]) orelse return null;
        return .{ .r = r * hex_short_multiplier, .g = g * hex_short_multiplier, .b = b * hex_short_multiplier, .a = a * hex_short_multiplier };
    }
    if (value.len == 7 and value[0] == '#') {
        return .{
            .r = parseHexByte(value[1], value[2]) orelse return null,
            .g = parseHexByte(value[3], value[4]) orelse return null,
            .b = parseHexByte(value[5], value[6]) orelse return null,
            .a = color_component_max,
        };
    }
    if (value.len == 9 and value[0] == '#') {
        return .{
            .r = parseHexByte(value[1], value[2]) orelse return null,
            .g = parseHexByte(value[3], value[4]) orelse return null,
            .b = parseHexByte(value[5], value[6]) orelse return null,
            .a = parseHexByte(value[7], value[8]) orelse return null,
        };
    }
    return null;
}

fn parseFunctionalColor(value: []const u8) ?icon_vector.Paint {
    const rgb_open = "rgb(";
    const rgba_open = "rgba(";
    if (asciiStartsWithIgnoreCase(value, rgb_open)) return parseColorFunctionBody(value[rgb_open.len..], false);
    if (asciiStartsWithIgnoreCase(value, rgba_open)) return parseColorFunctionBody(value[rgba_open.len..], true);
    return null;
}

fn parseColorFunctionBody(raw_body: []const u8, alpha_required: bool) ?icon_vector.Paint {
    if (raw_body.len == 0 or raw_body[raw_body.len - 1] != ')') return null;
    const body = trimAscii(raw_body[0 .. raw_body.len - 1]);
    var tokens: [max_color_function_tokens][]const u8 = undefined;
    const token_count = collectColorFunctionTokens(body, &tokens) orelse return null;
    if (alpha_required) {
        if (token_count != color_function_alpha_tokens) return null;
    } else if (token_count != color_function_rgb_tokens and token_count != color_function_alpha_tokens) {
        return null;
    }
    return .{
        .r = parseColorByteComponent(tokens[0]) orelse return null,
        .g = parseColorByteComponent(tokens[1]) orelse return null,
        .b = parseColorByteComponent(tokens[2]) orelse return null,
        .a = if (token_count == color_function_alpha_tokens) parseAlphaByteComponent(tokens[3]) orelse return null else color_component_max,
    };
}

fn collectColorFunctionTokens(body: []const u8, out: *[max_color_function_tokens][]const u8) ?usize {
    var count: usize = 0;
    var index: usize = 0;
    var token_start: ?usize = null;
    var comma_separated = false;
    var slash_seen = false;
    while (index < body.len) : (index += 1) {
        const byte = body[index];
        switch (byte) {
            ',', '/' => {
                if (byte == ',') {
                    if (slash_seen) return null;
                    comma_separated = true;
                } else {
                    if (slash_seen or count != color_function_rgb_tokens) return null;
                    slash_seen = true;
                }
                if (token_start) |start| {
                    if (count >= out.len) return null;
                    out[count] = trimAscii(body[start..index]);
                    if (out[count].len == 0) return null;
                    count += 1;
                    token_start = null;
                } else if (byte == ',') return null;
            },
            ' ', '\n', '\r', '\t' => {
                if (token_start) |start| {
                    if (count >= out.len) return null;
                    out[count] = trimAscii(body[start..index]);
                    if (out[count].len == 0) return null;
                    count += 1;
                    token_start = null;
                }
            },
            else => {
                if (token_start == null) {
                    if (comma_separated and count > 0 and !slash_seen) {
                        var prev = index;
                        while (prev > 0 and isSvgWhitespace(body[prev - 1])) prev -= 1;
                        if (prev > 0 and body[prev - 1] != ',') return null;
                    }
                    token_start = index;
                }
            },
        }
    }
    if (token_start) |start| {
        if (count >= out.len) return null;
        out[count] = trimAscii(body[start..]);
        if (out[count].len == 0) return null;
        count += 1;
    }
    return count;
}

fn parseColorByteComponent(raw: []const u8) ?u8 {
    const value = trimAscii(raw);
    if (asciiEndsWithIgnoreCase(value, "%")) {
        const percent = parseColorNumber(trimAscii(value[0 .. value.len - 1])) orelse return null;
        if (percent < 0.0 or percent > color_percent_max) return null;
        return roundedByte(percent * color_component_max_float / color_percent_max);
    }
    const number = parseColorNumber(value) orelse return null;
    if (number < 0.0 or number > color_component_max_float) return null;
    return roundedByte(number);
}

fn parseAlphaByteComponent(raw: []const u8) ?u8 {
    const value = trimAscii(raw);
    if (asciiEndsWithIgnoreCase(value, "%")) {
        const percent = parseColorNumber(trimAscii(value[0 .. value.len - 1])) orelse return null;
        if (percent < 0.0 or percent > color_percent_max) return null;
        return roundedByte(percent * color_component_max_float / color_percent_max);
    }
    const alpha = parseColorNumber(value) orelse return null;
    if (alpha < 0.0 or alpha > opacity_opaque) return null;
    return roundedByte(alpha * color_component_max_float);
}

fn parseColorNumber(value: []const u8) ?f32 {
    if (value.len == 0) return null;
    if (std.mem.indexOfAny(u8, value, color_forbidden_number_letters) != null) return null;
    return parseFiniteSvgFloat(value, error.InvalidSvg) catch null;
}

fn roundedByte(value: f32) u8 {
    const rounded = @round(value);
    if (rounded <= 0.0) return 0;
    if (rounded >= color_component_max_float) return color_component_max;
    return @intFromFloat(rounded);
}

fn parseHexByte(high: u8, low: u8) ?u8 {
    const high_value = hexNibble(high) orelse return null;
    const low_value = hexNibble(low) orelse return null;
    return high_value * hex_base + low_value;
}

fn hexNibble(value: u8) ?u8 {
    if (value >= '0' and value <= '9') return value - '0';
    if (value >= 'a' and value <= 'f') return value - 'a' + 10;
    if (value >= 'A' and value <= 'F') return value - 'A' + 10;
    return null;
}

fn parseFillRule(value: []const u8) ?FillRule {
    if (supportedKeyword(value, "nonzero")) return .nonzero;
    if (supportedKeyword(value, "evenodd")) return .evenodd;
    return null;
}

fn supportedStrokeWidth(value: []const u8) Error!bool {
    const width = parseLengthPx(value) catch return error.UnsupportedSvgStroke;
    return @abs(width - supported_stroke_width) <= transform_epsilon;
}

fn parseLengthPx(raw: []const u8) Error!f32 {
    const value = trimAscii(raw);
    if (asciiEndsWithIgnoreCase(value, "px")) return parseFiniteSvgFloat(trimAscii(value[0 .. value.len - 2]), error.InvalidSvg);
    if (std.mem.indexOfAny(u8, value, svg_length_unit_letters) != null) return error.InvalidSvg;
    return parseFiniteSvgFloat(value, error.InvalidSvg);
}

fn trimAscii(value: []const u8) []const u8 {
    return std.mem.trim(u8, value, " \n\r\t");
}

fn supportedKeyword(value: []const u8, expected: []const u8) bool {
    return asciiEqlIgnoreCase(trimAscii(value), expected);
}

fn styleValue(raw: []const u8) Error![]const u8 {
    const value = trimAscii(raw);
    const important = "important";
    if (value.len < important.len) return value;
    const suffix = value[value.len - important.len ..];
    if (!asciiEqlIgnoreCase(suffix, important)) return value;
    var bang_index = value.len - important.len;
    while (bang_index > 0 and std.ascii.isWhitespace(value[bang_index - 1])) bang_index -= 1;
    if (bang_index == 0 or value[bang_index - 1] != '!') return value;
    const before_marker = trimAscii(value[0 .. bang_index - 1]);
    if (before_marker.len == 0) return error.InvalidSvg;
    return before_marker;
}

fn asciiEqlIgnoreCase(left: []const u8, right: []const u8) bool {
    if (left.len != right.len) return false;
    for (left, right) |a, b| {
        if (std.ascii.toLower(a) != std.ascii.toLower(b)) return false;
    }
    return true;
}

fn asciiEndsWithIgnoreCase(value: []const u8, suffix: []const u8) bool {
    if (value.len < suffix.len) return false;
    return asciiEqlIgnoreCase(value[value.len - suffix.len ..], suffix);
}

fn asciiStartsWithIgnoreCase(value: []const u8, prefix: []const u8) bool {
    if (value.len < prefix.len) return false;
    return asciiEqlIgnoreCase(value[0..prefix.len], prefix);
}

fn elementTransform(tag: []const u8) Error!Transform {
    const raw = (try attrValueOptional(tag, "transform")) orelse return .{};
    return parseTransform(raw);
}

fn combineElementTransform(inherited: Transform, tag: []const u8) Error!Transform {
    return appendTransform(inherited, try elementTransform(tag));
}

fn useTranslation(tag: []const u8) Error!Transform {
    return .{
        .e = try attrNumberDefault(tag, "x", 0.0),
        .f = try attrNumberDefault(tag, "y", 0.0),
    };
}

fn useReferenceId(tag: []const u8) Error![]const u8 {
    const href = (try attrValueOptional(tag, "href")) orelse (try attrValueOptional(tag, "xlink:href")) orelse return error.InvalidSvg;
    const trimmed = trimAscii(href);
    if (trimmed.len < 2 or trimmed[0] != '#') return error.UnsupportedSvgElement;
    const id = trimmed[1..];
    if (!validCssSimpleName(id)) return error.UnsupportedSvgElement;
    return id;
}

fn findReferencedElement(svg: []const u8, id: []const u8) Error!ReferencedElement {
    var search_index: usize = 0;
    while (search_index < svg.len) {
        const tag_start_offset = std.mem.indexOfScalar(u8, svg[search_index..], '<') orelse return error.InvalidSvg;
        const tag_start = search_index + tag_start_offset;
        if (try skipSpecialMarkup(svg, tag_start, &search_index)) continue;
        const tag_end = try svgTagEnd(svg, tag_start);
        const tag = svg[tag_start..tag_end];
        search_index = tag_end + 1;
        if (std.mem.startsWith(u8, tag, "</")) continue;
        if (try attrValueOptional(tag, "id")) |candidate| {
            if (std.mem.eql(u8, candidate, id)) {
                if (isReusableContainerOpenTag(tag)) {
                    if (isSelfClosingTag(tag)) return .{ .tag = tag, .content_start = search_index, .content_end = search_index };
                    const close_start = try containerCloseStart(svg, search_index, tagName(tag));
                    return .{ .tag = tag, .content_start = search_index, .content_end = close_start };
                }
                return .{ .tag = tag, .content_start = search_index, .content_end = search_index };
            }
        }
    }
    return error.InvalidSvg;
}

fn parseTransform(raw: []const u8) Error!Transform {
    var result = Transform{};
    var index: usize = 0;
    while (true) {
        try skipTransformSeparators(raw, &index);
        if (index >= raw.len) return result;
        const name_start = index;
        while (index < raw.len and std.ascii.isAlphabetic(raw[index])) : (index += 1) {}
        if (name_start == index) return error.InvalidSvg;
        const name = raw[name_start..index];
        skipTransformWhitespace(raw, &index);
        if (index >= raw.len or raw[index] != '(') return error.InvalidSvg;
        index += 1;
        const args_start = index;
        while (index < raw.len and raw[index] != ')') : (index += 1) {}
        if (index >= raw.len) return error.InvalidSvg;
        const args = raw[args_start..index];
        index += 1;
        result = appendTransform(result, try parseTransformFunction(name, args));
    }
}

fn parseTransformFunction(name: []const u8, args: []const u8) Error!Transform {
    if (std.mem.eql(u8, name, "matrix")) return parseMatrix(args);
    if (std.mem.eql(u8, name, "translate")) return parseTranslate(args);
    if (std.mem.eql(u8, name, "scale")) return parseScale(args);
    if (std.mem.eql(u8, name, "rotate")) return parseRotate(args);
    if (std.mem.eql(u8, name, "skewX")) return parseSkewX(args);
    if (std.mem.eql(u8, name, "skewY")) return parseSkewY(args);
    return error.UnsupportedSvgElement;
}

fn parseMatrix(args: []const u8) Error!Transform {
    var values = NumberList.init(args);
    const a = try values.next();
    const b = try values.next();
    const c = try values.next();
    const d = try values.next();
    const e = try values.next();
    const f = try values.next();
    if (try values.hasMore()) return error.InvalidSvg;
    return .{ .a = a, .b = b, .c = c, .d = d, .e = e, .f = f };
}

fn parseTranslate(args: []const u8) Error!Transform {
    var values = NumberList.init(args);
    const tx = try values.next();
    const ty = if (try values.hasMore()) try values.next() else 0.0;
    if (try values.hasMore()) return error.InvalidSvg;
    return .{ .e = tx, .f = ty };
}

fn parseScale(args: []const u8) Error!Transform {
    var values = NumberList.init(args);
    const sx = try values.next();
    const sy = if (try values.hasMore()) try values.next() else sx;
    if (try values.hasMore()) return error.InvalidSvg;
    return .{ .a = sx, .d = sy };
}

fn parseRotate(args: []const u8) Error!Transform {
    var values = NumberList.init(args);
    const angle = degreesToRadians(try values.next());
    const cos_value = @cos(angle);
    const sin_value = @sin(angle);
    const rotation = Transform{
        .a = cos_value,
        .b = sin_value,
        .c = -sin_value,
        .d = cos_value,
    };
    if (!(try values.hasMore())) return rotation;
    const cx = try values.next();
    const cy = try values.next();
    if (try values.hasMore()) return error.InvalidSvg;
    return appendTransform(appendTransform(.{ .e = cx, .f = cy }, rotation), .{ .e = -cx, .f = -cy });
}

fn parseSkewX(args: []const u8) Error!Transform {
    var values = NumberList.init(args);
    const angle = degreesToRadians(try values.next());
    if (try values.hasMore()) return error.InvalidSvg;
    return .{ .c = @tan(angle) };
}

fn parseSkewY(args: []const u8) Error!Transform {
    var values = NumberList.init(args);
    const angle = degreesToRadians(try values.next());
    if (try values.hasMore()) return error.InvalidSvg;
    return .{ .b = @tan(angle) };
}

fn appendTransform(current: Transform, next: Transform) Transform {
    return .{
        .a = current.a * next.a + current.c * next.b,
        .b = current.b * next.a + current.d * next.b,
        .c = current.a * next.c + current.c * next.d,
        .d = current.b * next.c + current.d * next.d,
        .e = current.a * next.e + current.c * next.f + current.e,
        .f = current.b * next.e + current.d * next.f + current.f,
    };
}

fn skipTransformSeparators(raw: []const u8, index: *usize) Error!void {
    skipTransformWhitespace(raw, index);
    if (index.* >= raw.len or raw[index.*] != ',') return;
    if (!previousNonWhitespaceIs(raw, index.*, ')')) return error.InvalidSvg;
    index.* += 1;
    while (index.* < raw.len and isSvgWhitespace(raw[index.*])) : (index.* += 1) {}
    if (index.* >= raw.len or !std.ascii.isAlphabetic(raw[index.*])) return error.InvalidSvg;
}

fn skipTransformWhitespace(raw: []const u8, index: *usize) void {
    while (index.* < raw.len and isSvgWhitespace(raw[index.*])) : (index.* += 1) {}
}

fn previousNonWhitespaceIs(data: []const u8, current_index: usize, expected: u8) bool {
    var index = current_index;
    while (index > 0) {
        index -= 1;
        if (isSvgWhitespace(data[index])) continue;
        return data[index] == expected;
    }
    return false;
}

fn degreesToRadians(value: f32) f32 {
    return value * std.math.pi / half_turn_degrees;
}

fn radiansToDegrees(value: f32) f32 {
    return value * half_turn_degrees / std.math.pi;
}

fn isIgnorableTag(tag: []const u8) bool {
    return std.mem.startsWith(u8, tag, "<!") or std.mem.startsWith(u8, tag, "<?") or std.mem.startsWith(u8, tag, "<svg") or std.mem.startsWith(u8, tag, "</svg");
}

fn isGroupOpenTag(tag: []const u8) bool {
    return tagHasName(tag, "g");
}

fn isGroupCloseTag(tag: []const u8) bool {
    return std.mem.startsWith(u8, tag, "</g") and tagNameBoundary(tag, 3);
}

fn isSymbolOpenTag(tag: []const u8) bool {
    return tagHasName(tag, "symbol");
}

fn isSymbolCloseTag(tag: []const u8) bool {
    return tagCloseHasName(tag, "symbol");
}

fn isReusableContainerOpenTag(tag: []const u8) bool {
    return isGroupOpenTag(tag) or isSymbolOpenTag(tag);
}

fn isMetadataTag(tag: []const u8) bool {
    return tagHasName(tag, "title") or
        tagHasName(tag, "desc") or
        (std.mem.startsWith(u8, tag, "</title") and tagNameBoundary(tag, 7)) or
        (std.mem.startsWith(u8, tag, "</desc") and tagNameBoundary(tag, 6));
}

fn isStyleTag(tag: []const u8) bool {
    return tagHasName(tag, "style");
}

fn isDefsOpenTag(tag: []const u8) bool {
    return tagHasName(tag, "defs");
}

fn isDefsCloseTag(tag: []const u8) bool {
    return tagCloseHasName(tag, "defs");
}

fn isUseTag(tag: []const u8) bool {
    return tagHasName(tag, "use");
}

fn styleCloseStart(svg: []const u8, content_start: usize) ?usize {
    var search_index = content_start;
    while (search_index < svg.len) {
        const offset = std.mem.indexOf(u8, svg[search_index..], "</style") orelse return null;
        const candidate = search_index + offset;
        const tag_end = svgTagEnd(svg, candidate) catch return null;
        const tag = svg[candidate..tag_end];
        if (tagCloseHasName(tag, "style")) return candidate;
        search_index = tag_end + 1;
    }
    return null;
}

fn styleCloseEnd(svg: []const u8, content_start: usize) Error!usize {
    const close_start = styleCloseStart(svg, content_start) orelse return error.InvalidSvg;
    return try svgTagEnd(svg, close_start) + 1;
}

fn containerCloseStart(svg: []const u8, content_start: usize, name: []const u8) Error!usize {
    var search_index = content_start;
    var depth: usize = 1;
    while (search_index < svg.len) {
        const tag_start_offset = std.mem.indexOfScalar(u8, svg[search_index..], '<') orelse return error.InvalidSvg;
        const tag_start = search_index + tag_start_offset;
        if (try skipSpecialMarkup(svg, tag_start, &search_index)) continue;
        const tag_end = try svgTagEnd(svg, tag_start);
        const tag = svg[tag_start..tag_end];
        search_index = tag_end + 1;
        if (tagHasName(tag, name) and !isSelfClosingTag(tag)) {
            depth += 1;
            continue;
        }
        if (!tagCloseHasName(tag, name)) continue;
        depth -= 1;
        if (depth == 0) return tag_start;
    }
    return error.InvalidSvg;
}

fn containerCloseEnd(svg: []const u8, content_start: usize, name: []const u8) Error!usize {
    const close_start = try containerCloseStart(svg, content_start, name);
    return try svgTagEnd(svg, close_start) + 1;
}

fn cssRuleMatchesTag(selector: CssSelector, tag: []const u8) Error!bool {
    return switch (selector) {
        .element => |name| tagHasName(tag, name),
        .class => |name| try tagClassContains(tag, name),
        .id => |name| if (try attrValueOptional(tag, "id")) |value| std.mem.eql(u8, value, name) else false,
    };
}

fn tagClassContains(tag: []const u8, name: []const u8) Error!bool {
    const classes = (try attrValueOptional(tag, "class")) orelse return false;
    var start: usize = 0;
    while (start < classes.len) {
        while (start < classes.len and std.ascii.isWhitespace(classes[start])) : (start += 1) {}
        const end = start;
        var token_end = end;
        while (token_end < classes.len and !std.ascii.isWhitespace(classes[token_end])) : (token_end += 1) {}
        if (token_end > start and std.mem.eql(u8, classes[start..token_end], name)) return true;
        start = token_end;
    }
    return false;
}

fn isSelfClosingTag(tag: []const u8) bool {
    var index = tag.len;
    while (index > 0) {
        index -= 1;
        if (std.ascii.isWhitespace(tag[index])) continue;
        return tag[index] == '/';
    }
    return false;
}

fn supportedElementKind(tag: []const u8) ?SvgElementKind {
    inline for (svg_element_names) |entry| {
        if (tagHasName(tag, entry.name)) return entry.kind;
    }
    return null;
}

fn isSupportedElementCloseTag(tag: []const u8) bool {
    inline for (svg_element_names) |entry| {
        if (tagCloseHasName(tag, entry.name)) return true;
    }
    return false;
}

fn unsupportedElementTag(tag: []const u8) bool {
    inline for (unsupported_svg_elements) |name| {
        if (tagHasName(tag, name)) return true;
    }
    return false;
}

fn svgContainsElementTag(svg: []const u8, name: []const u8) bool {
    var search_index: usize = 0;
    while (search_index < svg.len) {
        const tag_start_offset = std.mem.indexOfScalar(u8, svg[search_index..], '<') orelse return false;
        const tag_start = search_index + tag_start_offset;
        if (skipSpecialMarkup(svg, tag_start, &search_index) catch return false) continue;
        const tag_end = svgTagEnd(svg, tag_start) catch return false;
        const tag = svg[tag_start..tag_end];
        if (tagHasName(tag, name)) return true;
        search_index = tag_end + 1;
    }
    return false;
}

fn skipSpecialMarkup(svg: []const u8, tag_start: usize, search_index: *usize) Error!bool {
    inline for (special_markup_spans) |span| {
        if (std.mem.startsWith(u8, svg[tag_start..], span.open)) {
            const end_offset = std.mem.indexOf(u8, svg[tag_start + span.open.len ..], span.close) orelse return error.InvalidSvg;
            search_index.* = tag_start + span.open.len + end_offset + span.close.len;
            return true;
        }
    }
    if (std.mem.startsWith(u8, svg[tag_start..], svg_doctype_open)) {
        search_index.* = try svgDoctypeEnd(svg, tag_start) + 1;
        return true;
    }
    return false;
}

fn svgDoctypeEnd(svg: []const u8, tag_start: usize) Error!usize {
    var index = tag_start + svg_doctype_open.len;
    var quote: ?u8 = null;
    var subset_depth: usize = 0;
    while (index < svg.len) : (index += 1) {
        const byte = svg[index];
        if (quote) |active| {
            if (byte == active) quote = null;
            continue;
        }
        switch (byte) {
            '"', '\'' => quote = byte,
            '[' => subset_depth += 1,
            ']' => {
                if (subset_depth == 0) return error.InvalidSvg;
                subset_depth -= 1;
            },
            '>' => if (subset_depth == 0) return index,
            else => {},
        }
    }
    return error.InvalidSvg;
}

fn svgTagEnd(svg: []const u8, tag_start: usize) Error!usize {
    var index = tag_start;
    var quote: ?u8 = null;
    while (index < svg.len) : (index += 1) {
        const byte = svg[index];
        if (quote) |active| {
            if (byte == active) quote = null;
            continue;
        }
        switch (byte) {
            '"', '\'' => quote = byte,
            '>' => return index,
            else => {},
        }
    }
    return error.InvalidSvg;
}

fn tagHasName(tag: []const u8, name: []const u8) bool {
    if (tag.len < name.len + 1) return false;
    if (tag[0] != '<') return false;
    if (!std.mem.eql(u8, tag[1 .. 1 + name.len], name)) return false;
    return tagNameBoundary(tag, 1 + name.len);
}

fn tagCloseHasName(tag: []const u8, name: []const u8) bool {
    if (tag.len < name.len + 2) return false;
    if (!std.mem.startsWith(u8, tag, "</")) return false;
    if (!std.mem.eql(u8, tag[2 .. 2 + name.len], name)) return false;
    return tagNameBoundary(tag, 2 + name.len);
}

fn tagName(tag: []const u8) []const u8 {
    var index: usize = if (std.mem.startsWith(u8, tag, "</")) 2 else 1;
    const start = index;
    while (index < tag.len and !tagNameBoundary(tag, index)) : (index += 1) {}
    return tag[start..index];
}

fn tagNameBoundary(tag: []const u8, index: usize) bool {
    if (index >= tag.len) return true;
    return switch (tag[index]) {
        ' ', '\n', '\r', '\t', '/', '>' => true,
        else => false,
    };
}

const NumberList = struct {
    data: []const u8,
    index: usize = 0,

    fn init(data: []const u8) NumberList {
        return .{ .data = data };
    }

    fn next(self: *NumberList) Error!f32 {
        return parseSvgNumber(self.data, &self.index, error.InvalidSvg);
    }

    fn hasMore(self: *NumberList) Error!bool {
        try self.skipSeparators();
        return self.index < self.data.len;
    }

    fn skipSeparators(self: *NumberList) Error!void {
        try skipSvgNumberSeparators(self.data, &self.index, error.InvalidSvg);
    }
};

fn parseSvgNumber(data: []const u8, index: *usize, comptime invalid_error: Error) Error!f32 {
    try skipSvgNumberSeparators(data, index, invalid_error);
    const start = index.*;
    if (index.* < data.len and (data[index.*] == '-' or data[index.*] == '+')) index.* += 1;
    var has_digit = false;
    while (index.* < data.len and std.ascii.isDigit(data[index.*])) : (index.* += 1) has_digit = true;
    if (index.* < data.len and data[index.*] == '.') {
        index.* += 1;
        while (index.* < data.len and std.ascii.isDigit(data[index.*])) : (index.* += 1) has_digit = true;
    }
    if (!has_digit) return invalid_error;
    if (index.* < data.len and (data[index.*] == 'e' or data[index.*] == 'E')) {
        index.* += 1;
        if (index.* < data.len and (data[index.*] == '-' or data[index.*] == '+')) index.* += 1;
        var exponent_digits = false;
        while (index.* < data.len and std.ascii.isDigit(data[index.*])) : (index.* += 1) exponent_digits = true;
        if (!exponent_digits) return invalid_error;
    }
    return parseFiniteSvgFloat(data[start..index.*], invalid_error);
}

fn parseFiniteSvgFloat(raw: []const u8, comptime invalid_error: Error) Error!f32 {
    const value = std.fmt.parseFloat(f32, raw) catch return invalid_error;
    if (!std.math.isFinite(value)) return invalid_error;
    return value;
}

fn skipSvgNumberSeparators(data: []const u8, index: *usize, comptime invalid_error: Error) Error!void {
    while (index.* < data.len and isSvgWhitespace(data[index.*])) : (index.* += 1) {}
    if (index.* >= data.len or data[index.*] != ',') return;
    if (!previousSvgNumberCanTakeComma(data, index.*)) return invalid_error;
    index.* += 1;
    while (index.* < data.len and isSvgWhitespace(data[index.*])) : (index.* += 1) {}
    if (index.* >= data.len or !isSvgNumberStart(data[index.*])) return invalid_error;
}

fn isSvgWhitespace(byte: u8) bool {
    return switch (byte) {
        ' ', '\n', '\r', '\t' => true,
        else => false,
    };
}

fn isSvgNumberStart(byte: u8) bool {
    return switch (byte) {
        '-', '+', '.' => true,
        else => std.ascii.isDigit(byte),
    };
}

fn previousSvgNumberCanTakeComma(data: []const u8, comma_index: usize) bool {
    var index = comma_index;
    while (index > 0) {
        index -= 1;
        if (isSvgWhitespace(data[index])) continue;
        return std.ascii.isDigit(data[index]) or data[index] == '.';
    }
    return false;
}

const supported_stroke_width_attr = "stroke-width=\"2\"";
const supported_stroke_linecap_attr = "stroke-linecap=\"round\"";
const supported_stroke_linejoin_attr = "stroke-linejoin=\"round\"";
const svg_element_names = [_]struct {
    name: []const u8,
    kind: SvgElementKind,
}{
    .{ .name = "path", .kind = .path },
    .{ .name = "circle", .kind = .circle },
    .{ .name = "ellipse", .kind = .ellipse },
    .{ .name = "line", .kind = .line },
    .{ .name = "polyline", .kind = .polyline },
    .{ .name = "polygon", .kind = .polygon },
    .{ .name = "rect", .kind = .rect },
};
const unsupported_svg_elements = [_][]const u8{
    "clipPath",
    "linearGradient",
    "mask",
    "radialGradient",
};
const supported_display_values = [_][]const u8{
    "inline",
    "block",
    "list-item",
    "run-in",
    "compact",
    "marker",
    "table",
    "inline-table",
    "table-row-group",
    "table-header-group",
    "table-footer-group",
    "table-row",
    "table-column-group",
    "table-column",
    "table-cell",
    "table-caption",
    "none",
};
const supported_named_solid_paints = [_]struct {
    name: []const u8,
    color: icon_vector.Paint,
}{
    .{ .name = "black", .color = .{ .r = 0, .g = 0, .b = 0, .a = 255 } },
    .{ .name = "white", .color = .{ .r = 255, .g = 255, .b = 255, .a = 255 } },
    .{ .name = "red", .color = .{ .r = 255, .g = 0, .b = 0, .a = 255 } },
    .{ .name = "green", .color = .{ .r = 0, .g = 128, .b = 0, .a = 255 } },
    .{ .name = "blue", .color = .{ .r = 0, .g = 0, .b = 255, .a = 255 } },
};
const max_pending_ops: usize = 128;
const max_transform_depth: usize = 16;
const max_reference_depth: usize = 8;
const max_css_rules: usize = 48;
const max_color_function_tokens: usize = 4;
const color_function_rgb_tokens: usize = 3;
const color_function_alpha_tokens: usize = 4;
const half_turn_degrees: f32 = 180.0;
const half_unit: f32 = 0.5;
const transform_epsilon: f32 = 0.00001;
const supported_stroke_width: f32 = 2.0;
const opacity_opaque: f32 = 1.0;
const color_component_max: u8 = 255;
const color_component_max_float: f32 = 255.0;
const color_percent_max: f32 = 100.0;
const hex_short_multiplier: u8 = 17;
const hex_base: u8 = 16;
const svg_length_unit_letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ%";
const color_forbidden_number_letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
const special_markup_spans = [_]struct {
    open: []const u8,
    close: []const u8,
}{
    .{ .open = "<!--", .close = "-->" },
    .{ .open = "<![CDATA[", .close = "]]>" },
};
const svg_doctype_open = "<!DOCTYPE";
const css_comment_open = "/*";
const css_comment_close = "*/";

test "tabler search svg parses real path commands" {
    var iter = Iterator.init(source(.search));
    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.125, .y = 10.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .arc_to = .{
        .rx = 7.0 / 24.0,
        .ry = 7.0 / 24.0,
        .x_axis_rotation = 0.0,
        .large_arc = true,
        .sweep = false,
        .end = .{ .x = 17.0 / 24.0, .y = 10.0 / 24.0 },
    } }, (try iter.next()).?);
}

test "path parser supports quadratic and smooth quadratic commands" {
    var iter = PathIterator.init("M 2 2 Q 6 10 10 2 T 18 2");

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 2.0 / 24.0, .y = 2.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .quad_to = .{
        .control = .{ .x = 6.0 / 24.0, .y = 10.0 / 24.0 },
        .end = .{ .x = 10.0 / 24.0, .y = 2.0 / 24.0 },
    } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .quad_to = .{
        .control = .{ .x = 14.0 / 24.0, .y = -6.0 / 24.0 },
        .end = .{ .x = 18.0 / 24.0, .y = 2.0 / 24.0 },
    } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "path parser rejects paths that do not start with moveto" {
    var iter = PathIterator.init("L 1 1");
    try std.testing.expectError(error.InvalidPath, iter.next());
}

test "path parser supports implicit command repetition" {
    var iter = PathIterator.init("M 1 1 2 2 3 3 H 4 5 V 6 7 C 1 2 3 4 5 6 7 8 9 10 11 12");

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 1.0 / 24.0, .y = 1.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 2.0 / 24.0, .y = 2.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 3.0 / 24.0, .y = 3.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 4.0 / 24.0, .y = 3.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 5.0 / 24.0, .y = 3.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 5.0 / 24.0, .y = 6.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 5.0 / 24.0, .y = 7.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .cubic_to = .{
        .control0 = .{ .x = 1.0 / 24.0, .y = 2.0 / 24.0 },
        .control1 = .{ .x = 3.0 / 24.0, .y = 4.0 / 24.0 },
        .end = .{ .x = 5.0 / 24.0, .y = 6.0 / 24.0 },
    } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .cubic_to = .{
        .control0 = .{ .x = 7.0 / 24.0, .y = 8.0 / 24.0 },
        .control1 = .{ .x = 9.0 / 24.0, .y = 10.0 / 24.0 },
        .end = .{ .x = 11.0 / 24.0, .y = 12.0 / 24.0 },
    } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "path parser accepts compact svg number streams" {
    var iter = PathIterator.init("M10-5L.5.6L1e1-2e0");

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 10.0 / 24.0, .y = -5.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 0.5 / 24.0, .y = 0.6 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 10.0 / 24.0, .y = -2.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "path parser rejects malformed exponent numbers" {
    var iter = PathIterator.init("M 1e 2");

    try std.testing.expectError(error.InvalidPath, iter.next());
}

test "path parser rejects non finite numeric values" {
    var iter = PathIterator.init("M 1e9999 0");

    try std.testing.expectError(error.InvalidPath, iter.next());
}

test "path parser rejects invalid comma separators" {
    var leading = PathIterator.init("M ,0 1");
    try std.testing.expectError(error.InvalidPath, leading.next());

    var repeated = PathIterator.init("M 0,,1");
    try std.testing.expectError(error.InvalidPath, repeated.next());

    var trailing = PathIterator.init("M 0 1,");
    _ = try trailing.next();
    try std.testing.expectError(error.InvalidPath, trailing.next());
}

test "path parser requires a command after closepath before more coordinates" {
    var iter = PathIterator.init("M 1 1 Z 2 2");

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 1.0 / 24.0, .y = 1.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op.close_path, (try iter.next()).?);
    try std.testing.expectError(error.InvalidPath, iter.next());
}

test "svg iterator normalizes path coordinates through viewBox" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="10 20 100 200" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path d='M 10 20 L 110 220 A 50 100 0 0 1 60 120'/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.0, .y = 0.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 1.0, .y = 1.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .arc_to = .{
        .rx = 0.5,
        .ry = 0.5,
        .x_axis_rotation = 0.0,
        .large_arc = false,
        .sweep = true,
        .end = .{ .x = 0.5, .y = 0.5 },
    } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator lowers basic shape elements" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 10" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <circle cx="10" cy="5" r="2"/>
        \\  <ellipse cx="5" cy="5" rx="4" ry="2"/>
        \\  <line x1="0" y1="0" x2="20" y2="10"/>
        \\  <polyline points="0,10 10,0 20,10"/>
        \\  <polygon points="2,2 18,2 10,8"/>
        \\  <rect x="2" y="1" width="6" height="4" rx="1"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .ellipse = .{ .cx = 0.5, .cy = 0.5, .rx = 0.1, .ry = 0.2, .full = true } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .ellipse = .{ .cx = 0.25, .cy = 0.5, .rx = 0.2, .ry = 0.2, .full = true } }, (try iter.next()).?);
    const line = (try iter.next()).?.polyline;
    try std.testing.expectEqualSlices(f32, &.{ 0.0, 0.0, 1.0, 1.0 }, line);
    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.0, .y = 1.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 0.5, .y = 0.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 1.0, .y = 1.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.1, .y = 0.2 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 0.9, .y = 0.2 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 0.5, .y = 0.8 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op.close_path, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .round_rect = .{ .x = 0.1, .y = 0.1, .w = 0.3, .h = 0.4, .radius = 0.05 } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator lowers default filled shape elements" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 10">
        \\  <path d="M 2 2 L 10 2 L 6 8"/>
        \\  <circle cx="10" cy="5" r="2"/>
        \\  <ellipse cx="5" cy="5" rx="4" ry="2"/>
        \\  <polyline points="1,9 5,1 9,9"/>
        \\  <rect x="2" y="1" width="6" height="4" rx="1"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .paint_rgba = .{ .r = 0, .g = 0, .b = 0, .a = 255 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op.begin_fill_path, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.1, .y = 0.2 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 0.5, .y = 0.2 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 0.3, .y = 0.8 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op.end_fill_path, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .filled_ellipse = .{ .cx = 0.5, .cy = 0.5, .rx = 0.1, .ry = 0.2, .full = true } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .filled_ellipse = .{ .cx = 0.25, .cy = 0.5, .rx = 0.2, .ry = 0.2, .full = true } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op.begin_fill_path, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.05, .y = 0.9 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 0.25, .y = 0.1 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 0.45, .y = 0.9 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op.close_path, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op.end_fill_path, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .filled_round_rect = .{ .x = 0.1, .y = 0.1, .w = 0.3, .h = 0.4, .radius = 0.05 } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator lowers explicit fill rules" {
    var nonzero = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill-rule="nonzero">
        \\  <path d="M 4 4 L 20 4 L 12 20"/>
        \\</svg>
    );
    try std.testing.expectEqual(icon_vector.Op{ .paint_rgba = .{ .r = 0, .g = 0, .b = 0, .a = 255 } }, (try nonzero.next()).?);
    try std.testing.expectEqual(icon_vector.Op.begin_fill_path, (try nonzero.next()).?);

    var evenodd = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill-rule="evenodd">
        \\  <path d="M 4 4 L 20 4 L 12 20"/>
        \\</svg>
    );
    try std.testing.expectEqual(icon_vector.Op{ .paint_rgba = .{ .r = 0, .g = 0, .b = 0, .a = 255 } }, (try evenodd.next()).?);
    try std.testing.expectEqual(icon_vector.Op.begin_evenodd_fill_path, (try evenodd.next()).?);
}

test "svg iterator applies fill and stroke paint defaults explicitly" {
    var filled = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#1a2B3c" stroke="none">
        \\  <rect x="4" y="6" width="8" height="10"/>
        \\</svg>
    );
    try std.testing.expectEqual(icon_vector.Op{ .paint_rgba = .{ .r = 0x1a, .g = 0x2b, .b = 0x3c, .a = 255 } }, (try filled.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .filled_round_rect = .{ .x = 4.0 / 24.0, .y = 6.0 / 24.0, .w = 8.0 / 24.0, .h = 10.0 / 24.0, .radius = 0.0 } }, (try filled.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try filled.next());

    var stroke = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <circle cx="12" cy="12" r="4"/>
        \\</svg>
    );
    try std.testing.expectEqual(icon_vector.Op{ .circle = .{ .cx = 0.5, .cy = 0.5, .radius = 4.0 / 24.0 } }, (try stroke.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try stroke.next());
}

test "svg iterator parses common css color syntaxes" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
        \\  <rect fill="#abcd" x="0" y="0" width="1" height="1"/>
        \\  <rect fill="#11223344" x="2" y="0" width="1" height="1"/>
        \\  <rect fill="rgb(255 128 0)" x="4" y="0" width="1" height="1"/>
        \\  <rect fill="rgb(100% 50% 0% / 25%)" x="6" y="0" width="1" height="1"/>
        \\  <rect fill="rgba(1, 2, 3, .5)" x="8" y="0" width="1" height="1"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .paint_rgba = .{ .r = 0xaa, .g = 0xbb, .b = 0xcc, .a = 0xdd } }, (try iter.next()).?);
    _ = try iter.next();
    try std.testing.expectEqual(icon_vector.Op{ .paint_rgba = .{ .r = 0x11, .g = 0x22, .b = 0x33, .a = 0x44 } }, (try iter.next()).?);
    _ = try iter.next();
    try std.testing.expectEqual(icon_vector.Op{ .paint_rgba = .{ .r = 255, .g = 128, .b = 0, .a = 255 } }, (try iter.next()).?);
    _ = try iter.next();
    try std.testing.expectEqual(icon_vector.Op{ .paint_rgba = .{ .r = 255, .g = 128, .b = 0, .a = 64 } }, (try iter.next()).?);
    _ = try iter.next();
    try std.testing.expectEqual(icon_vector.Op{ .paint_rgba = .{ .r = 1, .g = 2, .b = 3, .a = 128 } }, (try iter.next()).?);
    _ = try iter.next();
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator rejects out of range css color components" {
    var rgb = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
        \\  <rect fill="rgb(256 0 0)" width="1" height="1"/>
        \\</svg>
    );
    try std.testing.expectError(error.UnsupportedSvgStroke, rgb.next());

    var percent = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
        \\  <rect fill="rgb(101% 0% 0%)" width="1" height="1"/>
        \\</svg>
    );
    try std.testing.expectError(error.UnsupportedSvgStroke, percent.next());

    var alpha = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
        \\  <rect fill="rgba(0, 0, 0, 2)" width="1" height="1"/>
        \\</svg>
    );
    try std.testing.expectError(error.UnsupportedSvgStroke, alpha.next());
}

test "svg iterator lowers mixed fill and stroke in paint order" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="black" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path d="M 4 4 L 20 4 L 12 20"/>
        \\  <circle cx="12" cy="12" r="4"/>
        \\</svg>
    );
    try std.testing.expectEqual(icon_vector.Op{ .paint_rgba = .{ .r = 0, .g = 0, .b = 0, .a = 255 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op.begin_fill_path, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 4.0 / 24.0, .y = 4.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 20.0 / 24.0, .y = 4.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 0.5, .y = 20.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op.end_fill_path, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op.paint_current_color, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 4.0 / 24.0, .y = 4.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 20.0 / 24.0, .y = 4.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 0.5, .y = 20.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .paint_rgba = .{ .r = 0, .g = 0, .b = 0, .a = 255 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .filled_circle = .{ .cx = 0.5, .cy = 0.5, .radius = 4.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op.paint_current_color, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .circle = .{ .cx = 0.5, .cy = 0.5, .radius = 4.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator skips elements with no visible paint" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="none">
        \\  <circle cx="12" cy="12" r="4"/>
        \\</svg>
    );
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator applies default zero geometry attributes" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="-10 -10 20 20" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <circle r="2"/>
        \\  <ellipse rx="4" ry="2"/>
        \\  <line x2="10" y2="10"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .circle = .{ .cx = 0.5, .cy = 0.5, .radius = 0.1 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .ellipse = .{ .cx = 0.5, .cy = 0.5, .rx = 0.2, .ry = 0.1, .full = true } }, (try iter.next()).?);
    const line = (try iter.next()).?.polyline;
    try std.testing.expectEqualSlices(f32, &.{ 0.5, 0.5, 1.0, 1.0 }, line);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator applies translate and scale transforms" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path transform="translate(10 20) scale(2)" d="M 0 0 L 5 10"/>
        \\  <circle transform="scale(2)" cx="10" cy="10" r="5"/>
        \\  <line transform="translate(5,10)" x1="0" y1="0" x2="10" y2="20"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.1, .y = 0.2 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 0.2, .y = 0.4 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .circle = .{ .cx = 0.2, .cy = 0.2, .radius = 0.1 } }, (try iter.next()).?);
    const line = (try iter.next()).?.polyline;
    try std.testing.expectEqualSlices(f32, &.{ 0.05, 0.1, 0.15, 0.3 }, line);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator accepts compact transform number streams" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path transform="translate(10-5)scale(.5.6)matrix(1e0 0 0 1e0-2e0 3)" d="M 4 5 L 6 7"/>
        \\</svg>
    );

    const start = (try iter.next()).?.move_to;
    try std.testing.expectApproxEqAbs(@as(f32, 11.0 / 24.0), start.x, transform_epsilon);
    try std.testing.expectApproxEqAbs(@as(f32, -0.2 / 24.0), start.y, transform_epsilon);
    const end = (try iter.next()).?.line_to;
    try std.testing.expectApproxEqAbs(@as(f32, 12.0 / 24.0), end.x, transform_epsilon);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0 / 24.0), end.y, transform_epsilon);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator rejects malformed transform numbers" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path transform="translate(1e 2)" d="M 0 0 L 1 1"/>
        \\</svg>
    );

    try std.testing.expectError(error.InvalidSvg, iter.next());
}

test "svg iterator rejects invalid transform list separators" {
    var leading = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path transform=",translate(1 2)" d="M 0 0 L 1 1"/>
        \\</svg>
    );
    try std.testing.expectError(error.InvalidSvg, leading.next());

    var repeated = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path transform="translate(1 2),,scale(2)" d="M 0 0 L 1 1"/>
        \\</svg>
    );
    try std.testing.expectError(error.InvalidSvg, repeated.next());

    var trailing = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path transform="translate(1 2)," d="M 0 0 L 1 1"/>
        \\</svg>
    );
    try std.testing.expectError(error.InvalidSvg, trailing.next());
}

test "svg iterator rejects invalid numeric list separators" {
    var view_box = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox=",0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path d="M 0 0 L 1 1"/>
        \\</svg>
    );
    try std.testing.expectError(error.InvalidSvg, view_box.next());

    var transform = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path transform="translate(1,,2)" d="M 0 0 L 1 1"/>
        \\</svg>
    );
    try std.testing.expectError(error.InvalidSvg, transform.next());
}

test "svg iterator supports negative scale transforms for paths" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="-10 0 20 20" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path transform="scale(-1 1)" d="M 1 2 L 3 4"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 9.0 / 20.0, .y = 2.0 / 20.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 7.0 / 20.0, .y = 4.0 / 20.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "path parser treats transform-collapsed arcs as lines" {
    var iter = PathIterator.initWithViewBoxTransform(
        "M 1 1 A 4 5 0 0 1 9 9",
        default_view_box,
        .{ .a = 0.0, .d = 1.0 },
    );

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.0, .y = 1.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 0.0, .y = 9.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator supports rotate and matrix transforms" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path transform="rotate(45)" d="M 0 0 L 1 1"/>
        \\  <path transform="matrix(1 0 0 1 2 3)" d="M 1 1 L 2 2"/>
        \\</svg>
    );

    const start = (try iter.next()).?.move_to;
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), start.x, transform_epsilon);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), start.y, transform_epsilon);
    const rotated = (try iter.next()).?.line_to;
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), rotated.x, transform_epsilon);
    try std.testing.expectApproxEqAbs(@as(f32, @sqrt(@as(f32, 2.0)) / 24.0), rotated.y, transform_epsilon);
    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 3.0 / 24.0, .y = 4.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 4.0 / 24.0, .y = 5.0 / 24.0 } }, (try iter.next()).?);
}

test "svg iterator supports skew transforms for path geometry" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path transform="skewX(45)" d="M 0 0 L 1 1"/>
        \\  <path transform="skewY(45)" d="M 1 1 L 2 1"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.0, .y = 0.0 } }, (try iter.next()).?);
    const skew_x = (try iter.next()).?.line_to;
    try std.testing.expectApproxEqAbs(@as(f32, 2.0 / 24.0), skew_x.x, transform_epsilon);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0 / 24.0), skew_x.y, transform_epsilon);
    const skew_y_start = (try iter.next()).?.move_to;
    try std.testing.expectApproxEqAbs(@as(f32, 1.0 / 24.0), skew_y_start.x, transform_epsilon);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0 / 24.0), skew_y_start.y, transform_epsilon);
    const skew_y_end = (try iter.next()).?.line_to;
    try std.testing.expectApproxEqAbs(@as(f32, 2.0 / 24.0), skew_y_end.x, transform_epsilon);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0 / 24.0), skew_y_end.y, transform_epsilon);
}

test "svg iterator rejects unsupported transform functions" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path transform="notARealSvgTransform(45)" d="M 0 0 L 1 1"/>
        \\</svg>
    );

    try std.testing.expectError(error.UnsupportedSvgElement, iter.next());
}

test "svg iterator applies nested group transforms" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <g transform="translate(1 1)">
        \\    <g transform="scale(2)">
        \\      <path d="M 1 1 L 2 2"/>
        \\    </g>
        \\    <path d="M 0 0 L 1 1"/>
        \\  </g>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 3.0 / 24.0, .y = 3.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 5.0 / 24.0, .y = 5.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 1.0 / 24.0, .y = 1.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 2.0 / 24.0, .y = 2.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator rejects unclosed groups" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <g>
        \\    <path d="M 0 0 L 1 1"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.0, .y = 0.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 1.0 / 24.0, .y = 1.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectError(error.InvalidSvg, iter.next());
}

test "svg iterator treats defs as non-rendered definitions" {
    var definitions_only = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <defs>
        \\    <path id="x" d="M 0 0 L 1 1"/>
        \\  </defs>
        \\</svg>
    );

    try std.testing.expectEqual(@as(?icon_vector.Op, null), try definitions_only.next());

    var unsupported_outside_defs = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <mask id="x"/>
        \\</svg>
    );

    try std.testing.expectError(error.UnsupportedSvgElement, unsupported_outside_defs.next());
}

test "svg iterator renders local use references" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <defs>
        \\    <path id="segment" d="M 1 2 L 3 4"/>
        \\  </defs>
        \\  <use href="#segment" x="4" y="5"/>
        \\  <use xlink:href="#segment" transform="translate(1 1)"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 5.0 / 24.0, .y = 7.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 7.0 / 24.0, .y = 9.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 2.0 / 24.0, .y = 3.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 4.0 / 24.0, .y = 5.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator applies use transforms to referenced shape elements" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <defs>
        \\    <circle id="dot" cx="2" cy="3" r="1"/>
        \\    <rect id="box" x="1" y="1" width="4" height="2"/>
        \\    <polyline id="line" points="1 1 2 2"/>
        \\  </defs>
        \\  <use href="#dot" x="4" y="5"/>
        \\  <use href="#box" transform="translate(2 3)"/>
        \\  <use href="#line" x="8" y="9"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .circle = .{ .cx = 6.0 / 24.0, .cy = 8.0 / 24.0, .radius = 1.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .round_rect = .{ .x = 3.0 / 24.0, .y = 4.0 / 24.0, .w = 4.0 / 24.0, .h = 2.0 / 24.0, .radius = 0.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 9.0 / 24.0, .y = 10.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 10.0 / 24.0, .y = 11.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator expands use references to reusable groups" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <defs>
        \\    <g id="pair" transform="translate(1 1)">
        \\      <path d="M 1 1 L 2 2"/>
        \\      <g transform="translate(2 0)">
        \\        <path d="M 3 3 L 4 4"/>
        \\      </g>
        \\    </g>
        \\  </defs>
        \\  <path d="M 0 0 L 1 0"/>
        \\  <use href="#pair" x="4" y="5"/>
        \\  <path d="M 10 10 L 11 10"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.0, .y = 0.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 1.0 / 24.0, .y = 0.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 6.0 / 24.0, .y = 7.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 7.0 / 24.0, .y = 8.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 10.0 / 24.0, .y = 9.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 11.0 / 24.0, .y = 10.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 10.0 / 24.0, .y = 10.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 11.0 / 24.0, .y = 10.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator expands use references to reusable symbols" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <defs>
        \\    <symbol id="glyph" transform="translate(2 3)">
        \\      <path d="M 1 1 L 2 2"/>
        \\      <circle cx="6" cy="6" r="1"/>
        \\    </symbol>
        \\  </defs>
        \\  <use href="#glyph" x="4" y="5"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 7.0 / 24.0, .y = 9.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 8.0 / 24.0, .y = 10.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .circle = .{ .cx = 12.0 / 24.0, .cy = 14.0 / 24.0, .radius = 1.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator applies use presentation before referenced presentation" {
    var inherited_stroke = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <defs>
        \\    <path id="segment" d="M 1 1 L 2 2"/>
        \\  </defs>
        \\  <use href="#segment" stroke="white"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 1.0 / 24.0, .y = 1.0 / 24.0 } }, (try inherited_stroke.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 2.0 / 24.0, .y = 2.0 / 24.0 } }, (try inherited_stroke.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try inherited_stroke.next());

    var reference_override = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <defs>
        \\    <path id="segment" stroke="#123456" d="M 1 1 L 2 2"/>
        \\  </defs>
        \\  <use href="#segment" stroke="white"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .paint_rgba = .{ .r = 0x12, .g = 0x34, .b = 0x56, .a = 255 } }, (try reference_override.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 1.0 / 24.0, .y = 1.0 / 24.0 } }, (try reference_override.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 2.0 / 24.0, .y = 2.0 / 24.0 } }, (try reference_override.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try reference_override.next());
}

test "svg iterator rejects unsupported use references explicitly" {
    var external = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <use href="icons.svg#segment"/>
        \\</svg>
    );

    try std.testing.expectError(error.UnsupportedSvgElement, external.next());

    var recursive = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <use id="self" href="#self"/>
        \\</svg>
    );

    try std.testing.expectError(error.UnsupportedSvgElement, recursive.next());
}

test "svg iterator skips metadata and rejects unknown elements" {
    var with_metadata = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <title>Search</title>
        \\  <desc>Decorative icon</desc>
        \\  <path d="M 0 0 L 1 1"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.0, .y = 0.0 } }, (try with_metadata.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 1.0 / 24.0, .y = 1.0 / 24.0 } }, (try with_metadata.next()).?);

    var unknown = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <foreignObject width="24" height="24"/>
        \\</svg>
    );

    try std.testing.expectError(error.UnsupportedSvgElement, unknown.next());
}

test "svg iterator rejects unsupported presentation attributes" {
    var filled = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="url(#paint)" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path d="M 0 0 L 1 1"/>
        \\</svg>
    );
    try std.testing.expectError(error.UnsupportedSvgStroke, filled.next());

    var square_cap = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="square" stroke-linejoin="round">
        \\  <path d="M 0 0 L 1 1"/>
        \\</svg>
    );
    try std.testing.expectError(error.UnsupportedSvgStroke, square_cap.next());

    var style = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path style="stroke-width: 4" d="M 0 0 L 1 1"/>
        \\</svg>
    );
    try std.testing.expectError(error.UnsupportedSvgStroke, style.next());
}

test "svg iterator uses svg default fill when stroke presentation is absent" {
    var filled = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
        \\  <path d="M 0 0 L 1 1"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .paint_rgba = .{ .r = 0, .g = 0, .b = 0, .a = 255 } }, (try filled.next()).?);
    try std.testing.expectEqual(icon_vector.Op.begin_fill_path, (try filled.next()).?);
}

test "svg iterator applies inherited group presentation" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
        \\  <g fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\    <path d="M 0 0 L 1 1"/>
        \\  </g>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.0, .y = 0.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 1.0 / 24.0, .y = 1.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator applies internal style element rules" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
        \\  <style>
        \\    /* real stylesheet text is not rendered */
        \\    path { fill: none; stroke: white; stroke-width: 2; stroke-linecap: round; stroke-linejoin: round; }
        \\    .hidden { display: none; }
        \\    #visible { visibility: visible; }
        \\  </style>
        \\  <path class="hidden" d="M 9 9 L 20 20"/>
        \\  <path id="visible" d="M 0 0 L 1 1"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.0, .y = 0.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 1.0 / 24.0, .y = 1.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator applies comma separated class style rules" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
        \\  <style>
        \\    .stroke, .accent { fill: none; stroke: white; stroke-width: 2; stroke-linecap: round; stroke-linejoin: round; }
        \\  </style>
        \\  <path class="accent other" d="M 0 0 L 1 1"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.0, .y = 0.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 1.0 / 24.0, .y = 1.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator lets inline style override internal style rules" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
        \\  <style>
        \\    path { fill: none; stroke: white; stroke-width: 2; stroke-linecap: round; stroke-linejoin: round; display: none; }
        \\  </style>
        \\  <path style="display: inline" d="M 0 0 L 1 1"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.0, .y = 0.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 1.0 / 24.0, .y = 1.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator rejects unsupported matching stylesheet declarations" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
        \\  <style>
        \\    path { fill: none; stroke: white; stroke-width: 2; stroke-linecap: square; stroke-linejoin: round; }
        \\  </style>
        \\  <path d="M 0 0 L 1 1"/>
        \\</svg>
    );

    try std.testing.expectError(error.UnsupportedSvgStroke, iter.next());
}

test "svg iterator skips display none elements and groups" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path display="none" fill="red" d="M 9 9 L 20 20"/>
        \\  <g style="display: none">
        \\    <foreignObject width="24" height="24"/>
        \\    <path fill="red" d="M 2 2 L 22 22"/>
        \\  </g>
        \\  <path d="M 0 0 L 1 1"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.0, .y = 0.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 1.0 / 24.0, .y = 1.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator skips hidden visibility elements and groups" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path visibility="hidden" fill="red" d="M 9 9 L 20 20"/>
        \\  <g style="visibility: collapse">
        \\    <foreignObject width="24" height="24"/>
        \\    <path fill="red" d="M 2 2 L 22 22"/>
        \\  </g>
        \\  <path visibility="visible" d="M 0 0 L 1 1"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.0, .y = 0.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 1.0 / 24.0, .y = 1.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator lets visible children override inherited hidden visibility" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <g visibility="hidden" transform="translate(1 1)">
        \\    <foreignObject width="24" height="24"/>
        \\    <path visibility="visible" d="M 0 0 L 1 1"/>
        \\  </g>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 1.0 / 24.0, .y = 1.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 2.0 / 24.0, .y = 2.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator does not let children override display none" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <g display="none">
        \\    <path visibility="visible" d="M 0 0 L 1 1"/>
        \\  </g>
        \\</svg>
    );

    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator lets inline style override display presentation attribute" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path display="none" style="display: inline" d="M 0 0 L 1 1"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.0, .y = 0.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 1.0 / 24.0, .y = 1.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator accepts visible svg display values" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path display="block" d="M 0 0 L 1 1"/>
        \\  <path style="display: inline-table" d="M 2 2 L 3 3"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.0, .y = 0.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 1.0 / 24.0, .y = 1.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 2.0 / 24.0, .y = 2.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 3.0 / 24.0, .y = 3.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator lets inline style override visibility presentation attribute" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path visibility="hidden" style="visibility: visible" d="M 0 0 L 1 1"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.0, .y = 0.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 1.0 / 24.0, .y = 1.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator skips zero opacity elements and groups" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path opacity="0" fill="red" d="M 9 9 L 20 20"/>
        \\  <g style="opacity: 0">
        \\    <foreignObject width="24" height="24"/>
        \\    <path fill="red" d="M 2 2 L 22 22"/>
        \\  </g>
        \\  <path d="M 0 0 L 1 1"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.0, .y = 0.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 1.0 / 24.0, .y = 1.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator skips zero stroke opacity elements and allows visible override" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path stroke-opacity="0" d="M 9 9 L 20 20"/>
        \\  <g style="stroke-opacity: 0">
        \\    <path stroke-opacity="1" d="M 0 0 L 1 1"/>
        \\  </g>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.0, .y = 0.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 1.0 / 24.0, .y = 1.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator accepts opaque fill and stroke opacity as no-op" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill-opacity="1">
        \\  <path style="stroke-opacity: 1; fill-opacity: 1" d="M 0 0 L 1 1"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.0, .y = 0.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 1.0 / 24.0, .y = 1.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator accepts fractional fill opacity under fill none contract" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" fill-opacity="0.5" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path style="fill-opacity: .25" d="M 0 0 L 1 1"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.0, .y = 0.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 1.0 / 24.0, .y = 1.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator accepts opaque opacity as no-op" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" opacity="1" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path style="opacity: 1.0" d="M 0 0 L 1 1"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.0, .y = 0.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 1.0 / 24.0, .y = 1.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator returns no ops when root display is none" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" display="none" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path d="M 0 0 L 1 1"/>
        \\</svg>
    );

    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator returns no ops when root visibility is hidden" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" style="visibility: hidden" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path d="M 0 0 L 1 1"/>
        \\</svg>
    );

    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator returns no ops when root opacity is zero" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" opacity="0" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path d="M 0 0 L 1 1"/>
        \\</svg>
    );

    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator rejects nonzero opacity because alpha compositing is unsupported" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" opacity="0.5" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path d="M 0 0 L 1 1"/>
        \\</svg>
    );

    try std.testing.expectError(error.UnsupportedSvgStroke, iter.next());

    var unit = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" opacity="1px" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path d="M 0 0 L 1 1"/>
        \\</svg>
    );

    try std.testing.expectError(error.InvalidSvg, unit.next());

    var stroke_partial = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path stroke-opacity="0.5" d="M 0 0 L 1 1"/>
        \\</svg>
    );

    try std.testing.expectError(error.UnsupportedSvgStroke, stroke_partial.next());

    var fill_out_of_range = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill-opacity="2" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path d="M 0 0 L 1 1"/>
        \\</svg>
    );

    try std.testing.expectError(error.UnsupportedSvgStroke, fill_out_of_range.next());
}

test "svg iterator rejects unsupported child presentation override" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path fill="url(#paint)" d="M 0 0 L 1 1"/>
        \\</svg>
    );

    try std.testing.expectError(error.UnsupportedSvgStroke, iter.next());
}

test "svg iterator treats stroke none as an inherited paint override" {
    var attr = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path stroke="none" d="M 0 0 L 1 1"/>
        \\</svg>
    );
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try attr.next());

    var style = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path style="stroke: none" d="M 0 0 L 1 1"/>
        \\</svg>
    );
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try style.next());
}

test "svg iterator supports inline style for stroke icon presentation" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" style="Fill: None ! important; Stroke: CURRENTCOLOR; stroke-width: 2PX; stroke-linecap: ROUND; stroke-linejoin: Round">
        \\  <path style="STROKE-WIDTH: 2PX !IMPORTANT; stroke-linecap: round; stroke-linejoin: round" d="M 0 0 L 1 1"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.0, .y = 0.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 1.0 / 24.0, .y = 1.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator accepts equivalent presentation keyword casing" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill=" NONE " stroke="#FFF" stroke-width="2" stroke-linecap="ROUND" stroke-linejoin="ROUND">
        \\  <path d="M 0 0 L 1 1"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.0, .y = 0.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 1.0 / 24.0, .y = 1.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator matches exact attribute names only" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" xmlns:edge="urn:edge" viewBox="0 0 24 24" fill-rule="nonzero" edge:fill="red" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path data-fill="red" d="M 0 0 L 1 1"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.0, .y = 0.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 1.0 / 24.0, .y = 1.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator ignores attribute-looking text inside quoted values" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" data-note=" fill='red' stroke-width='4' " viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path data-note=" fill='red' stroke='none' " d="M 0 0 L 1 1"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.0, .y = 0.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 1.0 / 24.0, .y = 1.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator rejects malformed attributes on supported elements" {
    var unquoted = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path data-note=bad d="M 0 0 L 1 1"/>
        \\</svg>
    );
    try std.testing.expectError(error.InvalidSvg, unquoted.next());

    var missing_value = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path data-note d="M 0 0 L 1 1"/>
        \\</svg>
    );
    try std.testing.expectError(error.InvalidSvg, missing_value.next());
}

test "svg iterator keeps tag boundaries outside quoted attributes" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" data-root="24 > 12" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path data-note="1 > 0" d="M 0 0 L 1 1"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.0, .y = 0.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 1.0 / 24.0, .y = 1.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator supports px length attributes and rejects other units" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="none" stroke="white" stroke-width="2PX" stroke-linecap="round" stroke-linejoin="round">
        \\  <rect x="1PX" y="2PX" width="10PX" height="10PX" rx="3PX"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .round_rect = .{ .x = 0.05, .y = 0.1, .w = 0.5, .h = 0.5, .radius = 0.15 } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());

    var unsupported = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="none" stroke="white" stroke-width="2em" stroke-linecap="round" stroke-linejoin="round">
        \\  <rect width="10" height="10"/>
        \\</svg>
    );

    try std.testing.expectError(error.UnsupportedSvgStroke, unsupported.next());

    var non_finite = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <rect x="1e9999" y="0" width="10" height="10"/>
        \\</svg>
    );

    try std.testing.expectError(error.InvalidSvg, non_finite.next());
}

test "svg iterator accepts non self closing supported graphics elements" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path d="M 0 0 L 1 1"></path>
        \\  <circle cx="12" cy="12" r="3"></circle>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.0, .y = 0.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 1.0 / 24.0, .y = 1.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .circle = .{ .cx = 0.5, .cy = 0.5, .radius = 3.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator skips complete xml comments" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <!-- <path d="M 9 9 L 20 20"> should not be seen -->
        \\  <path d="M 0 0 L 1 1"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.0, .y = 0.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 1.0 / 24.0, .y = 1.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator skips cdata sections that contain svg-looking tags" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <![CDATA[
        \\    <path d="M 9 9 L 20 20"/>
        \\    <defs><path d="M 1 1 L 2 2"/></defs>
        \\  ]]>
        \\  <path d="M 0 0 L 1 1"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.0, .y = 0.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 1.0 / 24.0, .y = 1.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator ignores prolog and commented out fake root" {
    var iter = Iterator.init(
        \\<?xml version="1.0" encoding="UTF-8"?>
        \\<!-- <svg viewBox="0 0 1 1"><path d="M 9 9 L 9 9"/></svg> -->
        \\<!DOCTYPE svg>
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path d="M 0 0 L 1 1"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.0, .y = 0.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 1.0 / 24.0, .y = 1.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator skips doctype internal subset before root" {
    var iter = Iterator.init(
        \\<!DOCTYPE svg [
        \\  <!ENTITY fake "<svg viewBox='0 0 1 1'><path d='M 9 9 L 9 9'/></svg>">
        \\]>
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path d="M 0 0 L 1 1"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.0, .y = 0.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 1.0 / 24.0, .y = 1.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator follows rect corner radius rules it can represent" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <rect x="1" y="2" width="10" height="10" ry="3"/>
        \\  <rect x="1" y="2" width="10" height="10" rx="9" ry="9"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .round_rect = .{ .x = 0.05, .y = 0.1, .w = 0.5, .h = 0.5, .radius = 0.15 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .round_rect = .{ .x = 0.05, .y = 0.1, .w = 0.5, .h = 0.5, .radius = 0.25 } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator rejects rect corner radii it cannot represent" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <rect x="1" y="2" width="10" height="10" rx="2" ry="3"/>
        \\</svg>
    );

    try std.testing.expectError(error.UnsupportedSvgElement, iter.next());
}

test "svg iterator rejects malformed optional rect attributes" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <rect x="wat" y="0" width="10" height="10"/>
        \\</svg>
    );

    try std.testing.expectError(error.InvalidSvg, iter.next());
}

test "svg iterator rejects missing viewBox in strict icon svg path" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg">
        \\  <path d="M 0 0 L 1 1"/>
        \\</svg>
    );

    try std.testing.expectError(error.InvalidSvg, iter.next());
}

test "path parser supports relative quadratic commands" {
    var iter = PathIterator.init("M 4 4 q 4 6 8 0 t 8 0");

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 4.0 / 24.0, .y = 4.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .quad_to = .{
        .control = .{ .x = 8.0 / 24.0, .y = 10.0 / 24.0 },
        .end = .{ .x = 12.0 / 24.0, .y = 4.0 / 24.0 },
    } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .quad_to = .{
        .control = .{ .x = 16.0 / 24.0, .y = -2.0 / 24.0 },
        .end = .{ .x = 20.0 / 24.0, .y = 4.0 / 24.0 },
    } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "path parser follows svg arc radius normalization" {
    var iter = PathIterator.init("M 1 1 A -4 -5 0 0 1 9 9 A 0 5 0 0 1 12 12");

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 1.0 / 24.0, .y = 1.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .arc_to = .{
        .rx = 4.0 / 24.0,
        .ry = 5.0 / 24.0,
        .x_axis_rotation = 0.0,
        .large_arc = false,
        .sweep = true,
        .end = .{ .x = 9.0 / 24.0, .y = 9.0 / 24.0 },
    } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 12.0 / 24.0, .y = 12.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "path parser accepts packed svg arc flags" {
    var iter = PathIterator.init("M 1 1 A 5 6 0 0110 10");

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 1.0 / 24.0, .y = 1.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .arc_to = .{
        .rx = 5.0 / 24.0,
        .ry = 6.0 / 24.0,
        .x_axis_rotation = 0.0,
        .large_arc = false,
        .sweep = true,
        .end = .{ .x = 10.0 / 24.0, .y = 10.0 / 24.0 },
    } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "smooth quadratic resets after non quadratic command" {
    var iter = PathIterator.init("M 2 2 Q 6 10 10 2 L 12 2 T 18 2");

    _ = try iter.next();
    _ = try iter.next();
    _ = try iter.next();
    try std.testing.expectEqual(icon_vector.Op{ .quad_to = .{
        .control = .{ .x = 12.0 / 24.0, .y = 2.0 / 24.0 },
        .end = .{ .x = 18.0 / 24.0, .y = 2.0 / 24.0 },
    } }, (try iter.next()).?);
}

test "all mapped tabler svgs parse without invalid path data" {
    inline for (std.meta.fields(icon.Icon)) |field| {
        var iter = Iterator.init(source(@enumFromInt(field.value)));
        var count: usize = 0;
        while (try iter.next()) |_| count += 1;
        try std.testing.expect(count > 0);
    }
}

test "all mapped tabler svgs match supported stroke contract" {
    inline for (std.meta.fields(icon.Icon)) |field| {
        try validateSupportedTablerStroke(source(@enumFromInt(field.value)));
    }
}
