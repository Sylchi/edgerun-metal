cmake_minimum_required(VERSION 3.16)
project(edgerun_identity C)

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR
    AND NOT CMAKE_BUILD_TYPE
    AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()

add_library(edgerun_identity STATIC
  src/er_identity.c
  ../edgerun-clock/src/er_clock.c
  ../edgerun-crypto/src/er_blake3.c
)
target_include_directories(edgerun_identity PUBLIC
  ${CMAKE_CURRENT_SOURCE_DIR}/include
  ${CMAKE_CURRENT_SOURCE_DIR}/../edgerun-clock/include
  ${CMAKE_CURRENT_SOURCE_DIR}/../edgerun-crypto/include
)
target_compile_definitions(edgerun_identity PRIVATE ER_BLAKE3_NO_SIMD=1)
target_compile_options(edgerun_identity PRIVATE
  -ffreestanding
  -fno-builtin
  -fno-stack-protector
)
target_compile_features(edgerun_identity PUBLIC c_std_11)

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  enable_testing()

  add_executable(test_identity
    tests/test_identity.c
  )
  target_link_libraries(test_identity PRIVATE edgerun_identity)

  add_test(NAME identity COMMAND test_identity)
endif()
