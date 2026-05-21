#ifndef ER_UI_NODE_DOMAIN_H
#define ER_UI_NODE_DOMAIN_H

#include "er_ui_node.h"

er_ui_node_t er_ui_node_identity_card(const char* name, const char* node, const char* policy, uint32_t id);
er_ui_node_t er_ui_node_contact_card(const char* name, const char* detail, uint32_t id);
er_ui_node_t er_ui_node_thread_row(const char* title, const char* last_message, bool unread, uint32_t id);
er_ui_node_t er_ui_node_attachment_preview(const char* name, const char* kind, uint32_t id);
er_ui_node_t er_ui_node_capability_grant_row(const char* app, const char* capability, const char* state, uint32_t id);
er_ui_node_t er_ui_node_proof_event_row(const char* title, const char* hash, const char* status_text, uint32_t id);
er_ui_node_t er_ui_node_chat_message(er_ui_component_chat_role_t role, const char* heading, const char* detail);
er_ui_node_t er_ui_node_route_path(const char* label, const char* const* hops, size_t hop_count);
er_ui_node_t er_ui_node_package_card(const char* name, const char* policy, const char* hash, uint32_t id);
er_ui_node_t er_ui_node_receipt_row(const char* label, const char* amount, const char* status_text, uint32_t id);
er_ui_node_t er_ui_node_control_row(const char* label, const char* detail, const char* accessory, uint32_t id);

#endif
