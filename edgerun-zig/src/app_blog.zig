const std = @import("std");
const icon = @import("icon.zig");
const ui = @import("ui.zig");
const components = @import("ui_components.zig");
const app_chrome = @import("app_chrome.zig");
const design = @import("app_design.zig");
const interaction = @import("ui_interaction.zig");

pub const back_button_id: u32 = 40_001;
pub const first_post_button_id: u32 = 40_100;
pub const all_lessons_button_id: u32 = 40_899;
pub const first_arc_filter_button_id: u32 = 40_900;

const header_h: f32 = app_chrome.header_h;
const content_wide: f32 = design.content_wide;
const content_pad: f32 = design.content_pad;
const workflow_w: f32 = 380.0;
const index_intro_w: f32 = 760.0;
const guide_h: f32 = 280.0;
const line_h: f32 = 18.0;
const code_line_h: f32 = 17.0;
const code_pad_x: f32 = 18.0;
const code_pad_y: f32 = 18.0;
const code_text_h: f32 = 12.0;
const code_radius: f32 = 10.0;
const code_clip_inset: f32 = 1.0;
const cloud_meme_image_id: u32 = 1;
const post_list_gap: f32 = 0.0;
const arc_overview_gap: f32 = 18.0;
const arc_overview_h: f32 = 96.0;
const lesson_rhythm_gap: f32 = 24.0;
const lesson_rhythm_h: f32 = 118.0;
const section_header_h: f32 = 62.0;
const section_gap: f32 = 18.0;
const page_bottom_pad: f32 = 160.0;
const post_list_padding_x: f32 = 6.0;
const post_list_padding_y: f32 = 10.0;
const post_list_min_h: f32 = 76.0;
const post_list_meta_h: f32 = 12.0;
const post_list_meta_gap: f32 = 8.0;
const post_list_title_h: f32 = 20.0;
const post_list_title_avg_char_w: f32 = 10.2;
const post_list_title_max_lines: usize = 2;
const post_list_summary_gap: f32 = 6.0;
const post_list_summary_h: f32 = 15.0;
const post_list_summary_avg_char_w: f32 = 8.6;
const post_list_summary_max_lines: usize = 2;
const post_list_arrow_slot: f32 = 32.0;
const post_list_divider_h: f32 = 1.0;
const node_map_min_h: f32 = 720.0;
const node_map_grid: f32 = 26.0;
const node_map_dot_size: f32 = 2.0;
const node_map_dot_radius: f32 = 1.0;
const node_map_dot_alpha: u8 = 10;
const node_map_pattern_divisor: i32 = 7;
const post_footer_gap: f32 = 52.0;
const post_footer_column_gap: f32 = 36.0;
const post_footer_heading_h: f32 = 34.0;
const post_footer_list_gap: f32 = 0.0;
const post_footer_neighbor_count: usize = 2;
const post_sidebar_w: f32 = 292.0;
const post_sidebar_gap: f32 = 48.0;
const post_sidebar_h: f32 = 420.0;
const post_header_top_h: f32 = 112.0;
const post_title_line_h: f32 = 44.0;
const post_title_max_lines: usize = 3;
const post_title_average_char_w: f32 = 22.0;
const post_focus_gap: f32 = 22.0;
const post_focus_h: f32 = 92.0;
const post_demo_gap: f32 = 24.0;
const post_demo_h: f32 = 32.0;
const post_body_gap: f32 = 28.0;
const post_model_demo_h: f32 = 360.0;
const post_model_demo_pad: f32 = 22.0;
const post_model_card_count: usize = 3;
const post_model_card_gap: f32 = 14.0;
const post_model_card_h: f32 = 128.0;
const post_model_detail_h: f32 = 74.0;
const callout_gap: f32 = 18.0;
const callout_pad_x: f32 = 18.0;
const callout_pad_y: f32 = 16.0;
const callout_line_h: f32 = 18.0;
const callout_avg_char_w: f32 = 9.2;
const post_demo_directive_gap: f32 = 30.0;
const vpn_demo_h: f32 = 430.0;
const vpn_demo_pad: f32 = 22.0;
const vpn_demo_header_h: f32 = 74.0;
const vpn_demo_lane_gap: f32 = 16.0;
const vpn_demo_lane_h: f32 = 82.0;
const vpn_demo_actor_gap: f32 = 10.0;
const vpn_demo_actor_h: f32 = 48.0;
const vpn_demo_actor_radius: f32 = 6.0;
const vpn_demo_arrow_h: f32 = 2.0;
const vpn_demo_detail_h: f32 = 64.0;
const vpn_demo_actor_count: usize = 5;
const vpn_demo_lane_count: usize = 3;
const tls_demo_h: f32 = 360.0;
const tls_demo_pad: f32 = 22.0;
const tls_demo_actor_count: usize = 5;
const tls_demo_actor_h: f32 = 58.0;
const tls_demo_actor_gap: f32 = 12.0;
const tls_demo_path_y: f32 = 130.0;
const tls_demo_detail_h: f32 = 66.0;
const data_copy_demo_h: f32 = 410.0;
const data_copy_demo_pad: f32 = 22.0;
const data_copy_node_count: usize = 8;
const data_copy_node_w: f32 = 136.0;
const data_copy_node_h: f32 = 54.0;
const data_copy_row_gap: f32 = 28.0;
const data_copy_detail_h: f32 = 66.0;
const identity_demo_h: f32 = 430.0;
const identity_demo_pad: f32 = 22.0;
const identity_signal_count: usize = 7;
const identity_signal_h: f32 = 38.0;
const identity_signal_gap: f32 = 10.0;
const identity_signal_w: f32 = 188.0;
const identity_detail_h: f32 = 68.0;
const permission_demo_h: f32 = 400.0;
const permission_demo_pad: f32 = 22.0;
const permission_step_count: usize = 5;
const permission_step_h: f32 = 46.0;
const permission_step_gap: f32 = 12.0;
const permission_detail_h: f32 = 68.0;
const dns_demo_h: f32 = 390.0;
const dns_demo_pad: f32 = 22.0;
const dns_step_count: usize = 5;
const dns_step_h: f32 = 54.0;
const dns_step_gap: f32 = 12.0;
const dns_detail_h: f32 = 68.0;
const account_demo_h: f32 = 390.0;
const account_demo_pad: f32 = 22.0;
const account_path_count: usize = 4;
const account_box_h: f32 = 54.0;
const account_box_gap: f32 = 12.0;
const account_detail_h: f32 = 68.0;
const server_demo_h: f32 = 420.0;
const server_demo_pad: f32 = 22.0;
const server_stage_count: usize = 7;
const server_stage_w: f32 = 122.0;
const server_stage_h: f32 = 52.0;
const server_stage_gap: f32 = 12.0;
const server_detail_h: f32 = 68.0;
const push_demo_h: f32 = 390.0;
const push_demo_pad: f32 = 22.0;
const push_step_count: usize = 5;
const push_step_h: f32 = 56.0;
const push_step_gap: f32 = 12.0;
const push_detail_h: f32 = 68.0;
const dependency_demo_h: f32 = 430.0;
const dependency_demo_pad: f32 = 22.0;
const dependency_node_count: usize = 8;
const dependency_node_w: f32 = 128.0;
const dependency_node_h: f32 = 50.0;
const dependency_node_gap: f32 = 14.0;
const dependency_detail_h: f32 = 68.0;
const router_demo_h: f32 = 390.0;
const router_demo_pad: f32 = 22.0;
const router_step_count: usize = 5;
const router_step_h: f32 = 56.0;
const router_step_gap: f32 = 12.0;
const router_detail_h: f32 = 68.0;
const keypress_demo_h: f32 = 390.0;
const keypress_demo_pad: f32 = 22.0;
const keypress_step_count: usize = 6;
const keypress_step_h: f32 = 54.0;
const keypress_step_gap: f32 = 12.0;
const keypress_detail_h: f32 = 68.0;
const compute_demo_h: f32 = 400.0;
const compute_demo_pad: f32 = 22.0;
const compute_task_count: usize = 6;
const compute_task_w: f32 = 142.0;
const compute_task_h: f32 = 50.0;
const compute_task_gap: f32 = 14.0;
const compute_detail_h: f32 = 68.0;
const storage_demo_h: f32 = 410.0;
const storage_demo_pad: f32 = 22.0;
const storage_stage_count: usize = 5;
const storage_stage_h: f32 = 56.0;
const storage_stage_gap: f32 = 12.0;
const storage_detail_h: f32 = 68.0;
const trust_demo_h: f32 = 410.0;
const trust_demo_pad: f32 = 22.0;
const trust_step_count: usize = 5;
const trust_step_h: f32 = 56.0;
const trust_step_gap: f32 = 12.0;
const trust_detail_h: f32 = 68.0;
const authority_flow_demo_h: f32 = 430.0;
const authority_flow_demo_pad: f32 = 22.0;
const authority_flow_stage_count: usize = 6;
const authority_flow_stage_h: f32 = 62.0;
const authority_flow_stage_gap: f32 = 12.0;
const authority_flow_detail_h: f32 = 82.0;
const arc_local_start: usize = 0;
const arc_local_end: usize = 10;
const arc_network_start: usize = 10;
const arc_network_end: usize = 21;
const arc_device_start: usize = 21;
const arc_device_end: usize = 34;
const arc_control_start: usize = 34;
const arc_control_end: usize = 61;
const arc_accounting_start: usize = 61;
const arc_accounting_end: usize = 67;

pub const season_title = "EdgeRun Academy";
pub const season_subtitle = "A practical, slightly irreverent path through devices, networks, security, and user-owned computing.";
pub const arc_local = "Arc 0: How Your Device Works";
pub const arc_network = "Arc 1: How Data Moves";
pub const arc_device = "Arc 2: Who Owns The Device?";
pub const arc_control = "Arc 3: Who Controls The Rules?";
pub const arc_accounting = "Arc 4: Who Pays And Who Profits?";

const ArcSection = struct {
    title: []const u8,
    detail: []const u8,
    count_label: []const u8,
    card_title: []const u8,
    card_detail: []const u8,
    start: usize,
    end: usize,
};

const arc_sections = [_]ArcSection{
    .{
        .title = arc_local,
        .detail = "CPU, RAM, storage, GPU, OS, apps, firmware, keys, and the door out of the machine.",
        .count_label = "10 lessons",
        .card_title = "Your device is a computer",
        .card_detail = "CPU -> RAM -> OS",
        .start = arc_local_start,
        .end = arc_local_end,
    },
    .{
        .title = arc_network,
        .detail = "From keypress to server: the simple message path becomes visible.",
        .count_label = "11 lessons",
        .card_title = "How data moves",
        .card_detail = "keypress -> DNS -> TLS",
        .start = arc_network_start,
        .end = arc_network_end,
    },
    .{
        .title = arc_device,
        .detail = "After the message arrives, the endpoint becomes the real question.",
        .count_label = "13 lessons",
        .card_title = "Who owns the device",
        .card_detail = "phone -> account -> app store",
        .start = arc_device_start,
        .end = arc_device_end,
    },
    .{
        .title = arc_control,
        .detail = "The hidden levers that rewrite attention, updates, payments, discovery, and trust.",
        .count_label = "27 lessons",
        .card_title = "Who controls the rules",
        .card_detail = "updates -> feeds -> AI",
        .start = arc_control_start,
        .end = arc_control_end,
    },
    .{
        .title = arc_accounting,
        .detail = "Receipts, contribution, settlement, and why fair systems need explicit resource accounting.",
        .count_label = "6 lessons",
        .card_title = "Who pays",
        .card_detail = "receipts -> settlement",
        .start = arc_accounting_start,
        .end = arc_accounting_end,
    },
};

const palette = design.palette;

pub const Post = struct {
    arc: []const u8,
    title: []const u8,
    date: []const u8,
    category: []const u8,
    demo: []const u8,
    summary: []const u8,
    body: []const u8,
};

pub const posts = [_]Post{
    .{
        .arc = arc_local,
        .title = "Your Phone Is Not Magic. It Is a Tiny City.",
        .date = "May 23, 2026",
        .category = "Device",
        .demo = "Device city map",
        .summary = "Build the basic mental model: CPU, RAM, storage, GPU, network, OS, apps, drivers, firmware, and keys.",
        .body = @embedFile("blog/01-device-city.md"),
    },
    .{
        .arc = arc_local,
        .title = "CPU: The Worker That Follows Instructions",
        .date = "May 23, 2026",
        .category = "CPU",
        .demo = "Instruction stepper",
        .summary = "Show that code becomes instructions, instructions change memory, and apps take turns on the CPU.",
        .body = @embedFile("blog/02-cpu-instructions.md"),
    },
    .{
        .arc = arc_local,
        .title = "RAM: The Desk, Not the Filing Cabinet",
        .date = "May 23, 2026",
        .category = "Memory",
        .demo = "RAM allocation map",
        .summary = "Explain fast temporary working memory, app lifetimes, leaks, crashes, and parent-owned app allocation.",
        .body = @embedFile("blog/03-ram-desk.md"),
    },
    .{
        .arc = arc_local,
        .title = "Storage: Your Device's Long-Term Memory",
        .date = "May 23, 2026",
        .category = "Storage",
        .demo = "Sealed object drawer",
        .summary = "Separate bytes sitting on a disk from ownership, encryption, deletion, cloud source-of-truth, and portability.",
        .body = @embedFile("blog/04-storage-long-term.md"),
    },
    .{
        .arc = arc_local,
        .title = "GPU: The Machine That Draws Your Reality",
        .date = "May 23, 2026",
        .category = "Graphics",
        .demo = "Pixel pipeline",
        .summary = "Explain that the screen is pixels drawn by software, and UI rendering is also a trust boundary.",
        .body = @embedFile("blog/05-gpu-draws-reality.md"),
    },
    .{
        .arc = arc_local,
        .title = "The Operating System: The Referee You Forgot You Had",
        .date = "May 23, 2026",
        .category = "OS",
        .demo = "Resource referee",
        .summary = "Map CPU time, RAM, files, network, devices, permissions, users, processes, drivers, and platform rules.",
        .body = @embedFile("blog/06-os-referee.md"),
    },
    .{
        .arc = arc_local,
        .title = "Apps Are Guests, Not Owners",
        .date = "May 23, 2026",
        .category = "Apps",
        .demo = "Capability sandbox",
        .summary = "Show apps asking for resources through the OS, and why safe apps get only what they need.",
        .body = @embedFile("blog/07-apps-are-guests.md"),
    },
    .{
        .arc = arc_local,
        .title = "Drivers and Firmware: The Hidden Software Under the Software",
        .date = "May 23, 2026",
        .category = "Firmware",
        .demo = "Hidden software stack",
        .summary = "Reveal drivers and firmware inside Wi-Fi, Bluetooth, baseband, storage, cameras, GPUs, and secure elements.",
        .body = @embedFile("blog/08-drivers-firmware.md"),
    },
    .{
        .arc = arc_local,
        .title = "Keys, TPMs, and Secure Boot: Who Holds the Root?",
        .date = "May 23, 2026",
        .category = "Keys",
        .demo = "Root-of-trust ladder",
        .summary = "Explain secure boot, TPMs, attestation, sealing, transaction intent, and who controls the master key.",
        .body = @embedFile("blog/09-keys-tpm-secure-boot.md"),
    },
    .{
        .arc = arc_local,
        .title = "Network: The Door Out of the Machine",
        .date = "May 23, 2026",
        .category = "Network",
        .demo = "Packet exit path",
        .summary = "Show that networking begins after the app, OS, memory, keys, and hardware already decided what to send.",
        .body = @embedFile("blog/10-network-door.md"),
    },
    .{
        .arc = arc_network,
        .title = "You Pressed a Key. Now What?",
        .date = "May 23, 2026",
        .category = "Input",
        .demo = "Event timeline",
        .summary = "Follow a single keypress through hardware, the OS, app state, render, and a message object.",
        .body = @embedFile("blog/01-keypress.md"),
    },
    .{
        .arc = arc_network,
        .title = "Your App Is Not One Thing",
        .date = "May 23, 2026",
        .category = "Dependencies",
        .demo = "Dependency explosion",
        .summary = "Open a chat app and reveal the analytics, SDKs, cloud clients, and hidden code it may carry.",
        .body = @embedFile("blog/02-app-not-one-thing.md"),
    },
    .{
        .arc = arc_network,
        .title = "Before the Internet: Your Device Could Already Do Most of This",
        .date = "May 23, 2026",
        .category = "Local Compute",
        .demo = "Workload estimator",
        .summary = "Compare everyday app work with the storage, graphics, crypto, networking, and compute already on the device.",
        .body = @embedFile("blog/03-device-can-do-this.md"),
    },
    .{
        .arc = arc_network,
        .title = "The Router: Your First Border Crossing",
        .date = "May 23, 2026",
        .category = "Network",
        .demo = "Home network map",
        .summary = "Trace the first trust boundary outside the device: Wi-Fi, router policy, NAT, metadata, and local-only apps.",
        .body = @embedFile("blog/04-router-border.md"),
    },
    .{
        .arc = arc_network,
        .title = "The VPN Company Is Just Your New ISP",
        .date = "May 23, 2026",
        .category = "Tunnels",
        .demo = "Who sees what map",
        .summary = "Compare no VPN, commercial VPN, self-hosted VPN, sealed messages, and EdgeRun relays.",
        .body = @embedFile("blog/05-vpn-new-isp.md"),
    },
    .{
        .arc = arc_network,
        .title = "DNS: The Internet's Phonebook That Someone Else Controls",
        .date = "May 23, 2026",
        .category = "Naming",
        .demo = "Name resolution simulator",
        .summary = "Simulate resolution, then watch lies, expiry, seizure, blocks, and address moves.",
        .body = @embedFile("blog/06-dns-phonebook.md"),
    },
    .{
        .arc = arc_network,
        .title = "TLS: A Locked Tunnel To Someone Else's Building",
        .date = "May 23, 2026",
        .category = "Encryption",
        .demo = "Tunnel observer",
        .summary = "Show what TLS protects, what it cannot hide, and why certificates do not make the server your server.",
        .body = @embedFile("blog/07-tls-tunnel.md"),
    },
    .{
        .arc = arc_network,
        .title = "The Server Receives Hello",
        .date = "May 23, 2026",
        .category = "Server",
        .demo = "Server boundary map",
        .summary = "Follow a message through load balancers, app handlers, queues, logs, moderation hooks, and account policy.",
        .body = @embedFile("blog/08-server-receives-message.md"),
    },
    .{
        .arc = arc_network,
        .title = "The Database Remembers For You",
        .date = "May 23, 2026",
        .category = "Storage",
        .demo = "Append log versus remote DB",
        .summary = "Turn storage from magic into a concrete trust decision: indexes, backups, breaches, deletion, and ownership.",
        .body = @embedFile("blog/09-database-remembers.md"),
    },
    .{
        .arc = arc_network,
        .title = "Push Notifications: The Remote Bell On Your Friend's Phone",
        .date = "May 23, 2026",
        .category = "Notifications",
        .demo = "Wake path visualizer",
        .summary = "See how a message wakes another device through platform push services before the app even renders it.",
        .body = @embedFile("blog/10-push-notifications.md"),
    },
    .{
        .arc = arc_network,
        .title = "Your Friend Sees Hello",
        .date = "May 23, 2026",
        .category = "Rebuild",
        .demo = "Full path comparison",
        .summary = "Put the whole chain together, then compare the rented-screen path with a local-first EdgeRun path.",
        .body = @embedFile("blog/11-friend-sees-hello.md"),
    },
    .{
        .arc = arc_device,
        .title = "Try Living Without Your Phone for One Week",
        .date = "May 23, 2026",
        .category = "Experiment",
        .demo = "Phone dependency checklist",
        .summary = "Turn phone identity dependency into a personal test: no smartphone, normal internet, seven days.",
        .body = @embedFile("blog/12-phone-free-week.md"),
    },
    .{
        .arc = arc_device,
        .title = "I Bought the Phone. They Kept the Keys.",
        .date = "May 23, 2026",
        .category = "Ownership",
        .demo = "Right-to-own checklist",
        .summary = "Rooting, bootloaders, banking apps, vendor permission, and why owner control is treated as suspicious.",
        .body = @embedFile("blog/13-phone-kept-keys.md"),
    },
    .{
        .arc = arc_device,
        .title = "How Does Your Phone Know You Are You?",
        .date = "May 23, 2026",
        .category = "Identity",
        .demo = "Identity signal stack",
        .summary = "Unpack PINs, biometrics, platform accounts, app accounts, numbers, tokens, and behavior patterns.",
        .body = @embedFile("blog/14-phone-knows-you.md"),
    },
    .{
        .arc = arc_device,
        .title = "Your Account Is Not Your Identity",
        .date = "May 23, 2026",
        .category = "Accounts",
        .demo = "Account versus key model",
        .summary = "Show why accounts are rented permission containers and keys are portable identity proofs.",
        .body = @embedFile("blog/15-account-not-identity.md"),
    },
    .{
        .arc = arc_device,
        .title = "Where Is Your Data Actually Stored?",
        .date = "May 23, 2026",
        .category = "Memory",
        .demo = "Copy map",
        .summary = "Trace phone data through local storage, sync, databases, caches, logs, backups, SDKs, and AI pipelines.",
        .body = @embedFile("blog/16-where-data-stored.md"),
    },
    .{
        .arc = arc_device,
        .title = "The Internet Already Connects Everything. Platforms Keep It Apart.",
        .date = "May 23, 2026",
        .category = "Interop",
        .demo = "Protocol tower",
        .summary = "Show why TCP and UDP move bytes, but platforms still trap identity, data, contacts, and meaning.",
        .body = @embedFile("blog/17-interoperability-platforms.md"),
    },
    .{
        .arc = arc_device,
        .title = "The Phone Is Powerful, But Permissioned",
        .date = "May 23, 2026",
        .category = "Hardware",
        .demo = "Permission ladder",
        .summary = "Walk from hardware to bootloader, OS vendor, app store, app sandbox, and restricted device features.",
        .body = @embedFile("blog/18-phone-permissioned.md"),
    },
    .{
        .arc = arc_device,
        .title = "Security for Whom?",
        .date = "May 23, 2026",
        .category = "Security",
        .demo = "Override-key map",
        .summary = "Ask who security protects, against whom, and who holds the override key.",
        .body = @embedFile("blog/19-security-for-whom.md"),
    },
    .{
        .arc = arc_device,
        .title = "The Illegal Button",
        .date = "May 23, 2026",
        .category = "Control",
        .demo = "Ownership checklist",
        .summary = "Show how law, vendors, carriers, and platforms can restrict what owners may do with their own devices.",
        .body = @embedFile("blog/20-illegal-button.md"),
    },
    .{
        .arc = arc_device,
        .title = "The Baseband: The Computer Inside Your Phone You Barely Control",
        .date = "May 23, 2026",
        .category = "Firmware",
        .demo = "Phone computer map",
        .summary = "Split the phone into main CPU, baseband, secure enclave, radios, accelerators, and SIM identity.",
        .body = @embedFile("blog/21-baseband.md"),
    },
    .{
        .arc = arc_device,
        .title = "App Stores Became Governments",
        .date = "May 23, 2026",
        .category = "Distribution",
        .demo = "Gatekeeper map",
        .summary = "Explain how app stores control publishing, APIs, payments, updates, regions, and business models.",
        .body = @embedFile("blog/22-app-stores-governments.md"),
    },
    .{
        .arc = arc_device,
        .title = "Your Phone's Memory Is Not Your Memory",
        .date = "May 23, 2026",
        .category = "AI",
        .demo = "Personal context map",
        .summary = "Connect personal data, local assistants, fragmented company silos, and user-controlled AI.",
        .body = @embedFile("blog/23-phone-memory.md"),
    },
    .{
        .arc = arc_device,
        .title = "What Owning a Phone Should Mean",
        .date = "May 23, 2026",
        .category = "Ownership",
        .demo = "Ownership rights checklist",
        .summary = "Summarize installation, repair, export, local apps, user keys, sealed sharing, and permission auditability.",
        .body = @embedFile("blog/24-owning-phone.md"),
    },
    .{
        .arc = arc_control,
        .title = "Updates: Who Is Allowed To Change Your Machine?",
        .date = "May 23, 2026",
        .category = "Updates",
        .demo = "Mutation timeline",
        .summary = "Track OS, app, firmware, model, feature flag, and server-side changes that rewrite devices after purchase.",
        .body = @embedFile("blog/25-updates.md"),
    },
    .{
        .arc = arc_control,
        .title = "Notifications: The Remote-Control Channel",
        .date = "May 23, 2026",
        .category = "Attention",
        .demo = "Interrupt path map",
        .summary = "Show how push systems became attention control, login approval, payment confirmation, and dependency infrastructure.",
        .body = @embedFile("blog/26-notifications.md"),
    },
    .{
        .arc = arc_control,
        .title = "App Permissions: Fake Clarity",
        .date = "May 23, 2026",
        .category = "Capabilities",
        .demo = "Permission scope slider",
        .summary = "Compare broad prompts with narrow, temporary, inspectable, revocable, and logged capabilities.",
        .body = @embedFile("blog/27-permissions.md"),
    },
    .{
        .arc = arc_control,
        .title = "Every App Has A Second App Watching The First One",
        .date = "May 23, 2026",
        .category = "Telemetry",
        .demo = "Shadow event stream",
        .summary = "Expose logs, metrics, traces, crash reports, journeys, A/B buckets, fraud scores, and support events.",
        .body = @embedFile("blog/28-telemetry.md"),
    },
    .{
        .arc = arc_control,
        .title = "Your Data Is Not Just Stored. It Is Distilled.",
        .date = "May 23, 2026",
        .category = "AI",
        .demo = "Extraction map",
        .summary = "Explain how text, photos, clicks, voice, and behavior become models, rankings, risk scores, and profiles.",
        .body = @embedFile("blog/29-ai-training.md"),
    },
    .{
        .arc = arc_control,
        .title = "Money On The Internet Is Permissioned Messaging With Fees",
        .date = "May 23, 2026",
        .category = "Payments",
        .demo = "Payment rail trace",
        .summary = "Follow card networks, processors, KYC, fraud scoring, merchant bans, chargebacks, and QR payment dependency.",
        .body = @embedFile("blog/30-payments-rails.md"),
    },
    .{
        .arc = arc_control,
        .title = "The App Store Is A Tax Border Around Software",
        .date = "May 23, 2026",
        .category = "App Stores",
        .demo = "Distribution fee gate",
        .summary = "Separate store discovery from payment control and show how combined gatekeepers decide which businesses survive.",
        .body = @embedFile("blog/31-app-store-payments.md"),
    },
    .{
        .arc = arc_control,
        .title = "The Account That Recovers Your Accounts Owns Your Accounts",
        .date = "May 23, 2026",
        .category = "Recovery",
        .demo = "Root account graph",
        .summary = "Map Apple ID, Google, email, OAuth, password managers, cloud backups, activation locks, and bans.",
        .body = @embedFile("blog/32-cloud-account-root.md"),
    },
    .{
        .arc = arc_control,
        .title = "Recovery: The Ignored Hard Problem",
        .date = "May 23, 2026",
        .category = "Keys",
        .demo = "Recovery design board",
        .summary = "Balance user-owned keys with social recovery, hardware keys, encrypted backups, threshold keys, and inheritance.",
        .body = @embedFile("blog/33-recovery.md"),
    },
    .{
        .arc = arc_control,
        .title = "Open Systems Fail When They Ignore Abuse",
        .date = "May 23, 2026",
        .category = "Moderation",
        .demo = "Abuse response layers",
        .summary = "Treat spam, scams, abuse, malware, botnets, and fraud without handing one company everyone's identity.",
        .body = @embedFile("blog/34-moderation-abuse.md"),
    },
    .{
        .arc = arc_control,
        .title = "Reputation Should Be Portable",
        .date = "May 23, 2026",
        .category = "Trust",
        .demo = "Signed claim graph",
        .summary = "Introduce attestations, verified relationships, revocable credentials, local trust lists, and proof without exposure.",
        .body = @embedFile("blog/35-reputation-trust.md"),
    },
    .{
        .arc = arc_control,
        .title = "Whoever Controls Discovery Controls Reality",
        .date = "May 23, 2026",
        .category = "Discovery",
        .demo = "Ranking pressure map",
        .summary = "Show how search engines, app stores, feeds, marketplaces, ads, SEO, and shadowbans centralize finding.",
        .body = @embedFile("blog/36-search-discovery.md"),
    },
    .{
        .arc = arc_control,
        .title = "The Feed Is Not A Window. It Is A Steering Wheel.",
        .date = "May 23, 2026",
        .category = "Feeds",
        .demo = "Recommendation loop",
        .summary = "Make attention steering visible through engagement ranking, outrage loops, short video, and creator dependency.",
        .body = @embedFile("blog/37-feeds-algorithms.md"),
    },
    .{
        .arc = arc_control,
        .title = "Modern Development Often Replaces Engineering With Subscription Assembly",
        .date = "May 23, 2026",
        .category = "Development",
        .demo = "Dependency incentive map",
        .summary = "Connect dependency sprawl, Electron apps, cloud SDKs, SaaS defaults, observability, and Kubernetes everywhere.",
        .body = @embedFile("blog/38-developer-incentives.md"),
    },
    .{
        .arc = arc_control,
        .title = "The Greenest Cloud Request Is The One Your Device Never Had To Make",
        .date = "May 23, 2026",
        .category = "Compute",
        .demo = "Local versus cloud meter",
        .summary = "Compare idle local compute with cloud round trips, duplicate storage, tracking scripts, ads, and background tasks.",
        .body = @embedFile("blog/39-energy-compute-waste.md"),
    },
    .{
        .arc = arc_control,
        .title = "A Locked Device Becomes Trash Before The Hardware Dies",
        .date = "May 23, 2026",
        .category = "E-Waste",
        .demo = "Lifecycle lock map",
        .summary = "Tie sealed batteries, parts pairing, repair locks, support cutoffs, missing drivers, and locked bootloaders together.",
        .body = @embedFile("blog/40-ewaste-hardware-lifecycle.md"),
    },
    .{
        .arc = arc_control,
        .title = "A Light Bulb Should Not Need A Cloud Account",
        .date = "May 23, 2026",
        .category = "IoT",
        .demo = "Smart home dependency map",
        .summary = "Show smart-home fragmentation through separate apps, vendor clouds, region locks, firmware, and local control.",
        .body = @embedFile("blog/41-iot-smart-home.md"),
    },
    .{
        .arc = arc_control,
        .title = "Your Memories Should Not Be Trapped Inside App Databases",
        .date = "May 23, 2026",
        .category = "Files",
        .demo = "Archive portability test",
        .summary = "Use photos, notes, chats, exports, file formats, metadata, backups, search, and content addressing.",
        .body = @embedFile("blog/42-files-archives.md"),
    },
    .{
        .arc = arc_control,
        .title = "The Internet Has No Borders Until Something Goes Wrong",
        .date = "May 23, 2026",
        .category = "Jurisdiction",
        .demo = "Invisible border map",
        .summary = "Make terms, law enforcement, data residency, sanctions, payment restrictions, app availability, and seizures visible.",
        .body = @embedFile("blog/43-legal-jurisdiction.md"),
    },
    .{
        .arc = arc_control,
        .title = "You Do Not Negotiate With Apps. You Accept Private Law.",
        .date = "May 23, 2026",
        .category = "Terms",
        .demo = "Terms consequence scanner",
        .summary = "Explain how unreadable contracts define deletion, data use, arbitration, disputes, and sudden access loss.",
        .body = @embedFile("blog/44-terms-private-law.md"),
    },
    .{
        .arc = arc_control,
        .title = "Cloud Backup Should Not Become A Hostage Copy",
        .date = "May 23, 2026",
        .category = "Backups",
        .demo = "Restore dependency test",
        .summary = "Distinguish real backup from provider lock-in through restore permission, encryption, exports, and account lockout.",
        .body = @embedFile("blog/45-cloud-backups.md"),
    },
    .{
        .arc = arc_control,
        .title = "Attestation Asks Who Gets To Decide Which Software Is Legitimate",
        .date = "May 23, 2026",
        .category = "Attestation",
        .demo = "Trust root selector",
        .summary = "Compare TPMs, secure enclaves, hardware attestation, Play Integrity, DRM, banking apps, and device management.",
        .body = @embedFile("blog/46-attestation.md"),
    },
    .{
        .arc = arc_control,
        .title = "Radio Is Where Ownership Meets Physics, Law, And National Infrastructure",
        .date = "May 23, 2026",
        .category = "Radio",
        .demo = "Radio boundary map",
        .summary = "Cover cellular modems, SIMs, IMEI, carrier locks, emergency calls, spectrum law, firmware, and SDR contrast.",
        .body = @embedFile("blog/47-baseband-radio-law.md"),
    },
    .{
        .arc = arc_control,
        .title = "The Web Won Interoperability, Then Dragged An Operating System Into Every Tab",
        .date = "May 23, 2026",
        .category = "Browsers",
        .demo = "Browser runtime stack",
        .summary = "Explain browsers as app runtimes: standards, JavaScript, WASM, WebGL, sandboxing, fingerprinting, DRM, and storage.",
        .body = @embedFile("blog/48-browsers-operating-systems.md"),
    },
    .{
        .arc = arc_control,
        .title = "DRM Protects Someone Else's Business Model From Your Computer",
        .date = "May 23, 2026",
        .category = "DRM",
        .demo = "Protected content path",
        .summary = "Use Widevine, streaming, ebooks, games, HDMI, repair, and anti-circumvention law to explain hostile security.",
        .body = @embedFile("blog/49-drm.md"),
    },
    .{
        .arc = arc_control,
        .title = "Automation Is Great Until There Is No Human Left To Appeal To",
        .date = "May 23, 2026",
        .category = "Appeals",
        .demo = "Fallback path audit",
        .summary = "Show why account bans, bank freezes, delivery support loops, SIM loss, and identity failures need human fallback.",
        .body = @embedFile("blog/50-human-fallback.md"),
    },
    .{
        .arc = arc_control,
        .title = "A Personal AI Must Not Belong To Someone Else",
        .date = "May 23, 2026",
        .category = "Personal AI",
        .demo = "Assistant authority map",
        .summary = "End the arc with local AI, personal context, embeddings, memory, tool access, permission logs, and ownership.",
        .body = @embedFile("blog/51-personal-ai.md"),
    },
    .{
        .arc = arc_accounting,
        .title = "The Internet Is Not Free. It Is Bad At Showing Who Pays.",
        .date = "May 23, 2026",
        .category = "Accounting",
        .demo = "Resource receipt ledger",
        .summary = "Turn hidden extraction into explicit accounting for bandwidth, storage, compute, attention, identity, and settlement.",
        .body = @embedFile("blog/52-broken-accounting.md"),
    },
    .{
        .arc = arc_accounting,
        .title = "My Computer Has 64GB of RAM. Why Is My Compiler Grinding My Disk?",
        .date = "May 23, 2026",
        .category = "Tooling",
        .demo = "Memory and storage budget trace",
        .summary = "Use compiler disk churn to explain why active computation belongs in memory and durable state must be explicit.",
        .body = @embedFile("blog/53-compiler-grinding-disk.md"),
    },
    .{
        .arc = arc_accounting,
        .title = "The Dependency Problem: Nobody Knows What Their Software Runs Anymore",
        .date = "May 23, 2026",
        .category = "Dependencies",
        .demo = "Trusted core dependency map",
        .summary = "Explain dependencies as delegated authority and why the core cannot import behavior nobody can fully account for.",
        .body = @embedFile("blog/54-dependency-problem.md"),
    },
    .{
        .arc = arc_accounting,
        .title = "Preallocation Is Accountability",
        .date = "May 23, 2026",
        .category = "Resources",
        .demo = "Parent-owned memory budget",
        .summary = "Explain why honest programs declare budgets, why hidden memory pressure punishes users, and why resource pressure should flow upward.",
        .body = @embedFile("blog/55-preallocation-accountability.md"),
    },
    .{
        .arc = arc_accounting,
        .title = "Computers Are Deterministic. We Made Them Guess.",
        .date = "May 23, 2026",
        .category = "Determinism",
        .demo = "Resource authority trace",
        .summary = "Use a pointless swap storm to show why programs should receive explicit resources and authority instead of forcing the system to guess.",
        .body = @embedFile("blog/56-computers-deterministic.md"),
    },
    .{
        .arc = arc_accounting,
        .title = "Authority Is Not A Vibe. It Is A Receipt Chain.",
        .date = "May 25, 2026",
        .category = "Authority",
        .demo = "Actor, authority, receipt, object",
        .summary = "Explain how messages, memory views, storage, TPM operations, and child apps move without one principal becoming another.",
        .body = @embedFile("blog/57-authority-movement.md"),
    },
};

const episode_labels = blk: {
    var labels: [posts.len][]const u8 = undefined;
    for (&labels, 0..) |*label, index| {
        label.* = std.fmt.comptimePrint("Episode {d:0>2}", .{index + 1});
    }
    break :blk labels;
};

pub const State = struct {
    scroll_y: f32 = 0.0,
    hover_x: f32 = -1.0,
    hover_y: f32 = -1.0,
    selected_post_id: u32 = 0,
    arc_filter_index: ?usize = null,
};

pub fn render(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, state: State) (ui.RenderError || interaction.Error)!void {
    try fill(scene, bounds, palette.bg, 0.0);

    const content = centered(bounds, content_wide);
    const page_y = header_h - state.scroll_y;
    try renderNodeMap(scene, ui.Rect.init(bounds.x, page_y, bounds.w, @max(bounds.h, node_map_min_h)));

    const page_clip = ui.Rect.init(bounds.x, bounds.y + header_h, bounds.w, @max(1.0, bounds.h - header_h));
    if (try scene.pushClip(page_clip)) {
        defer scene.popClip();

        if (postIndexById(state.selected_post_id)) |index| {
            try renderPost(scene, collector, ui.Rect.init(content.x, page_y + 52.0, content.w, 1800.0), index, state.hover_x, state.hover_y);
        } else {
            try renderIndex(scene, collector, ui.Rect.init(content.x, page_y + 52.0, content.w, 1100.0), state.arc_filter_index);
        }
    }

    try renderHeader(scene, collector, ui.Rect.init(bounds.x, bounds.y, bounds.w, header_h), content);
}

pub fn postById(id: u32) ?Post {
    const index = postIndexById(id) orelse return null;
    return posts[index];
}

fn postIndexById(id: u32) ?usize {
    if (id < first_post_button_id) return null;
    const index: usize = @intCast(id - first_post_button_id);
    if (index >= posts.len) return null;
    return index;
}

pub fn postIdAt(index: usize) u32 {
    return first_post_button_id + @as(u32, @intCast(index));
}

pub fn arcFilterButtonId(index: usize) u32 {
    return first_arc_filter_button_id + @as(u32, @intCast(index));
}

pub fn arcFilterIndexById(id: u32) ?usize {
    if (id < first_arc_filter_button_id) return null;
    const index: usize = @intCast(id - first_arc_filter_button_id);
    if (index >= arc_sections.len) return null;
    return index;
}

fn episodeAt(index: usize) usize {
    return index + 1;
}

fn renderHeader(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, content: ui.Rect) (ui.RenderError || interaction.Error)!void {
    try app_chrome.renderHeader(scene, collector, bounds, content, .blog);
}

fn renderIndex(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, arc_filter_index: ?usize) (ui.RenderError || interaction.Error)!void {
    _ = try flowIndexContent(scene, collector, bounds, arc_filter_index);
}

fn flowIndexContent(scene: ?*ui.Scene, collector: ?*interaction.Collector, bounds: ui.Rect, arc_filter_index: ?usize) (ui.RenderError || interaction.Error)!f32 {
    const split = bounds.w >= 980.0;
    const headline_w = if (split) @min(index_intro_w, bounds.w - workflow_w - 64.0) else bounds.w;
    const workflow_y = if (split) bounds.y + 18.0 else bounds.y + 230.0;
    const overview_y = if (split) bounds.y + 228.0 else workflow_y + 206.0;
    const rhythm_y = overview_y + arc_overview_h + lesson_rhythm_gap;
    const intro_h = rhythm_y - bounds.y + lesson_rhythm_h + 46.0;

    if (scene) |target| {
        try tag(target, ui.Rect.init(bounds.x, bounds.y, 136.0, 24.0), "EDGERUN ACADEMY", palette.primary);
        try text(target, bounds.x, bounds.y + 48.0, headline_w, 46.0, "Computers Are", palette.text);
        try text(target, bounds.x, bounds.y + 102.0, headline_w, 46.0, "Not Magic", palette.text);
        try paragraph(target, ui.Rect.init(bounds.x, bounds.y + 162.0, headline_w, 72.0), "A guided, hands-on path through devices, networks, security, and user-owned computing. The old man can still yell at cloud; now the yelling has a syllabus.");

        if (split) {
            try renderCloudMeme(target, ui.Rect.init(bounds.x + bounds.w - workflow_w, workflow_y, workflow_w, 188.0));
        } else {
            try renderCloudMeme(target, ui.Rect.init(bounds.x, workflow_y, bounds.w, 184.0));
        }

        try renderArcOverview(target, collector.?, ui.Rect.init(bounds.x, overview_y, bounds.w, arc_overview_h), arc_filter_index);
        try renderLessonRhythm(target, collector.?, ui.Rect.init(bounds.x, rhythm_y, bounds.w, lesson_rhythm_h));
    }

    var next_y = bounds.y + intro_h;
    if (arc_filter_index) |index| {
        next_y = try flowPostSection(scene, collector, bounds, next_y, arc_sections[index]);
    } else {
        for (arc_sections) |section| {
            next_y = try flowPostSection(scene, collector, bounds, next_y, section);
        }
    }

    const guide_y = next_y + 90.0;
    if (scene) |target| try renderReaderGuide(target, ui.Rect.init(bounds.x, guide_y, bounds.w, guide_h));
    return guide_y + guide_h;
}

pub fn indexContentHeight(width: f32) f32 {
    return indexContentHeightFiltered(width, null);
}

pub fn indexContentHeightFiltered(width: f32, arc_filter_index: ?usize) f32 {
    const content_w = @min(content_wide, @max(1.0, width - content_pad * 2.0));
    const measured_h = flowIndexContent(null, null, ui.Rect.init(0.0, 0.0, content_w, 1.0), arc_filter_index) catch unreachable;
    return 52.0 + measured_h + page_bottom_pad;
}

pub fn postContentHeight(width: f32, post_id: u32) f32 {
    const index = postIndexById(post_id) orelse return indexContentHeight(width);
    const content_w = @min(content_wide, @max(1.0, width - content_pad * 2.0));
    const measured_h = flowPostContent(null, null, ui.Rect.init(0.0, 0.0, content_w, 1.0), index, -1.0, -1.0) catch unreachable;
    return 52.0 + measured_h + page_bottom_pad;
}

fn renderArcOverview(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, active_index: ?usize) (ui.RenderError || interaction.Error)!void {
    const cols: usize = if (bounds.w >= 1040.0) 5 else if (bounds.w >= 700.0) 3 else 2;
    const rows = (arc_sections.len + cols - 1) / cols;
    const card_h = (bounds.h - arc_overview_gap * @as(f32, @floatFromInt(rows - 1))) / @as(f32, @floatFromInt(rows));
    for (arc_sections, 0..) |section, index| {
        const row = index / cols;
        const col = index % cols;
        const card = colBounds(bounds, cols, arc_overview_gap, col, bounds.y + @as(f32, @floatFromInt(row)) * (card_h + arc_overview_gap), card_h);
        const active = if (active_index) |found| found == index else false;
        try nativeComponentVisual(scene, card, .{ .card = .{
            .title = section.card_title,
            .detail = section.card_detail,
            .variant = if (active) .elevated else .subtle,
        } });
        if (active) try scene.pushRect(card, palette.primary, .border, app_chrome.surface_radius, 0.0);
        try nativeComponentVisual(scene, ui.Rect.init(card.x + @max(14.0, card.w - 106.0), card.y + @max(10.0, card.h - 30.0), 92.0, 22.0), .{ .badge = .{
            .label = section.count_label,
            .variant = if (active) .default else .outline,
        } });
        try hit(collector, card, .button, arcFilterButtonId(index));
    }
}

fn renderLessonRhythm(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect) (ui.RenderError || interaction.Error)!void {
    try nativeCard(scene, bounds, "", "");
    try tag(scene, ui.Rect.init(bounds.x + 18.0, bounds.y + 18.0, 92.0, 24.0), "HOW TO READ", palette.blue);
    try text(scene, bounds.x + 128.0, bounds.y + 23.0, bounds.w - 286.0, 14.0, "Every lesson has a job: notice the ordinary action, name the hidden authority, then ask what the user can own.", palette.text);
    try outlineButton(scene, collector, ui.Rect.init(bounds.x + bounds.w - 140.0, bounds.y + 14.0, 122.0, 32.0), "All Lessons", all_lessons_button_id);

    const gap: f32 = 14.0;
    const item_title_y = bounds.y + 58.0;
    const item_detail_y = item_title_y + 30.0;
    const item_title_h: f32 = 24.0;
    const item_detail_h: f32 = 16.0;
    const item_w = (bounds.w - 36.0 - gap * 2.0) / 3.0;
    const steps = [_]struct { []const u8, []const u8 }{
        .{ "1. Observe", "start with something normal" },
        .{ "2. Name", "find the key, policy, or server" },
        .{ "3. Own", "move authority back to the user" },
    };
    for (steps, 0..) |step, index| {
        const x = bounds.x + 18.0 + @as(f32, @floatFromInt(index)) * (item_w + gap);
        try text(scene, x, item_title_y, item_w, item_title_h, step[0], palette.primary);
        try text(scene, x, item_detail_y, item_w, item_detail_h, step[1], palette.dim);
    }
}

fn flowPostSection(scene: ?*ui.Scene, collector: ?*interaction.Collector, bounds: ui.Rect, y: f32, section: ArcSection) (ui.RenderError || interaction.Error)!f32 {
    if (scene) |target| {
        try text(target, bounds.x, y, bounds.w, 20.0, section.title, palette.text);
        try paragraph(target, ui.Rect.init(bounds.x, y + 28.0, @min(bounds.w, 760.0), 30.0), section.detail);
    }

    var item_y = y + section_header_h;
    for (posts[section.start..section.end], section.start..) |post, index| {
        const item_h = postListItemHeight(bounds.w, index, post);
        if (scene) |target| try renderPostListItem(target, collector.?, ui.Rect.init(bounds.x, item_y, bounds.w, item_h), index, post);
        item_y += item_h + post_list_gap;
    }

    return item_y + section_gap;
}

fn renderCloudMeme(scene: *ui.Scene, bounds: ui.Rect) ui.RenderError!void {
    try nativeCard(scene, bounds, "", "");
    try scene.pushImageQuad(.{
        .bounds = bounds.insetUniform(1.0),
        .atlas_id = cloud_meme_image_id,
        .color = ui.Color{ .r = 255, .g = 255, .b = 255 },
    });
}

fn renderWorkflow(scene: *ui.Scene, bounds: ui.Rect) ui.RenderError!void {
    try nativeCard(scene, bounds, "", "");
    try text(scene, bounds.x + 20.0, bounds.y + 18.0, bounds.w - 40.0, 16.0, "Season Path", palette.text);
    const rows = [_]struct { icon.Icon, []const u8, []const u8 }{
        .{ .key, "Keypress", "hardware -> OS -> app" },
        .{ .network, "Network", "router -> VPN -> DNS -> TLS" },
        .{ .user, "Authority", "identity -> storage -> execution" },
    };
    var y = bounds.y + 54.0;
    for (rows) |row| {
        const box = ui.Rect.init(bounds.x + 20.0, y, 28.0, 28.0);
        try fill(scene, box, palette.neutral_soft, 7.0);
        try iconQuad(scene, box.insetUniform(7.0), row[0], palette.primary);
        try text(scene, bounds.x + 60.0, y + 1.0, bounds.w - 80.0, 13.0, row[1], palette.text);
        try text(scene, bounds.x + 60.0, y + 20.0, bounds.w - 80.0, 11.0, row[2], palette.dim);
        y += 42.0;
    }
}

fn renderPostListItem(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, index: usize, post: Post) (ui.RenderError || interaction.Error)!void {
    try nativeComponentVisual(scene, bounds, .{ .card = .{
        .title = "",
        .detail = "",
        .variant = .subtle,
    } });
    const text_x = bounds.x + post_list_padding_x;
    const text_w = postListTextWidth(bounds.w);
    const meta_y = bounds.y + post_list_padding_y;
    try text(scene, text_x, meta_y, 118.0, post_list_meta_h, episodeLabel(episodeAt(index)), palette.primary);
    try alignedText(scene, text_x, meta_y, text_w, post_list_meta_h, post.arc, palette.dim, .end);

    const title_y = meta_y + post_list_meta_h + post_list_meta_gap;
    const title_lines = wrappedLineCount(post.title, text_w, post_list_title_avg_char_w, post_list_title_max_lines);
    const title_h = post_list_title_h * @as(f32, @floatFromInt(title_lines));
    try scene.pushWrappedText(ui.Rect.init(text_x, title_y, text_w, title_h), post.title, palette.text, .{
        .line_height = post_list_title_h,
        .average_char_width = post_list_title_avg_char_w,
        .max_lines = post_list_title_max_lines,
    });

    const summary_y = title_y + title_h + post_list_summary_gap;
    const summary_lines = wrappedLineCount(post.summary, text_w, post_list_summary_avg_char_w, post_list_summary_max_lines);
    const summary_h = post_list_summary_h * @as(f32, @floatFromInt(summary_lines));
    try scene.pushWrappedText(ui.Rect.init(text_x, summary_y, text_w, summary_h), post.summary, palette.dim, .{
        .line_height = post_list_summary_h,
        .average_char_width = post_list_summary_avg_char_w,
        .max_lines = post_list_summary_max_lines,
    });

    try iconQuad(scene, ui.Rect.init(bounds.x + bounds.w - 22.0, bounds.y + (bounds.h - 16.0) * 0.5, 16.0, 16.0), .chevron_right, palette.primary);
    try hit(collector, bounds, .button, postIdAt(index));
}

fn postListItemHeight(width: f32, index: usize, post: Post) f32 {
    _ = index;
    const text_w = postListTextWidth(width);
    const title_lines = wrappedLineCount(post.title, text_w, post_list_title_avg_char_w, post_list_title_max_lines);
    const summary_lines = wrappedLineCount(post.summary, text_w, post_list_summary_avg_char_w, post_list_summary_max_lines);
    const text_h = post_list_padding_y * 2.0 +
        post_list_meta_h +
        post_list_meta_gap +
        post_list_title_h * @as(f32, @floatFromInt(title_lines)) +
        post_list_summary_gap +
        post_list_summary_h * @as(f32, @floatFromInt(summary_lines));
    return @max(post_list_min_h, text_h);
}

fn postListTextWidth(width: f32) f32 {
    return @max(1.0, width - post_list_padding_x * 2.0 - post_list_arrow_slot);
}

fn renderReaderGuide(scene: *ui.Scene, bounds: ui.Rect) ui.RenderError!void {
    const split = bounds.w >= 900.0;
    const copy_w = if (split) bounds.w * 0.46 else bounds.w - 48.0;
    const code_bounds = if (split)
        ui.Rect.init(bounds.x + bounds.w * 0.54, bounds.y + 34.0, bounds.w * 0.42, bounds.h - 68.0)
    else
        ui.Rect.init(bounds.x + 24.0, bounds.y + 166.0, bounds.w - 48.0, bounds.h - 190.0);

    try nativeCard(scene, bounds, "", "");
    try tag(scene, ui.Rect.init(bounds.x + 24.0, bounds.y + 24.0, 110.0, 24.0), "ACADEMY MAP", palette.blue);
    try text(scene, bounds.x + 24.0, bounds.y + 70.0, bounds.w - 48.0, 24.0, "Start at the phone. End with user-owned authority.", palette.text);
    try paragraph(scene, ui.Rect.init(bounds.x + 24.0, bounds.y + 112.0, copy_w, 82.0), "The joke stays useful: every lesson follows one ordinary action until the invisible middlemen become visible enough to question.");
    try codeBlock(scene, code_bounds, &.{
        "learning path",
        "01 device basics",
        "02 data movement",
        "03 ownership and identity",
        "04 platform control",
        "05 accounting and resources",
    });
}

fn renderPost(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, index: usize, hover_x: f32, hover_y: f32) (ui.RenderError || interaction.Error)!void {
    _ = try flowPostContent(scene, collector, bounds, index, hover_x, hover_y);
}

fn flowPostContent(scene: ?*ui.Scene, collector: ?*interaction.Collector, bounds: ui.Rect, index: usize, hover_x: f32, hover_y: f32) (ui.RenderError || interaction.Error)!f32 {
    const post = posts[index];
    const sidebar_split = bounds.w >= 980.0;
    const main_w = if (sidebar_split) @max(320.0, bounds.w - post_sidebar_w - post_sidebar_gap) else bounds.w;
    const title_w = @min(main_w, 760.0);
    const title_h = wrappedTextHeight(post.title, title_w, post_title_line_h, post_title_max_lines, post_title_average_char_w);
    const focus_y = bounds.y + post_header_top_h + title_h + post_focus_gap;
    const demo_y = focus_y + post_focus_h + post_demo_gap;
    const body_y = demo_y + post_demo_h + post_body_gap;
    if (scene) |target| {
        try outlineButton(target, collector.?, ui.Rect.init(bounds.x, bounds.y, 134.0, 34.0), "All Lessons", back_button_id);
        try nativeBadge(target, ui.Rect.init(bounds.x, bounds.y + 62.0, 118.0, 24.0), episodeLabel(episodeAt(index)));
        try text(target, bounds.x + 136.0, bounds.y + 68.0, 280.0, 12.0, post.arc, palette.dim);
        try target.pushWrappedText(ui.Rect.init(bounds.x, bounds.y + post_header_top_h, title_w, title_h), post.title, palette.text, .{
            .line_height = post_title_line_h,
            .average_char_width = post_title_average_char_w,
            .max_lines = post_title_max_lines,
        });
        try renderLessonFocus(target, ui.Rect.init(bounds.x, focus_y, @min(main_w, 760.0), post_focus_h), post);
        try paragraph(target, ui.Rect.init(bounds.x, demo_y, @min(main_w, 720.0), post_demo_h), post.demo);
    }

    const content = ui.Rect.init(bounds.x, body_y, @min(main_w, 820.0), 1300.0);
    const content_end = try flowMarkdown(scene, content, index, bodyWithoutTitle(post.body), hover_x, hover_y);
    const footer_y = content_end + post_footer_gap;
    const footer_h = postFooterHeight(bounds.w, index);
    if (scene) |target| {
        try renderPostFooter(target, collector.?, ui.Rect.init(bounds.x, footer_y, bounds.w, footer_h), index);
        if (sidebar_split) try renderSidebar(target, ui.Rect.init(bounds.x + bounds.w - post_sidebar_w, bounds.y + post_header_top_h, post_sidebar_w, post_sidebar_h), index);
    }
    return footer_y + footer_h;
}

fn renderLessonFocus(scene: *ui.Scene, bounds: ui.Rect, post: Post) ui.RenderError!void {
    try nativeCard(scene, bounds, "", "");
    try tag(scene, ui.Rect.init(bounds.x + 18.0, bounds.y + 18.0, 86.0, 24.0), "LESSON", palette.blue);
    try text(scene, bounds.x + 122.0, bounds.y + 22.0, bounds.w - 140.0, 14.0, post.category, palette.primary);
    try paragraph(scene, ui.Rect.init(bounds.x + 18.0, bounds.y + 54.0, bounds.w - 36.0, 28.0), "Use the demo, then read for the authority shift: what action looks local, who actually decides, and what a user-owned version would change.");
}

fn renderPostFooter(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, index: usize) (ui.RenderError || interaction.Error)!void {
    const has_previous = neighborIndex(index, .previous, 0) != null;
    const has_next = neighborIndex(index, .next, 0) != null;
    if (!has_previous and !has_next) return;
    const split = bounds.w >= 760.0;
    if (split and has_previous and has_next) {
        const column_w = (bounds.w - post_footer_column_gap) * 0.5;
        const previous = ui.Rect.init(bounds.x, bounds.y, column_w, bounds.h);
        const next = ui.Rect.init(bounds.x + column_w + post_footer_column_gap, bounds.y, column_w, bounds.h);
        _ = try flowNeighborColumn(scene, collector, previous, index, .previous);
        _ = try flowNeighborColumn(scene, collector, next, index, .next);
        return;
    }

    var y = bounds.y;
    if (has_previous) {
        const previous = ui.Rect.init(bounds.x, y, bounds.w, bounds.h);
        y += try flowNeighborColumn(scene, collector, previous, index, .previous) + 42.0;
    }
    if (has_next) {
        const next = ui.Rect.init(bounds.x, y, bounds.w, bounds.h);
        _ = try flowNeighborColumn(scene, collector, next, index, .next);
    }
}

fn postFooterHeight(width: f32, index: usize) f32 {
    const has_previous = neighborIndex(index, .previous, 0) != null;
    const has_next = neighborIndex(index, .next, 0) != null;
    if (!has_previous and !has_next) return 0.0;
    if (width >= 760.0 and has_previous and has_next) {
        const column_w = (width - post_footer_column_gap) * 0.5;
        return @max(
            renderNeighborColumnHeight(column_w, index, .previous),
            renderNeighborColumnHeight(column_w, index, .next),
        );
    }
    var height: f32 = 0.0;
    if (has_previous) height += renderNeighborColumnHeight(width, index, .previous);
    if (has_previous and has_next) height += 42.0;
    if (has_next) height += renderNeighborColumnHeight(width, index, .next);
    return height;
}

const NeighborDirection = enum {
    previous,
    next,
};

fn renderNeighborColumnHeight(width: f32, index: usize, direction: NeighborDirection) f32 {
    return flowNeighborColumn(null, null, ui.Rect.init(0.0, 0.0, width, 1.0), index, direction) catch unreachable;
}

fn flowNeighborColumn(scene: ?*ui.Scene, collector: ?*interaction.Collector, bounds: ui.Rect, index: usize, direction: NeighborDirection) (ui.RenderError || interaction.Error)!f32 {
    const heading = switch (direction) {
        .previous => "Previous",
        .next => "Next",
    };
    if (scene) |target| try text(target, bounds.x, bounds.y, bounds.w, 20.0, heading, palette.text);
    var y = bounds.y + post_footer_heading_h;
    var count: usize = 0;
    while (count < post_footer_neighbor_count) : (count += 1) {
        const neighbor_index = neighborIndex(index, direction, count) orelse break;
        const neighbor = posts[neighbor_index];
        const item_h = postListItemHeight(bounds.w, neighbor_index, neighbor);
        if (scene) |target| try renderPostListItem(target, collector.?, ui.Rect.init(bounds.x, y, bounds.w, item_h), neighbor_index, neighbor);
        y += item_h + post_footer_list_gap;
    }
    return y - bounds.y;
}

fn neighborIndex(index: usize, direction: NeighborDirection, offset: usize) ?usize {
    return switch (direction) {
        .previous => {
            const distance = offset + 1;
            if (index < distance) return null;
            return index - distance;
        },
        .next => {
            const next = index + offset + 1;
            if (next >= posts.len) return null;
            return next;
        },
    };
}

fn renderSidebar(scene: *ui.Scene, bounds: ui.Rect, index: usize) ui.RenderError!void {
    if (bounds.x < 880.0) return;
    const post = posts[index];
    try nativeCard(scene, bounds, "", "");
    try text(scene, bounds.x + 20.0, bounds.y + 20.0, bounds.w - 40.0, 16.0, "Learning path", palette.text);
    try text(scene, bounds.x + 20.0, bounds.y + 52.0, bounds.w - 40.0, 12.0, episodeLabel(episodeAt(index)), palette.primary);
    try paragraph(scene, ui.Rect.init(bounds.x + 20.0, bounds.y + 78.0, bounds.w - 40.0, 42.0), post.arc);

    try fill(scene, ui.Rect.init(bounds.x + 20.0, bounds.y + 138.0, bounds.w - 40.0, 1.0), palette.border, 0.0);
    try text(scene, bounds.x + 20.0, bounds.y + 160.0, bounds.w - 40.0, 12.0, "Interactive model", palette.dim);
    try paragraph(scene, ui.Rect.init(bounds.x + 20.0, bounds.y + 184.0, bounds.w - 40.0, 48.0), post.demo);

    try fill(scene, ui.Rect.init(bounds.x + 20.0, bounds.y + 250.0, bounds.w - 40.0, 1.0), palette.border, 0.0);
    if (neighborIndex(index, .previous, 0)) |previous_index| {
        try text(scene, bounds.x + 20.0, bounds.y + 272.0, bounds.w - 40.0, 12.0, "Builds on", palette.dim);
        try scene.pushWrappedText(ui.Rect.init(bounds.x + 20.0, bounds.y + 294.0, bounds.w - 40.0, 36.0), posts[previous_index].title, palette.text, .{
            .line_height = 18.0,
            .average_char_width = 8.8,
            .max_lines = 2,
        });
    } else {
        try text(scene, bounds.x + 20.0, bounds.y + 272.0, bounds.w - 40.0, 12.0, "Starts with", palette.dim);
        try text(scene, bounds.x + 20.0, bounds.y + 294.0, bounds.w - 40.0, 14.0, "the device itself", palette.text);
    }
    if (neighborIndex(index, .next, 0)) |next_index| {
        try text(scene, bounds.x + 20.0, bounds.y + 342.0, bounds.w - 40.0, 12.0, "Next", palette.dim);
        try scene.pushWrappedText(ui.Rect.init(bounds.x + 20.0, bounds.y + 364.0, bounds.w - 40.0, 36.0), posts[next_index].title, palette.text, .{
            .line_height = 18.0,
            .average_char_width = 8.8,
            .max_lines = 2,
        });
    }
}

const DemoDirective = enum {
    post_model,
    vpn_who_sees_what,
    tls_endpoint,
    data_copy_map,
    phone_identity_stack,
    permission_ladder,
    dns_lookup_path,
    account_vs_key,
    server_pipeline,
    push_wake_path,
    dependency_graph,
    router_boundary,
    keypress_commit_path,
    local_compute_capacity,
    storage_sealed_objects,
    secure_boot_root,
    authority_flow,
};

fn flowMarkdown(scene: ?*ui.Scene, bounds: ui.Rect, post_index: usize, source: []const u8, hover_x: f32, hover_y: f32) ui.RenderError!f32 {
    var y = bounds.y;
    var in_code = false;
    var code_lines: [12][]const u8 = undefined;
    var code_count: usize = 0;
    var it = std.mem.splitScalar(u8, source, '\n');
    while (it.next()) |raw_line| {
        const line_value = std.mem.trim(u8, raw_line, "\r");
        if (std.mem.eql(u8, line_value, "```zig") or std.mem.eql(u8, line_value, "```text") or std.mem.eql(u8, line_value, "```")) {
            if (in_code) {
                const height = 28.0 + code_line_h * @as(f32, @floatFromInt(code_count));
                if (scene) |target| try codeBlock(target, ui.Rect.init(bounds.x, y, bounds.w, height), code_lines[0..code_count]);
                y += height + 28.0;
                code_count = 0;
                in_code = false;
            } else {
                in_code = true;
                code_count = 0;
            }
            continue;
        }
        if (in_code) {
            if (code_count < code_lines.len) {
                code_lines[code_count] = line_value;
                code_count += 1;
            }
            continue;
        }
        if (demoDirective(line_value)) |directive| {
            y += try flowDemoDirective(scene, ui.Rect.init(bounds.x, y, bounds.w, demoHeight(directive)), post_index, directive, hover_x, hover_y);
            y += post_demo_directive_gap;
            continue;
        }
        if (line_value.len == 0) {
            y += 12.0;
        } else if (std.mem.startsWith(u8, line_value, "# ")) {
            if (scene) |target| try target.pushWrappedText(ui.Rect.init(bounds.x, y, bounds.w, 84.0), line_value[2..], palette.text, .{
                .line_height = 34.0,
                .average_char_width = 15.0,
                .max_lines = 2,
            });
            y += 88.0;
        } else if (std.mem.startsWith(u8, line_value, "## ")) {
            if (scene) |target| try text(target, bounds.x, y + 16.0, bounds.w, 24.0, line_value[3..], palette.text);
            y += 58.0;
        } else if (std.mem.startsWith(u8, line_value, "- ")) {
            if (scene) |target| {
                try fill(target, ui.Rect.init(bounds.x + 2.0, y + 8.0, 5.0, 5.0), palette.primary, 3.0);
                try paragraph(target, ui.Rect.init(bounds.x + 22.0, y, bounds.w - 22.0, 42.0), line_value[2..]);
            }
            y += 44.0;
        } else if (std.mem.startsWith(u8, line_value, "> ")) {
            const callout_h = calloutHeight(line_value[2..], bounds.w);
            if (scene) |target| try callout(target, ui.Rect.init(bounds.x, y, bounds.w, callout_h), line_value[2..]);
            y += callout_h + callout_gap;
        } else {
            if (scene) |target| try paragraph(target, ui.Rect.init(bounds.x, y, bounds.w, 76.0), line_value);
            y += paragraphHeight(line_value, bounds.w) + 14.0;
        }
    }
    return y;
}

fn demoDirective(line_value: []const u8) ?DemoDirective {
    if (std.mem.eql(u8, line_value, "[[demo:post_model]]")) return .post_model;
    if (std.mem.eql(u8, line_value, "[[demo:vpn_who_sees_what]]")) return .vpn_who_sees_what;
    if (std.mem.eql(u8, line_value, "[[demo:tls_endpoint]]")) return .tls_endpoint;
    if (std.mem.eql(u8, line_value, "[[demo:data_copy_map]]")) return .data_copy_map;
    if (std.mem.eql(u8, line_value, "[[demo:phone_identity_stack]]")) return .phone_identity_stack;
    if (std.mem.eql(u8, line_value, "[[demo:permission_ladder]]")) return .permission_ladder;
    if (std.mem.eql(u8, line_value, "[[demo:dns_lookup_path]]")) return .dns_lookup_path;
    if (std.mem.eql(u8, line_value, "[[demo:account_vs_key]]")) return .account_vs_key;
    if (std.mem.eql(u8, line_value, "[[demo:server_pipeline]]")) return .server_pipeline;
    if (std.mem.eql(u8, line_value, "[[demo:push_wake_path]]")) return .push_wake_path;
    if (std.mem.eql(u8, line_value, "[[demo:dependency_graph]]")) return .dependency_graph;
    if (std.mem.eql(u8, line_value, "[[demo:router_boundary]]")) return .router_boundary;
    if (std.mem.eql(u8, line_value, "[[demo:keypress_commit_path]]")) return .keypress_commit_path;
    if (std.mem.eql(u8, line_value, "[[demo:local_compute_capacity]]")) return .local_compute_capacity;
    if (std.mem.eql(u8, line_value, "[[demo:storage_sealed_objects]]")) return .storage_sealed_objects;
    if (std.mem.eql(u8, line_value, "[[demo:secure_boot_root]]")) return .secure_boot_root;
    if (std.mem.eql(u8, line_value, "[[demo:authority_flow]]")) return .authority_flow;
    return null;
}

fn demoHeight(directive: DemoDirective) f32 {
    return switch (directive) {
        .post_model => post_model_demo_h,
        .vpn_who_sees_what => vpn_demo_h,
        .tls_endpoint => tls_demo_h,
        .data_copy_map => data_copy_demo_h,
        .phone_identity_stack => identity_demo_h,
        .permission_ladder => permission_demo_h,
        .dns_lookup_path => dns_demo_h,
        .account_vs_key => account_demo_h,
        .server_pipeline => server_demo_h,
        .push_wake_path => push_demo_h,
        .dependency_graph => dependency_demo_h,
        .router_boundary => router_demo_h,
        .keypress_commit_path => keypress_demo_h,
        .local_compute_capacity => compute_demo_h,
        .storage_sealed_objects => storage_demo_h,
        .secure_boot_root => trust_demo_h,
        .authority_flow => authority_flow_demo_h,
    };
}

fn flowDemoDirective(scene: ?*ui.Scene, bounds: ui.Rect, post_index: usize, directive: DemoDirective, hover_x: f32, hover_y: f32) ui.RenderError!f32 {
    if (scene) |target| switch (directive) {
        .post_model => try renderPostModelDemo(target, bounds, post_index, hover_x, hover_y),
        .vpn_who_sees_what => try renderVpnWhoSeesWhatDemo(target, bounds, hover_x, hover_y),
        .tls_endpoint => try renderTlsEndpointDemo(target, bounds, hover_x, hover_y),
        .data_copy_map => try renderDataCopyMapDemo(target, bounds, hover_x, hover_y),
        .phone_identity_stack => try renderPhoneIdentityStackDemo(target, bounds, hover_x, hover_y),
        .permission_ladder => try renderPermissionLadderDemo(target, bounds, hover_x, hover_y),
        .dns_lookup_path => try renderDnsLookupPathDemo(target, bounds, hover_x, hover_y),
        .account_vs_key => try renderAccountVsKeyDemo(target, bounds, hover_x, hover_y),
        .server_pipeline => try renderServerPipelineDemo(target, bounds, hover_x, hover_y),
        .push_wake_path => try renderPushWakePathDemo(target, bounds, hover_x, hover_y),
        .dependency_graph => try renderDependencyGraphDemo(target, bounds, hover_x, hover_y),
        .router_boundary => try renderRouterBoundaryDemo(target, bounds, hover_x, hover_y),
        .keypress_commit_path => try renderKeypressCommitPathDemo(target, bounds, hover_x, hover_y),
        .local_compute_capacity => try renderLocalComputeCapacityDemo(target, bounds, hover_x, hover_y),
        .storage_sealed_objects => try renderStorageSealedObjectsDemo(target, bounds, hover_x, hover_y),
        .secure_boot_root => try renderSecureBootRootDemo(target, bounds, hover_x, hover_y),
        .authority_flow => try renderAuthorityFlowDemo(target, bounds, hover_x, hover_y),
    };
    return bounds.h;
}

const PostModelCard = enum {
    visible_action,
    authority_shift,
    user_owned_shape,
};

const AuthorityFlowStage = enum {
    app,
    allocator,
    host,
    relay,
    storage,
    tpm,
};

fn renderAuthorityFlowDemo(scene: *ui.Scene, bounds: ui.Rect, hover_x: f32, hover_y: f32) ui.RenderError!void {
    try demoFrame(scene, bounds);
    const inner = bounds.insetUniform(authority_flow_demo_pad);
    try tag(scene, ui.Rect.init(inner.x, inner.y, 152.0, 24.0), "AUTHORITY FLOW", palette.blue);
    try paragraph(scene, ui.Rect.init(inner.x + 176.0, inner.y + 2.0, @max(1.0, inner.w - 176.0), 48.0), "Follow one request without letting any participant become another participant.");

    const stages = [_]AuthorityFlowStage{ .app, .allocator, .host, .relay, .storage, .tpm };
    const column_count: usize = if (inner.w >= 620.0) 3 else 2;
    const row_count: usize = (authority_flow_stage_count + column_count - 1) / column_count;
    const stage_w = (inner.w - authority_flow_stage_gap * @as(f32, @floatFromInt(column_count - 1))) / @as(f32, @floatFromInt(column_count));
    const stages_y = inner.y + 76.0;
    var active: AuthorityFlowStage = .relay;

    for (stages, 0..) |stage, index| {
        const column = index % column_count;
        const row = index / column_count;
        const stage_bounds = ui.Rect.init(
            inner.x + @as(f32, @floatFromInt(column)) * (stage_w + authority_flow_stage_gap),
            stages_y + @as(f32, @floatFromInt(row)) * (authority_flow_stage_h + authority_flow_stage_gap),
            stage_w,
            authority_flow_stage_h,
        );
        const hovered = stage_bounds.containsInclusive(hover_x, hover_y);
        if (hovered) active = stage;
        try renderAuthorityFlowStage(scene, stage_bounds, stage, hovered);
    }

    const detail_y = stages_y + @as(f32, @floatFromInt(row_count)) * (authority_flow_stage_h + authority_flow_stage_gap) + 16.0;
    try renderAuthorityFlowDetail(scene, ui.Rect.init(inner.x, detail_y, inner.w, authority_flow_detail_h), active);
}

fn renderAuthorityFlowStage(scene: *ui.Scene, bounds: ui.Rect, stage: AuthorityFlowStage, hovered: bool) ui.RenderError!void {
    try fill(scene, bounds, authorityFlowStageColor(stage), 7.0);
    try scene.pushRect(bounds, if (hovered) palette.primary else palette.border, .border, 7.0, 0.0);
    try text(scene, bounds.x + 12.0, bounds.y + 11.0, bounds.w - 24.0, 14.0, authorityFlowStageTitle(stage), palette.text);
    try paragraph(scene, ui.Rect.init(bounds.x + 12.0, bounds.y + 32.0, bounds.w - 24.0, 24.0), authorityFlowStageBody(stage));
}

fn renderAuthorityFlowDetail(scene: *ui.Scene, bounds: ui.Rect, stage: AuthorityFlowStage) ui.RenderError!void {
    try fill(scene, bounds, ui.Color{ .r = 9, .g = 9, .b = 9, .a = 220 }, 6.0);
    try text(scene, bounds.x + 16.0, bounds.y + 14.0, 260.0, 14.0, authorityFlowStageTitle(stage), palette.primary);
    try paragraph(scene, ui.Rect.init(bounds.x + 16.0, bounds.y + 34.0, bounds.w - 32.0, 42.0), authorityFlowStageDetail(stage));
}

fn authorityFlowStageTitle(stage: AuthorityFlowStage) []const u8 {
    return switch (stage) {
        .app => "App",
        .allocator => "Allocator",
        .host => "Host",
        .relay => "Relay",
        .storage => "Storage",
        .tpm => "TPM",
    };
}

fn authorityFlowStageBody(stage: AuthorityFlowStage) []const u8 {
    return switch (stage) {
        .app => "owns memory and identity",
        .allocator => "approves resource movement",
        .host => "spawns from allocation",
        .relay => "forwards encrypted objects",
        .storage => "stores sealed objects",
        .tpm => "uses policy-bound keys",
    };
}

fn authorityFlowStageDetail(stage: AuthorityFlowStage) []const u8 {
    return switch (stage) {
        .app => "The app can ask and can encrypt, but it cannot become the reader, storage authority, TPM, parent, or child.",
        .allocator => "The allocator signs resource movement. A memory view names owner bytes, reader identity, allocator approval, and the exact grant receipt.",
        .host => "The host performs spawn and reclaim. Parent apps keep ledgers and handles, not direct child memory authority.",
        .relay => "The relay proves transit for a route. It can forward a sealed message, but it does not read or become either endpoint.",
        .storage => "Storage accepts canonical objects and stores encrypted bytes. App-private data stays sealed to the app policy.",
        .tpm => "The TPM role is explicit and TPM-backed. It seals, unseals, signs, or generates secret material only for admitted policy-bound callers.",
    };
}

fn authorityFlowStageColor(stage: AuthorityFlowStage) ui.Color {
    return switch (stage) {
        .app => ui.Color{ .r = 26, .g = 46, .b = 68, .a = 238 },
        .allocator => ui.Color{ .r = 57, .g = 42, .b = 22, .a = 238 },
        .host => ui.Color{ .r = 42, .g = 48, .b = 32, .a = 238 },
        .relay => ui.Color{ .r = 30, .g = 55, .b = 45, .a = 238 },
        .storage => ui.Color{ .r = 52, .g = 35, .b = 58, .a = 238 },
        .tpm => ui.Color{ .r = 65, .g = 32, .b = 32, .a = 238 },
    };
}

fn renderPostModelDemo(scene: *ui.Scene, bounds: ui.Rect, post_index: usize, hover_x: f32, hover_y: f32) ui.RenderError!void {
    const post = posts[post_index];
    try demoFrame(scene, bounds);
    const inner = bounds.insetUniform(post_model_demo_pad);
    try tag(scene, ui.Rect.init(inner.x, inner.y, 150.0, 24.0), "INTERACTIVE MODEL", palette.blue);
    try text(scene, inner.x, inner.y + 38.0, inner.w, 18.0, post.category, palette.text);
    try paragraph(scene, ui.Rect.init(inner.x + 184.0, inner.y + 2.0, @max(1.0, inner.w - 184.0), 54.0), post.demo);

    const card_w = (inner.w - post_model_card_gap * @as(f32, @floatFromInt(post_model_card_count - 1))) / @as(f32, @floatFromInt(post_model_card_count));
    const cards_y = inner.y + 86.0;
    var active: PostModelCard = .authority_shift;
    const cards = [_]PostModelCard{ .visible_action, .authority_shift, .user_owned_shape };
    for (cards, 0..) |card_kind, card_index| {
        const card_bounds = ui.Rect.init(
            inner.x + @as(f32, @floatFromInt(card_index)) * (card_w + post_model_card_gap),
            cards_y,
            card_w,
            post_model_card_h,
        );
        const hovered = card_bounds.containsInclusive(hover_x, hover_y);
        if (hovered) active = card_kind;
        try renderPostModelCard(scene, card_bounds, post, card_kind, hovered);
    }

    const detail_y = inner.y + inner.h - post_model_detail_h;
    try renderPostModelDetail(scene, ui.Rect.init(inner.x, detail_y, inner.w, post_model_detail_h), post, active);
}

fn renderPostModelCard(scene: *ui.Scene, bounds: ui.Rect, post: Post, card: PostModelCard, hovered: bool) ui.RenderError!void {
    try fill(scene, bounds, postModelCardColor(card), 7.0);
    try scene.pushRect(bounds, if (hovered) palette.primary else palette.border, .border, 7.0, 0.0);
    try text(scene, bounds.x + 14.0, bounds.y + 14.0, bounds.w - 28.0, 13.0, postModelCardTitle(card), palette.text);
    try paragraph(scene, ui.Rect.init(bounds.x + 14.0, bounds.y + 42.0, bounds.w - 28.0, 58.0), postModelCardBody(post, card));
    try alignedText(scene, bounds.x + 14.0, bounds.y + bounds.h - 22.0, bounds.w - 28.0, 10.0, postModelCardFooter(card), palette.primary, .center);
}

fn renderPostModelDetail(scene: *ui.Scene, bounds: ui.Rect, post: Post, card: PostModelCard) ui.RenderError!void {
    try fill(scene, bounds, ui.Color{ .r = 9, .g = 9, .b = 9, .a = 210 }, 6.0);
    try text(scene, bounds.x + 16.0, bounds.y + 14.0, 220.0, 14.0, postModelDetailTitle(card), palette.primary);
    try paragraph(scene, ui.Rect.init(bounds.x + 16.0, bounds.y + 34.0, bounds.w - 32.0, 34.0), postModelDetail(post, card));
}

fn postModelCardTitle(card: PostModelCard) []const u8 {
    return switch (card) {
        .visible_action => "Visible action",
        .authority_shift => "Authority shift",
        .user_owned_shape => "User-owned shape",
    };
}

fn postModelCardBody(post: Post, card: PostModelCard) []const u8 {
    return switch (card) {
        .visible_action => post.demo,
        .authority_shift => post.summary,
        .user_owned_shape => postModelArcShape(post.arc),
    };
}

fn postModelCardFooter(card: PostModelCard) []const u8 {
    return switch (card) {
        .visible_action => "what the user sees",
        .authority_shift => "who gets power",
        .user_owned_shape => "what changes",
    };
}

fn postModelDetailTitle(card: PostModelCard) []const u8 {
    return switch (card) {
        .visible_action => "Visible action",
        .authority_shift => "Authority shift",
        .user_owned_shape => "User-owned shape",
    };
}

fn postModelDetail(post: Post, card: PostModelCard) []const u8 {
    return switch (card) {
        .visible_action => "Start with the ordinary thing the reader recognizes. The model makes the hidden systems around that action visible enough to inspect.",
        .authority_shift => postModelArcRisk(post.arc),
        .user_owned_shape => postModelArcDetail(post.arc),
    };
}

fn postModelArcShape(arc: []const u8) []const u8 {
    if (std.mem.eql(u8, arc, arc_local)) return "Name the local component before sending work away.";
    if (std.mem.eql(u8, arc, arc_network)) return "Keep transport from becoming identity or ownership.";
    if (std.mem.eql(u8, arc, arc_device)) return "Move root authority back toward owner-held keys.";
    if (std.mem.eql(u8, arc, arc_control)) return "Make policy, ranking, updates, and access inspectable.";
    return "Turn hidden resource use into explicit receipts.";
}

fn postModelArcRisk(arc: []const u8) []const u8 {
    if (std.mem.eql(u8, arc, arc_local)) return "The risk is treating the device as magic. Once local components are invisible, cloud authority feels natural.";
    if (std.mem.eql(u8, arc, arc_network)) return "The risk is trusting the path as if it owned the user's intent. Networks carry objects; they should not become roots.";
    if (std.mem.eql(u8, arc, arc_device)) return "The risk is buying hardware but renting the keys, accounts, storage, identity, and recovery path.";
    if (std.mem.eql(u8, arc, arc_control)) return "The risk is letting platforms quietly define discovery, payments, updates, attention, terms, and legitimacy.";
    return "The risk is invisible cost: memory, storage, compute, dependencies, and bandwidth get spent without a local receipt.";
}

fn postModelArcDetail(arc: []const u8) []const u8 {
    if (std.mem.eql(u8, arc, arc_local)) return "The user should see which local component acts, what state it changes, and which boundary must approve the next step.";
    if (std.mem.eql(u8, arc, arc_network)) return "The better path is sealed objects, explicit routes, and minimal metadata: transport does work without owning meaning.";
    if (std.mem.eql(u8, arc, arc_device)) return "The better path is owner-held identity, portable storage, inspectable capabilities, and recovery that does not become platform ownership.";
    if (std.mem.eql(u8, arc, arc_control)) return "The better path is replaceable clients, visible rules, signed claims, local indexes, and appealable receipts.";
    return "The better path is preallocated resources, scoped children, explicit durable commits, and receipts for work performed.";
}

fn postModelCardColor(card: PostModelCard) ui.Color {
    return switch (card) {
        .visible_action => ui.Color{ .r = 24, .g = 55, .b = 44, .a = 238 },
        .authority_shift => ui.Color{ .r = 72, .g = 36, .b = 36, .a = 238 },
        .user_owned_shape => ui.Color{ .r = 26, .g = 36, .b = 52, .a = 238 },
    };
}

const VpnActorRole = enum {
    user,
    local_network,
    isp,
    vpn_provider,
    webapp,
    relay,
    recipient,
};

const VpnActor = struct {
    label: []const u8,
    role: VpnActorRole,
};

const VpnLane = struct {
    label: []const u8,
    detail: []const u8,
    actors: [vpn_demo_actor_count]VpnActor,
};

const vpn_lanes = [_]VpnLane{
    .{
        .label = "No VPN",
        .detail = "The ISP sees destinations and timing. The webapp sees your ISP-facing address.",
        .actors = .{
            .{ .label = "You", .role = .user },
            .{ .label = "Router", .role = .local_network },
            .{ .label = "ISP", .role = .isp },
            .{ .label = "Internet", .role = .relay },
            .{ .label = "Webapp", .role = .webapp },
        },
    },
    .{
        .label = "Commercial VPN",
        .detail = "The ISP sees a tunnel. The VPN provider now sees concentrated destination metadata.",
        .actors = .{
            .{ .label = "You", .role = .user },
            .{ .label = "Router", .role = .local_network },
            .{ .label = "ISP", .role = .isp },
            .{ .label = "VPN Co.", .role = .vpn_provider },
            .{ .label = "Webapp", .role = .webapp },
        },
    },
    .{
        .label = "Sealed relay",
        .detail = "Relays move sealed objects. They should not need content, account identity, or plaintext.",
        .actors = .{
            .{ .label = "You", .role = .user },
            .{ .label = "Route", .role = .local_network },
            .{ .label = "Relay", .role = .relay },
            .{ .label = "Relay", .role = .relay },
            .{ .label = "Friend", .role = .recipient },
        },
    },
};

fn renderVpnWhoSeesWhatDemo(scene: *ui.Scene, bounds: ui.Rect, hover_x: f32, hover_y: f32) ui.RenderError!void {
    try demoFrame(scene, bounds);
    const inner = bounds.insetUniform(vpn_demo_pad);
    try tag(scene, ui.Rect.init(inner.x, inner.y, 126.0, 24.0), "NATIVE DEMO", palette.blue);
    try text(scene, inner.x, inner.y + 38.0, inner.w, 18.0, "Who sees what?", palette.text);
    try paragraph(scene, ui.Rect.init(inner.x + 160.0, inner.y + 2.0, @max(1.0, inner.w - 160.0), 54.0), "A VPN changes which middleman sees metadata. It does not make trust disappear.");

    var hovered: ?VpnActorRole = null;
    const lanes_top = inner.y + vpn_demo_header_h;
    for (vpn_lanes, 0..) |lane, lane_index| {
        const lane_y = lanes_top + @as(f32, @floatFromInt(lane_index)) * (vpn_demo_lane_h + vpn_demo_lane_gap);
        const lane_bounds = ui.Rect.init(inner.x, lane_y, inner.w, vpn_demo_lane_h);
        if (try renderVpnLane(scene, lane_bounds, lane, hover_x, hover_y)) |role| hovered = role;
    }

    const detail_y = lanes_top + @as(f32, @floatFromInt(vpn_demo_lane_count)) * (vpn_demo_lane_h + vpn_demo_lane_gap) + 4.0;
    try renderVpnDetail(scene, ui.Rect.init(inner.x, detail_y, inner.w, vpn_demo_detail_h), hovered);
}

fn renderVpnLane(scene: *ui.Scene, bounds: ui.Rect, lane: VpnLane, hover_x: f32, hover_y: f32) ui.RenderError!?VpnActorRole {
    try fill(scene, bounds, palette.neutral_soft, 6.0);
    try text(scene, bounds.x + 14.0, bounds.y + 13.0, 122.0, 14.0, lane.label, palette.text);
    try paragraph(scene, ui.Rect.init(bounds.x + 14.0, bounds.y + 35.0, 134.0, 38.0), lane.detail);

    const actor_area_x = bounds.x + 166.0;
    const actor_area_w = @max(1.0, bounds.w - 180.0);
    const actor_w = (actor_area_w - vpn_demo_actor_gap * @as(f32, @floatFromInt(vpn_demo_actor_count - 1))) / @as(f32, @floatFromInt(vpn_demo_actor_count));
    const actor_y = bounds.y + (bounds.h - vpn_demo_actor_h) * 0.5;
    var hovered: ?VpnActorRole = null;
    for (lane.actors, 0..) |actor, index| {
        const actor_x = actor_area_x + @as(f32, @floatFromInt(index)) * (actor_w + vpn_demo_actor_gap);
        const actor_bounds = ui.Rect.init(actor_x, actor_y, actor_w, vpn_demo_actor_h);
        const is_hovered = actor_bounds.containsInclusive(hover_x, hover_y);
        if (is_hovered) hovered = actor.role;
        try renderVpnActor(scene, actor_bounds, actor, is_hovered);
        if (index + 1 < vpn_demo_actor_count) {
            const arrow_x = actor_bounds.x + actor_bounds.w + 2.0;
            const arrow_y = actor_bounds.y + actor_bounds.h * 0.5 - vpn_demo_arrow_h * 0.5;
            try fill(scene, ui.Rect.init(arrow_x, arrow_y, vpn_demo_actor_gap - 4.0, vpn_demo_arrow_h), palette.border, 0.0);
        }
    }
    return hovered;
}

fn renderVpnActor(scene: *ui.Scene, bounds: ui.Rect, actor: VpnActor, hovered: bool) ui.RenderError!void {
    const fill_color = vpnActorColor(actor.role);
    try fill(scene, bounds, fill_color, vpn_demo_actor_radius);
    try scene.pushRect(bounds, if (hovered) palette.primary else palette.border, .border, vpn_demo_actor_radius, 0.0);
    try alignedText(scene, bounds.x + 8.0, bounds.y + 10.0, bounds.w - 16.0, 12.0, actor.label, palette.text, .center);
    try alignedText(scene, bounds.x + 8.0, bounds.y + 29.0, bounds.w - 16.0, 10.0, vpnActorExposure(actor.role), palette.dim, .center);
}

fn renderVpnDetail(scene: *ui.Scene, bounds: ui.Rect, hovered: ?VpnActorRole) ui.RenderError!void {
    try fill(scene, bounds, ui.Color{ .r = 9, .g = 9, .b = 9, .a = 210 }, 6.0);
    const role = hovered orelse .vpn_provider;
    try text(scene, bounds.x + 16.0, bounds.y + 14.0, 160.0, 14.0, vpnActorDetailTitle(role), palette.primary);
    try paragraph(scene, ui.Rect.init(bounds.x + 16.0, bounds.y + 34.0, bounds.w - 32.0, 28.0), vpnActorDetail(role));
}

fn vpnActorColor(role: VpnActorRole) ui.Color {
    return switch (role) {
        .user, .recipient => ui.Color{ .r = 24, .g = 55, .b = 44, .a = 238 },
        .local_network, .relay => ui.Color{ .r = 26, .g = 36, .b = 52, .a = 238 },
        .isp => ui.Color{ .r = 56, .g = 42, .b = 24, .a = 238 },
        .vpn_provider => ui.Color{ .r = 72, .g = 36, .b = 36, .a = 238 },
        .webapp => ui.Color{ .r = 44, .g = 44, .b = 44, .a = 238 },
    };
}

fn vpnActorExposure(role: VpnActorRole) []const u8 {
    return switch (role) {
        .user => "source",
        .local_network => "local path",
        .isp => "route + time",
        .vpn_provider => "new middleman",
        .webapp => "account + IP",
        .relay => "sealed route",
        .recipient => "decrypts",
    };
}

fn vpnActorDetailTitle(role: VpnActorRole) []const u8 {
    return switch (role) {
        .user => "User device",
        .local_network => "Local network",
        .isp => "ISP",
        .vpn_provider => "VPN provider",
        .webapp => "Webapp",
        .relay => "Relay",
        .recipient => "Recipient",
    };
}

fn vpnActorDetail(role: VpnActorRole) []const u8 {
    return switch (role) {
        .user => "The safest data is data that never leaves the device. Local intent should decide what gets sent.",
        .local_network => "Wi-Fi and routers see local traffic shape unless another layer hides it. They are transport, not identity.",
        .isp => "The ISP may lose final destination detail with a VPN, but it still sees the VPN endpoint and timing.",
        .vpn_provider => "The commercial VPN becomes the concentrated metadata observer. Trust moved; it did not vanish.",
        .webapp => "The service still sees account behavior, cookies, fingerprinting signals, and whatever plaintext reaches it.",
        .relay => "A good relay carries sealed objects and minimal routing data. It should not need content or account identity.",
        .recipient => "Only the intended recipient should decrypt message content. Transport should not become authority.",
    };
}

const TlsActorRole = enum {
    device,
    network,
    tls_endpoint,
    server,
    database,
};

const TlsActor = struct {
    label: []const u8,
    exposure: []const u8,
    role: TlsActorRole,
};

const tls_actors = [_]TlsActor{
    .{ .label = "Device", .exposure = "plaintext before send", .role = .device },
    .{ .label = "Network", .exposure = "encrypted tunnel", .role = .network },
    .{ .label = "TLS endpoint", .exposure = "decrypts here", .role = .tls_endpoint },
    .{ .label = "App server", .exposure = "policy + logs", .role = .server },
    .{ .label = "Database", .exposure = "stored memory", .role = .database },
};

fn renderTlsEndpointDemo(scene: *ui.Scene, bounds: ui.Rect, hover_x: f32, hover_y: f32) ui.RenderError!void {
    try demoFrame(scene, bounds);
    const inner = bounds.insetUniform(tls_demo_pad);
    try tag(scene, ui.Rect.init(inner.x, inner.y, 120.0, 24.0), "TLS DEMO", palette.blue);
    try text(scene, inner.x, inner.y + 38.0, inner.w, 18.0, "The tunnel ends at the endpoint.", palette.text);
    try paragraph(scene, ui.Rect.init(inner.x + 152.0, inner.y + 2.0, @max(1.0, inner.w - 152.0), 54.0), "TLS protects the trip. After termination, server systems can handle plaintext unless the object stays sealed.");

    const actor_area_w = inner.w;
    const actor_w = (actor_area_w - tls_demo_actor_gap * @as(f32, @floatFromInt(tls_demo_actor_count - 1))) / @as(f32, @floatFromInt(tls_demo_actor_count));
    var hovered: ?TlsActorRole = null;
    for (tls_actors, 0..) |actor, index| {
        const x = inner.x + @as(f32, @floatFromInt(index)) * (actor_w + tls_demo_actor_gap);
        const actor_bounds = ui.Rect.init(x, inner.y + tls_demo_path_y, actor_w, tls_demo_actor_h);
        const is_hovered = actor_bounds.containsInclusive(hover_x, hover_y);
        if (is_hovered) hovered = actor.role;
        try renderTlsActor(scene, actor_bounds, actor, is_hovered);
        if (index + 1 < tls_demo_actor_count) {
            const line_color = if (index == 0) palette.primary else palette.border;
            try fill(scene, ui.Rect.init(actor_bounds.x + actor_bounds.w + 3.0, actor_bounds.y + 20.0, tls_demo_actor_gap - 6.0, 2.0), line_color, 0.0);
        }
    }

    const tunnel = ui.Rect.init(inner.x + actor_w + tls_demo_actor_gap * 0.5, inner.y + tls_demo_path_y + tls_demo_actor_h + 18.0, actor_w * 2.0 + tls_demo_actor_gap, 28.0);
    try fill(scene, tunnel, ui.Color{ .r = 20, .g = 60, .b = 42, .a = 190 }, 5.0);
    try alignedText(scene, tunnel.x + 10.0, tunnel.y + 8.0, tunnel.w - 20.0, 10.0, "encrypted in transit", palette.primary, .center);
    const plaintext = ui.Rect.init(tunnel.x + tunnel.w + tls_demo_actor_gap, tunnel.y, actor_w * 2.0 + tls_demo_actor_gap, 28.0);
    try fill(scene, plaintext, ui.Color{ .r = 68, .g = 36, .b = 36, .a = 190 }, 5.0);
    try alignedText(scene, plaintext.x + 10.0, plaintext.y + 8.0, plaintext.w - 20.0, 10.0, "plaintext after endpoint", palette.text, .center);

    const detail_y = inner.y + tls_demo_path_y + tls_demo_actor_h + 62.0;
    try renderTlsDetail(scene, ui.Rect.init(inner.x, detail_y, inner.w, tls_demo_detail_h), hovered);
}

fn renderTlsActor(scene: *ui.Scene, bounds: ui.Rect, actor: TlsActor, hovered: bool) ui.RenderError!void {
    try fill(scene, bounds, tlsActorColor(actor.role), 6.0);
    try scene.pushRect(bounds, if (hovered) palette.primary else palette.border, .border, 6.0, 0.0);
    try alignedText(scene, bounds.x + 8.0, bounds.y + 11.0, bounds.w - 16.0, 12.0, actor.label, palette.text, .center);
    try alignedText(scene, bounds.x + 8.0, bounds.y + 33.0, bounds.w - 16.0, 10.0, actor.exposure, palette.dim, .center);
}

fn renderTlsDetail(scene: *ui.Scene, bounds: ui.Rect, hovered: ?TlsActorRole) ui.RenderError!void {
    try fill(scene, bounds, ui.Color{ .r = 9, .g = 9, .b = 9, .a = 210 }, 6.0);
    const role = hovered orelse .tls_endpoint;
    try text(scene, bounds.x + 16.0, bounds.y + 14.0, 180.0, 14.0, tlsDetailTitle(role), palette.primary);
    try paragraph(scene, ui.Rect.init(bounds.x + 16.0, bounds.y + 34.0, bounds.w - 32.0, 30.0), tlsDetail(role));
}

fn tlsActorColor(role: TlsActorRole) ui.Color {
    return switch (role) {
        .device => ui.Color{ .r = 24, .g = 55, .b = 44, .a = 238 },
        .network => ui.Color{ .r = 26, .g = 36, .b = 52, .a = 238 },
        .tls_endpoint => ui.Color{ .r = 70, .g = 52, .b = 25, .a = 238 },
        .server => ui.Color{ .r = 72, .g = 36, .b = 36, .a = 238 },
        .database => ui.Color{ .r = 44, .g = 44, .b = 44, .a = 238 },
    };
}

fn tlsDetailTitle(role: TlsActorRole) []const u8 {
    return switch (role) {
        .device => "Before TLS",
        .network => "Network path",
        .tls_endpoint => "TLS endpoint",
        .server => "Server systems",
        .database => "Stored data",
    };
}

fn tlsDetail(role: TlsActorRole) []const u8 {
    return switch (role) {
        .device => "The device holds plaintext before it enters the tunnel. Local malware or bad UI can still betray the user.",
        .network => "The network should see an encrypted connection, timing, and endpoints, not page content.",
        .tls_endpoint => "TLS terminates here. After decryption, connection security has finished its job.",
        .server => "Application code can log, queue, inspect, moderate, or forward plaintext after TLS termination.",
        .database => "If plaintext is stored here, deletion, access, breach, and export become service policy questions.",
    };
}

const DataCopyRole = enum {
    phone,
    app_storage,
    sync,
    database,
    backup,
    search,
    logs,
    analytics,
};

const DataCopyNode = struct {
    label: []const u8,
    exposure: []const u8,
    role: DataCopyRole,
};

const data_copy_nodes = [_]DataCopyNode{
    .{ .label = "Phone UI", .exposure = "visible copy", .role = .phone },
    .{ .label = "App storage", .exposure = "local cache", .role = .app_storage },
    .{ .label = "Cloud sync", .exposure = "replica", .role = .sync },
    .{ .label = "Database", .exposure = "source of truth", .role = .database },
    .{ .label = "Backups", .exposure = "old state", .role = .backup },
    .{ .label = "Search index", .exposure = "derived text", .role = .search },
    .{ .label = "Logs", .exposure = "metadata", .role = .logs },
    .{ .label = "Analytics", .exposure = "behavior", .role = .analytics },
};

fn renderDataCopyMapDemo(scene: *ui.Scene, bounds: ui.Rect, hover_x: f32, hover_y: f32) ui.RenderError!void {
    try demoFrame(scene, bounds);
    const inner = bounds.insetUniform(data_copy_demo_pad);
    try tag(scene, ui.Rect.init(inner.x, inner.y, 128.0, 24.0), "COPY MAP", palette.blue);
    try text(scene, inner.x, inner.y + 38.0, inner.w, 18.0, "Deleting the UI copy is not deleting every copy.", palette.text);
    try paragraph(scene, ui.Rect.init(inner.x + 162.0, inner.y + 2.0, @max(1.0, inner.w - 162.0), 54.0), "One note, photo, or message can become storage, sync, backup, search, log, and analytics records.");

    const map_top = inner.y + 88.0;
    const row_w = data_copy_node_w * 4.0 + data_copy_row_gap * 3.0;
    const start_x = inner.x + @max(0.0, (inner.w - row_w) * 0.5);
    var hovered: ?DataCopyRole = null;
    for (data_copy_nodes, 0..) |node, index| {
        const row = index / 4;
        const col = index % 4;
        const node_bounds = ui.Rect.init(
            start_x + @as(f32, @floatFromInt(col)) * (data_copy_node_w + data_copy_row_gap),
            map_top + @as(f32, @floatFromInt(row)) * (data_copy_node_h + 46.0),
            data_copy_node_w,
            data_copy_node_h,
        );
        const is_hovered = node_bounds.containsInclusive(hover_x, hover_y);
        if (is_hovered) hovered = node.role;
        try renderDataCopyNode(scene, node_bounds, node, is_hovered);
        if (index > 0) try renderDataCopyLink(scene, node_bounds);
    }

    const warning = ui.Rect.init(start_x, map_top + data_copy_node_h + 16.0, row_w, 24.0);
    try fill(scene, warning, ui.Color{ .r = 66, .g = 45, .b = 26, .a = 190 }, 5.0);
    try alignedText(scene, warning.x + 10.0, warning.y + 7.0, warning.w - 20.0, 10.0, "Delete in app UI usually removes one reference first.", palette.text, .center);

    const detail_y = inner.y + inner.h - data_copy_detail_h;
    try renderDataCopyDetail(scene, ui.Rect.init(inner.x, detail_y, inner.w, data_copy_detail_h), hovered);
}

fn renderDataCopyNode(scene: *ui.Scene, bounds: ui.Rect, node: DataCopyNode, hovered: bool) ui.RenderError!void {
    try fill(scene, bounds, dataCopyColor(node.role), 6.0);
    try scene.pushRect(bounds, if (hovered) palette.primary else palette.border, .border, 6.0, 0.0);
    try alignedText(scene, bounds.x + 8.0, bounds.y + 10.0, bounds.w - 16.0, 12.0, node.label, palette.text, .center);
    try alignedText(scene, bounds.x + 8.0, bounds.y + 31.0, bounds.w - 16.0, 10.0, node.exposure, palette.dim, .center);
}

fn renderDataCopyLink(scene: *ui.Scene, bounds: ui.Rect) ui.RenderError!void {
    const line_y = bounds.y + bounds.h * 0.5;
    try fill(scene, ui.Rect.init(bounds.x - data_copy_row_gap + 4.0, line_y, data_copy_row_gap - 8.0, 2.0), palette.border, 0.0);
}

fn renderDataCopyDetail(scene: *ui.Scene, bounds: ui.Rect, hovered: ?DataCopyRole) ui.RenderError!void {
    try fill(scene, bounds, ui.Color{ .r = 9, .g = 9, .b = 9, .a = 210 }, 6.0);
    const role = hovered orelse .database;
    try text(scene, bounds.x + 16.0, bounds.y + 14.0, 190.0, 14.0, dataCopyTitle(role), palette.primary);
    try paragraph(scene, ui.Rect.init(bounds.x + 16.0, bounds.y + 34.0, bounds.w - 32.0, 30.0), dataCopyDetail(role));
}

fn dataCopyColor(role: DataCopyRole) ui.Color {
    return switch (role) {
        .phone, .app_storage => ui.Color{ .r = 24, .g = 55, .b = 44, .a = 238 },
        .sync, .database => ui.Color{ .r = 26, .g = 36, .b = 52, .a = 238 },
        .backup, .search => ui.Color{ .r = 56, .g = 42, .b = 24, .a = 238 },
        .logs, .analytics => ui.Color{ .r = 72, .g = 36, .b = 36, .a = 238 },
    };
}

fn dataCopyTitle(role: DataCopyRole) []const u8 {
    return switch (role) {
        .phone => "Phone UI",
        .app_storage => "App storage",
        .sync => "Cloud sync",
        .database => "Database",
        .backup => "Backups",
        .search => "Search index",
        .logs => "Logs",
        .analytics => "Analytics",
    };
}

fn dataCopyDetail(role: DataCopyRole) []const u8 {
    return switch (role) {
        .phone => "The phone may only show a cached or filtered view. The visible copy is not always the source of truth.",
        .app_storage => "Local app storage can hold drafts, caches, thumbnails, databases, and decrypted temporary state.",
        .sync => "Sync creates another copy and conflict policy. It can help backup, but it can also become ownership.",
        .database => "The service database often decides reality: access, deletion, export, search, and account lockout.",
        .backup => "Backups can preserve old state after a visible delete. Retention is policy, not a UI gesture.",
        .search => "Search indexes keep derived text or metadata so the system can find data quickly later.",
        .logs => "Logs may retain timestamps, identifiers, errors, and routing metadata long after content changes.",
        .analytics => "Analytics turns user behavior into another dataset with different retention and access rules.",
    };
}

const IdentitySignalRole = enum {
    person,
    device_unlock,
    carrier,
    platform,
    app_account,
    payment,
    behavior,
};

const IdentitySignal = struct {
    label: []const u8,
    owner: []const u8,
    role: IdentitySignalRole,
};

const identity_signals = [_]IdentitySignal{
    .{ .label = "Person", .owner = "human", .role = .person },
    .{ .label = "PIN / biometric", .owner = "device vendor path", .role = .device_unlock },
    .{ .label = "SIM / number", .owner = "carrier", .role = .carrier },
    .{ .label = "Apple / Google", .owner = "platform account", .role = .platform },
    .{ .label = "App login", .owner = "service policy", .role = .app_account },
    .{ .label = "Payment card", .owner = "bank network", .role = .payment },
    .{ .label = "Location pattern", .owner = "behavior model", .role = .behavior },
};

fn renderPhoneIdentityStackDemo(scene: *ui.Scene, bounds: ui.Rect, hover_x: f32, hover_y: f32) ui.RenderError!void {
    try demoFrame(scene, bounds);
    const inner = bounds.insetUniform(identity_demo_pad);
    try tag(scene, ui.Rect.init(inner.x, inner.y, 142.0, 24.0), "IDENTITY STACK", palette.blue);
    try text(scene, inner.x, inner.y + 38.0, inner.w, 18.0, "Your phone correlates signals. It does not own you.", palette.text);
    try paragraph(scene, ui.Rect.init(inner.x + 176.0, inner.y + 2.0, @max(1.0, inner.w - 176.0), 54.0), "A service may combine local unlock, carrier identity, platform accounts, payment rails, and behavior.");

    const stack_x = inner.x;
    const stack_top = inner.y + 86.0;
    const service_x = inner.x + identity_signal_w + 72.0;
    const service_w = @max(1.0, inner.w - identity_signal_w - 72.0);
    var hovered: ?IdentitySignalRole = null;
    for (identity_signals, 0..) |signal, index| {
        const signal_y = stack_top + @as(f32, @floatFromInt(index)) * (identity_signal_h + identity_signal_gap);
        const signal_bounds = ui.Rect.init(stack_x, signal_y, identity_signal_w, identity_signal_h);
        const is_hovered = signal_bounds.containsInclusive(hover_x, hover_y);
        if (is_hovered) hovered = signal.role;
        try renderIdentitySignal(scene, signal_bounds, signal, is_hovered);
        const route_y = signal_bounds.y + signal_bounds.h * 0.5;
        try fill(scene, ui.Rect.init(signal_bounds.x + signal_bounds.w + 8.0, route_y, 46.0, 2.0), palette.border, 0.0);
    }

    const service_bounds = ui.Rect.init(service_x, stack_top + 30.0, service_w, 180.0);
    try fill(scene, service_bounds, ui.Color{ .r = 55, .g = 38, .b = 50, .a = 230 }, 8.0);
    try scene.pushRect(service_bounds, palette.border, .border, 8.0, 0.0);
    try text(scene, service_bounds.x + 22.0, service_bounds.y + 22.0, service_bounds.w - 44.0, 16.0, "Service decides: accepted or rejected", palette.text);
    try paragraph(scene, ui.Rect.init(service_bounds.x + 22.0, service_bounds.y + 58.0, service_bounds.w - 44.0, 72.0), "The same person can be rejected when one correlation signal fails: lost number, locked platform account, failed attestation, or changed behavior.");
    try fill(scene, ui.Rect.init(service_bounds.x + 22.0, service_bounds.y + 144.0, service_bounds.w - 44.0, 1.0), palette.border, 0.0);
    try alignedText(scene, service_bounds.x + 22.0, service_bounds.y + 154.0, service_bounds.w - 44.0, 12.0, "Correlation is not ownership.", palette.primary, .center);

    const detail_y = inner.y + inner.h - identity_detail_h;
    try renderIdentityDetail(scene, ui.Rect.init(inner.x, detail_y, inner.w, identity_detail_h), hovered);
}

fn renderIdentitySignal(scene: *ui.Scene, bounds: ui.Rect, signal: IdentitySignal, hovered: bool) ui.RenderError!void {
    try fill(scene, bounds, identitySignalColor(signal.role), 6.0);
    try scene.pushRect(bounds, if (hovered) palette.primary else palette.border, .border, 6.0, 0.0);
    try text(scene, bounds.x + 12.0, bounds.y + 8.0, bounds.w - 24.0, 12.0, signal.label, palette.text);
    try text(scene, bounds.x + 12.0, bounds.y + 25.0, bounds.w - 24.0, 10.0, signal.owner, palette.dim);
}

fn renderIdentityDetail(scene: *ui.Scene, bounds: ui.Rect, hovered: ?IdentitySignalRole) ui.RenderError!void {
    try fill(scene, bounds, ui.Color{ .r = 9, .g = 9, .b = 9, .a = 210 }, 6.0);
    const role = hovered orelse .platform;
    try text(scene, bounds.x + 16.0, bounds.y + 14.0, 190.0, 14.0, identityDetailTitle(role), palette.primary);
    try paragraph(scene, ui.Rect.init(bounds.x + 16.0, bounds.y + 34.0, bounds.w - 32.0, 32.0), identityDetail(role));
}

fn identitySignalColor(role: IdentitySignalRole) ui.Color {
    return switch (role) {
        .person => ui.Color{ .r = 24, .g = 55, .b = 44, .a = 238 },
        .device_unlock => ui.Color{ .r = 26, .g = 36, .b = 52, .a = 238 },
        .carrier => ui.Color{ .r = 56, .g = 42, .b = 24, .a = 238 },
        .platform => ui.Color{ .r = 72, .g = 36, .b = 36, .a = 238 },
        .app_account => ui.Color{ .r = 55, .g = 38, .b = 50, .a = 238 },
        .payment => ui.Color{ .r = 44, .g = 44, .b = 44, .a = 238 },
        .behavior => ui.Color{ .r = 38, .g = 48, .b = 44, .a = 238 },
    };
}

fn identityDetailTitle(role: IdentitySignalRole) []const u8 {
    return switch (role) {
        .person => "Person",
        .device_unlock => "Device unlock",
        .carrier => "Carrier signal",
        .platform => "Platform account",
        .app_account => "App account",
        .payment => "Payment signal",
        .behavior => "Behavior model",
    };
}

fn identityDetail(role: IdentitySignalRole) []const u8 {
    return switch (role) {
        .person => "The human is the subject. The stack should serve them, not replace them with a vendor-controlled record.",
        .device_unlock => "PINs and biometrics unlock the device, but the trusted path is still controlled by device software.",
        .carrier => "Phone numbers are carrier records. Losing a SIM or eSIM can break account recovery even when the person is unchanged.",
        .platform => "Apple and Google accounts often become identity roots because apps outsource trust to platform services.",
        .app_account => "A service account is permission inside one system. Suspension can erase reachability without erasing the person.",
        .payment => "Cards and banks add strong signals, but they also add risk policy, fraud scoring, and regional rules.",
        .behavior => "Location and behavior patterns can correlate identity silently, even when the user never intended to present proof.",
    };
}

const PermissionStepRole = enum {
    hardware,
    bootloader,
    os_vendor,
    app_store,
    app_permission,
};

const PermissionStep = struct {
    label: []const u8,
    blocks: []const u8,
    role: PermissionStepRole,
};

const permission_steps = [_]PermissionStep{
    .{ .label = "Hardware you bought", .blocks = "physical capability", .role = .hardware },
    .{ .label = "Bootloader", .blocks = "replace OS", .role = .bootloader },
    .{ .label = "OS vendor", .blocks = "background, files, sensors", .role = .os_vendor },
    .{ .label = "App store", .blocks = "install and update", .role = .app_store },
    .{ .label = "App permissions", .blocks = "camera, NFC, routes", .role = .app_permission },
};

fn renderPermissionLadderDemo(scene: *ui.Scene, bounds: ui.Rect, hover_x: f32, hover_y: f32) ui.RenderError!void {
    try demoFrame(scene, bounds);
    const inner = bounds.insetUniform(permission_demo_pad);
    try tag(scene, ui.Rect.init(inner.x, inner.y, 154.0, 24.0), "PERMISSION LADDER", palette.blue);
    try text(scene, inner.x, inner.y + 38.0, inner.w, 18.0, "Powerful hardware, gated authority.", palette.text);
    try paragraph(scene, ui.Rect.init(inner.x + 188.0, inner.y + 2.0, @max(1.0, inner.w - 188.0), 54.0), "The device can do the work. The question is which rung can say no to the owner.");

    const ladder_x = inner.x;
    const ladder_top = inner.y + 84.0;
    const step_w = @min(430.0, inner.w * 0.55);
    var hovered: ?PermissionStepRole = null;
    for (permission_steps, 0..) |step, index| {
        const step_y = ladder_top + @as(f32, @floatFromInt(index)) * (permission_step_h + permission_step_gap);
        const step_bounds = ui.Rect.init(ladder_x, step_y, step_w, permission_step_h);
        const is_hovered = step_bounds.containsInclusive(hover_x, hover_y);
        if (is_hovered) hovered = step.role;
        try renderPermissionStep(scene, step_bounds, step, is_hovered);
        if (index + 1 < permission_step_count) {
            try fill(scene, ui.Rect.init(step_bounds.x + 22.0, step_bounds.y + step_bounds.h, 2.0, permission_step_gap), palette.border, 0.0);
        }
    }

    const task_bounds = ui.Rect.init(ladder_x + step_w + 34.0, ladder_top + 28.0, @max(1.0, inner.w - step_w - 34.0), 160.0);
    try fill(scene, task_bounds, ui.Color{ .r = 38, .g = 42, .b = 48, .a = 230 }, 8.0);
    try scene.pushRect(task_bounds, palette.border, .border, 8.0, 0.0);
    try text(scene, task_bounds.x + 20.0, task_bounds.y + 20.0, task_bounds.w - 40.0, 16.0, "Try a normal owner task", palette.text);
    try paragraph(scene, ui.Rect.init(task_bounds.x + 20.0, task_bounds.y + 56.0, task_bounds.w - 40.0, 54.0), "Replace the OS, repair a camera, use NFC, install a local runtime, or run background sync.");
    try alignedText(scene, task_bounds.x + 20.0, task_bounds.y + 124.0, task_bounds.w - 40.0, 12.0, "Any rung can block it.", palette.primary, .center);

    const detail_y = inner.y + inner.h - permission_detail_h;
    try renderPermissionDetail(scene, ui.Rect.init(inner.x, detail_y, inner.w, permission_detail_h), hovered);
}

fn renderPermissionStep(scene: *ui.Scene, bounds: ui.Rect, step: PermissionStep, hovered: bool) ui.RenderError!void {
    try fill(scene, bounds, permissionStepColor(step.role), 6.0);
    try scene.pushRect(bounds, if (hovered) palette.primary else palette.border, .border, 6.0, 0.0);
    try text(scene, bounds.x + 14.0, bounds.y + 9.0, bounds.w - 28.0, 12.0, step.label, palette.text);
    try text(scene, bounds.x + 14.0, bounds.y + 28.0, bounds.w - 28.0, 10.0, step.blocks, palette.dim);
}

fn renderPermissionDetail(scene: *ui.Scene, bounds: ui.Rect, hovered: ?PermissionStepRole) ui.RenderError!void {
    try fill(scene, bounds, ui.Color{ .r = 9, .g = 9, .b = 9, .a = 210 }, 6.0);
    const role = hovered orelse .bootloader;
    try text(scene, bounds.x + 16.0, bounds.y + 14.0, 190.0, 14.0, permissionDetailTitle(role), palette.primary);
    try paragraph(scene, ui.Rect.init(bounds.x + 16.0, bounds.y + 34.0, bounds.w - 32.0, 32.0), permissionDetail(role));
}

fn permissionStepColor(role: PermissionStepRole) ui.Color {
    return switch (role) {
        .hardware => ui.Color{ .r = 24, .g = 55, .b = 44, .a = 238 },
        .bootloader => ui.Color{ .r = 56, .g = 42, .b = 24, .a = 238 },
        .os_vendor => ui.Color{ .r = 26, .g = 36, .b = 52, .a = 238 },
        .app_store => ui.Color{ .r = 72, .g = 36, .b = 36, .a = 238 },
        .app_permission => ui.Color{ .r = 44, .g = 44, .b = 44, .a = 238 },
    };
}

fn permissionDetailTitle(role: PermissionStepRole) []const u8 {
    return switch (role) {
        .hardware => "Hardware",
        .bootloader => "Bootloader",
        .os_vendor => "OS vendor",
        .app_store => "App store",
        .app_permission => "App permissions",
    };
}

fn permissionDetail(role: PermissionStepRole) []const u8 {
    return switch (role) {
        .hardware => "The chip can run code, store data, draw UI, and use radios. Possession does not mean authority.",
        .bootloader => "A locked bootloader can prevent owner-maintained software after vendor support ends.",
        .os_vendor => "The OS vendor controls background work, files, APIs, signing policy, and hardware access.",
        .app_store => "Store review controls distribution, updates, payments, region access, and allowed business models.",
        .app_permission => "App prompts can protect users, but broad grants still hand apps more authority than one task needs.",
    };
}

const DnsStepRole = enum {
    name,
    resolver,
    root,
    registry,
    authoritative,
};

const DnsStep = struct {
    label: []const u8,
    risk: []const u8,
    role: DnsStepRole,
};

const dns_steps = [_]DnsStep{
    .{ .label = "friend.example", .risk = "friendly label", .role = .name },
    .{ .label = "Resolver", .risk = "cache or filter", .role = .resolver },
    .{ .label = "Root", .risk = "delegation", .role = .root },
    .{ .label = "TLD / registrar", .risk = "ownership policy", .role = .registry },
    .{ .label = "Authoritative", .risk = "current address", .role = .authoritative },
};

fn renderDnsLookupPathDemo(scene: *ui.Scene, bounds: ui.Rect, hover_x: f32, hover_y: f32) ui.RenderError!void {
    try demoFrame(scene, bounds);
    const inner = bounds.insetUniform(dns_demo_pad);
    try tag(scene, ui.Rect.init(inner.x, inner.y, 118.0, 24.0), "DNS PATH", palette.blue);
    try text(scene, inner.x, inner.y + 38.0, inner.w, 18.0, "A name is a lookup, not an identity.", palette.text);
    try paragraph(scene, ui.Rect.init(inner.x + 150.0, inner.y + 2.0, @max(1.0, inner.w - 150.0), 54.0), "A friendly name becomes an address through resolvers, caches, registries, and authoritative records.");

    const path_top = inner.y + 92.0;
    const step_w = (inner.w - dns_step_gap * @as(f32, @floatFromInt(dns_step_count - 1))) / @as(f32, @floatFromInt(dns_step_count));
    var hovered: ?DnsStepRole = null;
    for (dns_steps, 0..) |step, index| {
        const step_bounds = ui.Rect.init(inner.x + @as(f32, @floatFromInt(index)) * (step_w + dns_step_gap), path_top, step_w, dns_step_h);
        const is_hovered = step_bounds.containsInclusive(hover_x, hover_y);
        if (is_hovered) hovered = step.role;
        try renderDnsStep(scene, step_bounds, step, is_hovered);
        if (index + 1 < dns_step_count) {
            try fill(scene, ui.Rect.init(step_bounds.x + step_bounds.w + 3.0, step_bounds.y + step_bounds.h * 0.5, dns_step_gap - 6.0, 2.0), palette.border, 0.0);
        }
    }

    const warning = ui.Rect.init(inner.x, path_top + dns_step_h + 30.0, inner.w, 54.0);
    try fill(scene, warning, ui.Color{ .r = 66, .g = 45, .b = 26, .a = 190 }, 6.0);
    try alignedText(scene, warning.x + 12.0, warning.y + 12.0, warning.w - 24.0, 12.0, "Certificate control still starts with name control.", palette.text, .center);
    try alignedText(scene, warning.x + 12.0, warning.y + 32.0, warning.w - 24.0, 10.0, "Cryptographic identity should be the root. Names should be labels.", palette.dim, .center);

    const detail_y = inner.y + inner.h - dns_detail_h;
    try renderDnsDetail(scene, ui.Rect.init(inner.x, detail_y, inner.w, dns_detail_h), hovered);
}

fn renderDnsStep(scene: *ui.Scene, bounds: ui.Rect, step: DnsStep, hovered: bool) ui.RenderError!void {
    try fill(scene, bounds, dnsStepColor(step.role), 6.0);
    try scene.pushRect(bounds, if (hovered) palette.primary else palette.border, .border, 6.0, 0.0);
    try alignedText(scene, bounds.x + 8.0, bounds.y + 10.0, bounds.w - 16.0, 12.0, step.label, palette.text, .center);
    try alignedText(scene, bounds.x + 8.0, bounds.y + 32.0, bounds.w - 16.0, 10.0, step.risk, palette.dim, .center);
}

fn renderDnsDetail(scene: *ui.Scene, bounds: ui.Rect, hovered: ?DnsStepRole) ui.RenderError!void {
    try fill(scene, bounds, ui.Color{ .r = 9, .g = 9, .b = 9, .a = 210 }, 6.0);
    const role = hovered orelse .registry;
    try text(scene, bounds.x + 16.0, bounds.y + 14.0, 190.0, 14.0, dnsDetailTitle(role), palette.primary);
    try paragraph(scene, ui.Rect.init(bounds.x + 16.0, bounds.y + 34.0, bounds.w - 32.0, 32.0), dnsDetail(role));
}

fn dnsStepColor(role: DnsStepRole) ui.Color {
    return switch (role) {
        .name => ui.Color{ .r = 24, .g = 55, .b = 44, .a = 238 },
        .resolver => ui.Color{ .r = 26, .g = 36, .b = 52, .a = 238 },
        .root => ui.Color{ .r = 44, .g = 44, .b = 44, .a = 238 },
        .registry => ui.Color{ .r = 56, .g = 42, .b = 24, .a = 238 },
        .authoritative => ui.Color{ .r = 72, .g = 36, .b = 36, .a = 238 },
    };
}

fn dnsDetailTitle(role: DnsStepRole) []const u8 {
    return switch (role) {
        .name => "Name",
        .resolver => "Resolver",
        .root => "Root",
        .registry => "Registry",
        .authoritative => "Authoritative server",
    };
}

fn dnsDetail(role: DnsStepRole) []const u8 {
    return switch (role) {
        .name => "The name is memorable for humans, but it is not proof of who controls the service.",
        .resolver => "Resolvers can cache, filter, block, or lie. The answer depends on who you ask.",
        .root => "The root delegates authority. It does not prove the human meaning behind a name.",
        .registry => "Registrars and registries can expire, seize, suspend, or transfer control of a name.",
        .authoritative => "The authoritative server returns today's address. That address can change without changing the label.",
    };
}

const AccountPathRole = enum {
    person,
    account,
    key,
    service,
};

const AccountBox = struct {
    label: []const u8,
    detail: []const u8,
    role: AccountPathRole,
};

const account_path = [_]AccountBox{
    .{ .label = "Person", .detail = "real subject", .role = .person },
    .{ .label = "Platform account", .detail = "permission container", .role = .account },
    .{ .label = "User-owned key", .detail = "portable proof", .role = .key },
    .{ .label = "Service", .detail = "verifies proof", .role = .service },
};

fn renderAccountVsKeyDemo(scene: *ui.Scene, bounds: ui.Rect, hover_x: f32, hover_y: f32) ui.RenderError!void {
    try demoFrame(scene, bounds);
    const inner = bounds.insetUniform(account_demo_pad);
    try tag(scene, ui.Rect.init(inner.x, inner.y, 132.0, 24.0), "IDENTITY DEMO", palette.blue);
    try text(scene, inner.x, inner.y + 38.0, inner.w, 18.0, "Account permission is not portable identity.", palette.text);
    try paragraph(scene, ui.Rect.init(inner.x + 166.0, inner.y + 2.0, @max(1.0, inner.w - 166.0), 54.0), "A platform account can disappear. A user-owned key can prove continuity across services.");

    const lane_top = inner.y + 96.0;
    const lane_w = (inner.w - 40.0) * 0.5;
    var hovered: ?AccountPathRole = null;
    hovered = (try renderAccountLane(scene, ui.Rect.init(inner.x, lane_top, lane_w, 158.0), "Account root", &.{ account_path[0], account_path[1], account_path[3] }, hover_x, hover_y)) orelse hovered;
    hovered = (try renderAccountLane(scene, ui.Rect.init(inner.x + lane_w + 40.0, lane_top, lane_w, 158.0), "Key root", &.{ account_path[0], account_path[2], account_path[3] }, hover_x, hover_y)) orelse hovered;

    const lockout = ui.Rect.init(inner.x, lane_top + 180.0, lane_w, 42.0);
    try fill(scene, lockout, ui.Color{ .r = 72, .g = 36, .b = 36, .a = 205 }, 6.0);
    try alignedText(scene, lockout.x + 12.0, lockout.y + 9.0, lockout.w - 24.0, 10.0, "Account locked -> service access fails", palette.text, .center);
    try alignedText(scene, lockout.x + 12.0, lockout.y + 25.0, lockout.w - 24.0, 9.0, "same person, missing permission", palette.dim, .center);
    const portable = ui.Rect.init(inner.x + lane_w + 40.0, lane_top + 180.0, lane_w, 42.0);
    try fill(scene, portable, ui.Color{ .r = 24, .g = 55, .b = 44, .a = 205 }, 6.0);
    try alignedText(scene, portable.x + 12.0, portable.y + 9.0, portable.w - 24.0, 10.0, "Key proves continuity across labels", palette.text, .center);
    try alignedText(scene, portable.x + 12.0, portable.y + 25.0, portable.w - 24.0, 9.0, "names and recovery sit above it", palette.dim, .center);

    const detail_y = inner.y + inner.h - account_detail_h;
    try renderAccountDetail(scene, ui.Rect.init(inner.x, detail_y, inner.w, account_detail_h), hovered);
}

fn renderAccountLane(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, boxes: []const AccountBox, hover_x: f32, hover_y: f32) ui.RenderError!?AccountPathRole {
    try text(scene, bounds.x, bounds.y, bounds.w, 14.0, label, palette.text);
    const box_w = (bounds.w - account_box_gap * @as(f32, @floatFromInt(boxes.len - 1))) / @as(f32, @floatFromInt(boxes.len));
    var hovered: ?AccountPathRole = null;
    for (boxes, 0..) |box, index| {
        const box_bounds = ui.Rect.init(bounds.x + @as(f32, @floatFromInt(index)) * (box_w + account_box_gap), bounds.y + 34.0, box_w, account_box_h);
        const is_hovered = box_bounds.containsInclusive(hover_x, hover_y);
        if (is_hovered) hovered = box.role;
        try renderAccountBox(scene, box_bounds, box, is_hovered);
        if (index + 1 < boxes.len) {
            try fill(scene, ui.Rect.init(box_bounds.x + box_bounds.w + 3.0, box_bounds.y + box_bounds.h * 0.5, account_box_gap - 6.0, 2.0), palette.border, 0.0);
        }
    }
    return hovered;
}

fn renderAccountBox(scene: *ui.Scene, bounds: ui.Rect, box: AccountBox, hovered: bool) ui.RenderError!void {
    try fill(scene, bounds, accountBoxColor(box.role), 6.0);
    try scene.pushRect(bounds, if (hovered) palette.primary else palette.border, .border, 6.0, 0.0);
    try alignedText(scene, bounds.x + 8.0, bounds.y + 11.0, bounds.w - 16.0, 12.0, box.label, palette.text, .center);
    try alignedText(scene, bounds.x + 8.0, bounds.y + 32.0, bounds.w - 16.0, 10.0, box.detail, palette.dim, .center);
}

fn renderAccountDetail(scene: *ui.Scene, bounds: ui.Rect, hovered: ?AccountPathRole) ui.RenderError!void {
    try fill(scene, bounds, ui.Color{ .r = 9, .g = 9, .b = 9, .a = 210 }, 6.0);
    const role = hovered orelse .key;
    try text(scene, bounds.x + 16.0, bounds.y + 14.0, 190.0, 14.0, accountDetailTitle(role), palette.primary);
    try paragraph(scene, ui.Rect.init(bounds.x + 16.0, bounds.y + 34.0, bounds.w - 32.0, 32.0), accountDetail(role));
}

fn accountBoxColor(role: AccountPathRole) ui.Color {
    return switch (role) {
        .person => ui.Color{ .r = 24, .g = 55, .b = 44, .a = 238 },
        .account => ui.Color{ .r = 72, .g = 36, .b = 36, .a = 238 },
        .key => ui.Color{ .r = 26, .g = 52, .b = 40, .a = 238 },
        .service => ui.Color{ .r = 44, .g = 44, .b = 44, .a = 238 },
    };
}

fn accountDetailTitle(role: AccountPathRole) []const u8 {
    return switch (role) {
        .person => "Person",
        .account => "Platform account",
        .key => "User-owned key",
        .service => "Service",
    };
}

fn accountDetail(role: AccountPathRole) []const u8 {
    return switch (role) {
        .person => "The person should survive account suspension, region policy, device loss, and support failures.",
        .account => "An account is permission inside one service. It can be suspended, deleted, or trapped behind recovery.",
        .key => "A key can prove continuity without making one platform the root of identity.",
        .service => "A service can verify proofs from user keys while names, profiles, and recovery remain replaceable layers.",
    };
}

const ServerStageRole = enum {
    tls_endpoint,
    load_balancer,
    app_handler,
    policy,
    queue,
    logs,
    database,
};

const ServerStage = struct {
    label: []const u8,
    exposure: []const u8,
    role: ServerStageRole,
};

const server_stages = [_]ServerStage{
    .{ .label = "TLS endpoint", .exposure = "decrypts", .role = .tls_endpoint },
    .{ .label = "Load balancer", .exposure = "routes", .role = .load_balancer },
    .{ .label = "App handler", .exposure = "runs code", .role = .app_handler },
    .{ .label = "Policy", .exposure = "accepts/rejects", .role = .policy },
    .{ .label = "Queue", .exposure = "delays/retries", .role = .queue },
    .{ .label = "Logs", .exposure = "metadata", .role = .logs },
    .{ .label = "Database", .exposure = "state owner", .role = .database },
};

fn renderServerPipelineDemo(scene: *ui.Scene, bounds: ui.Rect, hover_x: f32, hover_y: f32) ui.RenderError!void {
    try demoFrame(scene, bounds);
    const inner = bounds.insetUniform(server_demo_pad);
    try tag(scene, ui.Rect.init(inner.x, inner.y, 142.0, 24.0), "SERVER PIPELINE", palette.blue);
    try text(scene, inner.x, inner.y + 38.0, inner.w, 18.0, "The server is code, policy, queues, logs, and memory.", palette.text);
    try paragraph(scene, ui.Rect.init(inner.x + 176.0, inner.y + 2.0, @max(1.0, inner.w - 176.0), 54.0), "A message can be routed, delayed, logged, checked, indexed, or rejected before another person sees it.");

    const path_top = inner.y + 94.0;
    const row_w = server_stage_w * 4.0 + server_stage_gap * 3.0;
    const start_x = inner.x + @max(0.0, (inner.w - row_w) * 0.5);
    var hovered: ?ServerStageRole = null;
    for (server_stages, 0..) |stage, index| {
        const row = index / 4;
        const col = index % 4;
        const stage_bounds = ui.Rect.init(
            start_x + @as(f32, @floatFromInt(col)) * (server_stage_w + server_stage_gap),
            path_top + @as(f32, @floatFromInt(row)) * (server_stage_h + 58.0),
            server_stage_w,
            server_stage_h,
        );
        const is_hovered = stage_bounds.containsInclusive(hover_x, hover_y);
        if (is_hovered) hovered = stage.role;
        try renderServerStage(scene, stage_bounds, stage, is_hovered);
        if (index > 0 and col != 0) {
            try fill(scene, ui.Rect.init(stage_bounds.x - server_stage_gap + 3.0, stage_bounds.y + stage_bounds.h * 0.5, server_stage_gap - 6.0, 2.0), palette.border, 0.0);
        }
    }

    const warning = ui.Rect.init(start_x, path_top + server_stage_h + 20.0, row_w, 30.0);
    try fill(scene, warning, ui.Color{ .r = 72, .g = 36, .b = 36, .a = 190 }, 6.0);
    try alignedText(scene, warning.x + 12.0, warning.y + 9.0, warning.w - 24.0, 10.0, "Useful coordination becomes dangerous when it becomes the source of truth.", palette.text, .center);

    const detail_y = inner.y + inner.h - server_detail_h;
    try renderServerDetail(scene, ui.Rect.init(inner.x, detail_y, inner.w, server_detail_h), hovered);
}

fn renderServerStage(scene: *ui.Scene, bounds: ui.Rect, stage: ServerStage, hovered: bool) ui.RenderError!void {
    try fill(scene, bounds, serverStageColor(stage.role), 6.0);
    try scene.pushRect(bounds, if (hovered) palette.primary else palette.border, .border, 6.0, 0.0);
    try alignedText(scene, bounds.x + 8.0, bounds.y + 10.0, bounds.w - 16.0, 12.0, stage.label, palette.text, .center);
    try alignedText(scene, bounds.x + 8.0, bounds.y + 31.0, bounds.w - 16.0, 10.0, stage.exposure, palette.dim, .center);
}

fn renderServerDetail(scene: *ui.Scene, bounds: ui.Rect, hovered: ?ServerStageRole) ui.RenderError!void {
    try fill(scene, bounds, ui.Color{ .r = 9, .g = 9, .b = 9, .a = 210 }, 6.0);
    const role = hovered orelse .database;
    try text(scene, bounds.x + 16.0, bounds.y + 14.0, 190.0, 14.0, serverDetailTitle(role), palette.primary);
    try paragraph(scene, ui.Rect.init(bounds.x + 16.0, bounds.y + 34.0, bounds.w - 32.0, 32.0), serverDetail(role));
}

fn serverStageColor(role: ServerStageRole) ui.Color {
    return switch (role) {
        .tls_endpoint => ui.Color{ .r = 70, .g = 52, .b = 25, .a = 238 },
        .load_balancer, .queue => ui.Color{ .r = 26, .g = 36, .b = 52, .a = 238 },
        .app_handler => ui.Color{ .r = 44, .g = 44, .b = 44, .a = 238 },
        .policy => ui.Color{ .r = 72, .g = 36, .b = 36, .a = 238 },
        .logs => ui.Color{ .r = 56, .g = 42, .b = 24, .a = 238 },
        .database => ui.Color{ .r = 55, .g = 38, .b = 50, .a = 238 },
    };
}

fn serverDetailTitle(role: ServerStageRole) []const u8 {
    return switch (role) {
        .tls_endpoint => "TLS endpoint",
        .load_balancer => "Load balancer",
        .app_handler => "App handler",
        .policy => "Policy",
        .queue => "Queue",
        .logs => "Logs",
        .database => "Database",
    };
}

fn serverDetail(role: ServerStageRole) []const u8 {
    return switch (role) {
        .tls_endpoint => "The request becomes plaintext here. After this point, server-side systems can inspect it.",
        .load_balancer => "Routing infrastructure can observe timing, volume, endpoint choice, and service health metadata.",
        .app_handler => "Application code interprets the message and decides which internal systems receive it.",
        .policy => "Spam, fraud, moderation, region, and account rules can accept, reject, or transform the message.",
        .queue => "Queues improve reliability but also create another place where message state can wait and be copied.",
        .logs => "Logs often preserve metadata and error context long after the visible operation has finished.",
        .database => "If the database owns state, the user asks permission to access their own conversation.",
    };
}

const PushStepRole = enum {
    sender_service,
    push_provider,
    phone_os,
    app_wake,
    app_fetch,
};

const PushStep = struct {
    label: []const u8,
    exposure: []const u8,
    role: PushStepRole,
};

const push_steps = [_]PushStep{
    .{ .label = "Sender service", .exposure = "relationship", .role = .sender_service },
    .{ .label = "Platform push", .exposure = "device token", .role = .push_provider },
    .{ .label = "Phone OS", .exposure = "wake policy", .role = .phone_os },
    .{ .label = "App wake", .exposure = "opens app", .role = .app_wake },
    .{ .label = "Fetch/decrypt", .exposure = "content path", .role = .app_fetch },
};

fn renderPushWakePathDemo(scene: *ui.Scene, bounds: ui.Rect, hover_x: f32, hover_y: f32) ui.RenderError!void {
    try demoFrame(scene, bounds);
    const inner = bounds.insetUniform(push_demo_pad);
    try tag(scene, ui.Rect.init(inner.x, inner.y, 128.0, 24.0), "WAKE PATH", palette.blue);
    try text(scene, inner.x, inner.y + 38.0, inner.w, 18.0, "A notification is delivery plus a wakeup.", palette.text);
    try paragraph(scene, ui.Rect.init(inner.x + 162.0, inner.y + 2.0, @max(1.0, inner.w - 162.0), 54.0), "Even encrypted content can leave timing, device, app, and relationship metadata in the wake path.");

    const path_top = inner.y + 104.0;
    const step_w = (inner.w - push_step_gap * @as(f32, @floatFromInt(push_step_count - 1))) / @as(f32, @floatFromInt(push_step_count));
    var hovered: ?PushStepRole = null;
    for (push_steps, 0..) |step, index| {
        const step_bounds = ui.Rect.init(inner.x + @as(f32, @floatFromInt(index)) * (step_w + push_step_gap), path_top, step_w, push_step_h);
        const is_hovered = step_bounds.containsInclusive(hover_x, hover_y);
        if (is_hovered) hovered = step.role;
        try renderPushStep(scene, step_bounds, step, is_hovered);
        if (index + 1 < push_step_count) {
            try fill(scene, ui.Rect.init(step_bounds.x + step_bounds.w + 3.0, step_bounds.y + step_bounds.h * 0.5, push_step_gap - 6.0, 2.0), palette.border, 0.0);
        }
    }

    const metadata = ui.Rect.init(inner.x, path_top + push_step_h + 34.0, inner.w, 62.0);
    try fill(scene, metadata, ui.Color{ .r = 66, .g = 45, .b = 26, .a = 190 }, 6.0);
    try text(scene, metadata.x + 18.0, metadata.y + 14.0, metadata.w - 36.0, 12.0, "Metadata still exists", palette.text);
    try paragraph(scene, ui.Rect.init(metadata.x + 18.0, metadata.y + 34.0, metadata.w - 36.0, 24.0), "Who woke which app, on which device, at what time, and how often can be sensitive even when content is encrypted.");

    const detail_y = inner.y + inner.h - push_detail_h;
    try renderPushDetail(scene, ui.Rect.init(inner.x, detail_y, inner.w, push_detail_h), hovered);
}

fn renderPushStep(scene: *ui.Scene, bounds: ui.Rect, step: PushStep, hovered: bool) ui.RenderError!void {
    try fill(scene, bounds, pushStepColor(step.role), 6.0);
    try scene.pushRect(bounds, if (hovered) palette.primary else palette.border, .border, 6.0, 0.0);
    try alignedText(scene, bounds.x + 8.0, bounds.y + 11.0, bounds.w - 16.0, 12.0, step.label, palette.text, .center);
    try alignedText(scene, bounds.x + 8.0, bounds.y + 34.0, bounds.w - 16.0, 10.0, step.exposure, palette.dim, .center);
}

fn renderPushDetail(scene: *ui.Scene, bounds: ui.Rect, hovered: ?PushStepRole) ui.RenderError!void {
    try fill(scene, bounds, ui.Color{ .r = 9, .g = 9, .b = 9, .a = 210 }, 6.0);
    const role = hovered orelse .push_provider;
    try text(scene, bounds.x + 16.0, bounds.y + 14.0, 190.0, 14.0, pushDetailTitle(role), palette.primary);
    try paragraph(scene, ui.Rect.init(bounds.x + 16.0, bounds.y + 34.0, bounds.w - 32.0, 32.0), pushDetail(role));
}

fn pushStepColor(role: PushStepRole) ui.Color {
    return switch (role) {
        .sender_service => ui.Color{ .r = 44, .g = 44, .b = 44, .a = 238 },
        .push_provider => ui.Color{ .r = 72, .g = 36, .b = 36, .a = 238 },
        .phone_os => ui.Color{ .r = 26, .g = 36, .b = 52, .a = 238 },
        .app_wake => ui.Color{ .r = 56, .g = 42, .b = 24, .a = 238 },
        .app_fetch => ui.Color{ .r = 24, .g = 55, .b = 44, .a = 238 },
    };
}

fn pushDetailTitle(role: PushStepRole) []const u8 {
    return switch (role) {
        .sender_service => "Sender service",
        .push_provider => "Platform push",
        .phone_os => "Phone OS",
        .app_wake => "App wake",
        .app_fetch => "Fetch/decrypt",
    };
}

fn pushDetail(role: PushStepRole) []const u8 {
    return switch (role) {
        .sender_service => "The sender service often knows who should be woken, which app is involved, and when.",
        .push_provider => "The platform push provider can learn device token, app identity, timing, and delivery status.",
        .phone_os => "The OS decides whether and how to wake the app, balancing power, policy, and platform control.",
        .app_wake => "A wakeup may reveal that a relationship or account action just happened, even without plaintext content.",
        .app_fetch => "The app may fetch from a server after waking, creating another account and metadata event.",
    };
}

const DependencyRole = enum {
    app,
    analytics,
    crash,
    login,
    push,
    cloud,
    ads,
    transitive,
};

const DependencyNode = struct {
    label: []const u8,
    exposure: []const u8,
    role: DependencyRole,
};

const dependency_nodes = [_]DependencyNode{
    .{ .label = "Chat App", .exposure = "trusted icon", .role = .app },
    .{ .label = "Analytics", .exposure = "event stream", .role = .analytics },
    .{ .label = "Crash SDK", .exposure = "error context", .role = .crash },
    .{ .label = "Login SDK", .exposure = "identity path", .role = .login },
    .{ .label = "Push SDK", .exposure = "wake path", .role = .push },
    .{ .label = "Cloud SDK", .exposure = "remote state", .role = .cloud },
    .{ .label = "Ads", .exposure = "tracking", .role = .ads },
    .{ .label = "Transitive", .exposure = "hidden code", .role = .transitive },
};

fn renderDependencyGraphDemo(scene: *ui.Scene, bounds: ui.Rect, hover_x: f32, hover_y: f32) ui.RenderError!void {
    try demoFrame(scene, bounds);
    const inner = bounds.insetUniform(dependency_demo_pad);
    try tag(scene, ui.Rect.init(inner.x, inner.y, 150.0, 24.0), "DEPENDENCY GRAPH", palette.blue);
    try text(scene, inner.x, inner.y + 38.0, inner.w, 18.0, "One app icon can hide many trust paths.", palette.text);
    try paragraph(scene, ui.Rect.init(inner.x + 184.0, inner.y + 2.0, @max(1.0, inner.w - 184.0), 54.0), "Each SDK can bring code, network routes, update policy, logging, and transitive dependencies.");

    const graph_top = inner.y + 94.0;
    const center = ui.Rect.init(inner.x + (inner.w - dependency_node_w) * 0.5, graph_top, dependency_node_w, dependency_node_h);
    var hovered: ?DependencyRole = null;
    const center_hovered = center.containsInclusive(hover_x, hover_y);
    if (center_hovered) hovered = .app;
    try renderDependencyNode(scene, center, dependency_nodes[0], center_hovered);

    const row_w = dependency_node_w * 4.0 + dependency_node_gap * 3.0;
    const start_x = inner.x + @max(0.0, (inner.w - row_w) * 0.5);
    for (dependency_nodes[1..], 0..) |node, offset| {
        const index = offset + 1;
        const row = offset / 4;
        const col = offset % 4;
        const node_bounds = ui.Rect.init(
            start_x + @as(f32, @floatFromInt(col)) * (dependency_node_w + dependency_node_gap),
            graph_top + 96.0 + @as(f32, @floatFromInt(row)) * (dependency_node_h + 44.0),
            dependency_node_w,
            dependency_node_h,
        );
        const is_hovered = node_bounds.containsInclusive(hover_x, hover_y);
        if (is_hovered) hovered = node.role;
        try renderDependencyLink(scene, center, node_bounds, index);
        try renderDependencyNode(scene, node_bounds, node, is_hovered);
    }

    const warning = ui.Rect.init(start_x, graph_top + 96.0 + dependency_node_h + 16.0, row_w, 24.0);
    try fill(scene, warning, ui.Color{ .r = 72, .g = 36, .b = 36, .a = 190 }, 5.0);
    try alignedText(scene, warning.x + 12.0, warning.y + 7.0, warning.w - 24.0, 10.0, "Running code is authority, even when it arrived as a library.", palette.text, .center);

    const detail_y = inner.y + inner.h - dependency_detail_h;
    try renderDependencyDetail(scene, ui.Rect.init(inner.x, detail_y, inner.w, dependency_detail_h), hovered);
}

fn renderDependencyLink(scene: *ui.Scene, center: ui.Rect, target: ui.Rect, index: usize) ui.RenderError!void {
    _ = index;
    const x0 = center.x + center.w * 0.5;
    const y0 = center.y + center.h;
    const x1 = target.x + target.w * 0.5;
    const y1 = target.y;
    const mid_y = y0 + @max(8.0, (y1 - y0) * 0.45);
    try fill(scene, ui.Rect.init(@min(x0, x1), mid_y, @abs(x1 - x0), 2.0), palette.border, 0.0);
    try fill(scene, ui.Rect.init(x0, y0, 2.0, mid_y - y0), palette.border, 0.0);
    try fill(scene, ui.Rect.init(x1, mid_y, 2.0, y1 - mid_y), palette.border, 0.0);
}

fn renderDependencyNode(scene: *ui.Scene, bounds: ui.Rect, node: DependencyNode, hovered: bool) ui.RenderError!void {
    try fill(scene, bounds, dependencyNodeColor(node.role), 6.0);
    try scene.pushRect(bounds, if (hovered) palette.primary else palette.border, .border, 6.0, 0.0);
    try alignedText(scene, bounds.x + 8.0, bounds.y + 10.0, bounds.w - 16.0, 12.0, node.label, palette.text, .center);
    try alignedText(scene, bounds.x + 8.0, bounds.y + 30.0, bounds.w - 16.0, 10.0, node.exposure, palette.dim, .center);
}

fn renderDependencyDetail(scene: *ui.Scene, bounds: ui.Rect, hovered: ?DependencyRole) ui.RenderError!void {
    try fill(scene, bounds, ui.Color{ .r = 9, .g = 9, .b = 9, .a = 210 }, 6.0);
    const role = hovered orelse .transitive;
    try text(scene, bounds.x + 16.0, bounds.y + 14.0, 190.0, 14.0, dependencyDetailTitle(role), palette.primary);
    try paragraph(scene, ui.Rect.init(bounds.x + 16.0, bounds.y + 34.0, bounds.w - 32.0, 32.0), dependencyDetail(role));
}

fn dependencyNodeColor(role: DependencyRole) ui.Color {
    return switch (role) {
        .app => ui.Color{ .r = 24, .g = 55, .b = 44, .a = 238 },
        .analytics, .ads => ui.Color{ .r = 72, .g = 36, .b = 36, .a = 238 },
        .crash, .transitive => ui.Color{ .r = 56, .g = 42, .b = 24, .a = 238 },
        .login, .cloud => ui.Color{ .r = 55, .g = 38, .b = 50, .a = 238 },
        .push => ui.Color{ .r = 26, .g = 36, .b = 52, .a = 238 },
    };
}

fn dependencyDetailTitle(role: DependencyRole) []const u8 {
    return switch (role) {
        .app => "App",
        .analytics => "Analytics SDK",
        .crash => "Crash SDK",
        .login => "Login SDK",
        .push => "Push SDK",
        .cloud => "Cloud SDK",
        .ads => "Ads SDK",
        .transitive => "Transitive dependency",
    };
}

fn dependencyDetail(role: DependencyRole) []const u8 {
    return switch (role) {
        .app => "The user trusts one app icon, but the binary may include many code owners and update paths.",
        .analytics => "Analytics can turn local actions into remote behavior streams and product experiments.",
        .crash => "Crash reports can include sensitive context if errors capture payloads, paths, or account state.",
        .login => "Login SDKs can outsource identity and recovery to a platform outside the app.",
        .push => "Push SDKs connect the app to platform wake paths and delivery metadata.",
        .cloud => "Cloud clients can make a remote database the real owner of app state.",
        .ads => "Ad SDKs often bring identifiers, auctions, profiling, and extra network destinations.",
        .transitive => "Indirect packages are easy to forget, but they still ship code into the user's trust boundary.",
    };
}

const RouterStepRole = enum {
    phone,
    wifi,
    router,
    isp,
    internet,
};

const RouterStep = struct {
    label: []const u8,
    exposure: []const u8,
    role: RouterStepRole,
};

const router_steps = [_]RouterStep{
    .{ .label = "Phone", .exposure = "creates data", .role = .phone },
    .{ .label = "Wi-Fi", .exposure = "local radio", .role = .wifi },
    .{ .label = "Router", .exposure = "first gatekeeper", .role = .router },
    .{ .label = "ISP", .exposure = "outside route", .role = .isp },
    .{ .label = "Internet", .exposure = "remote path", .role = .internet },
};

fn renderRouterBoundaryDemo(scene: *ui.Scene, bounds: ui.Rect, hover_x: f32, hover_y: f32) ui.RenderError!void {
    try demoFrame(scene, bounds);
    const inner = bounds.insetUniform(router_demo_pad);
    try tag(scene, ui.Rect.init(inner.x, inner.y, 142.0, 24.0), "ROUTER BOUNDARY", palette.blue);
    try text(scene, inner.x, inner.y + 38.0, inner.w, 18.0, "Wi-Fi protects local air, not every later boundary.", palette.text);
    try paragraph(scene, ui.Rect.init(inner.x + 176.0, inner.y + 2.0, @max(1.0, inner.w - 176.0), 54.0), "The router is a separate system with address assignment, forwarding, DNS settings, logs, and firewall policy.");

    const path_top = inner.y + 104.0;
    const step_w = (inner.w - router_step_gap * @as(f32, @floatFromInt(router_step_count - 1))) / @as(f32, @floatFromInt(router_step_count));
    var hovered: ?RouterStepRole = null;
    for (router_steps, 0..) |step, index| {
        const step_bounds = ui.Rect.init(inner.x + @as(f32, @floatFromInt(index)) * (step_w + router_step_gap), path_top, step_w, router_step_h);
        const is_hovered = step_bounds.containsInclusive(hover_x, hover_y);
        if (is_hovered) hovered = step.role;
        try renderRouterStep(scene, step_bounds, step, is_hovered);
        if (index + 1 < router_step_count) {
            const line_color = if (index == 1) palette.primary else palette.border;
            try fill(scene, ui.Rect.init(step_bounds.x + step_bounds.w + 3.0, step_bounds.y + step_bounds.h * 0.5, router_step_gap - 6.0, 2.0), line_color, 0.0);
        }
    }

    const local = ui.Rect.init(inner.x, path_top + router_step_h + 34.0, step_w * 3.0 + router_step_gap * 2.0, 44.0);
    try fill(scene, local, ui.Color{ .r = 24, .g = 55, .b = 44, .a = 190 }, 6.0);
    try alignedText(scene, local.x + 12.0, local.y + 10.0, local.w - 24.0, 10.0, "Local trust boundary", palette.text, .center);
    try alignedText(scene, local.x + 12.0, local.y + 26.0, local.w - 24.0, 9.0, "device, Wi-Fi, router", palette.dim, .center);
    const remote = ui.Rect.init(local.x + local.w + router_step_gap, local.y, inner.w - local.w - router_step_gap, 44.0);
    try fill(scene, remote, ui.Color{ .r = 56, .g = 42, .b = 24, .a = 190 }, 6.0);
    try alignedText(scene, remote.x + 12.0, remote.y + 10.0, remote.w - 24.0, 10.0, "Outside path", palette.text, .center);
    try alignedText(scene, remote.x + 12.0, remote.y + 26.0, remote.w - 24.0, 9.0, "ISP and internet", palette.dim, .center);

    const detail_y = inner.y + inner.h - router_detail_h;
    try renderRouterDetail(scene, ui.Rect.init(inner.x, detail_y, inner.w, router_detail_h), hovered);
}

fn renderRouterStep(scene: *ui.Scene, bounds: ui.Rect, step: RouterStep, hovered: bool) ui.RenderError!void {
    try fill(scene, bounds, routerStepColor(step.role), 6.0);
    try scene.pushRect(bounds, if (hovered) palette.primary else palette.border, .border, 6.0, 0.0);
    try alignedText(scene, bounds.x + 8.0, bounds.y + 11.0, bounds.w - 16.0, 12.0, step.label, palette.text, .center);
    try alignedText(scene, bounds.x + 8.0, bounds.y + 34.0, bounds.w - 16.0, 10.0, step.exposure, palette.dim, .center);
}

fn renderRouterDetail(scene: *ui.Scene, bounds: ui.Rect, hovered: ?RouterStepRole) ui.RenderError!void {
    try fill(scene, bounds, ui.Color{ .r = 9, .g = 9, .b = 9, .a = 210 }, 6.0);
    const role = hovered orelse .router;
    try text(scene, bounds.x + 16.0, bounds.y + 14.0, 190.0, 14.0, routerDetailTitle(role), palette.primary);
    try paragraph(scene, ui.Rect.init(bounds.x + 16.0, bounds.y + 34.0, bounds.w - 32.0, 32.0), routerDetail(role));
}

fn routerStepColor(role: RouterStepRole) ui.Color {
    return switch (role) {
        .phone => ui.Color{ .r = 24, .g = 55, .b = 44, .a = 238 },
        .wifi => ui.Color{ .r = 26, .g = 36, .b = 52, .a = 238 },
        .router => ui.Color{ .r = 56, .g = 42, .b = 24, .a = 238 },
        .isp => ui.Color{ .r = 72, .g = 36, .b = 36, .a = 238 },
        .internet => ui.Color{ .r = 44, .g = 44, .b = 44, .a = 238 },
    };
}

fn routerDetailTitle(role: RouterStepRole) []const u8 {
    return switch (role) {
        .phone => "Phone",
        .wifi => "Wi-Fi",
        .router => "Router",
        .isp => "ISP",
        .internet => "Internet",
    };
}

fn routerDetail(role: RouterStepRole) []const u8 {
    return switch (role) {
        .phone => "The best boundary is not sending unnecessary data from the device in the first place.",
        .wifi => "WPA protects local radio traffic. It does not decide identity, app tracking, or server trust.",
        .router => "The router assigns addresses, forwards packets, sets DNS, applies firewall policy, and may keep logs.",
        .isp => "The ISP sees the outside route unless other layers hide destination detail.",
        .internet => "Past the router and ISP, DNS, TLS, VPNs, relays, servers, and databases add new boundaries.",
    };
}

const KeypressStepRole = enum {
    finger,
    hardware,
    os_event,
    app_state,
    render,
    committed_object,
};

const KeypressStep = struct {
    label: []const u8,
    exposure: []const u8,
    role: KeypressStepRole,
};

const keypress_steps = [_]KeypressStep{
    .{ .label = "Finger", .exposure = "physical action", .role = .finger },
    .{ .label = "Hardware", .exposure = "electrical event", .role = .hardware },
    .{ .label = "OS event", .exposure = "input queue", .role = .os_event },
    .{ .label = "App state", .exposure = "draft buffer", .role = .app_state },
    .{ .label = "Render", .exposure = "visible pixels", .role = .render },
    .{ .label = "Send intent", .exposure = "committed object", .role = .committed_object },
};

fn renderKeypressCommitPathDemo(scene: *ui.Scene, bounds: ui.Rect, hover_x: f32, hover_y: f32) ui.RenderError!void {
    try demoFrame(scene, bounds);
    const inner = bounds.insetUniform(keypress_demo_pad);
    try tag(scene, ui.Rect.init(inner.x, inner.y, 142.0, 24.0), "COMMIT PATH", palette.blue);
    try text(scene, inner.x, inner.y + 38.0, inner.w, 18.0, "Typing is not the same as sending.", palette.text);
    try paragraph(scene, ui.Rect.init(inner.x + 176.0, inner.y + 2.0, @max(1.0, inner.w - 176.0), 54.0), "Raw input can stay local. Only explicit user intent should become a durable object worth storing or sending.");

    const path_top = inner.y + 104.0;
    const step_w = (inner.w - keypress_step_gap * @as(f32, @floatFromInt(keypress_step_count - 1))) / @as(f32, @floatFromInt(keypress_step_count));
    var hovered: ?KeypressStepRole = null;
    for (keypress_steps, 0..) |step, index| {
        const step_bounds = ui.Rect.init(inner.x + @as(f32, @floatFromInt(index)) * (step_w + keypress_step_gap), path_top, step_w, keypress_step_h);
        const is_hovered = step_bounds.containsInclusive(hover_x, hover_y);
        if (is_hovered) hovered = step.role;
        try renderKeypressStep(scene, step_bounds, step, is_hovered);
        if (index + 1 < keypress_step_count) {
            const line_color = if (index + 1 == keypress_step_count - 1) palette.primary else palette.border;
            try fill(scene, ui.Rect.init(step_bounds.x + step_bounds.w + 3.0, step_bounds.y + step_bounds.h * 0.5, keypress_step_gap - 6.0, 2.0), line_color, 0.0);
        }
    }

    const boundary = ui.Rect.init(inner.x, path_top + keypress_step_h + 34.0, inner.w, 52.0);
    try fill(scene, boundary, ui.Color{ .r = 24, .g = 55, .b = 44, .a = 190 }, 6.0);
    try alignedText(scene, boundary.x + 12.0, boundary.y + 12.0, boundary.w - 24.0, 10.0, "Commit boundary", palette.text, .center);
    try alignedText(scene, boundary.x + 12.0, boundary.y + 30.0, boundary.w - 24.0, 9.0, "drafts and corrections are local state until the user chooses to send", palette.dim, .center);

    const detail_y = inner.y + inner.h - keypress_detail_h;
    try renderKeypressDetail(scene, ui.Rect.init(inner.x, detail_y, inner.w, keypress_detail_h), hovered);
}

fn renderKeypressStep(scene: *ui.Scene, bounds: ui.Rect, step: KeypressStep, hovered: bool) ui.RenderError!void {
    try fill(scene, bounds, keypressStepColor(step.role), 6.0);
    try scene.pushRect(bounds, if (hovered) palette.primary else palette.border, .border, 6.0, 0.0);
    try alignedText(scene, bounds.x + 8.0, bounds.y + 11.0, bounds.w - 16.0, 12.0, step.label, palette.text, .center);
    try alignedText(scene, bounds.x + 8.0, bounds.y + 33.0, bounds.w - 16.0, 10.0, step.exposure, palette.dim, .center);
}

fn renderKeypressDetail(scene: *ui.Scene, bounds: ui.Rect, hovered: ?KeypressStepRole) ui.RenderError!void {
    try fill(scene, bounds, ui.Color{ .r = 9, .g = 9, .b = 9, .a = 210 }, 6.0);
    const role = hovered orelse .committed_object;
    try text(scene, bounds.x + 16.0, bounds.y + 14.0, 190.0, 14.0, keypressDetailTitle(role), palette.primary);
    try paragraph(scene, ui.Rect.init(bounds.x + 16.0, bounds.y + 34.0, bounds.w - 32.0, 32.0), keypressDetail(role));
}

fn keypressStepColor(role: KeypressStepRole) ui.Color {
    return switch (role) {
        .finger, .committed_object => ui.Color{ .r = 24, .g = 55, .b = 44, .a = 238 },
        .hardware => ui.Color{ .r = 56, .g = 42, .b = 24, .a = 238 },
        .os_event => ui.Color{ .r = 26, .g = 36, .b = 52, .a = 238 },
        .app_state => ui.Color{ .r = 55, .g = 38, .b = 50, .a = 238 },
        .render => ui.Color{ .r = 44, .g = 44, .b = 44, .a = 238 },
    };
}

fn keypressDetailTitle(role: KeypressStepRole) []const u8 {
    return switch (role) {
        .finger => "Finger",
        .hardware => "Hardware",
        .os_event => "OS event",
        .app_state => "App state",
        .render => "Render",
        .committed_object => "Send intent",
    };
}

fn keypressDetail(role: KeypressStepRole) []const u8 {
    return switch (role) {
        .finger => "A physical action starts the path, but it is not yet a message or a network event.",
        .hardware => "Keyboard or touch hardware reports low-level signals without knowing user meaning.",
        .os_event => "The OS turns hardware input into an event for the focused app.",
        .app_state => "The app can hold drafts, corrections, and deleted text before anything is committed.",
        .render => "Pixels let the user inspect local state before choosing a durable action.",
        .committed_object => "Only explicit send intent should become signed history, storage, or network transfer.",
    };
}

const ComputeTaskRole = enum {
    notes,
    contacts,
    calendar,
    local_search,
    assistant,
    cloud_capacity,
};

const ComputeTask = struct {
    label: []const u8,
    owner: []const u8,
    role: ComputeTaskRole,
};

const compute_tasks = [_]ComputeTask{
    .{ .label = "Notes", .owner = "local text", .role = .notes },
    .{ .label = "Contacts", .owner = "local graph", .role = .contacts },
    .{ .label = "Calendar", .owner = "local schedule", .role = .calendar },
    .{ .label = "Search", .owner = "local index", .role = .local_search },
    .{ .label = "Assistant", .owner = "local context", .role = .assistant },
    .{ .label = "Cloud", .owner = "extra capacity", .role = .cloud_capacity },
};

fn renderLocalComputeCapacityDemo(scene: *ui.Scene, bounds: ui.Rect, hover_x: f32, hover_y: f32) ui.RenderError!void {
    try demoFrame(scene, bounds);
    const inner = bounds.insetUniform(compute_demo_pad);
    try tag(scene, ui.Rect.init(inner.x, inner.y, 150.0, 24.0), "LOCAL COMPUTE", palette.blue);
    try text(scene, inner.x, inner.y + 38.0, inner.w, 18.0, "Small personal workloads fit on the device.", palette.text);
    try paragraph(scene, ui.Rect.init(inner.x + 184.0, inner.y + 2.0, @max(1.0, inner.w - 184.0), 54.0), "Cloud is useful for remote coordination and large jobs. It should not become the default owner of ordinary state.");

    const chip = ui.Rect.init(inner.x, inner.y + 100.0, 170.0, 150.0);
    try fill(scene, chip, ui.Color{ .r = 24, .g = 55, .b = 44, .a = 215 }, 8.0);
    try scene.pushRect(chip, palette.primary, .border, 8.0, 0.0);
    try alignedText(scene, chip.x + 12.0, chip.y + 32.0, chip.w - 24.0, 14.0, "Your device", palette.text, .center);
    try alignedText(scene, chip.x + 12.0, chip.y + 64.0, chip.w - 24.0, 10.0, "CPU + storage + keys", palette.dim, .center);
    try alignedText(scene, chip.x + 12.0, chip.y + 86.0, chip.w - 24.0, 10.0, "graphics + network", palette.dim, .center);

    const task_area_x = chip.x + chip.w + 44.0;
    const task_area_w = @max(1.0, inner.w - chip.w - 44.0);
    const row_w = compute_task_w * 3.0 + compute_task_gap * 2.0;
    const start_x = task_area_x + @max(0.0, (task_area_w - row_w) * 0.5);
    var hovered: ?ComputeTaskRole = null;
    for (compute_tasks, 0..) |task, index| {
        const row = index / 3;
        const col = index % 3;
        const task_bounds = ui.Rect.init(
            start_x + @as(f32, @floatFromInt(col)) * (compute_task_w + compute_task_gap),
            inner.y + 96.0 + @as(f32, @floatFromInt(row)) * (compute_task_h + 42.0),
            compute_task_w,
            compute_task_h,
        );
        const is_hovered = task_bounds.containsInclusive(hover_x, hover_y);
        if (is_hovered) hovered = task.role;
        try renderComputeTask(scene, task_bounds, task, is_hovered);
    }

    const rule = ui.Rect.init(inner.x, inner.y + 280.0, inner.w, 34.0);
    try fill(scene, rule, ui.Color{ .r = 26, .g = 36, .b = 52, .a = 190 }, 6.0);
    try alignedText(scene, rule.x + 12.0, rule.y + 10.0, rule.w - 24.0, 10.0, "local first -> sync when needed -> cloud only when useful", palette.text, .center);

    const detail_y = inner.y + inner.h - compute_detail_h;
    try renderComputeDetail(scene, ui.Rect.init(inner.x, detail_y, inner.w, compute_detail_h), hovered);
}

fn renderComputeTask(scene: *ui.Scene, bounds: ui.Rect, task: ComputeTask, hovered: bool) ui.RenderError!void {
    try fill(scene, bounds, computeTaskColor(task.role), 6.0);
    try scene.pushRect(bounds, if (hovered) palette.primary else palette.border, .border, 6.0, 0.0);
    try alignedText(scene, bounds.x + 8.0, bounds.y + 10.0, bounds.w - 16.0, 12.0, task.label, palette.text, .center);
    try alignedText(scene, bounds.x + 8.0, bounds.y + 30.0, bounds.w - 16.0, 10.0, task.owner, palette.dim, .center);
}

fn renderComputeDetail(scene: *ui.Scene, bounds: ui.Rect, hovered: ?ComputeTaskRole) ui.RenderError!void {
    try fill(scene, bounds, ui.Color{ .r = 9, .g = 9, .b = 9, .a = 210 }, 6.0);
    const role = hovered orelse .notes;
    try text(scene, bounds.x + 16.0, bounds.y + 14.0, 190.0, 14.0, computeDetailTitle(role), palette.primary);
    try paragraph(scene, ui.Rect.init(bounds.x + 16.0, bounds.y + 34.0, bounds.w - 32.0, 32.0), computeDetail(role));
}

fn computeTaskColor(role: ComputeTaskRole) ui.Color {
    return switch (role) {
        .notes, .contacts, .calendar, .local_search, .assistant => ui.Color{ .r = 24, .g = 55, .b = 44, .a = 238 },
        .cloud_capacity => ui.Color{ .r = 72, .g = 36, .b = 36, .a = 238 },
    };
}

fn computeDetailTitle(role: ComputeTaskRole) []const u8 {
    return switch (role) {
        .notes => "Notes",
        .contacts => "Contacts",
        .calendar => "Calendar",
        .local_search => "Search",
        .assistant => "Assistant",
        .cloud_capacity => "Cloud capacity",
    };
}

fn computeDetail(role: ComputeTaskRole) []const u8 {
    return switch (role) {
        .notes => "Plain text and small documents do not need a server round trip to exist or display.",
        .contacts => "A contact book can be local user-owned state, then replicated or shared deliberately.",
        .calendar => "Schedules are small structured records. Remote sync can help without becoming authority.",
        .local_search => "Local indexes can search personal state without leaking every query to a service.",
        .assistant => "The most useful assistant needs context. That context is safest when local by default.",
        .cloud_capacity => "Remote compute should be a chosen tool for delivery, backup, coordination, or large workloads.",
    };
}

const StorageStageRole = enum {
    raw_bytes,
    app_database,
    sealed_object,
    verifier,
    portable_export,
};

const StorageStage = struct {
    label: []const u8,
    exposure: []const u8,
    role: StorageStageRole,
};

const storage_stages = [_]StorageStage{
    .{ .label = "Raw bytes", .exposure = "survive on disk", .role = .raw_bytes },
    .{ .label = "App DB", .exposure = "private meaning", .role = .app_database },
    .{ .label = "Sealed object", .exposure = "encrypted body", .role = .sealed_object },
    .{ .label = "Verifier", .exposure = "checks identity", .role = .verifier },
    .{ .label = "Export", .exposure = "portable proof", .role = .portable_export },
};

fn renderStorageSealedObjectsDemo(scene: *ui.Scene, bounds: ui.Rect, hover_x: f32, hover_y: f32) ui.RenderError!void {
    try demoFrame(scene, bounds);
    const inner = bounds.insetUniform(storage_demo_pad);
    try tag(scene, ui.Rect.init(inner.x, inner.y, 142.0, 24.0), "SEALED STORAGE", palette.blue);
    try text(scene, inner.x, inner.y + 38.0, inner.w, 18.0, "Bytes need ownership rules.", palette.text);
    try paragraph(scene, ui.Rect.init(inner.x + 176.0, inner.y + 2.0, @max(1.0, inner.w - 176.0), 54.0), "Storage is only where bytes sit. Sealed objects add identity, verification, encryption, and exportable meaning.");

    const path_top = inner.y + 104.0;
    const stage_w = (inner.w - storage_stage_gap * @as(f32, @floatFromInt(storage_stage_count - 1))) / @as(f32, @floatFromInt(storage_stage_count));
    var hovered: ?StorageStageRole = null;
    for (storage_stages, 0..) |stage, index| {
        const stage_bounds = ui.Rect.init(inner.x + @as(f32, @floatFromInt(index)) * (stage_w + storage_stage_gap), path_top, stage_w, storage_stage_h);
        const is_hovered = stage_bounds.containsInclusive(hover_x, hover_y);
        if (is_hovered) hovered = stage.role;
        try renderStorageStage(scene, stage_bounds, stage, is_hovered);
        if (index + 1 < storage_stage_count) {
            const line_color = if (index >= 1) palette.primary else palette.border;
            try fill(scene, ui.Rect.init(stage_bounds.x + stage_bounds.w + 3.0, stage_bounds.y + stage_bounds.h * 0.5, storage_stage_gap - 6.0, 2.0), line_color, 0.0);
        }
    }

    const raw_band = ui.Rect.init(inner.x, path_top + storage_stage_h + 34.0, inner.w * 0.43, 50.0);
    try fill(scene, raw_band, ui.Color{ .r = 72, .g = 36, .b = 36, .a = 190 }, 6.0);
    try alignedText(scene, raw_band.x + 12.0, raw_band.y + 11.0, raw_band.w - 24.0, 10.0, "raw bytes -> app-private pile", palette.text, .center);
    try alignedText(scene, raw_band.x + 12.0, raw_band.y + 30.0, raw_band.w - 24.0, 9.0, "hard to prove or move", palette.dim, .center);
    const sealed_band = ui.Rect.init(raw_band.x + raw_band.w + storage_stage_gap, raw_band.y, inner.w - raw_band.w - storage_stage_gap, 50.0);
    try fill(scene, sealed_band, ui.Color{ .r = 24, .g = 55, .b = 44, .a = 190 }, 6.0);
    try alignedText(scene, sealed_band.x + 12.0, sealed_band.y + 11.0, sealed_band.w - 24.0, 10.0, "sealed object -> portable verified state", palette.text, .center);
    try alignedText(scene, sealed_band.x + 12.0, sealed_band.y + 30.0, sealed_band.w - 24.0, 9.0, "identity travels with the bytes", palette.dim, .center);

    const detail_y = inner.y + inner.h - storage_detail_h;
    try renderStorageDetail(scene, ui.Rect.init(inner.x, detail_y, inner.w, storage_detail_h), hovered);
}

fn renderStorageStage(scene: *ui.Scene, bounds: ui.Rect, stage: StorageStage, hovered: bool) ui.RenderError!void {
    try fill(scene, bounds, storageStageColor(stage.role), 6.0);
    try scene.pushRect(bounds, if (hovered) palette.primary else palette.border, .border, 6.0, 0.0);
    try alignedText(scene, bounds.x + 8.0, bounds.y + 11.0, bounds.w - 16.0, 12.0, stage.label, palette.text, .center);
    try alignedText(scene, bounds.x + 8.0, bounds.y + 34.0, bounds.w - 16.0, 10.0, stage.exposure, palette.dim, .center);
}

fn renderStorageDetail(scene: *ui.Scene, bounds: ui.Rect, hovered: ?StorageStageRole) ui.RenderError!void {
    try fill(scene, bounds, ui.Color{ .r = 9, .g = 9, .b = 9, .a = 210 }, 6.0);
    const role = hovered orelse .sealed_object;
    try text(scene, bounds.x + 16.0, bounds.y + 14.0, 190.0, 14.0, storageDetailTitle(role), palette.primary);
    try paragraph(scene, ui.Rect.init(bounds.x + 16.0, bounds.y + 34.0, bounds.w - 32.0, 32.0), storageDetail(role));
}

fn storageStageColor(role: StorageStageRole) ui.Color {
    return switch (role) {
        .raw_bytes => ui.Color{ .r = 72, .g = 36, .b = 36, .a = 238 },
        .app_database => ui.Color{ .r = 56, .g = 42, .b = 24, .a = 238 },
        .sealed_object, .verifier, .portable_export => ui.Color{ .r = 24, .g = 55, .b = 44, .a = 238 },
    };
}

fn storageDetailTitle(role: StorageStageRole) []const u8 {
    return switch (role) {
        .raw_bytes => "Raw bytes",
        .app_database => "App database",
        .sealed_object => "Sealed object",
        .verifier => "Verifier",
        .portable_export => "Export",
    };
}

fn storageDetail(role: StorageStageRole) []const u8 {
    return switch (role) {
        .raw_bytes => "Bytes on disk do not say who owns them, who may open them, or whether they were changed.",
        .app_database => "A private schema may make backups dependent on the original app and account service.",
        .sealed_object => "A sealed object binds encrypted bytes to explicit identity, authority, and object meaning.",
        .verifier => "Verification checks canonical bytes and signatures before treating stored data as true.",
        .portable_export => "Good export preserves proof and meaning after the original service or app is gone.",
    };
}

const TrustStepRole = enum {
    rom,
    bootloader,
    measured_runtime,
    tpm_key,
    user_intent,
};

const TrustStep = struct {
    label: []const u8,
    exposure: []const u8,
    role: TrustStepRole,
};

const trust_steps = [_]TrustStep{
    .{ .label = "ROM", .exposure = "first check", .role = .rom },
    .{ .label = "Bootloader", .exposure = "approved next", .role = .bootloader },
    .{ .label = "Runtime", .exposure = "measured state", .role = .measured_runtime },
    .{ .label = "TPM key", .exposure = "signs/seals", .role = .tpm_key },
    .{ .label = "User intent", .exposure = "authorizes", .role = .user_intent },
};

fn renderSecureBootRootDemo(scene: *ui.Scene, bounds: ui.Rect, hover_x: f32, hover_y: f32) ui.RenderError!void {
    try demoFrame(scene, bounds);
    const inner = bounds.insetUniform(trust_demo_pad);
    try tag(scene, ui.Rect.init(inner.x, inner.y, 146.0, 24.0), "ROOT OF TRUST", palette.blue);
    try text(scene, inner.x, inner.y + 38.0, inner.w, 18.0, "A root of trust must answer: root for whom?", palette.text);
    try paragraph(scene, ui.Rect.init(inner.x + 180.0, inner.y + 2.0, @max(1.0, inner.w - 180.0), 54.0), "Secure boot and TPMs help when hardware measurements bind to user-owned runtime authority, not vendor-only approval.");

    const path_top = inner.y + 104.0;
    const step_w = (inner.w - trust_step_gap * @as(f32, @floatFromInt(trust_step_count - 1))) / @as(f32, @floatFromInt(trust_step_count));
    var hovered: ?TrustStepRole = null;
    for (trust_steps, 0..) |step, index| {
        const step_bounds = ui.Rect.init(inner.x + @as(f32, @floatFromInt(index)) * (step_w + trust_step_gap), path_top, step_w, trust_step_h);
        const is_hovered = step_bounds.containsInclusive(hover_x, hover_y);
        if (is_hovered) hovered = step.role;
        try renderTrustStep(scene, step_bounds, step, is_hovered);
        if (index + 1 < trust_step_count) {
            const line_color = if (index >= 2) palette.primary else palette.border;
            try fill(scene, ui.Rect.init(step_bounds.x + step_bounds.w + 3.0, step_bounds.y + step_bounds.h * 0.5, trust_step_gap - 6.0, 2.0), line_color, 0.0);
        }
    }

    const mechanism = ui.Rect.init(inner.x, path_top + trust_step_h + 34.0, inner.w, 52.0);
    try fill(scene, mechanism, ui.Color{ .r = 26, .g = 36, .b = 52, .a = 190 }, 6.0);
    try alignedText(scene, mechanism.x + 12.0, mechanism.y + 12.0, mechanism.w - 24.0, 10.0, "mechanism is not enough: ask who enrolls, recovers, and overrides", palette.text, .center);
    try alignedText(scene, mechanism.x + 12.0, mechanism.y + 30.0, mechanism.w - 24.0, 9.0, "hardware is useful only when the authority chain serves the owner", palette.dim, .center);

    const detail_y = inner.y + inner.h - trust_detail_h;
    try renderTrustDetail(scene, ui.Rect.init(inner.x, detail_y, inner.w, trust_detail_h), hovered);
}

fn renderTrustStep(scene: *ui.Scene, bounds: ui.Rect, step: TrustStep, hovered: bool) ui.RenderError!void {
    try fill(scene, bounds, trustStepColor(step.role), 6.0);
    try scene.pushRect(bounds, if (hovered) palette.primary else palette.border, .border, 6.0, 0.0);
    try alignedText(scene, bounds.x + 8.0, bounds.y + 11.0, bounds.w - 16.0, 12.0, step.label, palette.text, .center);
    try alignedText(scene, bounds.x + 8.0, bounds.y + 34.0, bounds.w - 16.0, 10.0, step.exposure, palette.dim, .center);
}

fn renderTrustDetail(scene: *ui.Scene, bounds: ui.Rect, hovered: ?TrustStepRole) ui.RenderError!void {
    try fill(scene, bounds, ui.Color{ .r = 9, .g = 9, .b = 9, .a = 210 }, 6.0);
    const role = hovered orelse .tpm_key;
    try text(scene, bounds.x + 16.0, bounds.y + 14.0, 190.0, 14.0, trustDetailTitle(role), palette.primary);
    try paragraph(scene, ui.Rect.init(bounds.x + 16.0, bounds.y + 34.0, bounds.w - 32.0, 32.0), trustDetail(role));
}

fn trustStepColor(role: TrustStepRole) ui.Color {
    return switch (role) {
        .rom => ui.Color{ .r = 56, .g = 42, .b = 24, .a = 238 },
        .bootloader => ui.Color{ .r = 72, .g = 36, .b = 36, .a = 238 },
        .measured_runtime => ui.Color{ .r = 26, .g = 36, .b = 52, .a = 238 },
        .tpm_key, .user_intent => ui.Color{ .r = 24, .g = 55, .b = 44, .a = 238 },
    };
}

fn trustDetailTitle(role: TrustStepRole) []const u8 {
    return switch (role) {
        .rom => "ROM",
        .bootloader => "Bootloader",
        .measured_runtime => "Runtime",
        .tpm_key => "TPM key",
        .user_intent => "User intent",
    };
}

fn trustDetail(role: TrustStepRole) []const u8 {
    return switch (role) {
        .rom => "The immutable first stage can check what runs next, but it does not decide owner policy alone.",
        .bootloader => "Approval can protect the user or lock the user out, depending on who controls enrollment.",
        .measured_runtime => "Measured runtime state gives a key operation context that software alone cannot prove.",
        .tpm_key => "A TPM-backed key should sign explicit local authority, not an opaque platform blessing.",
        .user_intent => "The chain is incomplete unless the signed action includes a real user intent boundary.",
    };
}

fn bodyWithoutTitle(source: []const u8) []const u8 {
    if (!std.mem.startsWith(u8, source, "# ")) return source;
    const split = std.mem.indexOfScalar(u8, source, '\n') orelse return "";
    var start = split + 1;
    while (start < source.len and (source[start] == '\n' or source[start] == '\r')) : (start += 1) {}
    return source[start..];
}

fn paragraphHeight(value: []const u8, width: f32) f32 {
    const chars_per_line = @max(@as(usize, 24), @as(usize, @intFromFloat(width / 10.0)));
    const lines = (value.len + chars_per_line - 1) / chars_per_line;
    return line_h * @as(f32, @floatFromInt(@max(@as(usize, 1), @min(@as(usize, 5), lines))));
}

fn calloutHeight(value: []const u8, width: f32) f32 {
    const text_w = @max(1.0, width - callout_pad_x * 2.0 - 18.0);
    const chars_per_line = @max(@as(usize, 18), @as(usize, @intFromFloat(text_w / callout_avg_char_w)));
    const lines = @max(@as(usize, 1), @min(@as(usize, 4), (value.len + chars_per_line - 1) / chars_per_line));
    return callout_pad_y * 2.0 + callout_line_h * @as(f32, @floatFromInt(lines));
}

fn callout(scene: *ui.Scene, bounds: ui.Rect, value: []const u8) ui.RenderError!void {
    var callout_style = appStyle();
    callout_style.panel = palette.card_alt;
    try components.renderComponent(scene, bounds, .{ .card = .{
        .title = "",
        .detail = "",
        .variant = .subtle,
    } }, .{ .style = callout_style });
    try fill(scene, ui.Rect.init(bounds.x, bounds.y, 3.0, bounds.h), palette.primary, 2.0);
    try scene.pushWrappedText(ui.Rect.init(bounds.x + callout_pad_x, bounds.y + callout_pad_y, bounds.w - callout_pad_x * 2.0, bounds.h - callout_pad_y * 2.0), value, palette.text, .{
        .line_height = callout_line_h,
        .average_char_width = callout_avg_char_w,
        .max_lines = 4,
    });
}

fn wrappedTextHeight(value: []const u8, width: f32, line_height_value: f32, max_lines: usize, average_char_width: f32) f32 {
    const chars_per_line = @max(@as(usize, 1), @as(usize, @intFromFloat(width / average_char_width)));
    const lines = @max(@as(usize, 1), @min(max_lines, (value.len + chars_per_line - 1) / chars_per_line));
    return line_height_value * @as(f32, @floatFromInt(lines));
}

fn wrappedLineCount(value: []const u8, width: f32, average_char_width: f32, max_lines: usize) usize {
    if (value.len == 0 or max_lines == 0) return 0;
    const char_capacity = @max(@as(usize, 1), @as(usize, @intFromFloat(@max(1.0, width / average_char_width))));
    var byte_cursor: usize = 0;
    var line_count: usize = 0;
    while (line_count < max_lines) : (line_count += 1) {
        byte_cursor = ui.skipAsciiSpace(value, byte_cursor);
        if (byte_cursor >= value.len) return line_count;
        byte_cursor = ui.wrappedLine(value, byte_cursor, char_capacity).next;
    }
    return line_count;
}

fn episodeLabel(episode: usize) []const u8 {
    if (episode == 0 or episode > episode_labels.len) return "Episode";
    return episode_labels[episode - 1];
}

fn codeBlock(scene: *ui.Scene, bounds: ui.Rect, lines: []const []const u8) ui.RenderError!void {
    const style = appStyle();
    var code_style = style;
    code_style.panel = style.bg;
    try components.renderComponent(scene, bounds, .{ .card = .{
        .title = "",
        .detail = "",
    } }, .{ .style = code_style });
    if (try scene.pushClip(bounds.insetUniform(code_clip_inset))) {
        defer scene.popClip();
        var y = bounds.y + code_pad_y;
        for (lines) |line| {
            if (y + code_line_h > bounds.y + bounds.h - code_pad_y) break;
            try alignedText(scene, bounds.x + code_pad_x, y, bounds.w - code_pad_x * 2.0, code_text_h, line, style.accent, .start);
            y += code_line_h;
        }
    }
}

fn renderNodeMap(scene: *ui.Scene, bounds: ui.Rect) ui.RenderError!void {
    var x = bounds.x;
    while (x < bounds.x + bounds.w) : (x += node_map_grid) {
        var y = bounds.y;
        while (y < bounds.y + bounds.h) : (y += node_map_grid) {
            if (@mod(@as(i32, @intFromFloat(x + y)), node_map_pattern_divisor) == 0) {
                try fill(scene, ui.Rect.init(x, y, node_map_dot_size, node_map_dot_size), ui.Color{ .r = 255, .g = 255, .b = 255, .a = node_map_dot_alpha }, node_map_dot_radius);
            }
        }
    }
}

fn tag(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, color: ui.Color) ui.RenderError!void {
    var tag_style = appStyle();
    tag_style.accent = color;
    try components.renderComponent(scene, bounds, .{ .badge = .{
        .label = label,
    } }, .{ .style = tag_style });
}

fn paragraph(scene: *ui.Scene, bounds: ui.Rect, value: []const u8) ui.RenderError!void {
    try scene.pushWrappedText(bounds, value, palette.dim, .{ .line_height = line_h, .average_char_width = 10.0, .max_lines = 6 });
}

fn outlineButton(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, label: []const u8, id: u32) (ui.RenderError || interaction.Error)!void {
    try nativeComponent(scene, collector, bounds, .{ .button = .{ .id = id, .label = label, .variant = .outline } });
}

fn nativeBadge(scene: *ui.Scene, bounds: ui.Rect, label: []const u8) ui.RenderError!void {
    try nativeComponentVisual(scene, bounds, .{ .badge = .{ .label = label } });
}

fn nativeCard(scene: *ui.Scene, bounds: ui.Rect, title_value: []const u8, detail_value: []const u8) ui.RenderError!void {
    try nativeComponentVisual(scene, bounds, .{ .card = .{ .title = title_value, .detail = detail_value, .variant = .elevated } });
}

fn demoFrame(scene: *ui.Scene, bounds: ui.Rect) ui.RenderError!void {
    try nativeComponentVisual(scene, bounds, .{ .card = .{ .title = "", .detail = "" } });
}

fn nativeComponent(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, component: components.Component) (ui.RenderError || interaction.Error)!void {
    try components.renderComponent(scene, bounds, component, .{ .style = appStyle() });
    try components.collectComponentInteractions(collector, bounds, component);
}

fn nativeComponentVisual(scene: *ui.Scene, bounds: ui.Rect, component: components.Component) ui.RenderError!void {
    try components.renderComponent(scene, bounds, component, .{ .style = appStyle() });
}

fn appStyle() ui.Style {
    var resolved = app_chrome.style();
    resolved.panel = palette.card;
    resolved.row = palette.card_alt;
    return resolved;
}

fn fill(scene: *ui.Scene, bounds: ui.Rect, color: ui.Color, r: f32) ui.RenderError!void {
    try scene.pushRect(bounds, color, .fill, r, 0.0);
}

fn text(scene: *ui.Scene, x: f32, y: f32, w: f32, h: f32, value: []const u8, color: ui.Color) ui.RenderError!void {
    try scene.pushAlignedText(ui.Rect.init(x, y, @max(1.0, w), @max(1.0, h)), value, color, .start);
}

fn alignedText(scene: *ui.Scene, x: f32, y: f32, w: f32, h: f32, value: []const u8, color: ui.Color, alignment: ui.TextAlign) ui.RenderError!void {
    try scene.pushAlignedText(ui.Rect.init(x, y, @max(1.0, w), @max(1.0, h)), value, color, alignment);
}

fn iconQuad(scene: *ui.Scene, bounds: ui.Rect, value: icon.Icon, color: ui.Color) ui.RenderError!void {
    try scene.pushIconQuad(.{ .bounds = bounds, .icon_id = icon.id(value), .color = color });
}

fn hit(collector: *interaction.Collector, bounds: ui.Rect, kind: ui.HitKind, id: u32) interaction.Error!void {
    try collector.add(.{ .slot = 0, .kind = kind, .id = id, .bounds = bounds });
}

fn centered(bounds: ui.Rect, max_w: f32) ui.Rect {
    const width = @min(max_w, @max(1.0, bounds.w - content_pad * 2.0));
    return ui.Rect.init(bounds.x + (bounds.w - width) * 0.5, bounds.y, width, bounds.h);
}

fn colBounds(bounds: ui.Rect, cols: usize, gap: f32, col: usize, y: f32, h: f32) ui.Rect {
    const width = (bounds.w - gap * @as(f32, @floatFromInt(cols - 1))) / @as(f32, @floatFromInt(cols));
    return ui.Rect.init(bounds.x + @as(f32, @floatFromInt(col)) * (width + gap), y, width, h);
}

test "blog renders committed post index through native components" {
    var commands: [4096]ui.Command = undefined;
    var clips: [8]ui.Rect = undefined;
    var regions: [512]interaction.Region = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var collector = interaction.Collector.init(&regions);
    try render(&scene, &collector, ui.Rect.init(0, 0, 1280, 1800), .{});

    try std.testing.expectEqualStrings("EdgeRun Academy", season_title);
    try std.testing.expectEqual(posts.len, arc_accounting_end);
    try std.testing.expect(hasText(scene.written(), "Computers Are"));
    try std.testing.expect(hasText(scene.written(), "Not Magic"));
    try std.testing.expect(hasText(scene.written(), "EDGERUN ACADEMY"));
    try std.testing.expect(hasText(scene.written(), "HOW TO READ"));
    try std.testing.expect(hasText(scene.written(), "3. Own"));
    try std.testing.expect(hasText(scene.written(), posts[0].title));
    try std.testing.expect(postById(postIdAt(posts.len - 1)) != null);
    try std.testing.expectEqualStrings("Authority Is Not A Vibe. It Is A Receipt Chain.", posts[posts.len - 1].title);
    try std.testing.expectEqualStrings(arc_local, posts[0].arc);
    try std.testing.expectEqualStrings(arc_network, posts[10].arc);
    try std.testing.expectEqualStrings(arc_device, posts[21].arc);
    try std.testing.expectEqualStrings(arc_control, posts[34].arc);
    try std.testing.expectEqualStrings(arc_accounting, posts[61].arc);
    try std.testing.expect(hasHit(collector.written(), postIdAt(0)));
    try std.testing.expect(hasHit(collector.written(), app_chrome.blog_button_id));
    try std.testing.expect(hasHit(collector.written(), app_chrome.logo_button_id));
    try std.testing.expect(hasHit(collector.written(), all_lessons_button_id));
    try std.testing.expect(hasHit(collector.written(), arcFilterButtonId(0)));
    try std.testing.expect(hasImage(scene.written(), cloud_meme_image_id));
}

test "blog posts follow shared teaching format" {
    for (posts) |post| {
        try std.testing.expect(std.mem.startsWith(u8, post.body, "# "));
        try std.testing.expect(markdownSectionCount(post.body) >= 4);
        try std.testing.expect(hasMarkdownCallout(post.body));
        try std.testing.expect(contains(post.body, "[[demo:"));
        try std.testing.expect(contains(post.body, "\n## Main lesson\n"));
        try std.testing.expect(contains(post.body, "\n## EdgeRun seed\n"));
        try std.testing.expect(!contains(post.body, "\n## Main Lesson\n"));
        try std.testing.expect(!contains(post.body, "\n## EdgeRun Seed\n"));
        try std.testing.expect(!contains(post.body, "\n## Edgerun seed\n"));
        try std.testing.expect(!contains(post.body, "\n## Interactive Demo\n"));
        try std.testing.expect(!contains(post.body, "\n## The Path\n"));
        try std.testing.expect(!contains(post.body, "\n## The Problem\n"));
        try std.testing.expect(!contains(post.body, "\n## The Border\n"));
        try std.testing.expect(!contains(post.body, "Edgerun"));
    }
}

test "blog post list rows expand for wrapped titles and summaries" {
    const short_post = Post{
        .arc = arc_local,
        .title = "Short title",
        .date = "2026-05-24",
        .category = "test",
        .demo = "demo",
        .summary = "Short summary.",
        .body = "# Short title\n\nBody.",
    };
    const long_post = Post{
        .arc = arc_control,
        .title = "A Long Episode Title Should Stay Readable On Narrow Blog Lists",
        .date = "2026-05-24",
        .category = "test",
        .demo = "demo",
        .summary = "This summary is long enough to wrap into a second line when the reader uses a narrow viewport.",
        .body = "# Long\n\nBody.",
    };

    const short_h = postListItemHeight(320.0, 0, short_post);
    const long_h = postListItemHeight(320.0, 1, long_post);
    try std.testing.expect(long_h > short_h);

    var commands: [64]ui.Command = undefined;
    var regions: [8]interaction.Region = undefined;
    var scene = ui.Scene.init(&commands);
    var collector = interaction.Collector.init(&regions);
    try renderPostListItem(&scene, &collector, ui.Rect.init(0.0, 0.0, 320.0, long_h), 1, long_post);
    try std.testing.expect(hasHit(collector.written(), postIdAt(1)));
}

test "blog renders authoring guide after expanded season index" {
    var commands: [4096]ui.Command = undefined;
    var clips: [8]ui.Rect = undefined;
    var regions: [512]interaction.Region = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var collector = interaction.Collector.init(&regions);
    try render(&scene, &collector, ui.Rect.init(0, 0, 1280, 1800), .{ .scroll_y = indexContentHeight(1280.0) - 1600.0 });

    try std.testing.expect(textWithin(scene.written(), "Start at the phone. End with user-owned authority.", ui.Rect.init(0, 64.0, 1280.0, 1736.0)));
    try std.testing.expect(textWithin(scene.written(), "05 accounting and resources", ui.Rect.init(0, 64.0, 1280.0, 1736.0)));
}

test "blog node map scrolls with page content" {
    var commands_top: [4096]ui.Command = undefined;
    var clips_top: [8]ui.Rect = undefined;
    var regions_top: [512]interaction.Region = undefined;
    var scene_top = ui.Scene.initWithClips(&commands_top, &clips_top);
    var collector_top = interaction.Collector.init(&regions_top);
    try render(&scene_top, &collector_top, ui.Rect.init(0, 0, 1280, 900), .{});

    const scroll_delta = node_map_grid * @as(f32, @floatFromInt(node_map_pattern_divisor));
    var commands_scrolled: [4096]ui.Command = undefined;
    var clips_scrolled: [8]ui.Rect = undefined;
    var regions_scrolled: [512]interaction.Region = undefined;
    var scene_scrolled = ui.Scene.initWithClips(&commands_scrolled, &clips_scrolled);
    var collector_scrolled = interaction.Collector.init(&regions_scrolled);
    try render(&scene_scrolled, &collector_scrolled, ui.Rect.init(0, 0, 1280, 900), .{ .scroll_y = scroll_delta });

    const first_top = firstNodeMapDot(scene_top.written()).?;
    const first_scrolled = firstNodeMapDot(scene_scrolled.written()).?;
    try std.testing.expectApproxEqAbs(first_top.y - scroll_delta, first_scrolled.y, 0.01);
}

test "blog renders selected markdown post body" {
    var commands: [4096]ui.Command = undefined;
    var clips: [8]ui.Rect = undefined;
    var regions: [512]interaction.Region = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var collector = interaction.Collector.init(&regions);
    try render(&scene, &collector, ui.Rect.init(0, 0, 1280, 3600), .{ .selected_post_id = postIdAt(0) });

    try std.testing.expect(hasText(scene.written(), "All Lessons"));
    try std.testing.expect(std.mem.startsWith(u8, bodyWithoutTitle(posts[0].body), "Before your message"));
    try std.testing.expect(hasText(scene.written(), "The city model"));
    try std.testing.expect(hasTextPrefix(scene.written(), "The trick: before blaming"));
    try std.testing.expect(hasText(scene.written(), "Learning path"));
    try std.testing.expect(hasText(scene.written(), "LESSON"));
    try std.testing.expect(hasText(scene.written(), posts[0].category));
    try std.testing.expect(hasText(scene.written(), "Interactive model"));
    try std.testing.expect(hasText(scene.written(), "Visible action"));
    try std.testing.expect(hasText(scene.written(), "Authority shift"));
    try std.testing.expect(hasText(scene.written(), "User-owned shape"));
    try std.testing.expect(hasText(scene.written(), "Starts with"));
    try std.testing.expect(hasText(scene.written(), "Next"));
    try std.testing.expect(hasHit(collector.written(), back_button_id));
}

test "blog selected post footer links previous and next posts" {
    var commands: [4096]ui.Command = undefined;
    var clips: [8]ui.Rect = undefined;
    var regions: [512]interaction.Region = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var collector = interaction.Collector.init(&regions);
    try renderPost(&scene, &collector, ui.Rect.init(0, 0, 1180, 3200), 16, -1.0, -1.0);

    try std.testing.expect(hasText(scene.written(), "Previous"));
    try std.testing.expect(hasText(scene.written(), "Next"));
    try std.testing.expect(hasHit(collector.written(), postIdAt(15)));
    try std.testing.expect(hasHit(collector.written(), postIdAt(17)));
}

test "blog renders native demo directives inside post markup" {
    var commands: [4096]ui.Command = undefined;
    var clips: [8]ui.Rect = undefined;
    var regions: [512]interaction.Region = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var collector = interaction.Collector.init(&regions);
    try renderPost(&scene, &collector, ui.Rect.init(0, 0, 1180, 3600), 14, 520.0, 1130.0);

    try std.testing.expect(hasText(scene.written(), "Who sees what?"));
    try std.testing.expect(hasText(scene.written(), "Commercial VPN"));
    try std.testing.expect(hasText(scene.written(), "Sealed relay"));
    try std.testing.expect(hasText(scene.written(), "VPN provider"));

    scene.clear();
    collector.clear();
    try renderPost(&scene, &collector, ui.Rect.init(0, 0, 1180, 3600), 16, 560.0, 1080.0);
    try std.testing.expect(hasText(scene.written(), "The tunnel ends at the endpoint."));
    try std.testing.expect(hasText(scene.written(), "TLS endpoint"));
    try std.testing.expect(hasText(scene.written(), "plaintext after endpoint"));

    scene.clear();
    collector.clear();
    try renderPost(&scene, &collector, ui.Rect.init(0, 0, 1180, 3600), 25, 560.0, 1010.0);
    try std.testing.expect(hasText(scene.written(), "Deleting the UI copy is not deleting every copy."));
    try std.testing.expect(hasText(scene.written(), "Phone UI"));
    try std.testing.expect(hasText(scene.written(), "Analytics"));

    scene.clear();
    collector.clear();
    try renderPost(&scene, &collector, ui.Rect.init(0, 0, 1180, 3600), 23, 150.0, 1020.0);
    try std.testing.expect(hasText(scene.written(), "Your phone correlates signals. It does not own you."));
    try std.testing.expect(hasText(scene.written(), "PIN / biometric"));
    try std.testing.expect(hasText(scene.written(), "Service decides: accepted or rejected"));

    scene.clear();
    collector.clear();
    try renderPost(&scene, &collector, ui.Rect.init(0, 0, 1180, 3600), 27, 150.0, 1018.0);
    try std.testing.expect(hasText(scene.written(), "Powerful hardware, gated authority."));
    try std.testing.expect(hasText(scene.written(), "Bootloader"));
    try std.testing.expect(hasText(scene.written(), "Any rung can block it."));

    scene.clear();
    collector.clear();
    try renderPost(&scene, &collector, ui.Rect.init(0, 0, 1180, 3600), 15, 260.0, 1040.0);
    try std.testing.expect(hasText(scene.written(), "A name is a lookup, not an identity."));
    try std.testing.expect(hasText(scene.written(), "friend.example"));
    try std.testing.expect(hasText(scene.written(), "Certificate control still starts with name control."));

    scene.clear();
    collector.clear();
    try renderPost(&scene, &collector, ui.Rect.init(0, 0, 1180, 3600), 24, 520.0, 1038.0);
    try std.testing.expect(hasText(scene.written(), "Account permission is not portable identity."));
    try std.testing.expect(hasText(scene.written(), "Account root"));
    try std.testing.expect(hasText(scene.written(), "Key root"));

    scene.clear();
    collector.clear();
    try renderPost(&scene, &collector, ui.Rect.init(0, 0, 1180, 3600), 17, 240.0, 1042.0);
    try std.testing.expect(hasText(scene.written(), "The server is code, policy, queues, logs, and memory."));
    try std.testing.expect(hasText(scene.written(), "Load balancer"));
    try std.testing.expect(hasText(scene.written(), "Useful coordination becomes dangerous when it becomes the source of truth."));

    scene.clear();
    collector.clear();
    try renderPost(&scene, &collector, ui.Rect.init(0, 0, 1180, 3600), 19, 240.0, 1048.0);
    try std.testing.expect(hasText(scene.written(), "A notification is delivery plus a wakeup."));
    try std.testing.expect(hasText(scene.written(), "Platform push"));
    try std.testing.expect(hasText(scene.written(), "Metadata still exists"));

    scene.clear();
    collector.clear();
    try renderPost(&scene, &collector, ui.Rect.init(0, 0, 1180, 3600), 11, 520.0, 1052.0);
    try std.testing.expect(hasText(scene.written(), "One app icon can hide many trust paths."));
    try std.testing.expect(hasText(scene.written(), "Analytics"));
    try std.testing.expect(hasText(scene.written(), "Running code is authority, even when it arrived as a library."));

    scene.clear();
    collector.clear();
    try renderPost(&scene, &collector, ui.Rect.init(0, 0, 1180, 3600), 13, 360.0, 1110.0);
    try std.testing.expect(hasText(scene.written(), "Wi-Fi protects local air, not every later boundary."));
    try std.testing.expect(hasText(scene.written(), "Router"));
    try std.testing.expect(hasText(scene.written(), "Local trust boundary"));

    scene.clear();
    collector.clear();
    try renderPost(&scene, &collector, ui.Rect.init(0, 0, 1180, 3600), 10, 520.0, 1052.0);
    try std.testing.expect(hasText(scene.written(), "Typing is not the same as sending."));
    try std.testing.expect(hasText(scene.written(), "Send intent"));
    try std.testing.expect(hasText(scene.written(), "Commit boundary"));

    scene.clear();
    collector.clear();
    try renderPost(&scene, &collector, ui.Rect.init(0, 0, 1180, 3600), 12, 520.0, 1044.0);
    try std.testing.expect(hasText(scene.written(), "Small personal workloads fit on the device."));
    try std.testing.expect(hasText(scene.written(), "Your device"));
    try std.testing.expect(hasText(scene.written(), "local first -> sync when needed -> cloud only when useful"));

    scene.clear();
    collector.clear();
    try renderPost(&scene, &collector, ui.Rect.init(0, 0, 1180, 3600), 3, 520.0, 1040.0);
    try std.testing.expect(hasText(scene.written(), "Bytes need ownership rules."));
    try std.testing.expect(hasText(scene.written(), "Sealed object"));
    try std.testing.expect(hasText(scene.written(), "sealed object -> portable verified state"));

    scene.clear();
    collector.clear();
    try renderPost(&scene, &collector, ui.Rect.init(0, 0, 1180, 3600), 8, 520.0, 1040.0);
    try std.testing.expect(hasText(scene.written(), "A root of trust must answer: root for whom?"));
    try std.testing.expect(hasText(scene.written(), "TPM key"));
    try std.testing.expect(hasText(scene.written(), "mechanism is not enough: ask who enrolls, recovers, and overrides"));

    scene.clear();
    collector.clear();
    try renderPost(&scene, &collector, ui.Rect.init(0, 0, 1180, 3600), posts.len - 1, -1.0, -1.0);
    try std.testing.expect(hasText(scene.written(), "AUTHORITY FLOW"));
    try std.testing.expect(hasText(scene.written(), "Relay"));
    try std.testing.expect(hasText(scene.written(), "TPM"));
}

test "blog demo and callout frames use canonical card surfaces" {
    var commands: [256]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try renderAuthorityFlowDemo(&scene, ui.Rect.init(0, 0, 640, 260), -1.0, -1.0);
    try std.testing.expect(hasRectColor(scene.written(), appStyle().panel));
    try std.testing.expect(hasRectColor(scene.written(), appStyle().border));
    try std.testing.expect(hasText(scene.written(), "AUTHORITY FLOW"));

    scene.clear();
    try callout(&scene, ui.Rect.init(0, 0, 420, 82), "A receipt has to say who asked and what changed.");
    try std.testing.expect(hasRectColor(scene.written(), palette.card_alt));
    try std.testing.expect(hasRectColor(scene.written(), palette.primary));
}

fn hasText(commands: []const ui.Command, value: []const u8) bool {
    for (commands) |command| switch (command) {
        .text => |text_command| if (std.mem.eql(u8, text_command.value, value)) return true,
        else => {},
    };
    return false;
}

fn hasRectColor(commands: []const ui.Command, color: ui.Color) bool {
    for (commands) |command| switch (command) {
        .rect => |rect| if (std.meta.eql(rect.color, color)) return true,
        else => {},
    };
    return false;
}

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

fn markdownSectionCount(source: []const u8) usize {
    var count: usize = 0;
    var it = std.mem.splitScalar(u8, source, '\n');
    while (it.next()) |line| {
        if (std.mem.startsWith(u8, line, "## ")) count += 1;
    }
    return count;
}

fn hasMarkdownCallout(source: []const u8) bool {
    if (std.mem.startsWith(u8, source, "> ")) return true;
    return contains(source, "\n> ");
}

fn hasTextPrefix(commands: []const ui.Command, value: []const u8) bool {
    for (commands) |command| switch (command) {
        .text => |text_command| if (std.mem.startsWith(u8, text_command.value, value)) return true,
        else => {},
    };
    return false;
}

fn hasHit(regions: []const interaction.Region, id: u32) bool {
    for (regions) |region| {
        if (region.id == id) return true;
    }
    return false;
}

fn hasImage(commands: []const ui.Command, id: u32) bool {
    for (commands) |command| switch (command) {
        .image_quad => |quad| if (quad.atlas_id == id) return true,
        else => {},
    };
    return false;
}

fn firstNodeMapDot(commands: []const ui.Command) ?ui.Rect {
    for (commands) |command| switch (command) {
        .rect => |rect_command| {
            if (rect_command.bounds.w == node_map_dot_size and rect_command.bounds.h == node_map_dot_size and rect_command.color.a == node_map_dot_alpha) return rect_command.bounds;
        },
        else => {},
    };
    return null;
}

fn textWithin(commands: []const ui.Command, value: []const u8, bounds: ui.Rect) bool {
    for (commands) |command| switch (command) {
        .text => |text_command| {
            if (std.mem.eql(u8, text_command.value, value) and bounds.containsInclusive(text_command.origin.x, text_command.origin.y) and bounds.containsInclusive(text_command.origin.x + text_command.origin.w, text_command.origin.y + text_command.origin.h)) return true;
        },
        else => {},
    };
    return false;
}
