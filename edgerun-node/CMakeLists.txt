cmake_minimum_required(VERSION 3.16)
project(edgerun_node C)

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR
    AND NOT CMAKE_BUILD_TYPE
    AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()

add_library(edgerun_node STATIC
  src/er_node.c
  ../edgerun-storage/src/er_store.c
  ../edgerun-object/src/er_object.c
  ../edgerun-identity/src/er_identity.c
  ../edgerun-clock/src/er_clock.c
  ../edgerun-crypto/src/er_blake3.c
)
target_include_directories(edgerun_node PUBLIC
  ${CMAKE_CURRENT_SOURCE_DIR}/include
  ${CMAKE_CURRENT_SOURCE_DIR}/../edgerun-storage/include
  ${CMAKE_CURRENT_SOURCE_DIR}/../edgerun-object/include
  ${CMAKE_CURRENT_SOURCE_DIR}/../edgerun-identity/include
  ${CMAKE_CURRENT_SOURCE_DIR}/../edgerun-clock/include
  ${CMAKE_CURRENT_SOURCE_DIR}/../edgerun-crypto/include
  ${CMAKE_CURRENT_SOURCE_DIR}/../include
)
target_compile_definitions(edgerun_node PRIVATE ER_BLAKE3_NO_SIMD=1)
target_compile_features(edgerun_node PUBLIC c_std_11)

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  enable_testing()

  add_executable(test_node
    tests/test_node.c
  )
  target_link_libraries(test_node PRIVATE edgerun_node)

  add_test(NAME node COMMAND test_node)
endif()
