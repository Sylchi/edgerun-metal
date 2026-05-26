const std = @import("std");
const icon = @import("icon.zig");
const interaction = @import("ui_interaction.zig");
const ui = @import("ui.zig");
const components = @import("ui/components/Component.zig");
const component_gallery = @import("component_gallery.zig");
const app_blog = @import("app_blog.zig");
const app_chrome = @import("app_chrome.zig");
const design = @import("app_design.zig");
const app_layout = @import("app_layout.zig");

const DocsError = ui.RenderError || interaction.Error || component_gallery.GalleryError;

pub const component_catalog_button_id: u32 = 31_001;
pub const academy_button_id: u32 = 31_002;
pub const source_button_id: u32 = 31_003;
pub const first_doc_page_button_id: u32 = 31_200;

const header_h: f32 = app_chrome.header_h;
const content_wide: f32 = design.content_wide;
const page_top_pad: f32 = 34.0;
const page_bottom_pad: f32 = 120.0;
const sidebar_w: f32 = 264.0;
const sidebar_gap: f32 = 34.0;
const panel_radius: f32 = app_chrome.surface_radius;
const panel_gap: f32 = 14.0;
const compact_w: f32 = 820.0;
const card_pad: f32 = 18.0;
const row_h: f32 = 38.0;
const section_gap: f32 = 36.0;
const hero_min_h: f32 = 220.0;
const hero_label_h: f32 = 26.0;
const hero_title_line_h: f32 = 34.0;
const hero_title_avg_w: f32 = 16.0;
const hero_title_max_lines: usize = 2;
const hero_summary_line_h: f32 = 20.0;
const hero_summary_avg_w: f32 = 9.4;
const hero_summary_max_lines: usize = 4;
const hero_button_gap: f32 = 22.0;
const hero_action_min_w: f32 = 132.0;
const intro_title_h: f32 = 22.0;
const intro_gap: f32 = 10.0;
const intro_body_line_h: f32 = 18.0;
const intro_body_avg_w: f32 = 9.0;
const intro_body_max_lines: usize = 3;
const feature_title_h: f32 = 16.0;
const feature_summary_line_h: f32 = 16.0;
const feature_summary_avg_w: f32 = 8.4;
const feature_summary_max_lines: usize = 4;
const detail_title_h: f32 = 16.0;
const detail_body_line_h: f32 = 17.0;
const detail_body_avg_w: f32 = 8.6;
const detail_body_max_lines: usize = 6;
const code_title_h: f32 = 14.0;
const code_line_h: f32 = 20.0;
const section_block_gap: f32 = 14.0;
const section_block_title_h: f32 = 16.0;
const section_block_body_line_h: f32 = 17.0;
const section_block_body_avg_w: f32 = 8.4;
const section_block_body_max_lines: usize = 14;
const media_card_min_w: f32 = 220.0;
const media_card_h: f32 = 168.0;
const media_preview_h: f32 = 74.0;
const media_frame_gap: f32 = 8.0;
const sample_button_id: u32 = 31_101;
const sample_input_id: u32 = 31_102;
const sample_switch_id: u32 = 31_103;
const sample_tab_id: u32 = 31_104;

const palette = design.palette;
const fill = app_layout.fill;
const stroke = app_layout.stroke;
const text = app_layout.text;
const wrappedText = app_layout.wrappedTextWith;
const wrappedTextHeight = app_layout.wrappedTextHeightWith;

pub const State = struct {
    scroll_y: f32 = 0.0,
    hover_x: f32 = -1.0,
    hover_y: f32 = -1.0,
    selected_doc_index: ?usize = null,
    selected_component_index: ?usize = null,
};

pub const DocSection = enum {
    overview,
    runtime,
    routing,
    authority,
    rendering,
    components,
    media,
    fonts,
    wasm,
    storage,
    source,

    pub fn label(self: DocSection) []const u8 {
        return switch (self) {
            .overview => "Overview",
            .runtime => "Runtime",
            .routing => "Routing",
            .authority => "Authority",
            .rendering => "Rendering",
            .components => "Components",
            .media => "Media",
            .fonts => "Fonts",
            .wasm => "WASM",
            .storage => "Storage",
            .source => "Source",
        };
    }
};

pub const DocPage = struct {
    section: DocSection,
    slug: []const u8,
    route: []const u8,
    title: []const u8,
    summary: []const u8,
    status: []const u8,
    primary: []const u8,
    secondary: []const u8,
    api: []const u8,
    icon_value: icon.Icon,
    color: ui.Color,
};

const DocBlock = struct {
    title: []const u8,
    body: []const u8,
    code: []const u8 = "",
};

const runtime_blocks = [_]DocBlock{
    .{ .title = "Single app frame", .body = "Every host enters the same app through app_frame.render. Web, Wayland SHM, Wayland EGL, DRM, snapshots, and tests provide a rectangle and route state; they do not pick a separate product UI.", .code = "app_frame.render(scene, collector, bounds, state)\napp_frame.contentHeight(width, state)" },
    .{ .title = "Host responsibilities", .body = "Hosts own window creation, input collection, presentation, and resource upload. The app owns scene commands, interaction regions, scroll state, route state, and the visible content." },
    .{ .title = "Build contract", .body = "The app runtime artifact and the native window must compile the same app modules. The make wayland-window path builds app-runtime first, then launches the Wayland host against the same app frame." },
};

const routing_blocks = [_]DocBlock{
    .{ .title = "Route object", .body = "app_navigation.Route is the only app route shape. It carries the top-level view plus selected blog post, docs page, component page, and Academy filter state." },
    .{ .title = "Host route bridge", .body = "A host can pass route bytes into WASM, but the app parses those bytes with app_navigation.fromPath and writes canonical route strings back with writeHash. Host glue does not choose app views." },
    .{ .title = "Native route", .body = "Native hosts parse the same path strings and pass the resulting Route into app_frame. Header buttons, docs rows, catalog cards, and host route bytes all converge on the same route transition code.", .code = "/docs/fonts -> docs page: fonts\n/docs/components -> component catalog\n/docs/components/button -> component page: button" },
};

const authority_blocks = [_]DocBlock{
    .{ .title = "No ambient authority", .body = "Authority is represented by explicit objects, principals, receipts, and host-mediated transitions. An app should not gain storage, child memory, native execution, or user approval because it can call a global function.", .code = "ExecutionHost.spawnManifest(...)\nApp.shareMemoryReadOnly(...)\nobject.View.decode(canonical_bytes)" },
    .{ .title = "Object boundary", .body = "Stored or transferred data crosses boundaries as canonical EdgeRun object bytes. Callers verify object headers and typed bodies instead of inventing identity from arbitrary raw buffers." },
    .{ .title = "Receipts", .body = "Receipts bind the actor, subject, clock window, manifest, and consequence. They are meant to make authority transitions inspectable and replay-resistant instead of relying on logs or comments." },
};

const rendering_blocks = [_]DocBlock{
    .{ .title = "Scene first", .body = "UI code emits ui.Scene commands and interaction regions. The scene is the product UI contract; it is independent of whether pixels are eventually produced by software, GPU buffers, GLES, or native presentation.", .code = "ui.Scene.pushRect(...)\nui.Scene.pushWrappedText(...)\nui.Scene.pushImageQuad(...)" },
    .{ .title = "Render IR", .body = "render.pipeline.packScene converts scene commands into packed rectangles, text vertices, icon vertices, image vertices, and overlay buffers. Backends consume those buffers and declared resources." },
    .{ .title = "Backend boundary", .body = "Backends own storage, textures, damage, and presentation receipts. They must not duplicate product UI decisions, docs pages, components, or route logic." },
};

const component_blocks = [_]DocBlock{
    .{ .title = "Catalog as public vocabulary", .body = "component_gallery.component_catalog is the visible list of components compiled into the app. Catalog cards and opened component pages render from the same component specifications.", .code = "route: /docs/components\nsubsection: /docs/components/<slug>\nsource: component_gallery.component_catalog" },
    .{ .title = "Component object path", .body = "Components serialize to canonical component objects, render through shared component render helpers, and collect hit targets through component interaction helpers." },
    .{ .title = "Opened component page", .body = "Each /docs/components/<slug> page shows the actual component renderings plus the API and contract. It is not a static screenshot or separate demo renderer." },
};

const media_blocks = [_]DocBlock{
    .{ .title = "Owned decode", .body = "Media should be decoded by repo-owned code into EdgeRun drawing data. The host may present pixels, but hidden host decoders should not become part of the app contract.", .code = "src/media/png.zig\nsrc/media/jpeg.zig\nsrc/media/tga.zig\nsrc/media/webp/root.zig" },
    .{ .title = "Icons", .body = "Icon names map to semantic icon ids. SVG/vector parsing turns repo assets into renderer data so the same icon appears in web host and native paths.", .code = "icon_svg.Iterator\nicon_vector.Iterator\nui.Scene.pushIconQuad(...)" },
    .{ .title = "Images and video", .body = "Images move through image decode and renderer image vertices. Video work is staged around deterministic frame decode so media can be demonstrated without depending on platform players.", .code = "src/media/video_ivf.zig\nsrc/media/video_webm.zig\nsrc/media/vp8.zig\nui.Scene.pushImageQuad(...)" },
};

const font_blocks = [_]DocBlock{
    .{ .title = "Embedded asset", .body = "The font system starts with varfont.geist_bytes, an embedded Geist variable font file. The app does not ask the host, desktop, or OS for the user's installed font stack." },
    .{ .title = "Parser and metrics", .body = "varfont.Face.geist parses the TTF tables that EdgeRun supports, including glyph outlines, metrics, variation axes, and kerning. Text measurement uses those metrics before any backend sees a vertex." },
    .{ .title = "Compiled font object", .body = "render/font_atlas can compile the supported ASCII codepoints into a font_vector.Body. That gives the renderer an object-font path where glyph commands, metrics, and advances are owned data." },
    .{ .title = "Atlas bake", .body = "The atlas path rasterizes glyphs into a 2048x2048 alpha8 texture with room for 1280 cached glyphs. Glyphs are cached by character and pixel size; small text alpha is sharpened during bake." },
    .{ .title = "Render consumption", .body = "render.ir.FontAtlas exposes metrics, text width, and glyph lookup callbacks. packScene turns text commands into textured glyph quads. Software, GLES, web, and native hosts consume the same alpha atlas resource.", .code = "ui.Scene text\n-> render.ir.FontAtlas callbacks\n-> packed text vertices\n-> alpha texture in backend" },
};

const wasm_blocks = [_]DocBlock{
    .{ .title = "Normal execution target", .body = "WASM is the default app execution format. It gives the runtime a deterministic module boundary instead of native ambient access to files, sockets, or OS process APIs.", .code = "src/wasm/root.zig\nwasm magic: 00 61 73 6d\nnormal apps: wasm only" },
    .{ .title = "Compiler path", .body = "The source route owns the embedded source workspace, compile action, release artifact buffer, download action, and launch action. The compiler runs through the WASM interpreter path." },
    .{ .title = "Release artifact", .body = "A successful compile emits a real WASM module starting with the WASM magic bytes. That artifact can be exported or launched as another app instance." },
};

const storage_blocks = [_]DocBlock{
    .{ .title = "Canonical bytes", .body = "Storage stores canonical EdgeRun objects and typed indexes. The stored bytes carry object headers and bodies that can be verified when read back.", .code = "object.View.decode(bytes)\nstore.putObject(canonical)\nstore.index(owner, key, object_id)" },
    .{ .title = "Owner scoped indexes", .body = "Indexes are scoped by owner so one app cannot silently bind another app's object as its own. Storage paths should reject targets outside the declared owner scope." },
    .{ .title = "Sealed movement", .body = "Encrypted and sealed object movement is the intended path for private app data. The user grants storage by choosing to keep or share the app/object, not by giving broad filesystem access." },
};

const source_blocks = [_]DocBlock{
    .{ .title = "Workspace in the app", .body = "The source page exposes the embedded workspace as app-owned source. Editing happens inside the EdgeRun UI route, not through a host-side editor surface.", .code = "embed_file_zig embeds reachable source\napp_source.State carries editor bytes\n/source renders the live editor" },
    .{ .title = "Compile loop", .body = "Compile, download, launch, and reset are app actions resolved inside WASM. Host glue only carries bytes for export or launching; it should not understand the source tree." },
    .{ .title = "Successor app", .body = "The goal is a successor artifact: the app can edit its own source, compile a new WASM release artifact, and launch that artifact as a new isolated instance." },
};

const overview_blocks = [_]DocBlock{
    .{ .title = "How to read these docs", .body = "Each sidebar row is a route-backed page for a real subsystem. The overview shows the map; selected sections explain their own pipeline and ownership boundary." },
    .{ .title = "One app, many hosts", .body = "The same app frame feeds web host, native Wayland, GPU, DRM, and snapshots. Host code adapts presentation; app code owns routes, documentation, source editing, components, and interactions." },
};

pub const doc_pages = [_]DocPage{
    .{
        .section = .overview,
        .slug = "overview",
        .route = "/docs",
        .title = "EdgeRun documentation",
        .summary = "The docs are the map for what exists now: runtime, authority, rendering, components, media, fonts, WASM, storage, and source.",
        .status = "system map",
        .primary = "Use the sidebar as the app manual. Each row is a real feature surface or shipped subsystem, not a placeholder page.",
        .secondary = "Components have their own route per component because their API belongs beside the rendered preview.",
        .api = "route: /docs\nframe: app_frame.render -> app_docs.render\nnavigation: app_navigation.Route.selected_doc_index",
        .icon_value = .file,
        .color = palette.primary,
    },
    .{
        .section = .runtime,
        .slug = "runtime",
        .route = "/docs/runtime",
        .title = "Runtime",
        .summary = "The app boots through one shared app frame, then routes into landing, academy, docs, components, or source.",
        .status = "shared frame",
        .primary = "Runtime pages emit EdgeRun scene commands and interaction regions. Browser, native CPU, GPU, and Wayland hosts consume the same frame contract.",
        .secondary = "The app should never decide whether it is on CPU or GPU; the host chooses the backend after the scene is produced.",
        .api = "entry: app_frame.render\nheight: app_frame.contentHeight\nroute: app_navigation.Route",
        .icon_value = .terminal,
        .color = palette.cyan,
    },
    .{
        .section = .routing,
        .slug = "routing",
        .route = "/docs/routing",
        .title = "Routing",
        .summary = "Routing is one shared contract: host route bytes, native hosts, header buttons, docs rows, and component cards all resolve to app_navigation.Route.",
        .status = "single table",
        .primary = "Every opened surface is represented as a typed route before the frame renders. Host glue only carries route bytes; it does not choose the app view.",
        .secondary = "The component catalog is a docs subsection: `/docs/components` opens the catalog and `/docs/components/<slug>` opens the selected component inside Docs.",
        .api = "/ -> landing\n/academy[/id] -> Academy\n/docs[/slug] -> Docs\n/docs/components[/slug] -> Docs component subsection\n/source -> Source",
        .icon_value = .route,
        .color = palette.green,
    },
    .{
        .section = .authority,
        .slug = "authority",
        .route = "/docs/authority",
        .title = "Authority",
        .summary = "Authority is modeled as explicit principal, receipt, object, and route transitions instead of ambient trust.",
        .status = "receipt first",
        .primary = "The current model keeps resource movement explicit: allocator grants resources, apps receive handles, storage receives canonical objects, and crossings leave receipts.",
        .secondary = "This page links the docs to the Academy path because the learning material explains why each boundary exists.",
        .api = "objects: object.zig canonical bytes\nidentity: identity.zig principal material\nreceipts: typed object receipt nodes",
        .icon_value = .shield,
        .color = palette.violet,
    },
    .{
        .section = .rendering,
        .slug = "rendering",
        .route = "/docs/rendering",
        .title = "Rendering",
        .summary = "Rendering flows from UI/component code into scene commands and renderer IR before any backend paints.",
        .status = "one contract",
        .primary = "The software, web host, GPU, and native hosts should agree because they are adapters for the same scene and IR path.",
        .secondary = "Backend-specific code owns presentation, not product UI decisions.",
        .api = "scene: ui.Scene\ncomponents: ui/components/*.zig\nrender: render.zig\nbackends: render/*",
        .icon_value = .code,
        .color = palette.blue,
    },
    .{
        .section = .components,
        .slug = "component-system",
        .route = "/docs/component-system",
        .title = "Components",
        .summary = "The component catalog is now part of Docs. The catalog page and each component subsection render the real component previews and API surface.",
        .status = "58 entries",
        .primary = "The catalog is rendered inline on this page from component_gallery.component_catalog, so Docs is the manual and the live component catalog.",
        .secondary = "Each `/docs/components/<slug>` route keeps the Docs chrome, opens the selected subsection, and renders the component through the same shared component path.",
        .api = "catalog: /docs/components\nsubsection: /docs/components/<slug>\nrender: Component.render\ninteractions: Component.collectInteractions",
        .icon_value = .app,
        .color = palette.primary,
    },
    .{
        .section = .media,
        .slug = "media",
        .route = "/docs/media",
        .title = "Media",
        .summary = "Media covers repo-owned image decode, SVG icon parsing, WebP work, video containers, and visible media render commands.",
        .status = "owned decode",
        .primary = "Icons and media are decoded into EdgeRun-owned drawing data so hosts do not become hidden rendering dependencies.",
        .secondary = "The media docs now render image and video-format cards as real scene image quads, not just a list of files.",
        .api = "svg: icon_svg.zig\nimages: media/image.zig + png/jpeg/tga/webp\nvideo: media/video_ivf.zig + video_webm.zig + vp8.zig\nrender: ui.Scene.pushImageQuad -> renderer IR image vertices",
        .icon_value = .file,
        .color = palette.amber,
    },
    .{
        .section = .fonts,
        .slug = "fonts",
        .route = "/docs/fonts",
        .title = "Fonts",
        .summary = "Fonts are owned by EdgeRun: the app embeds Geist, parses the variable font, builds an alpha atlas, and sends textured glyph quads through renderer IR.",
        .status = "owned atlas",
        .primary = "UI code emits text commands only. Font parsing, glyph metrics, kerning, rasterization, atlas packing, and backend upload stay inside the EdgeRun render pipeline.",
        .secondary = "The current path supports embedded Geist bytes and compiled font objects. Small text is sharpened during atlas bake, and software/GPU/web hosts consume the same alpha atlas resource.",
        .api = "asset: varfont.geist_bytes\nparse: varfont.Face.geist\nobject font: font_vector -> render/font_atlas\natlas: 2048x2048 alpha8, 1280 glyphs\nir: render.ir.FontAtlas -> text quads\nbackends: software/GLES/web alpha texture",
        .icon_value = .activity,
        .color = palette.green,
    },
    .{
        .section = .wasm,
        .slug = "wasm",
        .route = "/docs/wasm",
        .title = "WASM",
        .summary = "WASM is the normal app execution target and the route for subapps to run without ambient host authority.",
        .status = "sandbox path",
        .primary = "The source workspace and release flow are the visible app authoring path; runtime authority is granted by manifest and receipt.",
        .secondary = "Native execution remains special. Normal app logic should prove itself through deterministic WASM behavior.",
        .api = "source: app_source.zig\nruntime: wasm/root.zig\nroute: /source",
        .icon_value = .terminal,
        .color = palette.cyan,
    },
    .{
        .section = .storage,
        .slug = "storage",
        .route = "/docs/storage",
        .title = "Storage",
        .summary = "Storage is object based: canonical bytes, scoped ownership, typed indexes, and encrypted object movement.",
        .status = "object boundary",
        .primary = "Stored data should cross boundaries as validated EdgeRun objects, not raw buffers with invented identity.",
        .secondary = "The storage docs intentionally point at object identity and receipt semantics because those are the authority boundary.",
        .api = "object: object.View.decode\nstore: store.zig\nindex: owner-scoped app keys",
        .icon_value = .database,
        .color = palette.yellow,
    },
    .{
        .section = .source,
        .slug = "source",
        .route = "/source",
        .title = "Source",
        .summary = "The Source page is the working authoring surface for compiling and launching a release artifact.",
        .status = "live tool",
        .primary = "Source is linked from Docs because it is not a marketing promise; it is a route you can open now.",
        .secondary = "The docs describe the path, while the Source route owns the editor, compile action, release download, and launch action.",
        .api = "route: /source\nstate: app_source.State\nactions: compile, download, launch, reset",
        .icon_value = .code,
        .color = palette.blue,
    },
};

pub fn indexBySlug(slug: []const u8) ?usize {
    for (doc_pages, 0..) |page, index| {
        if (std.mem.eql(u8, page.slug, slug)) return index;
    }
    return null;
}

pub fn indexByHit(hit_id: u32) ?usize {
    if (hit_id < first_doc_page_button_id) return null;
    const index: usize = @intCast(hit_id - first_doc_page_button_id);
    return if (index < doc_pages.len) index else null;
}

pub fn pageAt(index: ?usize) DocPage {
    const resolved = index orelse 0;
    return if (resolved < doc_pages.len) doc_pages[resolved] else doc_pages[0];
}

pub fn contentHeight(width: f32) f32 {
    return contentHeightForState(width, .{});
}

pub fn contentHeightForState(width: f32, state: State) f32 {
    const content_w = @min(content_wide, @max(1.0, width - design.content_pad * 2.0));
    const compact = content_w < compact_w;
    const sidebar_h = if (compact) sidebarHeight() + panel_gap else 0.0;
    const body_w = if (compact) content_w else content_w - sidebar_w - sidebar_gap;
    const body_h = docBodyHeight(body_w, compact, pageAt(state.selected_doc_index), state);
    return header_h + page_top_pad + sidebar_h + body_h + page_bottom_pad;
}

pub fn render(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, state: State) DocsError!void {
    try fill(scene, bounds, palette.bg, 0.0);
    try renderGrid(scene, ui.Rect.init(bounds.x, bounds.y + header_h - state.scroll_y, bounds.w, contentHeightForState(bounds.w, state)));

    const content = design.centered(bounds, content_wide);
    const page_clip = ui.Rect.init(bounds.x, bounds.y + header_h, bounds.w, @max(1.0, bounds.h - header_h));
    if (try scene.pushClip(page_clip)) {
        defer scene.popClip();
        const scrolled_y = bounds.y + header_h + page_top_pad - state.scroll_y;
        const compact = content.w < compact_w;
        if (compact) {
            try renderSidebar(scene, collector, ui.Rect.init(content.x, scrolled_y, content.w, sidebarHeight()), state.selected_doc_index);
            try renderDocBody(scene, collector, ui.Rect.init(content.x, scrolled_y + sidebarHeight() + panel_gap, content.w, docBodyHeight(content.w, true, pageAt(state.selected_doc_index), state)), true, pageAt(state.selected_doc_index), state);
        } else {
            try renderSidebar(scene, collector, ui.Rect.init(content.x, scrolled_y, sidebar_w, sidebarHeight()), state.selected_doc_index);
            const body_w = content.w - sidebar_w - sidebar_gap;
            const body = ui.Rect.init(content.x + sidebar_w + sidebar_gap, scrolled_y, body_w, docBodyHeight(body_w, false, pageAt(state.selected_doc_index), state));
            try renderDocBody(scene, collector, body, false, pageAt(state.selected_doc_index), state);
        }
    }

    try app_chrome.renderHeader(scene, collector, ui.Rect.init(bounds.x, bounds.y, bounds.w, header_h), content, .docs);
}

fn sidebarHeight() f32 {
    return 60.0 + @as(f32, @floatFromInt(doc_pages.len)) * row_h + 18.0;
}

fn docBodyHeight(width: f32, compact: bool, page: DocPage, state: State) f32 {
    return heroHeight(width, page) + section_gap +
        sectionPageHeight(width, page, state.selected_component_index) + section_gap +
        if (page.section == .overview) feature_title_h + intro_gap + featureGridHeight(compact, width) + section_gap else 0.0 +
            apiSectionHeight(width, page);
}

fn renderSidebar(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, selected_index: ?usize) (ui.RenderError || interaction.Error)!void {
    try components.renderComponent(scene, bounds, .{ .card = .{ .title = "", .detail = "" } }, .{ .style = app_chrome.style() });
    try text(scene, bounds.x + card_pad, bounds.y + 18.0, bounds.w - card_pad * 2.0, 16.0, "Docs", palette.text);
    try text(scene, bounds.x + card_pad, bounds.y + 38.0, bounds.w - card_pad * 2.0, 14.0, "Feature map", palette.muted);
    var y = bounds.y + 64.0;
    for (doc_pages, 0..) |page, index| {
        const active = (selected_index orelse 0) == index;
        const row = ui.Rect.init(bounds.x + 10.0, y, bounds.w - 20.0, row_h - 6.0);
        try renderSidebarRow(scene, collector, row, page, first_doc_page_button_id + @as(u32, @intCast(index)), active);
        y += row_h;
    }
}

fn renderSidebarRow(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, page: DocPage, id: u32, active: bool) (ui.RenderError || interaction.Error)!void {
    const row_component = components.Component{ .button = .{
        .id = id,
        .label = page.section.label(),
        .variant = if (active) .secondary else .ghost,
        .icon_slot = .{ .leading = page.icon_value },
    } };
    try components.renderComponent(scene, bounds, row_component, .{
        .style = app_chrome.style(),
        .control = .{ .active = active },
        .control_size = .small,
    });
    try components.collectComponentInteractions(collector, bounds, row_component);
}

fn renderDocBody(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, compact: bool, page: DocPage, state: State) DocsError!void {
    var cursor_y = bounds.y;
    const hero_h = heroHeight(bounds.w, page);
    try renderHero(scene, collector, ui.Rect.init(bounds.x, cursor_y, bounds.w, hero_h), page);
    cursor_y += hero_h + section_gap;

    const section_h = sectionPageHeight(bounds.w, page, state.selected_component_index);
    try renderSectionPage(scene, collector, ui.Rect.init(bounds.x, cursor_y, bounds.w, section_h), page, state);
    cursor_y += section_h + section_gap;

    if (page.section == .overview) {
        try text(scene, bounds.x, cursor_y, bounds.w, feature_title_h, "Feature sections", palette.text);
        cursor_y += feature_title_h + intro_gap;
        const feature_h = featureGridHeight(compact, bounds.w);
        try renderFeatureGrid(scene, collector, ui.Rect.init(bounds.x, cursor_y, bounds.w, feature_h), compact, page.section);
        cursor_y += feature_h + section_gap;
    }

    try renderApiSection(scene, ui.Rect.init(bounds.x, cursor_y, bounds.w, apiSectionHeight(bounds.w, page)), page);
}

fn renderHero(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, page: DocPage) (ui.RenderError || interaction.Error)!void {
    try components.renderComponent(scene, bounds, .{ .card = .{
        .title = "",
        .detail = "",
    } }, .{ .style = app_chrome.style() });
    const inset = bounds.insetUniform(card_pad);
    try label(scene, heroLabelBounds(inset, page.status), page.status, page.color);
    const split = bounds.w >= compact_w;
    const copy_w = if (split) inset.w * 0.64 else inset.w;
    const title_y = inset.y + hero_label_h + 20.0;
    const title_h = wrappedTextHeight(page.title, copy_w, hero_title_line_h, hero_title_max_lines, hero_title_avg_w);
    try scene.pushWrappedText(ui.Rect.init(inset.x, title_y, copy_w, title_h), page.title, palette.text, .{
        .line_height = hero_title_line_h,
        .average_char_width = hero_title_avg_w,
        .max_lines = hero_title_max_lines,
    });
    const summary_y = title_y + title_h + 14.0;
    const summary_h = wrappedTextHeight(page.summary, copy_w, hero_summary_line_h, hero_summary_max_lines, hero_summary_avg_w);
    try wrappedText(scene, ui.Rect.init(inset.x, summary_y, copy_w, summary_h), page.summary, palette.dim, hero_summary_line_h, hero_summary_avg_w, hero_summary_max_lines);

    if (split) {
        const diagram = ui.Rect.init(inset.x + inset.w * 0.72, inset.y + 18.0, inset.w * 0.28, inset.h - 36.0);
        try renderFeatureGlyph(scene, diagram, page);
    }

    if (page.section == .source) {
        try primaryButton(scene, collector, heroActionBounds(inset, bounds), "Open source", source_button_id);
    } else if (page.section == .authority) {
        try outlineButton(scene, collector, heroActionBounds(inset, bounds), "Academy", academy_button_id);
    }
}

fn heroLabelBounds(inset: ui.Rect, value: []const u8) ui.Rect {
    const desired_w = @as(f32, @floatFromInt(value.len)) * 8.0 + 34.0;
    return ui.Rect.init(inset.x, inset.y, @min(inset.w, @max(design.min_touch_target, desired_w)), hero_label_h);
}

fn heroActionBounds(inset: ui.Rect, bounds: ui.Rect) ui.Rect {
    const desired_w = @min(178.0, @max(hero_action_min_w, inset.w * 0.42));
    return ui.Rect.init(inset.x, bounds.y + bounds.h - design.control_h - card_pad, @min(inset.w, desired_w), design.control_h);
}

fn heroHasAction(page: DocPage) bool {
    return switch (page.section) {
        .authority, .source => true,
        else => false,
    };
}

fn heroHeight(width: f32, page: DocPage) f32 {
    const inner_w = @max(1.0, width - card_pad * 2.0);
    const split = width >= compact_w;
    const copy_w = if (split) inner_w * 0.64 else inner_w;
    const title_h = wrappedTextHeight(page.title, copy_w, hero_title_line_h, hero_title_max_lines, hero_title_avg_w);
    const summary_h = wrappedTextHeight(page.summary, copy_w, hero_summary_line_h, hero_summary_max_lines, hero_summary_avg_w);
    const copy_h = card_pad + hero_label_h + 20.0 + title_h + 14.0 + summary_h + card_pad;
    const action_h = if (heroHasAction(page)) hero_button_gap + design.control_h + card_pad else 0.0;
    const diagram_h = if (split) card_pad + 18.0 + design.Icon.hero_max + 42.0 + 16.0 + card_pad else 0.0;
    return @max(hero_min_h, @max(copy_h + action_h, diagram_h));
}

fn renderFeatureGlyph(scene: *ui.Scene, bounds: ui.Rect, page: DocPage) ui.RenderError!void {
    if (bounds.w < 90.0) return;
    try components.renderComponent(scene, bounds, .{ .card = .{
        .title = "",
        .detail = "",
        .variant = .subtle,
    } }, .{ .style = app_chrome.style() });
    try stroke(scene, bounds, page.color, panel_radius);
    const icon_size = @min(design.Icon.hero_max, bounds.w * 0.42);
    try iconQuad(scene, ui.Rect.init(bounds.x + bounds.w * 0.5 - icon_size * 0.5, bounds.y + 42.0, icon_size, icon_size), page.icon_value, page.color);
    try scene.pushAlignedText(ui.Rect.init(bounds.x + 12.0, bounds.y + bounds.h - 42.0, bounds.w - 24.0, 16.0), page.section.label(), palette.text, .center);
}

const docs_intro_text = "This sidebar is the docs index for the app as it exists now. Feature cards are route-backed and can become deeper pages without changing navigation shape.";

fn introHeight(width: f32) f32 {
    return intro_title_h + intro_gap + wrappedTextHeight(docs_intro_text, width, intro_body_line_h, intro_body_max_lines, intro_body_avg_w);
}

fn sectionBlocks(section: DocSection) []const DocBlock {
    return switch (section) {
        .overview => &overview_blocks,
        .runtime => &runtime_blocks,
        .routing => &routing_blocks,
        .authority => &authority_blocks,
        .rendering => &rendering_blocks,
        .components => &component_blocks,
        .media => &media_blocks,
        .fonts => &font_blocks,
        .wasm => &wasm_blocks,
        .storage => &storage_blocks,
        .source => &source_blocks,
    };
}

fn sectionPageHeight(width: f32, page: DocPage, selected_component_index: ?usize) f32 {
    var height: f32 = 0.0;
    height += intro_title_h + intro_gap + wrappedTextHeight(sectionIntro(page.section), width, intro_body_line_h, intro_body_max_lines, intro_body_avg_w);
    height += section_gap;
    const blocks = sectionBlocks(page.section);
    for (blocks, 0..) |block, index| {
        height += docBlockHeight(width, block);
        if (index + 1 < blocks.len) height += section_block_gap;
    }
    if (page.section == .components) height += section_gap + component_gallery.docsContentHeight(width, selected_component_index);
    if (page.section == .media) height += section_gap + mediaDemoHeight(width);
    return height;
}

fn renderSectionPage(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, page: DocPage, state: State) DocsError!void {
    try text(scene, bounds.x, bounds.y, bounds.w, 22.0, page.section.label(), palette.text);
    const intro_body_y = bounds.y + intro_title_h + intro_gap;
    const intro_text = sectionIntro(page.section);
    const intro_body_h = wrappedTextHeight(intro_text, bounds.w, intro_body_line_h, intro_body_max_lines, intro_body_avg_w);
    try wrappedText(scene, ui.Rect.init(bounds.x, intro_body_y, bounds.w, intro_body_h), intro_text, palette.dim, intro_body_line_h, intro_body_avg_w, intro_body_max_lines);

    var cursor_y = intro_body_y + intro_body_h + section_gap;
    const blocks = sectionBlocks(page.section);
    for (blocks) |block| {
        const block_h = docBlockHeight(bounds.w, block);
        try renderDocBlock(scene, ui.Rect.init(bounds.x, cursor_y, bounds.w, block_h), block);
        cursor_y += block_h + section_block_gap;
    }
    cursor_y -= section_block_gap;

    if (page.section == .components) {
        cursor_y += section_gap;
        try component_gallery.renderDocsContent(scene, collector, ui.Rect.init(bounds.x, cursor_y, bounds.w, component_gallery.docsContentHeight(bounds.w, state.selected_component_index)), state.selected_component_index, state.hover_x, state.hover_y);
    } else if (page.section == .media) {
        cursor_y += section_gap;
        try renderMediaDemo(scene, ui.Rect.init(bounds.x, cursor_y, bounds.w, mediaDemoHeight(bounds.w)));
    }
}

fn sectionIntro(section: DocSection) []const u8 {
    return switch (section) {
        .overview => "The overview is the map. Open any sidebar row to get a subsystem page with the actual path, ownership boundary, and current implementation shape.",
        .runtime => "Runtime documentation explains how the same app is launched by web host and native hosts without giving each host its own product UI.",
        .routing => "Routing documentation explains how path bytes, hit ids, and selected pages become one typed route before rendering.",
        .authority => "Authority documentation explains what can cross app boundaries and why EdgeRun avoids ambient host access.",
        .rendering => "Rendering documentation explains how UI becomes scene commands, then renderer IR, then backend-owned presentation.",
        .components => "Component documentation explains how the catalog, canonical component objects, rendering, and interactions fit together.",
        .media => "Media documentation explains which decoding and presentation work is owned by EdgeRun instead of hidden host APIs.",
        .fonts => "Font documentation explains the full path from embedded font bytes to glyph atlas to backend texture.",
        .wasm => "WASM documentation explains the execution and release artifact path for portable app instances.",
        .storage => "Storage documentation explains how canonical objects and scoped indexes replace raw file access.",
        .source => "Source documentation explains the authoring surface that edits, compiles, exports, and launches the app.",
    };
}

const MediaDemo = struct {
    label: []const u8,
    detail: []const u8,
    kind: enum { image, video },
    atlas_id: u32,
    color: ui.Color,
};

const media_demos = [_]MediaDemo{
    .{ .label = "PNG", .detail = "src/media/png.zig -> image quad", .kind = .image, .atlas_id = 11, .color = palette.blue },
    .{ .label = "JPEG", .detail = "src/media/jpeg.zig -> image quad", .kind = .image, .atlas_id = 12, .color = palette.amber },
    .{ .label = "TGA", .detail = "src/media/tga.zig -> image quad", .kind = .image, .atlas_id = 13, .color = palette.violet },
    .{ .label = "WebP", .detail = "src/media/webp/root.zig -> image quad", .kind = .image, .atlas_id = 14, .color = palette.green },
    .{ .label = "IVF/VP8", .detail = "src/media/video_ivf.zig -> frame strip", .kind = .video, .atlas_id = 21, .color = palette.cyan },
    .{ .label = "WebM", .detail = "src/media/video_webm.zig -> frame strip", .kind = .video, .atlas_id = 22, .color = palette.yellow },
};

fn mediaDemoHeight(width: f32) f32 {
    const columns = mediaDemoColumns(width);
    const rows = (media_demos.len + columns - 1) / columns;
    return 22.0 + intro_gap + @as(f32, @floatFromInt(rows)) * media_card_h + @as(f32, @floatFromInt(rows - 1)) * panel_gap;
}

fn mediaDemoColumns(width: f32) usize {
    if (width >= media_card_min_w * 3.0 + panel_gap * 2.0) return 3;
    if (width >= media_card_min_w * 2.0 + panel_gap) return 2;
    return 1;
}

fn renderMediaDemo(scene: *ui.Scene, bounds: ui.Rect) ui.RenderError!void {
    try text(scene, bounds.x, bounds.y, bounds.w, 22.0, "Formats rendering now", palette.text);
    const columns = mediaDemoColumns(bounds.w);
    const card_w = featureCardWidth(bounds.w, columns);
    const top = bounds.y + 22.0 + intro_gap;
    for (media_demos, 0..) |demo, index| {
        const row = index / columns;
        const col = index % columns;
        const card = ui.Rect.init(
            bounds.x + @as(f32, @floatFromInt(col)) * (card_w + panel_gap),
            top + @as(f32, @floatFromInt(row)) * (media_card_h + panel_gap),
            card_w,
            media_card_h,
        );
        try renderMediaCard(scene, card, demo);
    }
}

fn renderMediaCard(scene: *ui.Scene, bounds: ui.Rect, demo: MediaDemo) ui.RenderError!void {
    try components.renderComponent(scene, bounds, .{ .card = .{
        .title = "",
        .detail = "",
    } }, .{ .style = app_chrome.style() });
    const preview = ui.Rect.init(bounds.x + card_pad, bounds.y + card_pad, bounds.w - card_pad * 2.0, media_preview_h);
    switch (demo.kind) {
        .image => try renderImageDemo(scene, preview, demo),
        .video => try renderVideoDemo(scene, preview, demo),
    }
    try text(scene, bounds.x + card_pad, preview.y + preview.h + 16.0, bounds.w - card_pad * 2.0, 16.0, demo.label, palette.text);
    try wrappedText(scene, ui.Rect.init(bounds.x + card_pad, preview.y + preview.h + 38.0, bounds.w - card_pad * 2.0, 34.0), demo.detail, palette.dim, 16.0, 7.8, 2);
}

fn renderImageDemo(scene: *ui.Scene, bounds: ui.Rect, demo: MediaDemo) ui.RenderError!void {
    try fill(scene, bounds, palette.code_bg, 6.0);
    try scene.pushImageQuad(.{ .bounds = bounds.insetUniform(8.0), .atlas_id = demo.atlas_id, .color = demo.color });
    try iconQuad(scene, ui.Rect.init(bounds.x + 16.0, bounds.y + 16.0, 24.0, 24.0), .file, palette.text);
}

fn renderVideoDemo(scene: *ui.Scene, bounds: ui.Rect, demo: MediaDemo) ui.RenderError!void {
    try fill(scene, bounds, palette.code_bg, 6.0);
    const frame_w = @max(1.0, (bounds.w - media_frame_gap * 2.0 - 16.0) / 3.0);
    var x = bounds.x + 8.0;
    for (0..3) |index| {
        var color = demo.color;
        color.a = @intCast(150 + index * 35);
        try scene.pushImageQuad(.{ .bounds = ui.Rect.init(x, bounds.y + 10.0, frame_w, bounds.h - 20.0), .atlas_id = demo.atlas_id + @as(u32, @intCast(index)), .color = color });
        x += frame_w + media_frame_gap;
    }
    try iconQuad(scene, ui.Rect.init(bounds.x + bounds.w - 36.0, bounds.y + 14.0, 22.0, 22.0), .activity, palette.text);
}

fn docBlockHeight(width: f32, block: DocBlock) f32 {
    const text_w = @max(1.0, width - card_pad * 2.0);
    const body_h = wrappedTextHeight(block.body, text_w, section_block_body_line_h, section_block_body_max_lines, section_block_body_avg_w);
    const code_h: f32 = if (block.code.len == 0) 0.0 else 12.0 + @as(f32, @floatFromInt(lineCount(block.code))) * code_line_h;
    return card_pad + section_block_title_h + 10.0 + body_h + code_h + card_pad;
}

fn renderDocBlock(scene: *ui.Scene, bounds: ui.Rect, block: DocBlock) ui.RenderError!void {
    try components.renderComponent(scene, bounds, .{ .card = .{
        .title = "",
        .detail = "",
    } }, .{ .style = app_chrome.style() });
    try text(scene, bounds.x + card_pad, bounds.y + card_pad, bounds.w - card_pad * 2.0, section_block_title_h, block.title, palette.text);
    const body_y = bounds.y + card_pad + section_block_title_h + 10.0;
    const body_h = wrappedTextHeight(block.body, bounds.w - card_pad * 2.0, section_block_body_line_h, section_block_body_max_lines, section_block_body_avg_w);
    try wrappedText(scene, ui.Rect.init(bounds.x + card_pad, body_y, bounds.w - card_pad * 2.0, body_h), block.body, palette.dim, section_block_body_line_h, section_block_body_avg_w, section_block_body_max_lines);
    if (block.code.len != 0) {
        const code_y = body_y + body_h + 12.0;
        try renderInlineCode(scene, ui.Rect.init(bounds.x + card_pad, code_y, bounds.w - card_pad * 2.0, @as(f32, @floatFromInt(lineCount(block.code))) * code_line_h), block.code);
    }
}

fn renderInlineCode(scene: *ui.Scene, bounds: ui.Rect, value: []const u8) ui.RenderError!void {
    try fill(scene, bounds.insetLtrb(0.0, -6.0, 0.0, -6.0), palette.code_bg, 6.0);
    var line_cursor: usize = 0;
    var y = bounds.y;
    while (line_cursor < value.len) {
        const end = std.mem.indexOfScalarPos(u8, value, line_cursor, '\n') orelse value.len;
        try text(scene, bounds.x + 10.0, y, bounds.w - 20.0, 14.0, value[line_cursor..end], palette.primary);
        line_cursor = if (end < value.len) end + 1 else end;
        y += code_line_h;
    }
}

fn featureGridHeight(compact: bool, width: f32) f32 {
    const columns: usize = if (compact) 1 else 2;
    const rows = (doc_pages.len + columns - 1) / columns;
    const card_w = featureCardWidth(width, columns);
    return @as(f32, @floatFromInt(rows)) * featureCardHeight(card_w) + @as(f32, @floatFromInt(rows - 1)) * panel_gap;
}

fn featureCardWidth(width: f32, columns: usize) f32 {
    const column_count: f32 = @floatFromInt(columns);
    const gap_count: f32 = @floatFromInt(columns - 1);
    return @max(1.0, (width - panel_gap * gap_count) / column_count);
}

fn featureCardHeight(width: f32) f32 {
    var max_summary_h: f32 = 0.0;
    const text_w = @max(1.0, width - card_pad * 2.0);
    for (doc_pages) |page| {
        max_summary_h = @max(max_summary_h, wrappedTextHeight(page.summary, text_w, feature_summary_line_h, feature_summary_max_lines, feature_summary_avg_w));
    }
    return card_pad + design.Icon.card + 14.0 + max_summary_h + card_pad;
}

fn renderFeatureGrid(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, compact: bool, active_section: DocSection) (ui.RenderError || interaction.Error)!void {
    const columns: usize = if (compact) 1 else 2;
    const card_w = featureCardWidth(bounds.w, columns);
    const card_h = featureCardHeight(card_w);
    for (doc_pages, 0..) |page, index| {
        const row = index / columns;
        const col = index % columns;
        const card = ui.Rect.init(
            bounds.x + @as(f32, @floatFromInt(col)) * (card_w + panel_gap),
            bounds.y + @as(f32, @floatFromInt(row)) * (card_h + panel_gap),
            card_w,
            card_h,
        );
        try renderFeatureCard(scene, collector, card, page, first_doc_page_button_id + @as(u32, @intCast(index)), page.section == active_section);
    }
}

fn renderFeatureCard(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, page: DocPage, id: u32, active: bool) (ui.RenderError || interaction.Error)!void {
    try components.renderComponent(scene, bounds, .{ .card = .{
        .title = page.title,
        .detail = page.summary,
        .variant = if (active) .elevated else .subtle,
    } }, .{ .style = app_chrome.style() });
    try stroke(scene, bounds, if (active) page.color else palette.border, panel_radius);
    try collector.addHit(bounds, .button, id);
}

fn apiSectionHeight(width: f32, page: DocPage) f32 {
    const split = width >= compact_w;
    const detail_w = if (split) width * 0.48 else width;
    const code_w = if (split) width * 0.48 else width;
    const primary_h = detailCardHeight(detail_w, page.primary);
    const secondary_h = detailCardHeight(detail_w, page.secondary);
    const detail_h = primary_h + panel_gap + secondary_h;
    const code_h = codeCardHeight(code_w, page.api);
    const body_h = if (split) @max(detail_h, code_h) else detail_h + panel_gap + code_h;
    return 42.0 + body_h;
}

fn renderApiSection(scene: *ui.Scene, bounds: ui.Rect, page: DocPage) ui.RenderError!void {
    try text(scene, bounds.x, bounds.y, bounds.w, 22.0, "Contract and API", palette.text);
    const top = bounds.y + 42.0;
    const split = bounds.w >= compact_w;
    const detail_w = if (split) bounds.w * 0.48 else bounds.w;
    const primary_h = detailCardHeight(detail_w, page.primary);
    const secondary_h = detailCardHeight(detail_w, page.secondary);
    const code_w = if (split) bounds.w * 0.48 else bounds.w;
    const code_h = codeCardHeight(code_w, page.api);
    const left = if (split) ui.Rect.init(bounds.x, top, detail_w, primary_h + panel_gap + secondary_h) else ui.Rect.init(bounds.x, top, detail_w, primary_h + panel_gap + secondary_h);
    const right = if (split) ui.Rect.init(bounds.x + bounds.w * 0.52, top, code_w, @max(code_h, left.h)) else ui.Rect.init(bounds.x, top + left.h + panel_gap, code_w, code_h);
    try renderDetailCard(scene, ui.Rect.init(left.x, left.y, left.w, primary_h), "What it owns", page.primary);
    try renderDetailCard(scene, ui.Rect.init(left.x, left.y + primary_h + panel_gap, left.w, secondary_h), "Boundary", page.secondary);
    try renderCodeCard(scene, right, page.api);
}

fn detailCardHeight(width: f32, detail: []const u8) f32 {
    const text_w = @max(1.0, width - card_pad * 2.0);
    return card_pad + detail_title_h + 10.0 + wrappedTextHeight(detail, text_w, detail_body_line_h, detail_body_max_lines, detail_body_avg_w) + card_pad;
}

fn renderDetailCard(scene: *ui.Scene, bounds: ui.Rect, title_value: []const u8, detail: []const u8) ui.RenderError!void {
    try components.renderComponent(scene, bounds, .{ .card = .{
        .title = "",
        .detail = "",
    } }, .{ .style = app_chrome.style() });
    try text(scene, bounds.x + card_pad, bounds.y + 18.0, bounds.w - card_pad * 2.0, 16.0, title_value, palette.text);
    try wrappedText(scene, ui.Rect.init(bounds.x + card_pad, bounds.y + 44.0, bounds.w - card_pad * 2.0, @max(1.0, bounds.h - 44.0 - card_pad)), detail, palette.dim, detail_body_line_h, detail_body_avg_w, detail_body_max_lines);
}

fn codeCardHeight(width: f32, value: []const u8) f32 {
    _ = width;
    return card_pad + code_title_h + 16.0 + @as(f32, @floatFromInt(lineCount(value))) * code_line_h + card_pad;
}

fn lineCount(value: []const u8) usize {
    if (value.len == 0) return 0;
    var lines: usize = 1;
    for (value) |byte| {
        if (byte == '\n') lines += 1;
    }
    return lines;
}

fn renderCodeCard(scene: *ui.Scene, bounds: ui.Rect, value: []const u8) ui.RenderError!void {
    var code_style = app_chrome.style();
    code_style.panel = palette.code_bg;
    try components.renderComponent(scene, bounds, .{ .card = .{
        .title = "",
        .detail = "",
    } }, .{ .style = code_style });
    try text(scene, bounds.x + card_pad, bounds.y + 18.0, bounds.w - card_pad * 2.0, 14.0, "API surface", palette.primary);
    var line_cursor: usize = 0;
    var y = bounds.y + 48.0;
    while (line_cursor < value.len and y + 14.0 < bounds.y + bounds.h - 12.0) {
        const end = std.mem.indexOfScalarPos(u8, value, line_cursor, '\n') orelse value.len;
        try text(scene, bounds.x + card_pad, y, bounds.w - card_pad * 2.0, 14.0, value[line_cursor..end], palette.dim);
        line_cursor = if (end < value.len) end + 1 else end;
        y += code_line_h;
    }
}

fn renderGrid(scene: *ui.Scene, bounds: ui.Rect) ui.RenderError!void {
    const grid: f32 = 28.0;
    var x = bounds.x;
    while (x < bounds.x + bounds.w) : (x += grid) {
        try fill(scene, ui.Rect.init(x, bounds.y, 1.0, bounds.h), ui.Color{ .r = 255, .g = 255, .b = 255, .a = 5 }, 0.0);
    }
    var y = bounds.y;
    while (y < bounds.y + bounds.h) : (y += grid) {
        try fill(scene, ui.Rect.init(bounds.x, y, bounds.w, 1.0), ui.Color{ .r = 255, .g = 255, .b = 255, .a = 4 }, 0.0);
    }
}

fn primaryButton(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, label_value: []const u8, id: u32) (ui.RenderError || interaction.Error)!void {
    try components.renderComponent(scene, bounds, .{ .button = .{ .id = id, .label = label_value, .icon_slot = .{ .trailing = .chevron_right } } }, .{
        .style = appStyle(),
    });
    try components.collectComponentInteractions(collector, bounds, .{ .button = .{ .id = id, .label = label_value } });
}

fn outlineButton(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, label_value: []const u8, id: u32) (ui.RenderError || interaction.Error)!void {
    try components.renderComponent(scene, bounds, .{ .button = .{ .id = id, .label = label_value, .variant = .outline } }, .{
        .style = appStyle(),
    });
    try components.collectComponentInteractions(collector, bounds, .{ .button = .{ .id = id, .label = label_value } });
}

fn appStyle() ui.Style {
    var resolved = app_chrome.style();
    resolved.panel = palette.panel_alt;
    resolved.row = palette.row;
    resolved.border = palette.border;
    resolved.text = palette.text;
    resolved.muted = palette.dim;
    resolved.accent = palette.primary;
    return resolved;
}

fn label(scene: *ui.Scene, bounds: ui.Rect, value: []const u8, color: ui.Color) ui.RenderError!void {
    var label_style = appStyle();
    label_style.accent = color;
    try components.renderComponent(scene, bounds, .{ .badge = .{
        .label = value,
    } }, .{ .style = label_style });
}

fn iconQuad(scene: *ui.Scene, bounds: ui.Rect, value: icon.Icon, color: ui.Color) ui.RenderError!void {
    try scene.pushIconQuad(.{ .bounds = bounds, .icon_id = icon.id(value), .color = color });
}

test "docs page renders sidebar feature documentation" {
    var commands: [4096]ui.Command = undefined;
    var clips: [16]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var regions: [256]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try render(&scene, &collector, ui.Rect.init(0, 0, 1280, contentHeight(1280.0)), .{});

    try std.testing.expect(hasText(scene.written(), "Feature map"));
    try std.testing.expect(hasText(scene.written(), "Feature sections"));
    try std.testing.expect(hasText(scene.written(), "Contract and API"));
    try std.testing.expect(hasHit(collector.written(), first_doc_page_button_id + @as(u32, @intCast(indexBySlug("media").?))));
    try std.testing.expect(hasHit(collector.written(), first_doc_page_button_id + @as(u32, @intCast(indexBySlug("component-system").?))));
    try std.testing.expect(component_gallery.component_catalog.len > 0);
    try std.testing.expect(app_blog.posts.len > 0);
}

test "docs page renders selected feature route" {
    const media_index = indexBySlug("media").?;
    var commands: [4096]ui.Command = undefined;
    var clips: [16]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var regions: [256]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try render(&scene, &collector, ui.Rect.init(0, 0, 1280, contentHeightForState(1280.0, .{ .selected_doc_index = media_index })), .{
        .selected_doc_index = media_index,
    });

    try std.testing.expect(hasText(scene.written(), "Media"));
    try std.testing.expect(hasText(scene.written(), "API surface"));
    try std.testing.expect(hasText(scene.written(), "svg: icon_svg.zig"));
}

test "docs components page exposes catalog action" {
    const components_index = indexBySlug("component-system").?;
    var commands: [8192]ui.Command = undefined;
    var clips: [16]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var regions: [1024]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try render(&scene, &collector, ui.Rect.init(0, 0, 1280, contentHeightForState(1280.0, .{ .selected_doc_index = components_index })), .{
        .selected_doc_index = components_index,
    });

    try std.testing.expect(hasText(scene.written(), "Components"));
    try std.testing.expect(hasText(scene.written(), "Component Catalog"));
    try std.testing.expect(hasText(scene.written(), "Accordion"));
    try std.testing.expect(hasText(scene.written(), "Tooltip"));
    try std.testing.expect(hasHit(collector.written(), component_gallery.first_catalog_card_id + @as(u32, @intCast(component_gallery.indexBySlug("button").?))));
}

test "docs component subsection renders selected component inside docs" {
    const components_index = indexBySlug("component-system").?;
    const button_index = component_gallery.indexBySlug("button").?;
    var commands: [8192]ui.Command = undefined;
    var clips: [16]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var regions: [1024]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try render(&scene, &collector, ui.Rect.init(0, 0, 1280, contentHeightForState(1280.0, .{ .selected_doc_index = components_index, .selected_component_index = button_index })), .{
        .selected_doc_index = components_index,
        .selected_component_index = button_index,
    });

    try std.testing.expect(hasText(scene.written(), "/docs/components/button"));
    try std.testing.expect(hasText(scene.written(), "Rendered component"));
    try std.testing.expect(hasText(scene.written(), "default"));
}

test "docs fonts page documents owned font pipeline" {
    const fonts_index = indexBySlug("fonts").?;
    var commands: [4096]ui.Command = undefined;
    var clips: [16]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var regions: [256]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try render(&scene, &collector, ui.Rect.init(0, 0, 1280, contentHeightForState(1280.0, .{ .selected_doc_index = fonts_index })), .{
        .selected_doc_index = fonts_index,
    });

    try std.testing.expect(hasText(scene.written(), "Fonts"));
    try std.testing.expect(hasText(scene.written(), "asset: varfont.geist_bytes"));
    try std.testing.expect(hasText(scene.written(), "atlas: 2048x2048 alpha8, 1280 glyphs"));
    try std.testing.expect(hasText(scene.written(), "backends: software/GLES/web alpha texture"));
}

test "docs routing page documents the shared route table" {
    const routing_index = indexBySlug("routing").?;
    var commands: [4096]ui.Command = undefined;
    var clips: [16]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var regions: [256]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try render(&scene, &collector, ui.Rect.init(0, 0, 1280, contentHeightForState(1280.0, .{ .selected_doc_index = routing_index })), .{
        .selected_doc_index = routing_index,
    });

    try std.testing.expect(hasText(scene.written(), "Routing"));
    try std.testing.expect(hasText(scene.written(), "/docs/components[/slug] -> Docs component subsection"));
    try std.testing.expect(hasHit(collector.written(), first_doc_page_button_id + @as(u32, @intCast(routing_index))));
}

test "docs sidebar sections render their own page bodies" {
    for (doc_pages, 0..) |page, index| {
        var commands: [4096]ui.Command = undefined;
        var clips: [16]ui.Rect = undefined;
        var scene = ui.Scene.initWithClips(&commands, &clips);
        var regions: [256]interaction.Region = undefined;
        var collector = interaction.Collector.init(&regions);
        try render(&scene, &collector, ui.Rect.init(0, 0, 1280, contentHeightForState(1280.0, .{ .selected_doc_index = index })), .{
            .selected_doc_index = index,
        });

        const blocks = sectionBlocks(page.section);
        try std.testing.expect(blocks.len > 0);
        try std.testing.expect(hasText(scene.written(), page.section.label()));
        try std.testing.expect(hasText(scene.written(), blocks[0].title));
    }
}

test "docs page content height grows for compact layout" {
    try std.testing.expect(contentHeight(390.0) > contentHeight(1280.0));
}

test "docs measured sections respond to available width" {
    const media = pageAt(indexBySlug("media"));
    try std.testing.expect(heroHeight(360.0, media) >= heroHeight(900.0, media));
    try std.testing.expect(featureGridHeight(true, 360.0) > featureGridHeight(false, 900.0));
    try std.testing.expect(apiSectionHeight(360.0, media) > apiSectionHeight(900.0, media));
}

test "docs media page renders image and video format demos" {
    const media_index = indexBySlug("media").?;
    var commands: [4096]ui.Command = undefined;
    var clips: [16]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var regions: [256]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try render(&scene, &collector, ui.Rect.init(0, 0, 1280, contentHeightForState(1280.0, .{ .selected_doc_index = media_index })), .{
        .selected_doc_index = media_index,
    });

    try std.testing.expect(hasText(scene.written(), "Formats rendering now"));
    try std.testing.expect(hasText(scene.written(), "PNG"));
    try std.testing.expect(hasText(scene.written(), "WebM"));
    try std.testing.expect(hasImageQuad(scene.written()));
}

test "docs navigation surfaces render through shared components" {
    var commands: [256]ui.Command = undefined;
    var clips: [8]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var regions: [32]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);
    const page = doc_pages[0];

    try renderSidebarRow(&scene, &collector, ui.Rect.init(20.0, 40.0, 240.0, row_h - 6.0), page, first_doc_page_button_id, true);
    try renderFeatureCard(&scene, &collector, ui.Rect.init(20.0, 90.0, 420.0, featureCardHeight(420.0)), page, first_doc_page_button_id + 1, false);

    try std.testing.expect(hasText(scene.written(), page.section.label()));
    try std.testing.expect(hasText(scene.written(), page.title));
    try std.testing.expect(hasHit(collector.written(), first_doc_page_button_id));
    try std.testing.expect(hasHit(collector.written(), first_doc_page_button_id + 1));
}

fn hasText(commands: []const ui.Command, value: []const u8) bool {
    for (commands) |command| switch (command) {
        .text => |text_command| if (std.mem.eql(u8, text_command.value, value)) return true,
        else => {},
    };
    return false;
}

fn hasHit(regions: []const interaction.Region, id: u32) bool {
    for (regions) |region| if (region.id == id) return true;
    return false;
}

fn hasImageQuad(commands: []const ui.Command) bool {
    for (commands) |command| switch (command) {
        .image_quad => return true,
        else => {},
    };
    return false;
}
