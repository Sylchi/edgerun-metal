#include "vr_font_utils_internal.h"

vr_status_t vr_parse_kern(vr_font_face_t* face) {
  const vr_table_record_t* kern = vr_find_table(face, VR_TABLE_TAG('k','e','r','n'));
  if (!kern) {
    return VR_ERR_NOT_FOUND;
  }
  if (kern->offset + kern->length > face->file_size) {
    return VR_ERR_INVALID_FONT;
  }

  const uint8_t* p = face->file_data + kern->offset;
  uint16_t version = vr_u16(p);
  uint16_t n_tables = vr_u16(p + 2);
  (void)version;

  const uint8_t* tables = p + 4;
  for (uint16_t i = 0; i < n_tables; ++i) {
    const uint8_t* sub = tables + i * 8;
    if ((size_t)(sub - p) + 8 > kern->length) {
      return VR_ERR_INVALID_FONT;
    }

    uint16_t sub_version = vr_u16(sub);
    uint16_t sub_len = vr_u16(sub + 2);
    uint16_t coverage = vr_u16(sub + 4);
    (void)vr_u16(sub + 6);

    if (sub_version != 0) {
      continue;
    }
    if (sub_len < 12) {
      continue;
    }
    if (sub + sub_len > p + kern->length) {
      continue;
    }

    uint16_t coverage_type = coverage & 0xFF;
    if (coverage_type != 0) {
      continue;
    }

    uint16_t n_pairs = vr_u16(sub + 8);
    const uint8_t* q = sub + 12;
    size_t needed = (size_t)n_pairs * 6 + 12;
    if (sub + needed > p + kern->length || needed > sub_len) {
      return VR_ERR_INVALID_FONT;
    }

    if (n_pairs == 0) {
      continue;
    }

    size_t new_cap = face->kern.count + n_pairs;
    vr_kern_pair_t* pairs = (vr_kern_pair_t*)vr_face_realloc_array(face, face->kern.pairs, face->kern.cap, new_cap, sizeof(vr_kern_pair_t), 8u);
    if (!pairs && n_pairs > 0) {
      return VR_ERR_OOM;
    }
    face->kern.pairs = pairs;
    face->kern.cap = new_cap;
    for (uint16_t j = 0; j < n_pairs; ++j) {
      uint16_t left = vr_u16(q + j * 6);
      uint16_t right = vr_u16(q + j * 6 + 2);
      int16_t adjust = vr_i16(q + j * 6 + 4);
      face->kern.pairs[face->kern.count + j].left = left;
      face->kern.pairs[face->kern.count + j].right = right;
      face->kern.pairs[face->kern.count + j].adjust = (float)adjust;
    }
    face->kern.count = new_cap;
  }

  return VR_OK;
}

float vr_find_kern_adjust(const vr_font_face_t* face, uint16_t left, uint16_t right) {
  for (size_t i = 0; i < face->kern.count; ++i) {
    if (face->kern.pairs[i].left == left && face->kern.pairs[i].right == right) {
      return face->kern.pairs[i].adjust;
    }
  }
  return 0.0f;
}
