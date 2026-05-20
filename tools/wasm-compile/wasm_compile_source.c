#include "wasm_compile.h"

ErWcCompileStatus erwc_compile_source(const ErWcSource* source,
                                      ErWcSourceKind source_kind,
                                      ErWcBuffer* out) {
  ErWcParse parse;
  ErWcModule module;
  int root = -1;

  if (source == NULL || source->bytes == NULL || out == NULL) {
    return ERWC_COMPILE_STATUS_BAD_ARGS;
  }

  memset(&parse, 0, sizeof(parse));
  memset(&module, 0, sizeof(module));
  memset(out, 0, sizeof(*out));

  switch (source_kind) {
    case ERWC_SOURCE_KIND_ERC:
      if (erwc_build_c_source(source, &module) != 0) {
        return ERWC_COMPILE_STATUS_UNSUPPORTED_ERC;
      }
      break;
    case ERWC_SOURCE_KIND_WAT:
      if (erwc_tokenize(source, &parse) != 0) {
        return ERWC_COMPILE_STATUS_TOKENIZATION_FAILED;
      }
      root = erwc_parse_tree(&parse);
      if (root < 0 || erwc_build_module(&parse, root, &module) != 0) {
        return ERWC_COMPILE_STATUS_UNSUPPORTED_WAT;
      }
      break;
    default:
      return ERWC_COMPILE_STATUS_BAD_ARGS;
  }

  if (erwc_validate_contract(&module) != 0) {
    return ERWC_COMPILE_STATUS_CONTRACT_REJECTED;
  }
  if (erwc_emit_wasm(&module, out) != 0) {
    return ERWC_COMPILE_STATUS_EMIT_FAILED;
  }
  return ERWC_COMPILE_STATUS_OK;
}
