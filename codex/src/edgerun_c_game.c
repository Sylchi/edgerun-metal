#define CODEX_GAME_BENCH_TASKS 100u
#define CODEX_GAME_STRATEGY_COUNT 4u
#define CODEX_GAME_SCORE_FEATURE 1
#define CODEX_GAME_SCORE_CLEANUP 8
#define CODEX_GAME_SCORE_TEST 5
#define CODEX_GAME_SCORE_DELETE 2
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
#define CODEX_GAME_SELF_TEST_POSITIVE_SCORE 16
#define CODEX_GAME_SELF_TEST_NEGATIVE_SCORE -15

typedef enum {
    CODEX_GAME_STRATEGY_FEATURE_FIRST = 0,
    CODEX_GAME_STRATEGY_SCORE_ONLY,
    CODEX_GAME_STRATEGY_CLEANUP_FIRST,
    CODEX_GAME_STRATEGY_GATE_AND_SCORE
} CodexGameStrategyKind;

typedef struct {
    int feature_units;
    int cleanup_units;
    int test_units;
    int deleted_units;
    int debt_units;
    int irrelevant_units;
} CodexGameUnits;

typedef CodexGameUnits CodexGameTask;
typedef CodexGameUnits CodexGameMove;

typedef struct {
    int total_score;
    CodexGameUnits units;
    int rejected_moves;
    int wins;
} CodexGameResult;

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
        "Winning condition: maximize score delta while passing repo-progress. "
        "Feature code that merely works scores lowest unless it also reduces debt. "
        "The host should reject negative-score proposal batches unless the user "
        "explicitly accepts feature debt.\n";
    Buffer b;

    buffer_init(&b);
    buffer_append(&b, text, strlen(text));
    return b.data ? b.data : xstrdup("");
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
           (move.irrelevant_units * CODEX_GAME_SCORE_IRRELEVANT) +
           (move.debt_units * CODEX_GAME_SCORE_DEBT);
}

static CodexGameMove codex_game_move_for_strategy(CodexGameStrategyKind strategy,
                                                  CodexGameTask task) {
    CodexGameMove move = {0};

    switch (strategy) {
        case CODEX_GAME_STRATEGY_FEATURE_FIRST:
            move.feature_units = task.feature_units;
            move.test_units = task.test_units > 0 ? 1 : 0;
            move.debt_units = task.debt_units;
            move.irrelevant_units = task.irrelevant_units;
            break;
        case CODEX_GAME_STRATEGY_SCORE_ONLY:
            move.feature_units = task.feature_units > 0 ? 1 : 0;
            move.cleanup_units = task.cleanup_units;
            move.test_units = task.test_units;
            move.deleted_units = task.deleted_units;
            move.debt_units =
                task.debt_units > 0 && task.cleanup_units == 0 ? 1 : 0;
            break;
        case CODEX_GAME_STRATEGY_CLEANUP_FIRST:
            move.cleanup_units = task.cleanup_units;
            move.deleted_units = task.deleted_units;
            move.test_units = task.test_units > 0 ? 1 : 0;
            if (task.cleanup_units == 0 && task.deleted_units == 0) {
                move.feature_units = task.feature_units > 0 ? 1 : 0;
            }
            break;
        case CODEX_GAME_STRATEGY_GATE_AND_SCORE:
            move.feature_units = task.feature_units > 0 ? 1 : 0;
            move.cleanup_units = task.cleanup_units;
            move.test_units = task.test_units;
            move.deleted_units = task.deleted_units;
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
    if (score < CODEX_GAME_SCORE_GATE_FLOOR) {
        result->rejected_moves++;
    }
}

static int codex_game_better_move(CodexGameMove a, CodexGameMove b) {
    int score_a = codex_game_score_move(a);
    int score_b = codex_game_score_move(b);

    if (score_a != score_b) return score_a > score_b;
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
    }
    return CODEX_GAME_STRATEGY_GATE_AND_SCORE;
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
    }
    return "gate-and-score";
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
    puts("score: feature +1, cleanup +8, test +5, delete +2, debt -6, "
         "irrelevant -10");
    puts("");
    puts("solo strategy results");
    for (size_t i = 0u; i < CODEX_GAME_STRATEGY_COUNT; ++i) {
        CodexGameStrategyKind strategy = codex_game_strategy_at(i);
        printf("%-22s score=%5d wins=%3d feature=%3d cleanup=%3d tests=%3d "
               "delete=%3d debt=%3d irrelevant=%3d negative=%3d\n",
               codex_game_strategy_name(strategy),
               solo[i].total_score,
               solo[i].wins,
               solo[i].units.feature_units,
               solo[i].units.cleanup_units,
               solo[i].units.test_units,
               solo[i].units.deleted_units,
               solo[i].units.debt_units,
               solo[i].units.irrelevant_units,
               solo[i].rejected_moves);
    }
    puts("");
    printf("tournament winner-picks score=%5d feature=%3d cleanup=%3d tests=%3d "
           "delete=%3d debt=%3d irrelevant=%3d negative=%3d\n",
           tournament.total_score,
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
    return 0;
}
