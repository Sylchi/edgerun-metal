#include "er_blake3.h"

#if !defined(ER_BLAKE3_NO_SIMD) && defined(__SSE2__) && \
    (defined(__x86_64__) || defined(_M_X64) || defined(__i386) || defined(_M_IX86))
#include <emmintrin.h>
#define ER_BLAKE3_USE_SSE2 1
#endif

#define ER_BLAKE3_CHUNK_START 1u
#define ER_BLAKE3_CHUNK_END 2u
#define ER_BLAKE3_PARENT 4u
#define ER_BLAKE3_ROOT 8u
#define ER_BLAKE3_CV_WORDS 8u
#define ER_BLAKE3_BLOCK_WORDS 16u
#define ER_BLAKE3_WORD_BITS 32u
#define ER_BLAKE3_WORD_BYTES 4u
#define ER_BLAKE3_COMPRESS_ROUNDS 7u
#define ER_BLAKE3_LAST_PERMUTE_ROUND 6u
#define ER_BLAKE3_WORD_BYTE1_SHIFT 8u
#define ER_BLAKE3_WORD_BYTE2_SHIFT 16u
#define ER_BLAKE3_WORD_BYTE3_SHIFT 24u
#define ER_BLAKE3_WORD_BYTE0_INDEX 0u
#define ER_BLAKE3_WORD_BYTE1_INDEX 1u
#define ER_BLAKE3_WORD_BYTE2_INDEX 2u
#define ER_BLAKE3_WORD_BYTE3_INDEX 3u
#define ER_BLAKE3_COUNTER_HIGH_SHIFT 32u
#define ER_BLAKE3_STATE_IV0_INDEX 8u
#define ER_BLAKE3_STATE_IV1_INDEX 9u
#define ER_BLAKE3_STATE_IV2_INDEX 10u
#define ER_BLAKE3_STATE_IV3_INDEX 11u
#define ER_BLAKE3_STATE_COUNTER_LOW_INDEX 12u
#define ER_BLAKE3_STATE_COUNTER_HIGH_INDEX 13u
#define ER_BLAKE3_STATE_BLOCK_LEN_INDEX 14u
#define ER_BLAKE3_STATE_FLAGS_INDEX 15u
#define ER_BLAKE3_SSE2_LANE0_INDEX 0u
#define ER_BLAKE3_SSE2_LANE1_INDEX 1u
#define ER_BLAKE3_SSE2_LANE2_INDEX 2u
#define ER_BLAKE3_SSE2_LANE3_INDEX 3u
#define ER_BLAKE3_ROTATE_A 16u
#define ER_BLAKE3_ROTATE_B 12u
#define ER_BLAKE3_ROTATE_C 8u
#define ER_BLAKE3_ROTATE_D 7u
#define ER_BLAKE3_IV0 0x6a09e667u
#define ER_BLAKE3_IV1 0xbb67ae85u
#define ER_BLAKE3_IV2 0x3c6ef372u
#define ER_BLAKE3_IV3 0xa54ff53au
#define ER_BLAKE3_IV4 0x510e527fu
#define ER_BLAKE3_IV5 0x9b05688cu
#define ER_BLAKE3_IV6 0x1f83d9abu
#define ER_BLAKE3_IV7 0x5be0cd19u
#define ER_BLAKE3_FULL_CHUNK_BLOCKS (ER_BLAKE3_CHUNK_LEN / ER_BLAKE3_BLOCK_LEN)
#define ER_BLAKE3_SSE2_LANES 4u

static const uint32_t g_er_blake3_iv[ER_BLAKE3_CV_WORDS] = {
  ER_BLAKE3_IV0, ER_BLAKE3_IV1, ER_BLAKE3_IV2, ER_BLAKE3_IV3,
  ER_BLAKE3_IV4, ER_BLAKE3_IV5, ER_BLAKE3_IV6, ER_BLAKE3_IV7
};

static const uint8_t g_er_blake3_msg_perm[ER_BLAKE3_BLOCK_WORDS] = {
  2u, 6u, 3u, 10u, 7u, 0u, 4u, 13u, 1u, 11u, 12u, 5u, 9u, 14u, 15u, 8u //@optimizer-ignore BLAKE3 message word permutation
};

typedef struct {
  uint32_t input_cv[ER_BLAKE3_CV_WORDS];
  uint8_t block[ER_BLAKE3_BLOCK_LEN];
  uint64_t counter;
  uint32_t block_len;
  uint32_t flags;
} ErBlake3Output;

static void er_blake3_zero(uint8_t* bytes, size_t len) {
  size_t i;

  if (bytes == 0) {
    return;
  }
  for (i = 0u; i < len; ++i) {
    bytes[i] = 0u;
  }
}

static void er_blake3_copy(uint8_t* dst, const uint8_t* src, size_t len) {
  size_t i;

  if (dst == 0 || src == 0) {
    return;
  }
  for (i = 0u; i < len; ++i) {
    dst[i] = src[i];
  }
}

static uint32_t er_blake3_rotr32(uint32_t word, uint32_t bits) {
  return (word >> bits) | (word << (ER_BLAKE3_WORD_BITS - bits));
}

static uint32_t er_blake3_load32(const uint8_t* bytes) {
  return ((uint32_t)bytes[ER_BLAKE3_WORD_BYTE0_INDEX]) |
         ((uint32_t)bytes[ER_BLAKE3_WORD_BYTE1_INDEX] << ER_BLAKE3_WORD_BYTE1_SHIFT) |
         ((uint32_t)bytes[ER_BLAKE3_WORD_BYTE2_INDEX] << ER_BLAKE3_WORD_BYTE2_SHIFT) |
         ((uint32_t)bytes[ER_BLAKE3_WORD_BYTE3_INDEX] << ER_BLAKE3_WORD_BYTE3_SHIFT);
}

static void er_blake3_store32(uint8_t* bytes, uint32_t word) {
  bytes[ER_BLAKE3_WORD_BYTE0_INDEX] = (uint8_t)word;
  bytes[ER_BLAKE3_WORD_BYTE1_INDEX] = (uint8_t)(word >> ER_BLAKE3_WORD_BYTE1_SHIFT);
  bytes[ER_BLAKE3_WORD_BYTE2_INDEX] = (uint8_t)(word >> ER_BLAKE3_WORD_BYTE2_SHIFT);
  bytes[ER_BLAKE3_WORD_BYTE3_INDEX] = (uint8_t)(word >> ER_BLAKE3_WORD_BYTE3_SHIFT);
}

static void er_blake3_words_from_block(const uint8_t block[ER_BLAKE3_BLOCK_LEN],
                                       uint32_t words[ER_BLAKE3_BLOCK_WORDS]) {
  size_t i;

  for (i = 0u; i < ER_BLAKE3_BLOCK_WORDS; ++i) {
    words[i] = er_blake3_load32(&block[i * ER_BLAKE3_WORD_BYTES]);
  }
}

static void er_blake3_g(uint32_t state[ER_BLAKE3_BLOCK_WORDS], size_t a, size_t b, size_t c, size_t d,
                        uint32_t mx, uint32_t my) {
  state[a] = state[a] + state[b] + mx;
  state[d] = er_blake3_rotr32(state[d] ^ state[a], ER_BLAKE3_ROTATE_A);
  state[c] = state[c] + state[d];
  state[b] = er_blake3_rotr32(state[b] ^ state[c], ER_BLAKE3_ROTATE_B);
  state[a] = state[a] + state[b] + my;
  state[d] = er_blake3_rotr32(state[d] ^ state[a], ER_BLAKE3_ROTATE_C);
  state[c] = state[c] + state[d];
  state[b] = er_blake3_rotr32(state[b] ^ state[c], ER_BLAKE3_ROTATE_D);
}

static void er_blake3_round(uint32_t state[ER_BLAKE3_BLOCK_WORDS], const uint32_t msg[ER_BLAKE3_BLOCK_WORDS]) {
  er_blake3_g(state, 0u, 4u, 8u, 12u, msg[0], msg[1]); //@optimizer-ignore BLAKE3 compression schedule
  er_blake3_g(state, 1u, 5u, 9u, 13u, msg[2], msg[3]); //@optimizer-ignore BLAKE3 compression schedule
  er_blake3_g(state, 2u, 6u, 10u, 14u, msg[4], msg[5]); //@optimizer-ignore BLAKE3 compression schedule
  er_blake3_g(state, 3u, 7u, 11u, 15u, msg[6], msg[7]); //@optimizer-ignore BLAKE3 compression schedule
  er_blake3_g(state, 0u, 5u, 10u, 15u, msg[8], msg[9]); //@optimizer-ignore BLAKE3 compression schedule
  er_blake3_g(state, 1u, 6u, 11u, 12u, msg[10], msg[11]); //@optimizer-ignore BLAKE3 compression schedule
  er_blake3_g(state, 2u, 7u, 8u, 13u, msg[12], msg[13]); //@optimizer-ignore BLAKE3 compression schedule
  er_blake3_g(state, 3u, 4u, 9u, 14u, msg[14], msg[15]); //@optimizer-ignore BLAKE3 compression schedule
}

static void er_blake3_permute(uint32_t msg[ER_BLAKE3_BLOCK_WORDS]) {
  uint32_t permuted[ER_BLAKE3_BLOCK_WORDS];
  size_t i;

  for (i = 0u; i < ER_BLAKE3_BLOCK_WORDS; ++i) {
    permuted[i] = msg[g_er_blake3_msg_perm[i]];
  }
  for (i = 0u; i < ER_BLAKE3_BLOCK_WORDS; ++i) {
    msg[i] = permuted[i];
  }
}

static void er_blake3_compress(const uint32_t cv[ER_BLAKE3_CV_WORDS],
                               const uint32_t block_words[ER_BLAKE3_BLOCK_WORDS],
                               uint64_t counter, uint32_t block_len, uint32_t flags,
                               uint32_t out[ER_BLAKE3_BLOCK_WORDS]) {
  uint32_t msg[ER_BLAKE3_BLOCK_WORDS];
  size_t round;
  size_t i;

  for (i = 0u; i < ER_BLAKE3_CV_WORDS; ++i) {
    out[i] = cv[i];
    msg[i] = block_words[i];
    msg[i + ER_BLAKE3_CV_WORDS] = block_words[i + ER_BLAKE3_CV_WORDS];
  }
  out[ER_BLAKE3_STATE_IV0_INDEX] = g_er_blake3_iv[0];
  out[ER_BLAKE3_STATE_IV1_INDEX] = g_er_blake3_iv[1];
  out[ER_BLAKE3_STATE_IV2_INDEX] = g_er_blake3_iv[2];
  out[ER_BLAKE3_STATE_IV3_INDEX] = g_er_blake3_iv[3];
  out[ER_BLAKE3_STATE_COUNTER_LOW_INDEX] = (uint32_t)counter;
  out[ER_BLAKE3_STATE_COUNTER_HIGH_INDEX] = (uint32_t)(counter >> ER_BLAKE3_COUNTER_HIGH_SHIFT);
  out[ER_BLAKE3_STATE_BLOCK_LEN_INDEX] = block_len;
  out[ER_BLAKE3_STATE_FLAGS_INDEX] = flags;

  for (round = 0u; round < ER_BLAKE3_COMPRESS_ROUNDS; ++round) {
    er_blake3_round(out, msg);
    if (round != ER_BLAKE3_LAST_PERMUTE_ROUND) {
      er_blake3_permute(msg);
    }
  }

  for (i = 0u; i < ER_BLAKE3_CV_WORDS; ++i) {
    out[i] ^= out[i + ER_BLAKE3_CV_WORDS];
    out[i + ER_BLAKE3_CV_WORDS] ^= cv[i];
  }
}

static void er_blake3_compress_cv(const uint32_t cv[ER_BLAKE3_CV_WORDS],
                                  const uint8_t block[ER_BLAKE3_BLOCK_LEN],
                                  uint64_t counter, uint32_t block_len, uint32_t flags,
                                  uint32_t out_cv[ER_BLAKE3_CV_WORDS]) {
  uint32_t block_words[ER_BLAKE3_BLOCK_WORDS];
  uint32_t compressed[ER_BLAKE3_BLOCK_WORDS];
  size_t i;

  er_blake3_words_from_block(block, block_words);
  er_blake3_compress(cv, block_words, counter, block_len, flags, compressed);
  for (i = 0u; i < ER_BLAKE3_CV_WORDS; ++i) {
    out_cv[i] = compressed[i];
  }
}

#if defined(ER_BLAKE3_USE_SSE2)
static __m128i er_blake3_sse2_rotr32(__m128i word, int bits) {
  return _mm_or_si128(_mm_srli_epi32(word, bits), _mm_slli_epi32(word, 32 - bits));
}

static void er_blake3_sse2_g(__m128i state[ER_BLAKE3_BLOCK_WORDS], size_t a, size_t b, size_t c, size_t d,
                             __m128i mx, __m128i my) {
  state[a] = _mm_add_epi32(_mm_add_epi32(state[a], state[b]), mx);
  state[d] = er_blake3_sse2_rotr32(_mm_xor_si128(state[d], state[a]), ER_BLAKE3_ROTATE_A);
  state[c] = _mm_add_epi32(state[c], state[d]);
  state[b] = er_blake3_sse2_rotr32(_mm_xor_si128(state[b], state[c]), ER_BLAKE3_ROTATE_B);
  state[a] = _mm_add_epi32(_mm_add_epi32(state[a], state[b]), my);
  state[d] = er_blake3_sse2_rotr32(_mm_xor_si128(state[d], state[a]), ER_BLAKE3_ROTATE_C);
  state[c] = _mm_add_epi32(state[c], state[d]);
  state[b] = er_blake3_sse2_rotr32(_mm_xor_si128(state[b], state[c]), ER_BLAKE3_ROTATE_D);
}

static void er_blake3_sse2_round(__m128i state[ER_BLAKE3_BLOCK_WORDS], const __m128i msg[ER_BLAKE3_BLOCK_WORDS]) {
  er_blake3_sse2_g(state, 0u, 4u, 8u, 12u, msg[0], msg[1]); //@optimizer-ignore BLAKE3 compression schedule
  er_blake3_sse2_g(state, 1u, 5u, 9u, 13u, msg[2], msg[3]); //@optimizer-ignore BLAKE3 compression schedule
  er_blake3_sse2_g(state, 2u, 6u, 10u, 14u, msg[4], msg[5]); //@optimizer-ignore BLAKE3 compression schedule
  er_blake3_sse2_g(state, 3u, 7u, 11u, 15u, msg[6], msg[7]); //@optimizer-ignore BLAKE3 compression schedule
  er_blake3_sse2_g(state, 0u, 5u, 10u, 15u, msg[8], msg[9]); //@optimizer-ignore BLAKE3 compression schedule
  er_blake3_sse2_g(state, 1u, 6u, 11u, 12u, msg[10], msg[11]); //@optimizer-ignore BLAKE3 compression schedule
  er_blake3_sse2_g(state, 2u, 7u, 8u, 13u, msg[12], msg[13]); //@optimizer-ignore BLAKE3 compression schedule
  er_blake3_sse2_g(state, 3u, 4u, 9u, 14u, msg[14], msg[15]); //@optimizer-ignore BLAKE3 compression schedule
}

static void er_blake3_sse2_permute(__m128i msg[ER_BLAKE3_BLOCK_WORDS]) {
  __m128i permuted[ER_BLAKE3_BLOCK_WORDS];
  size_t i;

  for (i = 0u; i < ER_BLAKE3_BLOCK_WORDS; ++i) {
    permuted[i] = msg[g_er_blake3_msg_perm[i]];
  }
  for (i = 0u; i < ER_BLAKE3_BLOCK_WORDS; ++i) {
    msg[i] = permuted[i];
  }
}

static __m128i er_blake3_sse2_load_word4(const uint8_t* bytes, size_t word_index) {
  return _mm_set_epi32((int)er_blake3_load32(&bytes[(ER_BLAKE3_SSE2_LANE3_INDEX * ER_BLAKE3_CHUNK_LEN) + (word_index * ER_BLAKE3_WORD_BYTES)]),
                       (int)er_blake3_load32(&bytes[(ER_BLAKE3_SSE2_LANE2_INDEX * ER_BLAKE3_CHUNK_LEN) + (word_index * ER_BLAKE3_WORD_BYTES)]),
                       (int)er_blake3_load32(&bytes[(ER_BLAKE3_SSE2_LANE1_INDEX * ER_BLAKE3_CHUNK_LEN) + (word_index * ER_BLAKE3_WORD_BYTES)]),
                       (int)er_blake3_load32(&bytes[(ER_BLAKE3_SSE2_LANE0_INDEX * ER_BLAKE3_CHUNK_LEN) + (word_index * ER_BLAKE3_WORD_BYTES)]));
}

static void er_blake3_sse2_compress4(const __m128i cv[ER_BLAKE3_CV_WORDS],
                                     const __m128i block_words[ER_BLAKE3_BLOCK_WORDS],
                                     __m128i counter_low, __m128i counter_high,
                                     uint32_t block_len, uint32_t flags,
                                     __m128i out[ER_BLAKE3_BLOCK_WORDS]) {
  __m128i msg[ER_BLAKE3_BLOCK_WORDS];
  size_t round;
  size_t i;

  for (i = 0u; i < ER_BLAKE3_CV_WORDS; ++i) {
    out[i] = cv[i];
    msg[i] = block_words[i];
    msg[i + ER_BLAKE3_CV_WORDS] = block_words[i + ER_BLAKE3_CV_WORDS];
  }
  out[ER_BLAKE3_STATE_IV0_INDEX] = _mm_set1_epi32((int)g_er_blake3_iv[0]);
  out[ER_BLAKE3_STATE_IV1_INDEX] = _mm_set1_epi32((int)g_er_blake3_iv[1]);
  out[ER_BLAKE3_STATE_IV2_INDEX] = _mm_set1_epi32((int)g_er_blake3_iv[2]);
  out[ER_BLAKE3_STATE_IV3_INDEX] = _mm_set1_epi32((int)g_er_blake3_iv[3]);
  out[ER_BLAKE3_STATE_COUNTER_LOW_INDEX] = counter_low;
  out[ER_BLAKE3_STATE_COUNTER_HIGH_INDEX] = counter_high;
  out[ER_BLAKE3_STATE_BLOCK_LEN_INDEX] = _mm_set1_epi32((int)block_len);
  out[ER_BLAKE3_STATE_FLAGS_INDEX] = _mm_set1_epi32((int)flags);

  for (round = 0u; round < ER_BLAKE3_COMPRESS_ROUNDS; ++round) {
    er_blake3_sse2_round(out, msg);
    if (round != ER_BLAKE3_LAST_PERMUTE_ROUND) {
      er_blake3_sse2_permute(msg);
    }
  }

  for (i = 0u; i < ER_BLAKE3_CV_WORDS; ++i) {
    out[i] = _mm_xor_si128(out[i], out[i + ER_BLAKE3_CV_WORDS]);
    out[i + ER_BLAKE3_CV_WORDS] = _mm_xor_si128(out[i + ER_BLAKE3_CV_WORDS], cv[i]);
  }
}

static void er_blake3_sse2_compress4_full_chunks(const uint8_t* bytes, uint64_t chunk_counter,
                                                 uint32_t flags,
                                                 uint32_t out_cvs[ER_BLAKE3_SSE2_LANES][ER_BLAKE3_CV_WORDS]) {
  __m128i cv[ER_BLAKE3_CV_WORDS];
  __m128i words[ER_BLAKE3_BLOCK_WORDS];
  __m128i compressed[ER_BLAKE3_BLOCK_WORDS];
  uint32_t block_flags;
  uint32_t lanes[ER_BLAKE3_SSE2_LANES];
  size_t block;
  size_t word;
  size_t lane;

  for (word = 0u; word < ER_BLAKE3_CV_WORDS; ++word) {
    cv[word] = _mm_set1_epi32((int)g_er_blake3_iv[word]);
  }

  for (block = 0u; block < ER_BLAKE3_FULL_CHUNK_BLOCKS; ++block) {
    for (word = 0u; word < ER_BLAKE3_BLOCK_WORDS; ++word) {
      words[word] = er_blake3_sse2_load_word4(&bytes[block * ER_BLAKE3_BLOCK_LEN], word);
    }
    block_flags = flags;
    if (block == 0u) {
      block_flags |= ER_BLAKE3_CHUNK_START;
    }
    if (block == (ER_BLAKE3_FULL_CHUNK_BLOCKS - 1u)) {
      block_flags |= ER_BLAKE3_CHUNK_END;
    }
    er_blake3_sse2_compress4(cv, words,
                             _mm_set_epi32((int)(uint32_t)(chunk_counter + ER_BLAKE3_SSE2_LANE3_INDEX),
                                           (int)(uint32_t)(chunk_counter + ER_BLAKE3_SSE2_LANE2_INDEX),
                                           (int)(uint32_t)(chunk_counter + ER_BLAKE3_SSE2_LANE1_INDEX),
                                           (int)(uint32_t)chunk_counter),
                             _mm_set_epi32((int)(uint32_t)((chunk_counter + ER_BLAKE3_SSE2_LANE3_INDEX) >> ER_BLAKE3_COUNTER_HIGH_SHIFT),
                                           (int)(uint32_t)((chunk_counter + ER_BLAKE3_SSE2_LANE2_INDEX) >> ER_BLAKE3_COUNTER_HIGH_SHIFT),
                                           (int)(uint32_t)((chunk_counter + ER_BLAKE3_SSE2_LANE1_INDEX) >> ER_BLAKE3_COUNTER_HIGH_SHIFT),
                                           (int)(uint32_t)(chunk_counter >> ER_BLAKE3_COUNTER_HIGH_SHIFT)),
                             ER_BLAKE3_BLOCK_LEN, block_flags, compressed);
    for (word = 0u; word < ER_BLAKE3_CV_WORDS; ++word) {
      cv[word] = compressed[word];
    }
  }

  for (word = 0u; word < ER_BLAKE3_CV_WORDS; ++word) {
    _mm_storeu_si128((__m128i*)lanes, cv[word]);
    for (lane = 0u; lane < ER_BLAKE3_SSE2_LANES; ++lane) {
      out_cvs[lane][word] = lanes[lane];
    }
  }
}
#endif

static void er_blake3_parent_block(const uint32_t left_cv[ER_BLAKE3_CV_WORDS],
                                   const uint32_t right_cv[ER_BLAKE3_CV_WORDS],
                                   uint8_t block[ER_BLAKE3_BLOCK_LEN]) {
  size_t i;

  for (i = 0u; i < ER_BLAKE3_CV_WORDS; ++i) {
    er_blake3_store32(&block[i * ER_BLAKE3_WORD_BYTES], left_cv[i]);
    er_blake3_store32(&block[(i + ER_BLAKE3_CV_WORDS) * ER_BLAKE3_WORD_BYTES], right_cv[i]);
  }
}

static void er_blake3_parent_cv(const uint32_t left_cv[ER_BLAKE3_CV_WORDS],
                                const uint32_t right_cv[ER_BLAKE3_CV_WORDS],
                                uint32_t out_cv[ER_BLAKE3_CV_WORDS]) {
  uint8_t block[ER_BLAKE3_BLOCK_LEN];

  er_blake3_parent_block(left_cv, right_cv, block);
  er_blake3_compress_cv(g_er_blake3_iv, block, 0u, ER_BLAKE3_BLOCK_LEN, ER_BLAKE3_PARENT, out_cv);
}

static void er_blake3_output_cv(const ErBlake3Output* output, uint32_t out_cv[ER_BLAKE3_CV_WORDS]) {
  er_blake3_compress_cv(output->input_cv, output->block, output->counter,
                        output->block_len, output->flags, out_cv);
}

static void er_blake3_output_root(const ErBlake3Output* output, uint8_t out[ER_BLAKE3_OUT_LEN]) {
  uint32_t block_words[ER_BLAKE3_BLOCK_WORDS];
  uint32_t words[ER_BLAKE3_BLOCK_WORDS];
  size_t i;

  er_blake3_words_from_block(output->block, block_words);
  er_blake3_compress(output->input_cv, block_words, output->counter, output->block_len,
                     output->flags | ER_BLAKE3_ROOT, words);
  for (i = 0u; i < ER_BLAKE3_CV_WORDS; ++i) {
    er_blake3_store32(&out[i * ER_BLAKE3_WORD_BYTES], words[i]);
  }
}

static void er_blake3_copy_cv(uint32_t dst[ER_BLAKE3_CV_WORDS], const uint32_t src[ER_BLAKE3_CV_WORDS]) {
  size_t i;

  for (i = 0u; i < ER_BLAKE3_CV_WORDS; ++i) {
    dst[i] = src[i];
  }
}

static void er_blake3_reset_chunk(ErBlake3Hasher* hasher) {
  er_blake3_copy_cv(hasher->chunk_cv, hasher->key);
  er_blake3_zero(hasher->block, ER_BLAKE3_BLOCK_LEN);
  hasher->block_len = 0u;
  hasher->blocks_compressed = 0u;
}

static uint8_t er_blake3_push_cv(ErBlake3Hasher* hasher,
                                 const uint32_t input_cv[ER_BLAKE3_CV_WORDS],
                                 uint64_t total_chunks) {
  uint32_t cv[ER_BLAKE3_CV_WORDS];

  er_blake3_copy_cv(cv, input_cv);
  while ((total_chunks & 1u) == 0u) {
    if (hasher->cv_stack_len == 0u) {
      return 0u;
    }
    er_blake3_parent_cv(hasher->cv_stack[hasher->cv_stack_len - 1u], cv, cv);
    --hasher->cv_stack_len;
    total_chunks >>= 1u;
  }
  if (hasher->cv_stack_len >= ER_BLAKE3_MAX_DEPTH) {
    return 0u;
  }
  er_blake3_copy_cv(hasher->cv_stack[hasher->cv_stack_len], cv);
  ++hasher->cv_stack_len;
  return 1u;
}

static uint8_t er_blake3_finish_chunk(ErBlake3Hasher* hasher) {
  uint32_t flags = hasher->flags | ER_BLAKE3_CHUNK_END;
  uint32_t chunk_cv[ER_BLAKE3_CV_WORDS];

  if (hasher->blocks_compressed == 0u) {
    flags |= ER_BLAKE3_CHUNK_START;
  }
  er_blake3_compress_cv(hasher->chunk_cv, hasher->block, hasher->chunk_counter,
                        (uint32_t)hasher->block_len, flags, chunk_cv);
  ++hasher->chunk_counter;
  if (er_blake3_push_cv(hasher, chunk_cv, hasher->chunk_counter) == 0u) {
    return 0u;
  }
  er_blake3_reset_chunk(hasher);
  return 1u;
}

static size_t er_blake3_chunk_len(const ErBlake3Hasher* hasher) {
  return ((size_t)hasher->blocks_compressed * ER_BLAKE3_BLOCK_LEN) + hasher->block_len;
}

void er_blake3_init(ErBlake3Hasher* hasher) {
  if (hasher == 0) {
    return;
  }
  er_blake3_zero((uint8_t*)hasher, sizeof(*hasher));
  er_blake3_copy_cv(hasher->key, g_er_blake3_iv);
  er_blake3_reset_chunk(hasher);
}

uint8_t er_blake3_update(ErBlake3Hasher* hasher, const uint8_t* bytes, size_t len) {
  size_t take;
  uint32_t flags;

  if (hasher == 0 || (len > 0u && bytes == 0)) {
    return 0u;
  }

  while (len > 0u) {
#if defined(ER_BLAKE3_USE_SSE2)
    if (hasher->block_len == 0u && hasher->blocks_compressed == 0u &&
        len > (ER_BLAKE3_SSE2_LANES * ER_BLAKE3_CHUNK_LEN)) {
      uint32_t cvs[ER_BLAKE3_SSE2_LANES][ER_BLAKE3_CV_WORDS];
      size_t lane;

      er_blake3_sse2_compress4_full_chunks(bytes, hasher->chunk_counter, hasher->flags, cvs);
      for (lane = 0u; lane < ER_BLAKE3_SSE2_LANES; ++lane) {
        ++hasher->chunk_counter;
        if (er_blake3_push_cv(hasher, cvs[lane], hasher->chunk_counter) == 0u) {
          return 0u;
        }
      }
      bytes += ER_BLAKE3_SSE2_LANES * ER_BLAKE3_CHUNK_LEN;
      len -= ER_BLAKE3_SSE2_LANES * ER_BLAKE3_CHUNK_LEN;
      continue;
    }
#endif

    if (hasher->block_len == ER_BLAKE3_BLOCK_LEN) {
      if (er_blake3_chunk_len(hasher) == ER_BLAKE3_CHUNK_LEN) {
        if (er_blake3_finish_chunk(hasher) == 0u) {
          return 0u;
        }
        continue;
      }
      flags = hasher->flags;
      if (hasher->blocks_compressed == 0u) {
        flags |= ER_BLAKE3_CHUNK_START;
      }
      er_blake3_compress_cv(hasher->chunk_cv, hasher->block, hasher->chunk_counter,
                            ER_BLAKE3_BLOCK_LEN, flags, hasher->chunk_cv);
      ++hasher->blocks_compressed;
      hasher->block_len = 0u;
      er_blake3_zero(hasher->block, ER_BLAKE3_BLOCK_LEN);
    }

    take = ER_BLAKE3_BLOCK_LEN - hasher->block_len;
    if (take > len) {
      take = len;
    }
    er_blake3_copy(&hasher->block[hasher->block_len], bytes, take);
    hasher->block_len += take;
    bytes += take;
    len -= take;
  }

  return 1u;
}

uint8_t er_blake3_final(const ErBlake3Hasher* hasher, uint8_t out[ER_BLAKE3_OUT_LEN]) {
  ErBlake3Output output;
  uint32_t right_cv[ER_BLAKE3_CV_WORDS];
  uint32_t flags;
  size_t stack_len;

  if (hasher == 0 || out == 0) {
    return 0u;
  }

  er_blake3_copy_cv(output.input_cv, hasher->chunk_cv);
  er_blake3_copy(output.block, hasher->block, ER_BLAKE3_BLOCK_LEN);
  flags = hasher->flags | ER_BLAKE3_CHUNK_END;
  if (hasher->blocks_compressed == 0u) {
    flags |= ER_BLAKE3_CHUNK_START;
  }
  output.counter = hasher->chunk_counter;
  output.block_len = (uint32_t)hasher->block_len;
  output.flags = flags;

  stack_len = hasher->cv_stack_len;
  while (stack_len > 0u) {
    er_blake3_output_cv(&output, right_cv);
    --stack_len;
    er_blake3_copy_cv(output.input_cv, g_er_blake3_iv);
    er_blake3_parent_block(hasher->cv_stack[stack_len], right_cv, output.block);
    output.counter = 0u;
    output.block_len = ER_BLAKE3_BLOCK_LEN;
    output.flags = ER_BLAKE3_PARENT;
  }

  er_blake3_output_root(&output, out);
  return 1u;
}

uint8_t er_blake3_hash_bytes(const uint8_t* bytes, size_t len, uint8_t out[ER_BLAKE3_OUT_LEN]) {
  ErBlake3Hasher hasher;

  if (len > 0u && bytes == 0) {
    return 0u;
  }
  er_blake3_init(&hasher);
  if (er_blake3_update(&hasher, bytes, len) == 0u) {
    return 0u;
  }
  return er_blake3_final(&hasher, out);
}

const char* er_blake3_backend_name(void) {
#if defined(ER_BLAKE3_USE_SSE2)
  return "sse2-4x";
#else
  return "scalar";
#endif
}
