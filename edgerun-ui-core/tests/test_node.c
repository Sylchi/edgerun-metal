#include "test_common.h"

#define ER_UI_TEST_NODE_ARRAY_COUNT(values) (sizeof(values) / sizeof((values)[0]))
#define ER_UI_TEST_NODE_DEPLOY_BUTTON_ID 8001u
#define ER_UI_TEST_NODE_ICON_BUTTON_ID 8007u
#define ER_UI_TEST_NODE_BUTTON_GROUP_ID 8008u
#define ER_UI_TEST_NODE_BUTTON_GROUP_CHILD_INDEX 2u
#define ER_UI_TEST_NODE_BUTTON_GROUP_CHILD_ID 8010u
#define ER_UI_TEST_NODE_TOGGLE_GROUP_ID 8011u
#define ER_UI_TEST_NODE_TOGGLE_SELECTED_INDEX 1u
#define ER_UI_TEST_NODE_PAGINATION_ID 8018u
#define ER_UI_TEST_NODE_PAGINATION_SELECTED_INDEX 1u
#define ER_UI_TEST_NODE_PAGINATION_NEXT_INDEX 3u
#define ER_UI_TEST_NODE_PAGINATION_NEXT_ID 8021u
#define ER_UI_TEST_NODE_COLLAPSIBLE_ID 8022u
#define ER_UI_TEST_NODE_COLLAPSIBLE_TRIGGER_INDEX 0u
#define ER_UI_TEST_NODE_COLLAPSIBLE_ROW_INDEX 2u
#define ER_UI_TEST_NODE_COLLAPSIBLE_ROW_ID 8024u
#define ER_UI_TEST_NODE_ACCORDION_ID 8025u
#define ER_UI_TEST_NODE_ACCORDION_ITEM_INDEX 1u
#define ER_UI_TEST_NODE_ACCORDION_ITEM_ID 8026u
#define ER_UI_TEST_NODE_POPOVER_ID 8027u
#define ER_UI_TEST_NODE_POPOVER_FIELD_ID 8028u
#define ER_UI_TEST_NODE_POPOVER_TRIGGER_INDEX 0u
#define ER_UI_TEST_NODE_POPOVER_FIELD_INDEX 1u
#define ER_UI_TEST_NODE_SHEET_ID 8029u
#define ER_UI_TEST_NODE_SHEET_FIELD_INDEX 0u
#define ER_UI_TEST_NODE_SHEET_BUTTON_INDEX 1u
#define ER_UI_TEST_NODE_SHEET_BUTTON_ID 8030u
#define ER_UI_TEST_NODE_MENUBAR_ID 8031u
#define ER_UI_TEST_NODE_MENUBAR_SELECTED_INDEX 1u
#define ER_UI_TEST_NODE_MENUBAR_SELECTED_ID 8032u
#define ER_UI_TEST_NODE_RADIO_GROUP_ID 8034u
#define ER_UI_TEST_NODE_RADIO_SELECTED_INDEX 2u
#define ER_UI_TEST_NODE_RADIO_SELECTED_ID 8036u
#define ER_UI_TEST_NODE_INPUT_GROUP_ID 8038u
#define ER_UI_TEST_NODE_INPUT_GROUP_FIELD_INDEX 0u
#define ER_UI_TEST_NODE_INPUT_GROUP_BUTTON_INDEX 1u
#define ER_UI_TEST_NODE_INPUT_GROUP_BUTTON_ID 8039u
#define ER_UI_TEST_NODE_INPUT_OTP_ID 8040u
#define ER_UI_TEST_NODE_INPUT_OTP_FOCUSED_INDEX 4u
#define ER_UI_TEST_NODE_INPUT_OTP_FOCUSED_ID 8044u
#define ER_UI_TEST_NODE_INPUT_OTP_SEPARATOR_INDEX 3u
#define ER_UI_TEST_NODE_NAVIGATION_ID 8048u
#define ER_UI_TEST_NODE_NAVIGATION_SELECTED_INDEX 1u
#define ER_UI_TEST_NODE_NAVIGATION_SELECTED_ID 8049u
#define ER_UI_TEST_NODE_NAVIGATION_ROW_INDEX 3u
#define ER_UI_TEST_NODE_NAVIGATION_ROW_ID 8051u
#define ER_UI_TEST_NODE_SIDEBAR_ID 8052u
#define ER_UI_TEST_NODE_SIDEBAR_SELECTED_INDEX 0u
#define ER_UI_TEST_NODE_SIDEBAR_MAIN_INDEX 3u
#define ER_UI_TEST_NODE_SONNER_COUNT 2u
#define ER_UI_TEST_NODE_SONNER_TOAST_INDEX 1u
#define ER_UI_TEST_NODE_DIRECTION_RTL_INDEX 1u
#define ER_UI_TEST_NODE_DRAWER_ID 8059u
#define ER_UI_TEST_NODE_DRAWER_SLIDER_INDEX 0u
#define ER_UI_TEST_NODE_DRAWER_BUTTON_INDEX 1u
#define ER_UI_TEST_NODE_DRAWER_BUTTON_ID 8060u
#define ER_UI_TEST_NODE_DROPDOWN_ID 8061u
#define ER_UI_TEST_NODE_DROPDOWN_SELECTED_INDEX 1u
#define ER_UI_TEST_NODE_DROPDOWN_SELECTED_ID 8062u
#define ER_UI_TEST_NODE_CONTEXT_MENU_ID 8064u
#define ER_UI_TEST_NODE_CONTEXT_SELECTED_INDEX 2u
#define ER_UI_TEST_NODE_CONTEXT_SELECTED_ID 8066u
#define ER_UI_TEST_NODE_DATE_PICKER_ID 8068u
#define ER_UI_TEST_NODE_DATE_TRIGGER_INDEX 0u
#define ER_UI_TEST_NODE_DATE_SELECTED_INDEX 2u
#define ER_UI_TEST_NODE_DATE_SELECTED_CHILD_INDEX 3u
#define ER_UI_TEST_NODE_DATE_SELECTED_ID 8071u
#define ER_UI_TEST_NODE_CAROUSEL_ID 8074u
#define ER_UI_TEST_NODE_CAROUSEL_PREVIOUS_INDEX 0u
#define ER_UI_TEST_NODE_CAROUSEL_NEXT_INDEX 4u
#define ER_UI_TEST_NODE_CAROUSEL_NEXT_ID 8075u
#define ER_UI_TEST_NODE_CALENDAR_ID 8076u
#define ER_UI_TEST_NODE_CALENDAR_PREVIOUS_INDEX 0u
#define ER_UI_TEST_NODE_CALENDAR_SELECTED_CHILD_INDEX 4u
#define ER_UI_TEST_NODE_CALENDAR_SELECTED_ID 8080u
#define ER_UI_TEST_NODE_COMBOBOX_ID 8082u
#define ER_UI_TEST_NODE_COMBOBOX_SELECTED_INDEX 1u
#define ER_UI_TEST_NODE_COMBOBOX_SELECTED_CHILD_INDEX 3u
#define ER_UI_TEST_NODE_COMBOBOX_SELECTED_ID 8085u
#define ER_UI_TEST_NODE_DIFF_LINE_INDEX 2u
#define ER_UI_TEST_NODE_DIFF_TRUNCATED_INDEX 4u
#define ER_UI_TEST_NODE_CHAT_DIFF_LINE_INDEX 3u
#define ER_UI_TEST_NODE_CONVERSATION_ID 8090u
#define ER_UI_TEST_NODE_CONVERSATION_ASSISTANT_INDEX 1u
#define ER_UI_TEST_NODE_CONVERSATION_FIRST_INDEX 0u
#define ER_UI_TEST_NODE_CHECKBOX_ID 8002u
#define ER_UI_TEST_NODE_FIELD_ID 8003u
#define ER_UI_TEST_NODE_TREE_ID 8004u
#define ER_UI_TEST_NODE_TREE_DEPTH 1u
#define ER_UI_TEST_NODE_TABS_ID 8005u
#define ER_UI_TEST_NODE_TABS_SELECTED_INDEX 1u
#define ER_UI_TEST_NODE_TABS_SELECTED_ID 8006u
#define ER_UI_TEST_NODE_TABLE_ID 8010u
#define ER_UI_TEST_NODE_TABLE_HEADER_INDEX 0u
#define ER_UI_TEST_NODE_TABLE_ROW_INDEX 1u
#define ER_UI_TEST_NODE_RENDER_BREADCRUMB_ID 8100u
#define ER_UI_TEST_NODE_RENDER_BREADCRUMB_CURRENT_INDEX 2u
#define ER_UI_TEST_NODE_RENDER_TABLE_ID 8200u
#define ER_UI_TEST_NODE_RENDER_LIST_ROW_ID 8300u
#define ER_UI_TEST_NODE_RENDER_FIELD_ID 8400u
#define ER_UI_TEST_NODE_RENDER_TEXT_AREA_ID 8401u
#define ER_UI_TEST_NODE_RENDER_TABS_ID 8500u
#define ER_UI_TEST_NODE_RENDER_TABS_SELECTED_INDEX 1u
#define ER_UI_TEST_NODE_RENDER_CHART_ID 8600u
#define ER_UI_TEST_NODE_RENDER_CHART_ACTIVE_INDEX 1u
#define ER_UI_TEST_NODE_RENDER_COMMAND_ID 8700u
#define ER_UI_TEST_NODE_RENDER_TREE_ID 8800u
#define ER_UI_TEST_NODE_RENDER_IDENTITY_ID 8801u
#define ER_UI_TEST_NODE_RENDER_CONTACT_ID 8802u
#define ER_UI_TEST_NODE_RENDER_THREAD_ID 8803u
#define ER_UI_TEST_NODE_RENDER_ATTACHMENT_ID 8804u
#define ER_UI_TEST_NODE_RENDER_GRANT_ID 8805u
#define ER_UI_TEST_NODE_RENDER_PROOF_ID 8806u
#define ER_UI_TEST_NODE_RENDER_ROUTE_PACKAGE_ID 8807u
#define ER_UI_TEST_NODE_RENDER_RECEIPT_ID 8808u
#define ER_UI_TEST_NODE_RENDER_PANEL_ID 8809u
#define ER_UI_TEST_NODE_RENDER_TRANSACTION_ID 8810u
#define ER_UI_TEST_NODE_RENDER_MENU_ID 8811u
#define ER_UI_TEST_NODE_RENDER_CONTROL_ID 8812u
#define ER_UI_TEST_NODE_RENDER_GRID_COLUMNS 2u
#define ER_UI_TEST_NODE_RENDER_GRID_THIRD_CHILD 2u
#define ER_UI_TEST_NODE_RENDER_SCROLL_ID 8813u
#define ER_UI_TEST_NODE_RENDER_SCROLL_FIRST_ROW_ID 8814u
#define ER_UI_TEST_NODE_RENDER_SCROLL_SECOND_ROW_ID 8815u
#define ER_UI_TEST_NODE_RENDER_SCROLL_FIRST_CHILD 0u
#define ER_UI_TEST_NODE_RENDER_REORDERABLE_ID 8816u
#define ER_UI_TEST_NODE_RENDER_REORDER_GROUP_ID 42u
#define ER_UI_TEST_NODE_RENDER_REORDER_INDEX 3u
#define ER_UI_TEST_NODE_RENDER_TRANSITION_ID 8910u
#define ER_UI_TEST_NODE_RENDER_TRANSITION_MS 160u
#define ER_UI_TEST_NODE_RENDER_ICON_BUTTON_ID 8817u
#define ER_UI_TEST_NODE_RENDER_BUTTON_GROUP_ID 8818u
#define ER_UI_TEST_NODE_RENDER_TOGGLE_GROUP_ID 8821u
#define ER_UI_TEST_NODE_RENDER_PAGINATION_ID 8824u
#define ER_UI_TEST_NODE_RENDER_PAGINATION_SELECTED_INDEX 0u
#define ER_UI_TEST_NODE_RENDER_COLLAPSIBLE_ID 8828u
#define ER_UI_TEST_NODE_RENDER_ACCORDION_ID 8831u
#define ER_UI_TEST_NODE_RENDER_POPOVER_ID 8833u
#define ER_UI_TEST_NODE_RENDER_SHEET_ID 8835u
#define ER_UI_TEST_NODE_RENDER_MENUBAR_ID 8837u
#define ER_UI_TEST_NODE_RENDER_RADIO_GROUP_ID 8840u
#define ER_UI_TEST_NODE_RENDER_RADIO_SELECTED_INDEX 0u
#define ER_UI_TEST_NODE_RENDER_INPUT_GROUP_ID 8843u
#define ER_UI_TEST_NODE_RENDER_INPUT_OTP_ID 8845u
#define ER_UI_TEST_NODE_RENDER_INPUT_OTP_FOCUSED_INDEX 5u
#define ER_UI_TEST_NODE_RENDER_NAVIGATION_ID 8852u
#define ER_UI_TEST_NODE_RENDER_NAVIGATION_SELECTED_INDEX 1u
#define ER_UI_TEST_NODE_RENDER_SIDEBAR_ID 8856u
#define ER_UI_TEST_NODE_RENDER_SIDEBAR_SELECTED_INDEX 0u
#define ER_UI_TEST_NODE_RENDER_DRAWER_ID 8860u
#define ER_UI_TEST_NODE_RENDER_DROPDOWN_ID 8862u
#define ER_UI_TEST_NODE_RENDER_DROPDOWN_SELECTED_INDEX 1u
#define ER_UI_TEST_NODE_RENDER_CONTEXT_MENU_ID 8865u
#define ER_UI_TEST_NODE_RENDER_CONTEXT_SELECTED_INDEX 2u
#define ER_UI_TEST_NODE_RENDER_DATE_PICKER_ID 8868u
#define ER_UI_TEST_NODE_RENDER_DATE_SELECTED_INDEX 2u
#define ER_UI_TEST_NODE_RENDER_CAROUSEL_ID 8874u
#define ER_UI_TEST_NODE_RENDER_CALENDAR_ID 8876u
#define ER_UI_TEST_NODE_RENDER_COMBOBOX_ID 8882u
#define ER_UI_TEST_NODE_RENDER_COMBOBOX_SELECTED_INDEX 1u
#define ER_UI_TEST_NODE_RENDER_CONVERSATION_ID 8890u
#define ER_UI_TEST_NODE_RENDER_BUTTON_GROUP_HITS 3u
#define ER_UI_TEST_NODE_RENDER_TOGGLE_TOTAL_HITS 6u
#define ER_UI_TEST_NODE_RENDER_PAGINATION_TOTAL_HITS 10u
#define ER_UI_TEST_NODE_RENDER_COLLAPSIBLE_TOTAL_HITS 13u
#define ER_UI_TEST_NODE_RENDER_ACCORDION_TOTAL_HITS 15u
#define ER_UI_TEST_NODE_RENDER_TWO_HITS 2u
#define ER_UI_TEST_NODE_RENDER_MENUBAR_HITS 3u
#define ER_UI_TEST_NODE_RENDER_RADIO_HITS 3u
#define ER_UI_TEST_NODE_RENDER_INPUT_OTP_HITS 5u
#define ER_UI_TEST_NODE_RENDER_NAVIGATION_HITS 4u
#define ER_UI_TEST_NODE_RENDER_SIDEBAR_HITS 3u
#define ER_UI_TEST_NODE_RENDER_SONNER_ICON_QUADS 4u
#define ER_UI_TEST_NODE_RENDER_DROPDOWN_HITS 3u
#define ER_UI_TEST_NODE_RENDER_CONTEXT_HITS 3u
#define ER_UI_TEST_NODE_RENDER_DATE_PICKER_HITS 5u
#define ER_UI_TEST_NODE_RENDER_CALENDAR_HITS 6u
#define ER_UI_TEST_NODE_RENDER_COMBOBOX_HITS 5u
#define ER_UI_TEST_NODE_RENDER_CHAT_ICON_QUADS 3u
#define ER_UI_TEST_NODE_RENDER_ONE_HIT 1u
#define ER_UI_TEST_NODE_RENDER_GRADIENT_RECT_OFFSET 1u
#define ER_UI_TEST_NODE_MASONRY_COLUMNS 2u
#define ER_UI_TEST_NODE_MASONRY_CHILDREN 4u
#define ER_UI_TEST_NODE_MASONRY_THIRD_CHILD 2u
#define ER_UI_TEST_NODE_BENTO_COLUMNS 4u
#define ER_UI_TEST_NODE_BENTO_WIDE_COL_SPAN 2u
#define ER_UI_TEST_NODE_BENTO_WIDE_ROW_SPAN 2u
#define ER_UI_TEST_NODE_BENTO_ROW_SPAN 1u
#define ER_UI_TEST_NODE_BENTO_THIRD_CHILD 2u

void run_node_tests(void) {
  er_ui_node_t root = er_ui_node_card();
  er_ui_node_set_padding(&root, 10.0f);
  er_ui_node_set_gap(&root, 8.0f);
  er_ui_node_t title = er_ui_node_text("Create project");
  er_ui_node_t row = er_ui_node_row();
  er_ui_node_set_gap(&row, 6.0f);
  er_ui_node_t badge = er_ui_node_badge("Native", ER_UI_SHADCN_BADGE_SECONDARY);
  er_ui_node_t button = er_ui_node_button("Deploy", ER_UI_TEST_NODE_DEPLOY_BUTTON_ID, ER_UI_SHADCN_BUTTON_DEFAULT);
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
  expect_size(er_ui_icon_from_atlas_id(er_ui_icon_atlas_id(ER_UI_ICON_SEARCH)), ER_UI_ICON_SEARCH, "node: icon atlas id round trips");
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

  er_ui_node_t spaced_row = er_ui_node_row();
  er_ui_node_set_spacing(&spaced_row, 6.0f, 4.0f, 3.0f);
  er_ui_node_t spaced_a = er_ui_node_skeleton();
  er_ui_node_t spaced_b = er_ui_node_skeleton();
  expect_status(er_ui_node_add_child(&spaced_row, &spaced_a), ER_UI_OK, "node: spaced row accepts first child");
  expect_status(er_ui_node_add_child(&spaced_row, &spaced_b), ER_UI_OK, "node: spaced row accepts second child");
  expect_status(er_ui_node_child_bounds(&spaced_row, 0u, er_ui_bounds(0.0f, 0.0f, 220.0f, 80.0f), &resolved_child), ER_UI_OK,
                "node: spacing helper applies margin and padding");
  expect_float(resolved_child.x, 9.0f, "node: spacing child x includes margin and padding");
  expect_float(resolved_child.y, 9.0f, "node: spacing child y includes margin and padding");
  expect_float(resolved_child.w, 99.0f, "node: spacing child width subtracts margin padding and gap");
  expect_float(resolved_child.h, 62.0f, "node: spacing child height subtracts margin and padding");

  er_ui_node_t masonry = er_ui_node_masonry(ER_UI_TEST_NODE_MASONRY_COLUMNS);
  er_ui_node_set_gap(&masonry, 10.0f);
  er_ui_node_t masonry_children[ER_UI_TEST_NODE_MASONRY_CHILDREN];
  for (size_t i = 0u; i < ER_UI_TEST_NODE_ARRAY_COUNT(masonry_children); ++i) {
    masonry_children[i] = er_ui_node_skeleton();
    expect_status(er_ui_node_add_child(&masonry, &masonry_children[i]), ER_UI_OK, "node: masonry accepts child");
  }
  expect_status(er_ui_node_child_bounds(&masonry, ER_UI_TEST_NODE_MASONRY_THIRD_CHILD, er_ui_bounds(0.0f, 0.0f, 200.0f, 300.0f), &resolved_child), ER_UI_OK,
                "node: masonry child bounds use shortest column");
  expect_float(resolved_child.x, 0.0f, "node: masonry third child x is first column");
  expect_float(resolved_child.y, 84.1f, "node: masonry third child stacks below first column");
  expect_float(resolved_child.w, 95.0f, "node: masonry child width divides columns");
  expect_float(resolved_child.h, 108.3f, "node: masonry child height varies deterministically");

  er_ui_node_t bento = er_ui_node_bento_grid(ER_UI_TEST_NODE_BENTO_COLUMNS);
  er_ui_node_set_gap(&bento, 8.0f);
  er_ui_node_t bento_a = er_ui_node_skeleton();
  er_ui_node_t bento_b = er_ui_node_skeleton();
  er_ui_node_t bento_c = er_ui_node_skeleton();
  er_ui_node_set_grid_span(&bento_a, ER_UI_TEST_NODE_BENTO_WIDE_COL_SPAN, ER_UI_TEST_NODE_BENTO_WIDE_ROW_SPAN);
  er_ui_node_set_grid_span(&bento_c, ER_UI_TEST_NODE_BENTO_WIDE_COL_SPAN, ER_UI_TEST_NODE_BENTO_ROW_SPAN);
  expect_status(er_ui_node_add_child(&bento, &bento_a), ER_UI_OK, "node: bento accepts wide child");
  expect_status(er_ui_node_add_child(&bento, &bento_b), ER_UI_OK, "node: bento accepts compact child");
  expect_status(er_ui_node_add_child(&bento, &bento_c), ER_UI_OK, "node: bento accepts second wide child");
  expect_status(er_ui_node_child_bounds(&bento, 0u, er_ui_bounds(0.0f, 0.0f, 400.0f, 300.0f), &resolved_child), ER_UI_OK,
                "node: bento first child bounds resolve");
  expect_float(resolved_child.w, 196.0f, "node: bento child spans columns");
  expect_float(resolved_child.h, 149.0f, "node: bento child spans rows");
  expect_status(er_ui_node_child_bounds(&bento, ER_UI_TEST_NODE_BENTO_THIRD_CHILD, er_ui_bounds(0.0f, 0.0f, 400.0f, 300.0f), &resolved_child), ER_UI_OK,
                "node: bento packs around occupied cells");
  expect_float(resolved_child.x, 204.0f, "node: bento third child x skips occupied cells");
  expect_float(resolved_child.y, 78.5f, "node: bento third child y fills open row");
  expect_float(resolved_child.w, 196.0f, "node: bento third child spans columns");

  er_ui_a11y_node_t a11y = {0};
  expect_status(er_ui_node_accessibility(&button, &a11y), ER_UI_OK, "node: button accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_BUTTON, "node: button accessibility role");
  expect_true(a11y.has_id && a11y.id == ER_UI_TEST_NODE_DEPLOY_BUTTON_ID, "node: button accessibility id");
  expect_true(a11y.label == button.label, "node: button accessibility label is borrowed");

  er_ui_node_t icon_a11y = er_ui_node_icon(ER_UI_ICON_TRUST, NULL, er_ui_color_rgba(0.0f, 0.0f, 0.0f, 1.0f));
  expect_status(er_ui_node_accessibility(&icon_a11y, &a11y), ER_UI_OK, "node: icon accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_IMAGE, "node: icon accessibility role");
  expect_string(a11y.label, "trust", "node: icon accessibility uses canonical label fallback");

  er_ui_node_t icon_button_a11y = er_ui_node_icon_button(ER_UI_ICON_SEARCH, "Search", ER_UI_TEST_NODE_ICON_BUTTON_ID, ER_UI_SHADCN_BUTTON_GHOST);
  expect_status(er_ui_node_accessibility(&icon_button_a11y, &a11y), ER_UI_OK, "node: icon button accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_BUTTON, "node: icon button accessibility role");
  expect_true(a11y.has_id && a11y.id == ER_UI_TEST_NODE_ICON_BUTTON_ID, "node: icon button accessibility id");

  er_ui_node_t toast_icon_a11y = er_ui_node_toast_icon("Saved", ER_UI_ICON_CHECK, er_ui_color_rgba(0.0f, 0.5f, 0.2f, 1.0f));
  expect_status(er_ui_node_accessibility(&toast_icon_a11y, &a11y), ER_UI_OK, "node: icon toast accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_STATUS, "node: icon toast accessibility role");
  expect_true(a11y.label == toast_icon_a11y.label, "node: icon toast label is borrowed");

  er_ui_node_t card_summary_a11y = er_ui_node_card_summary("Title", "Detail");
  expect_status(er_ui_node_accessibility(&card_summary_a11y, &a11y), ER_UI_OK, "node: card summary accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_GROUP, "node: card summary accessibility role");
  expect_true(a11y.label == card_summary_a11y.label, "node: card summary title is borrowed");
  expect_true(a11y.value == card_summary_a11y.detail, "node: card summary detail is borrowed");

  const char *const button_group_labels[] = {"Copy", "Paste", "More"};
  er_ui_node_t button_group_a11y =
      er_ui_node_button_group(button_group_labels, ER_UI_TEST_NODE_ARRAY_COUNT(button_group_labels), ER_UI_TEST_NODE_BUTTON_GROUP_ID);
  expect_status(er_ui_node_accessibility(&button_group_a11y, &a11y), ER_UI_OK, "node: button group accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_GROUP, "node: button group accessibility role");
  expect_status(er_ui_node_accessibility_child(&button_group_a11y, ER_UI_TEST_NODE_BUTTON_GROUP_CHILD_INDEX, &a11y), ER_UI_OK,
                "node: button group child accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_BUTTON, "node: button group child accessibility role");
  expect_true(a11y.has_id && a11y.id == ER_UI_TEST_NODE_BUTTON_GROUP_CHILD_ID, "node: button group child id");

  const char *const toggle_group_labels[] = {"B", "I", "U"};
  er_ui_node_t toggle_group_a11y = er_ui_node_toggle_group(toggle_group_labels, ER_UI_TEST_NODE_ARRAY_COUNT(toggle_group_labels),
                                                           ER_UI_TEST_NODE_TOGGLE_SELECTED_INDEX, ER_UI_TEST_NODE_TOGGLE_GROUP_ID);
  expect_status(er_ui_node_accessibility(&toggle_group_a11y, &a11y), ER_UI_OK, "node: toggle group accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_GROUP, "node: toggle group accessibility role");
  expect_status(er_ui_node_accessibility_child(&toggle_group_a11y, ER_UI_TEST_NODE_TOGGLE_SELECTED_INDEX, &a11y), ER_UI_OK,
                "node: toggle group child accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_BUTTON, "node: toggle group child accessibility role");
  expect_true((a11y.states & ER_UI_A11Y_STATE_SELECTED) != 0u, "node: toggle group selected child state");

  const char *const pagination_labels[] = {"1", "2"};
  er_ui_node_t pagination_a11y = er_ui_node_pagination(pagination_labels, ER_UI_TEST_NODE_ARRAY_COUNT(pagination_labels), 0u,
                                                       ER_UI_TEST_NODE_PAGINATION_ID);
  expect_status(er_ui_node_accessibility(&pagination_a11y, &a11y), ER_UI_OK, "node: pagination accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_NAVIGATION, "node: pagination accessibility role");
  expect_status(er_ui_node_accessibility_child(&pagination_a11y, ER_UI_TEST_NODE_PAGINATION_SELECTED_INDEX, &a11y), ER_UI_OK,
                "node: selected page accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_BUTTON, "node: selected page accessibility role");
  expect_true((a11y.states & ER_UI_A11Y_STATE_CURRENT) != 0u, "node: selected page current state");
  expect_status(er_ui_node_accessibility_child(&pagination_a11y, ER_UI_TEST_NODE_PAGINATION_NEXT_INDEX, &a11y), ER_UI_OK,
                "node: next page accessibility maps");
  expect_true(a11y.has_id && a11y.id == ER_UI_TEST_NODE_PAGINATION_NEXT_ID, "node: next page accessibility id");

  const char *const collapsible_titles[] = {"Typography", "Spacing"};
  const char *const collapsible_details[] = {"Variable font", "Stable gaps"};
  er_ui_node_t collapsible_a11y = er_ui_node_collapsible("Foundations", collapsible_titles, collapsible_details,
                                                         ER_UI_TEST_NODE_ARRAY_COUNT(collapsible_titles), true, ER_UI_TEST_NODE_COLLAPSIBLE_ID);
  expect_status(er_ui_node_accessibility(&collapsible_a11y, &a11y), ER_UI_OK, "node: collapsible accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_GROUP, "node: collapsible accessibility role");
  expect_true((a11y.states & ER_UI_A11Y_STATE_EXPANDED) != 0u, "node: collapsible expanded state");
  expect_status(er_ui_node_accessibility_child(&collapsible_a11y, ER_UI_TEST_NODE_COLLAPSIBLE_TRIGGER_INDEX, &a11y), ER_UI_OK,
                "node: collapsible trigger accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_BUTTON, "node: collapsible trigger accessibility role");
  expect_true(a11y.has_id && a11y.id == ER_UI_TEST_NODE_COLLAPSIBLE_ID, "node: collapsible trigger id");
  expect_status(er_ui_node_accessibility_child(&collapsible_a11y, ER_UI_TEST_NODE_COLLAPSIBLE_ROW_INDEX, &a11y), ER_UI_OK,
                "node: collapsible row accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_LIST_ITEM, "node: collapsible row accessibility role");
  expect_true(a11y.has_id && a11y.id == ER_UI_TEST_NODE_COLLAPSIBLE_ROW_ID, "node: collapsible row id");

  const char *const accordion_titles[] = {"Product", "Billing"};
  const char *const accordion_bodies[] = {"Network app storage", "Proof-backed receipts"};
  er_ui_node_t accordion_a11y =
      er_ui_node_accordion(accordion_titles, accordion_bodies, ER_UI_TEST_NODE_ARRAY_COUNT(accordion_titles), ER_UI_TEST_NODE_ACCORDION_ID);
  expect_status(er_ui_node_accessibility(&accordion_a11y, &a11y), ER_UI_OK, "node: accordion accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_GROUP, "node: accordion accessibility role");
  expect_status(er_ui_node_accessibility_child(&accordion_a11y, ER_UI_TEST_NODE_ACCORDION_ITEM_INDEX, &a11y), ER_UI_OK,
                "node: accordion item accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_BUTTON, "node: accordion item accessibility role");
  expect_true(a11y.has_id && a11y.id == ER_UI_TEST_NODE_ACCORDION_ITEM_ID, "node: accordion item id");
  expect_true((a11y.states & ER_UI_A11Y_STATE_EXPANDED) != 0u, "node: accordion item expanded state");

  er_ui_node_t hover_a11y = er_ui_node_hover_card("ER", "UI", "Reusable shadcn primitive.", er_ui_color_rgba(0.1f, 0.2f, 0.3f, 1.0f));
  expect_status(er_ui_node_accessibility(&hover_a11y, &a11y), ER_UI_OK, "node: hover card accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_GROUP, "node: hover card accessibility role");
  expect_true(a11y.label == hover_a11y.label, "node: hover card label is borrowed");
  expect_true((a11y.states & ER_UI_A11Y_STATE_HAS_VALUE) != 0u, "node: hover card detail value state");

  er_ui_node_t popover_a11y = er_ui_node_popover("Open popover", "Dimensions", "Set layout constraints.", "Width", "100%", ER_UI_TEST_NODE_POPOVER_ID);
  expect_status(er_ui_node_accessibility(&popover_a11y, &a11y), ER_UI_OK, "node: popover accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_DIALOG, "node: popover accessibility role");
  expect_true(a11y.label == popover_a11y.value, "node: popover title is borrowed");
  expect_status(er_ui_node_accessibility_child(&popover_a11y, ER_UI_TEST_NODE_POPOVER_TRIGGER_INDEX, &a11y), ER_UI_OK,
                "node: popover trigger accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_BUTTON, "node: popover trigger accessibility role");
  expect_true(a11y.has_id && a11y.id == ER_UI_TEST_NODE_POPOVER_ID, "node: popover trigger id");
  expect_status(er_ui_node_accessibility_child(&popover_a11y, ER_UI_TEST_NODE_POPOVER_FIELD_INDEX, &a11y), ER_UI_OK,
                "node: popover field accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_TEXTBOX, "node: popover field accessibility role");
  expect_true(a11y.has_id && a11y.id == ER_UI_TEST_NODE_POPOVER_FIELD_ID, "node: popover field id");

  er_ui_node_t sheet_a11y = er_ui_node_sheet("Profile", "Update local profile.", "Name", "EdgeRun", "Save changes", ER_UI_TEST_NODE_SHEET_ID);
  expect_status(er_ui_node_accessibility(&sheet_a11y, &a11y), ER_UI_OK, "node: sheet accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_DIALOG, "node: sheet accessibility role");
  expect_true(a11y.label == sheet_a11y.label, "node: sheet title is borrowed");
  expect_status(er_ui_node_accessibility_child(&sheet_a11y, ER_UI_TEST_NODE_SHEET_FIELD_INDEX, &a11y), ER_UI_OK,
                "node: sheet field accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_TEXTBOX, "node: sheet field accessibility role");
  expect_true(a11y.has_id && a11y.id == ER_UI_TEST_NODE_SHEET_ID, "node: sheet field id");
  expect_status(er_ui_node_accessibility_child(&sheet_a11y, ER_UI_TEST_NODE_SHEET_BUTTON_INDEX, &a11y), ER_UI_OK,
                "node: sheet button accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_BUTTON, "node: sheet button accessibility role");
  expect_true(a11y.has_id && a11y.id == ER_UI_TEST_NODE_SHEET_BUTTON_ID, "node: sheet button id");

  const char *const kbd_keys[] = {"Cmd", "K"};
  er_ui_node_t kbd_a11y = er_ui_node_kbd(kbd_keys, ER_UI_TEST_NODE_ARRAY_COUNT(kbd_keys), "Open command palette");
  expect_status(er_ui_node_accessibility(&kbd_a11y, &a11y), ER_UI_OK, "node: kbd accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_GROUP, "node: kbd accessibility role");
  expect_true(a11y.label == kbd_a11y.label, "node: kbd label is borrowed");

  const char *const menubar_items[] = {"File", "Edit", "View"};
  er_ui_node_t menubar_a11y =
      er_ui_node_menubar(menubar_items, ER_UI_TEST_NODE_ARRAY_COUNT(menubar_items), ER_UI_TEST_NODE_MENUBAR_SELECTED_INDEX, ER_UI_TEST_NODE_MENUBAR_ID);
  expect_status(er_ui_node_accessibility(&menubar_a11y, &a11y), ER_UI_OK, "node: menubar accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_NAVIGATION, "node: menubar accessibility role");
  expect_status(er_ui_node_accessibility_child(&menubar_a11y, ER_UI_TEST_NODE_MENUBAR_SELECTED_INDEX, &a11y), ER_UI_OK,
                "node: menubar item accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_BUTTON, "node: menubar item accessibility role");
  expect_true(a11y.has_id && a11y.id == ER_UI_TEST_NODE_MENUBAR_SELECTED_ID, "node: menubar item id");
  expect_true((a11y.states & ER_UI_A11Y_STATE_SELECTED) != 0u, "node: menubar selected item state");

  const char *const radio_group_labels[] = {"Default", "Comfortable", "Compact"};
  er_ui_node_t radio_group_a11y = er_ui_node_radio_group(radio_group_labels, ER_UI_TEST_NODE_ARRAY_COUNT(radio_group_labels),
                                                         ER_UI_TEST_NODE_RADIO_SELECTED_INDEX, ER_UI_TEST_NODE_RADIO_GROUP_ID);
  expect_status(er_ui_node_accessibility(&radio_group_a11y, &a11y), ER_UI_OK, "node: radio group accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_GROUP, "node: radio group accessibility role");
  expect_status(er_ui_node_accessibility_child(&radio_group_a11y, ER_UI_TEST_NODE_RADIO_SELECTED_INDEX, &a11y), ER_UI_OK,
                "node: radio group item accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_RADIO, "node: radio group item accessibility role");
  expect_true(a11y.has_id && a11y.id == ER_UI_TEST_NODE_RADIO_SELECTED_ID, "node: radio group item id");
  expect_true((a11y.states & ER_UI_A11Y_STATE_CHECKED) != 0u, "node: radio group selected item state");

  er_ui_node_t input_group_a11y = er_ui_node_input_group("URL", "https://edgerun.local", "Copy", ER_UI_TEST_NODE_INPUT_GROUP_ID);
  expect_status(er_ui_node_accessibility(&input_group_a11y, &a11y), ER_UI_OK, "node: input group accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_GROUP, "node: input group accessibility role");
  expect_status(er_ui_node_accessibility_child(&input_group_a11y, ER_UI_TEST_NODE_INPUT_GROUP_FIELD_INDEX, &a11y), ER_UI_OK,
                "node: input group field accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_TEXTBOX, "node: input group field accessibility role");
  expect_true(a11y.has_id && a11y.id == ER_UI_TEST_NODE_INPUT_GROUP_ID, "node: input group field id");
  expect_status(er_ui_node_accessibility_child(&input_group_a11y, ER_UI_TEST_NODE_INPUT_GROUP_BUTTON_INDEX, &a11y), ER_UI_OK,
                "node: input group button accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_BUTTON, "node: input group button accessibility role");
  expect_true(a11y.has_id && a11y.id == ER_UI_TEST_NODE_INPUT_GROUP_BUTTON_ID, "node: input group button id");

  const char *const otp_values[] = {"1", "2", "3", "-", "4", "5"};
  er_ui_node_t otp_a11y =
      er_ui_node_input_otp(otp_values, ER_UI_TEST_NODE_ARRAY_COUNT(otp_values), ER_UI_TEST_NODE_INPUT_OTP_FOCUSED_INDEX, ER_UI_TEST_NODE_INPUT_OTP_ID);
  expect_status(er_ui_node_accessibility(&otp_a11y, &a11y), ER_UI_OK, "node: input otp accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_GROUP, "node: input otp accessibility role");
  expect_status(er_ui_node_accessibility_child(&otp_a11y, ER_UI_TEST_NODE_INPUT_OTP_FOCUSED_INDEX, &a11y), ER_UI_OK,
                "node: input otp digit accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_TEXTBOX, "node: input otp digit accessibility role");
  expect_true(a11y.has_id && a11y.id == ER_UI_TEST_NODE_INPUT_OTP_FOCUSED_ID, "node: input otp digit id");
  expect_true((a11y.states & ER_UI_A11Y_STATE_FOCUSED) != 0u, "node: input otp focused digit state");
  expect_status(er_ui_node_accessibility_child(&otp_a11y, ER_UI_TEST_NODE_INPUT_OTP_SEPARATOR_INDEX, &a11y), ER_UI_ERR_INVALID_ARGUMENT,
                "node: input otp separator is not focusable");

  const char *const nav_tabs[] = {"Docs", "Components", "Examples"};
  er_ui_node_t nav_a11y = er_ui_node_navigation_menu(nav_tabs, ER_UI_TEST_NODE_ARRAY_COUNT(nav_tabs), ER_UI_TEST_NODE_NAVIGATION_SELECTED_INDEX,
                                                     "Components", "Reusable primitives", "Accordion", "Disclosure rows", ER_UI_TEST_NODE_NAVIGATION_ID);
  expect_status(er_ui_node_accessibility(&nav_a11y, &a11y), ER_UI_OK, "node: navigation menu accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_NAVIGATION, "node: navigation menu accessibility role");
  expect_status(er_ui_node_accessibility_child(&nav_a11y, ER_UI_TEST_NODE_NAVIGATION_SELECTED_INDEX, &a11y), ER_UI_OK,
                "node: navigation menu tab accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_BUTTON, "node: navigation menu tab role");
  expect_true(a11y.has_id && a11y.id == ER_UI_TEST_NODE_NAVIGATION_SELECTED_ID, "node: navigation menu selected tab id");
  expect_true((a11y.states & ER_UI_A11Y_STATE_SELECTED) != 0u, "node: navigation menu selected tab state");
  expect_status(er_ui_node_accessibility_child(&nav_a11y, ER_UI_TEST_NODE_NAVIGATION_ROW_INDEX, &a11y), ER_UI_OK,
                "node: navigation menu row accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_LIST_ITEM, "node: navigation menu row role");
  expect_true(a11y.has_id && a11y.id == ER_UI_TEST_NODE_NAVIGATION_ROW_ID, "node: navigation menu row id");

  const char *const resizable_labels[] = {"One", "Two", "Three"};
  er_ui_node_t resizable_a11y = er_ui_node_resizable(resizable_labels, ER_UI_TEST_NODE_ARRAY_COUNT(resizable_labels));
  expect_status(er_ui_node_accessibility(&resizable_a11y, &a11y), ER_UI_OK, "node: resizable accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_GROUP, "node: resizable accessibility role");

  const char *const sidebar_items[] = {"Dashboard", "Transactions", "Settings"};
  er_ui_node_t sidebar_a11y = er_ui_node_sidebar("App", "Workspace", sidebar_items, ER_UI_TEST_NODE_ARRAY_COUNT(sidebar_items),
                                                 ER_UI_TEST_NODE_SIDEBAR_SELECTED_INDEX, "Dashboard", "Proof-aware activity",
                                                 ER_UI_TEST_NODE_SIDEBAR_ID);
  expect_status(er_ui_node_accessibility(&sidebar_a11y, &a11y), ER_UI_OK, "node: sidebar accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_NAVIGATION, "node: sidebar accessibility role");
  expect_status(er_ui_node_accessibility_child(&sidebar_a11y, ER_UI_TEST_NODE_SIDEBAR_SELECTED_INDEX, &a11y), ER_UI_OK,
                "node: sidebar selected item accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_MENU_ITEM, "node: sidebar selected item role");
  expect_true((a11y.states & ER_UI_A11Y_STATE_SELECTED) != 0u, "node: sidebar selected item state");
  expect_status(er_ui_node_accessibility_child(&sidebar_a11y, ER_UI_TEST_NODE_SIDEBAR_MAIN_INDEX, &a11y), ER_UI_OK,
                "node: sidebar main panel accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_GROUP, "node: sidebar main panel role");

  const char *const sonner_messages[] = {"Event created", "Upload failed"};
  const er_ui_icon_t sonner_check_icon = ER_UI_ICON_CHECK;
  const er_ui_icon_t sonner_warning_icon = ER_UI_ICON_WARNING;
  //@optimizer-ignore sonner node fixture requires a contiguous borrowed icon vector paired with message and color vectors
  const er_ui_icon_t sonner_icons[ER_UI_TEST_NODE_SONNER_COUNT] = {sonner_check_icon, sonner_warning_icon};
  const er_ui_color4_t sonner_colors[ER_UI_TEST_NODE_SONNER_COUNT] = {er_ui_color_rgba(0.0f, 0.5f, 0.2f, 1.0f),
                                                                       er_ui_color_rgba(0.8f, 0.2f, 0.1f, 1.0f)};
  er_ui_node_t sonner_a11y = er_ui_node_sonner(sonner_messages, sonner_icons, sonner_colors, ER_UI_TEST_NODE_ARRAY_COUNT(sonner_messages));
  expect_status(er_ui_node_accessibility(&sonner_a11y, &a11y), ER_UI_OK, "node: sonner accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_STATUS, "node: sonner accessibility role");
  expect_status(er_ui_node_accessibility_child(&sonner_a11y, ER_UI_TEST_NODE_SONNER_TOAST_INDEX, &a11y), ER_UI_OK,
                "node: sonner toast accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_STATUS, "node: sonner toast accessibility role");
  const char* expected_sonner_message = *(sonner_messages + ER_UI_TEST_NODE_SONNER_TOAST_INDEX);
  expect_true(a11y.label == expected_sonner_message, "node: sonner toast label is borrowed");

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
  expect_status(er_ui_node_accessibility_child(&direction_a11y, ER_UI_TEST_NODE_DIRECTION_RTL_INDEX, &a11y), ER_UI_OK,
                "node: direction child accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_TEXT, "node: direction child role");
  expect_true(a11y.label == direction_a11y.detail, "node: direction rtl text is borrowed");

  er_ui_node_t drawer_a11y = er_ui_node_drawer("Drawer", "Adjust display density.", "Density", 0.42f, ER_UI_TEST_NODE_DRAWER_ID);
  expect_status(er_ui_node_accessibility(&drawer_a11y, &a11y), ER_UI_OK, "node: drawer accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_DIALOG, "node: drawer accessibility role");
  expect_true((a11y.states & ER_UI_A11Y_STATE_OPEN) != 0u, "node: drawer open state");
  expect_status(er_ui_node_accessibility_child(&drawer_a11y, ER_UI_TEST_NODE_DRAWER_SLIDER_INDEX, &a11y), ER_UI_OK,
                "node: drawer slider accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_SLIDER, "node: drawer slider role");
  expect_true(a11y.has_id && a11y.id == ER_UI_TEST_NODE_DRAWER_ID, "node: drawer slider id");
  expect_status(er_ui_node_accessibility_child(&drawer_a11y, ER_UI_TEST_NODE_DRAWER_BUTTON_INDEX, &a11y), ER_UI_OK,
                "node: drawer button accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_BUTTON, "node: drawer button role");
  expect_true(a11y.has_id && a11y.id == ER_UI_TEST_NODE_DRAWER_BUTTON_ID, "node: drawer button id");

  const char *const dropdown_labels[] = {"Profile", "Billing", "Logout"};
  const char *const dropdown_shortcuts[] = {"P", "B", ""};
  er_ui_node_t dropdown_a11y = er_ui_node_dropdown_menu(dropdown_labels, dropdown_shortcuts, ER_UI_TEST_NODE_ARRAY_COUNT(dropdown_labels),
                                                        ER_UI_TEST_NODE_DROPDOWN_SELECTED_INDEX, ER_UI_TEST_NODE_DROPDOWN_ID);
  expect_status(er_ui_node_accessibility(&dropdown_a11y, &a11y), ER_UI_OK, "node: dropdown menu accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_NAVIGATION, "node: dropdown menu accessibility role");
  expect_status(er_ui_node_accessibility_child(&dropdown_a11y, ER_UI_TEST_NODE_DROPDOWN_SELECTED_INDEX, &a11y), ER_UI_OK,
                "node: dropdown menu item accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_MENU_ITEM, "node: dropdown menu item role");
  expect_true(a11y.has_id && a11y.id == ER_UI_TEST_NODE_DROPDOWN_SELECTED_ID, "node: dropdown menu item id");
  expect_true((a11y.states & ER_UI_A11Y_STATE_SELECTED) != 0u, "node: dropdown menu selected state");

  er_ui_node_t context_menu_a11y = er_ui_node_context_menu("Actions", "Right click options", dropdown_labels, dropdown_shortcuts,
                                                           ER_UI_TEST_NODE_ARRAY_COUNT(dropdown_labels), ER_UI_TEST_NODE_CONTEXT_SELECTED_INDEX,
                                                           ER_UI_TEST_NODE_CONTEXT_MENU_ID);
  expect_status(er_ui_node_accessibility(&context_menu_a11y, &a11y), ER_UI_OK, "node: context menu accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_NAVIGATION, "node: context menu accessibility role");
  expect_status(er_ui_node_accessibility_child(&context_menu_a11y, ER_UI_TEST_NODE_CONTEXT_SELECTED_INDEX, &a11y), ER_UI_OK,
                "node: context menu item accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_MENU_ITEM, "node: context menu item role");
  expect_true(a11y.has_id && a11y.id == ER_UI_TEST_NODE_CONTEXT_SELECTED_ID, "node: context menu item id");
  expect_true((a11y.states & ER_UI_A11Y_STATE_SELECTED) != 0u, "node: context menu selected state");

  const char *const date_days[] = {"12", "13", "14", "15"};
  er_ui_node_t date_picker_a11y =
      er_ui_node_date_picker("Pick a date", "May 2026", date_days, ER_UI_TEST_NODE_ARRAY_COUNT(date_days), ER_UI_TEST_NODE_DATE_SELECTED_INDEX,
                             ER_UI_TEST_NODE_DATE_PICKER_ID);
  expect_status(er_ui_node_accessibility(&date_picker_a11y, &a11y), ER_UI_OK, "node: date picker accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_COMBOBOX, "node: date picker accessibility role");
  expect_true((a11y.states & ER_UI_A11Y_STATE_OPEN) != 0u, "node: date picker open state");
  expect_status(er_ui_node_accessibility_child(&date_picker_a11y, ER_UI_TEST_NODE_DATE_TRIGGER_INDEX, &a11y), ER_UI_OK,
                "node: date picker trigger accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_BUTTON, "node: date picker trigger role");
  expect_true(a11y.has_id && a11y.id == ER_UI_TEST_NODE_DATE_PICKER_ID, "node: date picker trigger id");
  expect_status(er_ui_node_accessibility_child(&date_picker_a11y, ER_UI_TEST_NODE_DATE_SELECTED_CHILD_INDEX, &a11y), ER_UI_OK,
                "node: date picker day accessibility maps");
  expect_true(a11y.has_id && a11y.id == ER_UI_TEST_NODE_DATE_SELECTED_ID, "node: date picker day id");
  expect_true((a11y.states & ER_UI_A11Y_STATE_SELECTED) != 0u, "node: date picker selected day state");

  const char *const carousel_items[] = {"One", "Two", "Three"};
  er_ui_node_t carousel_a11y = er_ui_node_carousel(carousel_items, ER_UI_TEST_NODE_ARRAY_COUNT(carousel_items), ER_UI_TEST_NODE_CAROUSEL_ID);
  expect_status(er_ui_node_accessibility(&carousel_a11y, &a11y), ER_UI_OK, "node: carousel accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_GROUP, "node: carousel accessibility role");
  expect_status(er_ui_node_accessibility_child(&carousel_a11y, ER_UI_TEST_NODE_CAROUSEL_PREVIOUS_INDEX, &a11y), ER_UI_OK,
                "node: carousel previous accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_BUTTON, "node: carousel previous role");
  expect_true(a11y.has_id && a11y.id == ER_UI_TEST_NODE_CAROUSEL_ID, "node: carousel previous id");
  expect_status(er_ui_node_accessibility_child(&carousel_a11y, ER_UI_TEST_NODE_CAROUSEL_NEXT_INDEX, &a11y), ER_UI_OK,
                "node: carousel next accessibility maps");
  expect_true(a11y.has_id && a11y.id == ER_UI_TEST_NODE_CAROUSEL_NEXT_ID, "node: carousel next id");

  er_ui_node_t calendar_a11y =
      er_ui_node_calendar("May 2026", date_days, ER_UI_TEST_NODE_ARRAY_COUNT(date_days), ER_UI_TEST_NODE_DATE_SELECTED_INDEX, ER_UI_TEST_NODE_CALENDAR_ID);
  expect_status(er_ui_node_accessibility(&calendar_a11y, &a11y), ER_UI_OK, "node: calendar accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_GROUP, "node: calendar accessibility role");
  expect_status(er_ui_node_accessibility_child(&calendar_a11y, ER_UI_TEST_NODE_CALENDAR_PREVIOUS_INDEX, &a11y), ER_UI_OK,
                "node: calendar previous accessibility maps");
  expect_true(a11y.has_id && a11y.id == ER_UI_TEST_NODE_CALENDAR_ID, "node: calendar previous id");
  expect_status(er_ui_node_accessibility_child(&calendar_a11y, ER_UI_TEST_NODE_CALENDAR_SELECTED_CHILD_INDEX, &a11y), ER_UI_OK,
                "node: calendar day accessibility maps");
  expect_true(a11y.has_id && a11y.id == ER_UI_TEST_NODE_CALENDAR_SELECTED_ID, "node: calendar day id");
  expect_true((a11y.states & ER_UI_A11Y_STATE_SELECTED) != 0u, "node: calendar selected day state");

  const char *const combobox_options[] = {"Apple", "Banana", "Cherry"};
  er_ui_node_t combobox_a11y = er_ui_node_combobox("Fruit", "Banana", "Search fruit...", combobox_options,
                                                   ER_UI_TEST_NODE_ARRAY_COUNT(combobox_options), ER_UI_TEST_NODE_COMBOBOX_SELECTED_INDEX,
                                                   ER_UI_TEST_NODE_COMBOBOX_ID);
  expect_status(er_ui_node_accessibility(&combobox_a11y, &a11y), ER_UI_OK, "node: combobox accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_COMBOBOX, "node: combobox accessibility role");
  expect_true((a11y.states & ER_UI_A11Y_STATE_OPEN) != 0u, "node: combobox open state");
  expect_status(er_ui_node_accessibility_child(&combobox_a11y, ER_UI_TEST_NODE_COMBOBOX_SELECTED_CHILD_INDEX, &a11y), ER_UI_OK,
                "node: combobox option accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_MENU_ITEM, "node: combobox option role");
  expect_true(a11y.has_id && a11y.id == ER_UI_TEST_NODE_COMBOBOX_SELECTED_ID, "node: combobox option id");
  expect_true((a11y.states & ER_UI_A11Y_STATE_SELECTED) != 0u, "node: combobox selected option state");

  const char *const diff_lines[] = {"@@ -1,2 +1,2 @@", "-old", "+new", " context"};
  er_ui_node_t diff_body_a11y = er_ui_node_diff_body(diff_lines, ER_UI_TEST_NODE_ARRAY_COUNT(diff_lines), true);
  expect_status(er_ui_node_accessibility(&diff_body_a11y, &a11y), ER_UI_OK, "node: diff body accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_GROUP, "node: diff body accessibility role");
  expect_true((a11y.states & ER_UI_A11Y_STATE_HAS_VALUE) != 0u, "node: diff body truncated state is exposed");
  expect_status(er_ui_node_accessibility_child(&diff_body_a11y, ER_UI_TEST_NODE_DIFF_LINE_INDEX, &a11y), ER_UI_OK,
                "node: diff body line accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_TEXT, "node: diff body line role");
  const char* expected_diff_line = *(diff_lines + ER_UI_TEST_NODE_DIFF_LINE_INDEX);
  expect_true(a11y.label == expected_diff_line, "node: diff body line label is borrowed");
  expect_status(er_ui_node_accessibility_child(&diff_body_a11y, ER_UI_TEST_NODE_DIFF_TRUNCATED_INDEX, &a11y), ER_UI_OK,
                "node: diff body truncated accessibility maps");
  expect_string(a11y.label, "[diff preview truncated]", "node: diff body truncated label");

  er_ui_node_t chat_message_a11y = er_ui_node_chat_message(ER_UI_SHADCN_CHAT_ROLE_ASSISTANT, "Response", "Done");
  expect_status(er_ui_node_accessibility(&chat_message_a11y, &a11y), ER_UI_OK, "node: chat message accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_GROUP, "node: chat message accessibility role");
  expect_string(a11y.label, "assistant", "node: chat message role label maps");
  expect_true(a11y.value == chat_message_a11y.detail, "node: chat message detail is borrowed");
  er_ui_node_t chat_diff_a11y = er_ui_node_chat_diff_message("Patch", diff_lines, ER_UI_TEST_NODE_ARRAY_COUNT(diff_lines), true);
  expect_status(er_ui_node_accessibility_child(&chat_diff_a11y, ER_UI_TEST_NODE_CHAT_DIFF_LINE_INDEX, &a11y), ER_UI_OK,
                "node: chat diff line accessibility maps");
  expect_true(a11y.label == expected_diff_line, "node: chat diff line label is borrowed");

  er_ui_node_t conversation_a11y = er_ui_node_conversation(12.0f, ER_UI_TEST_NODE_CONVERSATION_ID);
  er_ui_node_t conversation_child_a = er_ui_node_chat_message(ER_UI_SHADCN_CHAT_ROLE_USER, "", "Run tests");
  er_ui_node_t conversation_child_b = er_ui_node_chat_message(ER_UI_SHADCN_CHAT_ROLE_ASSISTANT, "Response", "Tests passed");
  expect_status(er_ui_node_add_child(&conversation_a11y, &conversation_child_a), ER_UI_OK, "node: conversation accepts first child");
  expect_status(er_ui_node_add_child(&conversation_a11y, &conversation_child_b), ER_UI_OK, "node: conversation accepts second child");
  expect_status(er_ui_node_accessibility(&conversation_a11y, &a11y), ER_UI_OK, "node: conversation accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_GROUP, "node: conversation accessibility role");
  expect_true(a11y.has_id && a11y.id == ER_UI_TEST_NODE_CONVERSATION_ID, "node: conversation scroll id");
  expect_status(er_ui_node_accessibility_child(&conversation_a11y, ER_UI_TEST_NODE_CONVERSATION_ASSISTANT_INDEX, &a11y), ER_UI_OK,
                "node: conversation child accessibility maps");
  expect_string(a11y.label, "assistant", "node: conversation child role is preserved");
  expect_status(er_ui_node_child_bounds(&conversation_a11y, ER_UI_TEST_NODE_CONVERSATION_FIRST_INDEX, er_ui_bounds(0.0f, 0.0f, 360.0f, 220.0f),
                                        &resolved_child),
                ER_UI_OK,
                "node: conversation child bounds resolve");
  expect_float(resolved_child.y, 4.0f, "node: conversation child bounds apply padding and scroll offset");

  er_ui_node_t checked = er_ui_node_checkbox("Remember", true, ER_UI_TEST_NODE_CHECKBOX_ID);
  expect_status(er_ui_node_accessibility(&checked, &a11y), ER_UI_OK, "node: checkbox accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_CHECKBOX, "node: checkbox accessibility role");
  expect_true((a11y.states & ER_UI_A11Y_STATE_CHECKED) != 0u, "node: checkbox accessibility checked state");

  er_ui_node_t field_a11y = er_ui_node_field("Email", "name@example.com", ER_UI_TEST_NODE_FIELD_ID);
  expect_status(er_ui_node_accessibility(&field_a11y, &a11y), ER_UI_OK, "node: field accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_TEXTBOX, "node: field accessibility role");
  expect_true((a11y.states & ER_UI_A11Y_STATE_HAS_VALUE) != 0u, "node: field accessibility value state");
  expect_true(a11y.value == field_a11y.value, "node: field accessibility value is borrowed");

  er_ui_node_t tree_a11y = er_ui_node_tree_item("src", "expanded", ER_UI_TEST_NODE_TREE_DEPTH, true, ER_UI_TEST_NODE_TREE_ID);
  expect_status(er_ui_node_accessibility(&tree_a11y, &a11y), ER_UI_OK, "node: tree accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_LIST_ITEM, "node: tree accessibility role");
  expect_true((a11y.states & ER_UI_A11Y_STATE_EXPANDED) != 0u, "node: tree accessibility expanded state");
  expect_true(er_ui_a11y_role_label(a11y.role) != NULL, "node: accessibility role has stable label");

  const char *const a11y_tabs[] = {"One", "Two"};
  er_ui_node_t tabs_a11y =
      er_ui_node_tabs(a11y_tabs, ER_UI_TEST_NODE_ARRAY_COUNT(a11y_tabs), ER_UI_TEST_NODE_TABS_SELECTED_INDEX, ER_UI_TEST_NODE_TABS_ID);
  expect_status(er_ui_node_accessibility(&tabs_a11y, &a11y), ER_UI_OK, "node: tab list accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_TAB_LIST, "node: tab list accessibility role");
  expect_status(er_ui_node_accessibility_child(&tabs_a11y, ER_UI_TEST_NODE_TABS_SELECTED_INDEX, &a11y), ER_UI_OK,
                "node: selected tab accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_TAB, "node: selected tab accessibility role");
  expect_true(a11y.has_id && a11y.id == ER_UI_TEST_NODE_TABS_SELECTED_ID, "node: selected tab accessibility id");
  expect_true((a11y.states & ER_UI_A11Y_STATE_SELECTED) != 0u, "node: selected tab accessibility state");

  const char *const a11y_headers[] = {"Name"};
  const char *const a11y_cells[] = {"EdgeRun"};
  er_ui_node_t table_a11y =
      er_ui_node_table(a11y_headers, ER_UI_TEST_NODE_ARRAY_COUNT(a11y_headers), a11y_cells, ER_UI_TEST_NODE_ARRAY_COUNT(a11y_headers),
                       ER_UI_TEST_NODE_TABLE_ID);
  expect_status(er_ui_node_accessibility_child(&table_a11y, ER_UI_TEST_NODE_TABLE_HEADER_INDEX, &a11y), ER_UI_OK,
                "node: table header accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_ROW, "node: table header accessibility role");
  expect_status(er_ui_node_accessibility_child(&table_a11y, ER_UI_TEST_NODE_TABLE_ROW_INDEX, &a11y), ER_UI_OK, "node: table row accessibility maps");
  expect_true(a11y.has_id && a11y.id == ER_UI_TEST_NODE_TABLE_ID, "node: table row accessibility id");

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
  vr_font_face_t* face = er_ui_test_open_font(14.0f, "node: bundled variable font loads", "node: variable font opens from memory");
  if (face) {
    er_ui_resolved_theme_t theme = er_ui_resolved_theme_user_default();
    expect_status(er_ui_node_render(&root, &scene, face, er_ui_bounds(0.0f, 0.0f, 320.0f, 160.0f), theme), ER_UI_OK,
                  "node: card tree renders");

    er_ui_node_t alert = er_ui_node_alert("Heads up", "Reusable components stay in UI core.", theme.colors.warning);
    er_ui_node_t avatar = er_ui_node_avatar("ER", theme.colors.accent, true);
    er_ui_node_t progress = er_ui_node_progress(0.66f);
    er_ui_node_t switch_node = er_ui_node_switch(true, ER_UI_TEST_NODE_CHECKBOX_ID);
    const char *const breadcrumb_labels[] = {"Docs", "Components", "Button"};
    er_ui_node_t breadcrumb = er_ui_node_breadcrumb(breadcrumb_labels, ER_UI_TEST_NODE_ARRAY_COUNT(breadcrumb_labels),
                                                   ER_UI_TEST_NODE_RENDER_BREADCRUMB_CURRENT_INDEX, ER_UI_TEST_NODE_RENDER_BREADCRUMB_ID);
    const char *const table_headers[] = {"Invoice", "Status"};
    const char *const table_cells[] = {"INV001", "Paid", "INV002", "Pending"};
    er_ui_node_t table =
        er_ui_node_table(table_headers, ER_UI_TEST_NODE_ARRAY_COUNT(table_headers), table_cells, ER_UI_TEST_NODE_ARRAY_COUNT(table_headers),
                         ER_UI_TEST_NODE_RENDER_TABLE_ID);
    er_ui_node_t toast = er_ui_node_toast("Scheduled", theme.colors.accent);
    er_ui_node_t toast_icon = er_ui_node_toast_icon("Saved", ER_UI_ICON_CHECK, theme.colors.success);
    er_ui_node_t card_summary = er_ui_node_card_summary("Title", "Detail");
    er_ui_node_t empty = er_ui_node_empty("No results", "Try another filter.");
    er_ui_node_t list_row = er_ui_node_list_row("Billing", "Command B", ER_UI_TEST_NODE_RENDER_LIST_ROW_ID, true);
    er_ui_node_t field = er_ui_node_field("Email", "name@example.com", ER_UI_TEST_NODE_RENDER_FIELD_ID);
    er_ui_node_t text_area = er_ui_node_text_area("Message", "Type your message here.", ER_UI_TEST_NODE_RENDER_TEXT_AREA_ID);
    const char *const tab_labels[] = {"Account", "Billing", "Team"};
    er_ui_node_t tabs =
        er_ui_node_tabs(tab_labels, ER_UI_TEST_NODE_ARRAY_COUNT(tab_labels), ER_UI_TEST_NODE_RENDER_TABS_SELECTED_INDEX, ER_UI_TEST_NODE_RENDER_TABS_ID);
    const char *const chart_labels[] = {"Jan", "Feb", "Mar"};
    const float chart_values[] = {0.25f, 0.72f, 0.54f};
    er_ui_node_t chart = er_ui_node_bar_chart("Visitors", chart_labels, chart_values, ER_UI_TEST_NODE_ARRAY_COUNT(chart_labels),
                                              ER_UI_TEST_NODE_RENDER_CHART_ID, ER_UI_TEST_NODE_RENDER_CHART_ACTIVE_INDEX);
    er_ui_node_t command = er_ui_node_command_palette("Search components...", ER_UI_TEST_NODE_RENDER_COMMAND_ID);
    er_ui_node_t tree_item = er_ui_node_tree_item("src", "expanded", ER_UI_TEST_NODE_TREE_DEPTH, true, ER_UI_TEST_NODE_RENDER_TREE_ID);
    er_ui_node_t section = er_ui_node_section("Proof", "Verified rows");
    er_ui_node_t identity = er_ui_node_identity_card("Ken", "browser-node", "personal", ER_UI_TEST_NODE_RENDER_IDENTITY_ID);
    er_ui_node_t contact = er_ui_node_contact_card("Ada", "publisher", ER_UI_TEST_NODE_RENDER_CONTACT_ID);
    er_ui_node_t thread = er_ui_node_thread_row("Sync complete", "Drive import finished", true, ER_UI_TEST_NODE_RENDER_THREAD_ID);
    er_ui_node_t attachment = er_ui_node_attachment_preview("manifest.rkyv", "package manifest", ER_UI_TEST_NODE_RENDER_ATTACHMENT_ID);
    er_ui_node_t grant = er_ui_node_capability_grant_row("Mail", "contacts:read", "granted", ER_UI_TEST_NODE_RENDER_GRANT_ID);
    er_ui_node_t proof = er_ui_node_proof_event_row("Package hash", "b3:abc123", "verified", ER_UI_TEST_NODE_RENDER_PROOF_ID);
    const char *const route_hops[] = {"browser", "admission", "relay"};
    er_ui_node_t route = er_ui_node_route_path("Admission route", route_hops, ER_UI_TEST_NODE_ARRAY_COUNT(route_hops));
    er_ui_node_t package = er_ui_node_package_card("Docs", "cache-ok", "b3:def456", ER_UI_TEST_NODE_RENDER_ROUTE_PACKAGE_ID);
    er_ui_node_t receipt = er_ui_node_receipt_row("Retrieval", "4 units", "settled", ER_UI_TEST_NODE_RENDER_RECEIPT_ID);
    er_ui_node_t panel = er_ui_node_panel_header("Dashboard", "Reusable UI primitives", "Run", ER_UI_TEST_NODE_RENDER_PANEL_ID);
    er_ui_node_t metric = er_ui_node_metric_card("Budget", "184", "units reserved", true, 0.64f, theme.colors.accent);
    er_ui_node_t transaction = er_ui_node_transaction_row("Storage", "verified retrieval", "today", "8 units", false, ER_UI_TEST_NODE_RENDER_TRANSACTION_ID);
    er_ui_node_t menu = er_ui_node_menu_item("Verify package", "content hash", "new", true, theme.colors.accent, ER_UI_TEST_NODE_RENDER_MENU_ID);
    er_ui_node_t control = er_ui_node_control_row("Cache package", "avoid repeated retrieval", "enabled", ER_UI_TEST_NODE_RENDER_CONTROL_ID);
    er_ui_node_t grid = er_ui_node_grid(ER_UI_TEST_NODE_RENDER_GRID_COLUMNS);
    er_ui_node_set_gap(&grid, 4.0f);
    er_ui_node_t grid_badge_a = er_ui_node_badge("One", ER_UI_SHADCN_BADGE_DEFAULT);
    er_ui_node_t grid_badge_b = er_ui_node_badge("Two", ER_UI_SHADCN_BADGE_SECONDARY);
    er_ui_node_t grid_badge_c = er_ui_node_badge("Three", ER_UI_SHADCN_BADGE_OUTLINE);
    expect_status(er_ui_node_add_child(&grid, &grid_badge_a), ER_UI_OK, "node: grid accepts first child");
    expect_status(er_ui_node_add_child(&grid, &grid_badge_b), ER_UI_OK, "node: grid accepts second child");
    expect_status(er_ui_node_add_child(&grid, &grid_badge_c), ER_UI_OK, "node: grid accepts third child");
    expect_status(er_ui_node_child_bounds(&grid, ER_UI_TEST_NODE_RENDER_GRID_THIRD_CHILD, er_ui_bounds(0.0f, 0.0f, 260.0f, 80.0f), &resolved_child),
                  ER_UI_OK,
                  "node: grid child bounds resolve");
    expect_float(resolved_child.x, 0.0f, "node: grid child bounds x wraps");
    expect_float(resolved_child.y, 42.0f, "node: grid child bounds y wraps");
    expect_float(resolved_child.w, 128.0f, "node: grid child bounds width divides columns");
    expect_float(resolved_child.h, 38.0f, "node: grid child bounds height divides rows");
    er_ui_node_t scroll = er_ui_node_scroll_area(20.0f, ER_UI_TEST_NODE_RENDER_SCROLL_ID);
    er_ui_node_set_gap(&scroll, 4.0f);
    er_ui_node_t scroll_a = er_ui_node_list_row("Top", "scrolled", ER_UI_TEST_NODE_RENDER_SCROLL_FIRST_ROW_ID, false);
    er_ui_node_t scroll_b = er_ui_node_list_row("Bottom", "visible", ER_UI_TEST_NODE_RENDER_SCROLL_SECOND_ROW_ID, true);
    expect_status(er_ui_node_add_child(&scroll, &scroll_a), ER_UI_OK, "node: scroll accepts first child");
    expect_status(er_ui_node_add_child(&scroll, &scroll_b), ER_UI_OK, "node: scroll accepts second child");
    expect_status(er_ui_node_child_bounds(&scroll, ER_UI_TEST_NODE_RENDER_SCROLL_FIRST_CHILD, er_ui_bounds(0.0f, 2560.0f, 260.0f, 64.0f),
                                          &resolved_child),
                  ER_UI_OK,
                  "node: scroll child bounds resolve offset");
    expect_float(resolved_child.y, 2540.0f, "node: scroll child bounds applies offset");
    er_ui_node_t spacer = er_ui_node_spacer();
    er_ui_node_t tooltip = er_ui_node_tooltip("Verify package");
    er_ui_node_t dialog = er_ui_node_dialog("Run network app", "Verify signed package bytes first.", theme.colors.accent);
    er_ui_node_t ring = er_ui_node_progress_ring(0.58f, theme.colors.success);
    er_ui_node_t reorderable = er_ui_node_list_row("Drag me", "reorderable", ER_UI_TEST_NODE_RENDER_REORDERABLE_ID, false);
    er_ui_node_set_reorderable(&reorderable, ER_UI_TEST_NODE_RENDER_REORDER_GROUP_ID, ER_UI_TEST_NODE_RENDER_REORDERABLE_ID,
                               ER_UI_TEST_NODE_RENDER_REORDER_INDEX);
    er_ui_node_t gradient_card = er_ui_node_card();
    er_ui_node_set_background_gradient(&gradient_card, theme.colors.panel, theme.colors.active);
    er_ui_node_set_transition(&gradient_card, er_ui_transition_opacity(ER_UI_TEST_NODE_RENDER_TRANSITION_ID, 0.0f, 1.0f,
                                                                       ER_UI_TEST_NODE_RENDER_TRANSITION_MS));
    er_ui_node_t gradient_label = er_ui_node_text("Gradient card");
    expect_status(er_ui_node_add_child(&gradient_card, &gradient_label), ER_UI_OK, "node: gradient card accepts child");
    er_ui_node_t icon = er_ui_node_icon(ER_UI_ICON_TRUST, "Trust", theme.colors.accent);
    er_ui_node_t icon_button = er_ui_node_icon_button(ER_UI_ICON_SEARCH, "Search", ER_UI_TEST_NODE_RENDER_ICON_BUTTON_ID, ER_UI_SHADCN_BUTTON_GHOST);
    const char *const render_button_group_labels[] = {"Copy", "Paste", "More"};
    er_ui_node_t button_group =
        er_ui_node_button_group(render_button_group_labels, ER_UI_TEST_NODE_ARRAY_COUNT(render_button_group_labels), ER_UI_TEST_NODE_RENDER_BUTTON_GROUP_ID);
    const char *const render_toggle_group_labels[] = {"B", "I", "U"};
    er_ui_node_t toggle_group = er_ui_node_toggle_group(render_toggle_group_labels, ER_UI_TEST_NODE_ARRAY_COUNT(render_toggle_group_labels),
                                                        ER_UI_TEST_NODE_TOGGLE_SELECTED_INDEX, ER_UI_TEST_NODE_RENDER_TOGGLE_GROUP_ID);
    const char *const render_pagination_labels[] = {"1", "2"};
    er_ui_node_t pagination = er_ui_node_pagination(render_pagination_labels, ER_UI_TEST_NODE_ARRAY_COUNT(render_pagination_labels),
                                                    ER_UI_TEST_NODE_RENDER_PAGINATION_SELECTED_INDEX, ER_UI_TEST_NODE_RENDER_PAGINATION_ID);
    const char *const render_collapsible_titles[] = {"Accordion", "Collapsible"};
    const char *const render_collapsible_details[] = {"one open item", "disclosure rows"};
    er_ui_node_t collapsible = er_ui_node_collapsible("Disclosure", render_collapsible_titles, render_collapsible_details,
                                                      ER_UI_TEST_NODE_ARRAY_COUNT(render_collapsible_titles), true,
                                                      ER_UI_TEST_NODE_RENDER_COLLAPSIBLE_ID);
    const char *const render_accordion_titles[] = {"Is it accessible?", "Is it styled?"};
    const char *const render_accordion_bodies[] = {"Yes, each trigger is exposed.", "It uses shared shadcn primitives."};
    er_ui_node_t accordion = er_ui_node_accordion(render_accordion_titles, render_accordion_bodies, ER_UI_TEST_NODE_ARRAY_COUNT(render_accordion_titles),
                                                  ER_UI_TEST_NODE_RENDER_ACCORDION_ID);
    er_ui_node_t hover_card = er_ui_node_hover_card("ER", "UI core", "Variable font rendering stays required.", theme.colors.accent);
    er_ui_node_t popover = er_ui_node_popover("Open popover", "Dimensions", "Set layout constraints.", "Width", "100%", ER_UI_TEST_NODE_RENDER_POPOVER_ID);
    er_ui_node_t sheet = er_ui_node_sheet("Profile", "Update local profile.", "Name", "EdgeRun", "Save changes", ER_UI_TEST_NODE_RENDER_SHEET_ID);
    const char *const render_kbd_keys[] = {"Ctrl", "K"};
    er_ui_node_t kbd = er_ui_node_kbd(render_kbd_keys, ER_UI_TEST_NODE_ARRAY_COUNT(render_kbd_keys), "Open command palette");
    const char *const render_menubar_items[] = {"File", "Edit", "View"};
    er_ui_node_t menubar = er_ui_node_menubar(render_menubar_items, ER_UI_TEST_NODE_ARRAY_COUNT(render_menubar_items),
                                              ER_UI_TEST_NODE_MENUBAR_SELECTED_INDEX, ER_UI_TEST_NODE_RENDER_MENUBAR_ID);
    const char *const render_radio_group_labels[] = {"Default", "Comfortable", "Compact"};
    er_ui_node_t radio_group = er_ui_node_radio_group(render_radio_group_labels, ER_UI_TEST_NODE_ARRAY_COUNT(render_radio_group_labels),
                                                      ER_UI_TEST_NODE_RENDER_RADIO_SELECTED_INDEX, ER_UI_TEST_NODE_RENDER_RADIO_GROUP_ID);
    er_ui_node_t input_group = er_ui_node_input_group("URL", "https://edgerun.local", "Copy", ER_UI_TEST_NODE_RENDER_INPUT_GROUP_ID);
    const char *const render_otp_values[] = {"1", "2", "3", "-", "4", ""};
    er_ui_node_t input_otp = er_ui_node_input_otp(render_otp_values, ER_UI_TEST_NODE_ARRAY_COUNT(render_otp_values),
                                                 ER_UI_TEST_NODE_RENDER_INPUT_OTP_FOCUSED_INDEX, ER_UI_TEST_NODE_RENDER_INPUT_OTP_ID);
    const char *const render_nav_tabs[] = {"Docs", "Components", "Examples"};
    er_ui_node_t navigation_menu = er_ui_node_navigation_menu(render_nav_tabs, ER_UI_TEST_NODE_ARRAY_COUNT(render_nav_tabs),
                                                              ER_UI_TEST_NODE_RENDER_NAVIGATION_SELECTED_INDEX, "Components", "Reusable primitives",
                                                              "Accordion", "Disclosure rows", ER_UI_TEST_NODE_RENDER_NAVIGATION_ID);
    const char *const render_resizable_labels[] = {"One", "Two", "Three"};
    er_ui_node_t resizable = er_ui_node_resizable(render_resizable_labels, ER_UI_TEST_NODE_ARRAY_COUNT(render_resizable_labels));
    const char *const render_sidebar_items[] = {"Dashboard", "Transactions", "Settings"};
    er_ui_node_t sidebar = er_ui_node_sidebar("App", "Workspace", render_sidebar_items, ER_UI_TEST_NODE_ARRAY_COUNT(render_sidebar_items),
                                              ER_UI_TEST_NODE_RENDER_SIDEBAR_SELECTED_INDEX, "Dashboard", "Proof-aware activity",
                                              ER_UI_TEST_NODE_RENDER_SIDEBAR_ID);
    const char *const render_sonner_messages[] = {"Event created", "Upload failed"};
    const er_ui_icon_t render_sonner_check_icon = ER_UI_ICON_CHECK;
    const er_ui_icon_t render_sonner_warning_icon = ER_UI_ICON_WARNING;
    //@optimizer-ignore sonner render fixture requires a contiguous borrowed icon vector paired with message and color vectors
    const er_ui_icon_t render_sonner_icons[ER_UI_TEST_NODE_SONNER_COUNT] = {render_sonner_check_icon, render_sonner_warning_icon};
    const er_ui_color4_t render_sonner_colors[ER_UI_TEST_NODE_SONNER_COUNT] = {theme.colors.success, theme.colors.danger};
    er_ui_node_t sonner = er_ui_node_sonner(render_sonner_messages, render_sonner_icons, render_sonner_colors,
                                            ER_UI_TEST_NODE_ARRAY_COUNT(render_sonner_messages));
    er_ui_node_t aspect = er_ui_node_aspect_ratio("Preview", ER_UI_ICON_FILE);
    er_ui_node_t alert_dialog = er_ui_node_alert_dialog("Are you absolutely sure?", "This action cannot be undone.", ER_UI_ICON_WARNING);
    er_ui_node_t direction = er_ui_node_direction("Left to right", "Right to left");
    er_ui_node_t drawer = er_ui_node_drawer("Drawer", "Adjust display density.", "Density", 0.42f, ER_UI_TEST_NODE_RENDER_DRAWER_ID);
    const char *const render_dropdown_labels[] = {"Profile", "Billing", "Logout"};
    const char *const render_dropdown_shortcuts[] = {"P", "B", ""};
    er_ui_node_t dropdown_menu = er_ui_node_dropdown_menu(render_dropdown_labels, render_dropdown_shortcuts, ER_UI_TEST_NODE_ARRAY_COUNT(render_dropdown_labels),
                                                          ER_UI_TEST_NODE_RENDER_DROPDOWN_SELECTED_INDEX, ER_UI_TEST_NODE_RENDER_DROPDOWN_ID);
    er_ui_node_t context_menu =
        er_ui_node_context_menu("Actions", "Right click options", render_dropdown_labels, render_dropdown_shortcuts,
                                ER_UI_TEST_NODE_ARRAY_COUNT(render_dropdown_labels), ER_UI_TEST_NODE_RENDER_CONTEXT_SELECTED_INDEX,
                                ER_UI_TEST_NODE_RENDER_CONTEXT_MENU_ID);
    const char *const render_date_days[] = {"12", "13", "14", "15"};
    er_ui_node_t date_picker = er_ui_node_date_picker("Pick a date", "May 2026", render_date_days, ER_UI_TEST_NODE_ARRAY_COUNT(render_date_days),
                                                      ER_UI_TEST_NODE_RENDER_DATE_SELECTED_INDEX, ER_UI_TEST_NODE_RENDER_DATE_PICKER_ID);
    const char *const render_carousel_items[] = {"One", "Two", "Three"};
    er_ui_node_t carousel = er_ui_node_carousel(render_carousel_items, ER_UI_TEST_NODE_ARRAY_COUNT(render_carousel_items), ER_UI_TEST_NODE_RENDER_CAROUSEL_ID);
    er_ui_node_t calendar = er_ui_node_calendar("May 2026", render_date_days, ER_UI_TEST_NODE_ARRAY_COUNT(render_date_days),
                                                ER_UI_TEST_NODE_RENDER_DATE_SELECTED_INDEX, ER_UI_TEST_NODE_RENDER_CALENDAR_ID);
    const char *const render_combobox_options[] = {"Apple", "Banana", "Cherry"};
    er_ui_node_t combobox = er_ui_node_combobox("Fruit", "Banana", "Search fruit...", render_combobox_options,
                                                ER_UI_TEST_NODE_ARRAY_COUNT(render_combobox_options), ER_UI_TEST_NODE_RENDER_COMBOBOX_SELECTED_INDEX,
                                                ER_UI_TEST_NODE_RENDER_COMBOBOX_ID);
    const char *const render_diff_lines[] = {"@@ -1,2 +1,2 @@", "-old", "+new", "*** End Patch"};
    er_ui_node_t diff_body = er_ui_node_diff_body(render_diff_lines, ER_UI_TEST_NODE_ARRAY_COUNT(render_diff_lines), true);
    er_ui_node_t chat_message = er_ui_node_chat_message(ER_UI_SHADCN_CHAT_ROLE_ASSISTANT, "Response", "Done");
    er_ui_node_t chat_timeline = er_ui_node_chat_message(ER_UI_SHADCN_CHAT_ROLE_TOOL_RUNNING, "Started", "shell");
    er_ui_node_t chat_diff = er_ui_node_chat_diff_message("Patch", render_diff_lines, ER_UI_TEST_NODE_ARRAY_COUNT(render_diff_lines), true);
    er_ui_node_t conversation = er_ui_node_conversation(8.0f, ER_UI_TEST_NODE_RENDER_CONVERSATION_ID);
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
    const er_ui_quad_t* trust_icon_quad = scene.icon_quads + icon_quads_before;
    expect_u32(trust_icon_quad->atlas_id, er_ui_icon_atlas_id(ER_UI_ICON_TRUST), "node: icon quad carries atlas id");
    expect_status(er_ui_node_render(&icon_button, &scene, face, er_ui_bounds(108.0f, 2870.0f, 40.0f, 40.0f), theme), ER_UI_OK,
                  "node: icon button renders");
    expect_size(scene.icon_quad_count, icon_quads_before + 2u, "node: icon button emits icon quad");
    expect_size(scene.hit_count, hits_before_icon_button + 1u, "node: icon button emits hit");
    size_t hits_before_groups = scene.hit_count;
    expect_status(er_ui_node_render(&button_group, &scene, face, er_ui_bounds(160.0f, 2870.0f, 210.0f, 38.0f), theme), ER_UI_OK,
                  "node: button group renders");
    expect_size(scene.hit_count, hits_before_groups + ER_UI_TEST_NODE_RENDER_BUTTON_GROUP_HITS, "node: button group emits button hits");
    expect_status(er_ui_node_render(&toggle_group, &scene, face, er_ui_bounds(0.0f, 2994.0f, 126.0f, 38.0f), theme), ER_UI_OK,
                  "node: toggle group renders");
    expect_size(scene.hit_count, hits_before_groups + ER_UI_TEST_NODE_RENDER_TOGGLE_TOTAL_HITS, "node: toggle group emits button hits");
    expect_status(er_ui_node_render(&pagination, &scene, face, er_ui_bounds(140.0f, 2994.0f, 212.0f, 40.0f), theme), ER_UI_OK,
                  "node: pagination renders");
    expect_size(scene.hit_count, hits_before_groups + ER_UI_TEST_NODE_RENDER_PAGINATION_TOTAL_HITS, "node: pagination emits navigation hits");
    expect_status(er_ui_node_render(&collapsible, &scene, face, er_ui_bounds(0.0f, 3044.0f, 320.0f, 148.0f), theme), ER_UI_OK,
                  "node: collapsible renders");
    expect_size(scene.hit_count, hits_before_groups + ER_UI_TEST_NODE_RENDER_COLLAPSIBLE_TOTAL_HITS, "node: collapsible emits trigger and row hits");
    expect_status(er_ui_node_render(&accordion, &scene, face, er_ui_bounds(0.0f, 3204.0f, 340.0f, 156.0f), theme), ER_UI_OK,
                  "node: accordion renders");
    expect_size(scene.hit_count, hits_before_groups + ER_UI_TEST_NODE_RENDER_ACCORDION_TOTAL_HITS, "node: accordion emits item trigger hits");
    size_t text_before_hover = scene.text_quad_count;
    expect_status(er_ui_node_render(&hover_card, &scene, face, er_ui_bounds(0.0f, 3372.0f, 320.0f, 88.0f), theme), ER_UI_OK,
                  "node: hover card renders");
    expect_true(scene.text_quad_count > text_before_hover, "node: hover card emits variable font text");
    size_t hits_before_popover = scene.hit_count;
    expect_status(er_ui_node_render(&popover, &scene, face, er_ui_bounds(0.0f, 3472.0f, 320.0f, 170.0f), theme), ER_UI_OK,
                  "node: popover renders");
    expect_size(scene.hit_count, hits_before_popover + ER_UI_TEST_NODE_RENDER_TWO_HITS, "node: popover emits trigger and field hits");
    size_t hits_before_sheet = scene.hit_count;
    expect_status(er_ui_node_render(&sheet, &scene, face, er_ui_bounds(0.0f, 3654.0f, 320.0f, 196.0f), theme), ER_UI_OK,
                  "node: sheet renders");
    expect_size(scene.hit_count, hits_before_sheet + ER_UI_TEST_NODE_RENDER_TWO_HITS, "node: sheet emits field and button hits");
    size_t rects_before_kbd = scene.rect_count;
    expect_status(er_ui_node_render(&kbd, &scene, face, er_ui_bounds(0.0f, 3862.0f, 320.0f, 40.0f), theme), ER_UI_OK,
                  "node: kbd renders");
    expect_true(scene.rect_count > rects_before_kbd, "node: kbd emits key badge rects");
    size_t hits_before_menubar = scene.hit_count;
    expect_status(er_ui_node_render(&menubar, &scene, face, er_ui_bounds(0.0f, 3914.0f, 300.0f, 46.0f), theme), ER_UI_OK,
                  "node: menubar renders");
    expect_size(scene.hit_count, hits_before_menubar + ER_UI_TEST_NODE_RENDER_MENUBAR_HITS, "node: menubar emits item hits");
    size_t hits_before_radio_group = scene.hit_count;
    expect_status(er_ui_node_render(&radio_group, &scene, face, er_ui_bounds(0.0f, 3972.0f, 260.0f, 106.0f), theme), ER_UI_OK,
                  "node: radio group renders");
    expect_size(scene.hit_count, hits_before_radio_group + ER_UI_TEST_NODE_RENDER_RADIO_HITS, "node: radio group emits radio hits");
    size_t hits_before_input_group = scene.hit_count;
    expect_status(er_ui_node_render(&input_group, &scene, face, er_ui_bounds(0.0f, 4090.0f, 340.0f, 58.0f), theme), ER_UI_OK,
                  "node: input group renders");
    expect_size(scene.hit_count, hits_before_input_group + ER_UI_TEST_NODE_RENDER_TWO_HITS, "node: input group emits field and button hits");
    size_t hits_before_input_otp = scene.hit_count;
    expect_status(er_ui_node_render(&input_otp, &scene, face, er_ui_bounds(0.0f, 4160.0f, 300.0f, 52.0f), theme), ER_UI_OK,
                  "node: input otp renders");
    expect_size(scene.hit_count, hits_before_input_otp + ER_UI_TEST_NODE_RENDER_INPUT_OTP_HITS, "node: input otp emits editable cell hits");
    size_t hits_before_navigation_menu = scene.hit_count;
    expect_status(er_ui_node_render(&navigation_menu, &scene, face, er_ui_bounds(0.0f, 4224.0f, 360.0f, 154.0f), theme), ER_UI_OK,
                  "node: navigation menu renders");
    expect_size(scene.hit_count, hits_before_navigation_menu + ER_UI_TEST_NODE_RENDER_NAVIGATION_HITS, "node: navigation menu emits tab and row hits");
    size_t rects_before_resizable = scene.rect_count;
    expect_status(er_ui_node_render(&resizable, &scene, face, er_ui_bounds(0.0f, 4390.0f, 360.0f, 112.0f), theme), ER_UI_OK,
                  "node: resizable renders");
    expect_true(scene.rect_count > rects_before_resizable, "node: resizable emits cards and divider");
    size_t hits_before_sidebar = scene.hit_count;
    expect_status(er_ui_node_render(&sidebar, &scene, face, er_ui_bounds(0.0f, 4514.0f, 420.0f, 176.0f), theme), ER_UI_OK,
                  "node: sidebar renders");
    expect_size(scene.hit_count, hits_before_sidebar + ER_UI_TEST_NODE_RENDER_SIDEBAR_HITS, "node: sidebar emits menu item hits");
    size_t icon_quads_before_sonner = scene.icon_quad_count;
    expect_status(er_ui_node_render(&sonner, &scene, face, er_ui_bounds(0.0f, 4702.0f, 300.0f, 112.0f), theme), ER_UI_OK,
                  "node: sonner renders");
    expect_size(scene.icon_quad_count, icon_quads_before_sonner + ER_UI_TEST_NODE_RENDER_SONNER_ICON_QUADS,
                "node: sonner emits toast chrome and status icon quads");
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
    expect_size(scene.hit_count, hits_before_drawer + ER_UI_TEST_NODE_RENDER_TWO_HITS, "node: drawer emits slider and button hits");
    size_t hits_before_dropdown = scene.hit_count;
    expect_status(er_ui_node_render(&dropdown_menu, &scene, face, er_ui_bounds(0.0f, 5452.0f, 260.0f, 144.0f), theme), ER_UI_OK,
                  "node: dropdown menu renders");
    expect_size(scene.hit_count, hits_before_dropdown + ER_UI_TEST_NODE_RENDER_DROPDOWN_HITS, "node: dropdown menu emits item hits");
    size_t hits_before_context = scene.hit_count;
    expect_status(er_ui_node_render(&context_menu, &scene, face, er_ui_bounds(0.0f, 5608.0f, 280.0f, 220.0f), theme), ER_UI_OK,
                  "node: context menu renders");
    expect_size(scene.hit_count, hits_before_context + ER_UI_TEST_NODE_RENDER_CONTEXT_HITS, "node: context menu emits item hits");
    size_t hits_before_date_picker = scene.hit_count;
    expect_status(er_ui_node_render(&date_picker, &scene, face, er_ui_bounds(0.0f, 5840.0f, 300.0f, 128.0f), theme), ER_UI_OK,
                  "node: date picker renders");
    expect_size(scene.hit_count, hits_before_date_picker + ER_UI_TEST_NODE_RENDER_DATE_PICKER_HITS, "node: date picker emits trigger and day hits");
    size_t hits_before_carousel = scene.hit_count;
    size_t icons_before_carousel = scene.icon_quad_count;
    expect_status(er_ui_node_render(&carousel, &scene, face, er_ui_bounds(0.0f, 5980.0f, 420.0f, 96.0f), theme), ER_UI_OK,
                  "node: carousel renders");
    expect_size(scene.hit_count, hits_before_carousel + ER_UI_TEST_NODE_RENDER_TWO_HITS, "node: carousel emits previous and next hits");
    expect_size(scene.icon_quad_count, icons_before_carousel + ER_UI_TEST_NODE_RENDER_TWO_HITS, "node: carousel emits chevron icons");
    size_t hits_before_calendar = scene.hit_count;
    size_t icons_before_calendar = scene.icon_quad_count;
    expect_status(er_ui_node_render(&calendar, &scene, face, er_ui_bounds(0.0f, 6088.0f, 320.0f, 150.0f), theme), ER_UI_OK,
                  "node: calendar renders");
    expect_size(scene.hit_count, hits_before_calendar + ER_UI_TEST_NODE_RENDER_CALENDAR_HITS, "node: calendar emits navigation and day hits");
    expect_size(scene.icon_quad_count, icons_before_calendar + ER_UI_TEST_NODE_RENDER_TWO_HITS, "node: calendar emits navigation icons");
    size_t hits_before_combobox = scene.hit_count;
    expect_status(er_ui_node_render(&combobox, &scene, face, er_ui_bounds(0.0f, 6250.0f, 300.0f, 250.0f), theme), ER_UI_OK,
                  "node: combobox renders");
    expect_size(scene.hit_count, hits_before_combobox + ER_UI_TEST_NODE_RENDER_COMBOBOX_HITS, "node: combobox emits select, command, and option hits");
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
    expect_true(scene.icon_quad_count >= icons_before_chat + ER_UI_TEST_NODE_RENDER_CHAT_ICON_QUADS, "node: chat messages emit role icons");
    expect_true(scene.text_quad_count > text_before_chat, "node: chat messages emit variable font text");
    size_t hits_before_conversation = scene.hit_count;
    expect_status(er_ui_node_render(&conversation, &scene, face, er_ui_bounds(0.0f, 7034.0f, 380.0f, 220.0f), theme), ER_UI_OK,
                  "node: conversation renders");
    expect_size(scene.hit_count, hits_before_conversation + ER_UI_TEST_NODE_RENDER_ONE_HIT, "node: conversation emits scroll hit");
    size_t drag_sources_before = scene.drag_source_count;
    size_t drop_targets_before = scene.drop_target_count;
    expect_status(er_ui_node_render(&reorderable, &scene, face, er_ui_bounds(0.0f, 2930.0f, 260.0f, 52.0f), theme), ER_UI_OK,
                  "node: reorderable row renders");
    expect_size(scene.drag_source_count, drag_sources_before + ER_UI_TEST_NODE_RENDER_ONE_HIT, "node: reorderable emits drag source");
    expect_size(scene.drop_target_count, drop_targets_before + ER_UI_TEST_NODE_RENDER_ONE_HIT, "node: reorderable emits drop target");
    expect_size(scene.drag_sources[drag_sources_before].scope_id, ER_UI_TEST_NODE_RENDER_REORDER_GROUP_ID, "node: drag source scope is preserved");
    expect_size(scene.drag_sources[drag_sources_before].item_id, ER_UI_TEST_NODE_RENDER_REORDERABLE_ID, "node: drag source item is preserved");
    expect_size(scene.drop_targets[drop_targets_before].index, ER_UI_TEST_NODE_RENDER_REORDER_INDEX, "node: drop target index is preserved");
    size_t rects_before_gradient = scene.rect_count;
    size_t transitions_before_gradient = scene.transition_count;
    expect_status(er_ui_node_render(&gradient_card, &scene, face, er_ui_bounds(280.0f, 2930.0f, 220.0f, 90.0f), theme), ER_UI_OK,
                  "node: gradient transition card renders");
    expect_size(scene.transition_count, transitions_before_gradient + ER_UI_TEST_NODE_RENDER_ONE_HIT, "node: transition decorator emits transition");
    expect_size(scene.transitions[transitions_before_gradient].id, ER_UI_TEST_NODE_RENDER_TRANSITION_ID, "node: transition decorator preserves id");
    expect_true(scene.rect_count > rects_before_gradient, "node: gradient card emits rects");
    expect_size(scene.rects[rects_before_gradient + ER_UI_TEST_NODE_RENDER_GRADIENT_RECT_OFFSET].mode, ER_UI_RECT_LINEAR_GRADIENT,
                "node: gradient card emits linear gradient background");

    expect_true(scene.rect_count > 0u, "node: render emits rect geometry");
    expect_true(scene.hit_count > 0u, "node: render emits hit targets");
    expect_true(scene.text_quad_count > 0u, "node: render uses variable font text");
    expect_status(er_ui_node_render(&root, &scene, NULL, er_ui_bounds(0.0f, 0.0f, 320.0f, 160.0f), theme), ER_UI_ERR_INVALID_ARGUMENT,
                  "node: missing variable font is rejected");
    vr_font_face_destroy(face);
  }
  er_ui_scene_destroy(&scene);
}
