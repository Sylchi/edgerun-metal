; EdgeRun ctype self-hosted test runner — x86_64 assembly
; No libc, no external dependencies. Exits via syscall.
; Returns 0 if all tests pass, 1 on any failure.

%include "x86_64/macros.inc"
%include "test/test_macros.inc"

extern er_isdigit, er_isalpha, er_isalnum, er_isspace
extern er_isxdigit, er_islower, er_isupper, er_tolower, er_toupper

TEST_BSS_TOTAL_PASSED

SECTION .text
global _start
_start:
    ; er_isdigit
    TEST_CALL_EAX er_isdigit, '0', 1
    TEST_CALL_EAX er_isdigit, '5', 1
    TEST_CALL_EAX er_isdigit, '9', 1
    TEST_CALL_EAX er_isdigit, 'A', 0
    TEST_CALL_EAX er_isdigit, ' ', 0
    TEST_CALL_EAX er_isdigit, 0,   0

    ; er_isalpha
    TEST_CALL_EAX er_isalpha, 'A', 1
    TEST_CALL_EAX er_isalpha, 'Z', 1
    TEST_CALL_EAX er_isalpha, 'a', 1
    TEST_CALL_EAX er_isalpha, 'z', 1
    TEST_CALL_EAX er_isalpha, '0', 0
    TEST_CALL_EAX er_isalpha, '[', 0

    ; er_isalnum
    TEST_CALL_EAX er_isalnum, 'A', 1
    TEST_CALL_EAX er_isalnum, 'z', 1
    TEST_CALL_EAX er_isalnum, '0', 1
    TEST_CALL_EAX er_isalnum, '9', 1
    TEST_CALL_EAX er_isalnum, ' ', 0
    TEST_CALL_EAX er_isalnum, '@', 0

    ; er_isspace
    TEST_CALL_EAX er_isspace, ' ',  1
    TEST_CALL_EAX er_isspace, 9,    1       ; \t
    TEST_CALL_EAX er_isspace, 10,   1       ; \n
    TEST_CALL_EAX er_isspace, 13,   1       ; \r
    TEST_CALL_EAX er_isspace, 'A',  0
    TEST_CALL_EAX er_isspace, '0',  0

    ; er_isxdigit
    TEST_CALL_EAX er_isxdigit, '0', 1
    TEST_CALL_EAX er_isxdigit, '9', 1
    TEST_CALL_EAX er_isxdigit, 'A', 1
    TEST_CALL_EAX er_isxdigit, 'F', 1
    TEST_CALL_EAX er_isxdigit, 'a', 1
    TEST_CALL_EAX er_isxdigit, 'f', 1
    TEST_CALL_EAX er_isxdigit, 'G', 0
    TEST_CALL_EAX er_isxdigit, ' ', 0

    ; er_islower
    TEST_CALL_EAX er_islower, 'a', 1
    TEST_CALL_EAX er_islower, 'z', 1
    TEST_CALL_EAX er_islower, 'A', 0
    TEST_CALL_EAX er_islower, '0', 0

    ; er_isupper
    TEST_CALL_EAX er_isupper, 'A', 1
    TEST_CALL_EAX er_isupper, 'Z', 1
    TEST_CALL_EAX er_isupper, 'a', 0
    TEST_CALL_EAX er_isupper, '0', 0

    ; er_tolower
    TEST_CALL_EAX er_tolower, 'A', 'a'
    TEST_CALL_EAX er_tolower, 'Z', 'z'
    TEST_CALL_EAX er_tolower, 'a', 'a'
    TEST_CALL_EAX er_tolower, '0', '0'
    TEST_CALL_EAX er_tolower, '[', '['

    ; er_toupper
    TEST_CALL_EAX er_toupper, 'a', 'A'
    TEST_CALL_EAX er_toupper, 'z', 'Z'
    TEST_CALL_EAX er_toupper, 'A', 'A'
    TEST_CALL_EAX er_toupper, '0', '0'
    TEST_CALL_EAX er_toupper, '{', '{'

    TEST_EXIT_PASSED_TOTAL
