#include "internal/wasm_vm_internal.h"

int er_reader_init(ErReader* r, const UINT8* data, UINT32 size) {
  if (r == 0) {
    return -1;
  }

  r->data = data;
  r->size = size;
  r->ofs = 0;
  return 0;
}

int er_reader_more(const ErReader* r) {
  if (r == 0) {
    return 0;
  }
  return (r->ofs < r->size);
}

int er_reader_read_u8(ErReader* r, UINT8* out) {
  if (r == 0 || out == 0) {
    return -1;
  }
  if (!er_reader_more(r)) {
    return -1;
  }

  *out = r->data[r->ofs];
  ++r->ofs;
  return 0;
}

int er_reader_read_u32_leb(ErReader* r, UINT32* out) {
  UINT32 result = 0;
  UINT32 shift = 0;
  UINT8 byte = 0;
  UINT32 count = 0;

  if (r == 0 || out == 0) {
    return -1;
  }

  do {
    if (count++ >= ER_WASM_LEB32_MAX_BYTES || r->ofs >= r->size) {
      return -1;
    }
    byte = r->data[r->ofs++];
    result |= (UINT32)(byte & ER_WASM_LEB_PAYLOAD_MASK) << shift;
    shift += ER_WASM_LEB_BITS_PER_BYTE;
  } while (byte & ER_WASM_LEB_CONTINUE_MASK);

  *out = result;
  return 0;
}

int er_reader_read_i64_leb(ErReader* r, INT64* out) {
  UINT8 byte = 0;
  INT64 result = 0;
  INT32 shift = 0;
  UINT8 count = 0;

  if (r == 0 || out == 0) {
    return -1;
  }

  do {
    if (count++ >= ER_WASM_LEB64_MAX_BYTES || r->ofs >= r->size) {
      return -1;
    }
    byte = r->data[r->ofs++];
    result |= (INT64)(byte & ER_WASM_LEB_PAYLOAD_MASK) << shift;
    shift += ER_WASM_LEB_BITS_PER_BYTE;
  } while (byte & ER_WASM_LEB_CONTINUE_MASK);

  if ((shift < 64) && (byte & ER_WASM_LEB_SIGN_MASK)) {
    result |= (INT64)(~((UINT64)0) << shift);
  }

  *out = result;
  return 0;
}

int er_skip_leb_bytes(const UINT8* data, UINT32 size, UINT32* ofs, UINT32 max_bytes) {
  UINT8 byte = 0;
  UINT32 count = 0;

  if (data == 0 || ofs == 0 || max_bytes == 0u) {
    return -1;
  }

  while (*ofs < size) {
    byte = data[*ofs];
    ++(*ofs);
    if ((byte & ER_WASM_LEB_CONTINUE_MASK) == 0u) {
      return 0;
    }

    if (++count >= max_bytes) {
      return -1;
    }
  }

  return -1;
}
int er_skip_u32_leb(const UINT8* data, UINT32 size, UINT32* ofs) {
  return er_skip_leb_bytes(data, size, ofs, ER_WASM_LEB32_MAX_BYTES);
}

int er_skip_i64_leb(const UINT8* data, UINT32 size, UINT32* ofs) {
  return er_skip_leb_bytes(data, size, ofs, ER_WASM_LEB64_MAX_BYTES);
}

int er_reader_skip(ErReader* r, UINT32 count) {
  if (r == 0 || count > r->size - r->ofs) {
    return -1;
  }
  r->ofs += count;
  return 0;
}
int er_read_string(ErReader* r, const UINT8** out_string, UINT32* out_len) {
  UINT32 len = 0;

  if (r == 0 || out_string == 0 || out_len == 0) {
    return -1;
  }

  if (er_reader_read_u32_leb(r, &len) != 0) {
    return -1;
  }

  if (r->ofs + len > r->size) {
    return -1;
  }

  *out_string = &r->data[r->ofs];
  *out_len = len;
  r->ofs += len;
  return 0;
}

int er_scan_matching_end(const UINT8* data, UINT32 size, UINT32 start_pc,
                                UINT32* out_end_pc, UINT32* out_else_pc) {
  UINT32 pc = start_pc;
  UINT32 depth = 1;

  if (data == 0 || out_end_pc == 0) {
    return -1;
  }

  if (start_pc >= size) {
    return -1;
  }

  if (out_else_pc != 0) {
    *out_else_pc = 0;
  }

  while (pc < size) {
    UINT8 op = data[pc++];

    if (op == ER_WASM_OP_BLOCK || op == ER_WASM_OP_LOOP || op == ER_WASM_OP_IF) {
      if (pc >= size) {
        return -1;
      }
      pc += 1; /* block type */
      ++depth;
      continue;
    }

    if (op == ER_WASM_OP_ELSE) {
      if (depth == 1 && out_else_pc != 0 && *out_else_pc == 0) {
        *out_else_pc = pc;
      }
      continue;
    }

    if (op == ER_WASM_OP_END) {
      if (depth == 0) {
        return -1;
      }
      if (depth == 1) {
        *out_end_pc = pc;
        return 0;
      }
      --depth;
      continue;
    }

    if (op == ER_WASM_OP_CALL || op == ER_WASM_OP_BR || op == ER_WASM_OP_BR_IF ||
        op == ER_WASM_OP_LOCAL_GET || op == ER_WASM_OP_LOCAL_SET || op == ER_WASM_OP_LOCAL_TEE) {
      if (er_skip_u32_leb(data, size, &pc) != 0) {
        return -1;
      }
      continue;
    }

    if (op == ER_WASM_OP_I32_CONST) {
      if (er_skip_u32_leb(data, size, &pc) != 0) {
        return -1;
      }
      continue;
    }

    if (op == ER_WASM_OP_I64_CONST) {
      if (er_skip_i64_leb(data, size, &pc) != 0) {
        return -1;
      }
      continue;
    }

    if (op >= ER_WASM_OP_I32_LOAD && op <= ER_WASM_OP_MEMORY_MAX) {
      if (er_skip_u32_leb(data, size, &pc) != 0 || er_skip_u32_leb(data, size, &pc) != 0) {
        return -1;
      }
      continue;
    }

    if (op == ER_WASM_OP_MEMORY_SIZE || op == ER_WASM_OP_MEMORY_GROW) {
      if (er_skip_u32_leb(data, size, &pc) != 0) {
        return -1;
      }
      continue;
    }

    if (op == ER_WASM_OP_I32_WRAP_I64) {
      continue;
    }
  }

  return -1;
}
