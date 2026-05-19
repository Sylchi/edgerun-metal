/*
 * Purpose: report C repository shape from a virtual file snapshot.
 * Intention: keep analysis independent from the host filesystem while still
 * offering a small CLI loader for local development.
 */

#define _POSIX_C_SOURCE 200809L
#ifndef ER_REPO_INSPECT_H
#define ER_REPO_INSPECT_H

#include <ctype.h>
#include <dirent.h>
#include <errno.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#define ERI_MAX_PATH 512u
#define ERI_PACKAGE_MAX 96u
#define ERI_TOP_LIMIT 12u
#define ERI_HOTSPOT_LIMIT 6u
#define ERI_SAMPLE_LIMIT 5u
#define ERI_DEAD_CODE_SAMPLE_LIMIT 8u
#define ERI_PERCENT_SCALE 100u
#define ERI_LONG_LINE 120u
#define ERI_LONG_FUNCTION_LINES 120u
#define ERI_LARGE_FILE_LINES 800u
#define ERI_DUP_BLOCK_LINES 6u
#define ERI_LOOP_STACK_MAX 128u
#define ERI_SCAN_SNIPPET_MAX 256u
#define ERI_SCAN_STRUCTURAL_LINE_MAX 1024u
#define ERI_FUNCTION_NAME_MAX 128u
#define ERI_DEFAULT_THREAD_COUNT 1u
#define ERI_MIN_THREAD_COUNT 1u
#define ERI_MAX_THREAD_COUNT 32u
#define ERI_GIT_PATH ".git"
#define ERI_LOCAL_BUILD_PATH ".build"
#define ERI_BUILD_PATH "build"
#define ERI_CMAKE_DEBUG_PATH "cmake-build-debug"
#define ERI_STRIP_COMMAND "llvm-strip"
#define ERI_THIRD_PARTY_PATH "third_party"
#define ERI_VENDOR_UI_PATH "ui/shadcn-ui"
#define ERI_OPTIMIZER_IGNORE_TAG "@optimizer-ignore"
#define ERI_OPTIMIZER_IGNORE_FUNCTION_TAG "@optimizer-ignore-function"
#define ERI_OPTIMIZER_IGNORE_CONSTANT_TAG "@optimizer-ignore-constant"

typedef struct {
  char* path;
  uint8_t* bytes;
  size_t len;
  uint8_t executable;
} EriVfsFile;

typedef struct {
  EriVfsFile* files;
  size_t len;
  size_t cap;
} EriVfs;

typedef struct {
  char* path;
  uint8_t executable;
  uint8_t* bytes;
  size_t len;
  uint8_t loaded;
} EriLoadEntry;

typedef struct {
  EriLoadEntry* items;
  size_t len;
  size_t cap;
} EriLoadEntries;

typedef struct {
  uint64_t files;
  uint64_t bytes;
  uint64_t total_lines;
  uint64_t code_lines;
  uint64_t comment_lines;
  uint64_t blank_lines;
} EriTotals;

typedef struct {
  char name[ERI_PACKAGE_MAX];
  uint64_t files;
  uint64_t bytes;
  uint64_t code_lines;
} EriPackage;

typedef struct {
  EriPackage* items;
  size_t len;
  size_t cap;
} EriPackages;

typedef struct {
  char* path;
  char* name;
  uint32_t line;
  uint32_t end_line;
  uint8_t is_static;
  uint32_t calls;
} EriFunction;

typedef struct {
  EriFunction* items;
  size_t len;
  size_t cap;
} EriFunctions;

typedef struct {
  char* path;
  uint32_t line;
  char kind[32];
  char text[144];
} EriFinding;

typedef struct {
  EriFinding* items;
  size_t len;
  size_t cap;
} EriFindings;

typedef struct {
  const EriVfsFile* file;
  uint64_t size;
  uint64_t stripped_size;
  uint8_t stripped_available;
} EriBinary;

typedef struct {
  EriBinary* items;
  size_t len;
  size_t cap;
} EriBinaries;

typedef struct {
  char* path;
  uint64_t code_lines;
  uint8_t is_test;
  uint8_t has_test_signal;
} EriSourceFile;

typedef struct {
  EriSourceFile* items;
  size_t len;
  size_t cap;
} EriSourceFiles;

typedef struct {
  char package[ERI_PACKAGE_MAX];
  uint64_t source_files;
  uint64_t tested_source_files;
  uint64_t source_code_lines;
  uint64_t test_files;
  uint64_t test_code_lines;
} EriCoveragePackage;

typedef struct {
  EriCoveragePackage* items;
  size_t len;
  size_t cap;
} EriCoveragePackages;

typedef struct {
  char package[ERI_PACKAGE_MAX];
  uint64_t large_files;
  uint64_t long_functions;
  uint64_t markers;
  uint64_t gotos;
  uint64_t long_lines;
  uint64_t magic_numbers;
  uint64_t string_indexing;
  uint64_t math_primitives;
  uint64_t nonprod_findings;
} EriSmellPackage;

typedef struct {
  EriSmellPackage* items;
  size_t len;
  size_t cap;
} EriSmellPackages;

typedef struct {
  char package[ERI_PACKAGE_MAX];
  uint64_t nested_loops;
  uint64_t calls_in_loops;
  uint64_t divisions_in_loops;
  uint64_t memory_ops_in_loops;
  uint64_t allocations_in_loops;
  uint64_t io_ops_in_loops;
  uint64_t nonprod_findings;
} EriCpuPackage;

typedef struct {
  char package[ERI_PACKAGE_MAX];
  uint64_t host_fs_runtime;
  uint64_t path_identity;
  uint64_t legacy_object_ids;
  uint64_t raw_object_apis;
  uint64_t wasm64_offsets;
  uint64_t nonprod_findings;
} EriWorldviewPackage;

typedef struct {
  EriCpuPackage* items;
  size_t len;
  size_t cap;
} EriCpuPackages;

typedef struct {
  EriWorldviewPackage* items;
  size_t len;
  size_t cap;
} EriWorldviewPackages;

typedef struct {
  uint64_t hash;
  char* path;
  uint32_t line;
} EriDupBlockRef;

typedef struct {
  EriDupBlockRef* items;
  size_t len;
  size_t cap;
} EriDupBlockRefs;

typedef struct {
  char* path_a;
  uint32_t line_a;
  uint8_t is_test_a;
  char* path_b;
  uint32_t line_b;
  uint8_t is_test_b;
  uint64_t hash;
} EriDuplicate;

typedef struct {
  EriDuplicate* items;
  size_t len;
  size_t cap;
} EriDuplicates;

typedef struct {
  size_t thread_count;
  uint8_t details;
} EriInspectOptions;

typedef struct {
  uint32_t segment;
  int brace_depth;
  int function_ignore_depth;
  uint8_t pending_optimizer_ignore;
  uint8_t pending_function_ignore;
  uint8_t pending_constant_ignore;
  uint8_t function_ignore_active;
  uint8_t constant_ignore_active;
  uint8_t constant_ignore_macro;
} EriDupIgnoreState;

typedef struct {
  uint8_t analyzed;
  uint8_t failed;
  EriTotals totals;
  EriFindings findings;
  EriFunctions funcs;
  EriSourceFiles sources;
} EriFileAnalysis;

typedef struct {
  const EriVfs* vfs;
  EriFileAnalysis* files;
  pthread_mutex_t mutex;
  size_t next_index;
  uint8_t failed;
} EriAnalysisJobs;

typedef struct {
  const EriVfs* vfs;
  EriDupBlockRefs* refs;
  pthread_mutex_t mutex;
  size_t next_index;
  uint8_t failed;
} EriDuplicateJobs;

typedef struct {
  EriBinaries* bins;
  const char* strip_command;
  pthread_mutex_t mutex;
  size_t next_index;
  uint8_t failed;
} EriBinaryJobs;

typedef struct {
  const EriVfs* vfs;
  EriFunctions* funcs;
  pthread_mutex_t mutex;
  size_t next_index;
  uint8_t failed;
} EriFunctionRefJobs;

typedef struct {
  const EriVfs* vfs;
  EriSourceFiles* sources;
  const EriFunctions* funcs;
  pthread_mutex_t mutex;
  size_t next_index;
  uint8_t failed;
} EriTestSignalJobs;

typedef struct {
  const char* root;
  EriLoadEntries* entries;
  pthread_mutex_t mutex;
  size_t next_index;
  uint8_t failed;
} EriLoadJobs;

#endif
