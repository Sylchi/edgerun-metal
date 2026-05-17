#ifndef ER_UI_TEST_COMMON_H
#define ER_UI_TEST_COMMON_H

#include "er_ui_painter.h"
#include "er_ui_components.h"
#include "er_ui_primitives.h"
#include "er_ui_scene.h"
#include "er_ui_shell.h"
#include "er_ui_theme.h"
#include "er_ui_text.h"

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

extern int g_tests_total;
extern int g_tests_failed;

void expect_true(bool condition, const char* name);
void expect_status(er_ui_status_t got, er_ui_status_t expected, const char* name);
void expect_size(size_t got, size_t expected, const char* name);
void expect_u32(uint32_t got, uint32_t expected, const char* name);
void expect_float(float got, float expected, const char* name);
void expect_string(const char* got, const char* expected, const char* name);
er_ui_allocator_t er_ui_test_allocator(void);

#endif
