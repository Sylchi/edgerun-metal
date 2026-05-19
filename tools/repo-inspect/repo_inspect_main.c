#include "repo_inspect.h"

#include "repo_inspect_vfs.c"
#include "repo_inspect_model.c"
#include "repo_inspect_parse.c"
#include "repo_inspect_scan.c"
#include "repo_inspect_binaries.c"
#include "repo_inspect_coverage.c"
#include "repo_inspect_duplicates.c"
#include "repo_inspect_report.c"
#include "repo_inspect_analyze.c"

static void eri_usage(const char* argv0) {
  printf("usage: %s [repo-root-or-scope]\n", argv0);
  printf("\n");
  printf("Builds a virtual file snapshot, then reports C LOC, package size,\n");
  printf("binary artifacts, test signals, duplicate blocks, dead-code candidates,\n");
  printf("CPU cost signals, and simple code smells.\n");
  printf("Set %s to an integer from %u to %u to choose worker count.\n",
         ERI_THREAD_ENV, ERI_MIN_THREAD_COUNT, ERI_MAX_THREAD_COUNT);
}

static const char* eri_cli_relative_scope(const char* arg) {
  while (arg[0] == '.' && arg[1] == '/') {
    arg += 2u;
  }
  if (arg[0] == 0 || strcmp(arg, ".") == 0 || arg[0] == '/') {
    return "";
  }
  return arg;
}

int main(int argc, char** argv) {
  EriVfs vfs;
  const char* root = ".";
  const char* rel = "";
  int ok;

  if (argc > 2 || (argc == 2 && (strcmp(argv[1], "-h") == 0 || strcmp(argv[1], "--help") == 0))) {
    eri_usage(argv[0]);
    return argc > 2 ? 1 : 0;
  }
  if (argc == 2) {
    root = argv[1];
    rel = eri_cli_relative_scope(argv[1]);
    if (rel[0] != 0) {
      root = ".";
    }
  }

  memset(&vfs, 0, sizeof(vfs));
  if (eri_load_dir(&vfs, root, rel) == 0u) {
    eri_vfs_free(&vfs);
    return 1;
  }
  ok = eri_analyze(&vfs) != 0u ? 0 : 1;
  eri_vfs_free(&vfs);
  return ok;
}
