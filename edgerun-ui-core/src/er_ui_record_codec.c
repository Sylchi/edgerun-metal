#include "er_ui_record_codec.h"

enum {
  ER_UI_RECORD_U32_BYTES = 4u,
  ER_UI_RECORD_U64_BYTES = 8u,
  ER_UI_RECORD_BYTE_BITS = 8u,
  ER_UI_RECORD_BYTE_MASK = 0xFFu,
  ER_UI_RECORD_BOOL_FALSE = 0u,
  ER_UI_RECORD_BOOL_TRUE = 1u
};

static const size_t ER_UI_RECORD_U32_MAX_VALUE = 0xFFFFFFFFu;

enum {
  ER_UI_RECORD_UTF8_ASCII_MAX = 0x7Fu,
  ER_UI_RECORD_UTF8_CONT_MASK = 0xC0u,
  ER_UI_RECORD_UTF8_CONT_TAG = 0x80u,
  ER_UI_RECORD_UTF8_2_MIN = 0xC2u,
  ER_UI_RECORD_UTF8_2_MAX = 0xDFu,
  ER_UI_RECORD_UTF8_3_MIN = 0xE0u,
  ER_UI_RECORD_UTF8_3_MAX = 0xEFu,
  ER_UI_RECORD_UTF8_4_MIN = 0xF0u,
  ER_UI_RECORD_UTF8_4_MAX = 0xF4u,
  ER_UI_RECORD_UTF8_E0_CONT_MIN = 0xA0u,
  ER_UI_RECORD_UTF8_ED_CONT_MAX = 0x9Fu,
  ER_UI_RECORD_UTF8_F0_CONT_MIN = 0x90u,
  ER_UI_RECORD_UTF8_F4_CONT_MAX = 0x8Fu
};

static bool er_ui_record_bytes_equal(const uint8_t* a, const uint8_t* b, size_t len) {
  if ((!a || !b) && len > 0u) return false;
  for (size_t i = 0u; i < len; ++i) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

static void er_ui_record_copy(uint8_t* dst, const uint8_t* src, size_t len) {
  for (size_t i = 0u; i < len; ++i) dst[i] = src[i];
}

static bool er_ui_record_u32_fits(size_t value) {
  return value <= ER_UI_RECORD_U32_MAX_VALUE;
}

static er_ui_record_status_t er_ui_record_reserve(er_ui_record_writer_t* writer, size_t len) {
  if (!writer || (!writer->bytes && writer->capacity > 0u)) return ER_UI_RECORD_ERR_INVALID_ARGUMENT;
  if (len > ((size_t)-1) - writer->len) return ER_UI_RECORD_ERR_LENGTH_OVERFLOW;
  if (writer->len + len > writer->capacity) return ER_UI_RECORD_ERR_NO_SPACE;
  return ER_UI_RECORD_OK;
}

static er_ui_record_status_t er_ui_record_write_raw(er_ui_record_writer_t* writer, const uint8_t* bytes, size_t len) {
  if ((!bytes && len > 0u)) return ER_UI_RECORD_ERR_INVALID_ARGUMENT;
  er_ui_record_status_t status = er_ui_record_reserve(writer, len);
  if (status != ER_UI_RECORD_OK) return status;
  if (len == 0u) return ER_UI_RECORD_OK;
  er_ui_record_copy(writer->bytes + writer->len, bytes, len);
  writer->len += len;
  return ER_UI_RECORD_OK;
}

static er_ui_record_status_t er_ui_record_write_u32(er_ui_record_writer_t* writer, uint32_t value) {
  uint8_t bytes[ER_UI_RECORD_U32_BYTES];
  for (size_t i = 0u; i < ER_UI_RECORD_U32_BYTES; ++i) {
    bytes[i] = (uint8_t)((value >> (i * ER_UI_RECORD_BYTE_BITS)) & ER_UI_RECORD_BYTE_MASK);
  }
  return er_ui_record_write_raw(writer, bytes, sizeof(bytes));
}

static er_ui_record_status_t er_ui_record_read_exact(er_ui_record_reader_t* reader, size_t len, const uint8_t** out) {
  if (!reader || !out || (!reader->bytes && reader->len > 0u)) return ER_UI_RECORD_ERR_INVALID_ARGUMENT;
  if (len > ((size_t)-1) - reader->offset) return ER_UI_RECORD_ERR_LENGTH_OVERFLOW;
  size_t end = reader->offset + len;
  if (end > reader->len) return ER_UI_RECORD_ERR_TRUNCATED;
  *out = len == 0u ? reader->bytes : reader->bytes + reader->offset;
  reader->offset = end;
  return ER_UI_RECORD_OK;
}

static er_ui_record_status_t er_ui_record_read_u32(er_ui_record_reader_t* reader, uint32_t* out_value) {
  if (!out_value) return ER_UI_RECORD_ERR_INVALID_ARGUMENT;
  const uint8_t* bytes = 0;
  er_ui_record_status_t status = er_ui_record_read_exact(reader, ER_UI_RECORD_U32_BYTES, &bytes);
  if (status != ER_UI_RECORD_OK) return status;
  uint32_t value = 0u;
  for (size_t i = 0u; i < ER_UI_RECORD_U32_BYTES; ++i) {
    value |= ((uint32_t)bytes[i]) << (i * ER_UI_RECORD_BYTE_BITS);
  }
  *out_value = value;
  return ER_UI_RECORD_OK;
}

static bool er_ui_record_utf8_valid(const uint8_t* bytes, size_t len) {
  if (!bytes && len > 0u) return false;
  size_t offset = 0u;
  while (offset < len) {
    uint8_t b0 = bytes[offset];
    if (b0 <= ER_UI_RECORD_UTF8_ASCII_MAX) {
      offset += 1u;
    } else if (b0 >= ER_UI_RECORD_UTF8_2_MIN && b0 <= ER_UI_RECORD_UTF8_2_MAX) {
      if (offset + ER_UI_RECORD_BOOL_TRUE >= len) return false;
      uint8_t b1 = bytes[offset + ER_UI_RECORD_BOOL_TRUE];
      if ((b1 & ER_UI_RECORD_UTF8_CONT_MASK) != ER_UI_RECORD_UTF8_CONT_TAG) return false;
      offset += 2u;
    } else if (b0 >= ER_UI_RECORD_UTF8_3_MIN && b0 <= ER_UI_RECORD_UTF8_3_MAX) {
      if (offset + 2u >= len) return false;
      uint8_t b1 = bytes[offset + ER_UI_RECORD_BOOL_TRUE];
      uint8_t b2 = bytes[offset + 2u];
      if ((b1 & ER_UI_RECORD_UTF8_CONT_MASK) != ER_UI_RECORD_UTF8_CONT_TAG ||
          (b2 & ER_UI_RECORD_UTF8_CONT_MASK) != ER_UI_RECORD_UTF8_CONT_TAG) {
        return false;
      }
      if (b0 == ER_UI_RECORD_UTF8_3_MIN && b1 < ER_UI_RECORD_UTF8_E0_CONT_MIN) return false;
      if (b0 == 0xEDu && b1 > ER_UI_RECORD_UTF8_ED_CONT_MAX) return false;
      offset += 3u;
    } else if (b0 >= ER_UI_RECORD_UTF8_4_MIN && b0 <= ER_UI_RECORD_UTF8_4_MAX) {
      if (offset + 3u >= len) return false;
      uint8_t b1 = bytes[offset + ER_UI_RECORD_BOOL_TRUE];
      uint8_t b2 = bytes[offset + 2u];
      uint8_t b3 = bytes[offset + 3u];
      if ((b1 & ER_UI_RECORD_UTF8_CONT_MASK) != ER_UI_RECORD_UTF8_CONT_TAG ||
          (b2 & ER_UI_RECORD_UTF8_CONT_MASK) != ER_UI_RECORD_UTF8_CONT_TAG ||
          (b3 & ER_UI_RECORD_UTF8_CONT_MASK) != ER_UI_RECORD_UTF8_CONT_TAG) {
        return false;
      }
      if (b0 == ER_UI_RECORD_UTF8_4_MIN && b1 < ER_UI_RECORD_UTF8_F0_CONT_MIN) return false;
      if (b0 == ER_UI_RECORD_UTF8_4_MAX && b1 > ER_UI_RECORD_UTF8_F4_CONT_MAX) return false;
      offset += ER_UI_RECORD_U32_BYTES;
    } else {
      return false;
    }
  }
  return true;
}

er_ui_record_status_t er_ui_record_writer_init(er_ui_record_writer_t* writer, uint8_t* out, size_t capacity, const uint8_t* magic, size_t magic_len) {
  if (!writer || (!out && capacity > 0u) || (!magic && magic_len > 0u)) return ER_UI_RECORD_ERR_INVALID_ARGUMENT;
  writer->bytes = out;
  writer->capacity = capacity;
  writer->len = 0u;
  return er_ui_record_write_raw(writer, magic, magic_len);
}

size_t er_ui_record_writer_len(const er_ui_record_writer_t* writer) {
  return writer ? writer->len : 0u;
}

const uint8_t* er_ui_record_writer_bytes(const er_ui_record_writer_t* writer) {
  return writer ? writer->bytes : 0;
}

er_ui_record_status_t er_ui_record_write_bytes(er_ui_record_writer_t* writer, const uint8_t* value, size_t value_len) {
  if ((!value && value_len > 0u)) return ER_UI_RECORD_ERR_INVALID_ARGUMENT;
  if (value_len > ER_UI_RECORD_MAX_FIELD_LEN) return ER_UI_RECORD_ERR_LIMIT_EXCEEDED;
  if (!er_ui_record_u32_fits(value_len)) return ER_UI_RECORD_ERR_LENGTH_OVERFLOW;
  er_ui_record_status_t status = er_ui_record_write_u32(writer, (uint32_t)value_len);
  if (status != ER_UI_RECORD_OK) return status;
  return er_ui_record_write_raw(writer, value, value_len);
}

er_ui_record_status_t er_ui_record_write_string(er_ui_record_writer_t* writer, const char* value, size_t value_len) {
  return er_ui_record_write_bytes(writer, (const uint8_t*)value, value_len);
}

er_ui_record_status_t er_ui_record_write_vec_len(er_ui_record_writer_t* writer, size_t value_count) {
  if (value_count > ER_UI_RECORD_MAX_VEC_ENTRIES) return ER_UI_RECORD_ERR_LIMIT_EXCEEDED;
  if (!er_ui_record_u32_fits(value_count)) return ER_UI_RECORD_ERR_LENGTH_OVERFLOW;
  return er_ui_record_write_u32(writer, (uint32_t)value_count);
}

er_ui_record_status_t er_ui_record_write_bool(er_ui_record_writer_t* writer, bool value) {
  uint8_t byte = value ? ER_UI_RECORD_BOOL_TRUE : ER_UI_RECORD_BOOL_FALSE;
  return er_ui_record_write_raw(writer, &byte, ER_UI_RECORD_BOOL_TRUE);
}

er_ui_record_status_t er_ui_record_write_array_32(er_ui_record_writer_t* writer, const uint8_t value[ER_UI_RECORD_ARRAY_32_LEN]) {
  if (!value) return ER_UI_RECORD_ERR_INVALID_ARGUMENT;
  return er_ui_record_write_raw(writer, value, ER_UI_RECORD_ARRAY_32_LEN);
}

er_ui_record_status_t er_ui_record_write_u64(er_ui_record_writer_t* writer, uint64_t value) {
  uint8_t bytes[ER_UI_RECORD_U64_BYTES];
  for (size_t i = 0u; i < ER_UI_RECORD_U64_BYTES; ++i) {
    bytes[i] = (uint8_t)((value >> (i * ER_UI_RECORD_BYTE_BITS)) & ER_UI_RECORD_BYTE_MASK);
  }
  return er_ui_record_write_raw(writer, bytes, sizeof(bytes));
}

er_ui_record_status_t er_ui_record_reader_init(er_ui_record_reader_t* reader, const uint8_t* bytes, size_t byte_len, const uint8_t* magic, size_t magic_len) {
  if (!reader || (!bytes && byte_len > 0u) || (!magic && magic_len > 0u)) return ER_UI_RECORD_ERR_INVALID_ARGUMENT;
  if (byte_len < magic_len || !er_ui_record_bytes_equal(bytes, magic, magic_len)) return ER_UI_RECORD_ERR_WRONG_MAGIC;
  reader->bytes = bytes;
  reader->len = byte_len;
  reader->offset = magic_len;
  return ER_UI_RECORD_OK;
}

er_ui_record_status_t er_ui_record_reader_finish(const er_ui_record_reader_t* reader) {
  if (!reader) return ER_UI_RECORD_ERR_INVALID_ARGUMENT;
  return reader->offset == reader->len ? ER_UI_RECORD_OK : ER_UI_RECORD_ERR_TRAILING_BYTES;
}

size_t er_ui_record_reader_offset(const er_ui_record_reader_t* reader) {
  return reader ? reader->offset : 0u;
}

er_ui_record_status_t er_ui_record_read_bytes(er_ui_record_reader_t* reader, const uint8_t** out_value, size_t* out_len) {
  if (!out_value || !out_len) return ER_UI_RECORD_ERR_INVALID_ARGUMENT;
  uint32_t len = 0u;
  er_ui_record_status_t status = er_ui_record_read_u32(reader, &len);
  if (status != ER_UI_RECORD_OK) return status;
  if ((size_t)len > ER_UI_RECORD_MAX_FIELD_LEN) return ER_UI_RECORD_ERR_LIMIT_EXCEEDED;
  status = er_ui_record_read_exact(reader, (size_t)len, out_value);
  if (status != ER_UI_RECORD_OK) return status;
  *out_len = (size_t)len;
  return ER_UI_RECORD_OK;
}

er_ui_record_status_t er_ui_record_read_string(er_ui_record_reader_t* reader, const char** out_value, size_t* out_len) {
  if (!out_value || !out_len) return ER_UI_RECORD_ERR_INVALID_ARGUMENT;
  const uint8_t* bytes = 0;
  size_t len = 0u;
  er_ui_record_status_t status = er_ui_record_read_bytes(reader, &bytes, &len);
  if (status != ER_UI_RECORD_OK) return status;
  if (!er_ui_record_utf8_valid(bytes, len)) return ER_UI_RECORD_ERR_INVALID_UTF8;
  *out_value = (const char*)bytes;
  *out_len = len;
  return ER_UI_RECORD_OK;
}

er_ui_record_status_t er_ui_record_read_vec_len(er_ui_record_reader_t* reader, size_t* out_count) {
  if (!out_count) return ER_UI_RECORD_ERR_INVALID_ARGUMENT;
  uint32_t count = 0u;
  er_ui_record_status_t status = er_ui_record_read_u32(reader, &count);
  if (status != ER_UI_RECORD_OK) return status;
  if ((size_t)count > ER_UI_RECORD_MAX_VEC_ENTRIES) return ER_UI_RECORD_ERR_LIMIT_EXCEEDED;
  *out_count = (size_t)count;
  return ER_UI_RECORD_OK;
}

er_ui_record_status_t er_ui_record_read_bool(er_ui_record_reader_t* reader, bool* out_value) {
  if (!out_value) return ER_UI_RECORD_ERR_INVALID_ARGUMENT;
  const uint8_t* bytes = 0;
  er_ui_record_status_t status = er_ui_record_read_exact(reader, ER_UI_RECORD_BOOL_TRUE, &bytes);
  if (status != ER_UI_RECORD_OK) return status;
  switch (bytes[0]) {
    case ER_UI_RECORD_BOOL_FALSE:
      *out_value = false;
      return ER_UI_RECORD_OK;
    case ER_UI_RECORD_BOOL_TRUE:
      *out_value = true;
      return ER_UI_RECORD_OK;
    default:
      return ER_UI_RECORD_ERR_INVALID_BOOL;
  }
}

er_ui_record_status_t er_ui_record_read_array_32(er_ui_record_reader_t* reader, uint8_t out_value[ER_UI_RECORD_ARRAY_32_LEN]) {
  if (!out_value) return ER_UI_RECORD_ERR_INVALID_ARGUMENT;
  const uint8_t* bytes = 0;
  er_ui_record_status_t status = er_ui_record_read_exact(reader, ER_UI_RECORD_ARRAY_32_LEN, &bytes);
  if (status != ER_UI_RECORD_OK) return status;
  er_ui_record_copy(out_value, bytes, ER_UI_RECORD_ARRAY_32_LEN);
  return ER_UI_RECORD_OK;
}

er_ui_record_status_t er_ui_record_read_u64(er_ui_record_reader_t* reader, uint64_t* out_value) {
  if (!out_value) return ER_UI_RECORD_ERR_INVALID_ARGUMENT;
  const uint8_t* bytes = 0;
  er_ui_record_status_t status = er_ui_record_read_exact(reader, ER_UI_RECORD_U64_BYTES, &bytes);
  if (status != ER_UI_RECORD_OK) return status;
  uint64_t value = 0u;
  for (size_t i = 0u; i < ER_UI_RECORD_U64_BYTES; ++i) {
    value |= ((uint64_t)bytes[i]) << (i * ER_UI_RECORD_BYTE_BITS);
  }
  *out_value = value;
  return ER_UI_RECORD_OK;
}

const char* er_ui_record_status_label(er_ui_record_status_t status) {
  switch (status) {
    case ER_UI_RECORD_OK:
      return "ok";
    case ER_UI_RECORD_ERR_WRONG_MAGIC:
      return "wrong-magic";
    case ER_UI_RECORD_ERR_LENGTH_OVERFLOW:
      return "length-overflow";
    case ER_UI_RECORD_ERR_LIMIT_EXCEEDED:
      return "limit-exceeded";
    case ER_UI_RECORD_ERR_TRUNCATED:
      return "truncated";
    case ER_UI_RECORD_ERR_INVALID_BOOL:
      return "invalid-bool";
    case ER_UI_RECORD_ERR_INVALID_UTF8:
      return "invalid-utf8";
    case ER_UI_RECORD_ERR_TRAILING_BYTES:
      return "trailing-bytes";
    case ER_UI_RECORD_ERR_NO_SPACE:
      return "no-space";
    case ER_UI_RECORD_ERR_INVALID_ARGUMENT:
      return "invalid-argument";
    default:
      return "unknown";
  }
}
