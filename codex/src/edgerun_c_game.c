#define CODEX_GAME_BENCH_TASKS 100u
#define CODEX_GAME_STRATEGY_COUNT 5u
#define CODEX_GAME_SCORE_FEATURE 1
#define CODEX_GAME_SCORE_CLEANUP 8
#define CODEX_GAME_SCORE_SMELL_OR_WORLDVIEW 5
#define CODEX_GAME_SCORE_CPU 4
#define CODEX_GAME_SCORE_TEST 5
#define CODEX_GAME_SCORE_DELETE 2
#define CODEX_GAME_SCORE_STEP -1
#define CODEX_GAME_SCORE_SUBAGENT 0
#define CODEX_GAME_SCORE_IRRELEVANT -10
#define CODEX_GAME_SCORE_DEBT -6
#define CODEX_GAME_SCORE_GATE_FLOOR 0
#define CODEX_GAME_TASK_SEED UINT64_C(0x4d595df4d0f33173)
#define CODEX_GAME_TASK_MULTIPLIER UINT64_C(6364136223846793005)
#define CODEX_GAME_TASK_INCREMENT UINT64_C(1442695040888963407)
#define CODEX_GAME_FEATURE_MIN 1
#define CODEX_GAME_FEATURE_SPAN 5
#define CODEX_GAME_CLEANUP_SPAN 4
#define CODEX_GAME_TEST_SPAN 3
#define CODEX_GAME_DELETE_SPAN 4
#define CODEX_GAME_DEBT_SPAN 3
#define CODEX_GAME_IRRELEVANT_PERIOD 11u
#define CODEX_GAME_DELEGATE_MIN_WORK 3
#define CODEX_GAME_DELEGATE_MAX_AGENTS 3
#define CODEX_GAME_BASE_STEP_COUNT 1
#define CODEX_GAME_PARSE_BASE 10
#define CODEX_GAME_SELF_TEST_POSITIVE_SCORE 15
#define CODEX_GAME_SELF_TEST_NEGATIVE_SCORE -16
#define CODEX_GAME_SELF_TEST_PARSE_BEFORE_FAILURE 1
#define CODEX_GAME_SELF_TEST_PARSE_AFTER_FAILURE 2
#define CODEX_GAME_SELF_TEST_DUPLICATE_FAILURE 3
#define CODEX_GAME_SELF_TEST_CPU_FAILURE 4
#define CODEX_GAME_SELF_TEST_LOC_FAILURE 5
#define CODEX_GAME_SELF_TEST_DEBT_FAILURE 6
#define CODEX_GAME_SELF_TEST_SCORE_FAILURE 7
#define CODEX_GAME_SELF_TEST_EXPECTED_SCORE 10

typedef enum {
    CODEX_GAME_STRATEGY_FEATURE_FIRST = 0,
    CODEX_GAME_STRATEGY_SCORE_ONLY,
    CODEX_GAME_STRATEGY_CLEANUP_FIRST,
    CODEX_GAME_STRATEGY_GATE_AND_SCORE,
    CODEX_GAME_STRATEGY_DELEGATED_GATE
} CodexGameStrategyKind;

typedef struct {
    int feature_units;
    int cleanup_units;
    int test_units;
    int deleted_units;
    int debt_units;
    int irrelevant_units;
    int step_units;
    int subagent_units;
} CodexGameUnits;

typedef CodexGameUnits CodexGameTask;
typedef CodexGameUnits CodexGameMove;

typedef struct {
    int total_score;
    CodexGameUnits units;
    int rejected_moves;
    int wins;
} CodexGameResult;

typedef struct {
    unsigned long long code_loc;
    unsigned long long duplicates;
    unsigned long long worldview;
    unsigned long long cpu;
    unsigned long long smells;
} CodexGameInspectTotals;

typedef struct {
    int score;
    unsigned long long duplicates_removed;
    unsigned long long worldview_removed;
    unsigned long long cpu_removed;
    unsigned long long smells_removed;
    unsigned long long loc_removed;
    unsigned long long debt_added;
    int feature_progress;
} CodexGameQualityScore;

static char *quality_game_text_new(void) {
    static const char text[] =
        "\nQuality game score shown to every agent turn:\n"
        "+8 production duplicate removed\n"
        "+5 repo-inspect smell/worldview finding removed\n"
        "+5 deterministic test coverage added for changed behavior\n"
        "+4 CPU-cost or dead-code finding removed\n"
        "+2 net production LOC removed while tests still pass\n"
        "+1 requested feature behavior delivered with no inspect regression\n"
        "-6 new inspect debt in touched scope\n"
        "-10 unrelated touched file or irrelevant behavior\n"
        "-1 host step used; fewer steps win ties\n"
        "+0 delegated sub-agent used; only host steps are penalized\n"
        "Winning condition: maximize score delta while passing repo-progress. "
        "Feature code that merely works scores lowest unless it also reduces debt. "
        "The host should reject negative-score proposal batches unless the user "
        "explicitly accepts feature debt. Agents may delegate independent, "
        "bounded side work when that clears the objective in fewer host steps.\n";
    Buffer b;

    buffer_init(&b);
    buffer_append(&b, text, strlen(text));
    return b.data ? b.data : xstrdup("");
}

static int codex_game_parse_unsigned_after(const char *text,
                                           const char *marker,
                                           unsigned long long *out) {
    const char *p = strstr(text, marker);

    if (!p) return 0;
    p += strlen(marker);
    while (*p && !isdigit((unsigned char)*p)) p++;
    if (!*p) return 0;
    *out = strtoull(p, NULL, CODEX_GAME_PARSE_BASE);
    return 1;
}

static int codex_game_inspect_totals_parse(const char *text,
                                           CodexGameInspectTotals *out) {
    memset(out, 0, sizeof(*out));
    return codex_game_parse_unsigned_after(text, "code:", &out->code_loc) &&
           codex_game_parse_unsigned_after(text, "duplication:",
                                           &out->duplicates) &&
           codex_game_parse_unsigned_after(text, "worldview:",
                                           &out->worldview) &&
           codex_game_parse_unsigned_after(text, "CPU cost:", &out->cpu) &&
           codex_game_parse_unsigned_after(text, "smells:", &out->smells);
}

static unsigned long long codex_game_positive_delta(unsigned long long before,
                                                    unsigned long long after) {
    return before > after ? before - after : 0u;
}

static unsigned long long codex_game_negative_delta(unsigned long long before,
                                                    unsigned long long after) {
    return after > before ? after - before : 0u;
}

static void codex_game_quality_score_add(CodexGameQualityScore *score,
                                         CodexGameInspectTotals before,
                                         CodexGameInspectTotals after) {
    unsigned long long duplicate_debt =
        codex_game_negative_delta(before.duplicates, after.duplicates);
    unsigned long long worldview_debt =
        codex_game_negative_delta(before.worldview, after.worldview);
    unsigned long long cpu_debt =
        codex_game_negative_delta(before.cpu, after.cpu);
    unsigned long long smell_debt =
        codex_game_negative_delta(before.smells, after.smells);

    score->duplicates_removed +=
        codex_game_positive_delta(before.duplicates, after.duplicates);
    score->worldview_removed +=
        codex_game_positive_delta(before.worldview, after.worldview);
    score->cpu_removed += codex_game_positive_delta(before.cpu, after.cpu);
    score->smells_removed +=
        codex_game_positive_delta(before.smells, after.smells);
    score->loc_removed += codex_game_positive_delta(before.code_loc,
                                                    after.code_loc);
    score->debt_added += duplicate_debt + worldview_debt + cpu_debt +
                         smell_debt;
}

static CodexGameQualityScore codex_game_quality_score(
    const CodexGameInspectTotals *before,
    const CodexGameInspectTotals *after,
    size_t count) {
    CodexGameQualityScore score = {0};

    for (size_t i = 0u; i < count; ++i) {
        codex_game_quality_score_add(&score, before[i], after[i]);
    }
    score.feature_progress = score.debt_added == 0u ? 1 : 0;
    score.score =
        (int)(score.duplicates_removed * CODEX_GAME_SCORE_CLEANUP) +
        (int)(score.worldview_removed * CODEX_GAME_SCORE_SMELL_OR_WORLDVIEW) +
        (int)(score.cpu_removed * CODEX_GAME_SCORE_CPU) +
        (int)(score.smells_removed * CODEX_GAME_SCORE_SMELL_OR_WORLDVIEW) +
        (int)(score.loc_removed * CODEX_GAME_SCORE_DELETE) +
        (score.feature_progress * CODEX_GAME_SCORE_FEATURE) +
        (int)(score.debt_added * CODEX_GAME_SCORE_DEBT);
    return score;
}

static int codex_game_build_repo_inspect(Workspace *ws) {
    char *cmd = repo_command_new(ws, "make repo-inspect");
    int status = run_command_checked(cmd);

    free(cmd);
    return status;
}

static int codex_game_inspect_scope(Workspace *ws,
                                    const char *scope,
                                    CodexGameInspectTotals *out) {
    char *scope_q = shell_quote_new(scope);
    Buffer command;
    buffer_init(&command);
    buffer_appendf(&command, "./.build/repo-inspect %s", scope_q);
    char *cmd = repo_command_new(ws, command.data);
    int status = 0;
    char *text = run_command_text_new(cmd, &status);

    if (status == 0 && !codex_game_inspect_totals_parse(text, out)) {
        status = 1;
    }
    if (status != 0) {
        fprintf(stderr, "quality game: repo-inspect failed for %s\n", scope);
    }
    free(scope_q);
    free(command.data);
    free(cmd);
    free(text);
    return status;
}

static int codex_game_inspect_scopes(Workspace *ws,
                                     const char **scopes,
                                     size_t scope_count,
                                     CodexGameInspectTotals *out) {
    if (codex_game_build_repo_inspect(ws) != 0) return 1;
    for (size_t i = 0u; i < scope_count; ++i) {
        if (codex_game_inspect_scope(ws, scopes[i], &out[i]) != 0) return 1;
    }
    return 0;
}

static void codex_game_quality_score_print(CodexGameQualityScore score) {
    printf("quality game: score=%d feature=%d duplicate-removal=%llu "
           "worldview-removal=%llu cpu-removal=%llu smell-removal=%llu "
           "loc-removal=%llu new-debt=%llu\n",
           score.score,
           score.feature_progress,
           score.duplicates_removed,
           score.worldview_removed,
           score.cpu_removed,
           score.smells_removed,
           score.loc_removed,
           score.debt_added);
}

static uint64_t codex_game_next(uint64_t *state) {
    *state = (*state * CODEX_GAME_TASK_MULTIPLIER) + CODEX_GAME_TASK_INCREMENT;
    return *state;
}

static int codex_game_range(uint64_t *state, int span) {
    return (int)(codex_game_next(state) % (uint64_t)span);
}

static CodexGameTask codex_game_task_new(uint64_t *state, size_t index) {
    CodexGameTask task = {
        .feature_units = CODEX_GAME_FEATURE_MIN +
                         codex_game_range(state, CODEX_GAME_FEATURE_SPAN),
        .cleanup_units = codex_game_range(state, CODEX_GAME_CLEANUP_SPAN),
        .test_units = codex_game_range(state, CODEX_GAME_TEST_SPAN),
        .deleted_units = codex_game_range(state, CODEX_GAME_DELETE_SPAN),
        .debt_units = codex_game_range(state, CODEX_GAME_DEBT_SPAN),
        .irrelevant_units =
            ((index + 1u) % CODEX_GAME_IRRELEVANT_PERIOD) == 0u ? 1 : 0,
    };
    return task;
}

static int codex_game_score_move(CodexGameMove move) {
    return (move.feature_units * CODEX_GAME_SCORE_FEATURE) +
           (move.cleanup_units * CODEX_GAME_SCORE_CLEANUP) +
           (move.test_units * CODEX_GAME_SCORE_TEST) +
           (move.deleted_units * CODEX_GAME_SCORE_DELETE) +
           (move.step_units * CODEX_GAME_SCORE_STEP) +
           (move.subagent_units * CODEX_GAME_SCORE_SUBAGENT) +
           (move.irrelevant_units * CODEX_GAME_SCORE_IRRELEVANT) +
           (move.debt_units * CODEX_GAME_SCORE_DEBT);
}

static int codex_game_positive_unit(int value) {
    return value > 0 ? 1 : 0;
}

static int codex_game_move_work_units(CodexGameMove move) {
    return move.feature_units + move.cleanup_units + move.test_units +
           move.deleted_units;
}

static int codex_game_serial_steps(CodexGameMove move) {
    int work = codex_game_move_work_units(move);

    return work > 0 ? work : CODEX_GAME_BASE_STEP_COUNT;
}

static int codex_game_delegated_steps(int work, int agents) {
    int workers = agents + CODEX_GAME_BASE_STEP_COUNT;
    int steps = work / workers;

    if ((work % workers) != 0) steps++;
    return CODEX_GAME_BASE_STEP_COUNT + steps;
}

static int codex_game_delegated_cost(int work, int agents) {
    return codex_game_delegated_steps(work, agents);
}

static int codex_game_best_delegated_agent_count(int work) {
    int best_agents = 0;
    int best_cost = work;

    for (int agents = CODEX_GAME_BASE_STEP_COUNT;
         agents <= CODEX_GAME_DELEGATE_MAX_AGENTS;
         ++agents) {
        int cost = codex_game_delegated_cost(work, agents);
        if (cost < best_cost) {
            best_agents = agents;
            best_cost = cost;
        }
    }
    return best_agents;
}

static void codex_game_finish_move(CodexGameMove *move) {
    move->step_units = codex_game_serial_steps(*move);
}

static void codex_game_finish_delegated_move(CodexGameMove *move) {
    int work = codex_game_move_work_units(*move);

    if (work >= CODEX_GAME_DELEGATE_MIN_WORK) {
        move->subagent_units = codex_game_best_delegated_agent_count(work);
        move->step_units =
            codex_game_delegated_steps(work, move->subagent_units);
    } else {
        codex_game_finish_move(move);
    }
}

static CodexGameMove codex_game_move_for_strategy(CodexGameStrategyKind strategy,
                                                  CodexGameTask task) {
    CodexGameMove move = {0};

    switch (strategy) {
        case CODEX_GAME_STRATEGY_FEATURE_FIRST:
            move.feature_units = task.feature_units;
            move.test_units = codex_game_positive_unit(task.test_units);
            move.debt_units = task.debt_units;
            move.irrelevant_units = task.irrelevant_units;
            codex_game_finish_move(&move);
            break;
        case CODEX_GAME_STRATEGY_SCORE_ONLY:
            move.feature_units = codex_game_positive_unit(task.feature_units);
            move.cleanup_units = task.cleanup_units;
            move.test_units = task.test_units;
            move.deleted_units = task.deleted_units;
            move.debt_units =
                task.debt_units > 0 && task.cleanup_units == 0 ? 1 : 0;
            codex_game_finish_move(&move);
            break;
        case CODEX_GAME_STRATEGY_CLEANUP_FIRST:
            move.cleanup_units = task.cleanup_units;
            move.deleted_units = task.deleted_units;
            move.test_units = codex_game_positive_unit(task.test_units);
            if (task.cleanup_units == 0 && task.deleted_units == 0) {
                move.feature_units = codex_game_positive_unit(task.feature_units);
            }
            codex_game_finish_move(&move);
            break;
        case CODEX_GAME_STRATEGY_GATE_AND_SCORE:
            move.feature_units = codex_game_positive_unit(task.feature_units);
            move.cleanup_units = task.cleanup_units;
            move.test_units = task.test_units;
            move.deleted_units = task.deleted_units;
            codex_game_finish_move(&move);
            if (codex_game_score_move(move) < CODEX_GAME_SCORE_GATE_FLOOR) {
                memset(&move, 0, sizeof(move));
            }
            break;
        case CODEX_GAME_STRATEGY_DELEGATED_GATE:
            move.feature_units = codex_game_positive_unit(task.feature_units);
            move.cleanup_units = task.cleanup_units;
            move.test_units = task.test_units;
            move.deleted_units = task.deleted_units;
            codex_game_finish_delegated_move(&move);
            if (codex_game_score_move(move) < CODEX_GAME_SCORE_GATE_FLOOR) {
                memset(&move, 0, sizeof(move));
            }
            break;
    }
    return move;
}

static void codex_game_result_add(CodexGameResult *result,
                                  CodexGameMove move) {
    int score = codex_game_score_move(move);

    result->total_score += score;
    result->units.feature_units += move.feature_units;
    result->units.cleanup_units += move.cleanup_units;
    result->units.test_units += move.test_units;
    result->units.deleted_units += move.deleted_units;
    result->units.debt_units += move.debt_units;
    result->units.irrelevant_units += move.irrelevant_units;
    result->units.step_units += move.step_units;
    result->units.subagent_units += move.subagent_units;
    if (score < CODEX_GAME_SCORE_GATE_FLOOR) {
        result->rejected_moves++;
    }
}

static int codex_game_better_move(CodexGameMove a, CodexGameMove b) {
    int score_a = codex_game_score_move(a);
    int score_b = codex_game_score_move(b);

    if (score_a != score_b) return score_a > score_b;
    if (a.step_units != b.step_units) return a.step_units < b.step_units;
    if (a.cleanup_units != b.cleanup_units) {
        return a.cleanup_units > b.cleanup_units;
    }
    if (a.debt_units != b.debt_units) return a.debt_units < b.debt_units;
    return a.feature_units > b.feature_units;
}

static CodexGameStrategyKind codex_game_strategy_at(size_t index) {
    switch (index) {
        case CODEX_GAME_STRATEGY_FEATURE_FIRST:
            return CODEX_GAME_STRATEGY_FEATURE_FIRST;
        case CODEX_GAME_STRATEGY_SCORE_ONLY:
            return CODEX_GAME_STRATEGY_SCORE_ONLY;
        case CODEX_GAME_STRATEGY_CLEANUP_FIRST:
            return CODEX_GAME_STRATEGY_CLEANUP_FIRST;
        case CODEX_GAME_STRATEGY_GATE_AND_SCORE:
            return CODEX_GAME_STRATEGY_GATE_AND_SCORE;
        case CODEX_GAME_STRATEGY_DELEGATED_GATE:
            return CODEX_GAME_STRATEGY_DELEGATED_GATE;
    }
    return CODEX_GAME_STRATEGY_DELEGATED_GATE;
}

static const char *codex_game_strategy_name(CodexGameStrategyKind strategy) {
    switch (strategy) {
        case CODEX_GAME_STRATEGY_FEATURE_FIRST:
            return "current-feature-first";
        case CODEX_GAME_STRATEGY_SCORE_ONLY:
            return "score-only";
        case CODEX_GAME_STRATEGY_CLEANUP_FIRST:
            return "cleanup-first";
        case CODEX_GAME_STRATEGY_GATE_AND_SCORE:
            return "gate-and-score";
        case CODEX_GAME_STRATEGY_DELEGATED_GATE:
            return "delegated-gate";
    }
    return "delegated-gate";
}

static int codex_game_bench(void) {
    CodexGameResult solo[CODEX_GAME_STRATEGY_COUNT] = {{0}};
    CodexGameResult tournament = {0};
    uint64_t state = CODEX_GAME_TASK_SEED;

    for (size_t task_index = 0u;
         task_index < CODEX_GAME_BENCH_TASKS;
         ++task_index) {
        CodexGameTask task = codex_game_task_new(&state, task_index);
        CodexGameMove best = {0};
        size_t best_strategy = 0u;
        bool best_set = false;

        for (size_t strategy_index = 0u;
             strategy_index < CODEX_GAME_STRATEGY_COUNT;
             ++strategy_index) {
            CodexGameStrategyKind strategy =
                codex_game_strategy_at(strategy_index);
            CodexGameMove move = codex_game_move_for_strategy(
                strategy,
                task);
            codex_game_result_add(&solo[strategy_index], move);
            if (!best_set || codex_game_better_move(move, best) != 0) {
                best = move;
                best_strategy = strategy_index;
                best_set = true;
            }
        }
        codex_game_result_add(&tournament, best);
        solo[best_strategy].wins++;
        tournament.wins++;
    }

    puts("quality game benchmark");
    printf("tasks: %u deterministic synthetic repo-change tasks\n",
           (unsigned)CODEX_GAME_BENCH_TASKS);
    puts("score: feature +1, cleanup +8, test +5, delete +2, step -1, "
         "subagent +0, debt -6, irrelevant -10");
    puts("");
    puts("solo strategy results");
    for (size_t i = 0u; i < CODEX_GAME_STRATEGY_COUNT; ++i) {
        CodexGameStrategyKind strategy = codex_game_strategy_at(i);
        printf("%-22s score=%5d wins=%3d steps=%3d agents=%3d feature=%3d "
               "cleanup=%3d tests=%3d delete=%3d debt=%3d irrelevant=%3d "
               "negative=%3d\n",
               codex_game_strategy_name(strategy),
               solo[i].total_score,
               solo[i].wins,
               solo[i].units.step_units,
               solo[i].units.subagent_units,
               solo[i].units.feature_units,
               solo[i].units.cleanup_units,
               solo[i].units.test_units,
               solo[i].units.deleted_units,
               solo[i].units.debt_units,
               solo[i].units.irrelevant_units,
               solo[i].rejected_moves);
    }
    puts("");
    printf("tournament winner-picks score=%5d steps=%3d agents=%3d "
           "feature=%3d cleanup=%3d tests=%3d delete=%3d debt=%3d "
           "irrelevant=%3d negative=%3d\n",
           tournament.total_score,
           tournament.units.step_units,
           tournament.units.subagent_units,
           tournament.units.feature_units,
           tournament.units.cleanup_units,
           tournament.units.test_units,
           tournament.units.deleted_units,
           tournament.units.debt_units,
           tournament.units.irrelevant_units,
           tournament.rejected_moves);
    puts("");
    puts("learned:");
    puts("- feature-first creates the most feature units but also carries debt");
    puts("- cleanup-first wins cleanup-heavy tasks, but under-delivers features");
    puts("- score-only can still accept small debt when cleanup is absent");
    puts("- gate-and-score keeps feature progress while preventing negative moves");
    puts("- delegated-gate wins when parallel side work reduces host steps enough");
    return 0;
}

static int codex_game_self_test(void) {
    static const char fixture_before[] =
        "Inventory\n"
        "  C files: 1  code: 10 loc\n"
        "Issues by group\n"
        "  duplication: 2 production, 0 mixed test/source\n"
        "  worldview: 1 findings\n"
        "  CPU cost: 3 findings\n"
        "  smells: 4 findings\n";
    static const char fixture_after[] =
        "Inventory\n"
        "  C files: 1  code: 8 loc\n"
        "Issues by group\n"
        "  duplication: 1 production, 0 mixed test/source\n"
        "  worldview: 1 findings\n"
        "  CPU cost: 2 findings\n"
        "  smells: 5 findings\n";
    CodexGameInspectTotals before;
    CodexGameInspectTotals after;

    if (!codex_game_inspect_totals_parse(fixture_before, &before)) {
        return CODEX_GAME_SELF_TEST_PARSE_BEFORE_FAILURE;
    }
    if (!codex_game_inspect_totals_parse(fixture_after, &after)) {
        return CODEX_GAME_SELF_TEST_PARSE_AFTER_FAILURE;
    }
    CodexGameQualityScore score = codex_game_quality_score(&before, &after, 1u);
    if (score.duplicates_removed != 1u) {
        return CODEX_GAME_SELF_TEST_DUPLICATE_FAILURE;
    }
    if (score.cpu_removed != 1u) return CODEX_GAME_SELF_TEST_CPU_FAILURE;
    if (score.loc_removed != 2u) return CODEX_GAME_SELF_TEST_LOC_FAILURE;
    if (score.debt_added != 1u) return CODEX_GAME_SELF_TEST_DEBT_FAILURE;
    if (score.score != CODEX_GAME_SELF_TEST_EXPECTED_SCORE) {
        return CODEX_GAME_SELF_TEST_SCORE_FAILURE;
    }
    return 0;
}
