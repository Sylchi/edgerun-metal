cmake_minimum_required(VERSION 3.16)
project(edgerun_clock C)

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR
    AND NOT CMAKE_BUILD_TYPE
    AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()

add_library(edgerun_clock STATIC
  src/er_clock.c
)
target_include_directories(edgerun_clock PUBLIC
  ${CMAKE_CURRENT_SOURCE_DIR}/include
)
target_compile_options(edgerun_clock PRIVATE
  -ffreestanding
  -fno-builtin
  -fno-stack-protector
)
target_compile_features(edgerun_clock PUBLIC c_std_11)

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  enable_testing()

  add_executable(test_clock
    tests/test_clock.c
  )
  target_link_libraries(test_clock PRIVATE edgerun_clock)

  add_test(NAME clock COMMAND test_clock)
endif()
