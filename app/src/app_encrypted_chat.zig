const std = @import("std");

const clock = @import("clock.zig");
const encrypted_chat = @import("encrypted_chat.zig");
const identity = @import("identity.zig");
const interaction = @import("ui/interaction.zig");
const preimage = @import("preimage.zig");
const ui = @import("ui/core.zig");
const Component = @import("ui/components/Component.zig").Component;
const IconComponent = @import("ui/components/Icon.zig");
const icon = @import("ui/icon.zig");

const max_contacts = 16;
const max_messages = 64;

pub const import_button_id: u32 = 81_001;
pub const seal_button_id: u32 = 81_002;
pub const send_button_id: u32 = 81_003;
pub const compose_textarea_id: u32 = 81_004;
pub const import_textarea_id: u32 = 81_005;
pub const contact_row_base_id: u32 = 82_000;

const Chat = encrypted_chat.ChatState(max_contacts, max_messages);

pub const State = struct {
    chat: Chat,
    selected_index: usize = 0,
    compose: []const u8 = "Route update sealed for you.",
    import_preview: []const u8 = "route-to-me-for-new-contact|New Contact|contact.onion|contact-key",
    sealed: bool = false,
    status: []const u8 = "Local inbox open",
    count_buf: [48]u8 = undefined,
    route_buf: [160]u8 = undefined,
    remote_buf: [192]u8 = undefined,
    message_count_buf: [48]u8 = undefined,

    pub fn initDemo() !State {
        const epoch = demoEpoch();
        const device = testIdentity(.device, "chat ui device", epoch);
        const app = testIdentity(.app, "encrypted chat ui app", epoch);
        const user = testIdentity(.user, "chat ui user", epoch);
        var chat = try Chat.init(device, app, user, epoch);
        const alice = try chat.importContact(.{
            .contact_route = "route-to-me-for-alice-1",
            .name = "Alice",
            .route = "alice-hidden-service.onion",
            .public_key = "alice-ed25519-chat-key",
        }, epoch);
        const bob = try chat.importContact(.{
            .contact_route = "route-to-me-for-bob-1",
            .name = "Bob",
            .route = "bob-hidden-service.onion",
            .public_key = "bob-ed25519-chat-key",
        }, epoch);
        _ = try chat.appendMessage(alice, .inbound, "I imported the route you gave me.");
        _ = try chat.appendMessage(alice, .outbound, "Good. This contact id stays bound to that route.");
        _ = try chat.appendMessage(bob, .inbound, "New contact details can rotate without changing the route id.");
        return .{ .chat = chat };
    }

    pub fn render(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, options: @import("ui/component_common.zig").RenderOptions) !void {
        var render_options = options;
        render_options.style = chatStyle();
        try scene.pushGradientRect(bounds, chat_bg_top, chat_bg_bottom, 0.0);
        const outer = bounds.insetUniform(if (bounds.w >= 900.0) 20.0 else 12.0);
        if (outer.w >= 780.0) {
            try self.renderWide(scene, collector, outer, render_options);
        } else {
            try self.renderStacked(scene, collector, outer, render_options);
        }
    }

    fn renderWide(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, options: @import("ui/component_common.zig").RenderOptions) !void {
        const sidebar_w = @min(330.0, @max(270.0, bounds.w * 0.30));
        const gap: f32 = 14.0;
        try self.renderContacts(scene, collector, ui.Rect.init(bounds.x, bounds.y, sidebar_w, bounds.h), options);
        try self.renderConversation(scene, collector, ui.Rect.init(bounds.x + sidebar_w + gap, bounds.y, bounds.w - sidebar_w - gap, bounds.h), options);
    }

    fn renderStacked(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, options: @import("ui/component_common.zig").RenderOptions) !void {
        const contacts_h = @min(250.0, @max(190.0, bounds.h * 0.34));
        try self.renderContacts(scene, collector, ui.Rect.init(bounds.x, bounds.y, bounds.w, contacts_h), options);
        try self.renderConversation(scene, collector, ui.Rect.init(bounds.x, bounds.y + contacts_h + 12.0, bounds.w, @max(1.0, bounds.h - contacts_h - 12.0)), options);
    }

    fn renderContacts(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, options: @import("ui/component_common.zig").RenderOptions) !void {
        try (Component{ .card = .{ .title = "", .detail = "", .variant = .elevated } }).renderInteractive(scene, collector, bounds, options);
        const inner = bounds.insetUniform(16.0);
        try renderSectionTitle(scene, inner.x, inner.y, "Encrypted Chat", "Inbox and contact book", .address_book, options);

        const count_text = std.fmt.bufPrint(&self.count_buf, "{d} contacts / {d} messages", .{ self.chat.contact_count, self.chat.message_count }) catch "contacts";
        try (Component{ .badge = .{ .label = count_text, .variant = .secondary } }).renderInteractive(scene, collector, ui.Rect.init(inner.x, inner.y + 50.0, @min(inner.w, 180.0), 28.0), options);

        const button_w = (inner.w - 10.0) * 0.5;
        try (Component{ .button = .{ .id = import_button_id, .label = "Import", .variant = .outline, .icon_slot = IconComponent.IconSlot.named(.leading, .download) } }).renderInteractive(scene, collector, ui.Rect.init(inner.x, inner.y + 90.0, button_w, 34.0), options);
        try (Component{ .button = .{ .id = seal_button_id, .label = if (self.sealed) "Unseal" else "Seal", .variant = .primary, .icon_slot = IconComponent.IconSlot.named(.leading, if (self.sealed) .lock_open else .lock) } }).renderInteractive(scene, collector, ui.Rect.init(inner.x + button_w + 10.0, inner.y + 90.0, button_w, 34.0), options);

        var y = inner.y + 142.0;
        if (self.chat.contact_count == 0) {
            try scene.pushText(ui.Rect.init(inner.x, y, inner.w, 18.0), "Import contacts to start", options.style.muted);
            return;
        }
        var index: usize = 0;
        while (index < self.chat.contact_count and y + 56.0 <= inner.y + inner.h) : (index += 1) {
            const contact = &self.chat.contacts[index];
            const row = ui.Rect.init(inner.x, y, inner.w, 52.0);
            if (index == self.selected_index) {
                try scene.pushRect(row.insetUniform(-2.0), selected_fill, .fill, 8.0, 0.0);
                try scene.pushRect(row.insetUniform(-2.0), options.style.accent, .border, 8.0, 0.0);
            }
            const detail = std.fmt.bufPrint(&self.route_buf, "route: {s}", .{contact.contactRouteBytes()}) catch contact.contactRouteBytes();
            try (Component{ .row_item = .{
                .id = contact_row_base_id + @as(u32, @intCast(index)),
                .title = contact.nameBytes(),
                .detail = detail,
                .leading_icon = IconComponent.IconSlot.named(.leading, .message_2),
            } }).renderInteractive(scene, collector, row, options);
            y += 60.0;
        }
    }

    fn renderConversation(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, options: @import("ui/component_common.zig").RenderOptions) !void {
        try (Component{ .card = .{ .title = "", .detail = "", .variant = .elevated } }).renderInteractive(scene, collector, bounds, options);
        const inner = bounds.insetUniform(18.0);
        const selected = self.selectedContact() orelse {
            try renderSectionTitle(scene, inner.x, inner.y, "No Contact", "Import a route to begin", .inbox, options);
            return;
        };

        try renderSectionTitle(scene, inner.x, inner.y, selected.nameBytes(), self.status, .message, options);
        const remote = std.fmt.bufPrint(&self.remote_buf, "remote: {s}", .{selected.routeBytes()}) catch selected.routeBytes();
        try scene.pushText(ui.Rect.init(inner.x + 42.0, inner.y + 46.0, inner.w - 42.0, 16.0), remote, options.style.muted);
        const mine = std.fmt.bufPrint(&self.route_buf, "given route: {s}", .{selected.contactRouteBytes()}) catch selected.contactRouteBytes();
        try scene.pushText(ui.Rect.init(inner.x + 42.0, inner.y + 66.0, inner.w - 42.0, 16.0), mine, options.style.accent);

        const import_y = inner.y + 98.0;
        if (inner.h >= 520.0) {
            try (Component{ .textarea = .{ .id = import_textarea_id, .placeholder = "contact_route|name|remote_route|public_key", .value = self.import_preview } }).renderInteractive(scene, collector, ui.Rect.init(inner.x, import_y, inner.w, 66.0), options);
        }

        const compose_h: f32 = 96.0;
        const compose_y = inner.y + inner.h - compose_h;
        const list_y = if (inner.h >= 520.0) import_y + 82.0 else inner.y + 100.0;
        const list_h = @max(1.0, compose_y - list_y - 12.0);
        try self.renderMessages(scene, ui.Rect.init(inner.x, list_y, inner.w, list_h), selected.id, options);

        try (Component{ .textarea = .{ .id = compose_textarea_id, .placeholder = "Message", .value = self.compose } }).renderInteractive(scene, collector, ui.Rect.init(inner.x, compose_y, @max(1.0, inner.w - 116.0), 76.0), options);
        try (Component{ .button = .{ .id = send_button_id, .label = "Send", .variant = .primary, .icon_slot = IconComponent.IconSlot.named(.leading, .send) } }).renderInteractive(scene, collector, ui.Rect.init(inner.x + inner.w - 104.0, compose_y + 42.0, 104.0, 34.0), options);

        const msg_text = std.fmt.bufPrint(&self.message_count_buf, "{d} visible messages", .{self.visibleMessageCount(selected.id)}) catch "messages";
        try scene.pushText(ui.Rect.init(inner.x + inner.w - 160.0, inner.y + 18.0, 160.0, 16.0), msg_text, options.style.muted);
    }

    fn renderMessages(self: *State, scene: *ui.Scene, bounds: ui.Rect, contact_id: identity.Id, options: @import("ui/component_common.zig").RenderOptions) !void {
        try scene.pushRect(bounds, transcript_fill, .fill, 8.0, 0.0);
        var y = bounds.y + 12.0;
        var index: usize = 0;
        while (index < self.chat.message_count and y + 44.0 <= bounds.y + bounds.h) : (index += 1) {
            const message = &self.chat.messages[index];
            if (!message.contact_id.eql(contact_id)) continue;
            const outbound = message.direction == .outbound;
            const bubble_w = @min(bounds.w * 0.76, @max(180.0, @as(f32, @floatFromInt(message.body_len)) * 7.0 + 28.0));
            const x = if (outbound) bounds.x + bounds.w - bubble_w - 12.0 else bounds.x + 12.0;
            const bubble = ui.Rect.init(x, y, bubble_w, 42.0);
            try scene.pushRect(bubble, if (outbound) outbound_fill else inbound_fill, .fill, 8.0, 0.0);
            try scene.pushRect(bubble, if (outbound) options.style.accent else options.style.border, .border, 8.0, 0.0);
            try scene.pushWrappedText(bubble.insetUniform(10.0), message.bodyBytes(), options.style.text, .{ .line_height = 16.0, .average_char_width = 7.0, .max_lines = 2 });
            y += 50.0;
        }
    }

    fn selectedContact(self: *const State) ?*const encrypted_chat.Contact {
        if (self.chat.contact_count == 0) return null;
        return &self.chat.contacts[@min(self.selected_index, self.chat.contact_count - 1)];
    }

    fn visibleMessageCount(self: *const State, contact_id: identity.Id) usize {
        var count: usize = 0;
        for (self.chat.messages[0..self.chat.message_count]) |message| {
            if (message.contact_id.eql(contact_id)) count += 1;
        }
        return count;
    }
};

fn renderSectionTitle(scene: *ui.Scene, x: f32, y: f32, title: []const u8, detail: []const u8, icon_kind: icon.Icon, options: @import("ui/component_common.zig").RenderOptions) !void {
    const chip = ui.Rect.init(x, y + 2.0, 30.0, 30.0);
    try scene.pushRect(chip, selected_fill, .fill, 8.0, 0.0);
    try IconComponent.Icon.named(icon_kind).renderColor(scene, chip.withHeightCentered(16.0).withWidthCentered(16.0), options.style.accent);
    try scene.pushStrongText(ui.Rect.init(x + 42.0, y, 320.0, 20.0), title, options.style.text);
    try scene.pushText(ui.Rect.init(x + 42.0, y + 25.0, 360.0, 16.0), detail, options.style.muted);
}

fn chatStyle() ui.Style {
    return .{
        .bg = chat_bg_bottom,
        .panel = ui.Color{ .r = 18, .g = 24, .b = 29 },
        .row = ui.Color{ .r = 27, .g = 35, .b = 41 },
        .border = ui.Color{ .r = 67, .g = 82, .b = 91 },
        .text = ui.Color{ .r = 236, .g = 241, .b = 244 },
        .muted = ui.Color{ .r = 143, .g = 158, .b = 166 },
        .accent = ui.Color{ .r = 67, .g = 214, .b = 160 },
    };
}

fn demoEpoch() clock.Stamp {
    return .{ .keeper = .{ .bytes = [_]u8{7} ++ [_]u8{0} ** 31 }, .tick = 1 };
}

fn testIdentity(kind: identity.Kind, label: []const u8, epoch: clock.Stamp) identity.Identity {
    return identity.Identity.init(kind, identity.Source.prepare(.hash, &preimage.rawHash(label)).?, epoch).?;
}

const chat_bg_top = ui.Color{ .r = 8, .g = 13, .b = 16 };
const chat_bg_bottom = ui.Color{ .r = 13, .g = 18, .b = 22 };
const selected_fill = ui.Color{ .r = 22, .g = 60, .b = 48, .a = 180 };
const transcript_fill = ui.Color{ .r = 6, .g = 9, .b = 11, .a = 128 };
const inbound_fill = ui.Color{ .r = 28, .g = 35, .b = 41 };
const outbound_fill = ui.Color{ .r = 21, .g = 53, .b = 43 };

test "encrypted chat app renders contacts conversation and actions" {
    var state = try State.initDemo();
    var commands: [256]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [64]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);
    const component_test = @import("ui/components/TestSupport.zig");

    try state.render(&scene, &collector, ui.Rect.init(0, 0, 1000, 700), .{});

    try std.testing.expect(component_test.hasText(scene.written(), "Encrypted Chat"));
    try std.testing.expect(component_test.hasText(scene.written(), "Alice"));
    try std.testing.expect(component_test.textCommandPrefix(scene.written(), "given route: route-to-me-for-alice") != null);
    try std.testing.expect(component_test.hasText(scene.written(), "Good. This contact id stays bound to that route."));
    try std.testing.expect(hasRegion(collector.written(), .button, import_button_id));
    try std.testing.expect(hasRegion(collector.written(), .button, seal_button_id));
    try std.testing.expect(hasRegion(collector.written(), .button, send_button_id));
    try std.testing.expect(hasRegion(collector.written(), .textarea, compose_textarea_id));
    try std.testing.expect(hasRegion(collector.written(), .row_item, contact_row_base_id));
}

test "encrypted chat app renders stacked layout" {
    var state = try State.initDemo();
    var commands: [256]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [64]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);
    const component_test = @import("ui/components/TestSupport.zig");

    try state.render(&scene, &collector, ui.Rect.init(0, 0, 420, 760), .{});

    try std.testing.expect(component_test.hasText(scene.written(), "Encrypted Chat"));
    try std.testing.expect(component_test.hasText(scene.written(), "Send"));
    try std.testing.expect(hasRegion(collector.written(), .textarea, compose_textarea_id));
}

fn hasRegion(regions: []const interaction.Region, kind: ui.HitKind, id: u32) bool {
    for (regions) |region| {
        if (region.kind == kind and region.id == id) return true;
    }
    return false;
}
