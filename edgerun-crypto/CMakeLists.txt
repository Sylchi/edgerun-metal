cmake_minimum_required(VERSION 3.16)
project(edgerun_crypto C)

add_library(edgerun_crypto STATIC
  src/er_blake3.c
)
target_include_directories(edgerun_crypto PUBLIC
  ${CMAKE_CURRENT_SOURCE_DIR}/include
)
target_compile_features(edgerun_crypto PUBLIC c_std_11)

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  enable_testing()

  add_executable(test_blake3
    tests/test_blake3.c
  )
  target_link_libraries(test_blake3 PRIVATE edgerun_crypto)

  add_test(NAME blake3 COMMAND test_blake3)
endif()
