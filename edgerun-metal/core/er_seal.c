#include "er_seal.h"

ErSealStrategy er_seal_select_strategy(UINT32 recipient_count,
                                       UINT64 plaintext_len,
                                       UINT32 expected_reuse_count) {
  if (recipient_count == 0u || plaintext_len == 0u || expected_reuse_count == 0u) {
    return ER_SEAL_STRATEGY_INVALID;
  }

  if (recipient_count == ER_SEAL_RECIPIENT_COUNT_DIRECT &&
      plaintext_len < ER_SEAL_CONTENT_KEY_THRESHOLD_BYTES &&
      expected_reuse_count < ER_SEAL_CONTENT_KEY_REUSE_MIN) {
    return ER_SEAL_STRATEGY_DIRECT_RECIPIENT;
  }

  return ER_SEAL_STRATEGY_CONTENT_KEY_WRAP;
}

const char* er_seal_strategy_label(ErSealStrategy strategy) {
  switch (strategy) {
    case ER_SEAL_STRATEGY_DIRECT_RECIPIENT:
      return "direct-recipient";
    case ER_SEAL_STRATEGY_CONTENT_KEY_WRAP:
      return "content-key-wrap";
    case ER_SEAL_STRATEGY_INVALID:
    default:
      return "invalid";
  }
}
