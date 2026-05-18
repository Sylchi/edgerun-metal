#ifndef ER_SEAL_H
#define ER_SEAL_H

/*
 * Purpose: choose recipient-sealing envelope shape before crypto implementation details.
 * Intention: encrypt payload bytes once when fanout or durable reuse would make per-recipient sealing wasteful.
 */

#include "er_types.h"

#define ER_SEAL_CONTENT_KEY_THRESHOLD_BYTES 4096u
#define ER_SEAL_CONTENT_KEY_REUSE_MIN 2u
#define ER_SEAL_RECIPIENT_COUNT_DIRECT 1u

typedef enum {
  ER_SEAL_STRATEGY_INVALID = 0,
  ER_SEAL_STRATEGY_DIRECT_RECIPIENT = 1,
  ER_SEAL_STRATEGY_CONTENT_KEY_WRAP = 2
} ErSealStrategy;

ErSealStrategy er_seal_select_strategy(UINT32 recipient_count,
                                       UINT64 plaintext_len,
                                       UINT32 expected_reuse_count);
const char* er_seal_strategy_label(ErSealStrategy strategy);

#endif
