#define run_agent_prompt original_run_agent_prompt
#define main edgerun_c_original_main
#include "edgerun_c.c"
#undef main
#undef run_agent_prompt

#define CODEX_CONTEXT_TREE_PATH_LIMIT 200u
#define CODEX_CONTEXT_PROCESS_LINE_LIMIT 40u

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

static int run_agent_prompt(Workspace *ws, const char *prompt) {
    const char *model = getenv("CODEX_TUI_MODEL");
    if (!model || !*model) model = DEFAULT_MODEL;
    AgentRunSummary summary = {
        .model = model,
        .turns = 0,
        .tool_calls = 0,
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
    json_items_push(&history, user_item_json_new(prompt));

    for (;;) {
        AgentTurn turn = codex_stream_turn(model, &auth, &session, &history);
        summary.turns++;
        for (size_t i = 0; i < turn.output_items.count; i++) {
            json_items_push(&history, xstrdup(turn.output_items.items[i]));
        }
        if (turn.tool_count == 0) {
            putchar('\n');
            agent_turn_free(&turn);
            summary.proposals_before_commit = ws->proposal_count;
            summary.commit_status = cmd_commit_verified(ws);
            print_agent_summary(&summary);
            json_items_free(&history);
            free(auth.access_token);
            free(auth.account_id);
            return summary.commit_status;
        }
        for (size_t i = 0; i < turn.tool_count; i++) {
            bool ok = false;
            summary.tool_calls++;
            fprintf(stderr, "\n%s🔧 tool%s %s\n",
                    color_code(stderr, ANSI_BLUE), color_code(stderr, ANSI_RESET), turn.tools[i].name);
            char *tool_out = execute_agent_tool_new(ws, &turn.tools[i], &ok);
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

int main(int argc, char **argv) {
    if (argc > 1 && strcmp(argv[1], "--self-test") == 0) return self_test();
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
