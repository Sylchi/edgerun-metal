#include "er_epoch_clock.h"
#include "er_mem.h"

static UINT8 er_epoch_clock_limits_valid(const ErEpochClockLimits* limits) {
  return (UINT8)(limits != 0 &&
                 limits->ticks_per_slot != 0u &&
                 limits->slots_per_epoch != 0u &&
                 limits->epochs_per_era != 0u);
}

static INT32 er_epoch_compare_u64(UINT64 left, UINT64 right) {
  if (left < right) {
    return -1;
  }
  if (left > right) {
    return 1;
  }
  return 0;
}

ErEpochClockLimits er_epoch_clock_default_limits(void) {
  ErEpochClockLimits limits;

  limits.ticks_per_slot = ER_EPOCH_CLOCK_DEFAULT_TICKS_PER_SLOT;
  limits.slots_per_epoch = ER_EPOCH_CLOCK_DEFAULT_SLOTS_PER_EPOCH;
  limits.epochs_per_era = ER_EPOCH_CLOCK_DEFAULT_EPOCHS_PER_ERA;
  return limits;
}

UINT8 er_epoch_clock_init(const ErEpochClockLimits* limits, ErEpochClock* out_clock) {
  if (er_epoch_clock_limits_valid(limits) == 0u || out_clock == 0) {
    return 0u;
  }
  er_mem_zero((UINT8*)out_clock, (UINTN)sizeof(*out_clock));
  out_clock->limits = *limits;
  return 1u;
}

UINT8 er_epoch_clock_advance(ErEpochClock* clock, ErEpochBoundary* out_boundary) {
  if (clock == 0 || er_epoch_clock_limits_valid(&clock->limits) == 0u) {
    return 0u;
  }
  if (out_boundary != 0) {
    er_mem_zero((UINT8*)out_boundary, (UINTN)sizeof(*out_boundary));
  }

  ++clock->now.tick;
  if (clock->now.tick < clock->limits.ticks_per_slot) {
    return 1u;
  }

  clock->now.tick = 0u;
  ++clock->now.slot;
  if (out_boundary != 0) {
    out_boundary->slot_boundary = 1u;
  }
  if (clock->now.slot < clock->limits.slots_per_epoch) {
    return 1u;
  }

  clock->now.slot = 0u;
  ++clock->now.epoch;
  if (out_boundary != 0) {
    out_boundary->epoch_boundary = 1u;
  }
  if (clock->now.epoch < clock->limits.epochs_per_era) {
    return 1u;
  }

  clock->now.epoch = 0u;
  ++clock->now.era;
  if (out_boundary != 0) {
    out_boundary->era_boundary = 1u;
  }
  return 1u;
}

INT32 er_epoch_stamp_compare(ErEpochStamp left, ErEpochStamp right) {
  INT32 result;

  result = er_epoch_compare_u64(left.era, right.era);
  if (result != 0) {
    return result;
  }
  result = er_epoch_compare_u64(left.epoch, right.epoch);
  if (result != 0) {
    return result;
  }
  result = er_epoch_compare_u64(left.slot, right.slot);
  if (result != 0) {
    return result;
  }
  return er_epoch_compare_u64(left.tick, right.tick);
}
