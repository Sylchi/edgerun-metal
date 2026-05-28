const ui = @import("ui.zig");

pub const Node = union(enum) {
    rect: struct {
        color: ui.Color,
    },
    text: struct {
        value: []const u8,
        color: ?ui.Color = null,
    },
    slot: struct {
        id: u32,
        child: *const Node,
    },
    stack: ui.Layout,

    accordion: struct { id: u32, title: []const u8, detail: []const u8, open: bool = false },
    alert: struct { title: []const u8, detail: []const u8, destructive: bool = false, icon: u16 = 0 },
    alert_dialog: struct { id: u32, title: []const u8, detail: []const u8 },
    aspect_ratio: struct { ratio_w: u16, ratio_h: u16 },
    calendar: struct { id: u32, month: []const u8, selected_day: u16 = 0 },
    carousel: struct { id: u32, label: []const u8 },
    chart: struct { id: u32, label: []const u8 },
    combobox: struct { id: u32, placeholder: []const u8, selected: []const u8 = "" },
    empty: struct { title: []const u8, detail: []const u8, icon: u16 = 0 },

    button: struct { id: u32, label: []const u8, variant: u16 = 0, leading_icon: u16 = 0, trailing_icon: u16 = 0 },
    icon_button: struct { id: u32, label: []const u8, variant: u16 = 0, icon: u16 = 0 },
    button_group: struct { id: u32, first: []const u8, second: []const u8, active: u16 = 0 },
    toggle_group: struct { id: u32, first: []const u8, second: []const u8, active: u16 = 0 },

    input: struct { id: u32, placeholder: []const u8, leading_icon: u16 = 0 },
    input_group: struct { id: u32, addon: []const u8, placeholder: []const u8 },
    input_otp: struct { id: u32, value: []const u8 },
    textarea: struct { id: u32, placeholder: []const u8 },
    select: struct { id: u32, label: []const u8, trailing_icon: u16 = 0 },
    field: struct { id: u32, label: []const u8, placeholder: []const u8 },
    checkbox: struct { id: u32, label: []const u8, checked: bool = false },
    switch_control: struct { id: u32, label: []const u8, checked: bool = false },
    slider: struct { id: u32, label: []const u8, value: f32 = 0.0 },
    radio_group: struct { id: u32, first: []const u8, second: []const u8, selected: u16 = 0 },

    row_item: struct { id: u32, title: []const u8, detail: []const u8 },
    badge: struct { label: []const u8, variant: u16 = 0 },
    card: struct { title: []const u8, detail: []const u8, variant: u16 = 0 },
    avatar: struct { label: []const u8 },
    kbd: struct { label: []const u8 },
    label: struct { value: []const u8 },
    table: struct { id: u32, name: []const u8, role: []const u8 },

    separator: void,
    scroll_area: void,
    skeleton: void,
    spinner: void,
    progress: struct { value: f32 = 0.0 },

    breadcrumb: struct { id: u32, first: []const u8, current: []const u8 },
    menubar: struct { id: u32, first: []const u8, second: []const u8, active: u16 = 0 },
    navigation_menu: struct { id: u32, first: []const u8, second: []const u8, active: u16 = 0 },
    pagination: struct { id: u32, page: u16 = 0 },
    tabs: struct { id: u32, first: []const u8, second: []const u8, active: u16 = 0 },
    direction: struct { id: u32, active: u16 = 0 },

    command: struct { id: u32, placeholder: []const u8, leading_icon: u16 = 0 },
    context_menu: struct { id: u32, first: []const u8, second: []const u8 },
    dialog: struct { id: u32, title: []const u8, detail: []const u8 },
    drawer: struct { id: u32, title: []const u8, detail: []const u8 },
    dropdown_menu: struct { id: u32, first: []const u8, second: []const u8 },
    hover_card: struct { id: u32, trigger: []const u8, content: []const u8 },
    popover: struct { id: u32, trigger: []const u8, content: []const u8 },
    tooltip: struct { id: u32, trigger: []const u8, content: []const u8 },
    toast: struct { id: u32, title: []const u8, detail: []const u8 },
    sheet: struct { id: u32, title: []const u8, detail: []const u8 },
    sidebar: struct { id: u32, title: []const u8, item: []const u8 },

    icon: struct { label: []const u8, icon: u16 = 0 },
    toggle: struct { id: u32, label: []const u8, pressed: bool = false },
    resizable: struct { id: u32, ratio: f32 = 0.5 },
};
