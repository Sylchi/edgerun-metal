#include "er_ui_record_codec.h"
#include "test_common.h"

static const uint8_t ER_TEST_RECORD_MAGIC[] = {'T', 'E', 'S', 'T', '1'};

static void expect_record_status(er_ui_record_status_t got, er_ui_record_status_t expected, const char* name) {
  expect_true(got == expected, name);
}

static void expect_bytes(const uint8_t* got, size_t got_len, const uint8_t* expected, size_t expected_len, const char* name) {
  bool same = got_len == expected_len;
  for (size_t i = 0u; same && i < got_len; ++i) same = got[i] == expected[i];
  expect_true(same, name);
}

static void expect_string_slice(const char* got, size_t got_len, const char* expected, size_t expected_len, const char* name) {
  bool same = got_len == expected_len;
  for (size_t i = 0u; same && i < got_len; ++i) same = got[i] == expected[i];
  expect_true(same, name);
}

static void test_record_codec_round_trips_values(void) {
  uint8_t bytes[256];
  er_ui_record_writer_t writer = {0};
  expect_record_status(er_ui_record_writer_init(&writer, bytes, sizeof(bytes), ER_TEST_RECORD_MAGIC, sizeof(ER_TEST_RECORD_MAGIC)), ER_UI_RECORD_OK,
                       "record: writer init writes magic");
  const uint8_t one_two_three[] = {1u, 2u, 3u};
  const uint8_t four_five[] = {4u, 5u};
  const uint8_t six[] = {6u};
  uint8_t seven[ER_UI_RECORD_ARRAY_32_LEN];
  for (size_t i = 0u; i < ER_UI_RECORD_ARRAY_32_LEN; ++i) seven[i] = 7u;

  expect_record_status(er_ui_record_write_string(&writer, "slot", 4u), ER_UI_RECORD_OK, "record: string writes");
  expect_record_status(er_ui_record_write_bytes(&writer, one_two_three, sizeof(one_two_three)), ER_UI_RECORD_OK, "record: bytes write");
  expect_record_status(er_ui_record_write_vec_len(&writer, 2u), ER_UI_RECORD_OK, "record: bytes vec count writes");
  expect_record_status(er_ui_record_write_bytes(&writer, four_five, sizeof(four_five)), ER_UI_RECORD_OK, "record: first bytes vec element writes");
  expect_record_status(er_ui_record_write_bytes(&writer, six, sizeof(six)), ER_UI_RECORD_OK, "record: second bytes vec element writes");
  expect_record_status(er_ui_record_write_vec_len(&writer, 2u), ER_UI_RECORD_OK, "record: string vec count writes");
  expect_record_status(er_ui_record_write_string(&writer, "a", 1u), ER_UI_RECORD_OK, "record: first string vec element writes");
  expect_record_status(er_ui_record_write_string(&writer, "b", 1u), ER_UI_RECORD_OK, "record: second string vec element writes");
  expect_record_status(er_ui_record_write_bool(&writer, true), ER_UI_RECORD_OK, "record: bool writes");
  expect_record_status(er_ui_record_write_array_32(&writer, seven), ER_UI_RECORD_OK, "record: array32 writes");
  expect_record_status(er_ui_record_write_u64(&writer, 42u), ER_UI_RECORD_OK, "record: u64 writes");

  er_ui_record_reader_t reader = {0};
  expect_record_status(er_ui_record_reader_init(&reader, er_ui_record_writer_bytes(&writer), er_ui_record_writer_len(&writer), ER_TEST_RECORD_MAGIC,
                                                sizeof(ER_TEST_RECORD_MAGIC)),
                       ER_UI_RECORD_OK, "record: reader accepts magic");

  const char* str = 0;
  size_t str_len = 0u;
  expect_record_status(er_ui_record_read_string(&reader, &str, &str_len), ER_UI_RECORD_OK, "record: string reads");
  expect_string_slice(str, str_len, "slot", 4u, "record: string value round trips");

  const uint8_t* data = 0;
  size_t data_len = 0u;
  expect_record_status(er_ui_record_read_bytes(&reader, &data, &data_len), ER_UI_RECORD_OK, "record: bytes read");
  expect_bytes(data, data_len, one_two_three, sizeof(one_two_three), "record: bytes value round trips");

  size_t count = 0u;
  expect_record_status(er_ui_record_read_vec_len(&reader, &count), ER_UI_RECORD_OK, "record: bytes vec count reads");
  expect_size(count, 2u, "record: bytes vec count");
  expect_record_status(er_ui_record_read_bytes(&reader, &data, &data_len), ER_UI_RECORD_OK, "record: first bytes vec reads");
  expect_bytes(data, data_len, four_five, sizeof(four_five), "record: first bytes vec value");
  expect_record_status(er_ui_record_read_bytes(&reader, &data, &data_len), ER_UI_RECORD_OK, "record: second bytes vec reads");
  expect_bytes(data, data_len, six, sizeof(six), "record: second bytes vec value");

  expect_record_status(er_ui_record_read_vec_len(&reader, &count), ER_UI_RECORD_OK, "record: string vec count reads");
  expect_size(count, 2u, "record: string vec count");
  expect_record_status(er_ui_record_read_string(&reader, &str, &str_len), ER_UI_RECORD_OK, "record: first string vec reads");
  expect_string_slice(str, str_len, "a", 1u, "record: first string vec value");
  expect_record_status(er_ui_record_read_string(&reader, &str, &str_len), ER_UI_RECORD_OK, "record: second string vec reads");
  expect_string_slice(str, str_len, "b", 1u, "record: second string vec value");

  bool value = false;
  expect_record_status(er_ui_record_read_bool(&reader, &value), ER_UI_RECORD_OK, "record: bool reads");
  expect_true(value, "record: bool value round trips");

  uint8_t array[ER_UI_RECORD_ARRAY_32_LEN] = {0};
  expect_record_status(er_ui_record_read_array_32(&reader, array), ER_UI_RECORD_OK, "record: array32 reads");
  expect_bytes(array, sizeof(array), seven, sizeof(seven), "record: array32 value round trips");

  uint64_t wide = 0u;
  expect_record_status(er_ui_record_read_u64(&reader, &wide), ER_UI_RECORD_OK, "record: u64 reads");
  expect_true(wide == 42u, "record: u64 value round trips");
  expect_record_status(er_ui_record_reader_finish(&reader), ER_UI_RECORD_OK, "record: reader finishes at end");
}

static void test_record_codec_rejects_bad_records(void) {
  er_ui_record_reader_t reader = {0};
  expect_record_status(er_ui_record_reader_init(&reader, (const uint8_t*)"BAD", 3u, ER_TEST_RECORD_MAGIC, sizeof(ER_TEST_RECORD_MAGIC)),
                       ER_UI_RECORD_ERR_WRONG_MAGIC, "record: reader rejects wrong magic");

  uint8_t truncated[32];
  er_ui_record_writer_t writer = {0};
  const uint8_t payload[] = {1u, 2u, 3u};
  expect_record_status(er_ui_record_writer_init(&writer, truncated, sizeof(truncated), ER_TEST_RECORD_MAGIC, sizeof(ER_TEST_RECORD_MAGIC)),
                       ER_UI_RECORD_OK, "record: truncated writer init");
  expect_record_status(er_ui_record_write_bytes(&writer, payload, sizeof(payload)), ER_UI_RECORD_OK, "record: truncated payload writes");
  expect_record_status(er_ui_record_reader_init(&reader, truncated, er_ui_record_writer_len(&writer) - 1u, ER_TEST_RECORD_MAGIC,
                                                sizeof(ER_TEST_RECORD_MAGIC)),
                       ER_UI_RECORD_OK, "record: truncated reader init");
  const uint8_t* data = 0;
  size_t data_len = 0u;
  expect_record_status(er_ui_record_read_bytes(&reader, &data, &data_len), ER_UI_RECORD_ERR_TRUNCATED, "record: reader rejects truncated field");

  uint8_t bad_bool[] = {'T', 'E', 'S', 'T', '1', 2u};
  expect_record_status(er_ui_record_reader_init(&reader, bad_bool, sizeof(bad_bool), ER_TEST_RECORD_MAGIC, sizeof(ER_TEST_RECORD_MAGIC)),
                       ER_UI_RECORD_OK, "record: invalid bool reader init");
  bool value = false;
  expect_record_status(er_ui_record_read_bool(&reader, &value), ER_UI_RECORD_ERR_INVALID_BOOL, "record: reader rejects invalid bool");

  uint8_t invalid_utf8[] = {'T', 'E', 'S', 'T', '1', 1u, 0u, 0u, 0u, 0x80u};
  expect_record_status(er_ui_record_reader_init(&reader, invalid_utf8, sizeof(invalid_utf8), ER_TEST_RECORD_MAGIC, sizeof(ER_TEST_RECORD_MAGIC)),
                       ER_UI_RECORD_OK, "record: invalid utf8 reader init");
  const char* text = 0;
  size_t text_len = 0u;
  expect_record_status(er_ui_record_read_string(&reader, &text, &text_len), ER_UI_RECORD_ERR_INVALID_UTF8, "record: reader rejects invalid utf8");
}

static void test_record_codec_limits_and_capacity(void) {
  uint8_t field[] = {'T', 'E', 'S', 'T', '1', 1u, 0u, 0u, 1u};
  er_ui_record_reader_t reader = {0};
  expect_record_status(er_ui_record_reader_init(&reader, field, sizeof(field), ER_TEST_RECORD_MAGIC, sizeof(ER_TEST_RECORD_MAGIC)),
                       ER_UI_RECORD_OK, "record: oversized field reader init");
  const uint8_t* data = 0;
  size_t data_len = 0u;
  expect_record_status(er_ui_record_read_bytes(&reader, &data, &data_len), ER_UI_RECORD_ERR_LIMIT_EXCEEDED,
                       "record: oversized field is rejected before allocation");

  uint8_t vec[] = {'T', 'E', 'S', 'T', '1', 1u, 0u, 1u, 0u};
  expect_record_status(er_ui_record_reader_init(&reader, vec, sizeof(vec), ER_TEST_RECORD_MAGIC, sizeof(ER_TEST_RECORD_MAGIC)), ER_UI_RECORD_OK,
                       "record: oversized vec reader init");
  size_t count = 0u;
  expect_record_status(er_ui_record_read_vec_len(&reader, &count), ER_UI_RECORD_ERR_LIMIT_EXCEEDED,
                       "record: oversized vec is rejected before reads");

  uint8_t small[8];
  er_ui_record_writer_t writer = {0};
  expect_record_status(er_ui_record_writer_init(&writer, small, sizeof(small), ER_TEST_RECORD_MAGIC, sizeof(ER_TEST_RECORD_MAGIC)), ER_UI_RECORD_OK,
                       "record: small writer init");
  expect_record_status(er_ui_record_write_string(&writer, "toolong", 7u), ER_UI_RECORD_ERR_NO_SPACE, "record: writer reports capacity exhaustion");
  expect_record_status(er_ui_record_write_vec_len(&writer, ER_UI_RECORD_MAX_VEC_ENTRIES + 1u), ER_UI_RECORD_ERR_LIMIT_EXCEEDED,
                       "record: writer rejects oversized vec count");
}

void run_record_codec_tests(void) {
  test_record_codec_round_trips_values();
  test_record_codec_rejects_bad_records();
  test_record_codec_limits_and_capacity();
}
