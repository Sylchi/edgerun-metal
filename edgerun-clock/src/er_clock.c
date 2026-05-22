#include "er_clock.h"

#include "er_bytes.h"

#include <stdint.h>

static int er_clock_limits_valid(const er_clock_limits_t* limits) {
  return limits != (const er_clock_limits_t*)0 &&
         limits->ticks_per_slot != 0u &&
         limits->slots_per_epoch != 0u &&
         limits->epochs_per_era != 0u;
}

static int er_clock_power_of_two(uint64_t value) {
  return value != 0u && (value & (value - 1u)) == 0u;
}

static int er_clock_limit_shift(uint64_t value, uint8_t* out_shift) {
  uint8_t shift = 0u;

  if (er_clock_power_of_two(value) == 0 ||
      out_shift == (uint8_t*)0) {
    return ER_CLOCK_ERR_BADARG;
  }
  while (value > 1u) {
    value >>= 1u;
    ++shift;
  }
  *out_shift = shift;
  return ER_CLOCK_OK;
}

static int er_clock_limits_power_of_two(const er_clock_limits_t* limits) {
  return er_clock_limits_valid(limits) != 0 &&
         er_clock_power_of_two(limits->ticks_per_slot) != 0 &&
         er_clock_power_of_two(limits->slots_per_epoch) != 0 &&
         er_clock_power_of_two(limits->epochs_per_era) != 0;
}

static int er_clock_modifier_valid(const er_clock_modifier_t* modifier) {
  return modifier != (const er_clock_modifier_t*)0 &&
         modifier->tick_stride != 0u;
}

static int er_clock_compare_u64(uint64_t left, uint64_t right) {
  if (left < right) {
    return -1;
  }
  if (left > right) {
    return 1;
  }
  return 0;
}

er_clock_limits_t er_clock_default_limits(void) {
  er_clock_limits_t limits;

  limits.ticks_per_slot = ER_CLOCK_DEFAULT_TICKS_PER_SLOT;
  limits.slots_per_epoch = ER_CLOCK_DEFAULT_SLOTS_PER_EPOCH;
  limits.epochs_per_era = ER_CLOCK_DEFAULT_EPOCHS_PER_ERA;
  return limits;
}

er_clock_modifier_t er_clock_default_modifier(void) {
  er_clock_modifier_t modifier;

  modifier.tick_stride = ER_CLOCK_DEFAULT_STRIDE;
  return modifier;
}

int er_clock_keeper_id_valid(const er_clock_keeper_id_t* keeper_id) {
  if (keeper_id == (const er_clock_keeper_id_t*)0) {
    return 0;
  }
  return er_bytes_nonzero(keeper_id->bytes, ER_CLOCK_KEEPER_ID_SIZE);
}

int er_clock_keeper_id_equal(const er_clock_keeper_id_t* left,
                             const er_clock_keeper_id_t* right) {
  if (er_clock_keeper_id_valid(left) == 0 ||
      er_clock_keeper_id_valid(right) == 0) {
    return 0;
  }
  return er_bytes_compare(left->bytes, right->bytes,
                                ER_CLOCK_KEEPER_ID_SIZE) == 0;
}

int er_clock_stamp_valid(er_clock_epoch_stamp_t stamp) {
  return er_clock_keeper_id_valid(&stamp.keeper_id);
}

int er_clock_stamp_same_keeper(er_clock_epoch_stamp_t left,
                               er_clock_epoch_stamp_t right) {
  return er_clock_keeper_id_equal(&left.keeper_id, &right.keeper_id);
}

int er_clock_stamp_compare(er_clock_epoch_stamp_t left,
                           er_clock_epoch_stamp_t right) {
  int result;

  result = er_bytes_compare(left.keeper_id.bytes, right.keeper_id.bytes,
                                  ER_CLOCK_KEEPER_ID_SIZE);
  if (result != 0) {
    return result;
  }
  result = er_clock_compare_u64(left.era, right.era);
  if (result != 0) {
    return result;
  }
  result = er_clock_compare_u64(left.epoch, right.epoch);
  if (result != 0) {
    return result;
  }
  result = er_clock_compare_u64(left.slot, right.slot);
  if (result != 0) {
    return result;
  }
  return er_clock_compare_u64(left.tick, right.tick);
}

int er_clock_init(const er_clock_keeper_id_t* keeper_id,
                  const er_clock_limits_t* limits,
                  er_clock_t* out_clock) {
  uint8_t tick_shift = 0u;
  uint8_t slot_shift = 0u;
  uint8_t epoch_shift = 0u;

  if (out_clock == (er_clock_t*)0 ||
      er_clock_keeper_id_valid(keeper_id) == 0 ||
      er_clock_limits_power_of_two(limits) == 0 ||
      er_clock_limit_shift(limits->ticks_per_slot, &tick_shift) != ER_CLOCK_OK ||
      er_clock_limit_shift(limits->slots_per_epoch, &slot_shift) != ER_CLOCK_OK ||
      er_clock_limit_shift(limits->epochs_per_era, &epoch_shift) != ER_CLOCK_OK) {
    return ER_CLOCK_ERR_BADARG;
  }
  er_bytes_zero(out_clock, (uint64_t)sizeof(*out_clock));
  out_clock->now.keeper_id = *keeper_id;
  out_clock->limits = *limits;
  out_clock->tick_mask = limits->ticks_per_slot - 1u;
  out_clock->slot_mask = limits->slots_per_epoch - 1u;
  out_clock->epoch_mask = limits->epochs_per_era - 1u;
  out_clock->tick_shift = tick_shift;
  out_clock->slot_shift = slot_shift;
  out_clock->epoch_shift = epoch_shift;
  return ER_CLOCK_OK;
}

int er_clock_advance(er_clock_t* clock, er_clock_boundary_t* out_boundary) {
  er_clock_modifier_t modifier;

  modifier = er_clock_default_modifier();
  return er_clock_advance_with_modifier(clock, &modifier, out_boundary);
}

int er_clock_advance_with_modifier(er_clock_t* clock,
                                   const er_clock_modifier_t* modifier,
                                   er_clock_boundary_t* out_boundary) {
  uint64_t total_ticks;
  uint64_t slot_steps;
  uint64_t total_slots;
  uint64_t epoch_steps;
  uint64_t total_epochs;
  uint64_t era_steps;
  uint64_t next_tick;
  uint64_t next_slot;
  uint64_t next_epoch;
  uint64_t next_era;

  if (clock == (er_clock_t*)0 ||
      er_clock_limits_power_of_two(&clock->limits) == 0 ||
      er_clock_modifier_valid(modifier) == 0) {
    return ER_CLOCK_ERR_BADARG;
  }
  if (modifier->tick_stride > UINT64_MAX - clock->now.tick) {
    return ER_CLOCK_ERR_OVERFLOW;
  }
  if (out_boundary != (er_clock_boundary_t*)0) {
    er_bytes_zero(out_boundary, (uint64_t)sizeof(*out_boundary));
  }

  next_era = clock->now.era;
  next_epoch = clock->now.epoch;
  next_slot = clock->now.slot;
  total_ticks = clock->now.tick + modifier->tick_stride;
  next_tick = total_ticks & clock->tick_mask;
  slot_steps = total_ticks >> clock->tick_shift;
  if (slot_steps == 0u) {
    clock->now.tick = next_tick;
    return ER_CLOCK_OK;
  }
  if (slot_steps > UINT64_MAX - next_slot) {
    return ER_CLOCK_ERR_OVERFLOW;
  }

  total_slots = next_slot + slot_steps;
  next_slot = total_slots & clock->slot_mask;
  epoch_steps = total_slots >> clock->slot_shift;
  if (epoch_steps == 0u) {
    clock->now.tick = next_tick;
    clock->now.slot = next_slot;
    if (out_boundary != (er_clock_boundary_t*)0) {
      out_boundary->slot_boundary = 1u;
    }
    return ER_CLOCK_OK;
  }
  if (epoch_steps > UINT64_MAX - next_epoch) {
    return ER_CLOCK_ERR_OVERFLOW;
  }

  total_epochs = next_epoch + epoch_steps;
  next_epoch = total_epochs & clock->epoch_mask;
  era_steps = total_epochs >> clock->epoch_shift;
  if (era_steps == 0u) {
    clock->now.tick = next_tick;
    clock->now.slot = next_slot;
    clock->now.epoch = next_epoch;
    if (out_boundary != (er_clock_boundary_t*)0) {
      out_boundary->slot_boundary = 1u;
      out_boundary->epoch_boundary = 1u;
    }
    return ER_CLOCK_OK;
  }
  if (era_steps > UINT64_MAX - next_era) {
    return ER_CLOCK_ERR_OVERFLOW;
  }
  next_era += era_steps;
  clock->now.tick = next_tick;
  clock->now.slot = next_slot;
  clock->now.epoch = next_epoch;
  clock->now.era = next_era;
  if (out_boundary != (er_clock_boundary_t*)0) {
    out_boundary->slot_boundary = 1u;
    out_boundary->epoch_boundary = 1u;
    out_boundary->era_boundary = 1u;
  }
  return ER_CLOCK_OK;
}
