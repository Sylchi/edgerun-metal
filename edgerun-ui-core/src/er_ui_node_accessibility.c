#include "er_ui_node_internal.h"

const char* er_ui_a11y_role_label(er_ui_a11y_role_t role) {
  switch (role) {
    case ER_UI_A11Y_GROUP: return "group";
    case ER_UI_A11Y_TEXT: return "text";
    case ER_UI_A11Y_BUTTON: return "button";
    case ER_UI_A11Y_CHECKBOX: return "checkbox";
    case ER_UI_A11Y_RADIO: return "radio";
    case ER_UI_A11Y_TEXTBOX: return "textbox";
    case ER_UI_A11Y_COMBOBOX: return "combobox";
    case ER_UI_A11Y_DIALOG: return "dialog";
    case ER_UI_A11Y_TOOLTIP: return "tooltip";
    case ER_UI_A11Y_STATUS: return "status";
    case ER_UI_A11Y_PROGRESSBAR: return "progressbar";
    case ER_UI_A11Y_TABLE: return "table";
    case ER_UI_A11Y_ROW: return "row";
    case ER_UI_A11Y_CELL: return "cell";
    case ER_UI_A11Y_TAB_LIST: return "tab-list";
    case ER_UI_A11Y_TAB: return "tab";
    case ER_UI_A11Y_MENU_ITEM: return "menu-item";
    case ER_UI_A11Y_LIST_ITEM: return "list-item";
    case ER_UI_A11Y_NAVIGATION: return "navigation";
    case ER_UI_A11Y_SEPARATOR: return "separator";
    case ER_UI_A11Y_IMAGE: return "image";
    case ER_UI_A11Y_SLIDER: return "slider";
    case ER_UI_A11Y_GENERIC:
    default: return "generic";
  }
}

static er_ui_a11y_node_t er_ui_a11y_base(er_ui_a11y_role_t role, const char* label, bool has_id, uint32_t id) {
  er_ui_a11y_node_t out = {0};
  out.role = role;
  out.label = label ? label : "";
  out.value = "";
  out.has_id = has_id;
  out.id = id;
  return out;
}

static void er_ui_a11y_set_value(er_ui_a11y_node_t* out, const char* value) {
  if (!out) return;
  out->value = value ? value : "";
  out->states |= ER_UI_A11Y_STATE_HAS_VALUE;
}

static er_ui_status_t er_ui_node_menu_item_accessibility(const er_ui_node_t* node, size_t child_index, er_ui_a11y_node_t* out_a11y) {
  if (!node || !out_a11y || !node->labels || child_index >= node->label_count) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_MENU_ITEM, node->labels[child_index], true, node->id + (uint32_t)child_index);
  if (child_index == node->selected) out.states |= ER_UI_A11Y_STATE_SELECTED;
  if (node->cells) er_ui_a11y_set_value(&out, node->cells[child_index]);
  *out_a11y = out;
  return ER_UI_OK;
}

const char* er_ui_component_chat_role_label(er_ui_component_chat_role_t role) {
  switch (role) {
    case ER_UI_COMPONENT_CHAT_ROLE_USER: return "user";
    case ER_UI_COMPONENT_CHAT_ROLE_ASSISTANT: return "assistant";
    case ER_UI_COMPONENT_CHAT_ROLE_REASONING: return "reasoning";
    case ER_UI_COMPONENT_CHAT_ROLE_DIFF: return "diff";
    case ER_UI_COMPONENT_CHAT_ROLE_TOOL_RUNNING: return "tool running";
    case ER_UI_COMPONENT_CHAT_ROLE_TOOL_SUCCESS: return "tool ok";
    case ER_UI_COMPONENT_CHAT_ROLE_TOOL_ERROR: return "tool failed";
    case ER_UI_COMPONENT_CHAT_ROLE_ERROR: return "error";
    default: return "assistant";
  }
}

er_ui_component_badge_variant_t er_ui_component_chat_role_badge(er_ui_component_chat_role_t role) {
  switch (role) {
    case ER_UI_COMPONENT_CHAT_ROLE_TOOL_ERROR:
    case ER_UI_COMPONENT_CHAT_ROLE_ERROR: return ER_UI_COMPONENT_BADGE_DESTRUCTIVE;
    case ER_UI_COMPONENT_CHAT_ROLE_TOOL_RUNNING: return ER_UI_COMPONENT_BADGE_DEFAULT;
    case ER_UI_COMPONENT_CHAT_ROLE_DIFF:
    case ER_UI_COMPONENT_CHAT_ROLE_REASONING:
    case ER_UI_COMPONENT_CHAT_ROLE_TOOL_SUCCESS: return ER_UI_COMPONENT_BADGE_SECONDARY;
    case ER_UI_COMPONENT_CHAT_ROLE_USER:
    case ER_UI_COMPONENT_CHAT_ROLE_ASSISTANT:
    default: return ER_UI_COMPONENT_BADGE_OUTLINE;
  }
}

er_ui_icon_t er_ui_component_chat_role_icon(er_ui_component_chat_role_t role) {
  switch (role) {
    case ER_UI_COMPONENT_CHAT_ROLE_USER: return ER_UI_ICON_USER;
    case ER_UI_COMPONENT_CHAT_ROLE_ASSISTANT: return ER_UI_ICON_CHAT;
    case ER_UI_COMPONENT_CHAT_ROLE_REASONING: return ER_UI_ICON_SPARKLES;
    case ER_UI_COMPONENT_CHAT_ROLE_DIFF: return ER_UI_ICON_FILE;
    case ER_UI_COMPONENT_CHAT_ROLE_TOOL_RUNNING: return ER_UI_ICON_TERMINAL;
    case ER_UI_COMPONENT_CHAT_ROLE_TOOL_SUCCESS: return ER_UI_ICON_CHECK;
    case ER_UI_COMPONENT_CHAT_ROLE_TOOL_ERROR:
    case ER_UI_COMPONENT_CHAT_ROLE_ERROR: return ER_UI_ICON_WARNING;
    default: return ER_UI_ICON_CHAT;
  }
}

bool er_ui_component_chat_role_timeline(er_ui_component_chat_role_t role) {
  return role == ER_UI_COMPONENT_CHAT_ROLE_REASONING ||
         role == ER_UI_COMPONENT_CHAT_ROLE_TOOL_RUNNING ||
         role == ER_UI_COMPONENT_CHAT_ROLE_TOOL_SUCCESS ||
         role == ER_UI_COMPONENT_CHAT_ROLE_TOOL_ERROR ||
         role == ER_UI_COMPONENT_CHAT_ROLE_ERROR;
}

er_ui_status_t er_ui_node_accessibility(const er_ui_node_t* node, er_ui_a11y_node_t* out_a11y) {
  if (!node || !out_a11y) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_GENERIC, "", false, 0u);
  switch (node->kind) {
    case ER_UI_NODE_ROW:
    case ER_UI_NODE_COLUMN:
    case ER_UI_NODE_GRID:
    case ER_UI_NODE_MASONRY:
    case ER_UI_NODE_BENTO_GRID:
    case ER_UI_NODE_CARD:
    case ER_UI_NODE_CARD_SUMMARY:
      out = er_ui_a11y_base(ER_UI_A11Y_GROUP, "", false, 0u);
      if (node->kind == ER_UI_NODE_CARD_SUMMARY) {
        out.label = node->label ? node->label : "";
        er_ui_a11y_set_value(&out, node->detail);
      }
      break;
    case ER_UI_NODE_SCROLL_AREA:
      out = er_ui_a11y_base(ER_UI_A11Y_GROUP, "scroll area", node->id != 0u, node->id);
      break;
    case ER_UI_NODE_CONVERSATION:
      out = er_ui_a11y_base(ER_UI_A11Y_GROUP, "conversation", node->id != 0u, node->id);
      break;
    case ER_UI_NODE_TEXT:
    case ER_UI_NODE_BADGE:
      out = er_ui_a11y_base(ER_UI_A11Y_TEXT, node->label, false, 0u);
      break;
    case ER_UI_NODE_ICON: {
      const char* icon_label = node->label ? node->label : er_ui_icon_label(node->icon);
      if (!icon_label) return ER_UI_ERR_INVALID_ARGUMENT;
      out = er_ui_a11y_base(ER_UI_A11Y_IMAGE, icon_label, false, 0u);
      break;
    }
    case ER_UI_NODE_BUTTON:
    case ER_UI_NODE_ICON_BUTTON:
      out = er_ui_a11y_base(ER_UI_A11Y_BUTTON, node->label, true, node->id);
      break;
    case ER_UI_NODE_BUTTON_GROUP:
    case ER_UI_NODE_TOGGLE_GROUP:
      out = er_ui_a11y_base(ER_UI_A11Y_GROUP, node->kind == ER_UI_NODE_BUTTON_GROUP ? "button group" : "toggle group", false, 0u);
      break;
    case ER_UI_NODE_CHECKBOX:
      out = er_ui_a11y_base(ER_UI_A11Y_CHECKBOX, node->label, true, node->id);
      if (node->active) out.states |= ER_UI_A11Y_STATE_CHECKED;
      break;
    case ER_UI_NODE_RADIO:
      out = er_ui_a11y_base(ER_UI_A11Y_RADIO, node->label, true, node->id);
      if (node->active) out.states |= ER_UI_A11Y_STATE_CHECKED;
      break;
    case ER_UI_NODE_SELECT:
      out = er_ui_a11y_base(ER_UI_A11Y_COMBOBOX, node->label, true, node->id);
      er_ui_a11y_set_value(&out, node->value);
      break;
    case ER_UI_NODE_FIELD:
    case ER_UI_NODE_TEXT_AREA:
      out = er_ui_a11y_base(ER_UI_A11Y_TEXTBOX, node->label, true, node->id);
      er_ui_a11y_set_value(&out, node->value);
      break;
    case ER_UI_NODE_SLIDER:
      out = er_ui_a11y_base(ER_UI_A11Y_SLIDER, node->label, true, node->id);
      out.numeric_value = node->number;
      out.states |= ER_UI_A11Y_STATE_HAS_VALUE;
      break;
    case ER_UI_NODE_TOOLTIP:
      out = er_ui_a11y_base(ER_UI_A11Y_TOOLTIP, node->label, false, 0u);
      break;
    case ER_UI_NODE_DIALOG:
      out = er_ui_a11y_base(ER_UI_A11Y_DIALOG, node->label, false, 0u);
      break;
    case ER_UI_NODE_TOAST:
      out = er_ui_a11y_base(ER_UI_A11Y_STATUS, node->label, false, 0u);
      break;
    case ER_UI_NODE_EMPTY:
    case ER_UI_NODE_SECTION:
      out = er_ui_a11y_base(ER_UI_A11Y_GROUP, node->label, false, 0u);
      break;
    case ER_UI_NODE_SKELETON:
      out = er_ui_a11y_base(ER_UI_A11Y_GENERIC, "loading", false, 0u);
      break;
    case ER_UI_NODE_PROGRESS:
    case ER_UI_NODE_PROGRESS_RING:
      out = er_ui_a11y_base(ER_UI_A11Y_PROGRESSBAR, "progress", false, 0u);
      out.numeric_value = node->number;
      out.states |= ER_UI_A11Y_STATE_HAS_VALUE;
      break;
    case ER_UI_NODE_TABLE:
      out = er_ui_a11y_base(ER_UI_A11Y_TABLE, "table", true, node->id);
      break;
    case ER_UI_NODE_BREADCRUMB:
      out = er_ui_a11y_base(ER_UI_A11Y_NAVIGATION, "breadcrumb", false, 0u);
      break;
    case ER_UI_NODE_PAGINATION:
      out = er_ui_a11y_base(ER_UI_A11Y_NAVIGATION, "pagination", false, 0u);
      break;
    case ER_UI_NODE_COLLAPSIBLE:
      out = er_ui_a11y_base(ER_UI_A11Y_GROUP, node->label, false, 0u);
      if (node->active) out.states |= ER_UI_A11Y_STATE_EXPANDED | ER_UI_A11Y_STATE_OPEN;
      break;
    case ER_UI_NODE_ACCORDION:
      out = er_ui_a11y_base(ER_UI_A11Y_GROUP, "accordion", false, 0u);
      break;
    case ER_UI_NODE_HOVER_CARD:
      out = er_ui_a11y_base(ER_UI_A11Y_GROUP, node->label, false, 0u);
      er_ui_a11y_set_value(&out, node->detail);
      break;
    case ER_UI_NODE_POPOVER:
      out = er_ui_a11y_base(ER_UI_A11Y_DIALOG, node->value, false, 0u);
      er_ui_a11y_set_value(&out, node->detail);
      break;
    case ER_UI_NODE_SHEET:
      out = er_ui_a11y_base(ER_UI_A11Y_DIALOG, node->label, false, 0u);
      er_ui_a11y_set_value(&out, node->detail);
      break;
    case ER_UI_NODE_KBD:
      out = er_ui_a11y_base(ER_UI_A11Y_GROUP, node->label, false, 0u);
      break;
    case ER_UI_NODE_MENUBAR:
      out = er_ui_a11y_base(ER_UI_A11Y_NAVIGATION, "menubar", false, 0u);
      break;
    case ER_UI_NODE_RADIO_GROUP:
      out = er_ui_a11y_base(ER_UI_A11Y_GROUP, "radio group", false, 0u);
      break;
    case ER_UI_NODE_INPUT_GROUP:
      out = er_ui_a11y_base(ER_UI_A11Y_GROUP, node->label, false, 0u);
      er_ui_a11y_set_value(&out, node->value);
      break;
    case ER_UI_NODE_INPUT_OTP:
      out = er_ui_a11y_base(ER_UI_A11Y_GROUP, "one-time password", false, 0u);
      break;
    case ER_UI_NODE_NAVIGATION_MENU:
      out = er_ui_a11y_base(ER_UI_A11Y_NAVIGATION, node->label, false, 0u);
      break;
    case ER_UI_NODE_RESIZABLE:
      out = er_ui_a11y_base(ER_UI_A11Y_GROUP, "resizable", false, 0u);
      break;
    case ER_UI_NODE_SIDEBAR:
      out = er_ui_a11y_base(ER_UI_A11Y_NAVIGATION, node->label, false, 0u);
      break;
    case ER_UI_NODE_SONNER:
      out = er_ui_a11y_base(ER_UI_A11Y_STATUS, "toaster", false, 0u);
      break;
    case ER_UI_NODE_ASPECT_RATIO:
      out = er_ui_a11y_base(ER_UI_A11Y_IMAGE, node->label, false, 0u);
      break;
    case ER_UI_NODE_ALERT_DIALOG:
      out = er_ui_a11y_base(ER_UI_A11Y_DIALOG, node->label, false, 0u);
      er_ui_a11y_set_value(&out, node->detail);
      out.states |= ER_UI_A11Y_STATE_OPEN;
      break;
    case ER_UI_NODE_DIRECTION:
      out = er_ui_a11y_base(ER_UI_A11Y_GROUP, "direction", false, 0u);
      break;
    case ER_UI_NODE_DRAWER:
      out = er_ui_a11y_base(ER_UI_A11Y_DIALOG, node->label, false, 0u);
      er_ui_a11y_set_value(&out, node->detail);
      out.states |= ER_UI_A11Y_STATE_OPEN;
      break;
    case ER_UI_NODE_DROPDOWN_MENU:
      out = er_ui_a11y_base(ER_UI_A11Y_NAVIGATION, "dropdown menu", false, 0u);
      break;
    case ER_UI_NODE_CONTEXT_MENU:
      out = er_ui_a11y_base(ER_UI_A11Y_NAVIGATION, node->label, false, 0u);
      er_ui_a11y_set_value(&out, node->detail);
      break;
    case ER_UI_NODE_DATE_PICKER:
      out = er_ui_a11y_base(ER_UI_A11Y_COMBOBOX, node->label, true, node->id);
      er_ui_a11y_set_value(&out, node->detail);
      out.states |= ER_UI_A11Y_STATE_OPEN;
      break;
    case ER_UI_NODE_CAROUSEL:
      out = er_ui_a11y_base(ER_UI_A11Y_GROUP, "carousel", false, 0u);
      break;
    case ER_UI_NODE_CALENDAR:
      out = er_ui_a11y_base(ER_UI_A11Y_GROUP, node->label, false, 0u);
      break;
    case ER_UI_NODE_COMBOBOX:
      out = er_ui_a11y_base(ER_UI_A11Y_COMBOBOX, node->label, true, node->id);
      er_ui_a11y_set_value(&out, node->value);
      out.states |= ER_UI_A11Y_STATE_OPEN;
      break;
    case ER_UI_NODE_DIFF_BODY:
      out = er_ui_a11y_base(ER_UI_A11Y_GROUP, "diff body", false, 0u);
      if (node->active) out.states |= ER_UI_A11Y_STATE_HAS_VALUE;
      break;
    case ER_UI_NODE_CHAT_MESSAGE:
      out = er_ui_a11y_base(ER_UI_A11Y_GROUP, er_ui_component_chat_role_label((er_ui_component_chat_role_t)node->selected), false, 0u);
      er_ui_a11y_set_value(&out, node->detail ? node->detail : node->label);
      break;
    case ER_UI_NODE_TABS:
      out = er_ui_a11y_base(ER_UI_A11Y_TAB_LIST, "tabs", false, 0u);
      break;
    case ER_UI_NODE_COMMAND_PALETTE:
      out = er_ui_a11y_base(ER_UI_A11Y_COMBOBOX, node->label, true, node->id);
      break;
    case ER_UI_NODE_TREE_ITEM:
      out = er_ui_a11y_base(ER_UI_A11Y_LIST_ITEM, node->label, true, node->id);
      if (node->active) out.states |= ER_UI_A11Y_STATE_EXPANDED;
      break;
    case ER_UI_NODE_CONTACT_CARD:
    case ER_UI_NODE_ATTACHMENT_PREVIEW:
      out = er_ui_a11y_base(ER_UI_A11Y_GROUP, node->label, true, node->id);
      break;
    case ER_UI_NODE_THREAD_ROW:
      out = er_ui_a11y_base(ER_UI_A11Y_LIST_ITEM, node->label, true, node->id);
      if (node->active) out.states |= ER_UI_A11Y_STATE_CURRENT;
      break;
    case ER_UI_NODE_LIST_ROW:
      out = er_ui_a11y_base(ER_UI_A11Y_LIST_ITEM, node->label, true, node->id);
      break;
    case ER_UI_NODE_PANEL_HEADER:
    case ER_UI_NODE_METRIC_CARD:
      out = er_ui_a11y_base(ER_UI_A11Y_GROUP, node->label, false, 0u);
      if (node->kind == ER_UI_NODE_METRIC_CARD) er_ui_a11y_set_value(&out, node->value);
      break;
    case ER_UI_NODE_MENU_ITEM:
      out = er_ui_a11y_base(ER_UI_A11Y_MENU_ITEM, node->label, true, node->id);
      if (node->active) out.states |= ER_UI_A11Y_STATE_SELECTED;
      break;
    case ER_UI_NODE_CONTROL_ROW:
      out = er_ui_a11y_base(ER_UI_A11Y_LIST_ITEM, node->label, node->id != 0u, node->id);
      er_ui_a11y_set_value(&out, node->value);
      break;
    case ER_UI_NODE_SWITCH:
      out = er_ui_a11y_base(ER_UI_A11Y_BUTTON, "toggle", true, node->id);
      if (node->active) out.states |= ER_UI_A11Y_STATE_CHECKED;
      break;
    case ER_UI_NODE_AVATAR:
      out = er_ui_a11y_base(ER_UI_A11Y_IMAGE, node->label, false, 0u);
      if (node->active) out.states |= ER_UI_A11Y_STATE_CURRENT;
      break;
    case ER_UI_NODE_BAR_CHART:
      out = er_ui_a11y_base(ER_UI_A11Y_IMAGE, node->label, false, 0u);
      break;
    case ER_UI_NODE_ALERT:
      out = er_ui_a11y_base(ER_UI_A11Y_STATUS, node->label, false, 0u);
      break;
    case ER_UI_NODE_SEPARATOR:
      out = er_ui_a11y_base(ER_UI_A11Y_SEPARATOR, "", false, 0u);
      break;
    case ER_UI_NODE_SPACER:
    default:
      out = er_ui_a11y_base(ER_UI_A11Y_GENERIC, "", false, 0u);
      break;
  }
  *out_a11y = out;
  return ER_UI_OK;
}

er_ui_status_t er_ui_node_accessibility_child(const er_ui_node_t* node, size_t child_index, er_ui_a11y_node_t* out_a11y) {
  if (!node || !out_a11y) return ER_UI_ERR_INVALID_ARGUMENT;
  if (node->kind == ER_UI_NODE_TABS) {
    if (!node->labels || child_index >= node->label_count) return ER_UI_ERR_INVALID_ARGUMENT;
    er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_TAB, node->labels[child_index], true, node->id + (uint32_t)child_index);
    if (child_index == node->selected) out.states |= ER_UI_A11Y_STATE_SELECTED;
    *out_a11y = out;
    return ER_UI_OK;
  }
  if (node->kind == ER_UI_NODE_BUTTON_GROUP || node->kind == ER_UI_NODE_TOGGLE_GROUP) {
    if (!node->labels || child_index >= node->label_count) return ER_UI_ERR_INVALID_ARGUMENT;
    er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_BUTTON, node->labels[child_index], true, node->id + (uint32_t)child_index);
    if (node->kind == ER_UI_NODE_TOGGLE_GROUP && child_index == node->selected) out.states |= ER_UI_A11Y_STATE_SELECTED;
    *out_a11y = out;
    return ER_UI_OK;
  }
  if (node->kind == ER_UI_NODE_MENUBAR) {
    if (!node->labels || child_index >= node->label_count) return ER_UI_ERR_INVALID_ARGUMENT;
    er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_BUTTON, node->labels[child_index], true, node->id + (uint32_t)child_index);
    if (child_index == node->selected) out.states |= ER_UI_A11Y_STATE_SELECTED;
    *out_a11y = out;
    return ER_UI_OK;
  }
  if (node->kind == ER_UI_NODE_DROPDOWN_MENU) {
    return er_ui_node_menu_item_accessibility(node, child_index, out_a11y);
  }
  if (node->kind == ER_UI_NODE_CONTEXT_MENU) {
    return er_ui_node_menu_item_accessibility(node, child_index, out_a11y);
  }
  if (node->kind == ER_UI_NODE_DATE_PICKER) {
    if (!node->labels || child_index > node->label_count) return ER_UI_ERR_INVALID_ARGUMENT;
    if (child_index == 0u) {
      *out_a11y = er_ui_a11y_base(ER_UI_A11Y_BUTTON, node->label, true, node->id);
      return ER_UI_OK;
    }
    size_t day_index = child_index - 1u;
    er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_BUTTON, node->labels[day_index], true, node->id + (uint32_t)child_index);
    if (day_index == node->selected) out.states |= ER_UI_A11Y_STATE_SELECTED;
    *out_a11y = out;
    return ER_UI_OK;
  }
  if (node->kind == ER_UI_NODE_CAROUSEL) {
    if (!node->labels || child_index >= node->label_count + 2u) return ER_UI_ERR_INVALID_ARGUMENT;
    if (child_index == 0u) {
      *out_a11y = er_ui_a11y_base(ER_UI_A11Y_BUTTON, "Previous", true, node->id);
      return ER_UI_OK;
    }
    if (child_index == node->label_count + 1u) {
      *out_a11y = er_ui_a11y_base(ER_UI_A11Y_BUTTON, "Next", true, node->id + 1u);
      return ER_UI_OK;
    }
    *out_a11y = er_ui_a11y_base(ER_UI_A11Y_GROUP, node->labels[child_index - 1u], false, 0u);
    return ER_UI_OK;
  }
  if (node->kind == ER_UI_NODE_CALENDAR) {
    if (!node->labels || child_index >= node->label_count + 2u) return ER_UI_ERR_INVALID_ARGUMENT;
    if (child_index == 0u) {
      *out_a11y = er_ui_a11y_base(ER_UI_A11Y_BUTTON, "Previous month", true, node->id);
      return ER_UI_OK;
    }
    if (child_index == 1u) {
      *out_a11y = er_ui_a11y_base(ER_UI_A11Y_BUTTON, "Next month", true, node->id + 1u);
      return ER_UI_OK;
    }
    size_t day_index = child_index - 2u;
    er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_BUTTON, node->labels[day_index], true, node->id + (uint32_t)child_index);
    if (day_index == node->selected) out.states |= ER_UI_A11Y_STATE_SELECTED;
    *out_a11y = out;
    return ER_UI_OK;
  }
  if (node->kind == ER_UI_NODE_COMBOBOX) {
    if (!node->labels || child_index >= node->label_count + 2u) return ER_UI_ERR_INVALID_ARGUMENT;
    if (child_index == 0u) {
      er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_COMBOBOX, node->label, true, node->id);
      er_ui_a11y_set_value(&out, node->value);
      out.states |= ER_UI_A11Y_STATE_OPEN;
      *out_a11y = out;
      return ER_UI_OK;
    }
    if (child_index == 1u) {
      *out_a11y = er_ui_a11y_base(ER_UI_A11Y_COMBOBOX, node->detail, true, node->id + 1u);
      return ER_UI_OK;
    }
    size_t option_index = child_index - 2u;
    er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_MENU_ITEM, node->labels[option_index], true, node->id + (uint32_t)child_index);
    if (option_index == node->selected) out.states |= ER_UI_A11Y_STATE_SELECTED;
    *out_a11y = out;
    return ER_UI_OK;
  }
  if (node->kind == ER_UI_NODE_DIFF_BODY) {
    if (!node->labels || child_index >= node->label_count + (node->active ? 1u : 0u)) return ER_UI_ERR_INVALID_ARGUMENT;
    const char* label = child_index < node->label_count ? node->labels[child_index] : "[diff preview truncated]";
    *out_a11y = er_ui_a11y_base(ER_UI_A11Y_TEXT, label, false, 0u);
    return ER_UI_OK;
  }
  if (node->kind == ER_UI_NODE_CHAT_MESSAGE) {
    er_ui_component_chat_role_t role = (er_ui_component_chat_role_t)node->selected;
    if (role == ER_UI_COMPONENT_CHAT_ROLE_DIFF) {
      if (!node->labels || child_index >= node->label_count + 1u + (node->active ? 1u : 0u)) return ER_UI_ERR_INVALID_ARGUMENT;
      if (child_index == 0u) {
        *out_a11y = er_ui_a11y_base(ER_UI_A11Y_TEXT, node->label, false, 0u);
        return ER_UI_OK;
      }
      const char* label = child_index - 1u < node->label_count ? node->labels[child_index - 1u] : "[diff preview truncated]";
      *out_a11y = er_ui_a11y_base(ER_UI_A11Y_TEXT, label, false, 0u);
      return ER_UI_OK;
    }
    if (child_index > 1u) return ER_UI_ERR_INVALID_ARGUMENT;
    *out_a11y = er_ui_a11y_base(ER_UI_A11Y_TEXT, child_index == 0u ? node->label : node->detail, false, 0u);
    return ER_UI_OK;
  }
  if (node->kind == ER_UI_NODE_CONVERSATION) {
    if (child_index >= node->child_count || !node->children[child_index]) return ER_UI_ERR_INVALID_ARGUMENT;
    return er_ui_node_accessibility(node->children[child_index], out_a11y);
  }
  if (node->kind == ER_UI_NODE_RADIO_GROUP) {
    if (!node->labels || child_index >= node->label_count) return ER_UI_ERR_INVALID_ARGUMENT;
    er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_RADIO, node->labels[child_index], true, node->id + (uint32_t)child_index);
    if (child_index == node->selected) out.states |= ER_UI_A11Y_STATE_CHECKED;
    *out_a11y = out;
    return ER_UI_OK;
  }
  if (node->kind == ER_UI_NODE_DIRECTION) {
    if (child_index > 1u) return ER_UI_ERR_INVALID_ARGUMENT;
    *out_a11y = er_ui_a11y_base(ER_UI_A11Y_TEXT, child_index == 0u ? node->label : node->detail, false, 0u);
    return ER_UI_OK;
  }
  if (node->kind == ER_UI_NODE_DRAWER) {
    if (child_index == 0u) {
      er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_SLIDER, node->aux, true, node->id);
      out.numeric_value = node->number;
      out.states |= ER_UI_A11Y_STATE_HAS_VALUE;
      *out_a11y = out;
      return ER_UI_OK;
    }
    if (child_index == 1u) {
      *out_a11y = er_ui_a11y_base(ER_UI_A11Y_BUTTON, "Submit", true, node->id + 1u);
      return ER_UI_OK;
    }
    return ER_UI_ERR_INVALID_ARGUMENT;
  }
  if (node->kind == ER_UI_NODE_INPUT_GROUP) {
    if (child_index == 0u) {
      er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_TEXTBOX, node->label, true, node->id);
      er_ui_a11y_set_value(&out, node->value);
      *out_a11y = out;
      return ER_UI_OK;
    }
    if (child_index == 1u) {
      *out_a11y = er_ui_a11y_base(ER_UI_A11Y_BUTTON, node->detail, true, node->id + 1u);
      return ER_UI_OK;
    }
    return ER_UI_ERR_INVALID_ARGUMENT;
  }
  if (node->kind == ER_UI_NODE_INPUT_OTP) {
    if (!node->labels || child_index >= node->label_count || (node->labels[child_index] && node->labels[child_index][0] == '-' && node->labels[child_index][1] == 0)) {
      return ER_UI_ERR_INVALID_ARGUMENT;
    }
    er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_TEXTBOX, "otp digit", true, node->id + (uint32_t)child_index);
    er_ui_a11y_set_value(&out, node->labels[child_index]);
    if (child_index == node->selected) out.states |= ER_UI_A11Y_STATE_FOCUSED;
    *out_a11y = out;
    return ER_UI_OK;
  }
  if (node->kind == ER_UI_NODE_NAVIGATION_MENU) {
    if (!node->labels || child_index > node->label_count) return ER_UI_ERR_INVALID_ARGUMENT;
    if (child_index < node->label_count) {
      er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_BUTTON, node->labels[child_index], true, node->id + (uint32_t)child_index);
      if (child_index == node->selected) out.states |= ER_UI_A11Y_STATE_SELECTED;
      *out_a11y = out;
      return ER_UI_OK;
    }
    *out_a11y = er_ui_a11y_base(ER_UI_A11Y_LIST_ITEM, node->aux, true, node->id + (uint32_t)node->label_count);
    return ER_UI_OK;
  }
  if (node->kind == ER_UI_NODE_SIDEBAR) {
    if (!node->labels || child_index > node->label_count) return ER_UI_ERR_INVALID_ARGUMENT;
    if (child_index < node->label_count) {
      er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_MENU_ITEM, node->labels[child_index], true, node->id + (uint32_t)child_index);
      if (child_index == node->selected) out.states |= ER_UI_A11Y_STATE_SELECTED;
      *out_a11y = out;
      return ER_UI_OK;
    }
    *out_a11y = er_ui_a11y_base(ER_UI_A11Y_GROUP, node->value, false, 0u);
    return ER_UI_OK;
  }
  if (node->kind == ER_UI_NODE_SONNER) {
    if (!node->labels || child_index >= node->label_count) return ER_UI_ERR_INVALID_ARGUMENT;
    *out_a11y = er_ui_a11y_base(ER_UI_A11Y_STATUS, node->labels[child_index], false, 0u);
    return ER_UI_OK;
  }
  if (node->kind == ER_UI_NODE_BREADCRUMB) {
    if (!node->labels || child_index >= node->label_count) return ER_UI_ERR_INVALID_ARGUMENT;
    er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_LIST_ITEM, node->labels[child_index], true, node->id + (uint32_t)child_index);
    if (child_index == node->selected) out.states |= ER_UI_A11Y_STATE_CURRENT;
    *out_a11y = out;
    return ER_UI_OK;
  }
  if (node->kind == ER_UI_NODE_PAGINATION) {
    if (!node->labels || child_index >= node->label_count + 2u) return ER_UI_ERR_INVALID_ARGUMENT;
    const char* label = child_index == 0u ? "Previous" : (child_index == node->label_count + 1u ? "Next" : node->labels[child_index - 1u]);
    er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_BUTTON, label, true, node->id + (uint32_t)child_index);
    if (child_index > 0u && child_index <= node->label_count && child_index - 1u == node->selected) out.states |= ER_UI_A11Y_STATE_CURRENT;
    *out_a11y = out;
    return ER_UI_OK;
  }
  if (node->kind == ER_UI_NODE_COLLAPSIBLE) {
    if (child_index == 0u) {
      er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_BUTTON, node->label, true, node->id);
      if (node->active) out.states |= ER_UI_A11Y_STATE_EXPANDED | ER_UI_A11Y_STATE_OPEN;
      *out_a11y = out;
      return ER_UI_OK;
    }
    if (!node->active || !node->labels || child_index - 1u >= node->row_count) return ER_UI_ERR_INVALID_ARGUMENT;
    *out_a11y = er_ui_a11y_base(ER_UI_A11Y_LIST_ITEM, node->labels[child_index - 1u], true, node->id + (uint32_t)child_index);
    return ER_UI_OK;
  }
  if (node->kind == ER_UI_NODE_ACCORDION) {
    if (!node->labels || child_index >= node->row_count) return ER_UI_ERR_INVALID_ARGUMENT;
    er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_BUTTON, node->labels[child_index], true, node->id + (uint32_t)child_index);
    out.states |= ER_UI_A11Y_STATE_EXPANDED | ER_UI_A11Y_STATE_OPEN;
    *out_a11y = out;
    return ER_UI_OK;
  }
  if (node->kind == ER_UI_NODE_POPOVER) {
    if (child_index == 0u) {
      *out_a11y = er_ui_a11y_base(ER_UI_A11Y_BUTTON, node->label, true, node->id);
      return ER_UI_OK;
    }
    if (child_index == 1u) {
      er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_TEXTBOX, node->aux, true, node->id + 1u);
      er_ui_a11y_set_value(&out, node->extra);
      *out_a11y = out;
      return ER_UI_OK;
    }
    return ER_UI_ERR_INVALID_ARGUMENT;
  }
  if (node->kind == ER_UI_NODE_SHEET) {
    if (child_index == 0u) {
      er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_TEXTBOX, node->aux, true, node->id);
      er_ui_a11y_set_value(&out, node->extra);
      *out_a11y = out;
      return ER_UI_OK;
    }
    if (child_index == 1u) {
      *out_a11y = er_ui_a11y_base(ER_UI_A11Y_BUTTON, node->value, true, node->id + 1u);
      return ER_UI_OK;
    }
    return ER_UI_ERR_INVALID_ARGUMENT;
  }
  if (node->kind == ER_UI_NODE_TABLE) {
    if (node->label_count == 0u) return ER_UI_ERR_INVALID_ARGUMENT;
    if (child_index == 0u) {
      *out_a11y = er_ui_a11y_base(ER_UI_A11Y_ROW, "header", false, 0u);
      return ER_UI_OK;
    }
    size_t row = child_index - 1u;
    if (row >= node->row_count) return ER_UI_ERR_INVALID_ARGUMENT;
    *out_a11y = er_ui_a11y_base(ER_UI_A11Y_ROW, "", true, node->id + (uint32_t)row);
    return ER_UI_OK;
  }
  if (child_index >= node->child_count || !node->children[child_index]) return ER_UI_ERR_INVALID_ARGUMENT;
  return er_ui_node_accessibility(node->children[child_index], out_a11y);
}
