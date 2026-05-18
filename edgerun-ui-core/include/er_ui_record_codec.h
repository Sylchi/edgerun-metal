#ifndef ER_UI_RECORD_CODEC_H
#define ER_UI_RECORD_CODEC_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define ER_UI_RECORD_MAX_FIELD_LEN 16777216u
#define ER_UI_RECORD_MAX_VEC_ENTRIES 65536u
#define ER_UI_RECORD_ARRAY_32_LEN 32u

typedef enum {
  ER_UI_RECORD_OK = 0,
  ER_UI_RECORD_ERR_WRONG_MAGIC,
  ER_UI_RECORD_ERR_LENGTH_OVERFLOW,
  ER_UI_RECORD_ERR_LIMIT_EXCEEDED,
  ER_UI_RECORD_ERR_TRUNCATED,
  ER_UI_RECORD_ERR_INVALID_BOOL,
  ER_UI_RECORD_ERR_INVALID_UTF8,
  ER_UI_RECORD_ERR_TRAILING_BYTES,
  ER_UI_RECORD_ERR_NO_SPACE,
  ER_UI_RECORD_ERR_INVALID_ARGUMENT
} er_ui_record_status_t;

typedef struct {
  uint8_t* bytes;
  size_t capacity;
  size_t len;
} er_ui_record_writer_t;

typedef struct {
  const uint8_t* bytes;
  size_t len;
  size_t offset;
} er_ui_record_reader_t;

er_ui_record_status_t er_ui_record_writer_init(
  er_ui_record_writer_t* writer,
  uint8_t* out,
  size_t capacity,
  const uint8_t* magic,
  size_t magic_len);
size_t er_ui_record_writer_len(const er_ui_record_writer_t* writer);
const uint8_t* er_ui_record_writer_bytes(const er_ui_record_writer_t* writer);
er_ui_record_status_t er_ui_record_write_bytes(er_ui_record_writer_t* writer, const uint8_t* value, size_t value_len);
er_ui_record_status_t er_ui_record_write_string(er_ui_record_writer_t* writer, const char* value, size_t value_len);
er_ui_record_status_t er_ui_record_write_vec_len(er_ui_record_writer_t* writer, size_t value_count);
er_ui_record_status_t er_ui_record_write_bool(er_ui_record_writer_t* writer, bool value);
er_ui_record_status_t er_ui_record_write_array_32(
  er_ui_record_writer_t* writer,
  const uint8_t value[ER_UI_RECORD_ARRAY_32_LEN]);
er_ui_record_status_t er_ui_record_write_u64(er_ui_record_writer_t* writer, uint64_t value);

er_ui_record_status_t er_ui_record_reader_init(
  er_ui_record_reader_t* reader,
  const uint8_t* bytes,
  size_t byte_len,
  const uint8_t* magic,
  size_t magic_len);
er_ui_record_status_t er_ui_record_reader_finish(const er_ui_record_reader_t* reader);
size_t er_ui_record_reader_offset(const er_ui_record_reader_t* reader);
er_ui_record_status_t er_ui_record_read_bytes(
  er_ui_record_reader_t* reader,
  const uint8_t** out_value,
  size_t* out_len);
er_ui_record_status_t er_ui_record_read_string(
  er_ui_record_reader_t* reader,
  const char** out_value,
  size_t* out_len);
er_ui_record_status_t er_ui_record_read_vec_len(er_ui_record_reader_t* reader, size_t* out_count);
er_ui_record_status_t er_ui_record_read_bool(er_ui_record_reader_t* reader, bool* out_value);
er_ui_record_status_t er_ui_record_read_array_32(
  er_ui_record_reader_t* reader,
  uint8_t out_value[ER_UI_RECORD_ARRAY_32_LEN]);
er_ui_record_status_t er_ui_record_read_u64(er_ui_record_reader_t* reader, uint64_t* out_value);

const char* er_ui_record_status_label(er_ui_record_status_t status);

#ifdef __cplusplus
}
#endif

#endif
