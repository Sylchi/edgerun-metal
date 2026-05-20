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
  printf("usage: %s [--threads N] [--details] [repo-root-or-scope]\n", argv0);
  printf("\n");
  printf("Builds a virtual file snapshot, then reports C LOC, package size,\n");
  printf("binary artifacts, test signals, duplicate blocks, dead-code candidates,\n");
  printf("CPU cost signals, and simple code smells.\n");
  printf("--threads N must be an integer from %u to %u; the default is %u.\n",
         ERI_MIN_THREAD_COUNT, ERI_MAX_THREAD_COUNT, ERI_DEFAULT_THREAD_COUNT);
  printf("--details prints every duplicate and finding after the summary.\n");
}

static uint8_t eri_parse_thread_count(const char* text, size_t* out_count) {
  char* end = NULL;
  unsigned long requested;

  if (text == NULL || out_count == NULL) {
    return 0u;
  }
  errno = 0;
  requested = strtoul(text, &end, 10);
  if (end == text || *end != 0 || errno == ERANGE ||
      requested < (unsigned long)ERI_MIN_THREAD_COUNT ||
      requested > (unsigned long)ERI_MAX_THREAD_COUNT) {
    fprintf(stderr, "repo-inspect: --threads must be an integer from %u to %u\n",
            ERI_MIN_THREAD_COUNT, ERI_MAX_THREAD_COUNT);
    return 0u;
  }
  *out_count = (size_t)requested;
  return 1u;
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

int eri_main(int argc, char** argv) {
  EriVfs vfs;
  EriInspectOptions options;
  const char* root = ".";
  const char* rel = "";
  int argi = 1;
  int ok;

  options.thread_count = ERI_DEFAULT_THREAD_COUNT;
  options.details = 0u;

  while (argi < argc) {
    if (strcmp(argv[argi], "-h") == 0 || strcmp(argv[argi], "--help") == 0) {
      eri_usage(argv[0]);
      return 0;
    }
    if (strcmp(argv[argi], "--details") == 0) {
      options.details = 1u;
      ++argi;
      continue;
    }
    if (strcmp(argv[argi], "--threads") == 0) {
      if (argi + 1 >= argc || eri_parse_thread_count(argv[argi + 1], &options.thread_count) == 0u) {
        return 1;
      }
      argi += 2;
      continue;
    }
    break;
  }

  if (argc - argi > 1) {
    eri_usage(argv[0]);
    return 1;
  }
  if (argc - argi == 1) {
    root = argv[argi];
    rel = eri_cli_relative_scope(argv[argi]);
    if (rel[0] != 0) {
      root = ".";
    }
  }

  memset(&vfs, 0, sizeof(vfs));
  if (eri_load_dir(&vfs, root, rel, options.thread_count) == 0u) {
    eri_vfs_free(&vfs);
    return 1;
  }
  ok = eri_analyze(&vfs, &options) != 0u ? 0 : 1;
  eri_vfs_free(&vfs);
  return ok;
}

#ifndef ERI_NO_CLI_MAIN
int main(int argc, char** argv) {
  return eri_main(argc, argv);
}
#endif
