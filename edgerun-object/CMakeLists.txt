cmake_minimum_required(VERSION 3.16)
project(edgerun_object C)

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR
    AND NOT CMAKE_BUILD_TYPE
    AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()

add_library(edgerun_object STATIC
  src/er_object.c
  ../edgerun-crypto/src/er_blake3.c
)
target_include_directories(edgerun_object PUBLIC
  ${CMAKE_CURRENT_SOURCE_DIR}/include
  ${CMAKE_CURRENT_SOURCE_DIR}/../edgerun-crypto/include
  ${CMAKE_CURRENT_SOURCE_DIR}/../include
)
target_compile_definitions(edgerun_object PRIVATE ER_BLAKE3_NO_SIMD=1)
target_compile_options(edgerun_object PRIVATE
  -ffreestanding
  -fno-builtin
  -fno-stack-protector
)
target_compile_features(edgerun_object PUBLIC c_std_11)

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  enable_testing()

  add_executable(test_object
    tests/test_object.c
  )
  target_link_libraries(test_object PRIVATE edgerun_object)

  add_test(NAME object COMMAND test_object)
endif()
