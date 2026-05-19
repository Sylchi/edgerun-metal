#define run_agent_prompt original_run_agent_prompt
#define main edgerun_c_original_main
#include "edgerun_c.c"
#undef main
#undef run_agent_prompt

#define CODEX_CONTEXT_TREE_PATH_LIMIT 200u
#define CODEX_CONTEXT_PROCESS_LINE_LIMIT 40u
#define CODEX_FENCE_MARKER_LEN 3u
#define CODEX_MARKDOWN_HEADING_MAX_DEPTH 6u

typedef enum {
    CODEX_RESPONSE_LANG_TEXT = 0,
    CODEX_RESPONSE_LANG_C,
    CODEX_RESPONSE_LANG_MARKDOWN,
    CODEX_RESPONSE_LANG_OTHER
} CodexResponseLanguage;

typedef struct {
    Buffer line;
    bool in_fence;
    CodexResponseLanguage fence_language;
} CodexResponseRenderState;

static int context_path_compare(const void *a, const void *b) {
    const char *const *pa = (const char *const *)a;
    const char *const *pb = (const char *const *)b;
    return strcmp(*pa, *pb);
}

static char *context_tree_entry_new(const char *path) {
    const char *first = strchr(path, '/');
    if (!first) return xstrdup(path);
    const char *second = strchr(first + 1, '/');
    if (!second) return xstrdup(path);

    Buffer b;
    buffer_init(&b);
    buffer_append(&b, path, (size_t)(second - path));
    buffer_append(&b, "/...", 4);
    return b.data;
}

static bool context_tree_has_entry(char **entries, size_t count, const char *entry) {
    for (size_t i = 0; i < count; i++) {
        if (strcmp(entries[i], entry) == 0) return true;
    }
    return false;
}

static char *repo_tree_text_new(Workspace *ws) {
    char **entries = xmalloc(ws->file_count * sizeof(entries[0]));
    size_t entry_count = 0;
    for (size_t i = 0; i < ws->file_count; i++) {
        char *entry = context_tree_entry_new(ws->files[i].path);
        if (context_tree_has_entry(entries, entry_count, entry)) {
            free(entry);
        } else {
            entries[entry_count++] = entry;
        }
    }
    qsort(entries, entry_count, sizeof(entries[0]), context_path_compare);

    Buffer b;
    buffer_init(&b);
    buffer_append(&b, "\nRepository tree snapshot (top-level paths and collapsed two-level prefixes):\n", 72);
    size_t emitted = 0;
    for (size_t i = 0; i < entry_count && emitted < CODEX_CONTEXT_TREE_PATH_LIMIT; i++) {
        buffer_appendf(&b, "- %s\n", entries[i]);
        emitted++;
    }
    if (entry_count > emitted) {
        buffer_appendf(&b, "- ... %zu more entries available through search_code/read_code\n", entry_count - emitted);
    }
    for (size_t i = 0; i < entry_count; i++) free(entries[i]);
    free(entries);
    return b.data ? b.data : xstrdup("");
}

static char *process_context_text_new(Workspace *ws) {
    char command[128];
    snprintf(command, sizeof(command), "ps -axo pid,ppid,stat,comm,args | head -n %u", CODEX_CONTEXT_PROCESS_LINE_LIMIT);
    char *cmd = repo_command_new(ws, command);
    int status = 0;
    char *out = run_command_text_new(cmd, &status);
    Buffer b;
    buffer_init(&b);
    buffer_appendf(&b, "\nRunning processes snapshot exit=%d:\n%s", status, out);
    free(cmd);
    free(out);
    return b.data ? b.data : xstrdup("");
}

static char *enhanced_initial_context_text_new(Workspace *ws) {
    Buffer b;
    buffer_init(&b);
    const char *intro =
        "Host-provided repository context. Use this instead of asking for routine git/build checks.\n"
        "AGENTS.md, repo-progress plans, repository tree context, and running processes are provided on the first turn.\n\n";
    buffer_append(&b, intro, strlen(intro));

    char *status = repo_status_text_new(ws);
    buffer_append(&b, status, strlen(status));
    free(status);

    buffer_appendf(&b, "\nworkspace files loaded: %zu\npending in-memory proposals: %zu\n", ws->file_count, ws->proposal_count);

    char *rules = repo_rules_text_new(ws);
    buffer_append(&b, "\n", 1);
    buffer_append(&b, rules, strlen(rules));
    free(rules);

    char *tree = repo_tree_text_new(ws);
    buffer_append(&b, tree, strlen(tree));
    free(tree);

    char *processes = process_context_text_new(ws);
    buffer_append(&b, processes, strlen(processes));
    free(processes);

    const char *policy =
        "\nVerification policy: after proposals, the host writes only proposed paths, runs scoped repo-progress, "
        "and commits only if verification passes.\n";
    buffer_append(&b, policy, strlen(policy));
    return b.data;
}

static void codex_response_render_state_init(CodexResponseRenderState *state) {
    buffer_init(&state->line);
    state->in_fence = false;
    state->fence_language = CODEX_RESPONSE_LANG_TEXT;
}

static void codex_response_render_state_free(CodexResponseRenderState *state) {
    free(state->line.data);
    state->line.data = NULL;
    state->line.len = 0;
    state->line.cap = 0;
}

static size_t codex_skip_spaces(const char *line, size_t len, size_t i) {
    while (i < len && (line[i] == ' ' || line[i] == '\t')) i++;
    return i;
}

static bool codex_language_token_matches(const char *token, size_t token_len, const char *name) {
    size_t name_len = strlen(name);
    if (token_len != name_len) return false;
    for (size_t i = 0; i < token_len; i++) {
        if (lower_char(token[i]) != lower_char(name[i])) return false;
    }
    return true;
}

static CodexResponseLanguage codex_response_language_for_token(const char *token, size_t token_len) {
    if (token_len == 0) return CODEX_RESPONSE_LANG_OTHER;
    if (codex_language_token_matches(token, token_len, "c") ||
        codex_language_token_matches(token, token_len, "h")) {
        return CODEX_RESPONSE_LANG_C;
    }
    if (codex_language_token_matches(token, token_len, "md") ||
        codex_language_token_matches(token, token_len, "markdown")) {
        return CODEX_RESPONSE_LANG_MARKDOWN;
    }
    return CODEX_RESPONSE_LANG_OTHER;
}

static bool codex_markdown_fence_line(const char *line, size_t len, CodexResponseLanguage *out_language) {
    size_t i = codex_skip_spaces(line, len, 0);
    if (i + CODEX_FENCE_MARKER_LEN > len) return false;
    if (memcmp(line + i, "```", CODEX_FENCE_MARKER_LEN) != 0) return false;
    i += CODEX_FENCE_MARKER_LEN;
    i = codex_skip_spaces(line, len, i);
    size_t token_start = i;
    while (i < len && line[i] != ' ' && line[i] != '\t' && line[i] != '`' && line[i] != '{') i++;
    *out_language = codex_response_language_for_token(line + token_start, i - token_start);
    return true;
}

static size_t codex_markdown_heading_depth(const char *line, size_t len) {
    size_t depth = 0;
    while (depth < len && line[depth] == '#') depth++;
    if (depth == 0 || depth > CODEX_MARKDOWN_HEADING_MAX_DEPTH) return 0;
    if (depth < len && line[depth] != ' ' && line[depth] != '\t') return 0;
    return depth;
}

static bool codex_markdown_list_marker(const char *line, size_t len, size_t *marker_len) {
    size_t i = codex_skip_spaces(line, len, 0);
    if (i + 1u >= len) return false;
    switch (line[i]) {
        case '-':
        case '*':
            if (line[i + 1u] == ' ' || line[i + 1u] == '\t') {
                *marker_len = i + 1u;
                return true;
            }
            return false;
        default:
            break;
    }
    if (!isdigit((unsigned char)line[i])) return false;
    while (i < len && isdigit((unsigned char)line[i])) i++;
    if (i + 1u < len && line[i] == '.' && (line[i + 1u] == ' ' || line[i + 1u] == '\t')) {
        *marker_len = i + 1u;
        return true;
    }
    return false;
}

static void print_highlighted_markdown_inline(const char *line, size_t len) {
    for (size_t i = 0; i < len;) {
        switch (line[i]) {
            case '`': {
                size_t start = i++;
                while (i < len && line[i] != '`') i++;
                if (i < len) i++;
                printf("%s%.*s%s", color_code(stdout, ANSI_GREEN), (int)(i - start), line + start, color_code(stdout, ANSI_RESET));
                break;
            }
            case '*': {
                if (i + 1u < len && line[i + 1u] == '*') {
                    size_t start = i;
                    i += 2u;
                    while (i + 1u < len && !(line[i] == '*' && line[i + 1u] == '*')) i++;
                    if (i + 1u < len) i += 2u;
                    printf("%s%.*s%s", color_code(stdout, ANSI_MAGENTA), (int)(i - start), line + start, color_code(stdout, ANSI_RESET));
                } else {
                    putchar(line[i++]);
                }
                break;
            }
            case '[': {
                size_t start = i++;
                while (i < len && line[i] != ']') i++;
                if (i < len && i + 1u < len && line[i + 1u] == '(') {
                    i += 2u;
                    while (i < len && line[i] != ')') i++;
                    if (i < len) i++;
                    printf("%s%.*s%s", color_code(stdout, ANSI_CYAN), (int)(i - start), line + start, color_code(stdout, ANSI_RESET));
                } else {
                    printf("%.*s", (int)(i - start), line + start);
                }
                break;
            }
            default:
                putchar(line[i++]);
                break;
        }
    }
}

static void print_highlighted_markdown_line(const char *line, size_t len) {
    size_t heading_depth = codex_markdown_heading_depth(line, len);
    if (heading_depth != 0) {
        printf("%s%s%.*s%s", color_code(stdout, ANSI_BOLD), color_code(stdout, ANSI_CYAN), (int)len, line, color_code(stdout, ANSI_RESET));
        return;
    }
    size_t marker_len = 0;
    if (codex_markdown_list_marker(line, len, &marker_len)) {
        printf("%s%.*s%s", color_code(stdout, ANSI_YELLOW), (int)marker_len, line, color_code(stdout, ANSI_RESET));
        print_highlighted_markdown_inline(line + marker_len, len - marker_len);
        return;
    }
    if (len > 0 && line[0] == '>') {
        printf("%s%.*s%s", color_code(stdout, ANSI_GRAY), (int)len, line, color_code(stdout, ANSI_RESET));
        return;
    }
    print_highlighted_markdown_inline(line, len);
}

static void codex_render_plain_code_line(const char *line, size_t len) {
    printf("%s%.*s%s", color_code(stdout, ANSI_DIM), (int)len, line, color_code(stdout, ANSI_RESET));
}

static void codex_render_response_line(CodexResponseRenderState *state, const char *line, size_t len) {
    CodexResponseLanguage fence_language = CODEX_RESPONSE_LANG_TEXT;
    if (codex_markdown_fence_line(line, len, &fence_language)) {
        printf("%s%.*s%s", color_code(stdout, ANSI_GRAY), (int)len, line, color_code(stdout, ANSI_RESET));
        if (state->in_fence) {
            state->in_fence = false;
            state->fence_language = CODEX_RESPONSE_LANG_TEXT;
        } else {
            state->in_fence = true;
            state->fence_language = fence_language;
        }
        return;
    }

    if (!state->in_fence) {
        print_highlighted_markdown_line(line, len);
        return;
    }

    switch (state->fence_language) {
        case CODEX_RESPONSE_LANG_C:
            print_highlighted_c_line(line, len);
            break;
        case CODEX_RESPONSE_LANG_MARKDOWN:
            print_highlighted_markdown_line(line, len);
            break;
        case CODEX_RESPONSE_LANG_TEXT:
        case CODEX_RESPONSE_LANG_OTHER:
            codex_render_plain_code_line(line, len);
            break;
    }
}

static void codex_render_response_delta(CodexResponseRenderState *state, const char *delta) {
    for (const char *p = delta; *p; p++) {
        if (*p == '\n') {
            if (state->line.data) codex_render_response_line(state, state->line.data, state->line.len);
            putchar('\n');
            state->line.len = 0;
            if (state->line.data) state->line.data[0] = 0;
        } else {
            buffer_append_c(&state->line, *p);
        }
    }
    fflush(stdout);
}

static void codex_render_response_flush(CodexResponseRenderState *state) {
    if (state->line.len == 0) return;
    codex_render_response_line(state, state->line.data, state->line.len);
    state->line.len = 0;
    if (state->line.data) state->line.data[0] = 0;
    fflush(stdout);
}

static void highlighted_process_sse_json_event(AgentTurn *turn, CodexResponseRenderState *render, const char *event_json) {
    char *type = json_get_string_dup(event_json, "type");
    if (!type) return;
    if (strcmp(type, "response.output_text.delta") == 0) {
        char *delta = json_get_string_dup(event_json, "delta");
        if (delta) {
            codex_render_response_delta(render, delta);
            agent_turn_append_text(turn, delta);
            free(delta);
        }
    } else if (strcmp(type, "response.output_item.done") == 0) {
        char *item = json_dup_balanced_value(json_find_key_value_start(event_json, "item"));
        if (item) {
            process_output_item_json(turn, item);
            free(item);
        }
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

static AgentTurn highlighted_codex_stream_turn(const char *model, const CodexAuth *auth, const CodexSession *session, JsonItems *history) {
    AgentTurn turn;
    agent_turn_init(&turn);
    CodexResponseRenderState render;
    codex_response_render_state_init(&render);
    char *body = build_responses_body_new(model, session, history);
    debug_write_body(body);
    char *body_path = write_temp_body_new(body);
    free(body);

    char *body_q = shell_quote_new(body_path);
    char *url_q = shell_quote_new(CODEX_BACKEND_URL);
    Buffer auth_header;
    buffer_init(&auth_header);
    buffer_appendf(&auth_header, "authorization: Bearer %s", auth->access_token);
    char *auth_header_q = shell_quote_new(auth_header.data);
    Buffer request_id_header;
    buffer_init(&request_id_header);
    buffer_appendf(&request_id_header, "x-client-request-id: %s", session->thread_id);
    char *request_id_header_q = shell_quote_new(request_id_header.data);
    Buffer session_id_header;
    buffer_init(&session_id_header);
    buffer_appendf(&session_id_header, "session_id: %s", session->session_id);
    char *session_id_header_q = shell_quote_new(session_id_header.data);
    Buffer thread_id_header;
    buffer_init(&thread_id_header);
    buffer_appendf(&thread_id_header, "thread_id: %s", session->thread_id);
    char *thread_id_header_q = shell_quote_new(thread_id_header.data);
    Buffer installation_header;
    buffer_init(&installation_header);
    buffer_appendf(&installation_header, "x-codex-installation-id: %s", session->installation_id);
    char *installation_header_q = shell_quote_new(installation_header.data);
    Buffer window_header;
    buffer_init(&window_header);
    buffer_appendf(&window_header, "x-codex-window-id: %s", session->window_id);
    char *window_header_q = shell_quote_new(window_header.data);
    char *account_header_q = NULL;
    if (auth->account_id) {
        Buffer account_header;
        buffer_init(&account_header);
        buffer_appendf(&account_header, "ChatGPT-Account-ID: %s", auth->account_id);
        account_header_q = shell_quote_new(account_header.data);
        free(account_header.data);
    }

    Buffer cmd;
    buffer_init(&cmd);
    buffer_appendf(&cmd,
        "curl -sS -N --fail-with-body -X POST %s "
        "-H 'accept: text/event-stream' "
        "-H 'content-type: application/json' "
        "-H 'version: " CODEX_BACKEND_VERSION "' "
        "-H %s -H %s -H %s -H %s -H %s -H %s ",
        url_q, auth_header_q, request_id_header_q, session_id_header_q,
        thread_id_header_q, installation_header_q, window_header_q);
    if (account_header_q) {
        buffer_appendf(&cmd, "-H %s ", account_header_q);
    }
    buffer_appendf(&cmd, "--data-binary @%s", body_q);

    FILE *pipe = popen(cmd.data, "r");
    if (!pipe) die("failed to start curl; install curl or provide a local HTTPS transport");

    char *line = NULL;
    size_t cap = 0;
    Buffer event;
    buffer_init(&event);
    while (getline(&line, &cap, pipe) != -1) {
        trim_newline(line);
        if (line[0] == 0) {
            if (event.len > 0) {
                highlighted_process_sse_json_event(&turn, &render, event.data);
                bool done = response_completed(event.data);
                event.len = 0;
                if (event.data) event.data[0] = 0;
                if (done) break;
            }
        } else if (starts_with(line, "data: ")) {
            if (event.len) buffer_append_c(&event, '\n');
            buffer_append(&event, line + 6, strlen(line + 6));
        } else if (getenv("EDGERUN_C_DEBUG")) {
            fprintf(stderr, "[debug] non-sse: %s\n", line);
        }
    }
    codex_render_response_flush(&render);
    codex_response_render_state_free(&render);
    free(line);
    int rc = pclose(pipe);
    if (rc != 0) fprintf(stderr, "\ncurl exited with status %d\n", rc);
    unlink(body_path);
    free(body_path);
    free(body_q);
    free(url_q);
    free(auth_header.data);
    free(auth_header_q);
    free(request_id_header.data);
    free(request_id_header_q);
    free(session_id_header.data);
    free(session_id_header_q);
    free(thread_id_header.data);
    free(thread_id_header_q);
    free(installation_header.data);
    free(installation_header_q);
    free(window_header.data);
    free(window_header_q);
    free(account_header_q);
    free(cmd.data);
    free(event.data);
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
    char *context = enhanced_initial_context_text_new(ws);
    json_items_push(&history, user_item_json_new(context));
    free(context);
    char *current_prompt = xstrdup(prompt);
    Buffer exchange;
    buffer_init(&exchange);
    json_items_push(&history, user_item_json_new(current_prompt));

    for (;;) {
        AgentTurn turn = highlighted_codex_stream_turn(model, &auth, &session, &history);
        summary.turns++;
        if (turn.text && *turn.text) {
            buffer_append(&exchange, "\nassistant:\n", 12);
            buffer_append_excerpt(&exchange, turn.text, SESSION_EXCERPT_BYTES * 2u);
        }
        for (size_t i = 0; i < turn.output_items.count; i++) {
            json_items_push(&history, xstrdup(turn.output_items.items[i]));
        }
        if (turn.tool_count == 0) {
            putchar('\n');
            agent_turn_free(&turn);
            summary.proposals_before_commit = ws->proposal_count;
            if (ws->proposal_count == 0) {
                summary.review_only_turns++;
                summary.commit_status = 0;
                print_agent_summary(&summary);
                char *continue_message = host_continue_message_new(ws, false);
                json_items_push(&history, user_item_json_new(continue_message));
                free(continue_message);
                continue;
            }
            summary.commit_status = cmd_commit_verified(ws);
            print_agent_summary(&summary);
            if (summary.commit_status != 0) {
                json_items_free(&history);
                free(auth.access_token);
                free(auth.account_id);
                free(current_prompt);
                free(exchange.data);
                return summary.commit_status;
            }
            summary.checkpoints++;
            char *memory = session_memory_message_new(
                ws,
                &summary,
                current_prompt,
                exchange.data ? exchange.data : "");
            print_icon_line(stdout, "🧠", ANSI_CYAN, "session context compacted; enter the next prompt or 'quit'");
            char *next_prompt = read_session_prompt_new();
            if (!next_prompt) {
                free(memory);
                json_items_free(&history);
                free(auth.access_token);
                free(auth.account_id);
                free(current_prompt);
                free(exchange.data);
                return 0;
            }
            json_items_free(&history);
            memset(&history, 0, sizeof(history));
            context = enhanced_initial_context_text_new(ws);
            json_items_push(&history, user_item_json_new(context));
            free(context);
            json_items_push(&history, user_item_json_new(memory));
            free(memory);
            free(current_prompt);
            current_prompt = next_prompt;
            json_items_push(&history, user_item_json_new(current_prompt));
            exchange.len = 0;
            if (exchange.data) exchange.data[0] = 0;
            continue;
        }
        for (size_t i = 0; i < turn.tool_count; i++) {
            bool ok = false;
            summary.tool_calls++;
            fprintf(stderr, "\n%s🔧 tool%s %s\n",
                    color_code(stderr, ANSI_BLUE), color_code(stderr, ANSI_RESET), turn.tools[i].name);
            char *tool_out = execute_agent_tool_new(ws, &turn.tools[i], &ok);
            buffer_appendf(&exchange, "\ntool %s (%s):\n", turn.tools[i].name, ok ? "ok" : "failed");
            buffer_append_excerpt(&exchange, tool_out, SESSION_EXCERPT_BYTES);
            fprintf(stderr, "%s%s tool result%s %.160s%s\n",
                    color_code(stderr, ok ? ANSI_GREEN : ANSI_RED),
                    ok ? "✅" : "❌",
                    color_code(stderr, ANSI_RESET),
                    tool_out,
                    strlen(tool_out) > 160 ? "..." : "");
            json_items_push(&history, tool_output_item_json_new(turn.tools[i].call_id, tool_out, ok));
            free(tool_out);
        }
        agent_turn_free(&turn);
    }
}

static int enhanced_self_test(void) {
    int base = self_test();
    if (base != 0) return base;
    CodexResponseLanguage language = CODEX_RESPONSE_LANG_TEXT;
    if (!codex_markdown_fence_line("```c", 4, &language)) return 20;
    if (language != CODEX_RESPONSE_LANG_C) return 21;
    if (!codex_markdown_fence_line("```md", 5, &language)) return 22;
    if (language != CODEX_RESPONSE_LANG_MARKDOWN) return 23;
    if (!codex_markdown_fence_line("```", 3, &language)) return 24;
    if (language != CODEX_RESPONSE_LANG_OTHER) return 25;
    if (codex_markdown_fence_line("  text", 6, &language)) return 26;
    puts("enhanced self-test ok");
    return 0;
}

int main(int argc, char **argv) {
    if (argc > 1 && strcmp(argv[1], "--self-test") == 0) return enhanced_self_test();
    const char *root = ".";
    const char *prompt = NULL;
    for (int i = 1; i < argc; i++) {
        if ((strcmp(argv[i], "--prompt") == 0 || strcmp(argv[i], "-p") == 0) && i + 1 < argc) {
            prompt = argv[++i];
        } else if (strcmp(argv[i], "--root") == 0 && i + 1 < argc) {
            root = argv[++i];
        } else if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
            puts("usage: edgerun-c [--root PATH] [--prompt TEXT]");
            puts("       edgerun-c PATH");
            return 0;
        } else {
            root = argv[i];
        }
    }
    Workspace ws;
    workspace_init(&ws, root);
    print_icon_line(stdout, "📦", ANSI_GREEN, "loaded %zu files from %s", ws.file_count, ws.root);
    fflush(stdout);
    int rc = 0;
    if (prompt) rc = run_agent_prompt(&ws, prompt);
    else repl(&ws);
    workspace_free(&ws);
    return rc;
}
