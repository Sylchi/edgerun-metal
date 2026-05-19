#include "wasm_compile.h"

int main(int argc, char** argv) {
  if (argc != ERWC_ARGC) {
    return erwc_usage(argv[0]);
  }
  if (argv[ERWC_INPUT_ARG][0] == 0 || argv[ERWC_OUTPUT_ARG][0] == 0) {
    return erwc_usage(argv[0]);
  }
  return erwc_compile_path(argv[ERWC_INPUT_ARG], argv[ERWC_OUTPUT_ARG]);
}
