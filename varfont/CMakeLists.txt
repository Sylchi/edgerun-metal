cmake_minimum_required(VERSION 3.16)
project(vrfont C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
option(VRFONT_ENABLE_COVERAGE "Enable coverage instrumentation for the test target." OFF)
option(VRFONT_BUILD_HOSTED_TOOLS "Build hosted SDL demo and ctest targets." ON)

if(VRFONT_ENABLE_COVERAGE)
  if (CMAKE_C_COMPILER_ID MATCHES "GNU|Clang")
    set(COVERAGE_FLAGS -O0 -g -fprofile-arcs -ftest-coverage)
  else()
    message(FATAL_ERROR "Coverage flags are configured for GCC/Clang only.")
  endif()
endif()

add_library(vrfont
  src/vr_font_freestanding.c
  src/vr_font.c
  src/vr_font_utils.c
  src/vr_font_shape.c
  src/vr_font_raster.c
  src/vr_font_atlas.c
)
if(CMAKE_C_COMPILER_ID MATCHES "GNU|Clang")
  target_compile_options(vrfont PRIVATE -Wall -Wextra -Wpedantic -Werror -ffreestanding -fno-builtin -fno-stack-protector)
endif()
if(VRFONT_ENABLE_COVERAGE)
  target_compile_options(vrfont PRIVATE ${COVERAGE_FLAGS})
  target_link_options(vrfont PRIVATE --coverage)
endif()

target_include_directories(vrfont PUBLIC
  ${CMAKE_CURRENT_SOURCE_DIR}/include
  ${CMAKE_CURRENT_SOURCE_DIR}/../include
)

if(VRFONT_BUILD_HOSTED_TOOLS)
find_package(SDL2 REQUIRED)

if (NOT TARGET SDL2::SDL2)
  message(FATAL_ERROR "SDL2::SDL2 target not found. Install SDL2 with CMake package metadata.")
endif()

add_executable(vrfont_demo examples/main.c)
if (TARGET SDL2::SDL2main)
  target_link_libraries(vrfont_demo PRIVATE vrfont SDL2::SDL2 SDL2::SDL2main)
else()
  target_link_libraries(vrfont_demo PRIVATE vrfont SDL2::SDL2)
endif()
if(UNIX)
  target_link_libraries(vrfont_demo PRIVATE m)
endif()

enable_testing()

add_executable(vrfont_tests
  tests/test_runner.c
  tests/test_common.c
  tests/test_validation.c
  tests/test_axes.c
  tests/test_shape.c
  tests/test_atlas_cache.c
  tests/test_api.c
  tests/test_cmap.c
  tests/test_raster.c
)
target_link_libraries(vrfont_tests PRIVATE vrfont)
if(UNIX)
  target_link_libraries(vrfont_tests PRIVATE m)
endif()
target_include_directories(vrfont_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)
target_compile_definitions(vrfont_tests PRIVATE VRFONT_PROJECT_ROOT="${CMAKE_CURRENT_SOURCE_DIR}")
if(VRFONT_ENABLE_COVERAGE)
  target_compile_options(vrfont_tests PRIVATE ${COVERAGE_FLAGS})
  target_link_options(vrfont_tests PRIVATE --coverage)
endif()
add_test(NAME vrfont_tests COMMAND vrfont_tests)
endif()
