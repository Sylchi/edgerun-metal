#define _XOPEN_SOURCE 700
#define _POSIX_C_SOURCE 200809L

#include <ctype.h>
#include <dirent.h>
#include <errno.h>
#include <limits.h>
#include <netdb.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#ifndef PATH_MAX
#define PATH_MAX 4096
#endif

#define READ_CHUNK 8192u
#define GIT_COMMIT_SUBJECT_BYTES 72u
#define CODEX_BACKEND_VERSION "0.130.0"
#define DEFAULT_MODEL "gpt-5.5"
#define CODEX_BACKEND_URL "https://chatgpt.com/backend-api/codex/responses"
#define CODEX_SSE_HEADER_CAP 10u
static bool g_codex_memory_only = false;
static bool g_codex_quiet_agent = false;
static bool g_codex_minimal_agent = false;

#define ANSI_RESET "\033[0m"
#define ANSI_BOLD "\033[1m"
#define ANSI_DIM "\033[2m"
#define ANSI_RED "\033[31m"
#define ANSI_GREEN "\033[32m"
#define ANSI_YELLOW "\033[33m"
#define ANSI_BLUE "\033[34m"
#define ANSI_MAGENTA "\033[35m"
#define ANSI_CYAN "\033[36m"
#define ANSI_GRAY "\033[90m"
#define C_KEYWORD_COUNT 33u
#define SESSION_EXCERPT_BYTES 400u
#define SUMMARY_TEXT_BYTES 1200u
#define SUMMARY_INCLUDE_LIMIT 5u
#define SUMMARY_SYMBOL_LIMIT 8u
#define SELF_TEST_CODEX_GAME_FAILURE 15
#define SELF_TEST_TRANSPORT_URL_FAILURE 16
#define SELF_TEST_TRANSPORT_REQUEST_FAILURE 17
#define SELF_TEST_CODEX_SSE_HEADERS_FAILURE 18
#define SELF_TEST_TLS_FAILURE 19
#define WORKSPACE_INITIAL_CAPACITY 256u
#define FNV1A64_OFFSET_BASIS 1469598103934665603ull
#define FNV1A64_PRIME 1099511628211ull
#define MODE_PERMISSIONS_MASK 0777

typedef enum {
    SELF_TEST_SAFE_RELATIVE_PATH_FAILURE = 1,
    SELF_TEST_PARENT_PATH_FAILURE,
    SELF_TEST_INTERIOR_PARENT_PATH_FAILURE,
    SELF_TEST_CASE_INSENSITIVE_POSITIVE_FAILURE,
    SELF_TEST_CASE_INSENSITIVE_NEGATIVE_FAILURE,
    SELF_TEST_SCOPE_FAILURE,
    SELF_TEST_SCOPE_TEST_TARGET_FAILURE,
    SELF_TEST_DEFAULT_TEST_TARGET_FAILURE,
    SELF_TEST_KEYWORD_POSITIVE_FAILURE,
    SELF_TEST_KEYWORD_NEGATIVE_FAILURE,
    SELF_TEST_C_PATH_FAILURE,
    SELF_TEST_STEM_LENGTH_FAILURE,
    SELF_TEST_HASH_DIFFERENCE_FAILURE,
    SELF_TEST_SKIP_BUILD_DIR_FAILURE
} SelfTestFailure;

static const char *AGENT_INSTRUCTIONS =
    "You are Codex running inside EdgeRun C. "
    "You do not have direct shell or process access. "
    "Use search_code and read_code to inspect the in-memory workspace snapshot. "
    "Use summarize_code first when orienting on a topic so you do not reread files unnecessarily. "
    "Use propose_change to stage complete-file replacements in memory. "
    "The host automatically provides repository status, rules, and verification context. "
    "Do not ask the user to run git status, git diff, build, or test commands. "
    "After you propose changes, the host writes only those proposals, runs scoped repo-progress verification, "
    "and creates a git commit only after verification passes. "
    "A turn that ends with only analysis, planning, or review is not material progress; "
    "when you have enough context, call propose_change for one concrete improvement. "
    "The host may continue the loop after checkpoints so useful work keeps accumulating. "
    "Do not claim tests were run unless the host reports test output.";

typedef struct {
    char *path;
    unsigned char *data;
    size_t len;
    bool text;
    mode_t mode;
} MemoryFile;

typedef struct {
    char *path;
    unsigned char *data;
    size_t len;
    mode_t mode;
    bool mode_known;
} Proposal;

typedef struct {
    char *path;
    char *text;
    uint64_t hash;
} FileSummary;

typedef struct {
    char root[PATH_MAX];
    MemoryFile *files;
    size_t file_count;
    size_t file_cap;
    Proposal *proposals;
    size_t proposal_count;
    size_t proposal_cap;
    FileSummary *summaries;
    size_t summary_count;
    size_t summary_cap;
} Workspace;

typedef struct {
    char *data;
    size_t len;
    size_t cap;
} Buffer;

typedef struct {
    char *access_token;
    char *account_id;
} CodexAuth;

typedef struct {
    char thread_id[64];
    char session_id[64];
    char installation_id[64];
    char window_id[80];
} CodexSession;

typedef struct {
    char *name;
    char *arguments;
    char *call_id;
} ToolCall;

typedef struct {
    char **items;
    size_t count;
    size_t cap;
} JsonItems;

typedef struct {
    char *text;
    ToolCall *tools;
    size_t tool_count;
    JsonItems output_items;
} AgentTurn;

typedef struct {
    const char *model;
    size_t turns;
    size_t tool_calls;
    size_t checkpoints;
    size_t review_only_turns;
    size_t proposals_before_commit;
    int commit_status;
} AgentRunSummary;

static void trim_newline(char *s);
static const char *json_find_key_value_start(const char *json, const char *key);
static void buffer_append_excerpt(Buffer *b, const char *text, size_t max_bytes);

static void die(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    vfprintf(stderr, fmt, ap);
    va_end(ap);
    fputc('\n', stderr);
    exit(1);
}

static void *xmalloc(size_t n) {
    void *p = malloc(n ? n : 1);
    if (!p) die("out of memory");
    return p;
}

static void *xrealloc(void *p, size_t n) {
    void *q = realloc(p, n ? n : 1);
    if (!q) die("out of memory");
    return q;
}

static char *xstrdup(const char *s) {
    size_t n = strlen(s) + 1;
    char *p = xmalloc(n);
    memcpy(p, s, n);
    return p;
}

static bool starts_with(const char *s, const char *prefix) {
    return strncmp(s, prefix, strlen(prefix)) == 0;
}

static bool terminal_color_enabled(FILE *stream) {
    if (getenv("EDGERUN_C_COLOR")) {
        return strcmp(getenv("EDGERUN_C_COLOR"), "0") != 0;
    }
    if (getenv("NO_COLOR")) return false;
    return isatty(fileno(stream)) != 0;
}

static const char *color_code(FILE *stream, const char *code) {
    return terminal_color_enabled(stream) ? code : "";
}

static void print_icon_line(FILE *stream, const char *icon, const char *color, const char *fmt, ...) {
    fprintf(stream, "%s%s%s ", color_code(stream, color), icon, color_code(stream, ANSI_RESET));
    va_list ap;
    va_start(ap, fmt);
    vfprintf(stream, fmt, ap);
    va_end(ap);
    fputc('\n', stream);
}

static bool is_identifier_start_char(char c) {
    return isalpha((unsigned char)c) || c == '_';
}

static bool is_identifier_char(char c) {
    return isalnum((unsigned char)c) || c == '_';
}

static bool is_c_keyword(const char *s, size_t len) {
    static const char *keywords[C_KEYWORD_COUNT] = {
        "auto", "break", "case", "char", "const", "continue", "default",
        "do", "double", "else", "enum", "extern", "float", "for", "goto",
        "if", "inline", "int", "long", "register", "restrict", "return",
        "short", "signed", "sizeof", "static", "struct", "switch", "typedef",
        "union", "unsigned", "void", "while"
    };
    for (size_t i = 0; i < C_KEYWORD_COUNT; i++) {
        if (strlen(keywords[i]) == len && memcmp(s, keywords[i], len) == 0) return true;
    }
    return false;
}

static bool path_is_c_like(const char *path) {
    const char *dot = strrchr(path, '.');
    if (!dot) return false;
    return strcmp(dot, ".c") == 0 || strcmp(dot, ".h") == 0;
}

static bool path_is_summary_candidate(const char *path) {
    const char *base = strrchr(path, '/');
    base = base ? base + 1 : path;
    if (strcmp(base, "Makefile") == 0 ||
        strcmp(base, "CMakeLists.txt") == 0 ||
        strcmp(base, "AGENTS.md") == 0) {
        return true;
    }
    const char *dot = strrchr(path, '.');
    if (!dot) return false;
    return strcmp(dot, ".c") == 0 ||
           strcmp(dot, ".h") == 0 ||
           strcmp(dot, ".md") == 0 ||
           strcmp(dot, ".sh") == 0 ||
           strcmp(dot, ".txt") == 0 ||
           strcmp(dot, ".cmake") == 0;
}

static uint64_t stable_hash_bytes(const unsigned char *data, size_t len) {
    uint64_t hash = FNV1A64_OFFSET_BASIS;
    for (size_t i = 0; i < len; i++) {
        hash ^= (uint64_t)data[i];
        hash *= FNV1A64_PRIME;
    }
    return hash;
}

static void print_highlighted_c_line(const char *line, size_t len) {
    bool at_line_start = true;
    for (size_t i = 0; i < len;) {
        char c = line[i];
        if (at_line_start && c == '#') {
            printf("%s%.*s%s", color_code(stdout, ANSI_YELLOW), (int)(len - i), line + i, color_code(stdout, ANSI_RESET));
            return;
        }
        if (c != ' ' && c != '\t') at_line_start = false;
        if (c == '/' && i + 1u < len && line[i + 1u] == '/') {
            printf("%s%.*s%s", color_code(stdout, ANSI_GRAY), (int)(len - i), line + i, color_code(stdout, ANSI_RESET));
            return;
        }
        if (c == '"' || c == '\'') {
            char quote = c;
            size_t start = i++;
            while (i < len) {
                if (line[i] == '\\' && i + 1u < len) {
                    i += 2u;
                } else if (line[i++] == quote) {
                    break;
                }
            }
            printf("%s%.*s%s", color_code(stdout, ANSI_GREEN), (int)(i - start), line + start, color_code(stdout, ANSI_RESET));
        } else if (is_identifier_start_char(c)) {
            size_t start = i++;
            while (i < len && is_identifier_char(line[i])) i++;
            if (is_c_keyword(line + start, i - start)) {
                printf("%s%.*s%s", color_code(stdout, ANSI_MAGENTA), (int)(i - start), line + start, color_code(stdout, ANSI_RESET));
            } else {
                printf("%.*s", (int)(i - start), line + start);
            }
        } else if (isdigit((unsigned char)c)) {
            size_t start = i++;
            while (i < len && (isalnum((unsigned char)line[i]) || line[i] == '.')) i++;
            printf("%s%.*s%s", color_code(stdout, ANSI_CYAN), (int)(i - start), line + start, color_code(stdout, ANSI_RESET));
        } else {
            putchar(c);
            i++;
        }
    }
}

static bool contains_path_part(const char *path, const char *part) {
    size_t part_len = strlen(part);
    const char *p = path;
    while (*p) {
        const char *end = strchr(p, '/');
        size_t len = end ? (size_t)(end - p) : strlen(p);
        if (len == part_len && memcmp(p, part, len) == 0) return true;
        if (!end) break;
        p = end + 1;
    }
    return false;
}

static bool should_skip_dir(const char *rel) {
    static const char *skip[] = {
        ".git", ".build", "target", "node_modules", "dist", "build", "coverage",
        ".next", ".turbo", "out", "vendor", "shadcn-ui", NULL
    };
    for (size_t i = 0; skip[i]; i++) {
        if (contains_path_part(rel, skip[i])) return true;
    }
    return false;
}

static bool path_is_safe(const char *path) {
    if (!path || !*path) return false;
    if (path[0] == '/' || path[0] == '\\') return false;
    if (strstr(path, "\\") != NULL) return false;
    if (strstr(path, "//") != NULL) return false;
    if (strcmp(path, ".") == 0 || strcmp(path, "..") == 0) return false;
    const size_t path_len = strlen(path);
    const size_t parent_dir_suffix_len = sizeof("/..") - sizeof("");
    if (starts_with(path, "../") || strstr(path, "/../") || strstr(path, "/..") == path + path_len - parent_dir_suffix_len) return false;
    if (starts_with(path, "./") || strstr(path, "/./")) return false;
    return true;
}

static void join_path(char out[PATH_MAX], const char *root, const char *rel) {
    int n = snprintf(out, PATH_MAX, "%s/%s", root, rel);
    if (n < 0 || n >= PATH_MAX) die("path too long: %s/%s", root, rel);
}

static bool is_probably_text(const unsigned char *data, size_t len) {
    for (size_t i = 0; i < len; i++) {
        unsigned char c = data[i];
        if (c == 0) return false;
        if (c < 32 && c != '\n' && c != '\r' && c != '\t' && c != '\f') return false;
    }
    return true;
}

static unsigned char *read_file_bytes(const char *path, size_t *len_out, bool *text_out) {
    FILE *f = fopen(path, "rb");
    if (!f) return NULL;
    if (fseek(f, 0, SEEK_END) != 0) {
        fclose(f);
        return NULL;
    }
    long end = ftell(f);
    if (end < 0) {
        fclose(f);
        return NULL;
    }
    rewind(f);
    size_t len = (size_t)end;
    unsigned char *data = xmalloc(len + 1);
    size_t got = fread(data, 1, len, f);
    fclose(f);
    if (got != len) {
        free(data);
        return NULL;
    }
    data[len] = 0;
    *len_out = len;
    *text_out = is_probably_text(data, len);
    return data;
}

static void workspace_add_file(Workspace *ws, const char *rel, unsigned char *data, size_t len, bool text, mode_t mode) {
    if (ws->file_count == ws->file_cap) {
        ws->file_cap = ws->file_cap ? ws->file_cap * 2 : WORKSPACE_INITIAL_CAPACITY;
        ws->files = xrealloc(ws->files, ws->file_cap * sizeof(ws->files[0]));
    }
    ws->files[ws->file_count++] = (MemoryFile){
        .path = xstrdup(rel),
        .data = data,
        .len = len,
        .text = text,
        .mode = mode,
    };
}

static void workspace_clear_files(Workspace *ws) {
    for (size_t i = 0; i < ws->file_count; i++) {
        free(ws->files[i].path);
        free(ws->files[i].data);
    }
    ws->file_count = 0;
}

static void workspace_clear_summaries(Workspace *ws) {
    for (size_t i = 0; i < ws->summary_count; i++) {
        free(ws->summaries[i].path);
        free(ws->summaries[i].text);
    }
    ws->summary_count = 0;
}

static void scan_dir(Workspace *ws, const char *rel) {
    char abs[PATH_MAX];
    if (rel[0]) join_path(abs, ws->root, rel);
    else snprintf(abs, sizeof(abs), "%s", ws->root);

    DIR *dir = opendir(abs);
    if (!dir) return;

    struct dirent *ent;
    while ((ent = readdir(dir)) != NULL) {
        if (strcmp(ent->d_name, ".") == 0 || strcmp(ent->d_name, "..") == 0) continue;

        char child_rel[PATH_MAX];
        int n = rel[0]
            ? snprintf(child_rel, sizeof(child_rel), "%s/%s", rel, ent->d_name)
            : snprintf(child_rel, sizeof(child_rel), "%s", ent->d_name);
        if (n < 0 || n >= PATH_MAX) continue;

        char child_abs[PATH_MAX];
        join_path(child_abs, ws->root, child_rel);

        struct stat st;
        if (lstat(child_abs, &st) != 0) continue;
        if (S_ISDIR(st.st_mode)) {
            if (!should_skip_dir(child_rel)) scan_dir(ws, child_rel);
        } else if (S_ISREG(st.st_mode)) {
            size_t len = 0;
            bool text = false;
            unsigned char *data = read_file_bytes(child_abs, &len, &text);
            if (data) workspace_add_file(ws, child_rel, data, len, text, st.st_mode);
        }
    }
    closedir(dir);
}

static MemoryFile *find_file(Workspace *ws, const char *path) {
    for (size_t i = 0; i < ws->file_count; i++) {
        if (strcmp(ws->files[i].path, path) == 0) return &ws->files[i];
    }
    return NULL;
}

static Proposal *find_proposal(Workspace *ws, const char *path) {
    for (size_t i = 0; i < ws->proposal_count; i++) {
        if (strcmp(ws->proposals[i].path, path) == 0) return &ws->proposals[i];
    }
    return NULL;
}

static void upsert_proposal(Workspace *ws, const char *path, const unsigned char *data, size_t len) {
    Proposal *p = find_proposal(ws, path);
    if (!p) {
        if (ws->proposal_count == ws->proposal_cap) {
            ws->proposal_cap = ws->proposal_cap ? ws->proposal_cap * 2 : 32;
            ws->proposals = xrealloc(ws->proposals, ws->proposal_cap * sizeof(ws->proposals[0]));
        }
        p = &ws->proposals[ws->proposal_count++];
        p->path = xstrdup(path);
        p->data = NULL;
        p->len = 0;
        MemoryFile *existing = find_file(ws, path);
        if (existing) {
            p->mode = existing->mode;
            p->mode_known = true;
        } else {
            p->mode = 0;
            p->mode_known = false;
        }
    }
    free(p->data);
    p->data = xmalloc(len + 1);
    memcpy(p->data, data, len);
    p->data[len] = 0;
    p->len = len;
}

static void discard_proposal(Workspace *ws, const char *path) {
    for (size_t i = 0; i < ws->proposal_count; i++) {
        if (strcmp(ws->proposals[i].path, path) == 0) {
            free(ws->proposals[i].path);
            free(ws->proposals[i].data);
            memmove(&ws->proposals[i], &ws->proposals[i + 1],
                    (ws->proposal_count - i - 1) * sizeof(ws->proposals[0]));
            ws->proposal_count--;
            printf("discarded %s\n", path);
            return;
        }
    }
    printf("no proposal for %s\n", path);
}

static void discard_all(Workspace *ws) {
    for (size_t i = 0; i < ws->proposal_count; i++) {
        free(ws->proposals[i].path);
        free(ws->proposals[i].data);
    }
    ws->proposal_count = 0;
    printf("discarded all proposals\n");
}

static const unsigned char *effective_data(Workspace *ws, const char *path, size_t *len_out, bool *text_out) {
    Proposal *p = find_proposal(ws, path);
    if (p) {
        *len_out = p->len;
        *text_out = is_probably_text(p->data, p->len);
        return p->data;
    }
    MemoryFile *f = find_file(ws, path);
    if (!f) return NULL;
    *len_out = f->len;
    *text_out = f->text;
    return f->data;
}

static char lower_char(char c) {
    return (char)tolower((unsigned char)c);
}

static bool contains_case_insensitive(const char *hay, size_t hay_len, const char *needle) {
    size_t needle_len = strlen(needle);
    if (needle_len == 0 || needle_len > hay_len) return false;
    for (size_t i = 0; i + needle_len <= hay_len; i++) {
        size_t j = 0;
        while (j < needle_len && lower_char(hay[i + j]) == lower_char(needle[j])) j++;
        if (j == needle_len) return true;
    }
    return false;
}

static void cmd_stats(Workspace *ws) {
    size_t text = 0;
    size_t bytes = 0;
    for (size_t i = 0; i < ws->file_count; i++) {
        if (ws->files[i].text) text++;
        bytes += ws->files[i].len;
    }
    printf("%sroot:%s %s\n", color_code(stdout, ANSI_BOLD), color_code(stdout, ANSI_RESET), ws->root);
    printf("%sfiles loaded:%s %zu\n", color_code(stdout, ANSI_CYAN), color_code(stdout, ANSI_RESET), ws->file_count);
    printf("%stext files:%s %zu\n", color_code(stdout, ANSI_CYAN), color_code(stdout, ANSI_RESET), text);
    printf("%sbytes loaded:%s %zu\n", color_code(stdout, ANSI_CYAN), color_code(stdout, ANSI_RESET), bytes);
    printf("%ssummaries:%s %zu\n", color_code(stdout, ANSI_CYAN), color_code(stdout, ANSI_RESET), ws->summary_count);
    printf("%sproposals:%s %zu\n", color_code(stdout, ANSI_CYAN), color_code(stdout, ANSI_RESET), ws->proposal_count);
}

static void cmd_search(Workspace *ws, const char *query, size_t limit) {
    if (!query || !*query) {
        printf("usage: search <text> [limit]\n");
        return;
    }
    size_t hits = 0;
    for (size_t i = 0; i < ws->file_count && (limit == 0 || hits < limit); i++) {
        MemoryFile *f = &ws->files[i];
        if (!f->text) continue;
        const char *text = (const char *)f->data;
        size_t start = 0;
        size_t line_no = 1;
        for (size_t pos = 0; pos <= f->len && (limit == 0 || hits < limit); pos++) {
            if (pos == f->len || text[pos] == '\n') {
                size_t line_len = pos - start;
                if (contains_case_insensitive(text + start, line_len, query)) {
                    printf("%s%s%s:%s%zu%s: %.*s\n",
                           color_code(stdout, ANSI_CYAN), f->path, color_code(stdout, ANSI_RESET),
                           color_code(stdout, ANSI_YELLOW), line_no, color_code(stdout, ANSI_RESET),
                           (int)line_len, text + start);
                    hits++;
                }
                start = pos + 1;
                line_no++;
            }
        }
    }
    if (hits == 0) print_icon_line(stdout, "🔎", ANSI_YELLOW, "no matches");
}

static void cmd_read(Workspace *ws, const char *path, size_t start_line, size_t max_lines) {
    if (!path_is_safe(path)) {
        printf("invalid workspace-relative path\n");
        return;
    }
    size_t len = 0;
    bool text = false;
    const unsigned char *data = effective_data(ws, path, &len, &text);
    if (!data) {
        printf("file not loaded: %s\n", path);
        return;
    }
    if (!text) {
        printf("file is binary or unsupported text: %s (%zu bytes)\n", path, len);
        return;
    }
    if (start_line == 0) start_line = 1;
    bool highlight = path_is_c_like(path);
    const char *s = (const char *)data;
    size_t line_no = 1;
    size_t emitted = 0;
    size_t start = 0;
    for (size_t pos = 0; pos <= len && (max_lines == 0 || emitted < max_lines); pos++) {
        if (pos == len || s[pos] == '\n') {
            if (line_no >= start_line) {
                printf("%s%5zu%s %s|%s ",
                       color_code(stdout, ANSI_DIM), line_no, color_code(stdout, ANSI_RESET),
                       color_code(stdout, ANSI_GRAY), color_code(stdout, ANSI_RESET));
                if (highlight) print_highlighted_c_line(s + start, pos - start);
                else printf("%.*s", (int)(pos - start), s + start);
                putchar('\n');
                emitted++;
            }
            start = pos + 1;
            line_no++;
        }
    }
}

static void buffer_init(Buffer *b) {
    b->data = NULL;
    b->len = 0;
    b->cap = 0;
}

static void buffer_append(Buffer *b, const char *s, size_t n) {
    if (b->len + n + 1 > b->cap) {
        size_t next = b->cap ? b->cap * 2 : READ_CHUNK;
        while (next < b->len + n + 1) next *= 2;
        b->data = xrealloc(b->data, next);
        b->cap = next;
    }
    memcpy(b->data + b->len, s, n);
    b->len += n;
    b->data[b->len] = 0;
}

static void buffer_append_c(Buffer *b, char c) {
    buffer_append(b, &c, 1);
}

static void buffer_appendf(Buffer *b, const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    va_list copy;
    va_copy(copy, ap);
    int n = vsnprintf(NULL, 0, fmt, copy);
    va_end(copy);
    if (n < 0) die("format failed");
    char *tmp = xmalloc((size_t)n + 1);
    vsnprintf(tmp, (size_t)n + 1, fmt, ap);
    va_end(ap);
    buffer_append(b, tmp, (size_t)n);
    free(tmp);
}

static bool line_has_word(const char *line, size_t len, const char *word) {
    size_t word_len = strlen(word);
    if (word_len == 0 || word_len > len) return false;
    for (size_t i = 0; i + word_len <= len; i++) {
        bool left = i == 0 || !is_identifier_char(line[i - 1]);
        bool right = i + word_len == len || !is_identifier_char(line[i + word_len]);
        if (left && right && memcmp(line + i, word, word_len) == 0) return true;
    }
    return false;
}

static bool summary_symbol_line(const char *line, size_t len) {
    if (line_has_word(line, len, "typedef")) return true;
    if (memchr(line, '(', len) == NULL || memchr(line, ')', len) == NULL) return false;
    if (line_has_word(line, len, "if") ||
        line_has_word(line, len, "for") ||
        line_has_word(line, len, "while") ||
        line_has_word(line, len, "switch")) {
        return false;
    }
    return line_has_word(line, len, "static") ||
           line_has_word(line, len, "extern") ||
           line_has_word(line, len, "int") ||
           line_has_word(line, len, "void") ||
           line_has_word(line, len, "char");
}

static void append_trimmed_line(Buffer *b, const char *line, size_t len) {
    while (len > 0 && isspace((unsigned char)line[0])) {
        line++;
        len--;
    }
    while (len > 0 && isspace((unsigned char)line[len - 1])) len--;
    buffer_append(b, line, len);
}

static char *file_summary_text_new(const MemoryFile *file) {
    Buffer b;
    buffer_init(&b);
    uint64_t hash = stable_hash_bytes(file->data, file->len);
    buffer_appendf(&b, "file %s\nbytes %zu\nhash %016llx\n", file->path, file->len, (unsigned long long)hash);
    if (!file->text) {
        buffer_append(&b, "kind binary\n", strlen("kind binary\n"));
        return b.data;
    }

    size_t lines = 0;
    size_t includes = 0;
    size_t symbols = 0;
    bool purpose_done = false;
    Buffer include_text;
    Buffer symbol_text;
    buffer_init(&include_text);
    buffer_init(&symbol_text);
    const char *s = (const char *)file->data;
    size_t start = 0;
    for (size_t pos = 0; pos <= file->len; pos++) {
        if (pos == file->len || s[pos] == '\n') {
            size_t len = pos - start;
            lines++;
            const char *line = s + start;
            while (len > 0 && isspace((unsigned char)line[0])) {
                line++;
                len--;
            }
            if (!purpose_done && len > 0 && line[0] != '#') {
                buffer_append(&b, "purpose ", 8);
                append_trimmed_line(&b, line, len);
                buffer_append_c(&b, '\n');
                purpose_done = true;
            }
            if (starts_with(line, "#include") && includes < SUMMARY_INCLUDE_LIMIT) {
                buffer_append(&include_text, "include ", 8);
                append_trimmed_line(&include_text, line, len);
                buffer_append_c(&include_text, '\n');
                includes++;
            }
            if (path_is_c_like(file->path) && symbols < SUMMARY_SYMBOL_LIMIT && summary_symbol_line(line, len)) {
                buffer_append(&symbol_text, "symbol ", strlen("symbol "));
                append_trimmed_line(&symbol_text, line, len);
                buffer_append_c(&symbol_text, '\n');
                symbols++;
            }
            start = pos + 1;
        }
    }
    buffer_appendf(&b, "kind %s\nlines %zu\n", path_is_c_like(file->path) ? "c" : "text", lines);
    if (include_text.data) buffer_append(&b, include_text.data, include_text.len);
    if (symbol_text.data) buffer_append(&b, symbol_text.data, symbol_text.len);
    free(include_text.data);
    free(symbol_text.data);
    if (!purpose_done) {
        const char *empty_purpose = "purpose empty or declaration-only file\n";
        buffer_append(&b, empty_purpose, strlen(empty_purpose));
    }
    return b.data;
}

static void workspace_add_summary(Workspace *ws, const MemoryFile *file) {
    if (!file->text || !path_is_summary_candidate(file->path)) return;
    if (ws->summary_count == ws->summary_cap) {
        ws->summary_cap = ws->summary_cap ? ws->summary_cap * 2 : WORKSPACE_INITIAL_CAPACITY;
        ws->summaries = xrealloc(ws->summaries, ws->summary_cap * sizeof(ws->summaries[0]));
    }
    FileSummary *summary = &ws->summaries[ws->summary_count++];
    summary->path = xstrdup(file->path);
    summary->hash = stable_hash_bytes(file->data, file->len);
    summary->text = file_summary_text_new(file);
}

static void workspace_rebuild_summaries(Workspace *ws) {
    workspace_clear_summaries(ws);
    for (size_t i = 0; i < ws->file_count; i++) {
        workspace_add_summary(ws, &ws->files[i]);
    }
}

static size_t path_stem_len(const char *path) {
    const char *base = strrchr(path, '/');
    base = base ? base + 1 : path;
    const char *dot = strrchr(base, '.');
    return dot ? (size_t)(dot - base) : strlen(base);
}

static const char *path_base_name(const char *path) {
    const char *base = strrchr(path, '/');
    return base ? base + 1 : path;
}

static bool summaries_are_related(const FileSummary *a, const FileSummary *b) {
    if (strcmp(a->path, b->path) == 0) return false;
    if (!path_is_c_like(a->path) && !path_is_c_like(b->path)) return false;
    const char *a_base = path_base_name(a->path);
    const char *b_base = path_base_name(b->path);
    size_t a_stem = path_stem_len(a->path);
    size_t b_stem = path_stem_len(b->path);
    if (path_is_c_like(a->path) &&
        path_is_c_like(b->path) &&
        a_stem == b_stem &&
        memcmp(a_base, b_base, a_stem) == 0) {
        return true;
    }
    if (contains_case_insensitive(a->text, strlen(a->text), b_base)) return true;
    if (contains_case_insensitive(b->text, strlen(b->text), a_base)) return true;
    return false;
}

static void append_related_summaries(Buffer *out, Workspace *ws, const FileSummary *summary) {
    size_t emitted = 0;
    for (size_t i = 0; i < ws->summary_count && emitted < SUMMARY_INCLUDE_LIMIT; i++) {
        if (summaries_are_related(summary, &ws->summaries[i])) {
            if (emitted == 0) buffer_append(out, "related\n", 8);
            buffer_appendf(out, "- %s\n", ws->summaries[i].path);
            emitted++;
        }
    }
}

static bool summary_query_is_workspace(const char *query) {
    return contains_case_insensitive(query, strlen(query), "workspace") ||
           contains_case_insensitive(query, strlen(query), "repo") ||
           contains_case_insensitive(query, strlen(query), "project");
}

static bool summary_matches_query(const FileSummary *summary, const char *query) {
    if (!query || !*query) return true;
    if (contains_case_insensitive(summary->path, strlen(summary->path), query)) return true;
    if (contains_case_insensitive(summary->text, strlen(summary->text), query)) return true;
    if (summary_query_is_workspace(query)) {
        return starts_with(summary->path, "codex/") ||
               starts_with(summary->path, "tools/") ||
               starts_with(summary->path, "tests/") ||
               starts_with(summary->path, "docs/") ||
               strcmp(summary->path, "Makefile") == 0 ||
               strcmp(summary->path, "AGENTS.md") == 0 ||
               strcmp(summary->path, "README.md") == 0;
    }
    return false;
}

static char *workspace_summary_query_new(Workspace *ws, const char *query, size_t limit) {
    Buffer out;
    buffer_init(&out);
    bool *emitted_flags = xmalloc(ws->summary_count * sizeof(emitted_flags[0]));
    memset(emitted_flags, 0, ws->summary_count * sizeof(emitted_flags[0]));
    if (!query || !*query) {
        buffer_appendf(&out, "summary index: %zu files\n", ws->summary_count);
        query = "";
    }
    size_t emitted = 0;
    if (summary_query_is_workspace(query)) {
        static const char *preferred[] = {
            "AGENTS.md",
            "README.md",
            "Makefile",
            "codex/README.md",
            "codex/src/edgerun_c.c",
            "codex/src/edgerun_c_agent.c",
            "tools/repo-progress.sh",
            "tools/er-build/main.c",
            "docs/repository-structure.md",
            NULL
        };
        for (size_t p = 0; preferred[p] && (limit == 0 || emitted < limit); p++) {
            for (size_t i = 0; i < ws->summary_count; i++) {
                FileSummary *summary = &ws->summaries[i];
                if (!emitted_flags[i] && strcmp(summary->path, preferred[p]) == 0) {
                    buffer_appendf(&out, "\n[%zu] %s\n", emitted + 1, summary->path);
                    buffer_append_excerpt(&out, summary->text, SUMMARY_TEXT_BYTES);
                    append_related_summaries(&out, ws, summary);
                    emitted_flags[i] = true;
                    emitted++;
                    break;
                }
            }
        }
    }
    for (size_t i = 0; i < ws->summary_count && (limit == 0 || emitted < limit); i++) {
        if (emitted_flags[i]) continue;
        FileSummary *summary = &ws->summaries[i];
        if (!summary_matches_query(summary, query)) {
            continue;
        }
        buffer_appendf(&out, "\n[%zu] %s\n", emitted + 1, summary->path);
        buffer_append_excerpt(&out, summary->text, SUMMARY_TEXT_BYTES);
        append_related_summaries(&out, ws, summary);
        emitted_flags[i] = true;
        emitted++;
    }
    if (emitted == 0) buffer_append(&out, "no matching summaries\n", strlen("no matching summaries\n"));
    free(emitted_flags);
    return out.data ? out.data : xstrdup("");
}

static char *json_escape_new(const char *s) {
    Buffer b;
    buffer_init(&b);
    buffer_append_c(&b, '"');
    for (const unsigned char *p = (const unsigned char *)s; *p; p++) {
        switch (*p) {
            case '\\': buffer_append(&b, "\\\\", 2); break;
            case '"': buffer_append(&b, "\\\"", 2); break;
            case '\n': buffer_append(&b, "\\n", 2); break;
            case '\r': buffer_append(&b, "\\r", 2); break;
            case '\t': buffer_append(&b, "\\t", 2); break;
            default:
                if (*p < 32) buffer_appendf(&b, "\\u%04x", *p);
                else buffer_append_c(&b, (char)*p);
        }
    }
    buffer_append_c(&b, '"');
    return b.data ? b.data : xstrdup("\"\"");
}

static const size_t SHELL_SINGLE_QUOTE_ESCAPE_LEN = sizeof("'\\''") - sizeof("");

static char *shell_quote_new(const char *s) {
    Buffer b;
    buffer_init(&b);
    buffer_append_c(&b, '\'');
    for (const char *p = s; *p; p++) {
        if (*p == '\'') buffer_append(&b, "'\\''", SHELL_SINGLE_QUOTE_ESCAPE_LEN);
        else buffer_append_c(&b, *p);
    }
    buffer_append_c(&b, '\'');
    return b.data ? b.data : xstrdup("''");
}

static int command_status_code(int raw_status) {
    if (raw_status == -1) return 1;
    if (WIFEXITED(raw_status)) return WEXITSTATUS(raw_status);
    return 1;
}

static char *run_command_text_new(const char *cmd, int *status_out) {
    FILE *pipe = popen(cmd, "r");
    if (!pipe) die("failed to start command: %s", cmd);
    Buffer out;
    buffer_init(&out);
    char chunk[READ_CHUNK];
    while (fgets(chunk, sizeof(chunk), pipe) != NULL) {
        buffer_append(&out, chunk, strlen(chunk));
    }
    int raw = pclose(pipe);
    if (status_out) *status_out = command_status_code(raw);
    if (!out.data) return xstrdup("");
    return out.data;
}

static int run_command_checked(const char *cmd) {
    int status = 0;
    char *out = run_command_text_new(cmd, &status);
    if (*out) fputs(out, stdout);
    free(out);
    return status;
}

static char *read_text_file_new(const char *path) {
    size_t len = 0;
    bool text = false;
    unsigned char *data = read_file_bytes(path, &len, &text);
    if (!data || !text) {
        free(data);
        return NULL;
    }
    return (char *)data;
}

enum { JSON_KEY_NEEDLE_CAPACITY = 128 };

static char *json_get_string_dup(const char *json, const char *key) {
    char needle[JSON_KEY_NEEDLE_CAPACITY];
    snprintf(needle, sizeof(needle), "\"%s\"", key);
    const char *p = strstr(json, needle);
    if (!p) return NULL;
    p += strlen(needle);
    while (*p && isspace((unsigned char)*p)) p++;
    if (*p++ != ':') return NULL;
    while (*p && isspace((unsigned char)*p)) p++;
    if (*p++ != '"') return NULL;

    Buffer b;
    buffer_init(&b);
    while (*p && *p != '"') {
        if (*p == '\\') {
            p++;
            if (!*p) break;
            switch (*p) {
                case 'n': buffer_append_c(&b, '\n'); break;
                case 'r': buffer_append_c(&b, '\r'); break;
                case 't': buffer_append_c(&b, '\t'); break;
                case '"': buffer_append_c(&b, '"'); break;
                case '\\': buffer_append_c(&b, '\\'); break;
                default: buffer_append_c(&b, *p); break;
            }
            p++;
        } else {
            buffer_append_c(&b, *p++);
        }
    }
    return b.data ? b.data : xstrdup("");
}

static char *json_get_scalar_dup(const char *json, const char *key) {
    char *s = json_get_string_dup(json, key);
    if (s) return s;
    const char *p = json_find_key_value_start(json, key);
    if (!p) return NULL;
    if (*p == '-' || isdigit((unsigned char)*p)) {
        const char *start = p;
        while (*p && (isdigit((unsigned char)*p) || *p == '-' || *p == '+'
               || *p == '.' || *p == 'e' || *p == 'E')) {
            p++;
        }
        size_t n = (size_t)(p - start);
        char *out = xmalloc(n + 1);
        memcpy(out, start, n);
        out[n] = 0;
        return out;
    }
    return NULL;
}

static char *codex_home_new(void) {
    const char *home = getenv("CODEX_HOME");
    if (home && *home) return xstrdup(home);
    home = getenv("HOME");
    if (!home || !*home) return NULL;
    Buffer b;
    buffer_init(&b);
    buffer_appendf(&b, "%s/.codex", home);
    return b.data;
}

static CodexAuth read_codex_auth(void) {
    CodexAuth auth = {0};
    char *home = codex_home_new();
    if (!home) die("CODEX_HOME or HOME must be set");
    char path[PATH_MAX];
    int n = snprintf(path, sizeof(path), "%s/auth.json", home);
    free(home);
    if (n < 0 || n >= PATH_MAX) die("auth path too long");
    char *json = read_text_file_new(path);
    if (!json) die("failed to read Codex auth file: %s", path);
    auth.access_token = json_get_string_dup(json, "access_token");
    auth.account_id = json_get_string_dup(json, "account_id");
    free(json);
    if (!auth.access_token || !*auth.access_token) die("missing tokens.access_token in %s", path);
    return auth;
}

static void json_items_push(JsonItems *items, char *json) {
    if (items->count == items->cap) {
        items->cap = items->cap ? items->cap * 2 : 16;
        items->items = xrealloc(items->items, items->cap * sizeof(items->items[0]));
    }
    items->items[items->count++] = json;
}

static void json_items_free(JsonItems *items) {
    for (size_t i = 0; i < items->count; i++) free(items->items[i]);
    free(items->items);
    items->items = NULL;
    items->count = 0;
    items->cap = 0;
}

static char *user_item_json_new(const char *text) {
    char *escaped = json_escape_new(text);
    Buffer b;
    buffer_init(&b);
    buffer_appendf(&b,
        "{\"type\":\"message\",\"role\":\"user\",\"content\":[{\"type\":\"input_text\",\"text\":%s}]}",
        escaped);
    free(escaped);
    return b.data;
}

static char *tool_output_item_json_new(const char *call_id, const char *text, bool success) {
    (void)success;
    char *id = json_escape_new(call_id);
    char *out = json_escape_new(text);
    Buffer b;
    buffer_init(&b);
    buffer_appendf(&b,
        "{\"type\":\"function_call_output\",\"call_id\":%s,\"output\":%s}",
        id, out);
    free(id);
    free(out);
    return b.data;
}

static void codex_session_init(CodexSession *session) {
    unsigned long now = (unsigned long)time(NULL);
    unsigned long pid = (unsigned long)getpid();
    snprintf(session->thread_id, sizeof(session->thread_id), "edgerun-c-thread-%lx-%lx", now, pid);
    snprintf(session->session_id, sizeof(session->session_id), "%s", session->thread_id);
    snprintf(session->installation_id, sizeof(session->installation_id), "edgerun-c-install-%lx-%lx", now, pid);
    snprintf(session->window_id, sizeof(session->window_id), "%s:0", session->thread_id);
}

static void cmd_propose(Workspace *ws, const char *path) {
    if (!path_is_safe(path)) {
        printf("invalid workspace-relative path\n");
        return;
    }
    printf("enter full file content for %s; finish with a line containing only .end\n", path);
    Buffer b;
    buffer_init(&b);
    char *line = NULL;
    size_t cap = 0;
    while (getline(&line, &cap, stdin) != -1) {
        if (strcmp(line, ".end\n") == 0 || strcmp(line, ".end\r\n") == 0 || strcmp(line, ".end") == 0) break;
        buffer_append(&b, line, strlen(line));
    }
    free(line);
    upsert_proposal(ws, path, (unsigned char *)b.data, b.len);
    printf("staged in memory: %s (%zu bytes)\n", path, b.len);
    free(b.data);
}

static size_t line_number_for_offset(const unsigned char *data, size_t offset) {
    size_t line = 1;
    for (size_t i = 0; i < offset; i++) {
        if (data[i] == '\n') line++;
    }
    return line;
}

static size_t line_count_for_range(const unsigned char *data, size_t start, size_t end) {
    size_t lines = start < end ? 1 : 0;
    for (size_t i = start; i < end; i++) {
        if (data[i] == '\n' && i + 1u < end) lines++;
    }
    return lines;
}

static void print_prefixed_lines(char prefix, const unsigned char *data, size_t start, size_t end) {
    size_t line_start = start;
    for (size_t pos = start; pos <= end; pos++) {
        if (pos == end || data[pos] == '\n') {
            printf("%c%.*s\n", prefix, (int)(pos - line_start), (const char *)data + line_start);
            line_start = pos + 1u;
        }
    }
}

static void print_diff_for(Workspace *ws, Proposal *p) {
    MemoryFile *old = find_file(ws, p->path);
    printf("--- %s\n+++ %s (memory)\n", old ? p->path : "/dev/null", p->path);
    if (!old) {
        const char *s = (const char *)p->data;
        size_t start = 0;
        for (size_t pos = 0; pos <= p->len; pos++) {
            if (pos == p->len || s[pos] == '\n') {
                printf("+%.*s\n", (int)(pos - start), s + start);
                start = pos + 1;
            }
        }
        return;
    }
    if (old->len == p->len && memcmp(old->data, p->data, p->len) == 0) {
        printf("(no byte changes)\n");
        return;
    }
    size_t prefix = 0;
    while (prefix < old->len && prefix < p->len && old->data[prefix] == p->data[prefix]) {
        prefix++;
    }
    size_t old_start = prefix;
    size_t new_start = prefix;
    while (old_start > 0u && old->data[old_start - 1u] != '\n') old_start--;
    while (new_start > 0u && p->data[new_start - 1u] != '\n') new_start--;

    size_t old_end = old->len;
    size_t new_end = p->len;
    while (old_end > old_start && new_end > new_start &&
           old->data[old_end - 1u] == p->data[new_end - 1u]) {
        old_end--;
        new_end--;
    }
    while (old_end < old->len && old->data[old_end] != '\n') old_end++;
    if (old_end < old->len) old_end++;
    while (new_end < p->len && p->data[new_end] != '\n') new_end++;
    if (new_end < p->len) new_end++;

    size_t old_line = line_number_for_offset(old->data, old_start);
    size_t new_line = line_number_for_offset(p->data, new_start);
    size_t old_lines = line_count_for_range(old->data, old_start, old_end);
    size_t new_lines = line_count_for_range(p->data, new_start, new_end);
    printf("@@ -%zu,%zu +%zu,%zu @@\n", old_line, old_lines, new_line, new_lines);
    print_prefixed_lines('-', old->data, old_start, old_end);
    print_prefixed_lines('+', p->data, new_start, new_end);
}

static void cmd_diff(Workspace *ws, const char *path) {
    if (path && *path) {
        Proposal *p = find_proposal(ws, path);
        if (!p) {
            printf("no proposal for %s\n", path);
            return;
        }
        print_diff_for(ws, p);
        return;
    }
    if (ws->proposal_count == 0) {
        printf("no proposals\n");
        return;
    }
    for (size_t i = 0; i < ws->proposal_count; i++) print_diff_for(ws, &ws->proposals[i]);
}

static void ensure_parent_dirs(const char *path) {
    char tmp[PATH_MAX];
    snprintf(tmp, sizeof(tmp), "%s", path);
    for (char *p = tmp + 1; *p; p++) {
        if (*p == '/') {
            *p = 0;
            if (mkdir(tmp, MODE_PERMISSIONS_MASK) != 0 && errno != EEXIST) {
                die("mkdir failed for %s: %s", tmp, strerror(errno));
            }
            *p = '/';
        }
    }
}

static void write_bytes_atomicish(const char *path, const unsigned char *data, size_t len, mode_t mode, bool mode_known) {
    char tmp[PATH_MAX];
    int n = snprintf(tmp, sizeof(tmp), "%s.tmp.%ld", path, (long)getpid());
    if (n < 0 || n >= PATH_MAX) die("temp path too long");
    ensure_parent_dirs(path);
    FILE *f = fopen(tmp, "wb");
    if (!f) die("open failed for %s: %s", tmp, strerror(errno));
    if (fwrite(data, 1, len, f) != len) {
        fclose(f);
        unlink(tmp);
        die("write failed for %s", tmp);
    }
    if (fclose(f) != 0) {
        unlink(tmp);
        die("close failed for %s", tmp);
    }
    if (mode_known && chmod(tmp, mode & MODE_PERMISSIONS_MASK) != 0) {
        unlink(tmp);
        die("chmod failed for %s: %s", tmp, strerror(errno));
    }
    if (rename(tmp, path) != 0) {
        unlink(tmp);
        die("rename failed for %s: %s", path, strerror(errno));
    }
}

static void cmd_commit(Workspace *ws) {
    if (ws->proposal_count == 0) {
        printf("nothing to commit\n");
        return;
    }
    for (size_t i = 0; i < ws->proposal_count; i++) {
        char abs[PATH_MAX];
        join_path(abs, ws->root, ws->proposals[i].path);
        write_bytes_atomicish(abs, ws->proposals[i].data, ws->proposals[i].len, ws->proposals[i].mode, ws->proposals[i].mode_known);
        printf("wrote %s (%zu bytes)\n", ws->proposals[i].path, ws->proposals[i].len);
    }
    discard_all(ws);
    workspace_clear_files(ws);
    scan_dir(ws, "");
    workspace_rebuild_summaries(ws);
    printf("workspace reloaded from disk\n");
}

static const char *scope_for_path(const char *path) {
    if (starts_with(path, "codex/")) return "codex";
    if (starts_with(path, "edgerun-ui-core/")) return "edgerun-ui-core";
    if (starts_with(path, "varfont/")) return "varfont";
    if (starts_with(path, "edgerun-crypto/")) return "edgerun-crypto";
    if (starts_with(path, "edgerun-metal/")) return "edgerun-metal";
    if (starts_with(path, "docs/")) return "docs";
    if (starts_with(path, "tools/")) return "tools";
    if (starts_with(path, "tests/")) return "tests";
    return ".";
}

static const char *test_target_for_scope(const char *scope) {
    if (strcmp(scope, "codex") == 0) return "codex-test";
    if (strcmp(scope, "edgerun-ui-core") == 0) return "ui-core-test";
    if (strcmp(scope, "varfont") == 0) return "varfont-test";
    if (strcmp(scope, "edgerun-crypto") == 0) return "crypto-test";
    if (strcmp(scope, "edgerun-metal") == 0) return "edgerun-check";
    return "repo-test";
}

static bool scope_list_contains(const char **scopes, size_t count, const char *scope) {
    for (size_t i = 0; i < count; i++) {
        if (strcmp(scopes[i], scope) == 0) return true;
    }
    return false;
}

static char *repo_command_new(Workspace *ws, const char *command) {
    char *root_q = shell_quote_new(ws->root);
    Buffer b;
    buffer_init(&b);
    buffer_appendf(&b, "cd %s && %s 2>&1", root_q, command);
    free(root_q);
    return b.data;
}

#include "edgerun_c_game.c"
#include "edgerun_c_tls.c"
#include "edgerun_c_transport.c"

static char *repo_status_text_new(Workspace *ws) {
    char *cmd = repo_command_new(ws, "git status --short --branch");
    int status = 0;
    char *out = run_command_text_new(cmd, &status);
    Buffer b;
    buffer_init(&b);
    buffer_appendf(&b, "git status exit=%d\n%s", status, out);
    free(cmd);
    free(out);
    return b.data;
}

static char *repo_rules_text_new(Workspace *ws) {
    Buffer b;
    buffer_init(&b);
    size_t len = 0;
    bool text = false;
    const unsigned char *agents = effective_data(ws, "AGENTS.md", &len, &text);
    if (agents && text) {
        buffer_append(&b, "AGENTS.md:\n", strlen("AGENTS.md:\n"));
        buffer_append(&b, (const char *)agents, len);
        if (len == 0 || agents[len - 1] != '\n') buffer_append_c(&b, '\n');
    }
    enum { REPO_PROGRESS_COMMAND_CAPACITY = 256 };
    const char *scopes[] = {"codex", "edgerun-ui-core", "varfont", "edgerun-crypto", "edgerun-metal"};
    for (size_t i = 0; i < sizeof(scopes) / sizeof(scopes[0]); i++) {
        char command[REPO_PROGRESS_COMMAND_CAPACITY];
        snprintf(command, sizeof(command), "./tools/repo-progress.sh --print-plan %s %s",
                 scopes[i], test_target_for_scope(scopes[i]));
        char *cmd = repo_command_new(ws, command);
        int status = 0;
        char *out = run_command_text_new(cmd, &status);
        buffer_appendf(&b, "\nrepo-progress plan for %s exit=%d:\n%s", scopes[i], status, out);
        free(cmd);
        free(out);
    }
    return b.data ? b.data : xstrdup("");
}

static char *initial_context_text_new(Workspace *ws) {
    Buffer b;
    buffer_init(&b);
    const char *intro = "Host-provided repository context. Use this instead of asking for routine git/build checks.\n\n";
    buffer_append(&b, intro, strlen(intro));
    char *status = repo_status_text_new(ws);
    buffer_append(&b, status, strlen(status));
    free(status);
    buffer_appendf(&b,
                   "\nworkspace files loaded: %zu\ncached file summaries: %zu\npending in-memory proposals: %zu\n",
                   ws->file_count,
                   ws->summary_count,
                   ws->proposal_count);
    char *game = quality_game_text_new();
    buffer_append(&b, game, strlen(game));
    free(game);
    const char *policy =
        "\nVerification policy: after proposals, the host writes only proposed paths, runs scoped repo-progress, "
        "and commits only if verification passes.\n";
    buffer_append(&b, policy, strlen(policy));
    return b.data;
}

static int verify_scope(Workspace *ws, const char *scope) {
    const char *target = test_target_for_scope(scope);
    char *scope_q = shell_quote_new(scope);
    char *target_q = shell_quote_new(target);
    Buffer command;
    buffer_init(&command);
    buffer_appendf(&command, "./tools/repo-progress.sh %s %s", scope_q, target_q);
    char *cmd = repo_command_new(ws, command.data);
    printf("status: verifying %s with %s\n", scope, target);
    int status = run_command_checked(cmd);
    free(scope_q);
    free(target_q);
    free(command.data);
    free(cmd);
    if (status == 0) printf("status: verification passed for %s\n", scope);
    else printf("status: verification failed for %s\n", scope);
    return status;
}

static int ensure_main_branch(Workspace *ws) {
    char *cmd = repo_command_new(ws, "git rev-parse --abbrev-ref HEAD");
    int status = 0;
    char *branch = run_command_text_new(cmd, &status);
    trim_newline(branch);
    free(cmd);
    if (status != 0 || strcmp(branch, "main") != 0) {
        fprintf(stderr, "commit aborted: expected branch main, got %s\n", *branch ? branch : "(unknown)");
        free(branch);
        return 1;
    }
    free(branch);
    return 0;
}

static int write_all_proposals(Workspace *ws) {
    for (size_t i = 0; i < ws->proposal_count; i++) {
        char abs[PATH_MAX];
        join_path(abs, ws->root, ws->proposals[i].path);
        write_bytes_atomicish(abs, ws->proposals[i].data, ws->proposals[i].len, ws->proposals[i].mode, ws->proposals[i].mode_known);
        printf("status: wrote %s (%zu bytes)\n", ws->proposals[i].path, ws->proposals[i].len);
    }
    return 0;
}

static int stage_owned_paths(Workspace *ws) {
    for (size_t i = 0; i < ws->proposal_count; i++) {
        char *path_q = shell_quote_new(ws->proposals[i].path);
        Buffer command;
        buffer_init(&command);
        buffer_appendf(&command, "git add -- %s", path_q);
        char *cmd = repo_command_new(ws, command.data);
        int status = run_command_checked(cmd);
        free(path_q);
        free(command.data);
        free(cmd);
        if (status != 0) return status;
    }
    return 0;
}

static char *commit_subject_new(Workspace *ws) {
    const char *scope = ws->proposal_count ? scope_for_path(ws->proposals[0].path) : ".";
    bool same_scope = true;
    for (size_t i = 1; i < ws->proposal_count; i++) {
        if (strcmp(scope, scope_for_path(ws->proposals[i].path)) != 0) same_scope = false;
    }
    Buffer b;
    buffer_init(&b);
    buffer_appendf(&b, "%s: apply verified Codex changes", same_scope ? scope : "repo");
    if (b.len > GIT_COMMIT_SUBJECT_BYTES) b.data[GIT_COMMIT_SUBJECT_BYTES] = 0;
    return b.data;
}

static int cmd_commit_verified(Workspace *ws) {
    if (ws->proposal_count == 0) {
        printf("status: nothing to verify or commit\n");
        return 0;
    }
    if (ensure_main_branch(ws) != 0) return 1;

    const char **scopes = xmalloc(ws->proposal_count * sizeof(scopes[0]));
    size_t scope_count = 0;
    for (size_t i = 0; i < ws->proposal_count; i++) {
        const char *scope = scope_for_path(ws->proposals[i].path);
        if (!scope_list_contains(scopes, scope_count, scope)) scopes[scope_count++] = scope;
    }

    CodexGameInspectTotals *quality_before =
        xmalloc(scope_count * sizeof(quality_before[0]));
    CodexGameInspectTotals *quality_after =
        xmalloc(scope_count * sizeof(quality_after[0]));
    char *subject = NULL;
    char *subject_q = NULL;
    char *cmd = NULL;
    Buffer commit_cmd;
    buffer_init(&commit_cmd);
    int status = codex_game_inspect_scopes(ws, scopes, scope_count,
                                           quality_before);
    if (status == 0) {
        status = write_all_proposals(ws);
    }
    for (size_t i = 0; i < scope_count && status == 0; i++) {
        status = verify_scope(ws, scopes[i]);
    }
    if (status == 0) {
        status = codex_game_inspect_scopes(ws, scopes, scope_count,
                                           quality_after);
    }
    if (status == 0) {
        CodexGameQualityScore quality =
            codex_game_quality_score(quality_before, quality_after,
                                     scope_count);
        codex_game_quality_score_print(quality);
        if (quality.score < CODEX_GAME_SCORE_GATE_FLOOR) {
            fprintf(stderr, "commit aborted: quality game score is negative\n");
            status = 1;
        }
    }
    if (status == 0) {
        status = stage_owned_paths(ws);
    }
    if (status == 0) {
        subject = commit_subject_new(ws);
        subject_q = shell_quote_new(subject);
        buffer_appendf(&commit_cmd, "git commit -m %s", subject_q);
        cmd = repo_command_new(ws, commit_cmd.data);
        printf("status: committing verified changes\n");
        status = run_command_checked(cmd);
    }
    if (status == 0) {
        char *show = repo_command_new(ws, "git rev-parse --short HEAD");
        int show_status = 0;
        char *sha = run_command_text_new(show, &show_status);
        trim_newline(sha);
        printf("status: committed %s\n", show_status == 0 ? sha : "(unknown)");
        free(show);
        free(sha);
        discard_all(ws);
        workspace_clear_files(ws);
        scan_dir(ws, "");
        workspace_rebuild_summaries(ws);
        printf("status: workspace reloaded from disk\n");
    }
    free(quality_before);
    free(quality_after);
    free(scopes);
    free(subject);
    free(subject_q);
    free(commit_cmd.data);
    free(cmd);
    return status;
}

static void print_agent_summary(const AgentRunSummary *summary) {
    printf("\n%s%s Turn summary %s\n",
           color_code(stdout, ANSI_BOLD), "📋", color_code(stdout, ANSI_RESET));
    printf("  %smodel:%s %s\n", color_code(stdout, ANSI_CYAN), color_code(stdout, ANSI_RESET), summary->model);
    printf("  %sturns:%s %zu\n", color_code(stdout, ANSI_CYAN), color_code(stdout, ANSI_RESET), summary->turns);
    printf("  %stool calls:%s %zu\n", color_code(stdout, ANSI_CYAN), color_code(stdout, ANSI_RESET), summary->tool_calls);
    printf("  %scheckpoints:%s %zu\n", color_code(stdout, ANSI_CYAN), color_code(stdout, ANSI_RESET), summary->checkpoints);
    printf("  %sreview-only turns:%s %zu\n",
           color_code(stdout, ANSI_CYAN), color_code(stdout, ANSI_RESET), summary->review_only_turns);
    printf("  %sproposals before commit:%s %zu\n",
           color_code(stdout, ANSI_CYAN), color_code(stdout, ANSI_RESET), summary->proposals_before_commit);
    if (summary->commit_status == 0) {
        print_icon_line(stdout, "✅", ANSI_GREEN, "verified commit flow completed");
    } else {
        print_icon_line(stdout, "❌", ANSI_RED, "verified commit flow failed with status %d", summary->commit_status);
    }
}

static char *host_continue_message_new(Workspace *ws, bool checkpoint_committed) {
    char *status = repo_status_text_new(ws);
    Buffer b;
    buffer_init(&b);
    if (checkpoint_committed) {
        buffer_append(&b,
            "Host checkpoint completed: the previous proposal batch verified and committed. "
            "Continue the autonomous work loop. Pick the next concrete repo improvement, inspect only the context needed, "
            "and stage another material change with propose_change. Do not stop at a review or plan.\n\n",
            strlen("Host checkpoint completed: the previous proposal batch verified and committed. "
                   "Continue the autonomous work loop. Pick the next concrete repo improvement, inspect only the context needed, "
                   "and stage another material change with propose_change. Do not stop at a review or plan.\n\n"));
    } else {
        buffer_append(&b,
            "Host progress check: the turn ended with no pending proposals, so no code was saved. "
            "This client is meant to keep working, not hand back a review. Choose one concrete implementation step now, "
            "use the repo tools for missing context, and call propose_change. Do not answer with a plan-only response.\n\n",
            strlen("Host progress check: the turn ended with no pending proposals, so no code was saved. "
                   "This client is meant to keep working, not hand back a review. Choose one concrete implementation step now, "
                   "use the repo tools for missing context, and call propose_change. Do not answer with a plan-only response.\n\n"));
    }
    buffer_append(&b, status, strlen(status));
    free(status);
    return b.data;
}

static void buffer_append_excerpt(Buffer *b, const char *text, size_t max_bytes) {
    size_t len = strlen(text);
    size_t n = len < max_bytes ? len : max_bytes;
    buffer_append(b, text, n);
    if (len > n) buffer_append(b, "\n[truncated]\n", strlen("\n[truncated]\n"));
}

static char *session_memory_message_new(
    Workspace *ws,
    const AgentRunSummary *summary,
    const char *user_prompt,
    const char *exchange) {
    Buffer b;
    buffer_init(&b);
    buffer_append(&b,
        "Fixed end-of-turn carry-forward summary for the next user prompt. "
        "Keep this context, but prefer fresh repository tools when facts may have changed.\n\n",
        strlen("Fixed end-of-turn carry-forward summary for the next user prompt. "
               "Keep this context, but prefer fresh repository tools when facts may have changed.\n\n"));
    buffer_appendf(&b, "last user prompt:\n%s\n\n", user_prompt);
    buffer_appendf(&b,
                   "turn counters: turns=%zu tool_calls=%zu checkpoints=%zu review_only_turns=%zu last_commit_status=%d\n",
                   summary->turns,
                   summary->tool_calls,
                   summary->checkpoints,
                   summary->review_only_turns,
                   summary->commit_status);
    char *status = repo_status_text_new(ws);
    const char *status_title = "\nrepository status after turn:\n";
    buffer_append(&b, status_title, strlen(status_title));
    buffer_append(&b, status, strlen(status));
    free(status);
    const char *exchange_title = "\ncompact exchange record:\n";
    buffer_append(&b, exchange_title, strlen(exchange_title));
    buffer_append_excerpt(&b, exchange, SESSION_EXCERPT_BYTES * 8u);
    return b.data;
}

static char *read_session_prompt_new(void) {
    char *line = NULL;
    size_t cap = 0;
    for (;;) {
        printf("%scodex user>%s ", color_code(stdout, ANSI_BLUE), color_code(stdout, ANSI_RESET));
        fflush(stdout);
        if (getline(&line, &cap, stdin) == -1) {
            free(line);
            return NULL;
        }
        trim_newline(line);
        char *p = line;
        while (*p && isspace((unsigned char)*p)) p++;
        if (*p == 0) continue;
        if (strcmp(p, "quit") == 0 || strcmp(p, "exit") == 0) {
            free(line);
            return NULL;
        }
        char *out = xstrdup(p);
        free(line);
        return out;
    }
}

static void trim_newline(char *s) {
    size_t n = strlen(s);
    while (n && (s[n - 1] == '\n' || s[n - 1] == '\r')) s[--n] = 0;
}

static char *next_token(char **cursor) {
    char *s = *cursor;
    while (*s && isspace((unsigned char)*s)) s++;
    if (!*s) {
        *cursor = s;
        return NULL;
    }
    char *start = s;
    while (*s && !isspace((unsigned char)*s)) s++;
    if (*s) *s++ = 0;
    *cursor = s;
    return start;
}

static void print_help(void) {
    printf("%scommands:%s\n", color_code(stdout, ANSI_BOLD), color_code(stdout, ANSI_RESET));
    puts("  ❔ help");
    puts("  📊 stats");
    puts("  🧠 summarize [query] [limit]");
    puts("  🔎 search <text> [limit]");
    puts("  📖 read <path> [start_line] [max_lines]");
    puts("  ✍️  propose <path>   # full content until .end");
    puts("  📖 show <path>");
    puts("  🧾 diff [path]");
    puts("  🗑️  discard <path>");
    puts("  🗑️  discard --all");
    puts("  💾 commit           # writes staged in-memory replacements to disk");
    puts("  ✅ commit-verified  # verifies scoped repo-progress, then git commits");
    puts("  🚪 quit");
}

static char *workspace_search_text_new(Workspace *ws, const char *query, size_t limit) {
    if (!query || !*query) return xstrdup("tool error: query must not be empty");
    Buffer out;
    buffer_init(&out);
    size_t hits = 0;
    for (size_t i = 0; i < ws->file_count && (limit == 0 || hits < limit); i++) {
        MemoryFile *f = &ws->files[i];
        if (!f->text) continue;
        const char *text = (const char *)f->data;
        size_t start = 0;
        size_t line_no = 1;
        for (size_t pos = 0; pos <= f->len && (limit == 0 || hits < limit); pos++) {
            if (pos == f->len || text[pos] == '\n') {
                size_t line_len = pos - start;
                if (contains_case_insensitive(text + start, line_len, query)) {
                    buffer_appendf(&out, "%s:%zu: %.*s\n", f->path, line_no, (int)line_len, text + start);
                    hits++;
                }
                start = pos + 1;
                line_no++;
            }
        }
    }
    if (hits == 0) buffer_append(&out, "no matches\n", strlen("no matches\n"));
    return out.data;
}

static char *workspace_read_text_new(Workspace *ws, const char *path, size_t start_line, size_t max_lines) {
    if (!path_is_safe(path)) return xstrdup("tool error: invalid workspace-relative path");
    size_t len = 0;
    bool text = false;
    const unsigned char *data = effective_data(ws, path, &len, &text);
    if (!data) {
        Buffer b;
        buffer_init(&b);
        buffer_appendf(&b, "tool error: file not loaded: %s", path);
        return b.data;
    }
    if (!text) {
        Buffer b;
        buffer_init(&b);
        buffer_appendf(&b, "tool error: file is binary or unsupported text: %s (%zu bytes)", path, len);
        return b.data;
    }
    if (start_line == 0) start_line = 1;
    Buffer out;
    buffer_init(&out);
    buffer_appendf(&out, "file: %s\n", path);
    const char *s = (const char *)data;
    size_t line_no = 1;
    size_t emitted = 0;
    size_t start = 0;
    for (size_t pos = 0; pos <= len && (max_lines == 0 || emitted < max_lines); pos++) {
        if (pos == len || s[pos] == '\n') {
            if (line_no >= start_line) {
                buffer_appendf(&out, "%5zu | %.*s\n", line_no, (int)(pos - start), s + start);
                emitted++;
            }
            start = pos + 1;
            line_no++;
        }
    }
    return out.data;
}

static char *workspace_propose_text_new(Workspace *ws, const char *path, const char *content, const char *note) {
    if (!path_is_safe(path)) return xstrdup("tool error: invalid workspace-relative path");
    size_t len = strlen(content);
    upsert_proposal(ws, path, (const unsigned char *)content, len);
    Buffer out;
    buffer_init(&out);
    buffer_appendf(&out, "accepted in-memory proposal: %s (%zu bytes)\nnote: %s\nNo disk files were changed.",
                   path, len, (note && *note) ? note : "no note");
    return out.data;
}

static char *execute_agent_tool_new(Workspace *ws, const ToolCall *tool, bool *success_out) {
    *success_out = false;
    if (strcmp(tool->name, "project_status") == 0) {
        *success_out = true;
        return repo_status_text_new(ws);
    }
    if (strcmp(tool->name, "repo_rules") == 0) {
        *success_out = true;
        return repo_rules_text_new(ws);
    }
    if (strcmp(tool->name, "summarize_code") == 0) {
        char *query = json_get_string_dup(tool->arguments, "query");
        char *limit_s = json_get_scalar_dup(tool->arguments, "limit");
        size_t limit = limit_s ? (size_t)strtoull(limit_s, NULL, 10) : 20;
        char *out = workspace_summary_query_new(ws, query ? query : "", limit);
        *success_out = true;
        free(query);
        free(limit_s);
        return out;
    }
    if (strcmp(tool->name, "verify_scope") == 0) {
        char *scope = json_get_string_dup(tool->arguments, "scope");
        const char *selected = (scope && *scope) ? scope : ".";
        Buffer out;
        buffer_init(&out);
        int status = verify_scope(ws, selected);
        buffer_appendf(&out, "verify_scope %s exit=%d", selected, status);
        *success_out = status == 0;
        free(scope);
        return out.data;
    }
    if (strcmp(tool->name, "commit_verified") == 0) {
        if (g_codex_memory_only) {
            *success_out = false;
            return xstrdup("commit_verified disabled: memory-only mode keeps proposals in memory");
        }
        int status = cmd_commit_verified(ws);
        Buffer out;
        buffer_init(&out);
        buffer_appendf(&out, "commit_verified exit=%d", status);
        *success_out = status == 0;
        return out.data;
    }
    if (strcmp(tool->name, "search_code") == 0) {
        char *query = json_get_string_dup(tool->arguments, "query");
        char *limit_s = json_get_scalar_dup(tool->arguments, "limit");
        size_t limit = limit_s ? (size_t)strtoull(limit_s, NULL, 10) : 0;
        char *out = workspace_search_text_new(ws, query ? query : "", limit);
        *success_out = query != NULL;
        free(query);
        free(limit_s);
        return out;
    }
    if (strcmp(tool->name, "read_code") == 0) {
        char *path = json_get_string_dup(tool->arguments, "path");
        char *start_s = json_get_scalar_dup(tool->arguments, "start_line");
        char *max_s = json_get_scalar_dup(tool->arguments, "max_lines");
        char *out = workspace_read_text_new(ws, path ? path : "",
            start_s ? (size_t)strtoull(start_s, NULL, 10) : 1,
            max_s ? (size_t)strtoull(max_s, NULL, 10) : 0);
        *success_out = path != NULL;
        free(path);
        free(start_s);
        free(max_s);
        return out;
    }
    if (strcmp(tool->name, "propose_change") == 0) {
        char *path = json_get_string_dup(tool->arguments, "path");
        char *content = json_get_string_dup(tool->arguments, "content");
        char *note = json_get_string_dup(tool->arguments, "note");
        char *out = (path && content)
            ? workspace_propose_text_new(ws, path, content, note)
            : xstrdup("tool error: path and content are required");
        *success_out = path && content;
        free(path);
        free(content);
        free(note);
        return out;
    }
    Buffer out;
    buffer_init(&out);
    buffer_appendf(&out, "tool error: unsupported tool %s", tool->name);
    return out.data;
}

static const char *tools_json(void) {
    return "["
        "{\"type\":\"function\",\"name\":\"project_status\",\"description\":\"Returns host-gathered git branch and workspace status. Use instead of asking for git status.\",\"strict\":false,\"parameters\":{\"type\":\"object\",\"properties\":{},\"additionalProperties\":false}},"
        "{\"type\":\"function\",\"name\":\"repo_rules\",\"description\":\"Returns repository rules and the exact repo-progress verification plans for known scopes.\",\"strict\":false,\"parameters\":{\"type\":\"object\",\"properties\":{},\"additionalProperties\":false}},"
        "{\"type\":\"function\",\"name\":\"summarize_code\",\"description\":\"Returns deterministic cached summaries for matching files and related code context. Use before raw reads when orienting on a topic.\",\"strict\":false,\"parameters\":{\"type\":\"object\",\"properties\":{\"query\":{\"type\":\"string\",\"description\":\"Path, symbol, include, or topic text to match against cached summaries\"},\"limit\":{\"type\":\"number\",\"description\":\"Maximum matching summaries to return\"}},\"required\":[\"query\"],\"additionalProperties\":false}},"
        "{\"type\":\"function\",\"name\":\"verify_scope\",\"description\":\"Runs the repository-owned scoped progress check for a scope. Use only when explicit mid-turn verification is needed; the host also verifies automatically before commit.\",\"strict\":false,\"parameters\":{\"type\":\"object\",\"properties\":{\"scope\":{\"type\":\"string\",\"description\":\"Repository scope such as codex, edgerun-ui-core, varfont, edgerun-crypto, edgerun-metal, docs, tools, tests, or .\"}},\"required\":[\"scope\"],\"additionalProperties\":false}},"
        "{\"type\":\"function\",\"name\":\"commit_verified\",\"description\":\"Writes pending proposals, runs scoped repo-progress verification, stages only proposed paths, and creates a git commit only if verification passes. The host also runs this automatically after final proposed changes.\",\"strict\":false,\"parameters\":{\"type\":\"object\",\"properties\":{},\"additionalProperties\":false}},"
        "{\"type\":\"function\",\"name\":\"search_code\",\"description\":\"Searches the in-memory workspace snapshot. No disk or process access.\",\"strict\":false,\"parameters\":{\"type\":\"object\",\"properties\":{\"query\":{\"type\":\"string\",\"description\":\"Text to search for in UTF-8 workspace files\"},\"limit\":{\"type\":\"number\",\"description\":\"Maximum number of matching lines to return\"}},\"required\":[\"query\"],\"additionalProperties\":false}},"
        "{\"type\":\"function\",\"name\":\"read_code\",\"description\":\"Reads a UTF-8 file from the in-memory workspace snapshot.\",\"strict\":false,\"parameters\":{\"type\":\"object\",\"properties\":{\"path\":{\"type\":\"string\",\"description\":\"Workspace-relative UTF-8 file path to read\"},\"start_line\":{\"type\":\"number\",\"description\":\"One-based first line to return\"},\"max_lines\":{\"type\":\"number\",\"description\":\"Maximum number of lines to return\"}},\"required\":[\"path\"],\"additionalProperties\":false}},"
        "{\"type\":\"function\",\"name\":\"propose_change\",\"description\":\"Stages a complete-file replacement in the in-memory workspace. Does not write to disk.\",\"strict\":false,\"parameters\":{\"type\":\"object\",\"properties\":{\"path\":{\"type\":\"string\",\"description\":\"Workspace-relative file path to replace in memory\"},\"content\":{\"type\":\"string\",\"description\":\"Complete proposed file contents. This is stored only in memory.\"},\"note\":{\"type\":\"string\",\"description\":\"Short explanation of the proposed change\"}},\"required\":[\"path\",\"content\"],\"additionalProperties\":false}}"
        "]";
}

static const char *json_find_key_value_start(const char *json, const char *key) {
    char needle[128];
    snprintf(needle, sizeof(needle), "\"%s\"", key);
    const char *p = strstr(json, needle);
    if (!p) return NULL;
    p += strlen(needle);
    while (*p && isspace((unsigned char)*p)) p++;
    if (*p++ != ':') return NULL;
    while (*p && isspace((unsigned char)*p)) p++;
    return p;
}

static char *json_dup_balanced_value(const char *start) {
    if (!start) return NULL;
    if (*start == '"') {
        const char *p = start + 1;
        bool esc = false;
        while (*p) {
            if (esc) esc = false;
            else if (*p == '\\') esc = true;
            else if (*p == '"') {
                size_t n = (size_t)(p - start + 1);
                char *out = xmalloc(n + 1);
                memcpy(out, start, n);
                out[n] = 0;
                return out;
            }
            p++;
        }
        return NULL;
    }
    if (*start == '{' || *start == '[') {
        char open = *start;
        char close = open == '{' ? '}' : ']';
        int depth = 0;
        bool in_string = false;
        bool esc = false;
        const char *p = start;
        while (*p) {
            if (in_string) {
                if (esc) esc = false;
                else if (*p == '\\') esc = true;
                else if (*p == '"') in_string = false;
            } else {
                if (*p == '"') in_string = true;
                else if (*p == open) depth++;
                else if (*p == close && --depth == 0) {
                    size_t n = (size_t)(p - start + 1);
                    char *out = xmalloc(n + 1);
                    memcpy(out, start, n);
                    out[n] = 0;
                    return out;
                }
            }
            p++;
        }
    }
    return NULL;
}

static void agent_turn_init(AgentTurn *turn) {
    memset(turn, 0, sizeof(*turn));
    turn->text = xstrdup("");
}

static void agent_turn_free(AgentTurn *turn) {
    free(turn->text);
    for (size_t i = 0; i < turn->tool_count; i++) {
        free(turn->tools[i].name);
        free(turn->tools[i].arguments);
        free(turn->tools[i].call_id);
    }
    free(turn->tools);
    json_items_free(&turn->output_items);
}

static void agent_turn_append_text(AgentTurn *turn, const char *delta) {
    Buffer b;
    buffer_init(&b);
    if (turn->text) buffer_append(&b, turn->text, strlen(turn->text));
    buffer_append(&b, delta, strlen(delta));
    free(turn->text);
    turn->text = b.data;
}

static void agent_turn_add_tool(AgentTurn *turn, char *name, char *arguments, char *call_id) {
    turn->tools = xrealloc(turn->tools, (turn->tool_count + 1) * sizeof(turn->tools[0]));
    turn->tools[turn->tool_count++] = (ToolCall){
        .name = name,
        .arguments = arguments,
        .call_id = call_id,
    };
}

static void process_output_item_json(AgentTurn *turn, char *item_json) {
    char *type = json_get_string_dup(item_json, "type");
    if (type && strcmp(type, "function_call") == 0) {
        char *name = json_get_string_dup(item_json, "name");
        char *arguments = json_get_string_dup(item_json, "arguments");
        char *call_id = json_get_string_dup(item_json, "call_id");
        if (name && arguments && call_id) {
            agent_turn_add_tool(turn, xstrdup(name), xstrdup(arguments), xstrdup(call_id));
            char *name_json = json_escape_new(name);
            char *arguments_json = json_escape_new(arguments);
            char *call_id_json = json_escape_new(call_id);
            Buffer normalized;
            buffer_init(&normalized);
            buffer_appendf(&normalized,
                "{\"type\":\"function_call\",\"name\":%s,\"arguments\":%s,\"call_id\":%s}",
                name_json, arguments_json, call_id_json);
            json_items_push(&turn->output_items, normalized.data);
            free(name_json);
            free(arguments_json);
            free(call_id_json);
            free(name);
            free(arguments);
            free(call_id);
            free(type);
            free(item_json);
            return;
        }
        free(name);
        free(arguments);
        free(call_id);
    }
    free(type);
    free(item_json);
}

static void process_sse_json_event(AgentTurn *turn, const char *event_json) {
    char *type = json_get_string_dup(event_json, "type");
    if (!type) return;
    if (strcmp(type, "response.output_text.delta") == 0) {
        char *delta = json_get_string_dup(event_json, "delta");
        if (delta) {
            if (!g_codex_quiet_agent) {
                fputs(delta, stdout);
                fflush(stdout);
            }
            agent_turn_append_text(turn, delta);
            free(delta);
        }
    } else if (strcmp(type, "response.output_item.done") == 0) {
        char *item = json_dup_balanced_value(json_find_key_value_start(event_json, "item"));
        if (item) process_output_item_json(turn, item);
    } else if (strcmp(type, "response.failed") == 0) {
        char *message = json_get_string_dup(event_json, "message");
        if (message) {
            fprintf(stderr, "\nresponse failed: %s\n", message);
            free(message);
        } else {
            fprintf(stderr, "\nresponse failed\n");
        }
    }
    free(type);
}

static char *build_responses_body_new(const char *model, const CodexSession *session, JsonItems *history) {
    char *model_json = json_escape_new(model);
    char *instructions_json = json_escape_new(AGENT_INSTRUCTIONS);
    char *installation_json = json_escape_new(session->installation_id);
    char *window_json = json_escape_new(session->window_id);
    Buffer b;
    buffer_init(&b);
    buffer_appendf(&b,
        "{\"model\":%s,\"instructions\":%s,\"input\":[",
        model_json, instructions_json);
    for (size_t i = 0; i < history->count; i++) {
        if (i) buffer_append_c(&b, ',');
        buffer_append(&b, history->items[i], strlen(history->items[i]));
    }
    buffer_appendf(&b,
        "],\"tools\":%s,\"tool_choice\":\"auto\",\"parallel_tool_calls\":true,\"store\":false,\"stream\":true,\"prompt_cache_key\":%s,"
        "\"client_metadata\":{\"x-codex-installation-id\":%s,\"x-codex-window-id\":%s}}",
        tools_json(), window_json, installation_json, window_json);
    free(model_json);
    free(instructions_json);
    free(installation_json);
    free(window_json);
    return b.data;
}

static void debug_write_body(const char *body) {
    const char *debug = getenv("EDGERUN_C_DEBUG");
    if (!debug || strcmp(debug, "1") != 0) return;
    static unsigned long counter = 0;
    char path[PATH_MAX];
    snprintf(path, sizeof(path), "/tmp/edgerun-c-request-%lu.json", counter++);
    FILE *f = fopen(path, "wb");
    if (!f) return;
    fwrite(body, 1, strlen(body), f);
    fclose(f);
    fprintf(stderr, "[debug] wrote request body %s\n", path);
}

static void codex_transport_event(void *user, const char *event_json) {
    AgentTurn *turn = (AgentTurn *)user;
    process_sse_json_event(turn, event_json);
}

typedef struct {
    ErHttpHeader headers[CODEX_SSE_HEADER_CAP];
    size_t count;
    Buffer auth;
    Buffer request_id;
    Buffer session_id;
    Buffer thread_id;
    Buffer installation_id;
    Buffer window_id;
    Buffer account_id;
} CodexSseHeaders;

static void codex_sse_headers_append(CodexSseHeaders *out, const char *name, const char *value) {
    if (out->count >= CODEX_SSE_HEADER_CAP) die("too many Codex SSE headers");
    out->headers[out->count++] = (ErHttpHeader){name, value};
}

static void codex_sse_headers_init(CodexSseHeaders *out, const CodexAuth *auth, const CodexSession *session) {
    memset(out, 0, sizeof(*out));
    buffer_init(&out->auth);
    buffer_init(&out->request_id);
    buffer_init(&out->session_id);
    buffer_init(&out->thread_id);
    buffer_init(&out->installation_id);
    buffer_init(&out->window_id);
    buffer_init(&out->account_id);
    buffer_appendf(&out->auth, "Bearer %s", auth->access_token);
    buffer_appendf(&out->request_id, "%s", session->thread_id);
    buffer_appendf(&out->session_id, "%s", session->session_id);
    buffer_appendf(&out->thread_id, "%s", session->thread_id);
    buffer_appendf(&out->installation_id, "%s", session->installation_id);
    buffer_appendf(&out->window_id, "%s", session->window_id);
    codex_sse_headers_append(out, "accept", "text/event-stream");
    codex_sse_headers_append(out, "content-type", "application/json");
    codex_sse_headers_append(out, "version", CODEX_BACKEND_VERSION);
    codex_sse_headers_append(out, "authorization", out->auth.data);
    codex_sse_headers_append(out, "x-client-request-id", out->request_id.data);
    codex_sse_headers_append(out, "session_id", out->session_id.data);
    codex_sse_headers_append(out, "thread_id", out->thread_id.data);
    codex_sse_headers_append(out, "x-codex-installation-id", out->installation_id.data);
    codex_sse_headers_append(out, "x-codex-window-id", out->window_id.data);
    if (auth->account_id) {
        buffer_appendf(&out->account_id, "%s", auth->account_id);
        codex_sse_headers_append(out, "ChatGPT-Account-ID", out->account_id.data);
    }
}

static void codex_sse_headers_free(CodexSseHeaders *headers) {
    free(headers->auth.data);
    free(headers->request_id.data);
    free(headers->session_id.data);
    free(headers->thread_id.data);
    free(headers->installation_id.data);
    free(headers->window_id.data);
    free(headers->account_id.data);
}

static const char *codex_sse_header_value(const CodexSseHeaders *headers, const char *name) {
    for (size_t i = 0; i < headers->count; i++) {
        if (strcmp(headers->headers[i].name, name) == 0) return headers->headers[i].value;
    }
    return NULL;
}

static bool codex_sse_header_matches(const CodexSseHeaders *headers, const char *name, const char *value) {
    const char *actual = codex_sse_header_value(headers, name);
    return actual && strcmp(actual, value) == 0;
}

static bool codex_sse_headers_self_test(void) {
    CodexAuth auth = {
        .access_token = "token",
        .account_id = "account",
    };
    CodexSession session;
    CodexSseHeaders headers;
    bool ok;

    memset(&session, 0, sizeof(session));
    snprintf(session.thread_id, sizeof(session.thread_id), "thread");
    snprintf(session.session_id, sizeof(session.session_id), "session");
    snprintf(session.installation_id, sizeof(session.installation_id), "install");
    snprintf(session.window_id, sizeof(session.window_id), "window");
    codex_sse_headers_init(&headers, &auth, &session);
    ok = headers.count == CODEX_SSE_HEADER_CAP &&
         codex_sse_header_matches(&headers, "authorization", "Bearer token") &&
         codex_sse_header_matches(&headers, "x-client-request-id", "thread") &&
         codex_sse_header_matches(&headers, "session_id", "session") &&
         codex_sse_header_matches(&headers, "thread_id", "thread") &&
         codex_sse_header_matches(&headers, "x-codex-installation-id", "install") &&
         codex_sse_header_matches(&headers, "x-codex-window-id", "window") &&
         codex_sse_header_matches(&headers, "ChatGPT-Account-ID", "account");
    codex_sse_headers_free(&headers);
    return ok;
}

static AgentTurn codex_stream_turn(const char *model, const CodexAuth *auth, const CodexSession *session, JsonItems *history) {
    AgentTurn turn;
    agent_turn_init(&turn);
    char *body = build_responses_body_new(model, session, history);
    debug_write_body(body);
    CodexSseHeaders headers;
    codex_sse_headers_init(&headers, auth, session);
    er_transport_post_sse(CODEX_BACKEND_URL, headers.headers, headers.count, body, codex_transport_event, &turn);
    free(body);
    codex_sse_headers_free(&headers);
    return turn;
}

static int run_agent_prompt(Workspace *ws, const char *prompt) {
    const char *model = getenv("CODEX_TUI_MODEL");
    if (!model || !*model) model = DEFAULT_MODEL;
    AgentRunSummary summary = {
        .model = model,
        .turns = 0,
        .tool_calls = 0,
        .checkpoints = 0,
        .review_only_turns = 0,
        .proposals_before_commit = 0,
        .commit_status = 0,
    };
    CodexAuth auth = read_codex_auth();
    CodexSession session;
    codex_session_init(&session);
    JsonItems history = {0};
    if (!g_codex_minimal_agent) {
        char *context = initial_context_text_new(ws);
        json_items_push(&history, user_item_json_new(context));
        free(context);
    }
    json_items_push(&history, user_item_json_new(prompt));

    for (;;) {
        AgentTurn turn = codex_stream_turn(model, &auth, &session, &history);
        summary.turns++;
        for (size_t i = 0; i < turn.output_items.count; i++) {
            json_items_push(&history, xstrdup(turn.output_items.items[i]));
        }
        if (turn.tool_count == 0) {
            if (!g_codex_quiet_agent) putchar('\n');
            agent_turn_free(&turn);
            summary.proposals_before_commit = ws->proposal_count;
            if (ws->proposal_count == 0) {
                summary.review_only_turns++;
                summary.commit_status = 0;
                if (!g_codex_quiet_agent) print_agent_summary(&summary);
                if (g_codex_memory_only) {
                    json_items_free(&history);
                    free(auth.access_token);
                    free(auth.account_id);
                    return 0;
                }
                char *continue_message = host_continue_message_new(ws, false);
                json_items_push(&history, user_item_json_new(continue_message));
                free(continue_message);
                continue;
            }
            if (g_codex_memory_only) {
                cmd_diff(ws, NULL);
                summary.commit_status = 0;
                if (!g_codex_quiet_agent) print_agent_summary(&summary);
                json_items_free(&history);
                free(auth.access_token);
                free(auth.account_id);
                return 0;
            } else {
                summary.commit_status = cmd_commit_verified(ws);
            }
            if (!g_codex_quiet_agent) print_agent_summary(&summary);
            if (summary.commit_status != 0) {
                json_items_free(&history);
                free(auth.access_token);
                free(auth.account_id);
                return summary.commit_status;
            }
            summary.checkpoints++;
            char *continue_message = host_continue_message_new(ws, true);
            json_items_push(&history, user_item_json_new(continue_message));
            free(continue_message);
            continue;
        }
        for (size_t i = 0; i < turn.tool_count; i++) {
            bool ok = false;
            summary.tool_calls++;
            if (!g_codex_quiet_agent) {
                fprintf(stderr, "\n%s🔧 tool%s %s\n",
                        color_code(stderr, ANSI_BLUE), color_code(stderr, ANSI_RESET), turn.tools[i].name); //@optimizer-ignore ANSI color constants use the fixed palette indexes accepted by color_code.
            }
            char *tool_out = execute_agent_tool_new(ws, &turn.tools[i], &ok);
            if (!g_codex_quiet_agent) {
                fprintf(stderr, "%s%s tool result%s %.160s%s\n",
                        color_code(stderr, ok ? ANSI_GREEN : ANSI_RED),
                        ok ? "✅" : "❌",
                        color_code(stderr, ANSI_RESET),
                        tool_out,
                        strlen(tool_out) > 160 ? "..." : "");
            }
            json_items_push(&history, tool_output_item_json_new(turn.tools[i].call_id, tool_out, ok));
            free(tool_out);
        }
        agent_turn_free(&turn);
    }
}

static void repl(Workspace *ws) {
    print_help();
    char *line = NULL;
    size_t cap = 0;
    for (;;) {
        printf("%sedgerun-c>%s ", color_code(stdout, ANSI_BLUE), color_code(stdout, ANSI_RESET));
        fflush(stdout);
        if (getline(&line, &cap, stdin) == -1) break;
        trim_newline(line);
        char *cursor = line;
        char *cmd = next_token(&cursor);
        if (!cmd) continue;
        if (strcmp(cmd, "help") == 0) {
            print_help();
        } else if (strcmp(cmd, "stats") == 0) {
            cmd_stats(ws);
        } else if (strcmp(cmd, "summarize") == 0 || strcmp(cmd, "summary") == 0) {
            char *query = next_token(&cursor);
            char *limit_s = next_token(&cursor);
            char *out = workspace_summary_query_new(ws, query ? query : "", limit_s ? (size_t)strtoull(limit_s, NULL, 10) : 20);
            fputs(out, stdout);
            free(out);
        } else if (strcmp(cmd, "search") == 0) {
            char *query = next_token(&cursor);
            char *limit_s = next_token(&cursor);
            cmd_search(ws, query, limit_s ? (size_t)strtoull(limit_s, NULL, 10) : 0);
        } else if (strcmp(cmd, "read") == 0 || strcmp(cmd, "show") == 0) {
            char *path = next_token(&cursor);
            char *start_s = next_token(&cursor);
            char *max_s = next_token(&cursor);
            if (!path) printf("usage: %s <path> [start_line] [max_lines]\n", cmd);
            else cmd_read(ws, path, start_s ? (size_t)strtoull(start_s, NULL, 10) : 1,
                          max_s ? (size_t)strtoull(max_s, NULL, 10) : 0);
        } else if (strcmp(cmd, "propose") == 0) {
            char *path = next_token(&cursor);
            if (!path) printf("usage: propose <path>\n");
            else cmd_propose(ws, path);
        } else if (strcmp(cmd, "diff") == 0) {
            cmd_diff(ws, next_token(&cursor));
        } else if (strcmp(cmd, "discard") == 0) {
            char *path = next_token(&cursor);
            if (!path) printf("usage: discard <path>|--all\n");
            else if (strcmp(path, "--all") == 0) discard_all(ws);
            else discard_proposal(ws, path);
        } else if (strcmp(cmd, "commit") == 0) {
            cmd_commit(ws);
        } else if (strcmp(cmd, "commit-verified") == 0) {
            (void)cmd_commit_verified(ws);
        } else if (strcmp(cmd, "quit") == 0 || strcmp(cmd, "exit") == 0) {
            break;
        } else {
            printf("unknown command: %s\n", cmd);
        }
    }
    free(line);
}

static void workspace_init(Workspace *ws, const char *root) {
    memset(ws, 0, sizeof(*ws));
    char resolved[PATH_MAX];
    if (!realpath(root, resolved)) die("cannot resolve %s: %s", root, strerror(errno));
    snprintf(ws->root, sizeof(ws->root), "%s", resolved);
    scan_dir(ws, "");
    workspace_rebuild_summaries(ws);
}

static void workspace_init_one_file(Workspace *ws, const char *root, const char *path) {
    memset(ws, 0, sizeof(*ws));
    char resolved[PATH_MAX];
    char abs[PATH_MAX];
    struct stat st;
    size_t len = 0;
    bool text = false;
    unsigned char *data;

    if (!realpath(root, resolved)) die("cannot resolve %s: %s", root, strerror(errno));
    if (!path_is_safe(path)) die("invalid focused file path: %s", path ? path : "(null)");
    snprintf(ws->root, sizeof(ws->root), "%s", resolved);
    join_path(abs, ws->root, path);
    if (lstat(abs, &st) != 0 || !S_ISREG(st.st_mode)) {
        die("focused file missing: %s", path);
    }
    data = read_file_bytes(abs, &len, &text);
    if (data == NULL) die("cannot read focused file: %s", path);
    workspace_add_file(ws, path, data, len, text, st.st_mode);
    workspace_rebuild_summaries(ws);
}

static void workspace_free(Workspace *ws) {
    workspace_clear_files(ws);
    workspace_clear_summaries(ws);
    for (size_t i = 0; i < ws->proposal_count; i++) {
        free(ws->proposals[i].path);
        free(ws->proposals[i].data);
    }
    free(ws->files);
    free(ws->proposals);
    free(ws->summaries);
}

static int self_test(void) {
    if (!path_is_safe("src/main.c")) return SELF_TEST_SAFE_RELATIVE_PATH_FAILURE;
    if (path_is_safe("../x")) return SELF_TEST_PARENT_PATH_FAILURE;
    if (path_is_safe("x/../y")) return SELF_TEST_INTERIOR_PARENT_PATH_FAILURE;
    if (!contains_case_insensitive("Hello EdgeRun", strlen("Hello EdgeRun"), "edge")) {
        return SELF_TEST_CASE_INSENSITIVE_POSITIVE_FAILURE;
    }
    if (contains_case_insensitive("Hello", strlen("Hello"), "world")) {
        return SELF_TEST_CASE_INSENSITIVE_NEGATIVE_FAILURE;
    }
    if (strcmp(scope_for_path("codex/src/edgerun_c.c"), "codex") != 0) return SELF_TEST_SCOPE_FAILURE;
    if (strcmp(test_target_for_scope("codex"), "codex-test") != 0) return SELF_TEST_SCOPE_TEST_TARGET_FAILURE;
    if (strcmp(test_target_for_scope("docs"), "repo-test") != 0) return SELF_TEST_DEFAULT_TEST_TARGET_FAILURE;
    if (!is_c_keyword("static", strlen("static"))) return SELF_TEST_KEYWORD_POSITIVE_FAILURE;
    if (is_c_keyword("status", strlen("status"))) return SELF_TEST_KEYWORD_NEGATIVE_FAILURE;
    if (!path_is_c_like("codex/src/edgerun_c.c")) return SELF_TEST_C_PATH_FAILURE;
    if (path_stem_len("codex/src/edgerun_c.c") != strlen("edgerun_c")) return SELF_TEST_STEM_LENGTH_FAILURE;
    if (stable_hash_bytes((const unsigned char *)"abc", strlen("abc")) ==
        stable_hash_bytes((const unsigned char *)"abd", strlen("abd"))) {
        return SELF_TEST_HASH_DIFFERENCE_FAILURE;
    }
    if (!should_skip_dir(".build/codex")) return SELF_TEST_SKIP_BUILD_DIR_FAILURE;
    int transport_status = er_transport_self_test();
    if (transport_status == 1) return SELF_TEST_TRANSPORT_URL_FAILURE;
    if (transport_status == 2) return SELF_TEST_TRANSPORT_REQUEST_FAILURE;
    if (!codex_sse_headers_self_test()) return SELF_TEST_CODEX_SSE_HEADERS_FAILURE;
    if (er_tls_self_test() != 0) return SELF_TEST_TLS_FAILURE;
    if (codex_game_self_test() != 0) return SELF_TEST_CODEX_GAME_FAILURE;
    puts("self-test ok");
    return 0;
}

int main(int argc, char **argv) {
    if (argc > 1 && strcmp(argv[1], "--self-test") == 0) return self_test();
    if (argc > 1 && strcmp(argv[1], "--game-bench") == 0) return codex_game_bench();
    const char *root = ".";
    const char *prompt = NULL;
    const char *only_file = NULL;
    for (int i = 1; i < argc; i++) {
        if ((strcmp(argv[i], "--prompt") == 0 || strcmp(argv[i], "-p") == 0) && i + 1 < argc) {
            prompt = argv[++i];
        } else if (strcmp(argv[i], "--root") == 0 && i + 1 < argc) {
            root = argv[++i];
        } else if (strcmp(argv[i], "--only-file") == 0 && i + 1 < argc) {
            only_file = argv[++i];
        } else if (strcmp(argv[i], "--memory-only") == 0) {
            g_codex_memory_only = true;
        } else if (strcmp(argv[i], "--quiet-agent") == 0) {
            g_codex_quiet_agent = true;
        } else if (strcmp(argv[i], "--minimal-agent") == 0) {
            g_codex_minimal_agent = true;
        } else if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
            puts("usage: edgerun-c [--memory-only] [--quiet-agent] [--minimal-agent] [--only-file PATH] [--root PATH] [--prompt TEXT] [--game-bench]");
            puts("       edgerun-c PATH");
            return 0;
        } else {
            root = argv[i];
        }
    }
    Workspace ws;
    if (only_file != NULL) {
        workspace_init_one_file(&ws, root, only_file);
    } else {
        workspace_init(&ws, root);
    }
    if (!g_codex_quiet_agent) {
        print_icon_line(stdout, "📦", ANSI_GREEN, "loaded %zu files from %s", ws.file_count, ws.root);
        fflush(stdout);
    }
    int rc = 0;
    if (prompt) rc = run_agent_prompt(&ws, prompt);
    else repl(&ws);
    workspace_free(&ws);
    return rc;
}
