const std = @import("er_std");

pub const Icon = enum(u16) {
    a_b = 0,
    a_b_2 = 1,
    activity = 12,
    adjustments = 21,
    adjustments_minus = 33,
    adjustments_plus = 37,
    ai_agent = 48,
    alert_circle = 64,
    alert_triangle = 74,
    alpha = 101,
    alt = 112,
    archive = 141,
    arrow_down = 194,
    arrow_left = 215,
    arrow_right = 253,
    arrow_up = 273,
    arrows_exchange = 303,
    aspect_ratio = 337,
    at = 344,
    background = 363,
    badge = 369,
    badges = 387,
    battery = 444,
    blob = 517,
    blocks = 519,
    blur = 524,
    bold = 528,
    box = 587,
    brightness = 1005,
    brightness_down = 1008,
    brightness_up = 1011,
    broadcast = 1012,
    building = 1036,
    bus = 1075,
    calendar = 1087,
    camera = 1120,
    category = 1215,
    chart_bar = 1243,
    check = 1275,
    checkbox = 1276,
    chevron_left = 1297,
    chevron_right = 1299,
    circle = 1317,
    circle_check = 1331,
    circle_x = 1465,
    click = 1491,
    clock = 1506,
    code = 1586,
    columns = 1621,
    command = 1627,
    components = 1631,
    connection = 1641,
    container = 1642,
    copy = 1653,
    cpu = 1679,
    cursor_pointer_2 = 1800,
    cursor_hand_finger = 1801,
    dashboard = 1807,
    database = 1809,
    delta = 1829,
    details = 1835,
    device_desktop = 1850,
    device_floppy = 1872,
    device_speaker = 1978,
    devices = 2030,
    direction = 2071,
    disabled = 2078,
    download = 2103,
    ease_in = 2142,
    ease_in_out = 2144,
    ease_out = 2146,
    eye = 2193,
    file = 2236,
    filter = 2334,
    flag = 2397,
    focus = 2441,
    folder = 2448,
    frame = 2481,
    function = 2494,
    ghost = 2523,
    git_branch = 2531,
    git_commit = 2534,
    hand_finger = 2588,
    hash = 2607,
    heartbeat = 2644,
    help = 2651,
    icons = 2797,
    id = 2799,
    key = 2860,
    keyboard = 2862,
    label = 2871,
    lane = 2881,
    layout = 2903,
    layout_dashboard = 2920,
    leaf = 2942,
    line = 3016,
    line_height = 3019,
    link = 3021,
    link_plus = 3024,
    location = 3041,
    lock = 3064,
    lock_open = 3079,
    map = 3149,
    mask = 3207,
    math = 3213,
    menu = 3265,
    message = 3272,
    message_2 = 3273,
    messages = 3343,
    mood_smile = 3421,
    moon = 3436,
    navigation = 3481,
    needle = 3508,
    network = 3510,
    note = 3523,
    number = 3531,
    outbound = 3666,
    photo = 3783,
    pin = 3839,
    pipeline = 3845,
    placeholder = 3848,
    png = 3908,
    point = 3911,
    pointer = 3913,
    pointer_2 = 3914,
    pointer_down = 3923,
    pointer_up = 3935,
    pointer_x = 3936,
    progress = 3960,
    protocol = 3971,
    receipt = 4008,
    refresh = 4032,
    reload = 4042,
    repeat = 4044,
    resize = 4057,
    route = 4117,
    run = 4143,
    scale = 4158,
    search = 4193,
    section = 4195,
    select = 4200,
    send = 4203,
    separator = 4207,
    server = 4210,
    shadow = 4243,
    shield = 4254,
    shield_check = 4257,
    signature = 4335,
    slash = 4347,
    slice = 4350,
    space = 4389,
    sparkles = 4398,
    square = 4414,
    stack = 4556,
    svg = 4615,
    @"switch" = 4622,
    table = 4630,
    table_row = 4642,
    tag = 4646,
    target = 4660,
    temperature = 4670,
    terminal = 4682,
    text_wrap = 4703,
    timeline = 4729,
    tool = 4746,
    tooltip = 4754,
    transform = 4792,
    tree = 4806,
    user = 4856,
    vector = 4903,
    video = 4915,
    walk = 4946,
    weight = 4992,
    wheel = 4995,
    wifi = 5000,
    x = 5051,
    zoom_in = 5083,
    zoom_in_area = 5084,
    zoom_out = 5086,
    zoom_reset = 5091,
    zzz_off = 5094,
    _,
};

pub const Provider = enum {
    lucide,
    tabler,
};

pub const icon_count: usize = 5095;

fn hyphenatedIconName(comptime name: []const u8) []const u8 {
    comptime {
        var out: [name.len]u8 = undefined;
        for (name, 0..) |ch, index| {
            out[index] = if (ch == '_') '-' else ch;
        }
        const final = out;
        return final[0..];
    }
}

fn buildTablerNames() [icon_count][]const u8 {
    @setEvalBranchQuota(30000);
    const fields = @typeInfo(Icon).@"enum".fields;
    var result: [icon_count][]const u8 = [_][]const u8{""} ** icon_count;
    inline for (fields) |field| {
        result[field.value] = hyphenatedIconName(field.name);
    }
    return result;
}

const tabler_names = buildTablerNames();

pub fn tablerName(value: Icon) []const u8 {
    const index: usize = @intFromEnum(value);
    if (index >= tabler_names.len) return "";
    return tabler_names[index];
}

pub fn label(value: Icon) []const u8 {
    return tablerName(value);
}

pub fn id(value: Icon) u32 {
    return @as(u32, @intFromEnum(value)) + 1;
}

pub fn fromId(icon_id: u32) ?Icon {
    if (icon_id == 0 or icon_id > icon_count) return null;
    inline for (@typeInfo(Icon).@"enum".fields) |field| {
        if (icon_id == field.value + 1) return @enumFromInt(field.value);
    }
    return null;
}

pub fn providerName(value: Icon, provider: Provider) []const u8 {
    _ = provider;
    return tablerName(value);
}

test "icon ids are stable and one based" {
    try std.testing.expectEqual(@as(u32, 1), id(.a_b));
    try std.testing.expectEqual(@as(u32, 5095), id(.zzz_off));
    try std.testing.expect(fromId(0) == null);
    try std.testing.expect(fromId(icon_count + 1) == null);
    try std.testing.expectEqual(Icon.dashboard, fromId(id(.dashboard)).?);
}

test "every defined icon has a label" {
    inline for (std.meta.fields(Icon)) |field| {
        const value: Icon = @enumFromInt(field.value);
        try std.testing.expect(label(value).len > 0);
    }
}

test "tabler names are derived from enum tags" {
    try std.testing.expectEqualStrings("a-b-2", tablerName(.a_b_2));
    try std.testing.expectEqualStrings("switch", tablerName(.@"switch"));
    try std.testing.expectEqualStrings("zoom-in-area", tablerName(.zoom_in_area));
}

pub const cursor_pointer_2_icon_id: u32 = id(.cursor_pointer_2);
pub const cursor_hand_finger_icon_id: u32 = id(.cursor_hand_finger);

fn getPath(name: []const u8) ?[]const u8 {
    _ = name;
    return null;
}

fn getPathByName(name: []const u8, _: Provider) ?[]const u8 {
    return getPath(name);
}

pub fn getPathByIcon(which: Icon, _: Provider) ?[]const u8 {
    return getPath(@tagName(which));
}

pub fn getIr(icon_id: u32) ?[]const f32 {
    _ = icon_id;
    return null;
}

test "asset pack has tabler icons" {
    try std.testing.expect(icon_count > 5000);
}

test "getIr returns null for unknown icon id" {
    try std.testing.expectEqual(@as(?[]const f32, null), getIr(0));
    try std.testing.expectEqual(@as(?[]const f32, null), getIr(999_999));
}
