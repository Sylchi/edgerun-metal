#pragma once

#include "vr_font.h"

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#define TEST_FONT_PATH "fonts/Geist[wght].ttf"

extern int g_tests_total;
extern int g_tests_failed;

void test_expect(bool cond, const char* name);
void test_expect_status(vr_status_t got, vr_status_t expected, const char* name);
void test_expect_u32_eq(uint32_t got, uint32_t expected, const char* name);

vr_font_config_t test_default_font_config(void);
const char* test_font_path(void);
vr_font_face_t* test_open_face(const char* path);
vr_font_face_t* test_open_default_face(void);
void test_close_face(vr_font_face_t* face);

uint32_t* test_ascii_codepoints(const char* text, size_t* out_count);
void test_free_codepoints(uint32_t* cps);

void test_report_results(void);

