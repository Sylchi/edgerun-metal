#define ER_TEST_ST7789_LOG_BYTES 4096u
#define ER_TEST_ST7789_EVENT_COMMAND 0xc0u
#define ER_TEST_ST7789_EVENT_DATA 0xd0u
#define ER_TEST_ST7789_INIT_COMMANDS 7u
#define ER_TEST_ST7789_FILL_COMMANDS 3u
#define ER_TEST_ST7789_RGB565_GREEN_HI 0x07u
#define ER_TEST_ST7789_RGB565_GREEN_LO 0xe0u
#define ER_TEST_ST7789_PIXEL_RECORD_BYTES 4u

typedef struct ErTestSt7789Bus {
  UINT8 log[ER_TEST_ST7789_LOG_BYTES];
  UINT32 len;
  UINT32 delays;
  UINT8 fail_data;
} ErTestSt7789Bus;

static UINT8 test_st7789_push(ErTestSt7789Bus* bus, UINT8 value) {
  if (bus == 0 || bus->len >= ER_TEST_ST7789_LOG_BYTES) {
    return 0u;
  }
  bus->log[bus->len] = value;
  ++bus->len;
  return 1u;
}

static UINT8 test_st7789_command(void* ctx, UINT8 command) {
  ErTestSt7789Bus* bus = (ErTestSt7789Bus*)ctx;

  return test_st7789_push(bus, ER_TEST_ST7789_EVENT_COMMAND) != 0u &&
         test_st7789_push(bus, command) != 0u;
}

static UINT8 test_st7789_data(void* ctx, const UINT8* bytes, UINT32 len) {
  ErTestSt7789Bus* bus = (ErTestSt7789Bus*)ctx;
  UINT32 i;

  if (bus == 0 || bus->fail_data != 0u || (bytes == 0 && len != 0u) ||
      test_st7789_push(bus, ER_TEST_ST7789_EVENT_DATA) == 0u ||
      test_st7789_push(bus, (UINT8)len) == 0u) {
    return 0u;
  }
  for (i = 0u; i < len; ++i) {
    if (test_st7789_push(bus, bytes[i]) == 0u) {
      return 0u;
    }
  }
  return 1u;
}

static void test_st7789_delay(void* ctx, UINT32 ticks) {
  ErTestSt7789Bus* bus = (ErTestSt7789Bus*)ctx;

  (void)ticks;
  ++bus->delays;
}

static ErSt7789Bus test_st7789_bus(ErTestSt7789Bus* fake) {
  ErSt7789Bus bus;

  bus.ctx = fake;
  bus.write_command = test_st7789_command;
  bus.write_data = test_st7789_data;
  bus.delay = test_st7789_delay;
  return bus;
}

static UINT32 test_st7789_count_event(const ErTestSt7789Bus* bus, UINT8 event) {
  UINT32 i;
  UINT32 count = 0u;

  for (i = 0u; i < bus->len; ++i) {
    if (bus->log[i] == event) {
      ++count;
    }
  }
  return count;
}

static void test_st7789_driver(void) {
  ErTestSt7789Bus fake = {{0u}, 0u, 0u, 0u};
  ErSt7789Bus bus = test_st7789_bus(&fake);
  UINT32 before;

  check_int64("st7789 init succeeds", er_st7789_init(&bus), 1);
  check_uint64("st7789 init command count",
               test_st7789_count_event(&fake, ER_TEST_ST7789_EVENT_COMMAND),
               ER_TEST_ST7789_INIT_COMMANDS);
  check_uint64("st7789 init delay count", fake.delays, 3u);
  check_uint64("st7789 init first command event",
               fake.log[0],
               ER_TEST_ST7789_EVENT_COMMAND);
  check_uint64("st7789 init first command", fake.log[1], 0x01u);

  before = fake.len;
  check_int64("st7789 fill rect succeeds",
              er_st7789_fill_rect(&bus, 1u, 2u, 2u, 1u, ER_ST7789_COLOR_GREEN),
              1);
  check_uint64("st7789 fill rect command delta",
               test_st7789_count_event(&fake, ER_TEST_ST7789_EVENT_COMMAND),
               ER_TEST_ST7789_INIT_COMMANDS + ER_TEST_ST7789_FILL_COMMANDS);
  check_uint64("st7789 fill writes CASET", fake.log[before + 1u], 0x2au);
  check_uint64("st7789 fill first pixel high",
               fake.log[fake.len - (ER_TEST_ST7789_PIXEL_RECORD_BYTES * 2u) + 2u],
               ER_TEST_ST7789_RGB565_GREEN_HI);
  check_uint64("st7789 fill first pixel low",
               fake.log[fake.len - (ER_TEST_ST7789_PIXEL_RECORD_BYTES * 2u) + 3u],
               ER_TEST_ST7789_RGB565_GREEN_LO);
  check_uint64("st7789 fill second pixel high",
               fake.log[fake.len - 2u],
               ER_TEST_ST7789_RGB565_GREEN_HI);
  check_uint64("st7789 fill second pixel low",
               fake.log[fake.len - 1u],
               ER_TEST_ST7789_RGB565_GREEN_LO);

  check_int64("st7789 rejects offscreen rect",
              er_st7789_fill_rect(&bus, ER_ST7789_WIDTH, 0u, 1u, 1u, 0u),
              0);
  check_int64("st7789 text draws known glyph",
              er_st7789_draw_text(&bus,
                                  0u,
                                  0u,
                                  "A0",
                                  1u,
                                  ER_ST7789_COLOR_WHITE,
                                  ER_ST7789_COLOR_BLACK),
              1);

  fake.fail_data = 1u;
  check_int64("st7789 propagates bus failure",
              er_st7789_fill_rect(&bus, 0u, 0u, 1u, 1u, 0u),
              0);
}
