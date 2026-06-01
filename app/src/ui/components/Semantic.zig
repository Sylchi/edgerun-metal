const common = @import("../component_common.zig");
const ui = @import("../core.zig");
const ui_icon = @import("../icon.zig");

pub const Kind = enum {
    identity,
    metric,
    resource,
    path,
    event,
    action,
    artifact,
    warning,
    dependency,
    timeline,
};

pub const Importance = enum {
    primary,
    normal,
    support,
    background,
};

pub const State = enum {
    neutral,
    active,
    good,
    warning,
    bad,
    blocked,
    private,
    pending,
};

pub const Mode = enum {
    overview,
    inspect,
    compare,
    schedule,
    timeline,
    debug,
};

pub const Focus = enum {
    general,
    resources,
    paths,
    dependencies,
    privacy,
    errors,
};

pub const Density = enum {
    compact,
    normal,
    expanded,
};

pub const Intent = struct {
    mode: Mode = .overview,
    focus: Focus = .general,
    density: Density = .normal,
};

pub const Item = struct {
    id: u32 = 0,
    kind: Kind,
    label: []const u8,
    value: []const u8 = "",
    detail: []const u8 = "",
    importance: Importance = .normal,
    state: State = .neutral,
    progress: ?f32 = null,
    selected: bool = false,
    accent: ?ui.Color = null,
};

pub const ViewProps = struct {
    title: []const u8 = "",
    detail: []const u8 = "",
    intent: Intent = .{},
    items: []const Item,
};

pub fn controlId(item: Item) ?u32 {
    return if (item.id == 0) null else item.id;
}

pub fn promotes(item: Item, intent: Intent) bool {
    if (item.importance == .primary) return true;
    return switch (intent.focus) {
        .resources => item.kind == .resource and item.importance != .background,
        .paths => item.kind == .path and item.importance != .background,
        .dependencies => item.kind == .dependency and item.importance != .background,
        .privacy => item.state == .private,
        .errors => item.state == .bad or item.state == .blocked or item.kind == .warning,
        .general => false,
    };
}

pub fn primarySlots(bounds: ui.Rect, props: ViewProps) usize {
    if (bounds.h < 150.0) return 0;
    var count: usize = 0;
    for (props.items) |item| {
        if (promotes(item, props.intent)) count += 1;
    }
    if (count == 0) return 0;
    const max_slots: usize = if (bounds.w >= 720.0) 3 else if (bounds.w >= 440.0) 2 else 1;
    return @min(count, max_slots);
}

pub fn primaryHeight(density: Density) f32 {
    return switch (density) {
        .compact => 88.0,
        .normal => 104.0,
        .expanded => 122.0,
    };
}

pub fn rowHeight(density: Density) f32 {
    return switch (density) {
        .compact => 36.0,
        .normal => 44.0,
        .expanded => 54.0,
    };
}

pub fn gap(density: Density) f32 {
    return switch (density) {
        .compact => 6.0,
        .normal => 10.0,
        .expanded => 14.0,
    };
}

pub fn headerGap(density: Density) f32 {
    return switch (density) {
        .compact => 8.0,
        .normal => 12.0,
        .expanded => 16.0,
    };
}

pub fn detail(item: Item) []const u8 {
    if (item.detail.len != 0) return item.detail;
    return kindLabel(item.kind);
}

pub fn value(item: Item) []const u8 {
    if (item.value.len != 0) return item.value;
    return stateLabel(item.state);
}

pub fn rowDetail(item: Item) []const u8 {
    if (item.value.len != 0 and item.detail.len != 0) return item.detail;
    if (item.value.len != 0) return item.value;
    if (item.detail.len != 0) return item.detail;
    return stateLabel(item.state);
}

pub fn kindLabel(kind: Kind) []const u8 {
    return switch (kind) {
        .identity => "identity",
        .metric => "metric",
        .resource => "resource",
        .path => "path",
        .event => "event",
        .action => "action",
        .artifact => "artifact",
        .warning => "warning",
        .dependency => "dependency",
        .timeline => "timeline",
    };
}

pub fn stateLabel(state: State) []const u8 {
    return switch (state) {
        .neutral => "neutral",
        .active => "active",
        .good => "good",
        .warning => "warning",
        .bad => "bad",
        .blocked => "blocked",
        .private => "private",
        .pending => "pending",
    };
}

pub fn icon(kind: Kind) ui_icon.Icon {
    return switch (kind) {
        .identity => .user,
        .metric => .chart_bar,
        .resource => .database,
        .path => .folder,
        .event => .activity,
        .action => .send,
        .artifact => .archive,
        .warning => .alert_triangle,
        .dependency => .git_branch,
        .timeline => .clock,
    };
}

pub fn badgeVariant(state: State) common.BadgeVariant {
    return switch (state) {
        .good, .active => .secondary,
        .warning, .bad, .blocked => .default,
        .private, .pending, .neutral => .outline,
    };
}

pub fn badgeBounds(bounds: ui.Rect, label: []const u8) ui.Rect {
    const desired = @as(f32, @floatFromInt(label.len)) * 7.4 + 28.0;
    const width = @min(@max(54.0, desired), @max(54.0, bounds.w - 20.0));
    return ui.Rect.init(bounds.x + bounds.w - width - 12.0, bounds.y + 12.0, width, 22.0);
}
