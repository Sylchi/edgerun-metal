#include "er_epoch_clock.h"
#include "er_mem.h"

static UINT8 er_epoch_clock_limits_valid(const ErEpochClockLimits* limits) {
  return (UINT8)(limits != 0 &&
                 limits->ticks_per_slot != 0u &&
                 limits->slots_per_epoch != 0u &&
                 limits->epochs_per_era != 0u);
}

static UINT8 er_epoch_power_of_two(UINT64 value) {
  return (UINT8)(value != 0u && (value & (value - 1u)) == 0u);
}

static UINT8 er_epoch_limit_shift(UINT64 value, UINT8* out_shift) {
  UINT8 shift = 0u;

  if (er_epoch_power_of_two(value) == 0u || out_shift == 0) {
    return 0u;
  }
  while (value > 1u) {
    value >>= 1u;
    ++shift;
  }
  *out_shift = shift;
  return 1u;
}

static UINT8 er_epoch_clock_limits_power_of_two(const ErEpochClockLimits* limits) {
  return (UINT8)(er_epoch_clock_limits_valid(limits) != 0u &&
                 er_epoch_power_of_two(limits->ticks_per_slot) != 0u &&
                 er_epoch_power_of_two(limits->slots_per_epoch) != 0u &&
                 er_epoch_power_of_two(limits->epochs_per_era) != 0u);
}

static UINT8 er_epoch_clock_modifier_valid(const ErEpochClockModifier* modifier) {
  return (UINT8)(modifier != 0 && modifier->tick_stride != 0u);
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

ErEpochClockModifier er_epoch_clock_default_modifier(void) {
  ErEpochClockModifier modifier;

  modifier.tick_stride = ER_EPOCH_CLOCK_DEFAULT_STRIDE;
  return modifier;
}

UINT8 er_epoch_clock_init(const ErEpochClockLimits* limits, ErEpochClock* out_clock) {
  UINT8 tick_shift = 0u;
  UINT8 slot_shift = 0u;
  UINT8 epoch_shift = 0u;

  if (er_epoch_clock_limits_power_of_two(limits) == 0u || out_clock == 0 ||
      er_epoch_limit_shift(limits->ticks_per_slot, &tick_shift) == 0u ||
      er_epoch_limit_shift(limits->slots_per_epoch, &slot_shift) == 0u ||
      er_epoch_limit_shift(limits->epochs_per_era, &epoch_shift) == 0u) {
    return 0u;
  }
  er_mem_zero((UINT8*)out_clock, (UINTN)sizeof(*out_clock));
  out_clock->limits = *limits;
  out_clock->tick_mask = limits->ticks_per_slot - 1u;
  out_clock->slot_mask = limits->slots_per_epoch - 1u;
  out_clock->epoch_mask = limits->epochs_per_era - 1u;
  out_clock->tick_shift = tick_shift;
  out_clock->slot_shift = slot_shift;
  out_clock->epoch_shift = epoch_shift;
  return 1u;
}

UINT8 er_epoch_clock_advance(ErEpochClock* clock, ErEpochBoundary* out_boundary) {
  ErEpochClockModifier modifier;

  modifier = er_epoch_clock_default_modifier();
  return er_epoch_clock_advance_with_modifier(clock, &modifier, out_boundary);
}

UINT8 er_epoch_clock_advance_with_modifier(ErEpochClock* clock,
                                           const ErEpochClockModifier* modifier,
                                           ErEpochBoundary* out_boundary) {
  UINT64 total_ticks;
  UINT64 slot_steps;
  UINT64 total_slots;
  UINT64 epoch_steps;
  UINT64 total_epochs;
  UINT64 era_steps;
  UINT64 next_tick;
  UINT64 next_slot;
  UINT64 next_epoch;
  UINT64 next_era;

  if (clock == 0 || er_epoch_clock_limits_power_of_two(&clock->limits) == 0u) {
    return 0u;
  }
  if (er_epoch_clock_modifier_valid(modifier) == 0u) {
    return 0u;
  }
  if (modifier->tick_stride > UINT64_MAX - clock->now.tick) {
    return 0u;
  }
  if (out_boundary != 0) {
    er_mem_zero((UINT8*)out_boundary, (UINTN)sizeof(*out_boundary));
  }

  next_era = clock->now.era;
  next_epoch = clock->now.epoch;
  next_slot = clock->now.slot;
  total_ticks = clock->now.tick + modifier->tick_stride;
  next_tick = total_ticks & clock->tick_mask;
  slot_steps = total_ticks >> clock->tick_shift;
  if (slot_steps == 0u) {
    clock->now.tick = next_tick;
    return 1u;
  }
  if (slot_steps > UINT64_MAX - next_slot) {
    return 0u;
  }

  total_slots = next_slot + slot_steps;
  next_slot = total_slots & clock->slot_mask;
  epoch_steps = total_slots >> clock->slot_shift;
  if (epoch_steps == 0u) {
    clock->now.tick = next_tick;
    clock->now.slot = next_slot;
    if (out_boundary != 0) {
      out_boundary->slot_boundary = 1u;
    }
    return 1u;
  }
  if (epoch_steps > UINT64_MAX - next_epoch) {
    return 0u;
  }

  total_epochs = next_epoch + epoch_steps;
  next_epoch = total_epochs & clock->epoch_mask;
  era_steps = total_epochs >> clock->epoch_shift;
  if (era_steps == 0u) {
    clock->now.tick = next_tick;
    clock->now.slot = next_slot;
    clock->now.epoch = next_epoch;
    if (out_boundary != 0) {
      out_boundary->slot_boundary = 1u;
      out_boundary->epoch_boundary = 1u;
    }
    return 1u;
  }
  if (era_steps > UINT64_MAX - next_era) {
    return 0u;
  }
  next_era += era_steps;
  clock->now.tick = next_tick;
  clock->now.slot = next_slot;
  clock->now.epoch = next_epoch;
  clock->now.era = next_era;
  if (out_boundary != 0) {
    out_boundary->slot_boundary = 1u;
    out_boundary->epoch_boundary = 1u;
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
