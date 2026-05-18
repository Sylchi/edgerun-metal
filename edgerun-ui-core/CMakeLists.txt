cmake_minimum_required(VERSION 3.16)
project(er_ui_core C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
option(ER_UI_CORE_BUILD_TESTS "Build hosted ctest targets." ON)

if(NOT TARGET vrfont)
  set(VRFONT_BUILD_HOSTED_TOOLS OFF CACHE BOOL "" FORCE)
  add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/../varfont ${CMAKE_CURRENT_BINARY_DIR}/varfont)
endif()

add_library(er_ui_core
  src/er_ui_assets.c
  src/er_ui_components.c
  src/er_ui_demo_apps.c
  src/er_ui_icon.c
  src/er_ui_initial_setup.c
  src/er_ui_metal.c
  src/er_ui_node.c
  src/er_ui_painter.c
  src/er_ui_primitives.c
  src/er_ui_preset_code.c
  src/er_ui_record_codec.c
  src/er_ui_runtime.c
  src/er_ui_scene.c
  src/er_ui_shell.c
  src/er_ui_spacing.c
  src/er_ui_theme.c
  src/er_ui_text.c
)

target_include_directories(er_ui_core PUBLIC
  ${CMAKE_CURRENT_SOURCE_DIR}/include
  ${CMAKE_CURRENT_SOURCE_DIR}/../include
)

target_link_libraries(er_ui_core PUBLIC vrfont)

if(CMAKE_C_COMPILER_ID MATCHES "GNU|Clang")
  target_compile_options(er_ui_core PRIVATE -Wall -Wextra -Wpedantic -Werror -ffreestanding -fno-builtin -fno-stack-protector)
endif()

if(ER_UI_CORE_BUILD_TESTS)
  enable_testing()

add_executable(er_ui_core_tests
    tests/test_assets.c
    tests/test_components.c
    tests/test_demo_apps.c
    tests/test_initial_setup.c
    tests/test_node.c
    tests/test_preset_code.c
    tests/test_record_codec.c
    tests/test_shell.c
    tests/test_runtime.c
    tests/test_scene.c
    tests/test_text.c
    tests/test_spacing.c
  )

  target_link_libraries(er_ui_core_tests PRIVATE er_ui_core)
  target_compile_definitions(er_ui_core_tests PRIVATE ER_UI_REPO_ROOT="${CMAKE_CURRENT_SOURCE_DIR}/..")

  if(UNIX)
    target_link_libraries(er_ui_core_tests PRIVATE m)
  endif()

  if(CMAKE_C_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(er_ui_core_tests PRIVATE -Wall -Wextra -Wpedantic -Werror)
  endif()

  add_test(NAME er_ui_core_tests COMMAND er_ui_core_tests)
endif()
