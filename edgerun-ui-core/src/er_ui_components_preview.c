#include "er_ui_components_internal.h"

bool er_ui_component_scene_preview_available(const char* slug) {
  return er_ui_component_find_by_slug(slug) != 0;
}

er_ui_status_t er_ui_component_scene_preview_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* slug,
  const er_ui_component_gallery_state_t* state) {
  if (!scene || !font || !slug || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  if (er_ui_component_streq(slug, "accordion")) {
    er_ui_status_t status = er_ui_component_card_emit(scene, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 360.0f), 110.0f), theme);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_push_ascii_text(scene, font, "Is it accessible?", bounds.x + 14.0f, bounds.y + 26.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_push_ascii_text(scene, font, "Yes. It follows the WAI-ARIA design pattern.", bounds.x + 14.0f, bounds.y + 50.0f, theme.colors.muted);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_separator_emit(scene, er_ui_bounds(bounds.x + 12.0f, bounds.y + 64.0f, er_ui_float_min(bounds.w, 360.0f) - 24.0f, 1.0f), theme);
    if (status != ER_UI_OK) return status;
    return er_ui_component_push_ascii_text(scene, font, "Is it styled?", bounds.x + 14.0f, bounds.y + 88.0f, theme.colors.text);
  }
  if (er_ui_component_streq(slug, "alert")) {
    return er_ui_component_alert_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 390.0f), 76.0f), theme, "Heads up",
                                   "You can add components to your app using the CLI.", theme.colors.warning);
  }
  if (er_ui_component_streq(slug, "alert-dialog") || er_ui_component_streq(slug, "dialog")) {
    er_ui_bounds_t card = er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 360.0f), 150.0f);
    er_ui_status_t status = er_ui_component_card_emit(scene, card, theme);
    if (status != ER_UI_OK) return status;
    const char* title = er_ui_component_streq(slug, "alert-dialog") ? "Are you absolutely sure?" : "Edit profile";
    const char* body = er_ui_component_streq(slug, "alert-dialog") ? "This action cannot be undone." : "Make changes to your profile here.";
    status = er_ui_component_push_ascii_text_clipped(scene, font, title, card.x + 18.0f, card.y + 32.0f, card.w - 36.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_push_ascii_text_clipped(scene, font, body, card.x + 18.0f, card.y + 56.0f, card.w - 36.0f, theme.colors.muted);
    if (status != ER_UI_OK) return status;
    float confirm_w = 82.0f;
    float cancel_w = 76.0f;
    float button_y = card.y + card.h - 50.0f;
    float confirm_x = card.x + card.w - 18.0f - confirm_w;
    status = er_ui_component_button_emit(scene, font, er_ui_bounds(confirm_x - 8.0f - cancel_w, button_y, cancel_w, 36.0f), theme, "Cancel",
	                                      ER_UI_COMPONENT_PREVIEW_ALERT_DIALOG_CANCEL_ID, ER_UI_COMPONENT_BUTTON_SECONDARY, ER_UI_COMPONENT_BUTTON_SIZE_SM, true);
    if (status != ER_UI_OK) return status;
    return er_ui_component_button_emit(scene, font, er_ui_bounds(confirm_x, button_y, confirm_w, 36.0f), theme, "Confirm",
	                                    ER_UI_COMPONENT_PREVIEW_ALERT_DIALOG_CONFIRM_ID, ER_UI_COMPONENT_BUTTON_DEFAULT, ER_UI_COMPONENT_BUTTON_SIZE_SM, true);
  }
  if (er_ui_component_streq(slug, "aspect-ratio")) {
    er_ui_bounds_t card = er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 260.0f), 146.0f);
    er_ui_status_t status = er_ui_component_card_emit(scene, card, theme);
    if (status != ER_UI_OK) return status;
    status = er_ui_scene_push_rect(scene, er_ui_rect_fill(card.x + 12.0f, card.y + 12.0f, card.w - 24.0f, card.h - 24.0f, theme.radius.control,
                                                         er_ui_color_with_alpha(theme.colors.row, 0.52f)));
    if (status != ER_UI_OK) return status;
    return er_ui_component_push_ascii_text(scene, font, "16:9", card.x + card.w * 0.45f, card.y + card.h * 0.56f, theme.colors.text);
  }
  if (er_ui_component_streq(slug, "avatar")) {
    er_ui_status_t status = er_ui_component_avatar_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, 42.0f, 42.0f), theme, "CN", theme.colors.accent, true);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_avatar_emit(scene, font, er_ui_bounds(bounds.x + 52.0f, bounds.y, 42.0f, 42.0f), theme, "ER", theme.colors.success, false);
    if (status != ER_UI_OK) return status;
    return er_ui_component_avatar_emit(scene, font, er_ui_bounds(bounds.x + 104.0f, bounds.y, 42.0f, 42.0f), theme, "UI", theme.colors.info, false);
  }
  if (er_ui_component_streq(slug, "badge")) {
    er_ui_status_t status = er_ui_component_badge_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, 82.0f, 26.0f), theme, "Default", ER_UI_COMPONENT_BADGE_DEFAULT);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_badge_emit(scene, font, er_ui_bounds(bounds.x + 92.0f, bounds.y, 96.0f, 26.0f), theme, "Secondary", ER_UI_COMPONENT_BADGE_SECONDARY);
    if (status != ER_UI_OK) return status;
    return er_ui_component_badge_emit(scene, font, er_ui_bounds(bounds.x, bounds.y + 34.0f, 112.0f, 26.0f), theme, "Destructive", ER_UI_COMPONENT_BADGE_DESTRUCTIVE);
  }
  if (er_ui_component_streq(slug, "button")) {
    float gap = 8.0f;
    float default_w = er_ui_float_min(78.0f, bounds.w * 0.30f);
    float secondary_w = er_ui_float_min(104.0f, bounds.w * 0.42f);
    float ghost_w = er_ui_float_max(bounds.w - default_w - secondary_w - gap * 2.0f, 58.0f);
    er_ui_status_t status = er_ui_component_button_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, default_w, 42.0f), theme, "Button",
                                                     ER_UI_COMPONENT_PREVIEW_BUTTON_DEFAULT_ID,
                                                     ER_UI_COMPONENT_BUTTON_DEFAULT, ER_UI_COMPONENT_BUTTON_SIZE_DEFAULT, true);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_button_emit(scene, font, er_ui_bounds(bounds.x + default_w + gap, bounds.y, secondary_w, 42.0f), theme, "Secondary",
	                                      ER_UI_COMPONENT_PREVIEW_BUTTON_SECONDARY_ID, ER_UI_COMPONENT_BUTTON_SECONDARY, ER_UI_COMPONENT_BUTTON_SIZE_DEFAULT, true);
    if (status != ER_UI_OK) return status;
    return er_ui_component_button_emit(scene, font, er_ui_bounds(bounds.x + default_w + secondary_w + gap * 2.0f, bounds.y, ghost_w, 42.0f), theme, "Ghost",
	                                    ER_UI_COMPONENT_PREVIEW_BUTTON_GHOST_ID, ER_UI_COMPONENT_BUTTON_GHOST, ER_UI_COMPONENT_BUTTON_SIZE_DEFAULT, true);
  }
  if (er_ui_component_streq(slug, "breadcrumb")) {
    const char *const labels[] = {"Docs", "UI", "Breadcrumb"};
    return er_ui_component_breadcrumb_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 320.0f), 34.0f), theme, labels,
                                        ER_UI_COMPONENT_ARRAY_COUNT(labels), ER_UI_COMPONENT_PREVIEW_BREADCRUMB_CURRENT_INDEX,
                                        ER_UI_COMPONENT_PREVIEW_BREADCRUMB_ID);
  }
  if (er_ui_component_streq(slug, "button-group")) {
    const char *const labels[] = {"Copy", "Paste", "More"};
    return er_ui_component_tabs_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, 210.0f, 38.0f), theme, labels, ER_UI_COMPONENT_ARRAY_COUNT(labels), 0u,
                                  ER_UI_COMPONENT_PREVIEW_BUTTON_GROUP_ID);
  }
  if (er_ui_component_streq(slug, "calendar") || er_ui_component_streq(slug, "date-picker")) {
    er_ui_status_t status = ER_UI_OK;
    if (er_ui_component_streq(slug, "date-picker")) {
      status = er_ui_component_button_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, 120.0f, 38.0f), theme, "Pick a date", ER_UI_COMPONENT_PREVIEW_DATE_PICKER_ID,
                                        ER_UI_COMPONENT_BUTTON_SECONDARY, ER_UI_COMPONENT_BUTTON_SIZE_SM, true);
      if (status != ER_UI_OK) return status;
      bounds.y += 46.0f;
    }
    er_ui_bounds_t card = er_ui_bounds(bounds.x, bounds.y, 260.0f, 132.0f);
    status = er_ui_component_card_emit(scene, card, theme);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_push_ascii_text(scene, font, "June 2025", card.x + 14.0f, card.y + 26.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    const char *const days[] = {"8", "9", "10", "11", "12", "13", "14"};
    for (size_t i = 0u; i < ER_UI_COMPONENT_ARRAY_COUNT(days); ++i) {
      status = er_ui_component_button_emit(scene, font, er_ui_bounds(card.x + 10.0f + (float)i * 34.0f, card.y + 58.0f, 30.0f, 34.0f), theme, days[i],
                                        ER_UI_COMPONENT_PREVIEW_CALENDAR_DAY_BASE_ID + (uint32_t)i,
                                        i == ER_UI_COMPONENT_PREVIEW_CALENDAR_SELECTED_INDEX ? ER_UI_COMPONENT_BUTTON_SECONDARY : ER_UI_COMPONENT_BUTTON_GHOST,
                                        ER_UI_COMPONENT_BUTTON_SIZE_SM, true);
      if (status != ER_UI_OK) return status;
    }
    return ER_UI_OK;
  }
  if (er_ui_component_streq(slug, "card")) {
    er_ui_status_t status = er_ui_component_card_emit(scene, bounds, theme);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_push_ascii_text(scene, font, "Create project", bounds.x + 16.0f, bounds.y + 28.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    return er_ui_component_push_ascii_text_clipped(scene, font, "Deploy in one click.", bounds.x + 16.0f, bounds.y + 52.0f, bounds.w - 32.0f, theme.colors.muted);
  }
  if (er_ui_component_streq(slug, "carousel")) {
    er_ui_status_t status = ER_UI_OK;
    const char *const labels[] = {"1", "2", "3"};
    const char* const* label_cursor = labels;
    for (size_t i = 0u; i < ER_UI_COMPONENT_ARRAY_COUNT(labels); ++i) {
      const char* label = *label_cursor;
      er_ui_bounds_t card = er_ui_bounds(bounds.x + (float)i * 72.0f, bounds.y, 60.0f, 72.0f);
      status = er_ui_component_card_emit(scene, card, theme);
      if (status != ER_UI_OK) return status;
      status = er_ui_component_push_ascii_text(scene, font, label, card.x + 26.0f, card.y + 42.0f, theme.colors.text);
      if (status != ER_UI_OK) return status;
      label_cursor++;
    }
    return ER_UI_OK;
  }
  if (er_ui_component_streq(slug, "chart")) {
    const char *const labels[] = {"Jan", "Feb", "Mar", "Apr", "May", "Jun"};
    const float values[] = {0.42f, 0.68f, 0.51f, 0.82f, 0.56f, 0.74f};
    _Static_assert(ER_UI_COMPONENT_ARRAY_COUNT(labels) == ER_UI_COMPONENT_ARRAY_COUNT(values), "chart preview arrays must match");
    return er_ui_component_bar_chart_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 360.0f), 160.0f), theme, "Visitors", labels, values,
                                       ER_UI_COMPONENT_ARRAY_COUNT(values), ER_UI_COMPONENT_PREVIEW_CHART_ID, ER_UI_COMPONENT_PREVIEW_CHART_ACTIVE_INDEX);
  }
  if (er_ui_component_streq(slug, "checkbox")) {
    er_ui_status_t status = er_ui_component_checkbox_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, bounds.w, 32.0f), theme, "Accept terms and conditions", true,
                                                       ER_UI_COMPONENT_PREVIEW_CHECKBOX_TERMS_ID);
    if (status != ER_UI_OK) return status;
    return er_ui_component_checkbox_emit(scene, font, er_ui_bounds(bounds.x, bounds.y + 38.0f, bounds.w, 32.0f), theme, "Receive security emails", false,
                                      ER_UI_COMPONENT_PREVIEW_CHECKBOX_EMAILS_ID);
  }
  if (er_ui_component_streq(slug, "context-menu") || er_ui_component_streq(slug, "dropdown-menu")) {
    er_ui_status_t status = er_ui_component_list_row_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 220.0f), 44.0f), theme, "Profile", "Command P",
                                                       ER_UI_COMPONENT_PREVIEW_CONTEXT_PROFILE_ID, false);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_list_row_emit(scene, font, er_ui_bounds(bounds.x, bounds.y + 48.0f, er_ui_float_min(bounds.w, 220.0f), 44.0f), theme, "Billing", "Command B",
                                        ER_UI_COMPONENT_PREVIEW_CONTEXT_BILLING_ID, true);
    if (status != ER_UI_OK) return status;
    return er_ui_component_list_row_emit(scene, font, er_ui_bounds(bounds.x, bounds.y + 96.0f, er_ui_float_min(bounds.w, 220.0f), 44.0f), theme, "Log out", "Shift Command Q",
                                      ER_UI_COMPONENT_PREVIEW_CONTEXT_LOGOUT_ID, false);
  }
  if (er_ui_component_streq(slug, "collapsible")) {
    er_ui_status_t status = er_ui_component_card_emit(scene, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 360.0f), 150.0f), theme);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_push_ascii_text(scene, font, "@peduarte starred 3 repositories", bounds.x + 14.0f, bounds.y + 26.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_list_row_emit(scene, font, er_ui_bounds(bounds.x + 10.0f, bounds.y + 44.0f, 300.0f, 44.0f), theme, "@radix-ui/primitives",
                                        "Open source UI components", ER_UI_COMPONENT_PREVIEW_COLLAPSIBLE_PRIMITIVES_ID, false);
    if (status != ER_UI_OK) return status;
    return er_ui_component_list_row_emit(scene, font, er_ui_bounds(bounds.x + 10.0f, bounds.y + 92.0f, 300.0f, 44.0f), theme, "@radix-ui/colors",
                                      "Beautiful color scales", ER_UI_COMPONENT_PREVIEW_COLLAPSIBLE_COLORS_ID, false);
  }
  if (er_ui_component_streq(slug, "combobox")) {
    er_ui_status_t status = er_ui_component_select_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, 240.0f, 62.0f), theme, "Framework", "Select framework...",
                                                     ER_UI_COMPONENT_PREVIEW_COMBOBOX_SELECT_ID, false);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_field_emit(scene, font, er_ui_bounds(bounds.x, bounds.y + 70.0f, 240.0f, 54.0f), theme, "Search", "Search framework...",
                                     ER_UI_COMPONENT_PREVIEW_COMBOBOX_SEARCH_ID, false);
    if (status != ER_UI_OK) return status;
    return er_ui_component_list_row_emit(scene, font, er_ui_bounds(bounds.x, bounds.y + 130.0f, 240.0f, 44.0f), theme, "Next.js", "selected",
                                      ER_UI_COMPONENT_PREVIEW_COMBOBOX_RESULT_ID, true);
  }
  if (er_ui_component_streq(slug, "command")) {
    return er_ui_component_field_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 300.0f), 58.0f), theme, "Command",
                                   "Type a command or search...", ER_UI_COMPONENT_PREVIEW_COMMAND_ID, false);
  }
  if (er_ui_component_streq(slug, "data-table") || er_ui_component_streq(slug, "table")) {
    const char *const headers[] = {"Invoice", "Status", "Amount"};
    const char *const cells[] = {"INV001", "Paid", "$250.00", "INV002", "Pending", "$150.00"};
    _Static_assert(ER_UI_COMPONENT_ARRAY_COUNT(cells) % ER_UI_COMPONENT_ARRAY_COUNT(headers) == 0u, "table preview cells must fill rows");
    return er_ui_component_table_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 360.0f), 112.0f), theme, headers,
                                   ER_UI_COMPONENT_ARRAY_COUNT(headers), cells, ER_UI_COMPONENT_ARRAY_COUNT(cells) / ER_UI_COMPONENT_ARRAY_COUNT(headers),
                                   ER_UI_COMPONENT_PREVIEW_TABLE_ID);
  }
  if (er_ui_component_streq(slug, "empty")) {
    return er_ui_component_empty_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 280.0f), 120.0f), theme, "No results found",
                                   "Try adjusting your search or filters.");
  }
  if (er_ui_component_streq(slug, "direction")) {
    er_ui_status_t status = er_ui_component_badge_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, 44.0f, 26.0f), theme, "LTR", ER_UI_COMPONENT_BADGE_DEFAULT);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_push_ascii_text(scene, font, "Left to right content", bounds.x + 56.0f, bounds.y + 19.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_push_ascii_text(scene, font, "Right to left content", bounds.x, bounds.y + 56.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    return er_ui_component_badge_emit(scene, font, er_ui_bounds(bounds.x + 160.0f, bounds.y + 36.0f, 44.0f, 26.0f), theme, "RTL", ER_UI_COMPONENT_BADGE_SECONDARY);
  }
  if (er_ui_component_streq(slug, "drawer")) {
    er_ui_bounds_t card = er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 340.0f), 150.0f);
    er_ui_status_t status = er_ui_component_card_emit(scene, card, theme);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_push_ascii_text(scene, font, "Move goal", card.x + 16.0f, card.y + 28.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_push_ascii_text(scene, font, "Set your daily activity target.", card.x + 16.0f, card.y + 52.0f, theme.colors.muted);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_slider_emit(scene, font, er_ui_bounds(card.x + 16.0f, card.y + 70.0f, card.w - 32.0f, 42.0f), theme, "Calories", 0.58f,
                                      ER_UI_COMPONENT_PREVIEW_DRAWER_SLIDER_ID);
    if (status != ER_UI_OK) return status;
    return er_ui_component_button_emit(scene, font, er_ui_bounds(card.x + 16.0f, card.y + 112.0f, 88.0f, 34.0f), theme, "Submit",
                                    ER_UI_COMPONENT_PREVIEW_DRAWER_SUBMIT_ID, ER_UI_COMPONENT_BUTTON_DEFAULT, ER_UI_COMPONENT_BUTTON_SIZE_SM, true);
  }
  if (er_ui_component_streq(slug, "field") || er_ui_component_streq(slug, "input")) {
    return er_ui_component_field_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, bounds.w, 58.0f), theme, "Email", "name@example.com",
                                   ER_UI_COMPONENT_PREVIEW_FIELD_EMAIL_ID, false);
  }
  if (er_ui_component_streq(slug, "hover-card")) {
    er_ui_status_t status = er_ui_component_avatar_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, 42.0f, 42.0f), theme, "ER", theme.colors.accent, false);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_push_ascii_text(scene, font, "ER", bounds.x + 54.0f, bounds.y + 18.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_push_ascii_text(scene, font, "UI infrastructure", bounds.x + 54.0f, bounds.y + 38.0f, theme.colors.muted);
    if (status != ER_UI_OK) return status;
    return er_ui_component_push_ascii_text(scene, font, "User-owned app surfaces with reusable native components.", bounds.x, bounds.y + 72.0f, theme.colors.text);
  }
  if (er_ui_component_streq(slug, "input-group")) {
    er_ui_status_t status = er_ui_component_field_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_max(bounds.w - 92.0f, 96.0f), 58.0f), theme, "URL",
                                                    "https://example.com", ER_UI_COMPONENT_PREVIEW_INPUT_GROUP_FIELD_ID, false);
    if (status != ER_UI_OK) return status;
    return er_ui_component_button_emit(scene, font,
                                    er_ui_bounds(bounds.x + er_ui_float_max(bounds.w - 84.0f, 104.0f), bounds.y + 18.0f, 80.0f,
                                                 ER_UI_COMPONENT_PREVIEW_INPUT_GROUP_BUTTON_H),
                                    theme, "Copy",
                                    ER_UI_COMPONENT_PREVIEW_INPUT_GROUP_BUTTON_ID, ER_UI_COMPONENT_BUTTON_SECONDARY, ER_UI_COMPONENT_BUTTON_SIZE_SM, true);
  }
  if (er_ui_component_streq(slug, "input-otp")) {
    const char *const values[] = {"1", "2", "3", "-", "", "", ""};
    const char* const* value_cursor = values;
    for (size_t i = 0u; i < ER_UI_COMPONENT_ARRAY_COUNT(values); ++i) {
      const char* value = *value_cursor;
      if (er_ui_component_streq(value, "-")) {
        er_ui_status_t status = er_ui_component_push_ascii_text(scene, font, "-", bounds.x + (float)i * 42.0f + 12.0f, bounds.y + 36.0f, theme.colors.muted);
        if (status != ER_UI_OK) return status;
        value_cursor++;
        continue;
      }
      er_ui_status_t status = er_ui_component_field_emit(scene, font, er_ui_bounds(bounds.x + (float)i * 42.0f, bounds.y, 36.0f, 52.0f), theme, "", value,
                                                      ER_UI_COMPONENT_PREVIEW_INPUT_OTP_BASE_ID + (uint32_t)i, false);
      if (status != ER_UI_OK) return status;
      value_cursor++;
    }
    return ER_UI_OK;
  }
  if (er_ui_component_streq(slug, "item")) {
    return er_ui_component_list_row_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 280.0f), 52.0f), theme, "Payment successful",
                                      "Stripe payout completed", ER_UI_COMPONENT_PREVIEW_ITEM_ID, false);
  }
  if (er_ui_component_streq(slug, "kbd")) {
    er_ui_status_t status = er_ui_component_badge_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, 34.0f, 28.0f), theme, "Cmd", ER_UI_COMPONENT_BADGE_SECONDARY);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_badge_emit(scene, font, er_ui_bounds(bounds.x + 42.0f, bounds.y, 28.0f, 28.0f), theme, "K", ER_UI_COMPONENT_BADGE_SECONDARY);
    if (status != ER_UI_OK) return status;
    return er_ui_component_push_ascii_text(scene, font, "Command menu", bounds.x + 84.0f, bounds.y + 20.0f, theme.colors.text);
  }
  if (er_ui_component_streq(slug, "label")) {
    er_ui_status_t status = er_ui_component_push_ascii_text(scene, font, "Email", bounds.x, bounds.y + 16.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    return er_ui_component_field_emit(scene, font, er_ui_bounds(bounds.x, bounds.y + 24.0f, er_ui_float_min(bounds.w, 260.0f), 58.0f), theme, "", "name@example.com",
                                   ER_UI_COMPONENT_PREVIEW_LABEL_FIELD_ID, false);
  }
  if (er_ui_component_streq(slug, "menubar")) {
    const char *const labels[] = {"File", "Edit", "View", "Profiles"};
    return er_ui_component_tabs_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 360.0f), 38.0f), theme, labels,
                                  ER_UI_COMPONENT_ARRAY_COUNT(labels), 0u, ER_UI_COMPONENT_PREVIEW_MENUBAR_ID);
  }
  if (er_ui_component_streq(slug, "native-select") || er_ui_component_streq(slug, "select")) {
    uint32_t id = ER_UI_COMPONENT_SELECT_TICKER_ID;
    bool open = er_ui_component_gallery_select_open(state, id);
    return er_ui_component_select_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, bounds.w, 62.0f), theme, "Framework", "Next.js", id, open);
  }
  if (er_ui_component_streq(slug, "pagination")) {
    er_ui_status_t status = er_ui_component_button_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, 90.0f, 40.0f), theme, "Previous",
                                                     ER_UI_COMPONENT_PREVIEW_PAGINATION_PREVIOUS_ID,
                                                     ER_UI_COMPONENT_BUTTON_GHOST, ER_UI_COMPONENT_BUTTON_SIZE_DEFAULT, false);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_button_emit(scene, font, er_ui_bounds(bounds.x + 96.0f, bounds.y, 42.0f, 40.0f), theme, "1",
                                      ER_UI_COMPONENT_PREVIEW_PAGINATION_CURRENT_ID,
                                      ER_UI_COMPONENT_BUTTON_SECONDARY, ER_UI_COMPONENT_BUTTON_SIZE_DEFAULT, true);
    if (status != ER_UI_OK) return status;
    return er_ui_component_button_emit(scene, font, er_ui_bounds(bounds.x + 144.0f, bounds.y, 68.0f, 40.0f), theme, "Next",
                                    ER_UI_COMPONENT_PREVIEW_PAGINATION_NEXT_ID,
                                    ER_UI_COMPONENT_BUTTON_GHOST, ER_UI_COMPONENT_BUTTON_SIZE_DEFAULT, true);
  }
  if (er_ui_component_streq(slug, "navigation-menu")) {
    const char *const labels[] = {"Getting started", "Components", "Docs"};
    er_ui_status_t status = er_ui_component_tabs_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 360.0f), 38.0f), theme, labels,
                                                   ER_UI_COMPONENT_ARRAY_COUNT(labels), 0u, ER_UI_COMPONENT_PREVIEW_NAVIGATION_TABS_ID);
    if (status != ER_UI_OK) return status;
    return er_ui_component_list_row_emit(scene, font, er_ui_bounds(bounds.x, bounds.y + 50.0f, er_ui_float_min(bounds.w, 320.0f), 52.0f), theme, "Installation",
                                      "Add components to your app", ER_UI_COMPONENT_PREVIEW_NAVIGATION_INSTALL_ID, false);
  }
  if (er_ui_component_streq(slug, "popover")) {
    er_ui_status_t status = er_ui_component_button_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, 136.0f, 38.0f), theme, "Open popover",
                                                     ER_UI_COMPONENT_PREVIEW_POPOVER_BUTTON_ID, ER_UI_COMPONENT_BUTTON_SECONDARY, ER_UI_COMPONENT_BUTTON_SIZE_SM, true);
    if (status != ER_UI_OK) return status;
    er_ui_bounds_t card = er_ui_bounds(bounds.x, bounds.y + 48.0f, er_ui_float_min(bounds.w, 300.0f), 120.0f);
    status = er_ui_component_card_emit(scene, card, theme);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_push_ascii_text(scene, font, "Dimensions", card.x + 14.0f, card.y + 26.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_push_ascii_text(scene, font, "Set the dimensions for the layer.", card.x + 14.0f, card.y + 48.0f, theme.colors.muted);
    if (status != ER_UI_OK) return status;
    return er_ui_component_field_emit(scene, font, er_ui_bounds(card.x + 14.0f, card.y + 58.0f, card.w - 28.0f, 54.0f), theme, "Width", "100%",
                                   ER_UI_COMPONENT_PREVIEW_POPOVER_FIELD_ID, false);
  }
  if (er_ui_component_streq(slug, "progress")) {
    return er_ui_component_progress_emit(scene, er_ui_bounds(bounds.x, bounds.y + 20.0f, bounds.w, 8.0f), theme, 0.66f);
  }
  if (er_ui_component_streq(slug, "radio-group")) {
    er_ui_status_t status = er_ui_component_radio_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, bounds.w, 30.0f), theme, "Default", true,
                                                    ER_UI_COMPONENT_PREVIEW_RADIO_DEFAULT_ID);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_radio_emit(scene, font, er_ui_bounds(bounds.x, bounds.y + 34.0f, bounds.w, 30.0f), theme, "Comfortable", false,
                                     ER_UI_COMPONENT_PREVIEW_RADIO_COMFORTABLE_ID);
    if (status != ER_UI_OK) return status;
    return er_ui_component_radio_emit(scene, font, er_ui_bounds(bounds.x, bounds.y + 68.0f, bounds.w, 30.0f), theme, "Compact", false,
                                   ER_UI_COMPONENT_PREVIEW_RADIO_COMPACT_ID);
  }
  if (er_ui_component_streq(slug, "resizable")) {
    er_ui_bounds_t first = er_ui_bounds(bounds.x, bounds.y, 90.0f, 92.0f);
    er_ui_bounds_t second = er_ui_bounds(bounds.x + 100.0f, bounds.y, 120.0f, 42.0f);
    er_ui_bounds_t third = er_ui_bounds(bounds.x + 100.0f, bounds.y + 50.0f, 120.0f, 42.0f);
    er_ui_status_t status = er_ui_component_card_emit(scene, first, theme);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_push_ascii_text(scene, font, "One", first.x + 14.0f, first.y + 28.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_card_emit(scene, second, theme);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_push_ascii_text(scene, font, "Two", second.x + 14.0f, second.y + 28.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_card_emit(scene, third, theme);
    if (status != ER_UI_OK) return status;
    return er_ui_component_push_ascii_text(scene, font, "Three", third.x + 14.0f, third.y + 28.0f, theme.colors.text);
  }
  if (er_ui_component_streq(slug, "scroll-area")) {
    er_ui_status_t status = er_ui_component_list_row_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 260.0f), 44.0f), theme, "v1.0.0",
                                                       "Initial release", ER_UI_COMPONENT_PREVIEW_SCROLL_INITIAL_ID, false);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_list_row_emit(scene, font, er_ui_bounds(bounds.x, bounds.y + 48.0f, er_ui_float_min(bounds.w, 260.0f), 44.0f), theme, "v1.1.0",
                                        "Component updates", ER_UI_COMPONENT_PREVIEW_SCROLL_UPDATES_ID, false);
    if (status != ER_UI_OK) return status;
    return er_ui_component_list_row_emit(scene, font, er_ui_bounds(bounds.x, bounds.y + 96.0f, er_ui_float_min(bounds.w, 260.0f), 44.0f), theme, "v1.2.0",
                                      "Preset builder", ER_UI_COMPONENT_PREVIEW_SCROLL_PRESET_ID, false);
  }
  if (er_ui_component_streq(slug, "separator")) {
    er_ui_status_t status = er_ui_component_push_ascii_text(scene, font, "Radix Primitives", bounds.x, bounds.y + 12.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_separator_emit(scene, er_ui_bounds(bounds.x, bounds.y + 28.0f, bounds.w, 1.0f), theme);
    if (status != ER_UI_OK) return status;
    return er_ui_component_push_ascii_text(scene, font, "Styled with EdgeRun UI tokens", bounds.x, bounds.y + 52.0f, theme.colors.muted);
  }
  if (er_ui_component_streq(slug, "sheet")) {
    er_ui_bounds_t card = er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 340.0f), 166.0f);
    er_ui_status_t status = er_ui_component_card_emit(scene, card, theme);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_push_ascii_text(scene, font, "Edit profile", card.x + 16.0f, card.y + 28.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_push_ascii_text(scene, font, "Make changes to your profile here.", card.x + 16.0f, card.y + 52.0f, theme.colors.muted);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_field_emit(scene, font, er_ui_bounds(card.x + 16.0f, card.y + 62.0f, card.w - 32.0f, 58.0f), theme, "Name", "EdgeRun",
                                     ER_UI_COMPONENT_PREVIEW_SHEET_FIELD_ID, false);
    if (status != ER_UI_OK) return status;
    return er_ui_component_button_emit(scene, font, er_ui_bounds(card.x + 16.0f, card.y + 124.0f, 120.0f, 36.0f), theme, "Save changes",
                                    ER_UI_COMPONENT_PREVIEW_SHEET_SAVE_ID, ER_UI_COMPONENT_BUTTON_DEFAULT, ER_UI_COMPONENT_BUTTON_SIZE_SM, true);
  }
  if (er_ui_component_streq(slug, "sidebar")) {
    er_ui_bounds_t side = er_ui_bounds(bounds.x, bounds.y, 150.0f, 154.0f);
    er_ui_status_t status = er_ui_component_card_emit(scene, side, theme);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_push_ascii_text(scene, font, "App", side.x + 12.0f, side.y + 24.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_list_row_emit(scene, font, er_ui_bounds(side.x + 8.0f, side.y + 40.0f, side.w - 16.0f, 34.0f), theme, "Dashboard", "",
                                        ER_UI_COMPONENT_PREVIEW_SIDEBAR_DASHBOARD_ID, true);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_list_row_emit(scene, font, er_ui_bounds(side.x + 8.0f, side.y + 78.0f, side.w - 16.0f, 34.0f), theme, "Transactions", "",
                                        ER_UI_COMPONENT_PREVIEW_SIDEBAR_TRANSACTIONS_ID, false);
    if (status != ER_UI_OK) return status;
    er_ui_bounds_t main = er_ui_bounds(bounds.x + 162.0f, bounds.y, er_ui_float_min(bounds.w - 170.0f, 220.0f), 154.0f);
    status = er_ui_component_card_emit(scene, main, theme);
    if (status != ER_UI_OK) return status;
    return er_ui_component_push_ascii_text(scene, font, "Dashboard", main.x + 16.0f, main.y + 28.0f, theme.colors.text);
  }
  if (er_ui_component_streq(slug, "skeleton")) {
    er_ui_status_t status = er_ui_component_skeleton_emit(scene, er_ui_bounds(bounds.x, bounds.y, bounds.w, 18.0f), theme);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_skeleton_emit(scene, er_ui_bounds(bounds.x, bounds.y + 28.0f, bounds.w * 0.66f, 18.0f), theme);
    if (status != ER_UI_OK) return status;
    return er_ui_component_skeleton_emit(scene, er_ui_bounds(bounds.x, bounds.y + 56.0f, bounds.w * 0.50f, 18.0f), theme);
  }
  if (er_ui_component_streq(slug, "slider")) {
    float value = er_ui_component_gallery_slider(state, ER_UI_COMPONENT_PREVIEW_SLIDER_ID, 0.42f);
    return er_ui_component_slider_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, bounds.w, 48.0f), theme, "Volume", value, ER_UI_COMPONENT_PREVIEW_SLIDER_ID);
  }
  if (er_ui_component_streq(slug, "switch")) {
    er_ui_status_t status = er_ui_component_switch_emit(scene, er_ui_bounds(bounds.x, bounds.y, 44.0f, 24.0f), theme, true, ER_UI_COMPONENT_PREVIEW_SWITCH_ID);
    if (status != ER_UI_OK) return status;
    return er_ui_component_push_ascii_text(scene, font, "Airplane mode", bounds.x + 56.0f, bounds.y + 18.0f, theme.colors.text);
  }
  if (er_ui_component_streq(slug, "spinner")) {
    er_ui_status_t status = er_ui_component_spinner_emit(scene, er_ui_bounds(bounds.x, bounds.y, 28.0f, 28.0f), theme);
    if (status != ER_UI_OK) return status;
    return er_ui_component_push_ascii_text(scene, font, "Loading", bounds.x + 40.0f, bounds.y + 21.0f, theme.shadcn.colors.muted_foreground);
  }
  if (er_ui_component_streq(slug, "sonner")) {
    er_ui_status_t status = er_ui_component_toast_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 260.0f), 48.0f), theme, "Event has been created",
                                                    theme.colors.success);
    if (status != ER_UI_OK) return status;
    return er_ui_component_toast_emit(scene, font, er_ui_bounds(bounds.x, bounds.y + 56.0f, er_ui_float_min(bounds.w, 260.0f), 48.0f), theme, "Upload failed",
                                   theme.colors.danger);
  }
  if (er_ui_component_streq(slug, "tabs")) {
    const char *const labels[] = {"Account", "Password", "Settings"};
    return er_ui_component_tabs_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 330.0f), 38.0f), theme, labels,
                                  ER_UI_COMPONENT_ARRAY_COUNT(labels), 0u, ER_UI_COMPONENT_PREVIEW_TABS_ID);
  }
  if (er_ui_component_streq(slug, "textarea")) {
    return er_ui_component_field_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, bounds.w, 84.0f), theme, "Message", "Type your message here.",
                                   ER_UI_COMPONENT_PREVIEW_TEXTAREA_ID, true);
  }
  if (er_ui_component_streq(slug, "toast")) {
    return er_ui_component_toast_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 260.0f), 48.0f), theme, "Scheduled: Catch up",
                                   theme.colors.accent);
  }
  if (er_ui_component_streq(slug, "toggle")) {
    return er_ui_component_switch_emit(scene, er_ui_bounds(bounds.x, bounds.y, 44.0f, 24.0f), theme, true, ER_UI_COMPONENT_PREVIEW_TOGGLE_ID);
  }
  if (er_ui_component_streq(slug, "toggle-group")) {
    const char *const labels[] = {"B", "I", "U"};
    return er_ui_component_tabs_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, 126.0f, 38.0f), theme, labels,
                                  ER_UI_COMPONENT_ARRAY_COUNT(labels), 0u, ER_UI_COMPONENT_PREVIEW_TOGGLE_GROUP_ID);
  }
  if (er_ui_component_streq(slug, "tooltip")) {
    er_ui_status_t status = er_ui_component_button_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, 80.0f, 38.0f), theme, "Hover",
                                                     ER_UI_COMPONENT_PREVIEW_TOOLTIP_ID, ER_UI_COMPONENT_BUTTON_SECONDARY, ER_UI_COMPONENT_BUTTON_SIZE_SM, true);
    if (status != ER_UI_OK) return status;
    er_ui_bounds_t tip = er_ui_bounds(bounds.x + 94.0f, bounds.y + 2.0f, 112.0f, 34.0f);
    status = er_ui_scene_push_rect(scene, er_ui_rect_fill(tip.x, tip.y, tip.w, tip.h, theme.radius.control, er_ui_color_with_alpha(theme.colors.panel, 0.96f)));
    if (status != ER_UI_OK) return status;
    status = er_ui_scene_push_rect(scene, er_ui_rect_border(tip.x, tip.y, tip.w, tip.h, theme.radius.control, er_ui_color_with_alpha(theme.colors.border, 0.42f)));
    if (status != ER_UI_OK) return status;
    return er_ui_component_push_ascii_text(scene, font, "Add to library", tip.x + 10.0f, tip.y + 22.0f, theme.colors.text);
  }
  return ER_UI_ERR_INVALID_ARGUMENT;
}

static er_ui_status_t er_ui_component_showcase_card_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const er_ui_component_spec_t* spec,
  const er_ui_component_spec_t* selected,
  const er_ui_component_gallery_state_t* state,
  uint32_t id) {
  if (!scene || !font || !spec || !selected || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_LIST_ROW, id, bounds.x, bounds.y, bounds.w, bounds.h));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, theme.shadcn.radius.xl,
                                                       er_ui_color_with_alpha(theme.shadcn.colors.card, 1.0f)));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_border(bounds.x, bounds.y, bounds.w, bounds.h, theme.shadcn.radius.xl,
                                                         er_ui_color_with_alpha(theme.shadcn.colors.border, 1.8f)));
  if (status != ER_UI_OK) return status;
  if (er_ui_component_streq(spec->slug, selected->slug)) {
    status = er_ui_scene_push_rect(scene, er_ui_rect_border(bounds.x, bounds.y, bounds.w, bounds.h, theme.shadcn.radius.xl,
                                                           er_ui_color_with_alpha(theme.shadcn.colors.ring, 0.72f)));
    if (status != ER_UI_OK) return status;
  }
  er_ui_bounds_t content = er_ui_bounds_inset(bounds, ER_UI_COMPONENT_SHOWCASE_CARD_PAD, ER_UI_COMPONENT_SHOWCASE_CARD_PAD);
  status = er_ui_component_push_ascii_text_clipped(scene, font, spec->name, content.x, content.y + 16.0f, content.w, theme.colors.text);
  if (status != ER_UI_OK) return status;
  if (content.h >= ER_UI_COMPONENT_SHOWCASE_CARD_DETAIL_MIN_H) {
    status = er_ui_component_push_ascii_text_clipped(scene, font, er_ui_component_category_label(spec->category),
                                                     content.x, content.y + 34.0f, content.w, theme.colors.muted);
    if (status != ER_UI_OK) return status;
  }
  er_ui_bounds_t preview = er_ui_bounds(content.x,
                                        content.y + ER_UI_COMPONENT_SHOWCASE_CARD_HEADER_H,
                                        content.w,
                                        content.h - ER_UI_COMPONENT_SHOWCASE_CARD_HEADER_H);
  if (preview.h < ER_UI_COMPONENT_SHOWCASE_CARD_PREVIEW_MIN_H || preview.w < ER_UI_COMPONENT_SHOWCASE_CARD_PREVIEW_MIN_W) {
    status = er_ui_scene_push_rect(scene, er_ui_rect_fill(preview.x,
                                                         preview.y + er_ui_float_max(preview.h * 0.20f, 0.0f),
                                                         er_ui_float_min(preview.w, 72.0f),
                                                         er_ui_float_max(preview.h * 0.16f, 3.0f),
                                                         theme.shadcn.radius.sm,
                                                         theme.shadcn.colors.muted));
    if (status != ER_UI_OK) return status;
    status = er_ui_scene_push_rect(scene, er_ui_rect_fill(preview.x,
                                                         preview.y + er_ui_float_max(preview.h * 0.48f, 0.0f),
                                                         er_ui_float_min(preview.w * 0.74f, 96.0f),
                                                         er_ui_float_max(preview.h * 0.16f, 3.0f),
                                                         theme.shadcn.radius.sm,
                                                         er_ui_color_with_alpha(theme.shadcn.colors.muted, 0.72f)));
    if (status != ER_UI_OK) return status;
    return er_ui_component_badge_emit(scene, font,
                                      er_ui_bounds(content.x, bounds.y + bounds.h - 30.0f, er_ui_float_min(content.w, 88.0f), 22.0f),
                                      theme,
                                      er_ui_component_status_label(spec->status),
                                      ER_UI_COMPONENT_BADGE_SECONDARY);
  }
  bool pushed = false;
  status = er_ui_scene_push_clip(scene, er_ui_clip(preview.x, preview.y, preview.w, preview.h), &pushed);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_scene_preview_emit(scene, font, preview, theme, spec->slug, state);
  if (pushed) er_ui_scene_pop_clip(scene);
  return status;
}

static float er_ui_component_showcase_card_height(const er_ui_component_spec_t* spec) {
  if (!spec) return ER_UI_COMPONENT_SHOWCASE_CARD_H;
  if (er_ui_component_streq(spec->slug, "card") ||
      er_ui_component_streq(spec->slug, "chart") ||
      er_ui_component_streq(spec->slug, "data-table") ||
      er_ui_component_streq(spec->slug, "table") ||
      er_ui_component_streq(spec->slug, "calendar") ||
      er_ui_component_streq(spec->slug, "date-picker") ||
      er_ui_component_streq(spec->slug, "form") ||
      er_ui_component_streq(spec->slug, "sheet") ||
      er_ui_component_streq(spec->slug, "dialog") ||
      er_ui_component_streq(spec->slug, "alert-dialog") ||
      er_ui_component_streq(spec->slug, "combobox") ||
      er_ui_component_streq(spec->slug, "navigation-menu")) {
    return 330.0f;
  }
  if (er_ui_component_streq(spec->slug, "accordion") ||
      er_ui_component_streq(spec->slug, "collapsible") ||
      er_ui_component_streq(spec->slug, "context-menu") ||
      er_ui_component_streq(spec->slug, "dropdown-menu") ||
      er_ui_component_streq(spec->slug, "popover") ||
      er_ui_component_streq(spec->slug, "radio-group") ||
      er_ui_component_streq(spec->slug, "scroll-area") ||
      er_ui_component_streq(spec->slug, "tabs") ||
      er_ui_component_streq(spec->slug, "textarea")) {
    return 286.0f;
  }
  if (er_ui_component_streq(spec->slug, "button") ||
      er_ui_component_streq(spec->slug, "button-group") ||
      er_ui_component_streq(spec->slug, "badge") ||
      er_ui_component_streq(spec->slug, "avatar") ||
      er_ui_component_streq(spec->slug, "separator") ||
      er_ui_component_streq(spec->slug, "skeleton") ||
      er_ui_component_streq(spec->slug, "spinner") ||
      er_ui_component_streq(spec->slug, "switch") ||
      er_ui_component_streq(spec->slug, "toggle") ||
      er_ui_component_streq(spec->slug, "toggle-group")) {
    return 210.0f;
  }
  return ER_UI_COMPONENT_SHOWCASE_CARD_H;
}

static size_t er_ui_component_showcase_column_count(er_ui_bounds_t bounds) {
  size_t columns = (size_t)((bounds.w + ER_UI_COMPONENT_SHOWCASE_GRID_GAP) /
                            (ER_UI_COMPONENT_SHOWCASE_GRID_MIN_CARD_W + ER_UI_COMPONENT_SHOWCASE_GRID_GAP));
  if (columns < 1u) columns = 1u;
  if (columns > ER_UI_COMPONENT_SHOWCASE_GRID_MAX_COLUMNS) columns = ER_UI_COMPONENT_SHOWCASE_GRID_MAX_COLUMNS;
  return columns;
}

static er_ui_bounds_t er_ui_component_showcase_masonry_cell(
  er_ui_bounds_t content,
  const float* column_y,
  size_t column,
  size_t column_count,
  float height) {
  float gap_total = ER_UI_COMPONENT_SHOWCASE_GRID_GAP * (float)(column_count - 1u);
  float card_w = (content.w - gap_total) / (float)column_count;
  return er_ui_bounds(content.x + (card_w + ER_UI_COMPONENT_SHOWCASE_GRID_GAP) * (float)column,
                      column_y[column],
                      card_w,
                      height);
}

er_ui_status_t er_ui_component_showcase_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* selected_slug,
  const er_ui_component_gallery_state_t* state) {
  if (!scene || !font || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  const er_ui_component_spec_t* selected = er_ui_component_find_by_slug(selected_slug ? selected_slug : "button");
  if (!selected) selected = er_ui_component_find_by_slug("button");
  if (!selected) return ER_UI_ERR_INVALID_ARGUMENT;

  er_ui_status_t status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, 0.0f, theme.colors.bg));
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t grid_bounds = er_ui_bounds_inset(bounds, ER_UI_COMPONENT_SHOWCASE_GRID_GAP, ER_UI_COMPONENT_SHOWCASE_GRID_GAP);
  size_t columns = er_ui_component_showcase_column_count(grid_bounds);
  float measure_y[ER_UI_COMPONENT_SHOWCASE_GRID_MAX_COLUMNS] = {0};
  for (size_t i = 0u; i < columns; ++i) measure_y[i] = grid_bounds.y;
  for (size_t i = 0u; i < er_ui_component_count(); ++i) {
    const er_ui_component_spec_t* spec = er_ui_component_at(i);
    size_t column = 0u;
    for (size_t j = 1u; j < columns; ++j) {
      if (measure_y[j] < measure_y[column]) column = j;
    }
    measure_y[column] += er_ui_component_showcase_card_height(spec) + ER_UI_COMPONENT_SHOWCASE_GRID_GAP;
  }
  float content_bottom = measure_y[0u];
  for (size_t i = 1u; i < columns; ++i) {
    if (measure_y[i] > content_bottom) content_bottom = measure_y[i];
  }
  float content_h = er_ui_float_max(content_bottom - grid_bounds.y - ER_UI_COMPONENT_SHOWCASE_GRID_GAP, 1.0f);
  er_ui_scroll_viewport_t viewport = er_ui_scroll_viewport(grid_bounds,
                                                           content_h,
                                                           0.0f,
                                                           ER_UI_COMPONENT_SHOWCASE_SCROLL_THUMB_MIN_H);
  status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_SCROLL_AREA, ER_UI_COMPONENT_SHOWCASE_SCROLL_ID,
                                                 viewport.viewport.x, viewport.viewport.y,
                                                 viewport.viewport.w, viewport.viewport.h));
  if (status != ER_UI_OK) return status;
  float column_y[ER_UI_COMPONENT_SHOWCASE_GRID_MAX_COLUMNS] = {0};
  for (size_t i = 0u; i < columns; ++i) column_y[i] = viewport.content.y;
  bool pushed = false;
  status = er_ui_scene_push_clip(scene, er_ui_clip(viewport.viewport.x, viewport.viewport.y, viewport.viewport.w, viewport.viewport.h), &pushed);
  if (status != ER_UI_OK) return status;
  for (size_t i = 0u; i < er_ui_component_count(); ++i) {
    const er_ui_component_spec_t* spec = er_ui_component_at(i);
    if (!spec) continue;
    size_t column = 0u;
    for (size_t j = 1u; j < columns; ++j) {
      if (column_y[j] < column_y[column]) column = j;
    }
    float card_h = er_ui_component_showcase_card_height(spec);
    er_ui_bounds_t card = er_ui_component_showcase_masonry_cell(viewport.content, column_y, column, columns, card_h);
    column_y[column] += card_h + ER_UI_COMPONENT_SHOWCASE_GRID_GAP;
    if (card.y >= viewport.viewport.y + viewport.viewport.h || card.y + card.h <= viewport.viewport.y) continue;
    status = er_ui_component_showcase_card_emit(scene,
                                                font,
                                                card,
                                                theme,
                                                spec,
                                                selected,
                                                state,
                                                ER_UI_COMPONENT_SHOWCASE_ROW_BASE_ID + (uint32_t)i);
    if (status != ER_UI_OK) break;
  }
  if (pushed) er_ui_scene_pop_clip(scene);
  if (status != ER_UI_OK) return status;
  if (viewport.scrollable) {
    status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_SCROLLBAR, ER_UI_COMPONENT_SHOWCASE_SCROLL_ID,
                                                   viewport.hit.x, viewport.hit.y, viewport.hit.w, viewport.hit.h));
    if (status != ER_UI_OK) return status;
    status = er_ui_scene_push_rect(scene, er_ui_rect_fill(viewport.track.x, viewport.track.y, viewport.track.w, viewport.track.h,
                                                         viewport.track.w * 0.5f, er_ui_color_with_alpha(theme.shadcn.colors.border, 0.64f)));
    if (status != ER_UI_OK) return status;
    return er_ui_scene_push_rect(scene, er_ui_rect_fill(viewport.thumb.x, viewport.thumb.y, viewport.thumb.w, viewport.thumb.h,
                                                       viewport.thumb.w * 0.5f, theme.shadcn.colors.muted_foreground));
  }
  return status;
}
