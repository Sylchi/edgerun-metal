#include "disk_analyzer.h"

#include <stdio.h>

int main(int argc, char** argv) {
  DaOptions options;
  DaScan scan;
  DaDuplicateStats duplicate_stats;

  da_options_init(&options);
  if (da_parse_args(&options, argc, argv) != 0) {
    return 2;
  }
  if (da_scan_root(&scan, &options) != 0) {
    return 1;
  }
  printf("disk-analyzer root=%s files=%llu dirs=%zu bytes=%llu duplicate-min-bytes=%llu\n",
         options.root,
         (unsigned long long)scan.total_files,
         scan.dirs.count,
         (unsigned long long)scan.total_bytes,
         (unsigned long long)options.min_dup_size);
  da_print_top_folders(&scan, options.top_limit);
  if (options.duplicates_enabled != 0) {
    if (da_report_duplicates(&scan, &options, &duplicate_stats) != 0) {
      da_scan_free(&scan);
      return 1;
    }
  }
  da_scan_free(&scan);
  return 0;
}
