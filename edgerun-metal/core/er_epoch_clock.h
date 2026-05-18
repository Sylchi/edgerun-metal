#ifndef ER_EPOCH_CLOCK_H
#define ER_EPOCH_CLOCK_H

#include "er_types.h"

/*
 * Purpose: provide deterministic nested accounting time for replayable settlement loops.
 * Intention: advance on accepted state transitions instead of trusting wall-clock time.
 */

#define ER_EPOCH_CLOCK_DEFAULT_TICKS_PER_SLOT 1024u
#define ER_EPOCH_CLOCK_DEFAULT_SLOTS_PER_EPOCH 1024u
#define ER_EPOCH_CLOCK_DEFAULT_EPOCHS_PER_ERA 1024u
#define ER_EPOCH_CLOCK_DEFAULT_STRIDE 1u

typedef struct {
  UINT64 tick;
  UINT64 slot;
  UINT64 epoch;
  UINT64 era;
} ErEpochStamp;

typedef struct {
  UINT64 ticks_per_slot;
  UINT64 slots_per_epoch;
  UINT64 epochs_per_era;
} ErEpochClockLimits;

typedef struct {
  UINT8 slot_boundary;
  UINT8 epoch_boundary;
  UINT8 era_boundary;
} ErEpochBoundary;

typedef struct {
  ErEpochStamp now;
  ErEpochClockLimits limits;
  UINT64 tick_mask;
  UINT64 slot_mask;
  UINT64 epoch_mask;
  UINT8 tick_shift;
  UINT8 slot_shift;
  UINT8 epoch_shift;
} ErEpochClock;

typedef struct {
  UINT64 tick_stride;
} ErEpochClockModifier;

ErEpochClockLimits er_epoch_clock_default_limits(void);
ErEpochClockModifier er_epoch_clock_default_modifier(void);
UINT8 er_epoch_clock_init(const ErEpochClockLimits* limits, ErEpochClock* out_clock);
UINT8 er_epoch_clock_advance(ErEpochClock* clock, ErEpochBoundary* out_boundary);
UINT8 er_epoch_clock_advance_with_modifier(ErEpochClock* clock,
                                           const ErEpochClockModifier* modifier,
                                           ErEpochBoundary* out_boundary);
INT32 er_epoch_stamp_compare(ErEpochStamp left, ErEpochStamp right);

#endif
