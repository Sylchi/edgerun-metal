cmake_minimum_required(VERSION 3.16)
project(edgerun_storage C)

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR
    AND NOT CMAKE_BUILD_TYPE
    AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()

add_library(edgerun_storage STATIC
  src/er_store.c
  ../edgerun-object/src/er_object.c
  ../edgerun-identity/src/er_identity.c
  ../edgerun-clock/src/er_clock.c
  ../edgerun-crypto/src/er_blake3.c
)
target_include_directories(edgerun_storage PUBLIC
  ${CMAKE_CURRENT_SOURCE_DIR}/include
  ${CMAKE_CURRENT_SOURCE_DIR}/../edgerun-object/include
  ${CMAKE_CURRENT_SOURCE_DIR}/../edgerun-identity/include
  ${CMAKE_CURRENT_SOURCE_DIR}/../edgerun-clock/include
  ${CMAKE_CURRENT_SOURCE_DIR}/../edgerun-crypto/include
  ${CMAKE_CURRENT_SOURCE_DIR}/../include
)
target_compile_definitions(edgerun_storage PRIVATE ER_BLAKE3_NO_SIMD=1)
target_compile_features(edgerun_storage PUBLIC c_std_11)

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  enable_testing()

  add_executable(test_store
    tests/test_store.c
  )
  target_link_libraries(test_store PRIVATE edgerun_storage)

  add_test(NAME store COMMAND test_store)

  add_executable(bench_store
    bench/bench_store.c
  )
  target_link_libraries(bench_store PRIVATE edgerun_storage)

  add_custom_target(bench
    COMMAND bench_store
    DEPENDS bench_store
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
  )
endif()
