#include "er_ui_runtime_internal.h"

static bool er_ui_text_reserve(er_ui_text_buffer_t* buffer, size_t byte_len) {
  if (!buffer) return false;
  if (!er_ui_allocator_is_valid(buffer->allocator)) return false;
  if (byte_len == ((size_t)-1)) return false;
  size_t needed = byte_len + 1u;
  if (needed <= buffer->byte_capacity) return true;

  size_t next_capacity = buffer->byte_capacity == 0u ? ER_UI_TEXT_INITIAL_CAPACITY : buffer->byte_capacity;
  while (next_capacity < needed) {
    if (next_capacity > ((size_t)-1) / 2u) return false;
    next_capacity *= 2u;
  }

  char* next = (char*)buffer->allocator.alloc(buffer->allocator.user, next_capacity, 1u);
  if (!next) return false;
  if (buffer->value && buffer->byte_capacity > 0u) er_ui_mem_copy(next, buffer->value, buffer->byte_len + 1u);
  er_ui_allocator_free(buffer->allocator, buffer->value, buffer->byte_capacity, 1u);
  buffer->value = next;
  buffer->byte_capacity = next_capacity;
  return true;
}

bool er_ui_utf8_decode_one(const char* text, size_t available, er_ui_utf8_char_t* out_char) {
  if (!text || available == 0u || !out_char) return false;

  const unsigned char b0 = (unsigned char)text[0];
  if (b0 <= ER_UI_UTF8_ASCII_MAX) {
    out_char->codepoint = b0;
    out_char->byte_len = 1u;
    return true;
  }

  if (b0 >= ER_UI_UTF8_2_MIN && b0 <= ER_UI_UTF8_2_MAX) {
    if (available < ER_UI_UTF8_2_BYTES) return false;
    const unsigned char b1 = (unsigned char)text[1];
    if ((b1 & ER_UI_UTF8_CONT_MASK) != ER_UI_UTF8_CONT_TAG) return false;
    out_char->codepoint = ((uint32_t)(b0 & ER_UI_UTF8_2_PAYLOAD_MASK) << ER_UI_UTF8_CONT_SHIFT) |
                          (uint32_t)(b1 & ER_UI_UTF8_CONT_PAYLOAD_MASK);
    out_char->byte_len = ER_UI_UTF8_2_BYTES;
    return true;
  }

  if (b0 >= ER_UI_UTF8_3_MIN && b0 <= ER_UI_UTF8_3_MAX) {
    if (available < ER_UI_UTF8_3_BYTES) return false;
    const unsigned char b1 = (unsigned char)text[1];
    const unsigned char b2 = (unsigned char)text[ER_UI_UTF8_2_BYTES];
    if ((b1 & ER_UI_UTF8_CONT_MASK) != ER_UI_UTF8_CONT_TAG || (b2 & ER_UI_UTF8_CONT_MASK) != ER_UI_UTF8_CONT_TAG) return false;
    if (b0 == ER_UI_UTF8_3_MIN && b1 < ER_UI_UTF8_E0_CONT_MIN) return false;
    if (b0 == ER_UI_UTF8_SURROGATE_MIN && b1 >= ER_UI_UTF8_E0_CONT_MIN) return false;
    out_char->codepoint = ((uint32_t)(b0 & ER_UI_UTF8_3_PAYLOAD_MASK) << ER_UI_UTF8_3_LEAD_SHIFT) |
                          ((uint32_t)(b1 & ER_UI_UTF8_CONT_PAYLOAD_MASK) << ER_UI_UTF8_CONT_SHIFT) |
                          (uint32_t)(b2 & ER_UI_UTF8_CONT_PAYLOAD_MASK);
    out_char->byte_len = ER_UI_UTF8_3_BYTES;
    return true;
  }

  if (b0 >= ER_UI_UTF8_4_MIN && b0 <= ER_UI_UTF8_4_MAX) {
    if (available < ER_UI_UTF8_4_BYTES) return false;
    const unsigned char b1 = (unsigned char)text[1];
    const unsigned char b2 = (unsigned char)text[ER_UI_UTF8_2_BYTES];
    const unsigned char b3 = (unsigned char)text[ER_UI_UTF8_3_BYTES];
    if ((b1 & ER_UI_UTF8_CONT_MASK) != ER_UI_UTF8_CONT_TAG || (b2 & ER_UI_UTF8_CONT_MASK) != ER_UI_UTF8_CONT_TAG ||
        (b3 & ER_UI_UTF8_CONT_MASK) != ER_UI_UTF8_CONT_TAG) return false;
    if (b0 == ER_UI_UTF8_4_MIN && b1 < ER_UI_UTF8_F0_CONT_MIN) return false;
    if (b0 == ER_UI_UTF8_4_MAX && b1 > ER_UI_UTF8_F4_CONT_MAX) return false;
    out_char->codepoint = ((uint32_t)(b0 & ER_UI_UTF8_4_PAYLOAD_MASK) << ER_UI_UTF8_4_LEAD_SHIFT) |
                          ((uint32_t)(b1 & ER_UI_UTF8_CONT_PAYLOAD_MASK) << ER_UI_UTF8_3_LEAD_SHIFT) |
                          ((uint32_t)(b2 & ER_UI_UTF8_CONT_PAYLOAD_MASK) << ER_UI_UTF8_CONT_SHIFT) |
                          (uint32_t)(b3 & ER_UI_UTF8_CONT_PAYLOAD_MASK);
    out_char->byte_len = ER_UI_UTF8_4_BYTES;
    return true;
  }

  return false;
}

//@optimizer-ignore-function UTF-8 validation must decode each codepoint to count text length
bool er_ui_utf8_validate_and_count(const char* text, size_t* out_byte_len, size_t* out_char_count) {
  if (!text || !out_byte_len || !out_char_count) return false;
  size_t byte_len = er_ui_cstr_len(text);
  size_t offset = 0u;
  size_t char_count = 0u;
  while (offset < byte_len) {
    er_ui_utf8_char_t ch = {0};
    if (!er_ui_utf8_decode_one(text + offset, byte_len - offset, &ch)) return false;
    offset += ch.byte_len;
    char_count++;
  }
  *out_byte_len = byte_len;
  *out_char_count = char_count;
  return true;
}

//@optimizer-ignore-function cursor byte lookup must walk UTF-8 codepoints up to the logical cursor
static size_t er_ui_text_cursor_byte_index(const er_ui_text_buffer_t* buffer) {
  if (!buffer || !buffer->value) return 0u;
  size_t offset = 0u;
  size_t char_index = 0u;
  while (offset < buffer->byte_len && char_index < buffer->cursor_chars) {
    er_ui_utf8_char_t ch = {0};
    if (!er_ui_utf8_decode_one(buffer->value + offset, buffer->byte_len - offset, &ch)) return buffer->byte_len;
    offset += ch.byte_len;
    char_index++;
  }
  return offset;
}

//@optimizer-ignore-function text char count must decode each UTF-8 codepoint in the buffer
static size_t er_ui_text_char_count(const er_ui_text_buffer_t* buffer) {
  if (!buffer || !buffer->value) return 0u;
  size_t offset = 0u;
  size_t char_count = 0u;
  while (offset < buffer->byte_len) {
    er_ui_utf8_char_t ch = {0};
    if (!er_ui_utf8_decode_one(buffer->value + offset, buffer->byte_len - offset, &ch)) return char_count;
    offset += ch.byte_len;
    char_count++;
  }
  return char_count;
}

static bool er_ui_codepoint_is_control(uint32_t codepoint) {
  return codepoint <= ER_UI_CODEPOINT_C0_LAST || codepoint == ER_UI_CODEPOINT_ASCII_DELETE ||
         (codepoint >= ER_UI_CODEPOINT_C1_FIRST && codepoint <= ER_UI_CODEPOINT_C1_LAST);
}

static bool er_ui_codepoint_is_whitespace(uint32_t codepoint) {
  switch (codepoint) {
    case 0x09u:
    case 0x0Au:
    case 0x0Bu:
    case 0x0Cu:
    case 0x0Du:
    case 0x20u:
    case 0x85u:
    case 0xA0u:
    case 0x1680u:
    case 0x2000u:
    case 0x2001u:
    case 0x2002u:
    case 0x2003u:
    case 0x2004u:
    case 0x2005u:
    case 0x2006u:
    case 0x2007u:
    case 0x2008u:
    case 0x2009u:
    case 0x200Au:
    case 0x2028u:
    case 0x2029u:
    case 0x202Fu:
    case 0x205Fu:
    case 0x3000u:
      return true;
    default:
      return false;
  }
}

//@optimizer-ignore-function word navigation must decode UTF-8 codepoints up to the cursor
static uint32_t er_ui_text_codepoint_before_cursor(const er_ui_text_buffer_t* buffer) {
  if (!buffer || buffer->cursor_chars == 0u) return 0u;
  size_t offset = 0u;
  size_t char_index = 0u;
  uint32_t codepoint = 0u;
  while (offset < buffer->byte_len && char_index < buffer->cursor_chars) {
    er_ui_utf8_char_t ch = {0};
    if (!er_ui_utf8_decode_one(buffer->value + offset, buffer->byte_len - offset, &ch)) return 0u;
    codepoint = ch.codepoint;
    offset += ch.byte_len;
    char_index++;
  }
  return codepoint;
}

er_ui_key_t er_ui_key(er_ui_key_kind_t kind) {
  er_ui_key_t key = {kind, 0u};
  return key;
}

er_ui_key_t er_ui_key_other(uint32_t codepoint) {
  er_ui_key_t key = {ER_UI_KEY_OTHER, codepoint};
  return key;
}

er_ui_key_modifiers_t er_ui_key_modifiers(bool shift, bool ctrl, bool alt, bool meta) {
  er_ui_key_modifiers_t modifiers = {shift, ctrl, alt, meta};
  return modifiers;
}

er_ui_key_modifiers_t er_ui_key_modifiers_shift(bool shift) {
  return er_ui_key_modifiers(shift, false, false, false);
}

er_ui_status_t er_ui_text_buffer_init(er_ui_text_buffer_t* buffer) {
  er_ui_allocator_t allocator = {0};
  return er_ui_text_buffer_init_with_allocator(buffer, allocator);
}

er_ui_status_t er_ui_text_buffer_init_with_allocator(er_ui_text_buffer_t* buffer, er_ui_allocator_t allocator) {
  if (!buffer) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_mem_zero(buffer, sizeof(*buffer));
  buffer->allocator = allocator;
  if (!er_ui_text_reserve(buffer, 0u)) return ER_UI_ERR_OOM;
  buffer->value[0] = '\0';
  return ER_UI_OK;
}

void er_ui_text_buffer_destroy(er_ui_text_buffer_t* buffer) {
  if (!buffer) return;
  er_ui_allocator_t allocator = buffer->allocator;
  er_ui_allocator_free(allocator, buffer->value, buffer->byte_capacity, 1u);
  er_ui_mem_zero(buffer, sizeof(*buffer));
}

void er_ui_text_buffer_clear(er_ui_text_buffer_t* buffer) {
  if (!buffer || !buffer->value) return;
  buffer->value[0] = '\0';
  buffer->byte_len = 0u;
  buffer->cursor_chars = 0u;
}

bool er_ui_text_buffer_is_empty(const er_ui_text_buffer_t* buffer) {
  return !buffer || buffer->byte_len == 0u;
}

const char* er_ui_text_buffer_value(const er_ui_text_buffer_t* buffer) {
  if (!buffer || !buffer->value) return "";
  return buffer->value;
}

size_t er_ui_text_buffer_byte_len(const er_ui_text_buffer_t* buffer) {
  return buffer ? buffer->byte_len : 0u;
}

size_t er_ui_text_buffer_cursor_chars(const er_ui_text_buffer_t* buffer) {
  return buffer ? buffer->cursor_chars : 0u;
}

er_ui_status_t er_ui_text_buffer_set_text(er_ui_text_buffer_t* buffer, const char* text) {
  if (!buffer || !text) return ER_UI_ERR_INVALID_ARGUMENT;
  size_t byte_len = 0u;
  size_t char_count = 0u;
  if (!er_ui_utf8_validate_and_count(text, &byte_len, &char_count)) return ER_UI_ERR_INVALID_ARGUMENT;
  if (byte_len > ER_UI_TEXT_BUFFER_MAX_BYTES) return ER_UI_ERR_INVALID_ARGUMENT;
  if (!er_ui_text_reserve(buffer, byte_len)) return ER_UI_ERR_OOM;
  er_ui_mem_copy(buffer->value, text, byte_len + 1u);
  buffer->byte_len = byte_len;
  buffer->cursor_chars = char_count;
  return ER_UI_OK;
}

er_ui_status_t er_ui_text_buffer_insert(er_ui_text_buffer_t* buffer, const char* text) {
  if (!buffer || !buffer->value || !text) return ER_UI_ERR_INVALID_ARGUMENT;
  size_t insert_len = 0u;
  size_t insert_chars = 0u;
  if (!er_ui_utf8_validate_and_count(text, &insert_len, &insert_chars)) return ER_UI_ERR_INVALID_ARGUMENT;
  if (insert_len == 0u) return ER_UI_OK;
  if (buffer->byte_len > ER_UI_TEXT_BUFFER_MAX_BYTES || insert_len > ER_UI_TEXT_BUFFER_MAX_BYTES - buffer->byte_len) {
    return ER_UI_ERR_INVALID_ARGUMENT;
  }

  size_t byte_index = er_ui_text_cursor_byte_index(buffer);
  if (!er_ui_text_reserve(buffer, buffer->byte_len + insert_len)) return ER_UI_ERR_OOM;
  er_ui_mem_move(buffer->value + byte_index + insert_len, buffer->value + byte_index, buffer->byte_len - byte_index + 1u);
  er_ui_mem_copy(buffer->value + byte_index, text, insert_len);
  buffer->byte_len += insert_len;
  buffer->cursor_chars += insert_chars;
  return ER_UI_OK;
}

//@optimizer-ignore-function text input handler must decode and insert each accepted UTF-8 codepoint
er_ui_status_t er_ui_text_buffer_handle_text_input(er_ui_text_buffer_t* buffer, const char* text, er_ui_text_buffer_action_t* out_action) {
  if (!buffer || !buffer->value || !text || !out_action) return ER_UI_ERR_INVALID_ARGUMENT;
  *out_action = ER_UI_TEXT_ACTION_NONE;

  size_t byte_len = 0u;
  size_t ignored_char_count = 0u;
  if (!er_ui_utf8_validate_and_count(text, &byte_len, &ignored_char_count)) return ER_UI_ERR_INVALID_ARGUMENT;

  size_t offset = 0u;
  while (offset < byte_len && buffer->byte_len < ER_UI_TEXT_BUFFER_MAX_BYTES) {
    er_ui_utf8_char_t ch = {0};
    if (!er_ui_utf8_decode_one(text + offset, byte_len - offset, &ch)) return ER_UI_ERR_INVALID_ARGUMENT;
    if (!er_ui_codepoint_is_control(ch.codepoint)) {
      size_t available = ER_UI_TEXT_BUFFER_MAX_BYTES - buffer->byte_len;
      if (ch.byte_len > available) break;
      char one[5] = {0};
      er_ui_mem_copy(one, text + offset, ch.byte_len);
      er_ui_status_t status = er_ui_text_buffer_insert(buffer, one);
      if (status != ER_UI_OK) return status;
      *out_action = ER_UI_TEXT_ACTION_CHANGED;
    }
    offset += ch.byte_len;
  }

  return ER_UI_OK;
}

er_ui_status_t er_ui_text_buffer_handle_key(er_ui_text_buffer_t* buffer, er_ui_key_t key, bool shift, er_ui_text_buffer_action_t* out_action) {
  return er_ui_text_buffer_handle_key_with_modifiers(buffer, key, er_ui_key_modifiers_shift(shift), out_action);
}

er_ui_status_t er_ui_text_buffer_handle_key_with_modifiers(er_ui_text_buffer_t* buffer, er_ui_key_t key, er_ui_key_modifiers_t modifiers, er_ui_text_buffer_action_t* out_action) {
  if (!buffer || !buffer->value || !out_action) return ER_UI_ERR_INVALID_ARGUMENT;
  *out_action = ER_UI_TEXT_ACTION_NONE;
  size_t before = buffer->byte_len;

  if (key.kind == ER_UI_KEY_OTHER && modifiers.ctrl && (key.codepoint == 'a' || key.codepoint == 'A')) {
    er_ui_text_buffer_move_cursor_to_start(buffer);
    *out_action = ER_UI_TEXT_ACTION_CHANGED;
    return ER_UI_OK;
  }
  if (key.kind == ER_UI_KEY_OTHER && modifiers.ctrl && (key.codepoint == 'e' || key.codepoint == 'E')) {
    er_ui_text_buffer_move_cursor_to_end(buffer);
    *out_action = ER_UI_TEXT_ACTION_CHANGED;
    return ER_UI_OK;
  }
  if (key.kind == ER_UI_KEY_OTHER && modifiers.ctrl && (key.codepoint == 'u' || key.codepoint == 'U')) {
    er_ui_text_buffer_delete_before_cursor_all(buffer);
    *out_action = buffer->byte_len == before ? ER_UI_TEXT_ACTION_NONE : ER_UI_TEXT_ACTION_CHANGED;
    return ER_UI_OK;
  }
  if (key.kind == ER_UI_KEY_OTHER && modifiers.ctrl && (key.codepoint == 'k' || key.codepoint == 'K')) {
    er_ui_text_buffer_delete_after_cursor_all(buffer);
    *out_action = buffer->byte_len == before ? ER_UI_TEXT_ACTION_NONE : ER_UI_TEXT_ACTION_CHANGED;
    return ER_UI_OK;
  }
  if (key.kind == ER_UI_KEY_OTHER && modifiers.ctrl && (key.codepoint == 'w' || key.codepoint == 'W')) {
    er_ui_text_buffer_delete_word_before_cursor(buffer);
    *out_action = buffer->byte_len == before ? ER_UI_TEXT_ACTION_NONE : ER_UI_TEXT_ACTION_CHANGED;
    return ER_UI_OK;
  }

  switch (key.kind) {
    case ER_UI_KEY_BACKSPACE:
      er_ui_text_buffer_delete_before_cursor(buffer);
      *out_action = buffer->byte_len == before ? ER_UI_TEXT_ACTION_NONE : ER_UI_TEXT_ACTION_CHANGED;
      break;
    case ER_UI_KEY_DELETE:
      er_ui_text_buffer_delete_after_cursor(buffer);
      *out_action = buffer->byte_len == before ? ER_UI_TEXT_ACTION_NONE : ER_UI_TEXT_ACTION_CHANGED;
      break;
    case ER_UI_KEY_ENTER:
      if (modifiers.shift) {
        er_ui_status_t status = er_ui_text_buffer_insert(buffer, "\n");
        if (status != ER_UI_OK) return status;
        *out_action = ER_UI_TEXT_ACTION_CHANGED;
      } else {
        *out_action = ER_UI_TEXT_ACTION_SUBMIT;
      }
      break;
    case ER_UI_KEY_ARROW_LEFT:
      er_ui_text_buffer_move_cursor_left(buffer);
      *out_action = ER_UI_TEXT_ACTION_CHANGED;
      break;
    case ER_UI_KEY_ARROW_RIGHT:
      er_ui_text_buffer_move_cursor_right(buffer);
      *out_action = ER_UI_TEXT_ACTION_CHANGED;
      break;
    case ER_UI_KEY_HOME:
      er_ui_text_buffer_move_cursor_to_start(buffer);
      *out_action = ER_UI_TEXT_ACTION_CHANGED;
      break;
    case ER_UI_KEY_END:
      er_ui_text_buffer_move_cursor_to_end(buffer);
      *out_action = ER_UI_TEXT_ACTION_CHANGED;
      break;
    default:
      *out_action = ER_UI_TEXT_ACTION_NONE;
      break;
  }

  return ER_UI_OK;
}

void er_ui_text_buffer_delete_before_cursor(er_ui_text_buffer_t* buffer) {
  if (!buffer || !buffer->value || buffer->cursor_chars == 0u) return;
  size_t end = er_ui_text_cursor_byte_index(buffer);
  buffer->cursor_chars--;
  size_t start = er_ui_text_cursor_byte_index(buffer);
  er_ui_mem_move(buffer->value + start, buffer->value + end, buffer->byte_len - end + 1u);
  buffer->byte_len -= end - start;
}

void er_ui_text_buffer_delete_after_cursor(er_ui_text_buffer_t* buffer) {
  if (!buffer || !buffer->value) return;
  size_t start = er_ui_text_cursor_byte_index(buffer);
  if (start == buffer->byte_len) return;
  buffer->cursor_chars++;
  size_t end = er_ui_text_cursor_byte_index(buffer);
  buffer->cursor_chars--;
  er_ui_mem_move(buffer->value + start, buffer->value + end, buffer->byte_len - end + 1u);
  buffer->byte_len -= end - start;
}

void er_ui_text_buffer_delete_before_cursor_all(er_ui_text_buffer_t* buffer) {
  if (!buffer || !buffer->value) return;
  size_t end = er_ui_text_cursor_byte_index(buffer);
  er_ui_mem_move(buffer->value, buffer->value + end, buffer->byte_len - end + 1u);
  buffer->byte_len -= end;
  buffer->cursor_chars = 0u;
}

void er_ui_text_buffer_delete_after_cursor_all(er_ui_text_buffer_t* buffer) {
  if (!buffer || !buffer->value) return;
  size_t start = er_ui_text_cursor_byte_index(buffer);
  buffer->value[start] = '\0';
  buffer->byte_len = start;
}

void er_ui_text_buffer_delete_word_before_cursor(er_ui_text_buffer_t* buffer) {
  if (!buffer || !buffer->value || buffer->cursor_chars == 0u) return;
  size_t end = er_ui_text_cursor_byte_index(buffer);
  while (buffer->cursor_chars > 0u && er_ui_codepoint_is_whitespace(er_ui_text_codepoint_before_cursor(buffer))) {
    buffer->cursor_chars--;
  }
  while (buffer->cursor_chars > 0u && !er_ui_codepoint_is_whitespace(er_ui_text_codepoint_before_cursor(buffer))) {
    buffer->cursor_chars--;
  }
  size_t start = er_ui_text_cursor_byte_index(buffer);
  er_ui_mem_move(buffer->value + start, buffer->value + end, buffer->byte_len - end + 1u);
  buffer->byte_len -= end - start;
}

void er_ui_text_buffer_move_cursor_left(er_ui_text_buffer_t* buffer) {
  if (!buffer || buffer->cursor_chars == 0u) return;
  buffer->cursor_chars--;
}

void er_ui_text_buffer_move_cursor_right(er_ui_text_buffer_t* buffer) {
  if (!buffer) return;
  size_t char_count = er_ui_text_char_count(buffer);
  if (buffer->cursor_chars < char_count) buffer->cursor_chars++;
}

void er_ui_text_buffer_move_cursor_to_start(er_ui_text_buffer_t* buffer) {
  if (!buffer) return;
  buffer->cursor_chars = 0u;
}

void er_ui_text_buffer_move_cursor_to_end(er_ui_text_buffer_t* buffer) {
  if (!buffer) return;
  buffer->cursor_chars = er_ui_text_char_count(buffer);
}

er_ui_status_t er_ui_text_buffer_value_with_cursor(const er_ui_text_buffer_t* buffer, const char* marker, char** out_text) {
  if (!buffer || !buffer->value || !marker || !out_text) return ER_UI_ERR_INVALID_ARGUMENT;
  size_t marker_len = 0u;
  size_t marker_chars = 0u;
  if (!er_ui_utf8_validate_and_count(marker, &marker_len, &marker_chars)) return ER_UI_ERR_INVALID_ARGUMENT;
  if (marker_chars != 1u) return ER_UI_ERR_INVALID_ARGUMENT;
  if (buffer->byte_len > ((size_t)-1) - marker_len - 1u) return ER_UI_ERR_INVALID_ARGUMENT;

  size_t byte_index = er_ui_text_cursor_byte_index(buffer);
  if (!er_ui_allocator_is_valid(buffer->allocator)) return ER_UI_ERR_OOM;
  char* out = (char*)buffer->allocator.alloc(buffer->allocator.user, buffer->byte_len + marker_len + 1u, 1u);
  if (!out) return ER_UI_ERR_OOM;
  er_ui_mem_copy(out, buffer->value, byte_index);
  er_ui_mem_copy(out + byte_index, marker, marker_len);
  er_ui_mem_copy(out + byte_index + marker_len, buffer->value + byte_index, buffer->byte_len - byte_index + 1u);
  *out_text = out;
  return ER_UI_OK;
}

er_ui_status_t er_ui_text_buffer_display_value(const er_ui_text_buffer_t* buffer, const char* placeholder, const char* cursor_marker, char** out_text) {
  if (!buffer || !placeholder || !cursor_marker || !out_text) return ER_UI_ERR_INVALID_ARGUMENT;
  if (er_ui_text_buffer_is_empty(buffer)) {
    size_t placeholder_len = 0u;
    size_t placeholder_chars = 0u;
    if (!er_ui_utf8_validate_and_count(placeholder, &placeholder_len, &placeholder_chars)) return ER_UI_ERR_INVALID_ARGUMENT;
    if (!er_ui_allocator_is_valid(buffer->allocator)) return ER_UI_ERR_OOM;
    char* out = (char*)buffer->allocator.alloc(buffer->allocator.user, placeholder_len + 1u, 1u);
    if (!out) return ER_UI_ERR_OOM;
    er_ui_mem_copy(out, placeholder, placeholder_len + 1u);
    *out_text = out;
    return ER_UI_OK;
  }
  return er_ui_text_buffer_value_with_cursor(buffer, cursor_marker, out_text);
}

void er_ui_text_buffer_free_text(const er_ui_text_buffer_t* buffer, char* text) {
  if (!buffer || !text) return;
  er_ui_allocator_free(buffer->allocator, text, er_ui_cstr_len(text) + 1u, 1u);
}
