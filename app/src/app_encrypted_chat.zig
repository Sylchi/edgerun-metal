const std = @import("std");

const clock = @import("clock.zig");
const encrypted_chat = @import("encrypted_chat.zig");
const identity = @import("identity.zig");
const interaction = @import("ui/interaction.zig");
const preimage = @import("preimage.zig");
const ui = @import("ui/core.zig");
const design = @import("ui/theme.zig");
const component = @import("ui/components/Component.zig");

const RenderOptions = @import("ui/component_common.zig").RenderOptions;

const max_contacts = 16;
const max_messages = 64;

pub const import_button_id: u32 = 81_001;
pub const seal_button_id: u32 = 81_002;
pub const send_button_id: u32 = 81_003;
pub const compose_textarea_id: u32 = 81_004;
pub const import_textarea_id: u32 = 81_005;
pub const theme_button_id: u32 = 81_006;
pub const create_route_button_id: u32 = 81_007;
pub const image_button_id: u32 = 81_008;
pub const video_button_id: u32 = 81_009;
pub const emoji_button_id: u32 = 81_010;
pub const contact_row_base_id: u32 = 82_000;

const Chat = encrypted_chat.ChatState(max_contacts, max_messages);

pub const ThemeMode = enum { dark, light };

const workspace_rail_w: f32 = 48.0;
const workspace_sidebar_w: f32 = 260.0;
const workspace_top_h: f32 = 56.0;
const workspace_status_h: f32 = 24.0;
const workspace_rail_bg = ui.Color{ .r = 37, .g = 37, .b = 38 };
const workspace_sidebar_bg = ui.Color{ .r = 24, .g = 24, .b = 24 };
const workspace_main_bg = ui.Color{ .r = 10, .g = 12, .b = 16 };
const workspace_status_bg = ui.Color{ .r = 0, .g = 122, .b = 204 };

pub const State = struct {
    chat: Chat,
    selected_index: usize = 0,
    theme_mode: ThemeMode = .dark,
    compose: []const u8 = "Message...",
    import_preview: []const u8 = "local-route|Contact|remote-route|public-key",
    sealed: bool = false,
    status: []const u8 = "Active now",
    own_route_buf: [256]u8 = undefined,
    own_route_len: usize = 0,
    route_buf: [160]u8 = undefined,
    remote_buf: [192]u8 = undefined,
    message_count_buf: [48]u8 = undefined,

    pub fn initDemo() !State {
        const epoch = demoEpoch();
        const device = testIdentity(.device, "device", epoch);
        const app = testIdentity(.app, "app", epoch);
        const user = testIdentity(.user, "user", epoch);
        var chat = try Chat.init(device, app, user, epoch);
        const contact_1 = try chat.importContact(.{
            .contact_route = "local-route-1",
            .name = "Jordan",
            .route = "remote-route-1",
            .public_key = "public-key-1",
        }, epoch);
        const contact_2 = try chat.importContact(.{
            .contact_route = "local-route-2",
            .name = "Casey",
            .route = "remote-route-2",
            .public_key = "public-key-2",
        }, epoch);
        _ = try chat.appendMessage(contact_1, .inbound, "Hey, are you there? :)");
        _ = try chat.appendMessage(contact_1, .outbound, "Yes, I can read you.");
        _ = try chat.appendMediaMessage(contact_1, .inbound, "Image received", .image, "object://image/8f21", "image/erimg", 16384);
        _ = try chat.appendMediaMessage(contact_1, .outbound, "Video clip ready", .video, "object://video/34aa", "video/ivf", 98304);
        _ = try chat.appendMessage(contact_2, .inbound, "Send me the route when ready.");
        var state = State{ .chat = chat };
        state.writeOwnRoute();
        state.status = "Onion route ready";
        return state;
    }

    pub fn activate(self: *State, hit: ?interaction.Region) void {
        const region = hit orelse return;
        if (region.kind == .row_item and region.id >= contact_row_base_id) {
            const index: usize = @intCast(region.id - contact_row_base_id);
            if (index < self.chat.contact_count) {
                self.selected_index = index;
                self.status = "Active now";
            }
            return;
        }
        if (region.kind != .button) return;
        switch (region.id) {
            import_button_id => self.importPreviewContact(),
            seal_button_id => {
                self.sealed = !self.sealed;
                self.status = if (self.sealed) "Sealed" else "Active now";
            },
            theme_button_id => {
                self.theme_mode = if (self.theme_mode == .dark) .light else .dark;
            },
            create_route_button_id => self.createOnionRoute(),
            image_button_id => self.attachDemoMedia(.image),
            video_button_id => self.attachDemoMedia(.video),
            emoji_button_id => {
                self.compose = "Message... :)";
                self.status = "Emoji inserted";
            },
            send_button_id => self.sendDraft(),
            else => {},
        }
    }

    pub fn render(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, options: RenderOptions) !void {
        const render_options = options.withStyle(self.currentStyle());
        if (bounds.w >= 780.0) {
            try self.renderWorkspace(scene, collector, bounds, render_options);
        } else {
            try self.renderStacked(scene, collector, bounds, render_options);
        }
    }

    fn renderWorkspace(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, options: RenderOptions) !void {
        const app = component.renderer(scene, collector, options);
        try app.fill(bounds, design.Palette.bg, 0.0);
        const rail = ui.Rect.init(bounds.x, bounds.y, workspace_rail_w, @max(1.0, bounds.h - workspace_status_h));
        const top = ui.Rect.init(rail.x + rail.w, bounds.y, @max(1.0, bounds.w - rail.w), workspace_top_h);
        const sidebar = ui.Rect.init(rail.x + rail.w, bounds.y + workspace_top_h, workspace_sidebar_w, @max(1.0, bounds.h - workspace_top_h - workspace_status_h));
        const main = ui.Rect.init(sidebar.x + sidebar.w, bounds.y + workspace_top_h, @max(1.0, bounds.w - rail.w - sidebar.w), @max(1.0, bounds.h - workspace_top_h - workspace_status_h));
        const status = ui.Rect.init(bounds.x, bounds.y + bounds.h - workspace_status_h, bounds.w, workspace_status_h);
        try renderRail(self, scene, collector, rail, options);
        try renderTop(self, scene, top, options);
        try self.renderContacts(scene, collector, sidebar, options);
        try self.renderConversation(scene, collector, main, options);
        try renderStatus(self, scene, status);
    }

    fn renderStacked(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, options: RenderOptions) !void {
        const contacts_h = @min(250.0, @max(190.0, bounds.h * 0.34));
        try self.renderContacts(scene, collector, ui.Rect.init(bounds.x, bounds.y, bounds.w, contacts_h), options);
        try self.renderConversation(scene, collector, ui.Rect.init(bounds.x, bounds.y + contacts_h, bounds.w, @max(1.0, bounds.h - contacts_h)), options);
    }

    fn renderContacts(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, options: RenderOptions) !void {
        const inner = bounds.insetUniform(16.0);
        const app = component.renderer(scene, collector, options);
        try app.fill(bounds, workspace_sidebar_bg, 0.0);
        try app.fill(ui.Rect.init(bounds.x + bounds.w - 1.0, bounds.y, 1.0, bounds.h), design.Palette.border, 0.0);
        try app.title(ui.Rect.init(inner.x, inner.y + 2.0, inner.w, 16.0), "EDGERUN");
        try app.muted(ui.Rect.init(inner.x, inner.y + 24.0, inner.w, 14.0), "chat");

        const icon_y = inner.y + 54.0;
        try app.renderIconButtonNamed(ui.Rect.init(inner.x, icon_y, 34.0, 34.0), create_route_button_id, "Create route", .link_plus, .outline);
        try app.renderIconButtonNamed(ui.Rect.init(inner.x + 42.0, icon_y, 34.0, 34.0), import_button_id, "Import", .download, .outline);
        try app.renderIconButtonNamed(ui.Rect.init(inner.x + 84.0, icon_y, 34.0, 34.0), seal_button_id, if (self.sealed) "Unseal" else "Seal", if (self.sealed) .lock_open else .lock, .outline);
        try app.renderIconButtonNamed(ui.Rect.init(inner.x + 126.0, icon_y, 34.0, 34.0), theme_button_id, "Theme", .moon, .outline);

        if (self.own_route_len != 0) {
            try app.interactive(component.subtle("my onion route", self.ownRouteBytes()), ui.Rect.init(inner.x, inner.y + 92.0, inner.w, 44.0));
        }

        var y = inner.y + 150.0;
        if (self.chat.contact_count == 0) {
            try app.draw(component.empty("No contacts", "Import a route to begin."), ui.Rect.init(inner.x, y, inner.w, @min(150.0, @max(96.0, inner.y + inner.h - y))));
            return;
        }
        var index: usize = 0;
        while (index < self.chat.contact_count and y + 64.0 <= inner.y + inner.h) : (index += 1) {
            const contact = &self.chat.contacts[index];
            const row = ui.Rect.init(inner.x, y, inner.w, 64.0);
            const detail = std.fmt.bufPrint(&self.route_buf, "{s}", .{contact.contactRouteBytes()}) catch contact.contactRouteBytes();
            try app.selectableRow(row, contact_row_base_id + @as(u32, @intCast(index)), contact.nameBytes(), detail, .message_2, index == self.selected_index);
            y += 68.0;
        }
    }

    fn renderConversation(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, options: RenderOptions) !void {
        const app = component.renderer(scene, null, options);
        try app.fill(bounds, workspace_main_bg, 0.0);
        const selected = self.selectedContact() orelse {
            try app.draw(component.empty("No contact", "Import a route to begin."), bounds.insetUniform(18.0));
            return;
        };
        const active_app = component.renderer(scene, collector, options);

        const import_y = bounds.y + 18.0;
        if (bounds.h >= 620.0) {
            try active_app.renderTextareaValue(ui.Rect.init(bounds.x + 18.0, import_y, bounds.w - 36.0, 40.0), import_textarea_id, "", self.import_preview);
        }

        const compose_h: f32 = 74.0;
        const compose_y = bounds.y + bounds.h - compose_h;
        const list_y = if (bounds.h >= 620.0) import_y + 58.0 else bounds.y + 18.0;
        try self.renderMessages(scene, ui.Rect.init(bounds.x, list_y, bounds.w, @max(1.0, compose_y - list_y)), selected.id, options);

        try app.line(ui.Rect.init(bounds.x, compose_y, bounds.w, 1.0));
        const tool_y = compose_y + 18.0;
        try active_app.renderIconButtonNamed(ui.Rect.init(bounds.x + 18.0, tool_y, 34.0, 38.0), image_button_id, "Image", .photo, .outline);
        try active_app.renderIconButtonNamed(ui.Rect.init(bounds.x + 58.0, tool_y, 34.0, 38.0), video_button_id, "Video", .video, .outline);
        try active_app.renderIconButtonNamed(ui.Rect.init(bounds.x + 98.0, tool_y, 34.0, 38.0), emoji_button_id, "Emoji", .mood_smile, .outline);
        try active_app.renderTextareaValue(ui.Rect.init(bounds.x + 144.0, compose_y + 15.0, @max(1.0, bounds.w - 230.0), 44.0), compose_textarea_id, "", self.compose);
        try active_app.renderIconButtonNamed(ui.Rect.init(bounds.x + bounds.w - 68.0, compose_y + 18.0, 44.0, 38.0), send_button_id, "Send", .send, .outline);

        const msg_text = std.fmt.bufPrint(&self.message_count_buf, "{d} messages", .{self.visibleMessageCount(selected.id)}) catch "messages";
        try app.muted(ui.Rect.init(bounds.x + 18.0, bounds.y + bounds.h - 18.0, 160.0, 14.0), msg_text);
    }

    fn renderMessages(self: *State, scene: *ui.Scene, bounds: ui.Rect, contact_id: identity.Id, options: RenderOptions) !void {
        const app = component.renderer(scene, null, options);
        try app.fill(bounds, workspace_main_bg, 0.0);
        var y = bounds.y + 12.0;
        var index: usize = 0;
        while (index < self.chat.message_count and y + 44.0 <= bounds.y + bounds.h) : (index += 1) {
            const message = &self.chat.messages[index];
            if (!message.contact_id.eql(contact_id)) continue;
            const outbound = message.direction == .outbound;
            const media_h: f32 = if (message.media_kind == .none) 0.0 else 78.0;
            const bubble_h: f32 = 42.0 + media_h;
            const min_bubble_w: f32 = if (message.media_kind == .none) 86.0 else 220.0;
            const bubble_w = @min(bounds.w * 0.68, @max(min_bubble_w, @as(f32, @floatFromInt(message.body_len)) * 7.2 + 30.0));
            const x = if (outbound) bounds.x + bounds.w - bubble_w - 24.0 else bounds.x + 24.0;
            const bubble = ui.Rect.init(x, y, bubble_w, bubble_h);
            const media_label = switch (message.media_kind) {
                .image => "image",
                .video => "video",
                .none => "",
            };
            const media_icon: ?@import("ui/icon.zig").Icon = switch (message.media_kind) {
                .image => .photo,
                .video => .video,
                .none => null,
            };
            try app.messageBubble(bubble, .{
                .body = message.bodyBytes(),
                .outbound = outbound,
                .media_label = media_label,
                .media_detail = if (message.media_kind == .none) "" else message.mediaRefBytes(),
                .media_icon = media_icon,
            });
            y += bubble_h + 8.0;
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

    fn sendDraft(self: *State) void {
        const contact = self.selectedContact() orelse return;
        _ = self.chat.appendMessage(contact.id, .outbound, self.compose) catch {
            self.status = "Send failed";
            return;
        };
        self.status = "Sent";
    }

    fn attachDemoMedia(self: *State, kind: encrypted_chat.MediaKind) void {
        const contact = self.selectedContact() orelse return;
        const ref = switch (kind) {
            .image => "object://image/new",
            .video => "object://video/new",
            .none => return,
        };
        const mime = switch (kind) {
            .image => "image/erimg",
            .video => "video/ivf",
            .none => return,
        };
        const label = switch (kind) {
            .image => "Image attached",
            .video => "Video attached",
            .none => return,
        };
        _ = self.chat.appendMediaMessage(contact.id, .outbound, label, kind, ref, mime, 32768) catch {
            self.status = "Attach failed";
            return;
        };
        self.status = label;
    }

    fn importPreviewContact(self: *State) void {
        const old_count = self.chat.contact_count;
        const imported = self.chat.importContactsText(self.import_preview, self.chat.epoch) catch {
            self.status = "Import failed";
            return;
        };
        if (imported == 0) {
            self.status = "Import failed";
            return;
        }
        if (self.chat.contact_count > old_count) self.selected_index = self.chat.contact_count - 1;
        self.status = "Imported";
    }

    fn createOnionRoute(self: *State) void {
        self.writeOwnRoute();
        if (self.own_route_len != 0) self.import_preview = self.ownRouteBytes();
    }

    fn writeOwnRoute(self: *State) void {
        const value = encrypted_chat.ContactImport{
            .contact_route = "route-to-me-edgerun-chat",
            .name = "Me",
            .route = "edgerun-chat-demo-hidden-service.onion",
            .public_key = "edgerun-chat-demo-public-key",
        };
        const route = encrypted_chat.writeContactLink(&self.own_route_buf, value) catch {
            self.own_route_len = 0;
            self.status = "Route failed";
            return;
        };
        self.own_route_len = route.len;
        self.status = "Onion route ready";
    }

    fn ownRouteBytes(self: *const State) []const u8 {
        return self.own_route_buf[0..self.own_route_len];
    }

    fn currentStyle(self: *const State) ui.Style {
        return if (self.theme_mode == .dark) design.appStyle() else messengerLightStyle();
    }
};

fn renderRail(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, options: RenderOptions) !void {
    const app = component.renderer(scene, collector, options);
    try app.fill(bounds, workspace_rail_bg, 0.0);
    const route_rect = ui.Rect.init(bounds.x + 6.0, bounds.y + 12.0, bounds.w - 12.0, 36.0);
    const import_rect = ui.Rect.init(bounds.x + 6.0, bounds.y + 56.0, bounds.w - 12.0, 36.0);
    const seal_rect = ui.Rect.init(bounds.x + 6.0, bounds.y + 100.0, bounds.w - 12.0, 36.0);
    const theme_rect = ui.Rect.init(bounds.x + 6.0, bounds.y + 144.0, bounds.w - 12.0, 36.0);
    try app.renderIconButtonNamed(route_rect, create_route_button_id, "Create route", .link_plus, .outline);
    try app.renderIconButtonNamed(import_rect, import_button_id, "Import", .download, .outline);
    try app.renderIconButtonNamed(seal_rect, seal_button_id, if (self.sealed) "Unseal" else "Seal", if (self.sealed) .lock_open else .lock, .outline);
    try app.renderIconButtonNamed(theme_rect, theme_button_id, "Theme", .moon, .outline);
}

fn renderTop(self: *State, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) !void {
    const selected = self.selectedContact();
    const app = component.renderer(scene, null, options);
    try app.fill(bounds, workspace_sidebar_bg, 0.0);
    try app.line(ui.Rect.init(bounds.x, bounds.y + bounds.h - 1.0, bounds.w, 1.0));
    const title = if (selected) |contact| contact.nameBytes() else "Chat";
    try app.title(ui.Rect.init(bounds.x + 16.0, bounds.y + 13.0, bounds.w - 260.0, 18.0), title);
    try app.text(ui.Rect.init(bounds.x + 16.0, bounds.y + 34.0, bounds.w - 260.0, 14.0), self.status, design.Palette.dim);
    if (selected) |contact| {
        const remote = std.fmt.bufPrint(&self.remote_buf, "remote {s}", .{contact.routeBytes()}) catch contact.routeBytes();
        const local = std.fmt.bufPrint(&self.route_buf, "local {s}", .{contact.contactRouteBytes()}) catch contact.contactRouteBytes();
        try app.muted(ui.Rect.init(bounds.x + bounds.w - 230.0, bounds.y + 13.0, 210.0, 14.0), remote);
        try app.muted(ui.Rect.init(bounds.x + bounds.w - 230.0, bounds.y + 32.0, 210.0, 14.0), local);
    }
}

fn renderStatus(self: *State, scene: *ui.Scene, bounds: ui.Rect) !void {
    const app = component.renderer(scene, null, .{});
    try app.fill(bounds, workspace_status_bg, 0.0);
    const text = if (self.sealed) "chat: sealed" else "chat: active";
    try app.text(ui.Rect.init(bounds.x + 12.0, bounds.y + 5.0, bounds.w - 24.0, 14.0), text, ui.Color{ .r = 255, .g = 255, .b = 255 });
}

fn messengerDarkStyle() ui.Style {
    return .{
        .bg = ui.Color{ .r = 24, .g = 25, .b = 26 },
        .panel = ui.Color{ .r = 36, .g = 37, .b = 38 },
        .row = ui.Color{ .r = 58, .g = 59, .b = 60 },
        .border = ui.Color{ .r = 64, .g = 65, .b = 66 },
        .text = ui.Color{ .r = 228, .g = 230, .b = 235 },
        .muted = ui.Color{ .r = 176, .g = 179, .b = 184 },
        .accent = messenger_blue,
    };
}

fn messengerLightStyle() ui.Style {
    return .{
        .bg = ui.Color{ .r = 255, .g = 255, .b = 255 },
        .panel = ui.Color{ .r = 255, .g = 255, .b = 255 },
        .row = ui.Color{ .r = 240, .g = 242, .b = 245 },
        .border = ui.Color{ .r = 221, .g = 223, .b = 226 },
        .text = ui.Color{ .r = 5, .g = 5, .b = 5 },
        .muted = ui.Color{ .r = 101, .g = 103, .b = 107 },
        .accent = messenger_blue,
    };
}

fn searchFill(mode: ThemeMode) ui.Color {
    return if (mode == .dark) ui.Color{ .r = 58, .g = 59, .b = 60 } else ui.Color{ .r = 240, .g = 242, .b = 245 };
}

fn incomingFill(mode: ThemeMode) ui.Color {
    return if (mode == .dark) ui.Color{ .r = 58, .g = 59, .b = 60 } else ui.Color{ .r = 228, .g = 230, .b = 235 };
}

fn selectedFill(mode: ThemeMode) ui.Color {
    return if (mode == .dark) ui.Color{ .r = 50, .g = 51, .b = 52 } else ui.Color{ .r = 235, .g = 245, .b = 255 };
}

fn dividerColor(mode: ThemeMode) ui.Color {
    return if (mode == .dark) ui.Color{ .r = 62, .g = 63, .b = 64 } else ui.Color{ .r = 226, .g = 229, .b = 233 };
}

fn chatAreaFill(mode: ThemeMode) ui.Color {
    return if (mode == .dark) ui.Color{ .r = 24, .g = 25, .b = 26 } else ui.Color{ .r = 255, .g = 255, .b = 255 };
}

fn demoEpoch() clock.Stamp {
    return .{ .keeper = .{ .bytes = [_]u8{7} ++ [_]u8{0} ** 31 }, .tick = 1 };
}

fn testIdentity(kind: identity.Kind, label: []const u8, epoch: clock.Stamp) identity.Identity {
    return identity.Identity.init(kind, identity.Source.prepare(.hash, &preimage.rawHash(label)).?, epoch).?;
}

const messenger_blue = ui.Color{ .r = 0, .g = 132, .b = 255 };

test "encrypted chat app renders contacts conversation and actions" {
    var state = try State.initDemo();
    var commands: [256]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [64]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);
    const component_test = @import("ui/components/TestSupport.zig");

    try state.render(&scene, &collector, ui.Rect.init(0, 0, 1000, 700), .{});

    try std.testing.expect(component_test.hasText(scene.written(), "EDGERUN"));
    try std.testing.expect(component_test.hasText(scene.written(), "Jordan"));
    try std.testing.expect(component_test.hasText(scene.written(), "my onion route"));
    try std.testing.expect(component_test.textCommandPrefix(scene.written(), "route-to-me-edgerun-chat") != null);
    try std.testing.expect(component_test.textCommandPrefix(scene.written(), "local-route") != null);
    try std.testing.expect(component_test.hasText(scene.written(), "Yes, I can read you."));
    try std.testing.expect(component_test.hasText(scene.written(), "object://image/8f21"));
    try std.testing.expect(component_test.hasText(scene.written(), "object://video/34aa"));
    try std.testing.expect(hasRegion(collector.written(), .button, create_route_button_id));
    try std.testing.expect(hasRegion(collector.written(), .button, import_button_id));
    try std.testing.expect(hasRegion(collector.written(), .button, seal_button_id));
    try std.testing.expect(hasRegion(collector.written(), .button, theme_button_id));
    try std.testing.expect(hasRegion(collector.written(), .button, image_button_id));
    try std.testing.expect(hasRegion(collector.written(), .button, video_button_id));
    try std.testing.expect(hasRegion(collector.written(), .button, emoji_button_id));
    try std.testing.expect(hasRegion(collector.written(), .button, send_button_id));
    try std.testing.expect(hasRegion(collector.written(), .textarea, compose_textarea_id));
    try std.testing.expect(hasRegion(collector.written(), .row_item, contact_row_base_id));
}

test "encrypted chat app activation selects imports sends and toggles theme" {
    var state = try State.initDemo();

    state.activate(.{ .kind = .row_item, .id = contact_row_base_id + 1, .bounds = ui.Rect.init(0, 0, 1, 1) });
    try std.testing.expectEqual(@as(usize, 1), state.selected_index);

    const before_messages = state.chat.message_count;
    state.activate(.{ .kind = .button, .id = send_button_id, .bounds = ui.Rect.init(0, 0, 1, 1) });
    try std.testing.expectEqual(before_messages + 1, state.chat.message_count);
    try std.testing.expectEqualStrings("Sent", state.status);

    const before_contacts = state.chat.contact_count;
    state.activate(.{ .kind = .button, .id = import_button_id, .bounds = ui.Rect.init(0, 0, 1, 1) });
    try std.testing.expectEqual(before_contacts + 1, state.chat.contact_count);
    try std.testing.expectEqualStrings("Imported", state.status);

    state.activate(.{ .kind = .button, .id = create_route_button_id, .bounds = ui.Rect.init(0, 0, 1, 1) });
    try std.testing.expectEqualStrings(state.ownRouteBytes(), state.import_preview);

    const before_media = state.chat.message_count;
    state.activate(.{ .kind = .button, .id = image_button_id, .bounds = ui.Rect.init(0, 0, 1, 1) });
    try std.testing.expectEqual(before_media + 1, state.chat.message_count);
    try std.testing.expectEqual(encrypted_chat.MediaKind.image, state.chat.messages[state.chat.message_count - 1].media_kind);
    state.activate(.{ .kind = .button, .id = video_button_id, .bounds = ui.Rect.init(0, 0, 1, 1) });
    try std.testing.expectEqual(encrypted_chat.MediaKind.video, state.chat.messages[state.chat.message_count - 1].media_kind);

    state.activate(.{ .kind = .button, .id = emoji_button_id, .bounds = ui.Rect.init(0, 0, 1, 1) });
    try std.testing.expectEqualStrings("Message... :)", state.compose);

    state.activate(.{ .kind = .button, .id = theme_button_id, .bounds = ui.Rect.init(0, 0, 1, 1) });
    try std.testing.expectEqual(ThemeMode.light, state.theme_mode);

    state.activate(.{ .kind = .button, .id = seal_button_id, .bounds = ui.Rect.init(0, 0, 1, 1) });
    try std.testing.expect(state.sealed);
}

test "encrypted chat app renders stacked layout and light theme" {
    var state = try State.initDemo();
    state.theme_mode = .light;
    var commands: [384]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [64]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);
    const component_test = @import("ui/components/TestSupport.zig");

    try state.render(&scene, &collector, ui.Rect.init(0, 0, 420, 760), .{});

    try std.testing.expect(component_test.hasText(scene.written(), "EDGERUN"));
    try std.testing.expect(component_test.hasIcon(scene.written(), @import("ui/icon_pack.zig").iconId(.send)));
    try std.testing.expect(hasRegion(collector.written(), .textarea, compose_textarea_id));
}

fn hasRegion(regions: []const interaction.Region, kind: ui.HitKind, id: u32) bool {
    for (regions) |region| {
        if (region.kind == kind and region.id == id) return true;
    }
    return false;
}
