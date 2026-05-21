#include "er_clock.h"

#include <stdint.h>
#include <stdio.h>

enum {
  TEST_LIMIT_TWO = 2u,
  TEST_LIMIT_FOUR = 4u,
  TEST_LIMIT_THREE = 3u,
  TEST_STRIDE_THREE = 3u,
  TEST_KEEPER_SEED = 19u,
  TEST_OTHER_KEEPER_SEED = 41u
};

static int g_failed = 0;
static int g_total = 0;

static void check_int(const char* label, int got, int want) {
  ++g_total;
  if (got != want) {
    ++g_failed;
    fprintf(stderr, "%s: got %d want %d\n", label, got, want);
  }
}

static void check_u64(const char* label, uint64_t got, uint64_t want) {
  ++g_total;
  if (got != want) {
    ++g_failed;
    fprintf(stderr, "%s: got %llu want %llu\n", label,
            (unsigned long long)got, (unsigned long long)want);
  }
}

static er_clock_keeper_id_t test_keeper(uint8_t seed) {
  er_clock_keeper_id_t keeper;
  uint64_t i;

  for (i = 0u; i < ER_CLOCK_KEEPER_ID_SIZE; ++i) {
    keeper.bytes[i] = (uint8_t)(seed + i);
  }
  return keeper;
}

static void test_clock_progression(void) {
  er_clock_limits_t limits;
  er_clock_keeper_id_t keeper = test_keeper(TEST_KEEPER_SEED);
  er_clock_t clock;
  er_clock_boundary_t boundary;
  er_clock_epoch_stamp_t earlier;
  er_clock_epoch_stamp_t later;

  limits.ticks_per_slot = TEST_LIMIT_TWO;
  limits.slots_per_epoch = TEST_LIMIT_TWO;
  limits.epochs_per_era = TEST_LIMIT_TWO;
  check_int("keeper valid", er_clock_keeper_id_valid(&keeper), 1);
  check_int("clock init", er_clock_init(&keeper, &limits, &clock), ER_CLOCK_OK);
  check_int("stamp zero valid with keeper", er_clock_stamp_valid(clock.now), 1);
  check_int("advance 1", er_clock_advance(&clock, &boundary), ER_CLOCK_OK);
  check_int("clock keeps keeper",
            er_clock_keeper_id_equal(&keeper, &clock.now.keeper_id), 1);
  check_u64("tick 1", clock.now.tick, 1u);
  check_int("advance slot", er_clock_advance(&clock, &boundary), ER_CLOCK_OK);
  check_u64("tick wraps", clock.now.tick, 0u);
  check_u64("slot advances", clock.now.slot, 1u);
  check_int("slot boundary", boundary.slot_boundary, 1);
  check_int("advance epoch a", er_clock_advance(&clock, &boundary), ER_CLOCK_OK);
  check_int("advance epoch b", er_clock_advance(&clock, &boundary), ER_CLOCK_OK);
  check_u64("epoch advances", clock.now.epoch, 1u);
  check_int("epoch boundary", boundary.epoch_boundary, 1);
  earlier = clock.now;
  check_int("advance era a", er_clock_advance(&clock, &boundary), ER_CLOCK_OK);
  check_int("advance era b", er_clock_advance(&clock, &boundary), ER_CLOCK_OK);
  check_int("advance era c", er_clock_advance(&clock, &boundary), ER_CLOCK_OK);
  check_int("advance era d", er_clock_advance(&clock, &boundary), ER_CLOCK_OK);
  later = clock.now;
  check_int("same keeper", er_clock_stamp_same_keeper(earlier, later), 1);
  check_u64("era advances", later.era, 1u);
  check_int("era boundary", boundary.era_boundary, 1);
  check_int("compare less", er_clock_stamp_compare(earlier, later), -1);
  check_int("compare equal", er_clock_stamp_compare(later, later), 0);
  check_int("compare greater", er_clock_stamp_compare(later, earlier), 1);
}

static void test_clock_rejects_invalid(void) {
  er_clock_limits_t limits;
  er_clock_keeper_id_t keeper = test_keeper(TEST_KEEPER_SEED);
  er_clock_keeper_id_t other_keeper = test_keeper(TEST_OTHER_KEEPER_SEED);
  er_clock_t clock;
  er_clock_modifier_t modifier;
  er_clock_boundary_t boundary;

  limits.ticks_per_slot = 0u;
  limits.slots_per_epoch = TEST_LIMIT_TWO;
  limits.epochs_per_era = TEST_LIMIT_TWO;
  check_int("reject zero limit", er_clock_init(&keeper, &limits, &clock),
            ER_CLOCK_ERR_BADARG);
  limits.ticks_per_slot = TEST_LIMIT_TWO;
  limits.slots_per_epoch = TEST_LIMIT_THREE;
  check_int("reject non-power limit", er_clock_init(&keeper, &limits, &clock),
            ER_CLOCK_ERR_BADARG);
  limits.slots_per_epoch = TEST_LIMIT_FOUR;
  check_int("init modifier clock", er_clock_init(&keeper, &limits, &clock), ER_CLOCK_OK);
  check_int("different keeper",
            er_clock_keeper_id_equal(&keeper, &other_keeper), 0);
  clock.now.keeper_id = other_keeper;
  check_int("stamp different keeper compare",
            er_clock_stamp_same_keeper(clock.now,
                                       (er_clock_epoch_stamp_t){keeper, 0u, 0u, 0u, 0u}),
            0);
  clock.now.keeper_id = keeper;
  modifier.tick_stride = TEST_STRIDE_THREE;
  check_int("advance modifier",
            er_clock_advance_with_modifier(&clock, &modifier, &boundary),
            ER_CLOCK_OK);
  check_u64("modifier tick", clock.now.tick, 1u);
  check_u64("modifier slot", clock.now.slot, 1u);
  modifier.tick_stride = 0u;
  check_int("reject zero modifier",
            er_clock_advance_with_modifier(&clock, &modifier, &boundary),
            ER_CLOCK_ERR_BADARG);
}

int main(void) {
  test_clock_progression();
  test_clock_rejects_invalid();

  if (g_failed != 0) {
    fprintf(stderr, "clock tests failed: %d/%d\n", g_failed, g_total);
    return 1;
  }
  printf("clock tests passed: %d\n", g_total);
  return 0;
}
