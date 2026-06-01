const std = @import("er_std");
const clock = @import("../../clock.zig");
const common = @import("../component_common.zig");
const object = @import("../../object.zig");
const ui = @import("../core.zig");
const text_component = @import("Text.zig");
const layout = @import("../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const component_primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;
const constrainPreferredSize = component_primitives.constrainPreferredSize;
const contentInset = component_primitives.contentInset;

pub const Separator = struct {
    const serialization = component_codec.EmptyComponent(Separator, "separator");

    pub fn node(self: Separator) ui.Node {
        _ = self;
        return ui.separatorNode();
    }

    pub fn render(self: Separator, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        _ = self;
        const line = ui.Rect.init(bounds.x, bounds.y + (bounds.h - separator_height) * 0.5, bounds.w, separator_height);
        try scene.pushRect(line, options.style.border, .fill, 0.0, 0.0);
    }

    pub fn measure(self: Separator, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureFlexibleLine(separator_height, constraints);
    }

    pub const toObject = serialization.toObject;
    pub const writeRecord = serialization.writeRecord;
    pub const fromView = serialization.fromView;

    pub fn fromNode(separator: @FieldType(ui.Node, "separator")) Error!Separator {
        _ = separator;
        return .{};
    }
};

pub const Skeleton = struct {
    const serialization = component_codec.EmptyComponent(Skeleton, "skeleton");

    pub fn node(self: Skeleton) ui.Node {
        _ = self;
        return ui.skeletonNode();
    }

    pub fn render(self: Skeleton, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        _ = self;
        var fill = options.style.accent;
        fill.a = skeleton_alpha;
        try scene.pushRect(bounds, fill, .fill, skeleton_radius, 0.0);
    }

    pub fn measure(self: Skeleton, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        const preferred = constrainPreferredSize(.{ .w = skeleton_min_width, .h = skeleton_height }, constraints);
        return layout.Measurement.flexible(
            .{ .w = @min(component_primitives.min_extent, preferred.w), .h = @min(skeleton_height, preferred.h) },
            preferred,
            .{ .w = component_primitives.maxMeasuredWidth(constraints, preferred.w), .h = preferred.h },
        ).applyExact(constraints);
    }

    pub const toObject = serialization.toObject;
    pub const writeRecord = serialization.writeRecord;
    pub const fromView = serialization.fromView;

    pub fn fromNode(skeleton: @FieldType(ui.Node, "skeleton")) Error!Skeleton {
        _ = skeleton;
        return .{};
    }
};

pub const Spinner = struct {
    const serialization = component_codec.EmptyComponent(Spinner, "spinner");

    pub fn node(self: Spinner) ui.Node {
        _ = self;
        return ui.spinnerNode();
    }

    pub fn render(self: Spinner, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        _ = self;
        const size = @min(spinner_size, @max(component_primitives.min_extent, @min(bounds.w, bounds.h)));
        const spinner = ui.Rect.init(bounds.x + (bounds.w - size) * 0.5, bounds.y + (bounds.h - size) * 0.5, size, size);
        try scene.pushRect(spinner, options.style.border, .border, size * 0.5, 0.0);
        try scene.pushPieSlice(spinner.insetUniform(spinner_slice_inset), options.style.accent, spinner_start_turn, spinner_end_turn);
    }

    pub fn measure(self: Spinner, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureIntrinsic(.{ .w = spinner_size, .h = spinner_size }, constraints);
    }

    pub const toObject = serialization.toObject;
    pub const writeRecord = serialization.writeRecord;
    pub const fromView = serialization.fromView;

    pub fn fromNode(spinner: @FieldType(ui.Node, "spinner")) Error!Spinner {
        _ = spinner;
        return .{};
    }
};

pub const Progress = struct {
    value: f32,

    pub fn node(self: Progress) ui.Node {
        return ui.progressNode(self.value);
    }

    pub fn render(self: Progress, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const track = ui.Rect.init(bounds.x, bounds.y + (bounds.h - progress_height) * 0.5, bounds.w, progress_height);
        try renderTrack(scene, track, self.value, options);
    }

    pub fn measure(self: Progress, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        const preferred = constrainPreferredSize(.{ .w = progress_min_width, .h = progress_height }, constraints);
        return layout.Measurement.flexible(
            .{ .w = @min(progress_min_width, preferred.w), .h = @min(progress_height, preferred.h) },
            preferred,
            .{ .w = component_primitives.maxMeasuredWidth(constraints, preferred.w), .h = preferred.h },
        ).applyExact(constraints);
    }

    pub fn toObject(self: Progress, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.refObject(.progress, 0, component_codec.unitRef(self.value), ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Progress, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.refRecord(writer, index, .progress, 0, component_codec.unitRef(self.value));
    }

    pub fn fromView(view: object.View) Error!Progress {
        return component_codec.decodeFromView(Progress, .progress, view);
    }

    pub fn fromNode(progress: @FieldType(ui.Node, "progress")) Error!Progress {
        return .{ .value = progress.value };
    }
};

pub const AspectRatio = struct {
    ratio_w: u16 = 16,
    ratio_h: u16 = 9,

    pub fn node(self: AspectRatio) ui.Node {
        return ui.aspectRatioNode(self.ratio_w, self.ratio_h);
    }

    pub fn render(self: AspectRatio, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const frame = frameBounds(bounds, self.ratio_w, self.ratio_h);
        try scene.pushRect(frame, options.style.row, .fill, component_primitives.control_radius, 0.0);
        try scene.pushRect(frame, options.style.border, .border, component_primitives.control_radius, 0.0);
    }

    pub fn measure(self: AspectRatio, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        return measureIntrinsic(aspectRatioIntrinsicSize(self.ratio_w, self.ratio_h), constraints);
    }

    pub fn toObject(self: AspectRatio, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.refObject(.aspect_ratio, 0, .{ .offset = self.ratio_w, .len = self.ratio_h }, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: AspectRatio, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.refRecord(writer, index, .aspect_ratio, 0, .{ .offset = self.ratio_w, .len = self.ratio_h });
    }

    pub fn fromView(view: object.View) Error!AspectRatio {
        return component_codec.decodeFromView(AspectRatio, .aspect_ratio, view);
    }

    pub fn fromNode(aspect_ratio: @FieldType(ui.Node, "aspect_ratio")) Error!AspectRatio {
        return .{ .ratio_w = aspect_ratio.ratio_w, .ratio_h = aspect_ratio.ratio_h };
    }
};

pub const Kbd = struct {
    label: []const u8,

    const serialization = component_codec.OneStringFixedIdComponent(Kbd, "kbd", 0, "label");

    pub fn node(self: Kbd) ui.Node {
        return ui.kbdNode(self.label);
    }

    pub fn render(self: Kbd, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const height = @min(kbd_height, @max(component_primitives.min_extent, bounds.h));
        const kbd_bounds = ui.Rect.init(bounds.x, bounds.y + (bounds.h - height) * 0.5, bounds.w, height);
        try scene.pushRect(kbd_bounds, options.style.row, .fill, component_primitives.control_radius, 0.0);
        try scene.pushRect(kbd_bounds, options.style.border, .border, component_primitives.control_radius, 0.0);
        if (contentInset(kbd_bounds, kbd_label_padding)) |text_bounds| {
            try text_component.Text.renderAligned(scene, text_bounds.withHeightCentered(kbd_text_height), self.label, options.style.text, .center);
        }
    }

    pub fn measure(self: Kbd, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        const label = text_component.Text.measureValue(self.label, constraints.inner(.{ .left = kbd_label_padding, .right = kbd_label_padding }), component_primitives.textMetrics(self.label, kbd_text_height, kbd_label_max_lines));
        const preferred = constrainPreferredSize(.{
            .w = @max(kbd_min_width, label.preferred.w + kbd_label_padding * 2.0),
            .h = @max(kbd_height, label.preferred.h + kbd_label_padding),
        }, constraints);
        return layout.Measurement.flexible(
            .{ .w = @min(kbd_min_width, preferred.w), .h = @min(kbd_height, preferred.h) },
            preferred,
            .{ .w = component_primitives.maxMeasuredWidth(constraints, preferred.w), .h = preferred.h },
        ).applyExact(constraints);
    }

    pub const toObject = serialization.toObject;
    pub const writeRecord = serialization.writeRecord;
    pub const fromView = serialization.fromView;

    pub fn fromNode(kbd: @FieldType(ui.Node, "kbd")) Error!Kbd {
        return .{ .label = kbd.label };
    }
};

pub const Avatar = struct {
    label: []const u8,

    const serialization = component_codec.OneStringFixedIdComponent(Avatar, "avatar", 0, "label");

    pub fn node(self: Avatar) ui.Node {
        return ui.avatarNode(self.label);
    }

    pub fn accessibility(self: Avatar) common.Accessibility {
        return .{ .role = .image, .label = self.label };
    }

    pub fn render(self: Avatar, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const size = @min(avatar_size, @max(component_primitives.min_extent, @min(bounds.w, bounds.h)));
        const avatar_bounds = ui.Rect.init(bounds.x + (bounds.w - size) * 0.5, bounds.y + (bounds.h - size) * 0.5, size, size);
        try scene.pushRect(avatar_bounds, options.style.row, .fill, size * 0.5, 0.0);
        try scene.pushRect(avatar_bounds, options.style.border, .border, size * 0.5, 0.0);
        if (contentInset(avatar_bounds, avatar_label_inset)) |text_bounds| {
            try text_component.Text.renderAligned(scene, text_bounds.withHeightCentered(avatar_text_height), self.label, options.style.text, .center);
        }
    }

    pub fn measure(self: Avatar, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureIntrinsic(.{ .w = avatar_size, .h = avatar_size }, constraints);
    }

    pub const toObject = serialization.toObject;
    pub const writeRecord = serialization.writeRecord;
    pub const fromView = serialization.fromView;

    pub fn fromNode(avatar: @FieldType(ui.Node, "avatar")) Error!Avatar {
        return .{ .label = avatar.label };
    }
};

pub const Label = struct {
    value: []const u8,

    const serialization = component_codec.OneStringFixedIdComponent(Label, "label", 0, "value");

    pub fn node(self: Label) ui.Node {
        return ui.labelNode(self.value);
    }

    pub fn render(self: Label, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const text_h = @min(bounds.h, component_primitives.measuredTextHeight(self.value, bounds.w, label_height, label_max_lines));
        try text_component.Text.renderWrapped(scene, bounds.withHeightCentered(text_h), self.value, options.style.text, component_primitives.textWrap(self.value, label_height, label_max_lines));
    }

    pub fn measure(self: Label, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        const measured = text_component.Text.measureValue(self.value, constraints, component_primitives.textMetrics(self.value, label_height, label_max_lines));
        const preferred = constrainPreferredSize(measured.preferred, constraints);
        return layout.Measurement.flexible(
            .{ .w = @min(label_min_width, preferred.w), .h = @min(label_height, preferred.h) },
            preferred,
            measured.max,
        ).applyExact(constraints);
    }

    pub const toObject = serialization.toObject;
    pub const writeRecord = serialization.writeRecord;
    pub const fromView = serialization.fromView;

    pub fn fromNode(label: @FieldType(ui.Node, "label")) Error!Label {
        return .{ .value = label.value };
    }
};

fn renderTrack(scene: *ui.Scene, track: ui.Rect, value: f32, options: RenderOptions) ui.RenderError!void {
    if (track.w <= 0.0 or track.h <= 0.0) return;
    try scene.pushGradientRect(track, options.style.row, progress_floor, progress_height * 0.5);
    const clamped = ui.clampUnit(value);
    const fill_width = @min(track.w, @max(0.0, track.w * clamped));
    try scene.pushRect(ui.Rect.init(track.x, track.y, fill_width, track.h), options.style.accent, .fill, progress_height * 0.5, 0.0);
}

fn measureIntrinsic(size: ui.Size, constraints: layout.Constraints) layout.Measurement {
    const preferred = constrainPreferredSize(size, constraints);
    return layout.Measurement.flexible(preferred, preferred, preferred).applyExact(constraints);
}

fn measureFlexibleLine(height: f32, constraints: layout.Constraints) layout.Measurement {
    const preferred = constrainPreferredSize(.{ .w = separator_min_width, .h = height }, constraints);
    return layout.Measurement.flexible(
        .{ .w = @min(separator_min_width, preferred.w), .h = @min(height, preferred.h) },
        preferred,
        .{ .w = component_primitives.maxMeasuredWidth(constraints, preferred.w), .h = preferred.h },
    ).applyExact(constraints);
}

fn frameBounds(bounds: ui.Rect, ratio_w: u16, ratio_h: u16) ui.Rect {
    const safe_w = @max(@as(f32, @floatFromInt(ratio_w)), component_primitives.min_extent);
    const safe_h = @max(@as(f32, @floatFromInt(ratio_h)), component_primitives.min_extent);
    const frame_w = @min(bounds.w, bounds.h * safe_w / safe_h);
    const frame_h = @min(bounds.h, frame_w * safe_h / safe_w);
    return ui.Rect.init(bounds.x + (bounds.w - frame_w) * 0.5, bounds.y + (bounds.h - frame_h) * 0.5, frame_w, frame_h);
}

fn aspectRatioIntrinsicSize(ratio_w: u16, ratio_h: u16) ui.Size {
    const safe_w = @max(@as(f32, @floatFromInt(ratio_w)), component_primitives.min_extent);
    const safe_h = @max(@as(f32, @floatFromInt(ratio_h)), component_primitives.min_extent);
    return .{ .w = aspect_ratio_min_width, .h = aspect_ratio_min_width * safe_h / safe_w };
}

const separator_height: f32 = 1.0;
const separator_min_width: f32 = 1.0;
const skeleton_alpha: u8 = 32;
const skeleton_radius: f32 = 6.0;
const skeleton_min_width: f32 = 96.0;
const skeleton_height: f32 = 20.0;
const spinner_size: f32 = 28.0;
const spinner_slice_inset: f32 = 3.0;
const spinner_start_turn: f32 = 0.08;
const spinner_end_turn: f32 = 0.78;
const progress_height: f32 = 8.0;
const progress_min_width: f32 = 96.0;
const progress_floor = ui.Color{ .r = 5, .g = 7, .b = 10, .a = 72 };
const aspect_ratio_min_width: f32 = 160.0;
const kbd_height: f32 = 24.0;
const kbd_text_height: f32 = 12.0;
const kbd_label_max_lines: usize = 1;
const kbd_label_padding: f32 = 8.0;
const kbd_min_width: f32 = 24.0;
const avatar_size: f32 = 40.0;
const avatar_text_height: f32 = 14.0;
const avatar_label_inset: f32 = 6.0;
const label_height: f32 = 16.0;
const label_min_width: f32 = 24.0;
const label_max_lines: usize = 2;

test "separator component renders centered border line" {
    var commands: [4]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    const border = ui.Color{ .r = 9, .g = 8, .b = 7 };
    try (Separator{}).render(&scene, ui.Rect.init(4, 10, 120, 9), .{ .style = .{ .border = border } });
    const line = component_test.fillRectColor(scene.written(), border).?;
    try std.testing.expectEqual(ui.Rect.init(4, 14, 120, 1), line);
}

test "skeleton component renders muted accent pulse base" {
    var commands: [4]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try (Skeleton{}).render(&scene, ui.Rect.init(8, 12, 120, 20), .{});
    const rect = component_test.lastFillRect(scene.written()).?;
    try std.testing.expectEqual(ui.Rect.init(8, 12, 120, 20), rect);
}

test "spinner component renders deterministic status mark" {
    const spinner = Spinner{};
    var commands: [8]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try spinner.render(&scene, ui.Rect.init(0, 0, 32, 32), .{});
    try std.testing.expectEqual(@as(usize, 2), scene.written().len);
    try std.testing.expectEqual(ui.RectMode.border, scene.written()[0].rect.mode);
    try std.testing.expectEqual(ui.RectMode.pie_slice, scene.written()[1].rect.mode);
}

test "progress component clamps rendered fill to track" {
    const progress = Progress{ .value = 2.0 };
    var commands: [8]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    const bounds = ui.Rect.init(0, 0, 120, 10);
    try progress.render(&scene, bounds, .{});
    const fill = component_test.fillRectColor(scene.written(), ui.Color.accent).?;
    try std.testing.expectEqual(@as(f32, 120.0), fill.w);
    try std.testing.expect(fill.x + fill.w <= bounds.x + bounds.w);
}

test "aspect ratio component keeps frame inside bounds" {
    const ratio = AspectRatio{ .ratio_w = 16, .ratio_h = 9 };
    var commands: [4]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try ratio.render(&scene, ui.Rect.init(0, 0, 160, 160), .{});
    const frame = component_test.lastFillRect(scene.written()).?;
    try std.testing.expectEqual(@as(f32, 160.0), frame.w);
    try std.testing.expect(frame.h < frame.w);
}

test "kbd component centers label through shared control text" {
    const kbd = Kbd{ .label = "Ctrl" };
    var commands: [8]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try kbd.render(&scene, ui.Rect.init(10, 20, 48, 32), .{});
    const label = component_test.textCommand(scene.written(), "Ctrl").?;
    try std.testing.expectEqual(ui.TextAlign.center, label.text.alignment);
    try std.testing.expectEqual(@as(f32, 18.0), label.text.origin.x);
    try std.testing.expectEqual(@as(f32, 32.0), label.text.origin.y);
    try std.testing.expectEqual(@as(f32, 8.0), label.text.origin.h);
}

test "avatar component centers initials through shared control text" {
    const avatar = Avatar{ .label = "ER" };
    var commands: [8]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try avatar.render(&scene, ui.Rect.init(10, 20, 64, 48), .{});
    const label = component_test.textCommand(scene.written(), "ER").?;
    try std.testing.expectEqual(ui.TextAlign.center, label.text.alignment);
    try std.testing.expectEqual(@as(f32, 28.0), label.text.origin.x);
    try std.testing.expectEqual(@as(f32, 37.0), label.text.origin.y);
}

test "label component renders its own text slot" {
    const label = Label{ .value = "Email" };
    var commands: [4]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try label.render(&scene, ui.Rect.init(0, 0, 96, 24), .{});
    const text_command = component_test.textCommand(scene.written(), "Email").?;
    try std.testing.expectEqual(ui.Color.text, text_command.text.color);
    try std.testing.expectEqual(@as(f32, 4.0), text_command.text.origin.y);
}

test "label measurement wraps long values under narrow constraints" {
    const label = Label{ .value = "Runtime authority label" };
    const measured = label.measure(.{ .width = .{ .at_most = label_wrap_test_width }, .text_wrap = .wrap }, .{});
    try std.testing.expect(measured.preferred.w <= label_wrap_test_width);
    try std.testing.expect(measured.preferred.h > label_height);
}

test "display primitive measurements derive from local geometry" {
    try std.testing.expectEqual(separator_height, (Separator{}).measure(.{}, .{}).preferred.h);
    try std.testing.expectEqual(skeleton_height, (Skeleton{}).measure(.{}, .{}).preferred.h);
    try std.testing.expectEqual(spinner_size, (Spinner{}).measure(.{}, .{}).preferred.w);
    try std.testing.expectEqual(progress_height, (Progress{ .value = 0.5 }).measure(.{}, .{}).preferred.h);
    try std.testing.expectEqual(aspectRatioIntrinsicSize(16, 9).h, (AspectRatio{ .ratio_w = 16, .ratio_h = 9 }).measure(.{}, .{}).preferred.h);
    try std.testing.expectEqual(avatar_size, (Avatar{ .label = "ER" }).measure(.{}, .{}).preferred.w);
}

const label_wrap_test_width: f32 = 48.0;
