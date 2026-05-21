#ifndef ER_CLOCK_H
#define ER_CLOCK_H

/*
 * Purpose: define deterministic EdgeRun epoch time shared across devices.
 * Intention: give identity, object, admission, storage, and wire records one
 * replayable time coordinate that advances on accepted state transitions.
 */

#include <stdint.h>

#define ER_CLOCK_OK 0
#define ER_CLOCK_ERR_BADARG -1
#define ER_CLOCK_ERR_OVERFLOW -2

#define ER_CLOCK_DEFAULT_TICKS_PER_SLOT 1024u
#define ER_CLOCK_DEFAULT_SLOTS_PER_EPOCH 1024u
#define ER_CLOCK_DEFAULT_EPOCHS_PER_ERA 1024u
#define ER_CLOCK_DEFAULT_STRIDE 1u

typedef struct er_clock_epoch_stamp {
  uint64_t tick;
  uint64_t slot;
  uint64_t epoch;
  uint64_t era;
} er_clock_epoch_stamp_t;

typedef struct er_clock_limits {
  uint64_t ticks_per_slot;
  uint64_t slots_per_epoch;
  uint64_t epochs_per_era;
} er_clock_limits_t;

typedef struct er_clock_boundary {
  uint8_t slot_boundary;
  uint8_t epoch_boundary;
  uint8_t era_boundary;
} er_clock_boundary_t;

typedef struct er_clock {
  er_clock_epoch_stamp_t now;
  er_clock_limits_t limits;
  uint64_t tick_mask;
  uint64_t slot_mask;
  uint64_t epoch_mask;
  uint8_t tick_shift;
  uint8_t slot_shift;
  uint8_t epoch_shift;
} er_clock_t;

typedef struct er_clock_modifier {
  uint64_t tick_stride;
} er_clock_modifier_t;

er_clock_limits_t er_clock_default_limits(void);
er_clock_modifier_t er_clock_default_modifier(void);
int er_clock_stamp_valid(er_clock_epoch_stamp_t stamp);
int er_clock_stamp_compare(er_clock_epoch_stamp_t left,
                           er_clock_epoch_stamp_t right);
int er_clock_init(const er_clock_limits_t* limits, er_clock_t* out_clock);
int er_clock_advance(er_clock_t* clock, er_clock_boundary_t* out_boundary);
int er_clock_advance_with_modifier(er_clock_t* clock,
                                   const er_clock_modifier_t* modifier,
                                   er_clock_boundary_t* out_boundary);

#endif
