#include "test_common.h"

#include <stdio.h>
#include <stdlib.h>

static void* node_vr_alloc(void* user, size_t size, size_t align) {
  (void)user;
  (void)align;
  return malloc(size);
}

static void* node_vr_realloc(void* user, void* ptr, size_t old_size, size_t new_size, size_t align) {
  (void)user;
  (void)old_size;
  (void)align;
  return realloc(ptr, new_size);
}

static void node_vr_free(void* user, void* ptr, size_t size, size_t align) {
  (void)user;
  (void)size;
  (void)align;
  free(ptr);
}

static vr_font_allocator_t node_vr_allocator(void) {
  vr_font_allocator_t allocator = {0};
  allocator.alloc = node_vr_alloc;
  allocator.realloc = node_vr_realloc;
  allocator.free = node_vr_free;
  return allocator;
}

static unsigned char* node_read_file(const char* path, size_t* out_size) {
  if (out_size) *out_size = 0u;
  FILE* file = fopen(path, "rb");
  if (!file) return NULL;
  if (fseek(file, 0, SEEK_END) != 0) {
    fclose(file);
    return NULL;
  }
  long len = ftell(file);
  if (len <= 0) {
    fclose(file);
    return NULL;
  }
  rewind(file);
  unsigned char* data = (unsigned char*)malloc((size_t)len);
  if (!data) {
    fclose(file);
    return NULL;
  }
  size_t read = fread(data, 1u, (size_t)len, file);
  fclose(file);
  if (read != (size_t)len) {
    free(data);
    return NULL;
  }
  if (out_size) *out_size = (size_t)len;
  return data;
}

static vr_font_face_t* node_open_test_font(void) {
  size_t font_size = 0u;
  unsigned char* font_data = node_read_file(ER_UI_REPO_ROOT "/varfont/fonts/Geist[wght].ttf", &font_size);
  expect_true(font_data != NULL && font_size > 0u, "node: bundled variable font loads");
  if (!font_data) return NULL;
  vr_font_config_t cfg = {0};
  cfg.px_size = 14.0f;
  cfg.atlas_width = 512u;
  cfg.atlas_height = 512u;
  cfg.atlas_pad = VR_FONT_DEFAULT_ATLAS_PADDING;
  cfg.atlas_format = VR_FONT_ATLAS_FORMAT_ALPHA8;
  cfg.allocator = node_vr_allocator();
  vr_font_face_t* face = NULL;
  expect_status((er_ui_status_t)vr_font_face_create_from_memory(&face, font_data, font_size, &cfg), (er_ui_status_t)VR_OK,
                "node: variable font opens from memory");
  free(font_data);
  return face;
}

void run_node_tests(void) {
  er_ui_node_t root = er_ui_node_card();
  er_ui_node_set_padding(&root, 10.0f);
  er_ui_node_set_gap(&root, 8.0f);
  er_ui_node_t title = er_ui_node_text("Create project");
  er_ui_node_t row = er_ui_node_row();
  er_ui_node_set_gap(&row, 6.0f);
  er_ui_node_t badge = er_ui_node_badge("Native", ER_UI_SHADCN_BADGE_SECONDARY);
  er_ui_node_t button = er_ui_node_button("Deploy", 8001u, ER_UI_SHADCN_BUTTON_DEFAULT);
  expect_status(er_ui_node_add_child(&row, &badge), ER_UI_OK, "node: row accepts badge child");
  expect_status(er_ui_node_add_child(&row, &button), ER_UI_OK, "node: row accepts button child");
  expect_status(er_ui_node_add_child(&root, &title), ER_UI_OK, "node: card accepts title child");
  expect_status(er_ui_node_add_child(&root, &row), ER_UI_OK, "node: card accepts row child");
  expect_string(er_ui_node_kind_label(ER_UI_NODE_CARD), "card", "node: kind label maps card");
  expect_string(er_ui_node_kind_label(ER_UI_NODE_CARD_SUMMARY), "card-summary", "node: kind label maps card summary");
  expect_string(er_ui_node_kind_label(ER_UI_NODE_ICON_BUTTON), "icon-button", "node: kind label maps icon button");
  expect_string(er_ui_node_kind_label(ER_UI_NODE_BUTTON_GROUP), "button-group", "node: kind label maps button group");
  expect_string(er_ui_node_kind_label(ER_UI_NODE_TOGGLE_GROUP), "toggle-group", "node: kind label maps toggle group");
  expect_string(er_ui_node_kind_label(ER_UI_NODE_PAGINATION), "pagination", "node: kind label maps pagination");
  expect_string(er_ui_node_kind_label(ER_UI_NODE_COLLAPSIBLE), "collapsible", "node: kind label maps collapsible");
  expect_string(er_ui_node_kind_label(ER_UI_NODE_ACCORDION), "accordion", "node: kind label maps accordion");
  expect_string(er_ui_node_kind_label(ER_UI_NODE_HOVER_CARD), "hover-card", "node: kind label maps hover card");
  expect_string(er_ui_node_kind_label(ER_UI_NODE_POPOVER), "popover", "node: kind label maps popover");
  expect_string(er_ui_node_kind_label(ER_UI_NODE_SHEET), "sheet", "node: kind label maps sheet");
  expect_string(er_ui_node_kind_label(ER_UI_NODE_KBD), "kbd", "node: kind label maps kbd");
  expect_string(er_ui_node_kind_label(ER_UI_NODE_MENUBAR), "menubar", "node: kind label maps menubar");
  expect_string(er_ui_node_kind_label(ER_UI_NODE_RADIO_GROUP), "radio-group", "node: kind label maps radio group");
  expect_string(er_ui_node_kind_label(ER_UI_NODE_INPUT_GROUP), "input-group", "node: kind label maps input group");
  expect_string(er_ui_node_kind_label(ER_UI_NODE_INPUT_OTP), "input-otp", "node: kind label maps input otp");
  expect_string(er_ui_node_kind_label(ER_UI_NODE_NAVIGATION_MENU), "navigation-menu", "node: kind label maps navigation menu");
  expect_string(er_ui_node_kind_label(ER_UI_NODE_RESIZABLE), "resizable", "node: kind label maps resizable");
  expect_string(er_ui_node_kind_label(ER_UI_NODE_SIDEBAR), "sidebar", "node: kind label maps sidebar");
  expect_string(er_ui_node_kind_label(ER_UI_NODE_SONNER), "sonner", "node: kind label maps sonner");
  expect_string(er_ui_node_kind_label(ER_UI_NODE_ASPECT_RATIO), "aspect-ratio", "node: kind label maps aspect ratio");
  expect_string(er_ui_node_kind_label(ER_UI_NODE_ALERT_DIALOG), "alert-dialog", "node: kind label maps alert dialog");
  expect_string(er_ui_node_kind_label(ER_UI_NODE_DIRECTION), "direction", "node: kind label maps direction");
  expect_string(er_ui_node_kind_label(ER_UI_NODE_DRAWER), "drawer", "node: kind label maps drawer");
  expect_string(er_ui_node_kind_label(ER_UI_NODE_DROPDOWN_MENU), "dropdown-menu", "node: kind label maps dropdown menu");
  expect_string(er_ui_node_kind_label(ER_UI_NODE_CONTEXT_MENU), "context-menu", "node: kind label maps context menu");
  expect_string(er_ui_node_kind_label(ER_UI_NODE_DATE_PICKER), "date-picker", "node: kind label maps date picker");
  expect_string(er_ui_node_kind_label(ER_UI_NODE_CAROUSEL), "carousel", "node: kind label maps carousel");
  expect_string(er_ui_node_kind_label(ER_UI_NODE_CALENDAR), "calendar", "node: kind label maps calendar");
  expect_string(er_ui_node_kind_label(ER_UI_NODE_COMBOBOX), "combobox", "node: kind label maps combobox");
  expect_string(er_ui_node_kind_label(ER_UI_NODE_DIFF_BODY), "diff-body", "node: kind label maps diff body");
  expect_string(er_ui_node_kind_label(ER_UI_NODE_CHAT_MESSAGE), "chat-message", "node: kind label maps chat message");
  expect_string(er_ui_node_kind_label(ER_UI_NODE_CONVERSATION), "conversation", "node: kind label maps conversation");
  expect_string(er_ui_icon_label(ER_UI_ICON_SEARCH), "search", "node: icon label maps canonical icon");
  expect_u32(er_ui_icon_atlas_id(ER_UI_ICON_SEARCH), (uint32_t)ER_UI_ICON_SEARCH + 1u, "node: icon atlas id is stable");
  expect_string(er_ui_icon_provider_name(ER_UI_ICON_APP, ER_UI_ICON_PROVIDER_LUCIDE), "app-window", "node: lucide provider name maps app icon");
  expect_string(er_ui_icon_provider_name(ER_UI_ICON_APP, ER_UI_ICON_PROVIDER_TABLER), "apps", "node: tabler provider name maps app icon");
  expect_string(er_ui_icon_provider_name(ER_UI_ICON_TRASH, ER_UI_ICON_PROVIDER_LUCIDE), "trash-2", "node: lucide provider name maps trash icon");
  expect_string(er_ui_icon_provider_name(ER_UI_ICON_TRASH, ER_UI_ICON_PROVIDER_TABLER), "trash", "node: tabler provider name maps trash icon");
  expect_true(er_ui_icon_provider_name(ER_UI_ICON_COUNT, ER_UI_ICON_PROVIDER_LUCIDE) == NULL, "node: invalid icon provider name is null");
  expect_string(er_ui_node_composition_issue_label(ER_UI_NODE_COMPOSITION_NESTED_CARD), "nested-card",
                "node: composition issue label maps nested card");
  er_ui_node_composition_issue_t issue = {0};
  expect_status(er_ui_node_validate_composition(&root, &issue), ER_UI_OK, "node: card tree composition validates");
  expect_size(issue.kind, ER_UI_NODE_COMPOSITION_OK, "node: valid composition reports ok");

  er_ui_node_t outer_card = er_ui_node_card();
  er_ui_node_t nested_column = er_ui_node_column();
  er_ui_node_t inner_card = er_ui_node_metric_card("Spend", "4", "units", false, 0.0f, er_ui_color_rgba(0.0f, 0.0f, 0.0f, 1.0f));
  expect_status(er_ui_node_add_child(&nested_column, &inner_card), ER_UI_OK, "node: nested column accepts card-like child");
  expect_status(er_ui_node_add_child(&outer_card, &nested_column), ER_UI_OK, "node: outer card accepts column child");
  expect_status(er_ui_node_validate_composition(&outer_card, &issue), ER_UI_ERR_INVALID_ARGUMENT,
                "node: composition rejects cards inside cards");
  expect_size(issue.kind, ER_UI_NODE_COMPOSITION_NESTED_CARD, "node: nested card issue kind");
  expect_size(issue.ancestor_kind, ER_UI_NODE_CARD, "node: nested card issue ancestor");
  expect_size(issue.parent_kind, ER_UI_NODE_COLUMN, "node: nested card issue parent");
  expect_size(issue.node_kind, ER_UI_NODE_METRIC_CARD, "node: nested card issue node");
  expect_size(issue.child_index, 0u, "node: nested card issue child index");

  er_ui_node_t section_card = er_ui_node_card();
  er_ui_node_t section_column = er_ui_node_column();
  er_ui_node_t section_child = er_ui_node_section("Policy", "hash visible");
  expect_status(er_ui_node_add_child(&section_column, &section_child), ER_UI_OK, "node: section column accepts child");
  expect_status(er_ui_node_add_child(&section_card, &section_column), ER_UI_OK, "node: card accepts unframed section");
  expect_status(er_ui_node_validate_composition(&section_card, &issue), ER_UI_OK,
                "node: composition allows unframed sections in cards");
  er_ui_bounds_t resolved_child = {0};
  expect_status(er_ui_node_child_bounds(&root, 1u, er_ui_bounds(0.0f, 0.0f, 320.0f, 160.0f), &resolved_child), ER_UI_OK,
                "node: card child bounds resolve");
  expect_float(resolved_child.x, 10.0f, "node: card child bounds x includes padding");
  expect_float(resolved_child.y, 84.0f, "node: card child bounds y includes gap");
  expect_float(resolved_child.w, 300.0f, "node: card child bounds width includes padding");
  expect_float(resolved_child.h, 66.0f, "node: card child bounds height divides space");
  expect_status(er_ui_node_child_bounds(&button, 0u, er_ui_bounds(0.0f, 0.0f, 80.0f, 30.0f), &resolved_child), ER_UI_ERR_INVALID_ARGUMENT,
                "node: leaf child bounds are rejected");

  er_ui_a11y_node_t a11y = {0};
  expect_status(er_ui_node_accessibility(&button, &a11y), ER_UI_OK, "node: button accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_BUTTON, "node: button accessibility role");
  expect_true(a11y.has_id && a11y.id == 8001u, "node: button accessibility id");
  expect_true(a11y.label == button.label, "node: button accessibility label is borrowed");

  er_ui_node_t icon_a11y = er_ui_node_icon(ER_UI_ICON_TRUST, NULL, er_ui_color_rgba(0.0f, 0.0f, 0.0f, 1.0f));
  expect_status(er_ui_node_accessibility(&icon_a11y, &a11y), ER_UI_OK, "node: icon accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_IMAGE, "node: icon accessibility role");
  expect_string(a11y.label, "trust", "node: icon accessibility uses canonical label fallback");

  er_ui_node_t icon_button_a11y = er_ui_node_icon_button(ER_UI_ICON_SEARCH, "Search", 8007u, ER_UI_SHADCN_BUTTON_GHOST);
  expect_status(er_ui_node_accessibility(&icon_button_a11y, &a11y), ER_UI_OK, "node: icon button accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_BUTTON, "node: icon button accessibility role");
  expect_true(a11y.has_id && a11y.id == 8007u, "node: icon button accessibility id");

  er_ui_node_t toast_icon_a11y = er_ui_node_toast_icon("Saved", ER_UI_ICON_CHECK, er_ui_color_rgba(0.0f, 0.5f, 0.2f, 1.0f));
  expect_status(er_ui_node_accessibility(&toast_icon_a11y, &a11y), ER_UI_OK, "node: icon toast accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_STATUS, "node: icon toast accessibility role");
  expect_true(a11y.label == toast_icon_a11y.label, "node: icon toast label is borrowed");

  er_ui_node_t card_summary_a11y = er_ui_node_card_summary("Title", "Detail");
  expect_status(er_ui_node_accessibility(&card_summary_a11y, &a11y), ER_UI_OK, "node: card summary accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_GROUP, "node: card summary accessibility role");
  expect_true(a11y.label == card_summary_a11y.label, "node: card summary title is borrowed");
  expect_true(a11y.value == card_summary_a11y.detail, "node: card summary detail is borrowed");

  const char* const button_group_labels[] = {"Copy", "Paste", "More"};
  er_ui_node_t button_group_a11y = er_ui_node_button_group(button_group_labels, 3u, 8008u);
  expect_status(er_ui_node_accessibility(&button_group_a11y, &a11y), ER_UI_OK, "node: button group accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_GROUP, "node: button group accessibility role");
  expect_status(er_ui_node_accessibility_child(&button_group_a11y, 2u, &a11y), ER_UI_OK, "node: button group child accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_BUTTON, "node: button group child accessibility role");
  expect_true(a11y.has_id && a11y.id == 8010u, "node: button group child id");

  const char* const toggle_group_labels[] = {"B", "I", "U"};
  er_ui_node_t toggle_group_a11y = er_ui_node_toggle_group(toggle_group_labels, 3u, 1u, 8011u);
  expect_status(er_ui_node_accessibility(&toggle_group_a11y, &a11y), ER_UI_OK, "node: toggle group accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_GROUP, "node: toggle group accessibility role");
  expect_status(er_ui_node_accessibility_child(&toggle_group_a11y, 1u, &a11y), ER_UI_OK, "node: toggle group child accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_BUTTON, "node: toggle group child accessibility role");
  expect_true((a11y.states & ER_UI_A11Y_STATE_SELECTED) != 0u, "node: toggle group selected child state");

  const char* const pagination_labels[] = {"1", "2"};
  er_ui_node_t pagination_a11y = er_ui_node_pagination(pagination_labels, 2u, 0u, 8018u);
  expect_status(er_ui_node_accessibility(&pagination_a11y, &a11y), ER_UI_OK, "node: pagination accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_NAVIGATION, "node: pagination accessibility role");
  expect_status(er_ui_node_accessibility_child(&pagination_a11y, 1u, &a11y), ER_UI_OK, "node: selected page accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_BUTTON, "node: selected page accessibility role");
  expect_true((a11y.states & ER_UI_A11Y_STATE_CURRENT) != 0u, "node: selected page current state");
  expect_status(er_ui_node_accessibility_child(&pagination_a11y, 3u, &a11y), ER_UI_OK, "node: next page accessibility maps");
  expect_true(a11y.has_id && a11y.id == 8021u, "node: next page accessibility id");

  const char* const collapsible_titles[] = {"Typography", "Spacing"};
  const char* const collapsible_details[] = {"Variable font", "Stable gaps"};
  er_ui_node_t collapsible_a11y = er_ui_node_collapsible("Foundations", collapsible_titles, collapsible_details, 2u, true, 8022u);
  expect_status(er_ui_node_accessibility(&collapsible_a11y, &a11y), ER_UI_OK, "node: collapsible accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_GROUP, "node: collapsible accessibility role");
  expect_true((a11y.states & ER_UI_A11Y_STATE_EXPANDED) != 0u, "node: collapsible expanded state");
  expect_status(er_ui_node_accessibility_child(&collapsible_a11y, 0u, &a11y), ER_UI_OK, "node: collapsible trigger accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_BUTTON, "node: collapsible trigger accessibility role");
  expect_true(a11y.has_id && a11y.id == 8022u, "node: collapsible trigger id");
  expect_status(er_ui_node_accessibility_child(&collapsible_a11y, 2u, &a11y), ER_UI_OK, "node: collapsible row accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_LIST_ITEM, "node: collapsible row accessibility role");
  expect_true(a11y.has_id && a11y.id == 8024u, "node: collapsible row id");

  const char* const accordion_titles[] = {"Product", "Billing"};
  const char* const accordion_bodies[] = {"Network app storage", "Proof-backed receipts"};
  er_ui_node_t accordion_a11y = er_ui_node_accordion(accordion_titles, accordion_bodies, 2u, 8025u);
  expect_status(er_ui_node_accessibility(&accordion_a11y, &a11y), ER_UI_OK, "node: accordion accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_GROUP, "node: accordion accessibility role");
  expect_status(er_ui_node_accessibility_child(&accordion_a11y, 1u, &a11y), ER_UI_OK, "node: accordion item accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_BUTTON, "node: accordion item accessibility role");
  expect_true(a11y.has_id && a11y.id == 8026u, "node: accordion item id");
  expect_true((a11y.states & ER_UI_A11Y_STATE_EXPANDED) != 0u, "node: accordion item expanded state");

  er_ui_node_t hover_a11y = er_ui_node_hover_card("ER", "UI", "Reusable shadcn primitive.", er_ui_color_rgba(0.1f, 0.2f, 0.3f, 1.0f));
  expect_status(er_ui_node_accessibility(&hover_a11y, &a11y), ER_UI_OK, "node: hover card accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_GROUP, "node: hover card accessibility role");
  expect_true(a11y.label == hover_a11y.label, "node: hover card label is borrowed");
  expect_true((a11y.states & ER_UI_A11Y_STATE_HAS_VALUE) != 0u, "node: hover card detail value state");

  er_ui_node_t popover_a11y = er_ui_node_popover("Open popover", "Dimensions", "Set layout constraints.", "Width", "100%", 8027u);
  expect_status(er_ui_node_accessibility(&popover_a11y, &a11y), ER_UI_OK, "node: popover accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_DIALOG, "node: popover accessibility role");
  expect_true(a11y.label == popover_a11y.value, "node: popover title is borrowed");
  expect_status(er_ui_node_accessibility_child(&popover_a11y, 0u, &a11y), ER_UI_OK, "node: popover trigger accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_BUTTON, "node: popover trigger accessibility role");
  expect_true(a11y.has_id && a11y.id == 8027u, "node: popover trigger id");
  expect_status(er_ui_node_accessibility_child(&popover_a11y, 1u, &a11y), ER_UI_OK, "node: popover field accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_TEXTBOX, "node: popover field accessibility role");
  expect_true(a11y.has_id && a11y.id == 8028u, "node: popover field id");

  er_ui_node_t sheet_a11y = er_ui_node_sheet("Profile", "Update local profile.", "Name", "EdgeRun", "Save changes", 8029u);
  expect_status(er_ui_node_accessibility(&sheet_a11y, &a11y), ER_UI_OK, "node: sheet accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_DIALOG, "node: sheet accessibility role");
  expect_true(a11y.label == sheet_a11y.label, "node: sheet title is borrowed");
  expect_status(er_ui_node_accessibility_child(&sheet_a11y, 0u, &a11y), ER_UI_OK, "node: sheet field accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_TEXTBOX, "node: sheet field accessibility role");
  expect_true(a11y.has_id && a11y.id == 8029u, "node: sheet field id");
  expect_status(er_ui_node_accessibility_child(&sheet_a11y, 1u, &a11y), ER_UI_OK, "node: sheet button accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_BUTTON, "node: sheet button accessibility role");
  expect_true(a11y.has_id && a11y.id == 8030u, "node: sheet button id");

  const char* const kbd_keys[] = {"Cmd", "K"};
  er_ui_node_t kbd_a11y = er_ui_node_kbd(kbd_keys, 2u, "Open command palette");
  expect_status(er_ui_node_accessibility(&kbd_a11y, &a11y), ER_UI_OK, "node: kbd accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_GROUP, "node: kbd accessibility role");
  expect_true(a11y.label == kbd_a11y.label, "node: kbd label is borrowed");

  const char* const menubar_items[] = {"File", "Edit", "View"};
  er_ui_node_t menubar_a11y = er_ui_node_menubar(menubar_items, 3u, 1u, 8031u);
  expect_status(er_ui_node_accessibility(&menubar_a11y, &a11y), ER_UI_OK, "node: menubar accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_NAVIGATION, "node: menubar accessibility role");
  expect_status(er_ui_node_accessibility_child(&menubar_a11y, 1u, &a11y), ER_UI_OK, "node: menubar item accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_BUTTON, "node: menubar item accessibility role");
  expect_true(a11y.has_id && a11y.id == 8032u, "node: menubar item id");
  expect_true((a11y.states & ER_UI_A11Y_STATE_SELECTED) != 0u, "node: menubar selected item state");

  const char* const radio_group_labels[] = {"Default", "Comfortable", "Compact"};
  er_ui_node_t radio_group_a11y = er_ui_node_radio_group(radio_group_labels, 3u, 2u, 8034u);
  expect_status(er_ui_node_accessibility(&radio_group_a11y, &a11y), ER_UI_OK, "node: radio group accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_GROUP, "node: radio group accessibility role");
  expect_status(er_ui_node_accessibility_child(&radio_group_a11y, 2u, &a11y), ER_UI_OK, "node: radio group item accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_RADIO, "node: radio group item accessibility role");
  expect_true(a11y.has_id && a11y.id == 8036u, "node: radio group item id");
  expect_true((a11y.states & ER_UI_A11Y_STATE_CHECKED) != 0u, "node: radio group selected item state");

  er_ui_node_t input_group_a11y = er_ui_node_input_group("URL", "https://edgerun.local", "Copy", 8038u);
  expect_status(er_ui_node_accessibility(&input_group_a11y, &a11y), ER_UI_OK, "node: input group accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_GROUP, "node: input group accessibility role");
  expect_status(er_ui_node_accessibility_child(&input_group_a11y, 0u, &a11y), ER_UI_OK, "node: input group field accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_TEXTBOX, "node: input group field accessibility role");
  expect_true(a11y.has_id && a11y.id == 8038u, "node: input group field id");
  expect_status(er_ui_node_accessibility_child(&input_group_a11y, 1u, &a11y), ER_UI_OK, "node: input group button accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_BUTTON, "node: input group button accessibility role");
  expect_true(a11y.has_id && a11y.id == 8039u, "node: input group button id");

  const char* const otp_values[] = {"1", "2", "3", "-", "4", "5"};
  er_ui_node_t otp_a11y = er_ui_node_input_otp(otp_values, 6u, 4u, 8040u);
  expect_status(er_ui_node_accessibility(&otp_a11y, &a11y), ER_UI_OK, "node: input otp accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_GROUP, "node: input otp accessibility role");
  expect_status(er_ui_node_accessibility_child(&otp_a11y, 4u, &a11y), ER_UI_OK, "node: input otp digit accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_TEXTBOX, "node: input otp digit accessibility role");
  expect_true(a11y.has_id && a11y.id == 8044u, "node: input otp digit id");
  expect_true((a11y.states & ER_UI_A11Y_STATE_FOCUSED) != 0u, "node: input otp focused digit state");
  expect_status(er_ui_node_accessibility_child(&otp_a11y, 3u, &a11y), ER_UI_ERR_INVALID_ARGUMENT, "node: input otp separator is not focusable");

  const char* const nav_tabs[] = {"Docs", "Components", "Examples"};
  er_ui_node_t nav_a11y = er_ui_node_navigation_menu(nav_tabs, 3u, 1u, "Components", "Reusable primitives", "Accordion", "Disclosure rows", 8048u);
  expect_status(er_ui_node_accessibility(&nav_a11y, &a11y), ER_UI_OK, "node: navigation menu accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_NAVIGATION, "node: navigation menu accessibility role");
  expect_status(er_ui_node_accessibility_child(&nav_a11y, 1u, &a11y), ER_UI_OK, "node: navigation menu tab accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_BUTTON, "node: navigation menu tab role");
  expect_true(a11y.has_id && a11y.id == 8049u, "node: navigation menu selected tab id");
  expect_true((a11y.states & ER_UI_A11Y_STATE_SELECTED) != 0u, "node: navigation menu selected tab state");
  expect_status(er_ui_node_accessibility_child(&nav_a11y, 3u, &a11y), ER_UI_OK, "node: navigation menu row accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_LIST_ITEM, "node: navigation menu row role");
  expect_true(a11y.has_id && a11y.id == 8051u, "node: navigation menu row id");

  const char* const resizable_labels[] = {"One", "Two", "Three"};
  er_ui_node_t resizable_a11y = er_ui_node_resizable(resizable_labels, 3u);
  expect_status(er_ui_node_accessibility(&resizable_a11y, &a11y), ER_UI_OK, "node: resizable accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_GROUP, "node: resizable accessibility role");

  const char* const sidebar_items[] = {"Dashboard", "Transactions", "Settings"};
  er_ui_node_t sidebar_a11y = er_ui_node_sidebar("App", "Workspace", sidebar_items, 3u, 0u, "Dashboard", "Proof-aware activity", 8052u);
  expect_status(er_ui_node_accessibility(&sidebar_a11y, &a11y), ER_UI_OK, "node: sidebar accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_NAVIGATION, "node: sidebar accessibility role");
  expect_status(er_ui_node_accessibility_child(&sidebar_a11y, 0u, &a11y), ER_UI_OK, "node: sidebar selected item accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_MENU_ITEM, "node: sidebar selected item role");
  expect_true((a11y.states & ER_UI_A11Y_STATE_SELECTED) != 0u, "node: sidebar selected item state");
  expect_status(er_ui_node_accessibility_child(&sidebar_a11y, 3u, &a11y), ER_UI_OK, "node: sidebar main panel accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_GROUP, "node: sidebar main panel role");

  const char* const sonner_messages[] = {"Event created", "Upload failed"};
  const er_ui_icon_t sonner_icons[] = {ER_UI_ICON_CHECK, ER_UI_ICON_WARNING};
  const er_ui_color4_t sonner_colors[] = {er_ui_color_rgba(0.0f, 0.5f, 0.2f, 1.0f), er_ui_color_rgba(0.8f, 0.2f, 0.1f, 1.0f)};
  er_ui_node_t sonner_a11y = er_ui_node_sonner(sonner_messages, sonner_icons, sonner_colors, 2u);
  expect_status(er_ui_node_accessibility(&sonner_a11y, &a11y), ER_UI_OK, "node: sonner accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_STATUS, "node: sonner accessibility role");
  expect_status(er_ui_node_accessibility_child(&sonner_a11y, 1u, &a11y), ER_UI_OK, "node: sonner toast accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_STATUS, "node: sonner toast accessibility role");
  expect_true(a11y.label == sonner_messages[1], "node: sonner toast label is borrowed");

  er_ui_node_t aspect_a11y = er_ui_node_aspect_ratio("Preview", ER_UI_ICON_FILE);
  expect_status(er_ui_node_accessibility(&aspect_a11y, &a11y), ER_UI_OK, "node: aspect ratio accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_IMAGE, "node: aspect ratio accessibility role");
  expect_true(a11y.label == aspect_a11y.label, "node: aspect ratio label is borrowed");

  er_ui_node_t alert_dialog_a11y = er_ui_node_alert_dialog("Are you absolutely sure?", "This action cannot be undone.", ER_UI_ICON_WARNING);
  expect_status(er_ui_node_accessibility(&alert_dialog_a11y, &a11y), ER_UI_OK, "node: alert dialog accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_DIALOG, "node: alert dialog accessibility role");
  expect_true((a11y.states & ER_UI_A11Y_STATE_OPEN) != 0u, "node: alert dialog open state");

  er_ui_node_t direction_a11y = er_ui_node_direction("Left to right", "Right to left");
  expect_status(er_ui_node_accessibility(&direction_a11y, &a11y), ER_UI_OK, "node: direction accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_GROUP, "node: direction accessibility role");
  expect_status(er_ui_node_accessibility_child(&direction_a11y, 1u, &a11y), ER_UI_OK, "node: direction child accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_TEXT, "node: direction child role");
  expect_true(a11y.label == direction_a11y.detail, "node: direction rtl text is borrowed");

  er_ui_node_t drawer_a11y = er_ui_node_drawer("Drawer", "Adjust display density.", "Density", 0.42f, 8059u);
  expect_status(er_ui_node_accessibility(&drawer_a11y, &a11y), ER_UI_OK, "node: drawer accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_DIALOG, "node: drawer accessibility role");
  expect_true((a11y.states & ER_UI_A11Y_STATE_OPEN) != 0u, "node: drawer open state");
  expect_status(er_ui_node_accessibility_child(&drawer_a11y, 0u, &a11y), ER_UI_OK, "node: drawer slider accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_SLIDER, "node: drawer slider role");
  expect_true(a11y.has_id && a11y.id == 8059u, "node: drawer slider id");
  expect_status(er_ui_node_accessibility_child(&drawer_a11y, 1u, &a11y), ER_UI_OK, "node: drawer button accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_BUTTON, "node: drawer button role");
  expect_true(a11y.has_id && a11y.id == 8060u, "node: drawer button id");

  const char* const dropdown_labels[] = {"Profile", "Billing", "Logout"};
  const char* const dropdown_shortcuts[] = {"P", "B", ""};
  er_ui_node_t dropdown_a11y = er_ui_node_dropdown_menu(dropdown_labels, dropdown_shortcuts, 3u, 1u, 8061u);
  expect_status(er_ui_node_accessibility(&dropdown_a11y, &a11y), ER_UI_OK, "node: dropdown menu accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_NAVIGATION, "node: dropdown menu accessibility role");
  expect_status(er_ui_node_accessibility_child(&dropdown_a11y, 1u, &a11y), ER_UI_OK, "node: dropdown menu item accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_MENU_ITEM, "node: dropdown menu item role");
  expect_true(a11y.has_id && a11y.id == 8062u, "node: dropdown menu item id");
  expect_true((a11y.states & ER_UI_A11Y_STATE_SELECTED) != 0u, "node: dropdown menu selected state");

  er_ui_node_t context_menu_a11y = er_ui_node_context_menu("Actions", "Right click options", dropdown_labels, dropdown_shortcuts, 3u, 2u, 8064u);
  expect_status(er_ui_node_accessibility(&context_menu_a11y, &a11y), ER_UI_OK, "node: context menu accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_NAVIGATION, "node: context menu accessibility role");
  expect_status(er_ui_node_accessibility_child(&context_menu_a11y, 2u, &a11y), ER_UI_OK, "node: context menu item accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_MENU_ITEM, "node: context menu item role");
  expect_true(a11y.has_id && a11y.id == 8066u, "node: context menu item id");
  expect_true((a11y.states & ER_UI_A11Y_STATE_SELECTED) != 0u, "node: context menu selected state");

  const char* const date_days[] = {"12", "13", "14", "15"};
  er_ui_node_t date_picker_a11y = er_ui_node_date_picker("Pick a date", "May 2026", date_days, 4u, 2u, 8068u);
  expect_status(er_ui_node_accessibility(&date_picker_a11y, &a11y), ER_UI_OK, "node: date picker accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_COMBOBOX, "node: date picker accessibility role");
  expect_true((a11y.states & ER_UI_A11Y_STATE_OPEN) != 0u, "node: date picker open state");
  expect_status(er_ui_node_accessibility_child(&date_picker_a11y, 0u, &a11y), ER_UI_OK, "node: date picker trigger accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_BUTTON, "node: date picker trigger role");
  expect_true(a11y.has_id && a11y.id == 8068u, "node: date picker trigger id");
  expect_status(er_ui_node_accessibility_child(&date_picker_a11y, 3u, &a11y), ER_UI_OK, "node: date picker day accessibility maps");
  expect_true(a11y.has_id && a11y.id == 8071u, "node: date picker day id");
  expect_true((a11y.states & ER_UI_A11Y_STATE_SELECTED) != 0u, "node: date picker selected day state");

  const char* const carousel_items[] = {"One", "Two", "Three"};
  er_ui_node_t carousel_a11y = er_ui_node_carousel(carousel_items, 3u, 8074u);
  expect_status(er_ui_node_accessibility(&carousel_a11y, &a11y), ER_UI_OK, "node: carousel accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_GROUP, "node: carousel accessibility role");
  expect_status(er_ui_node_accessibility_child(&carousel_a11y, 0u, &a11y), ER_UI_OK, "node: carousel previous accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_BUTTON, "node: carousel previous role");
  expect_true(a11y.has_id && a11y.id == 8074u, "node: carousel previous id");
  expect_status(er_ui_node_accessibility_child(&carousel_a11y, 4u, &a11y), ER_UI_OK, "node: carousel next accessibility maps");
  expect_true(a11y.has_id && a11y.id == 8075u, "node: carousel next id");

  er_ui_node_t calendar_a11y = er_ui_node_calendar("May 2026", date_days, 4u, 2u, 8076u);
  expect_status(er_ui_node_accessibility(&calendar_a11y, &a11y), ER_UI_OK, "node: calendar accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_GROUP, "node: calendar accessibility role");
  expect_status(er_ui_node_accessibility_child(&calendar_a11y, 0u, &a11y), ER_UI_OK, "node: calendar previous accessibility maps");
  expect_true(a11y.has_id && a11y.id == 8076u, "node: calendar previous id");
  expect_status(er_ui_node_accessibility_child(&calendar_a11y, 4u, &a11y), ER_UI_OK, "node: calendar day accessibility maps");
  expect_true(a11y.has_id && a11y.id == 8080u, "node: calendar day id");
  expect_true((a11y.states & ER_UI_A11Y_STATE_SELECTED) != 0u, "node: calendar selected day state");

  const char* const combobox_options[] = {"Apple", "Banana", "Cherry"};
  er_ui_node_t combobox_a11y = er_ui_node_combobox("Fruit", "Banana", "Search fruit...", combobox_options, 3u, 1u, 8082u);
  expect_status(er_ui_node_accessibility(&combobox_a11y, &a11y), ER_UI_OK, "node: combobox accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_COMBOBOX, "node: combobox accessibility role");
  expect_true((a11y.states & ER_UI_A11Y_STATE_OPEN) != 0u, "node: combobox open state");
  expect_status(er_ui_node_accessibility_child(&combobox_a11y, 3u, &a11y), ER_UI_OK, "node: combobox option accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_MENU_ITEM, "node: combobox option role");
  expect_true(a11y.has_id && a11y.id == 8085u, "node: combobox option id");
  expect_true((a11y.states & ER_UI_A11Y_STATE_SELECTED) != 0u, "node: combobox selected option state");

  const char* const diff_lines[] = {"@@ -1,2 +1,2 @@", "-old", "+new", " context"};
  er_ui_node_t diff_body_a11y = er_ui_node_diff_body(diff_lines, 4u, true);
  expect_status(er_ui_node_accessibility(&diff_body_a11y, &a11y), ER_UI_OK, "node: diff body accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_GROUP, "node: diff body accessibility role");
  expect_true((a11y.states & ER_UI_A11Y_STATE_HAS_VALUE) != 0u, "node: diff body truncated state is exposed");
  expect_status(er_ui_node_accessibility_child(&diff_body_a11y, 2u, &a11y), ER_UI_OK, "node: diff body line accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_TEXT, "node: diff body line role");
  expect_true(a11y.label == diff_lines[2], "node: diff body line label is borrowed");
  expect_status(er_ui_node_accessibility_child(&diff_body_a11y, 4u, &a11y), ER_UI_OK, "node: diff body truncated accessibility maps");
  expect_string(a11y.label, "[diff preview truncated]", "node: diff body truncated label");

  er_ui_node_t chat_message_a11y = er_ui_node_chat_message(ER_UI_SHADCN_CHAT_ROLE_ASSISTANT, "Response", "Done");
  expect_status(er_ui_node_accessibility(&chat_message_a11y, &a11y), ER_UI_OK, "node: chat message accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_GROUP, "node: chat message accessibility role");
  expect_string(a11y.label, "assistant", "node: chat message role label maps");
  expect_true(a11y.value == chat_message_a11y.detail, "node: chat message detail is borrowed");
  er_ui_node_t chat_diff_a11y = er_ui_node_chat_diff_message("Patch", diff_lines, 4u, true);
  expect_status(er_ui_node_accessibility_child(&chat_diff_a11y, 3u, &a11y), ER_UI_OK, "node: chat diff line accessibility maps");
  expect_true(a11y.label == diff_lines[2], "node: chat diff line label is borrowed");

  er_ui_node_t conversation_a11y = er_ui_node_conversation(12.0f, 8090u);
  er_ui_node_t conversation_child_a = er_ui_node_chat_message(ER_UI_SHADCN_CHAT_ROLE_USER, "", "Run tests");
  er_ui_node_t conversation_child_b = er_ui_node_chat_message(ER_UI_SHADCN_CHAT_ROLE_ASSISTANT, "Response", "Tests passed");
  expect_status(er_ui_node_add_child(&conversation_a11y, &conversation_child_a), ER_UI_OK, "node: conversation accepts first child");
  expect_status(er_ui_node_add_child(&conversation_a11y, &conversation_child_b), ER_UI_OK, "node: conversation accepts second child");
  expect_status(er_ui_node_accessibility(&conversation_a11y, &a11y), ER_UI_OK, "node: conversation accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_GROUP, "node: conversation accessibility role");
  expect_true(a11y.has_id && a11y.id == 8090u, "node: conversation scroll id");
  expect_status(er_ui_node_accessibility_child(&conversation_a11y, 1u, &a11y), ER_UI_OK, "node: conversation child accessibility maps");
  expect_string(a11y.label, "assistant", "node: conversation child role is preserved");
  expect_status(er_ui_node_child_bounds(&conversation_a11y, 0u, er_ui_bounds(0.0f, 0.0f, 360.0f, 220.0f), &resolved_child), ER_UI_OK,
                "node: conversation child bounds resolve");
  expect_float(resolved_child.y, 4.0f, "node: conversation child bounds apply padding and scroll offset");

  er_ui_node_t checked = er_ui_node_checkbox("Remember", true, 8002u);
  expect_status(er_ui_node_accessibility(&checked, &a11y), ER_UI_OK, "node: checkbox accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_CHECKBOX, "node: checkbox accessibility role");
  expect_true((a11y.states & ER_UI_A11Y_STATE_CHECKED) != 0u, "node: checkbox accessibility checked state");

  er_ui_node_t field_a11y = er_ui_node_field("Email", "name@example.com", 8003u);
  expect_status(er_ui_node_accessibility(&field_a11y, &a11y), ER_UI_OK, "node: field accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_TEXTBOX, "node: field accessibility role");
  expect_true((a11y.states & ER_UI_A11Y_STATE_HAS_VALUE) != 0u, "node: field accessibility value state");
  expect_true(a11y.value == field_a11y.value, "node: field accessibility value is borrowed");

  er_ui_node_t tree_a11y = er_ui_node_tree_item("src", "expanded", 1u, true, 8004u);
  expect_status(er_ui_node_accessibility(&tree_a11y, &a11y), ER_UI_OK, "node: tree accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_LIST_ITEM, "node: tree accessibility role");
  expect_true((a11y.states & ER_UI_A11Y_STATE_EXPANDED) != 0u, "node: tree accessibility expanded state");
  expect_true(er_ui_a11y_role_label(a11y.role) != NULL, "node: accessibility role has stable label");

  const char* const a11y_tabs[] = {"One", "Two"};
  er_ui_node_t tabs_a11y = er_ui_node_tabs(a11y_tabs, 2u, 1u, 8005u);
  expect_status(er_ui_node_accessibility(&tabs_a11y, &a11y), ER_UI_OK, "node: tab list accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_TAB_LIST, "node: tab list accessibility role");
  expect_status(er_ui_node_accessibility_child(&tabs_a11y, 1u, &a11y), ER_UI_OK, "node: selected tab accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_TAB, "node: selected tab accessibility role");
  expect_true(a11y.has_id && a11y.id == 8006u, "node: selected tab accessibility id");
  expect_true((a11y.states & ER_UI_A11Y_STATE_SELECTED) != 0u, "node: selected tab accessibility state");

  const char* const a11y_headers[] = {"Name"};
  const char* const a11y_cells[] = {"EdgeRun"};
  er_ui_node_t table_a11y = er_ui_node_table(a11y_headers, 1u, a11y_cells, 1u, 8010u);
  expect_status(er_ui_node_accessibility_child(&table_a11y, 0u, &a11y), ER_UI_OK, "node: table header accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_ROW, "node: table header accessibility role");
  expect_status(er_ui_node_accessibility_child(&table_a11y, 1u, &a11y), ER_UI_OK, "node: table row accessibility maps");
  expect_true(a11y.has_id && a11y.id == 8010u, "node: table row accessibility id");

  er_ui_node_t full = er_ui_node_row();
  er_ui_node_t children[ER_UI_NODE_MAX_CHILDREN + 1u];
  for (size_t i = 0u; i < ER_UI_NODE_MAX_CHILDREN; ++i) {
    children[i] = er_ui_node_skeleton();
    expect_status(er_ui_node_add_child(&full, &children[i]), ER_UI_OK, "node: fixed child slot accepts within capacity");
  }
  children[ER_UI_NODE_MAX_CHILDREN] = er_ui_node_skeleton();
  expect_status(er_ui_node_add_child(&full, &children[ER_UI_NODE_MAX_CHILDREN]), ER_UI_ERR_OOM, "node: fixed child capacity rejects overflow");

  er_ui_scene_t scene = {0};
  expect_status(er_ui_scene_init_with_allocator(&scene, er_ui_palette_slate_950(), er_ui_test_allocator()), ER_UI_OK, "node: scene init succeeds");
  vr_font_face_t* face = node_open_test_font();
  if (face) {
    er_ui_resolved_theme_t theme = er_ui_resolved_theme_user_default();
    expect_status(er_ui_node_render(&root, &scene, face, er_ui_bounds(0.0f, 0.0f, 320.0f, 160.0f), theme), ER_UI_OK,
                  "node: card tree renders");

    er_ui_node_t alert = er_ui_node_alert("Heads up", "Reusable components stay in UI core.", theme.colors.warning);
    er_ui_node_t avatar = er_ui_node_avatar("ER", theme.colors.accent, true);
    er_ui_node_t progress = er_ui_node_progress(0.66f);
    er_ui_node_t switch_node = er_ui_node_switch(true, 8002u);
    const char* const breadcrumb_labels[] = {"Docs", "Components", "Button"};
    er_ui_node_t breadcrumb = er_ui_node_breadcrumb(breadcrumb_labels, 3u, 2u, 8100u);
    const char* const table_headers[] = {"Invoice", "Status"};
    const char* const table_cells[] = {"INV001", "Paid", "INV002", "Pending"};
    er_ui_node_t table = er_ui_node_table(table_headers, 2u, table_cells, 2u, 8200u);
    er_ui_node_t toast = er_ui_node_toast("Scheduled", theme.colors.accent);
    er_ui_node_t toast_icon = er_ui_node_toast_icon("Saved", ER_UI_ICON_CHECK, theme.colors.success);
    er_ui_node_t card_summary = er_ui_node_card_summary("Title", "Detail");
    er_ui_node_t empty = er_ui_node_empty("No results", "Try another filter.");
    er_ui_node_t list_row = er_ui_node_list_row("Billing", "Command B", 8300u, true);
    er_ui_node_t field = er_ui_node_field("Email", "name@example.com", 8400u);
    er_ui_node_t text_area = er_ui_node_text_area("Message", "Type your message here.", 8401u);
    const char* const tab_labels[] = {"Account", "Billing", "Team"};
    er_ui_node_t tabs = er_ui_node_tabs(tab_labels, 3u, 1u, 8500u);
    const char* const chart_labels[] = {"Jan", "Feb", "Mar"};
    const float chart_values[] = {0.25f, 0.72f, 0.54f};
    er_ui_node_t chart = er_ui_node_bar_chart("Visitors", chart_labels, chart_values, 3u, 8600u, 1u);
    er_ui_node_t command = er_ui_node_command_palette("Search components...", 8700u);
    er_ui_node_t tree_item = er_ui_node_tree_item("src", "expanded", 1u, true, 8800u);
    er_ui_node_t section = er_ui_node_section("Proof", "Verified rows");
    er_ui_node_t identity = er_ui_node_identity_card("Ken", "browser-node", "personal", 8801u);
    er_ui_node_t contact = er_ui_node_contact_card("Ada", "publisher", 8802u);
    er_ui_node_t thread = er_ui_node_thread_row("Sync complete", "Drive import finished", true, 8803u);
    er_ui_node_t attachment = er_ui_node_attachment_preview("manifest.rkyv", "package manifest", 8804u);
    er_ui_node_t grant = er_ui_node_capability_grant_row("Mail", "contacts:read", "granted", 8805u);
    er_ui_node_t proof = er_ui_node_proof_event_row("Package hash", "b3:abc123", "verified", 8806u);
    const char* const route_hops[] = {"browser", "admission", "relay"};
    er_ui_node_t route = er_ui_node_route_path("Admission route", route_hops, 3u);
    er_ui_node_t package = er_ui_node_package_card("Docs", "cache-ok", "b3:def456", 8807u);
    er_ui_node_t receipt = er_ui_node_receipt_row("Retrieval", "4 units", "settled", 8808u);
    er_ui_node_t panel = er_ui_node_panel_header("Dashboard", "Reusable UI primitives", "Run", 8809u);
    er_ui_node_t metric = er_ui_node_metric_card("Budget", "184", "units reserved", true, 0.64f, theme.colors.accent);
    er_ui_node_t transaction = er_ui_node_transaction_row("Storage", "verified retrieval", "today", "8 units", false, 8810u);
    er_ui_node_t menu = er_ui_node_menu_item("Verify package", "content hash", "new", true, theme.colors.accent, 8811u);
    er_ui_node_t control = er_ui_node_control_row("Cache package", "avoid repeated retrieval", "enabled", 8812u);
    er_ui_node_t grid = er_ui_node_grid(2u);
    er_ui_node_set_gap(&grid, 4.0f);
    er_ui_node_t grid_badge_a = er_ui_node_badge("One", ER_UI_SHADCN_BADGE_DEFAULT);
    er_ui_node_t grid_badge_b = er_ui_node_badge("Two", ER_UI_SHADCN_BADGE_SECONDARY);
    er_ui_node_t grid_badge_c = er_ui_node_badge("Three", ER_UI_SHADCN_BADGE_OUTLINE);
    expect_status(er_ui_node_add_child(&grid, &grid_badge_a), ER_UI_OK, "node: grid accepts first child");
    expect_status(er_ui_node_add_child(&grid, &grid_badge_b), ER_UI_OK, "node: grid accepts second child");
    expect_status(er_ui_node_add_child(&grid, &grid_badge_c), ER_UI_OK, "node: grid accepts third child");
    expect_status(er_ui_node_child_bounds(&grid, 2u, er_ui_bounds(0.0f, 0.0f, 260.0f, 80.0f), &resolved_child), ER_UI_OK,
                  "node: grid child bounds resolve");
    expect_float(resolved_child.x, 0.0f, "node: grid child bounds x wraps");
    expect_float(resolved_child.y, 42.0f, "node: grid child bounds y wraps");
    expect_float(resolved_child.w, 128.0f, "node: grid child bounds width divides columns");
    expect_float(resolved_child.h, 38.0f, "node: grid child bounds height divides rows");
    er_ui_node_t scroll = er_ui_node_scroll_area(20.0f, 8813u);
    er_ui_node_set_gap(&scroll, 4.0f);
    er_ui_node_t scroll_a = er_ui_node_list_row("Top", "scrolled", 8814u, false);
    er_ui_node_t scroll_b = er_ui_node_list_row("Bottom", "visible", 8815u, true);
    expect_status(er_ui_node_add_child(&scroll, &scroll_a), ER_UI_OK, "node: scroll accepts first child");
    expect_status(er_ui_node_add_child(&scroll, &scroll_b), ER_UI_OK, "node: scroll accepts second child");
    expect_status(er_ui_node_child_bounds(&scroll, 0u, er_ui_bounds(0.0f, 2560.0f, 260.0f, 64.0f), &resolved_child), ER_UI_OK,
                  "node: scroll child bounds resolve offset");
    expect_float(resolved_child.y, 2540.0f, "node: scroll child bounds applies offset");
    er_ui_node_t spacer = er_ui_node_spacer();
    er_ui_node_t tooltip = er_ui_node_tooltip("Verify package");
    er_ui_node_t dialog = er_ui_node_dialog("Run network app", "Verify signed package bytes first.", theme.colors.accent);
    er_ui_node_t ring = er_ui_node_progress_ring(0.58f, theme.colors.success);
    er_ui_node_t reorderable = er_ui_node_list_row("Drag me", "reorderable", 8816u, false);
    er_ui_node_set_reorderable(&reorderable, 42u, 8816u, 3u);
    er_ui_node_t icon = er_ui_node_icon(ER_UI_ICON_TRUST, "Trust", theme.colors.accent);
    er_ui_node_t icon_button = er_ui_node_icon_button(ER_UI_ICON_SEARCH, "Search", 8817u, ER_UI_SHADCN_BUTTON_GHOST);
    const char* const render_button_group_labels[] = {"Copy", "Paste", "More"};
    er_ui_node_t button_group = er_ui_node_button_group(render_button_group_labels, 3u, 8818u);
    const char* const render_toggle_group_labels[] = {"B", "I", "U"};
    er_ui_node_t toggle_group = er_ui_node_toggle_group(render_toggle_group_labels, 3u, 1u, 8821u);
    const char* const render_pagination_labels[] = {"1", "2"};
    er_ui_node_t pagination = er_ui_node_pagination(render_pagination_labels, 2u, 0u, 8824u);
    const char* const render_collapsible_titles[] = {"Accordion", "Collapsible"};
    const char* const render_collapsible_details[] = {"one open item", "disclosure rows"};
    er_ui_node_t collapsible = er_ui_node_collapsible("Disclosure", render_collapsible_titles, render_collapsible_details, 2u, true, 8828u);
    const char* const render_accordion_titles[] = {"Is it accessible?", "Is it styled?"};
    const char* const render_accordion_bodies[] = {"Yes, each trigger is exposed.", "It uses shared shadcn primitives."};
    er_ui_node_t accordion = er_ui_node_accordion(render_accordion_titles, render_accordion_bodies, 2u, 8831u);
    er_ui_node_t hover_card = er_ui_node_hover_card("ER", "UI core", "Variable font rendering stays required.", theme.colors.accent);
    er_ui_node_t popover = er_ui_node_popover("Open popover", "Dimensions", "Set layout constraints.", "Width", "100%", 8833u);
    er_ui_node_t sheet = er_ui_node_sheet("Profile", "Update local profile.", "Name", "EdgeRun", "Save changes", 8835u);
    const char* const render_kbd_keys[] = {"Ctrl", "K"};
    er_ui_node_t kbd = er_ui_node_kbd(render_kbd_keys, 2u, "Open command palette");
    const char* const render_menubar_items[] = {"File", "Edit", "View"};
    er_ui_node_t menubar = er_ui_node_menubar(render_menubar_items, 3u, 1u, 8837u);
    const char* const render_radio_group_labels[] = {"Default", "Comfortable", "Compact"};
    er_ui_node_t radio_group = er_ui_node_radio_group(render_radio_group_labels, 3u, 0u, 8840u);
    er_ui_node_t input_group = er_ui_node_input_group("URL", "https://edgerun.local", "Copy", 8843u);
    const char* const render_otp_values[] = {"1", "2", "3", "-", "4", ""};
    er_ui_node_t input_otp = er_ui_node_input_otp(render_otp_values, 6u, 5u, 8845u);
    const char* const render_nav_tabs[] = {"Docs", "Components", "Examples"};
    er_ui_node_t navigation_menu =
      er_ui_node_navigation_menu(render_nav_tabs, 3u, 1u, "Components", "Reusable primitives", "Accordion", "Disclosure rows", 8852u);
    const char* const render_resizable_labels[] = {"One", "Two", "Three"};
    er_ui_node_t resizable = er_ui_node_resizable(render_resizable_labels, 3u);
    const char* const render_sidebar_items[] = {"Dashboard", "Transactions", "Settings"};
    er_ui_node_t sidebar = er_ui_node_sidebar("App", "Workspace", render_sidebar_items, 3u, 0u, "Dashboard", "Proof-aware activity", 8856u);
    const char* const render_sonner_messages[] = {"Event created", "Upload failed"};
    const er_ui_icon_t render_sonner_icons[] = {ER_UI_ICON_CHECK, ER_UI_ICON_WARNING};
    const er_ui_color4_t render_sonner_colors[] = {theme.colors.success, theme.colors.danger};
    er_ui_node_t sonner = er_ui_node_sonner(render_sonner_messages, render_sonner_icons, render_sonner_colors, 2u);
    er_ui_node_t aspect = er_ui_node_aspect_ratio("Preview", ER_UI_ICON_FILE);
    er_ui_node_t alert_dialog = er_ui_node_alert_dialog("Are you absolutely sure?", "This action cannot be undone.", ER_UI_ICON_WARNING);
    er_ui_node_t direction = er_ui_node_direction("Left to right", "Right to left");
    er_ui_node_t drawer = er_ui_node_drawer("Drawer", "Adjust display density.", "Density", 0.42f, 8860u);
    const char* const render_dropdown_labels[] = {"Profile", "Billing", "Logout"};
    const char* const render_dropdown_shortcuts[] = {"P", "B", ""};
    er_ui_node_t dropdown_menu = er_ui_node_dropdown_menu(render_dropdown_labels, render_dropdown_shortcuts, 3u, 1u, 8862u);
    er_ui_node_t context_menu = er_ui_node_context_menu("Actions", "Right click options", render_dropdown_labels, render_dropdown_shortcuts, 3u, 2u, 8865u);
    const char* const render_date_days[] = {"12", "13", "14", "15"};
    er_ui_node_t date_picker = er_ui_node_date_picker("Pick a date", "May 2026", render_date_days, 4u, 2u, 8868u);
    const char* const render_carousel_items[] = {"One", "Two", "Three"};
    er_ui_node_t carousel = er_ui_node_carousel(render_carousel_items, 3u, 8874u);
    er_ui_node_t calendar = er_ui_node_calendar("May 2026", render_date_days, 4u, 2u, 8876u);
    const char* const render_combobox_options[] = {"Apple", "Banana", "Cherry"};
    er_ui_node_t combobox = er_ui_node_combobox("Fruit", "Banana", "Search fruit...", render_combobox_options, 3u, 1u, 8882u);
    const char* const render_diff_lines[] = {"@@ -1,2 +1,2 @@", "-old", "+new", "*** End Patch"};
    er_ui_node_t diff_body = er_ui_node_diff_body(render_diff_lines, 4u, true);
    er_ui_node_t chat_message = er_ui_node_chat_message(ER_UI_SHADCN_CHAT_ROLE_ASSISTANT, "Response", "Done");
    er_ui_node_t chat_timeline = er_ui_node_chat_message(ER_UI_SHADCN_CHAT_ROLE_TOOL_RUNNING, "Started", "shell");
    er_ui_node_t chat_diff = er_ui_node_chat_diff_message("Patch", render_diff_lines, 4u, true);
    er_ui_node_t conversation = er_ui_node_conversation(8.0f, 8890u);
    er_ui_node_t conversation_a = er_ui_node_chat_message(ER_UI_SHADCN_CHAT_ROLE_USER, "", "Run tests");
    er_ui_node_t conversation_b = er_ui_node_chat_message(ER_UI_SHADCN_CHAT_ROLE_ASSISTANT, "Response", "Tests passed");
    expect_status(er_ui_node_add_child(&conversation, &conversation_a), ER_UI_OK, "node: render conversation accepts first child");
    expect_status(er_ui_node_add_child(&conversation, &conversation_b), ER_UI_OK, "node: render conversation accepts second child");

    expect_status(er_ui_node_render(&alert, &scene, face, er_ui_bounds(0.0f, 170.0f, 360.0f, 76.0f), theme), ER_UI_OK, "node: alert renders");
    expect_status(er_ui_node_render(&avatar, &scene, face, er_ui_bounds(0.0f, 254.0f, 42.0f, 42.0f), theme), ER_UI_OK, "node: avatar renders");
    expect_status(er_ui_node_render(&progress, &scene, face, er_ui_bounds(54.0f, 268.0f, 180.0f, 8.0f), theme), ER_UI_OK,
                  "node: progress renders");
    expect_status(er_ui_node_render(&switch_node, &scene, face, er_ui_bounds(246.0f, 262.0f, 44.0f, 24.0f), theme), ER_UI_OK,
                  "node: switch renders");
    expect_status(er_ui_node_render(&breadcrumb, &scene, face, er_ui_bounds(0.0f, 308.0f, 320.0f, 34.0f), theme), ER_UI_OK,
                  "node: breadcrumb renders");
    expect_status(er_ui_node_render(&table, &scene, face, er_ui_bounds(0.0f, 354.0f, 320.0f, 112.0f), theme), ER_UI_OK, "node: table renders");
    expect_status(er_ui_node_render(&toast, &scene, face, er_ui_bounds(0.0f, 478.0f, 260.0f, 48.0f), theme), ER_UI_OK, "node: toast renders");
    size_t icon_quads_before_toast = scene.icon_quad_count;
    expect_status(er_ui_node_render(&toast_icon, &scene, face, er_ui_bounds(0.0f, 530.0f, 260.0f, 48.0f), theme), ER_UI_OK,
                  "node: icon toast renders");
    expect_size(scene.icon_quad_count, icon_quads_before_toast + 1u, "node: icon toast emits icon quad");
    size_t text_before_card_summary = scene.text_quad_count;
    expect_status(er_ui_node_render(&card_summary, &scene, face, er_ui_bounds(0.0f, 584.0f, 260.0f, 84.0f), theme), ER_UI_OK,
                  "node: card summary renders");
    expect_true(scene.text_quad_count > text_before_card_summary, "node: card summary emits variable font text");
    expect_status(er_ui_node_render(&empty, &scene, face, er_ui_bounds(0.0f, 538.0f, 280.0f, 120.0f), theme), ER_UI_OK, "node: empty renders");
    expect_status(er_ui_node_render(&list_row, &scene, face, er_ui_bounds(0.0f, 670.0f, 220.0f, 44.0f), theme), ER_UI_OK,
                  "node: list row renders");
    expect_status(er_ui_node_render(&field, &scene, face, er_ui_bounds(0.0f, 726.0f, 240.0f, 58.0f), theme), ER_UI_OK, "node: field renders");
    expect_status(er_ui_node_render(&text_area, &scene, face, er_ui_bounds(0.0f, 796.0f, 280.0f, 84.0f), theme), ER_UI_OK,
                  "node: text area renders");
    expect_status(er_ui_node_render(&tabs, &scene, face, er_ui_bounds(0.0f, 892.0f, 300.0f, 38.0f), theme), ER_UI_OK, "node: tabs render");
    expect_status(er_ui_node_render(&chart, &scene, face, er_ui_bounds(0.0f, 942.0f, 320.0f, 160.0f), theme), ER_UI_OK,
                  "node: bar chart renders");
    expect_status(er_ui_node_render(&command, &scene, face, er_ui_bounds(0.0f, 1114.0f, 300.0f, 46.0f), theme), ER_UI_OK,
                  "node: command palette renders");
    expect_status(er_ui_node_render(&tree_item, &scene, face, er_ui_bounds(0.0f, 1172.0f, 320.0f, 42.0f), theme), ER_UI_OK,
                  "node: tree item renders");
    expect_status(er_ui_node_render(&section, &scene, face, er_ui_bounds(0.0f, 1226.0f, 320.0f, 34.0f), theme), ER_UI_OK,
                  "node: section renders");
    expect_status(er_ui_node_render(&identity, &scene, face, er_ui_bounds(0.0f, 1272.0f, 320.0f, 110.0f), theme), ER_UI_OK,
                  "node: identity card renders");
    expect_status(er_ui_node_render(&contact, &scene, face, er_ui_bounds(0.0f, 1394.0f, 320.0f, 64.0f), theme), ER_UI_OK,
                  "node: contact card renders");
    expect_status(er_ui_node_render(&thread, &scene, face, er_ui_bounds(0.0f, 1470.0f, 320.0f, 58.0f), theme), ER_UI_OK,
                  "node: thread row renders");
    expect_status(er_ui_node_render(&attachment, &scene, face, er_ui_bounds(0.0f, 1540.0f, 320.0f, 64.0f), theme), ER_UI_OK,
                  "node: attachment preview renders");
    expect_status(er_ui_node_render(&grant, &scene, face, er_ui_bounds(0.0f, 1616.0f, 360.0f, 58.0f), theme), ER_UI_OK,
                  "node: capability grant row renders");
    expect_status(er_ui_node_render(&proof, &scene, face, er_ui_bounds(0.0f, 1686.0f, 360.0f, 58.0f), theme), ER_UI_OK,
                  "node: proof event row renders");
    expect_status(er_ui_node_render(&route, &scene, face, er_ui_bounds(0.0f, 1756.0f, 360.0f, 86.0f), theme), ER_UI_OK,
                  "node: route path renders");
    expect_status(er_ui_node_render(&package, &scene, face, er_ui_bounds(0.0f, 1854.0f, 320.0f, 110.0f), theme), ER_UI_OK,
                  "node: package card renders");
    expect_status(er_ui_node_render(&receipt, &scene, face, er_ui_bounds(0.0f, 1976.0f, 360.0f, 58.0f), theme), ER_UI_OK,
                  "node: receipt row renders");
    expect_status(er_ui_node_render(&panel, &scene, face, er_ui_bounds(0.0f, 2046.0f, 360.0f, 56.0f), theme), ER_UI_OK,
                  "node: panel header renders");
    expect_status(er_ui_node_render(&metric, &scene, face, er_ui_bounds(0.0f, 2114.0f, 220.0f, 132.0f), theme), ER_UI_OK,
                  "node: metric card renders");
    expect_status(er_ui_node_render(&transaction, &scene, face, er_ui_bounds(0.0f, 2258.0f, 360.0f, 58.0f), theme), ER_UI_OK,
                  "node: transaction row renders");
    expect_status(er_ui_node_render(&menu, &scene, face, er_ui_bounds(0.0f, 2328.0f, 260.0f, 58.0f), theme), ER_UI_OK,
                  "node: menu item renders");
    expect_status(er_ui_node_render(&control, &scene, face, er_ui_bounds(0.0f, 2398.0f, 360.0f, 58.0f), theme), ER_UI_OK,
                  "node: control row renders");
    expect_status(er_ui_node_render(&grid, &scene, face, er_ui_bounds(0.0f, 2468.0f, 260.0f, 80.0f), theme), ER_UI_OK,
                  "node: grid renders children");
    expect_status(er_ui_node_render(&scroll, &scene, face, er_ui_bounds(0.0f, 2560.0f, 260.0f, 64.0f), theme), ER_UI_OK,
                  "node: scroll area renders clipped children");
    expect_status(er_ui_node_render(&spacer, &scene, face, er_ui_bounds(0.0f, 2636.0f, 24.0f, 24.0f), theme), ER_UI_OK,
                  "node: spacer renders as no-op");
    expect_status(er_ui_node_render(&tooltip, &scene, face, er_ui_bounds(0.0f, 2672.0f, 180.0f, 34.0f), theme), ER_UI_OK,
                  "node: tooltip renders");
    expect_status(er_ui_node_render(&dialog, &scene, face, er_ui_bounds(0.0f, 2718.0f, 360.0f, 140.0f), theme), ER_UI_OK,
                  "node: dialog renders");
    expect_status(er_ui_node_render(&ring, &scene, face, er_ui_bounds(0.0f, 2870.0f, 48.0f, 48.0f), theme), ER_UI_OK,
                  "node: progress ring renders");
    size_t icon_quads_before = scene.icon_quad_count;
    size_t hits_before_icon_button = scene.hit_count;
    expect_status(er_ui_node_render(&icon, &scene, face, er_ui_bounds(64.0f, 2870.0f, 32.0f, 32.0f), theme), ER_UI_OK,
                  "node: icon renders");
    expect_size(scene.icon_quad_count, icon_quads_before + 1u, "node: icon emits icon quad");
    expect_u32(scene.icon_quads[icon_quads_before].atlas_id, er_ui_icon_atlas_id(ER_UI_ICON_TRUST), "node: icon quad carries atlas id");
    expect_status(er_ui_node_render(&icon_button, &scene, face, er_ui_bounds(108.0f, 2870.0f, 40.0f, 40.0f), theme), ER_UI_OK,
                  "node: icon button renders");
    expect_size(scene.icon_quad_count, icon_quads_before + 2u, "node: icon button emits icon quad");
    expect_size(scene.hit_count, hits_before_icon_button + 1u, "node: icon button emits hit");
    size_t hits_before_groups = scene.hit_count;
    expect_status(er_ui_node_render(&button_group, &scene, face, er_ui_bounds(160.0f, 2870.0f, 210.0f, 38.0f), theme), ER_UI_OK,
                  "node: button group renders");
    expect_size(scene.hit_count, hits_before_groups + 3u, "node: button group emits button hits");
    expect_status(er_ui_node_render(&toggle_group, &scene, face, er_ui_bounds(0.0f, 2994.0f, 126.0f, 38.0f), theme), ER_UI_OK,
                  "node: toggle group renders");
    expect_size(scene.hit_count, hits_before_groups + 6u, "node: toggle group emits button hits");
    expect_status(er_ui_node_render(&pagination, &scene, face, er_ui_bounds(140.0f, 2994.0f, 212.0f, 40.0f), theme), ER_UI_OK,
                  "node: pagination renders");
    expect_size(scene.hit_count, hits_before_groups + 10u, "node: pagination emits navigation hits");
    expect_status(er_ui_node_render(&collapsible, &scene, face, er_ui_bounds(0.0f, 3044.0f, 320.0f, 148.0f), theme), ER_UI_OK,
                  "node: collapsible renders");
    expect_size(scene.hit_count, hits_before_groups + 13u, "node: collapsible emits trigger and row hits");
    expect_status(er_ui_node_render(&accordion, &scene, face, er_ui_bounds(0.0f, 3204.0f, 340.0f, 156.0f), theme), ER_UI_OK,
                  "node: accordion renders");
    expect_size(scene.hit_count, hits_before_groups + 15u, "node: accordion emits item trigger hits");
    size_t text_before_hover = scene.text_quad_count;
    expect_status(er_ui_node_render(&hover_card, &scene, face, er_ui_bounds(0.0f, 3372.0f, 320.0f, 88.0f), theme), ER_UI_OK,
                  "node: hover card renders");
    expect_true(scene.text_quad_count > text_before_hover, "node: hover card emits variable font text");
    size_t hits_before_popover = scene.hit_count;
    expect_status(er_ui_node_render(&popover, &scene, face, er_ui_bounds(0.0f, 3472.0f, 320.0f, 170.0f), theme), ER_UI_OK,
                  "node: popover renders");
    expect_size(scene.hit_count, hits_before_popover + 2u, "node: popover emits trigger and field hits");
    size_t hits_before_sheet = scene.hit_count;
    expect_status(er_ui_node_render(&sheet, &scene, face, er_ui_bounds(0.0f, 3654.0f, 320.0f, 196.0f), theme), ER_UI_OK,
                  "node: sheet renders");
    expect_size(scene.hit_count, hits_before_sheet + 2u, "node: sheet emits field and button hits");
    size_t rects_before_kbd = scene.rect_count;
    expect_status(er_ui_node_render(&kbd, &scene, face, er_ui_bounds(0.0f, 3862.0f, 320.0f, 40.0f), theme), ER_UI_OK,
                  "node: kbd renders");
    expect_true(scene.rect_count > rects_before_kbd, "node: kbd emits key badge rects");
    size_t hits_before_menubar = scene.hit_count;
    expect_status(er_ui_node_render(&menubar, &scene, face, er_ui_bounds(0.0f, 3914.0f, 300.0f, 46.0f), theme), ER_UI_OK,
                  "node: menubar renders");
    expect_size(scene.hit_count, hits_before_menubar + 3u, "node: menubar emits item hits");
    size_t hits_before_radio_group = scene.hit_count;
    expect_status(er_ui_node_render(&radio_group, &scene, face, er_ui_bounds(0.0f, 3972.0f, 260.0f, 106.0f), theme), ER_UI_OK,
                  "node: radio group renders");
    expect_size(scene.hit_count, hits_before_radio_group + 3u, "node: radio group emits radio hits");
    size_t hits_before_input_group = scene.hit_count;
    expect_status(er_ui_node_render(&input_group, &scene, face, er_ui_bounds(0.0f, 4090.0f, 340.0f, 58.0f), theme), ER_UI_OK,
                  "node: input group renders");
    expect_size(scene.hit_count, hits_before_input_group + 2u, "node: input group emits field and button hits");
    size_t hits_before_input_otp = scene.hit_count;
    expect_status(er_ui_node_render(&input_otp, &scene, face, er_ui_bounds(0.0f, 4160.0f, 300.0f, 52.0f), theme), ER_UI_OK,
                  "node: input otp renders");
    expect_size(scene.hit_count, hits_before_input_otp + 5u, "node: input otp emits editable cell hits");
    size_t hits_before_navigation_menu = scene.hit_count;
    expect_status(er_ui_node_render(&navigation_menu, &scene, face, er_ui_bounds(0.0f, 4224.0f, 360.0f, 154.0f), theme), ER_UI_OK,
                  "node: navigation menu renders");
    expect_size(scene.hit_count, hits_before_navigation_menu + 4u, "node: navigation menu emits tab and row hits");
    size_t rects_before_resizable = scene.rect_count;
    expect_status(er_ui_node_render(&resizable, &scene, face, er_ui_bounds(0.0f, 4390.0f, 360.0f, 112.0f), theme), ER_UI_OK,
                  "node: resizable renders");
    expect_true(scene.rect_count > rects_before_resizable, "node: resizable emits cards and divider");
    size_t hits_before_sidebar = scene.hit_count;
    expect_status(er_ui_node_render(&sidebar, &scene, face, er_ui_bounds(0.0f, 4514.0f, 420.0f, 176.0f), theme), ER_UI_OK,
                  "node: sidebar renders");
    expect_size(scene.hit_count, hits_before_sidebar + 3u, "node: sidebar emits menu item hits");
    size_t icon_quads_before_sonner = scene.icon_quad_count;
    expect_status(er_ui_node_render(&sonner, &scene, face, er_ui_bounds(0.0f, 4702.0f, 300.0f, 112.0f), theme), ER_UI_OK,
                  "node: sonner renders");
    expect_size(scene.icon_quad_count, icon_quads_before_sonner + 2u, "node: sonner emits toast icon quads");
    size_t icon_quads_before_aspect = scene.icon_quad_count;
    expect_status(er_ui_node_render(&aspect, &scene, face, er_ui_bounds(0.0f, 4826.0f, 320.0f, 180.0f), theme), ER_UI_OK,
                  "node: aspect ratio renders");
    expect_size(scene.icon_quad_count, icon_quads_before_aspect + 1u, "node: aspect ratio emits icon quad");
    size_t icon_quads_before_alert_dialog = scene.icon_quad_count;
    expect_status(er_ui_node_render(&alert_dialog, &scene, face, er_ui_bounds(0.0f, 5018.0f, 360.0f, 150.0f), theme), ER_UI_OK,
                  "node: alert dialog renders");
    expect_size(scene.icon_quad_count, icon_quads_before_alert_dialog + 1u, "node: alert dialog emits icon quad");
    size_t rects_before_direction = scene.rect_count;
    size_t text_before_direction = scene.text_quad_count;
    expect_status(er_ui_node_render(&direction, &scene, face, er_ui_bounds(0.0f, 5180.0f, 260.0f, 64.0f), theme), ER_UI_OK,
                  "node: direction renders");
    expect_true(scene.rect_count > rects_before_direction, "node: direction emits badge rects");
    expect_true(scene.text_quad_count > text_before_direction, "node: direction emits variable font text");
    size_t hits_before_drawer = scene.hit_count;
    expect_status(er_ui_node_render(&drawer, &scene, face, er_ui_bounds(0.0f, 5256.0f, 320.0f, 184.0f), theme), ER_UI_OK,
                  "node: drawer renders");
    expect_size(scene.hit_count, hits_before_drawer + 2u, "node: drawer emits slider and button hits");
    size_t hits_before_dropdown = scene.hit_count;
    expect_status(er_ui_node_render(&dropdown_menu, &scene, face, er_ui_bounds(0.0f, 5452.0f, 260.0f, 144.0f), theme), ER_UI_OK,
                  "node: dropdown menu renders");
    expect_size(scene.hit_count, hits_before_dropdown + 3u, "node: dropdown menu emits item hits");
    size_t hits_before_context = scene.hit_count;
    expect_status(er_ui_node_render(&context_menu, &scene, face, er_ui_bounds(0.0f, 5608.0f, 280.0f, 220.0f), theme), ER_UI_OK,
                  "node: context menu renders");
    expect_size(scene.hit_count, hits_before_context + 3u, "node: context menu emits item hits");
    size_t hits_before_date_picker = scene.hit_count;
    expect_status(er_ui_node_render(&date_picker, &scene, face, er_ui_bounds(0.0f, 5840.0f, 300.0f, 128.0f), theme), ER_UI_OK,
                  "node: date picker renders");
    expect_size(scene.hit_count, hits_before_date_picker + 5u, "node: date picker emits trigger and day hits");
    size_t hits_before_carousel = scene.hit_count;
    size_t icons_before_carousel = scene.icon_quad_count;
    expect_status(er_ui_node_render(&carousel, &scene, face, er_ui_bounds(0.0f, 5980.0f, 420.0f, 96.0f), theme), ER_UI_OK,
                  "node: carousel renders");
    expect_size(scene.hit_count, hits_before_carousel + 2u, "node: carousel emits previous and next hits");
    expect_size(scene.icon_quad_count, icons_before_carousel + 2u, "node: carousel emits chevron icons");
    size_t hits_before_calendar = scene.hit_count;
    size_t icons_before_calendar = scene.icon_quad_count;
    expect_status(er_ui_node_render(&calendar, &scene, face, er_ui_bounds(0.0f, 6088.0f, 320.0f, 150.0f), theme), ER_UI_OK,
                  "node: calendar renders");
    expect_size(scene.hit_count, hits_before_calendar + 6u, "node: calendar emits navigation and day hits");
    expect_size(scene.icon_quad_count, icons_before_calendar + 2u, "node: calendar emits navigation icons");
    size_t hits_before_combobox = scene.hit_count;
    expect_status(er_ui_node_render(&combobox, &scene, face, er_ui_bounds(0.0f, 6250.0f, 300.0f, 250.0f), theme), ER_UI_OK,
                  "node: combobox renders");
    expect_size(scene.hit_count, hits_before_combobox + 5u, "node: combobox emits select, command, and option hits");
    size_t text_before_diff = scene.text_quad_count;
    expect_status(er_ui_node_render(&diff_body, &scene, face, er_ui_bounds(0.0f, 6512.0f, 360.0f, 128.0f), theme), ER_UI_OK,
                  "node: diff body renders");
    expect_true(scene.text_quad_count > text_before_diff, "node: diff body emits variable font text");
    size_t icons_before_chat = scene.icon_quad_count;
    size_t text_before_chat = scene.text_quad_count;
    expect_status(er_ui_node_render(&chat_message, &scene, face, er_ui_bounds(0.0f, 6652.0f, 360.0f, 110.0f), theme), ER_UI_OK,
                  "node: chat message renders");
    expect_status(er_ui_node_render(&chat_timeline, &scene, face, er_ui_bounds(0.0f, 6774.0f, 360.0f, 82.0f), theme), ER_UI_OK,
                  "node: chat timeline message renders");
    expect_status(er_ui_node_render(&chat_diff, &scene, face, er_ui_bounds(0.0f, 6868.0f, 380.0f, 154.0f), theme), ER_UI_OK,
                  "node: chat diff message renders");
    expect_true(scene.icon_quad_count >= icons_before_chat + 3u, "node: chat messages emit role icons");
    expect_true(scene.text_quad_count > text_before_chat, "node: chat messages emit variable font text");
    size_t hits_before_conversation = scene.hit_count;
    expect_status(er_ui_node_render(&conversation, &scene, face, er_ui_bounds(0.0f, 7034.0f, 380.0f, 220.0f), theme), ER_UI_OK,
                  "node: conversation renders");
    expect_size(scene.hit_count, hits_before_conversation + 1u, "node: conversation emits scroll hit");
    size_t drag_sources_before = scene.drag_source_count;
    size_t drop_targets_before = scene.drop_target_count;
    expect_status(er_ui_node_render(&reorderable, &scene, face, er_ui_bounds(0.0f, 2930.0f, 260.0f, 52.0f), theme), ER_UI_OK,
                  "node: reorderable row renders");
    expect_size(scene.drag_source_count, drag_sources_before + 1u, "node: reorderable emits drag source");
    expect_size(scene.drop_target_count, drop_targets_before + 1u, "node: reorderable emits drop target");
    expect_size(scene.drag_sources[drag_sources_before].scope_id, 42u, "node: drag source scope is preserved");
    expect_size(scene.drag_sources[drag_sources_before].item_id, 8816u, "node: drag source item is preserved");
    expect_size(scene.drop_targets[drop_targets_before].index, 3u, "node: drop target index is preserved");

    expect_true(scene.rect_count > 0u, "node: render emits rect geometry");
    expect_true(scene.hit_count > 0u, "node: render emits hit targets");
    expect_true(scene.text_quad_count > 0u, "node: render uses variable font text");
    expect_status(er_ui_node_render(&root, &scene, NULL, er_ui_bounds(0.0f, 0.0f, 320.0f, 160.0f), theme), ER_UI_ERR_INVALID_ARGUMENT,
                  "node: missing variable font is rejected");
    vr_font_face_destroy(face);
  }
  er_ui_scene_destroy(&scene);
}
