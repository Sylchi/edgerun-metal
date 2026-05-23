const std = @import("std");
const icon = @import("icon.zig");
const ui = @import("ui.zig");
const components = @import("ui_components.zig");
const site_landing = @import("site_landing.zig");

pub const back_button_id: u32 = 40_001;
pub const first_post_button_id: u32 = 40_100;

const header_h: f32 = 64.0;
const content_wide: f32 = 1180.0;
const content_pad: f32 = 28.0;
const workflow_w: f32 = 380.0;
const index_intro_w: f32 = 760.0;
const guide_h: f32 = 320.0;
const line_h: f32 = 18.0;
const code_line_h: f32 = 17.0;
const cloud_meme_image_id: u32 = 1;
const post_list_gap: f32 = 0.0;
const arc_overview_gap: f32 = 18.0;
const arc_overview_h: f32 = 104.0;
const section_header_h: f32 = 86.0;
const section_gap: f32 = 30.0;
const page_bottom_pad: f32 = 160.0;
const post_footer_gap: f32 = 52.0;
const post_footer_column_gap: f32 = 36.0;
const post_footer_heading_h: f32 = 34.0;
const post_footer_list_gap: f32 = 0.0;
const post_footer_neighbor_count: usize = 2;
const post_sidebar_w: f32 = 292.0;
const post_sidebar_gap: f32 = 48.0;
const post_header_top_h: f32 = 112.0;
const post_title_line_h: f32 = 44.0;
const post_title_max_lines: usize = 3;
const post_title_average_char_w: f32 = 22.0;
const post_demo_gap: f32 = 24.0;
const post_demo_h: f32 = 32.0;
const post_body_gap: f32 = 28.0;
const arc_local_start: usize = 0;
const arc_local_end: usize = 10;
const arc_network_start: usize = 10;
const arc_network_end: usize = 21;
const arc_device_start: usize = 21;
const arc_device_end: usize = 34;
const arc_control_start: usize = 34;
const arc_control_end: usize = 61;
const arc_accounting_start: usize = 61;
const arc_accounting_end: usize = 64;

pub const season_title = "Your Device Is Already a Computer";
pub const season_subtitle = "Before we talk about the internet, we need to understand the machine in your hand.";
pub const arc_local = "Arc 0: How Your Device Works";
pub const arc_network = "Arc 1: How Data Moves";
pub const arc_device = "Arc 2: Who Owns The Device?";
pub const arc_control = "Arc 3: Who Controls The Rules?";
pub const arc_accounting = "Arc 4: Who Pays And Who Profits?";

const ArcSection = struct {
    title: []const u8,
    detail: []const u8,
    start: usize,
    end: usize,
};

const arc_sections = [_]ArcSection{
    .{
        .title = arc_local,
        .detail = "CPU, RAM, storage, GPU, OS, apps, firmware, keys, and the door out of the machine.",
        .start = arc_local_start,
        .end = arc_local_end,
    },
    .{
        .title = arc_network,
        .detail = "From keypress to server: the simple message path becomes visible.",
        .start = arc_network_start,
        .end = arc_network_end,
    },
    .{
        .title = arc_device,
        .detail = "After the message arrives, the endpoint becomes the real question.",
        .start = arc_device_start,
        .end = arc_device_end,
    },
    .{
        .title = arc_control,
        .detail = "The hidden levers that rewrite attention, updates, payments, discovery, and trust.",
        .start = arc_control_start,
        .end = arc_control_end,
    },
    .{
        .title = arc_accounting,
        .detail = "Receipts, contribution, settlement, and why fair systems need explicit resource accounting.",
        .start = arc_accounting_start,
        .end = arc_accounting_end,
    },
};

const palette = struct {
    const bg = ui.Color{ .r = 11, .g = 11, .b = 11 };
    const card = ui.Color{ .r = 18, .g = 18, .b = 18, .a = 238 };
    const card_alt = ui.Color{ .r = 24, .g = 24, .b = 24, .a = 224 };
    const border = ui.Color{ .r = 56, .g = 56, .b = 56 };
    const text = ui.Color{ .r = 242, .g = 242, .b = 242 };
    const dim = ui.Color{ .r = 154, .g = 154, .b = 154 };
    const primary = ui.Color{ .r = 74, .g = 222, .b = 128 };
    const primary_soft = ui.Color{ .r = 74, .g = 222, .b = 128, .a = 34 };
    const blue = ui.Color{ .r = 96, .g = 165, .b = 250 };
};

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
};

pub fn render(scene: *ui.Scene, bounds: ui.Rect, state: State) ui.RenderError!void {
    try fill(scene, bounds, palette.bg, 0.0);
    try renderNodeMap(scene, ui.Rect.init(bounds.x, bounds.y, bounds.w, @max(bounds.h, 720.0)));

    const content = centered(bounds, content_wide);
    const page_clip = ui.Rect.init(bounds.x, bounds.y + header_h, bounds.w, @max(1.0, bounds.h - header_h));
    if (try scene.pushClip(page_clip)) {
        defer scene.popClip();

        const page_y = header_h - state.scroll_y;
        if (postIndexById(state.selected_post_id)) |index| {
            try renderPost(scene, ui.Rect.init(content.x, page_y + 52.0, content.w, 1800.0), index);
        } else {
            try renderIndex(scene, ui.Rect.init(content.x, page_y + 52.0, content.w, 1100.0));
        }
    }

    try renderHeader(scene, ui.Rect.init(bounds.x, bounds.y, bounds.w, header_h), content);
    _ = state.hover_x;
    _ = state.hover_y;
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

fn episodeAt(index: usize) usize {
    return index + 1;
}

fn renderHeader(scene: *ui.Scene, bounds: ui.Rect, content: ui.Rect) ui.RenderError!void {
    try fill(scene, bounds, palette.bg, 0.0);
    try fill(scene, ui.Rect.init(bounds.x, bounds.y + bounds.h - 1.0, bounds.w, 1.0), palette.border, 0.0);

    const logo = ui.Rect.init(content.x, bounds.y + 16.0, 32.0, 32.0);
    try fill(scene, logo, palette.primary, 7.0);
    try iconQuad(scene, logo.insetUniform(8.0), .terminal, palette.bg);
    try text(scene, logo.x + 42.0, bounds.y + 23.0, 110.0, 18.0, "EdgeRun", palette.text);

    const nav_y = bounds.y + 19.0;
    try navItem(scene, ui.Rect.init(content.x + 190.0, nav_y, 68.0, 28.0), "Docs", site_landing.docs_button_id, false);
    try navItem(scene, ui.Rect.init(content.x + 266.0, nav_y, 64.0, 28.0), "Blog", site_landing.blog_button_id, true);
    try navItem(scene, ui.Rect.init(content.x + 338.0, nav_y, 64.0, 28.0), "Apps", site_landing.apps_button_id, false);

    const launch = ui.Rect.init(content.x + content.w - 128.0, bounds.y + 16.0, 128.0, 32.0);
    try primaryButton(scene, launch, "Launch Desktop", site_landing.launch_button_id);
    const search = ui.Rect.init(launch.x - 126.0, launch.y, 112.0, 32.0);
    try outlineButton(scene, search, "Search", site_landing.search_button_id);
}

fn renderIndex(scene: *ui.Scene, bounds: ui.Rect) ui.RenderError!void {
    _ = try flowIndexContent(scene, bounds);
}

fn flowIndexContent(scene: ?*ui.Scene, bounds: ui.Rect) ui.RenderError!f32 {
    const split = bounds.w >= 980.0;
    const headline_w = if (split) @min(index_intro_w, bounds.w - workflow_w - 64.0) else bounds.w;
    const workflow_y = if (split) bounds.y + 28.0 else bounds.y + 256.0;
    const overview_y = if (split) bounds.y + 260.0 else workflow_y + 222.0;
    const intro_h: f32 = if (split) 392.0 else 602.0;

    if (scene) |target| {
        try tag(target, ui.Rect.init(bounds.x, bounds.y, 92.0, 24.0), "ARC 0", palette.primary);
        try text(target, bounds.x, bounds.y + 48.0, headline_w, 46.0, "Your Device Is", palette.text);
        try text(target, bounds.x, bounds.y + 102.0, headline_w, 46.0, "Already a Computer", palette.text);
        try paragraph(target, ui.Rect.init(bounds.x, bounds.y + 162.0, headline_w, 72.0), "Before we talk about the internet, we need to understand the machine in your hand.");

        if (split) {
            try renderCloudMeme(target, ui.Rect.init(bounds.x + bounds.w - workflow_w, workflow_y, workflow_w, 214.0));
        } else {
            try renderCloudMeme(target, ui.Rect.init(bounds.x, workflow_y, bounds.w, 198.0));
        }

        try renderArcOverview(target, ui.Rect.init(bounds.x, overview_y, bounds.w, arc_overview_h));
    }

    var next_y = bounds.y + intro_h;
    for (arc_sections) |section| {
        next_y = try flowPostSection(scene, bounds, next_y, section);
    }

    const guide_y = next_y + 90.0;
    if (scene) |target| try renderGuide(target, ui.Rect.init(bounds.x, guide_y, bounds.w, guide_h));
    return guide_y + guide_h;
}

pub fn indexContentHeight(width: f32) f32 {
    const content_w = @min(content_wide, @max(1.0, width - content_pad * 2.0));
    const measured_h = flowIndexContent(null, ui.Rect.init(0.0, 0.0, content_w, 1.0)) catch unreachable;
    return 52.0 + measured_h + page_bottom_pad;
}

pub fn postContentHeight(width: f32, post_id: u32) f32 {
    const index = postIndexById(post_id) orelse return indexContentHeight(width);
    const content_w = @min(content_wide, @max(1.0, width - content_pad * 2.0));
    const measured_h = flowPostContent(null, ui.Rect.init(0.0, 0.0, content_w, 1.0), index) catch unreachable;
    return 52.0 + measured_h + page_bottom_pad;
}

fn renderArcOverview(scene: *ui.Scene, bounds: ui.Rect) ui.RenderError!void {
    const items = [_]struct { []const u8, []const u8, []const u8 }{
        .{ "10 posts", "Your device is a computer", "CPU -> RAM -> OS" },
        .{ "11 posts", "How data moves", "keypress -> DNS -> TLS" },
        .{ "13 posts", "Who owns the device", "phone -> account -> app store" },
        .{ "27 posts", "Who controls the rules", "updates -> feeds -> AI" },
        .{ "3 posts", "Who pays", "receipts -> settlement" },
    };
    const cols: usize = if (bounds.w >= 1040.0) 5 else if (bounds.w >= 700.0) 3 else 2;
    const rows = (items.len + cols - 1) / cols;
    const card_h = (bounds.h - arc_overview_gap * @as(f32, @floatFromInt(rows - 1))) / @as(f32, @floatFromInt(rows));
    for (items, 0..) |item, index| {
        const row = index / cols;
        const col = index % cols;
        const card = colBounds(bounds, cols, arc_overview_gap, col, bounds.y + @as(f32, @floatFromInt(row)) * (card_h + arc_overview_gap), card_h);
        try fill(scene, card, palette.card_alt, 8.0);
        try text(scene, card.x + 14.0, card.y + 12.0, card.w - 28.0, 12.0, item[0], palette.primary);
        try text(scene, card.x + 14.0, card.y + 34.0, card.w - 28.0, 14.0, item[1], palette.text);
        try text(scene, card.x + 14.0, card.y + 58.0, card.w - 28.0, 11.0, item[2], palette.dim);
    }
}

fn flowPostSection(scene: ?*ui.Scene, bounds: ui.Rect, y: f32, section: ArcSection) ui.RenderError!f32 {
    if (scene) |target| {
        try text(target, bounds.x, y, bounds.w, 22.0, section.title, palette.text);
        try paragraph(target, ui.Rect.init(bounds.x, y + 32.0, @min(bounds.w, 720.0), 40.0), section.detail);
    }

    var item_y = y + section_header_h;
    for (posts[section.start..section.end], section.start..) |post, index| {
        const item_h = postListItemHeight(bounds.w, index, post);
        if (scene) |target| try renderPostListItem(target, ui.Rect.init(bounds.x, item_y, bounds.w, item_h), index, post);
        item_y += item_h + post_list_gap;
    }

    return item_y + section_gap;
}

fn renderCloudMeme(scene: *ui.Scene, bounds: ui.Rect) ui.RenderError!void {
    try fill(scene, bounds, palette.card, 8.0);
    try scene.pushImageQuad(.{
        .bounds = bounds.insetUniform(1.0),
        .atlas_id = cloud_meme_image_id,
        .color = ui.Color{ .r = 255, .g = 255, .b = 255 },
    });
    try scene.pushRect(bounds, palette.border, .border, 8.0, 0.0);
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
        try fill(scene, box, palette.primary_soft, 7.0);
        try iconQuad(scene, box.insetUniform(7.0), row[0], palette.primary);
        try text(scene, bounds.x + 60.0, y + 1.0, bounds.w - 80.0, 13.0, row[1], palette.text);
        try text(scene, bounds.x + 60.0, y + 20.0, bounds.w - 80.0, 11.0, row[2], palette.dim);
        y += 42.0;
    }
}

fn renderPostListItem(scene: *ui.Scene, bounds: ui.Rect, index: usize, post: Post) ui.RenderError!void {
    try components.renderArticleListItem(scene, bounds, .{
        .id = postIdAt(index),
        .category = episodeLabel(episodeAt(index)),
        .meta = post.arc,
        .title = post.title,
        .summary = post.summary,
    }, .{ .style = siteStyle() });
    try iconQuad(scene, ui.Rect.init(bounds.x + bounds.w - 22.0, bounds.y + (bounds.h - 16.0) * 0.5, 16.0, 16.0), .chevron_right, palette.primary);
}

fn postListItemHeight(width: f32, index: usize, post: Post) f32 {
    return components.articleListItemHeight(width, .{
        .id = postIdAt(index),
        .category = episodeLabel(episodeAt(index)),
        .meta = post.arc,
        .title = post.title,
        .summary = post.summary,
    });
}

fn renderGuide(scene: *ui.Scene, bounds: ui.Rect) ui.RenderError!void {
    const split = bounds.w >= 900.0;
    const copy_w = if (split) bounds.w * 0.46 else bounds.w - 48.0;
    const code_bounds = if (split)
        ui.Rect.init(bounds.x + bounds.w * 0.54, bounds.y + 34.0, bounds.w * 0.42, bounds.h - 68.0)
    else
        ui.Rect.init(bounds.x + 24.0, bounds.y + 178.0, bounds.w - 48.0, bounds.h - 202.0);

    try nativeCard(scene, bounds, "", "");
    try tag(scene, ui.Rect.init(bounds.x + 24.0, bounds.y + 24.0, 116.0, 24.0), "AUTHORING", palette.blue);
    try text(scene, bounds.x + 24.0, bounds.y + 70.0, bounds.w - 48.0, 24.0, "Add an episode by committing a markdown file.", palette.text);
    try paragraph(scene, ui.Rect.init(bounds.x + 24.0, bounds.y + 112.0, copy_w, 88.0), "The season engine uses repo content as its source of truth. Add markdown, register episode metadata in the native index, and the browser render path picks it up at build time.");
    try codeBlock(scene, code_bounds, &.{
        "edgerun-zig/src/blog/my-post.md",
        "",
        "# Title",
        "",
        "## Section",
        "- point",
        "```zig",
        "const value = run();",
        "```",
    });
}

fn renderPost(scene: *ui.Scene, bounds: ui.Rect, index: usize) ui.RenderError!void {
    _ = try flowPostContent(scene, bounds, index);
}

fn flowPostContent(scene: ?*ui.Scene, bounds: ui.Rect, index: usize) ui.RenderError!f32 {
    const post = posts[index];
    const sidebar_split = bounds.w >= 980.0;
    const main_w = if (sidebar_split) @max(320.0, bounds.w - post_sidebar_w - post_sidebar_gap) else bounds.w;
    const title_w = @min(main_w, 760.0);
    const title_h = wrappedTextHeight(post.title, title_w, post_title_line_h, post_title_max_lines, post_title_average_char_w);
    const demo_y = bounds.y + post_header_top_h + title_h + post_demo_gap;
    const body_y = demo_y + post_demo_h + post_body_gap;
    if (scene) |target| {
        try outlineButton(target, ui.Rect.init(bounds.x, bounds.y, 124.0, 34.0), "All Posts", back_button_id);
        try nativeBadge(target, ui.Rect.init(bounds.x, bounds.y + 62.0, 118.0, 24.0), episodeLabel(episodeAt(index)));
        try text(target, bounds.x + 136.0, bounds.y + 68.0, 280.0, 12.0, post.arc, palette.dim);
        try target.pushWrappedText(ui.Rect.init(bounds.x, bounds.y + post_header_top_h, title_w, title_h), post.title, palette.text, .{
            .line_height = post_title_line_h,
            .average_char_width = post_title_average_char_w,
            .max_lines = post_title_max_lines,
        });
        try paragraph(target, ui.Rect.init(bounds.x, demo_y, @min(main_w, 720.0), post_demo_h), post.demo);
    }

    const content = ui.Rect.init(bounds.x, body_y, @min(main_w, 820.0), 1300.0);
    const content_end = try flowMarkdown(scene, content, bodyWithoutTitle(post.body));
    const footer_y = content_end + post_footer_gap;
    const footer_h = postFooterHeight(bounds.w, index);
    if (scene) |target| {
        try renderPostFooter(target, ui.Rect.init(bounds.x, footer_y, bounds.w, footer_h), index);
        if (sidebar_split) try renderSidebar(target, ui.Rect.init(bounds.x + bounds.w - post_sidebar_w, bounds.y + post_header_top_h, post_sidebar_w, 280.0), post);
    }
    return footer_y + footer_h;
}

fn renderPostFooter(scene: *ui.Scene, bounds: ui.Rect, index: usize) ui.RenderError!void {
    const has_previous = neighborIndex(index, .previous, 0) != null;
    const has_next = neighborIndex(index, .next, 0) != null;
    if (!has_previous and !has_next) return;
    const split = bounds.w >= 760.0;
    if (split and has_previous and has_next) {
        const column_w = (bounds.w - post_footer_column_gap) * 0.5;
        const previous = ui.Rect.init(bounds.x, bounds.y, column_w, bounds.h);
        const next = ui.Rect.init(bounds.x + column_w + post_footer_column_gap, bounds.y, column_w, bounds.h);
        _ = try flowNeighborColumn(scene, previous, index, .previous);
        _ = try flowNeighborColumn(scene, next, index, .next);
        return;
    }

    var y = bounds.y;
    if (has_previous) {
        const previous = ui.Rect.init(bounds.x, y, bounds.w, bounds.h);
        y += try flowNeighborColumn(scene, previous, index, .previous) + 42.0;
    }
    if (has_next) {
        const next = ui.Rect.init(bounds.x, y, bounds.w, bounds.h);
        _ = try flowNeighborColumn(scene, next, index, .next);
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
    return flowNeighborColumn(null, ui.Rect.init(0.0, 0.0, width, 1.0), index, direction) catch unreachable;
}

fn flowNeighborColumn(scene: ?*ui.Scene, bounds: ui.Rect, index: usize, direction: NeighborDirection) ui.RenderError!f32 {
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
        if (scene) |target| try renderPostListItem(target, ui.Rect.init(bounds.x, y, bounds.w, item_h), neighbor_index, neighbor);
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

fn renderSidebar(scene: *ui.Scene, bounds: ui.Rect, post: Post) ui.RenderError!void {
    if (bounds.x < 880.0) return;
    try nativeCard(scene, bounds, "", "");
    try text(scene, bounds.x + 20.0, bounds.y + 20.0, bounds.w - 40.0, 16.0, "Interactive Demo", palette.text);
    try paragraph(scene, ui.Rect.init(bounds.x + 20.0, bounds.y + 54.0, bounds.w - 40.0, 58.0), post.demo);
    try fill(scene, ui.Rect.init(bounds.x + 20.0, bounds.y + 134.0, bounds.w - 40.0, 1.0), palette.border, 0.0);
    try text(scene, bounds.x + 20.0, bounds.y + 158.0, bounds.w - 40.0, 12.0, "Arc", palette.dim);
    try paragraph(scene, ui.Rect.init(bounds.x + 20.0, bounds.y + 184.0, bounds.w - 40.0, 42.0), post.arc);
    try text(scene, bounds.x + 20.0, bounds.y + 236.0, bounds.w - 40.0, 12.0, post.date, palette.text);
}

fn flowMarkdown(scene: ?*ui.Scene, bounds: ui.Rect, source: []const u8) ui.RenderError!f32 {
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
        } else {
            if (scene) |target| try paragraph(target, ui.Rect.init(bounds.x, y, bounds.w, 76.0), line_value);
            y += paragraphHeight(line_value, bounds.w) + 14.0;
        }
    }
    return y;
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

fn wrappedTextHeight(value: []const u8, width: f32, line_height_value: f32, max_lines: usize, average_char_width: f32) f32 {
    const chars_per_line = @max(@as(usize, 1), @as(usize, @intFromFloat(width / average_char_width)));
    const lines = @max(@as(usize, 1), @min(max_lines, (value.len + chars_per_line - 1) / chars_per_line));
    return line_height_value * @as(f32, @floatFromInt(lines));
}

fn episodeLabel(episode: usize) []const u8 {
    if (episode == 0 or episode > episode_labels.len) return "Episode";
    return episode_labels[episode - 1];
}

fn codeBlock(scene: *ui.Scene, bounds: ui.Rect, lines: []const []const u8) ui.RenderError!void {
    try components.renderCodeBlock(scene, bounds, .{ .lines = lines }, .{ .style = siteStyle() });
}

fn renderNodeMap(scene: *ui.Scene, bounds: ui.Rect) ui.RenderError!void {
    const grid: f32 = 26.0;
    var x = bounds.x;
    while (x < bounds.x + bounds.w) : (x += grid) {
        var y = bounds.y;
        while (y < bounds.y + bounds.h) : (y += grid) {
            if (@mod(@as(i32, @intFromFloat(x + y)), 7) == 0) {
                try fill(scene, ui.Rect.init(x, y, 2.0, 2.0), ui.Color{ .r = 255, .g = 255, .b = 255, .a = 10 }, 1.0);
            }
        }
    }
}

fn navItem(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, id: u32, active: bool) ui.RenderError!void {
    if (active) try fill(scene, bounds, ui.Color{ .r = 74, .g = 222, .b = 128, .a = 22 }, 6.0);
    try alignedText(scene, bounds.x, bounds.y + 7.0, bounds.w, 12.0, label, if (active) palette.primary else palette.dim, .center);
    try hit(scene, bounds, .button, id);
}

fn tag(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, color: ui.Color) ui.RenderError!void {
    var soft = color;
    soft.a = 34;
    try fill(scene, bounds, soft, 5.0);
    try alignedText(scene, bounds.x + 8.0, bounds.y + 6.0, bounds.w - 16.0, 10.0, label, color, .center);
}

fn paragraph(scene: *ui.Scene, bounds: ui.Rect, value: []const u8) ui.RenderError!void {
    try scene.pushWrappedText(bounds, value, palette.dim, .{ .line_height = line_h, .average_char_width = 10.0, .max_lines = 6 });
}

fn primaryButton(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, id: u32) ui.RenderError!void {
    try nativeComponent(scene, bounds, .{ .button = .{ .id = id, .label = label } }, .{ .button_variant = .primary });
}

fn outlineButton(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, id: u32) ui.RenderError!void {
    try nativeComponent(scene, bounds, .{ .button = .{ .id = id, .label = label } }, .{ .button_variant = .outline });
}

fn nativeBadge(scene: *ui.Scene, bounds: ui.Rect, label: []const u8) ui.RenderError!void {
    try nativeComponent(scene, bounds, .{ .badge = .{ .label = label } }, .{ .badge_variant = .accent });
}

fn nativeCard(scene: *ui.Scene, bounds: ui.Rect, title_value: []const u8, detail_value: []const u8) ui.RenderError!void {
    try nativeComponent(scene, bounds, .{ .card = .{ .title = title_value, .detail = detail_value } }, .{ .surface_variant = .elevated });
}

fn nativeComponent(scene: *ui.Scene, bounds: ui.Rect, component: components.Component, options: components.RenderOptions) ui.RenderError!void {
    var resolved = options;
    resolved.style = siteStyle();
    try components.renderComponent(scene, bounds, component, resolved);
}

fn siteStyle() ui.Style {
    return .{
        .bg = palette.bg,
        .panel = palette.card,
        .row = palette.card_alt,
        .border = palette.border,
        .text = palette.text,
        .muted = palette.dim,
        .accent = palette.primary,
    };
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
    try scene.pushIconQuad(.{ .bounds = bounds, .atlas_id = icon.atlasId(value), .color = color });
}

fn hit(scene: *ui.Scene, bounds: ui.Rect, kind: ui.HitKind, id: u32) ui.RenderError!void {
    try scene.pushHit(.{ .slot = 0, .kind = kind, .id = id, .bounds = bounds });
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
    var scene = ui.Scene.initWithClips(&commands, &clips);
    try render(&scene, ui.Rect.init(0, 0, 1280, 1800), .{});

    try std.testing.expectEqual(posts.len, arc_accounting_end);
    try std.testing.expect(hasText(scene.written(), "Your Device Is"));
    try std.testing.expect(hasText(scene.written(), "Already a Computer"));
    try std.testing.expect(hasText(scene.written(), posts[0].title));
    try std.testing.expect(postById(postIdAt(posts.len - 1)) != null);
    try std.testing.expectEqualStrings(arc_local, posts[0].arc);
    try std.testing.expectEqualStrings(arc_network, posts[10].arc);
    try std.testing.expectEqualStrings(arc_device, posts[21].arc);
    try std.testing.expectEqualStrings(arc_control, posts[34].arc);
    try std.testing.expectEqualStrings(arc_accounting, posts[61].arc);
    try std.testing.expect(hasHit(scene.written(), postIdAt(0)));
    try std.testing.expect(hasHit(scene.written(), site_landing.blog_button_id));
    try std.testing.expect(hasImage(scene.written(), cloud_meme_image_id));
}

test "blog renders authoring guide after expanded season index" {
    var commands: [4096]ui.Command = undefined;
    var clips: [8]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    try render(&scene, ui.Rect.init(0, 0, 1280, 1800), .{ .scroll_y = indexContentHeight(1280.0) - 1600.0 });

    try std.testing.expect(textWithin(scene.written(), "Add an episode by committing a markdown file.", ui.Rect.init(0, 64.0, 1280.0, 1736.0)));
    try std.testing.expect(textWithin(scene.written(), "const value = run();", ui.Rect.init(0, 64.0, 1280.0, 1736.0)));
}

test "blog renders selected markdown post body" {
    var commands: [4096]ui.Command = undefined;
    var clips: [8]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    try render(&scene, ui.Rect.init(0, 0, 1280, 1400), .{ .selected_post_id = postIdAt(0) });

    try std.testing.expect(hasText(scene.written(), "All Posts"));
    try std.testing.expect(std.mem.startsWith(u8, bodyWithoutTitle(posts[0].body), "Before your message"));
    try std.testing.expect(hasText(scene.written(), "The city model"));
    try std.testing.expect(hasHit(scene.written(), back_button_id));
}

test "blog selected post footer links previous and next posts" {
    var commands: [4096]ui.Command = undefined;
    var clips: [8]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    try renderPost(&scene, ui.Rect.init(0, 0, 1180, 3200), 16);

    try std.testing.expect(hasText(scene.written(), "Previous"));
    try std.testing.expect(hasText(scene.written(), "Next"));
    try std.testing.expect(hasHit(scene.written(), postIdAt(15)));
    try std.testing.expect(hasHit(scene.written(), postIdAt(17)));
}

fn hasText(commands: []const ui.Command, value: []const u8) bool {
    for (commands) |command| switch (command) {
        .text => |text_command| if (std.mem.eql(u8, text_command.value, value)) return true,
        else => {},
    };
    return false;
}

fn hasHit(commands: []const ui.Command, id: u32) bool {
    for (commands) |command| switch (command) {
        .hit => |hit_command| if (hit_command.id == id) return true,
        else => {},
    };
    return false;
}

fn hasImage(commands: []const ui.Command, id: u32) bool {
    for (commands) |command| switch (command) {
        .image_quad => |quad| if (quad.atlas_id == id) return true,
        else => {},
    };
    return false;
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
