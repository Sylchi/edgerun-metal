cmake_minimum_required(VERSION 3.16)
project(edgerun_crypto C)

option(ER_CRYPTO_DISABLE_SIMD "Disable SIMD acceleration in edgerun-crypto" OFF)
option(ER_CRYPTO_ENABLE_AVX2 "Build edgerun-crypto with AVX2 acceleration" OFF)
option(ER_CRYPTO_ENABLE_AVX512 "Build edgerun-crypto with AVX-512 acceleration" OFF)
option(ER_CRYPTO_ENABLE_THREADS "Build hosted pthread adapter for development and benchmark runs" OFF)
option(ER_CRYPTO_ENABLE_NATIVE "Build with native host CPU tuning for development and benchmark runs" OFF)
set(ER_CRYPTO_THREAD_COUNT 8 CACHE STRING "Maximum hosted pthread jobs for BLAKE3 benchmark runs")

if(ER_CRYPTO_USE_UPSTREAM_BLAKE3_ASM)
  message(FATAL_ERROR "ER_CRYPTO_USE_UPSTREAM_BLAKE3_ASM is unsupported; edgerun-crypto uses repo-owned C SIMD/scalar code")
endif()
unset(ER_CRYPTO_USE_UPSTREAM_BLAKE3_ASM CACHE)

function(er_crypto_strict_c_warnings target_name)
  if(MSVC)
    target_compile_options(${target_name} PRIVATE
      $<$<COMPILE_LANGUAGE:C>:/W4>
      $<$<COMPILE_LANGUAGE:C>:/WX>
    )
  else()
    target_compile_options(${target_name} PRIVATE
      $<$<COMPILE_LANGUAGE:C>:-Wall>
      $<$<COMPILE_LANGUAGE:C>:-Wextra>
      $<$<COMPILE_LANGUAGE:C>:-Wpedantic>
      $<$<COMPILE_LANGUAGE:C>:-Werror>
    )
  endif()
endfunction()

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR
    AND NOT CMAKE_BUILD_TYPE
    AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()

add_library(edgerun_crypto STATIC
  src/er_blake3.c
)
target_include_directories(edgerun_crypto PUBLIC
  ${CMAKE_CURRENT_SOURCE_DIR}/include
  ${CMAKE_CURRENT_SOURCE_DIR}/../include
)
target_compile_features(edgerun_crypto PUBLIC c_std_11)
er_crypto_strict_c_warnings(edgerun_crypto)
if(ER_CRYPTO_DISABLE_SIMD)
  target_compile_definitions(edgerun_crypto PRIVATE ER_BLAKE3_NO_SIMD=1)
endif()
if(ER_CRYPTO_ENABLE_THREADS)
  find_package(Threads REQUIRED)
  target_compile_definitions(edgerun_crypto PRIVATE ER_BLAKE3_ENABLE_THREADS=1)
  target_compile_definitions(edgerun_crypto PRIVATE ER_BLAKE3_PTHREAD_JOBS=${ER_CRYPTO_THREAD_COUNT})
  target_link_libraries(edgerun_crypto PUBLIC Threads::Threads)
endif()
if(ER_CRYPTO_ENABLE_NATIVE AND NOT MSVC)
  target_compile_options(edgerun_crypto PRIVATE -march=native)
endif()
if(ER_CRYPTO_ENABLE_AVX512 AND NOT ER_CRYPTO_DISABLE_SIMD)
  if(MSVC)
    target_compile_options(edgerun_crypto PRIVATE /arch:AVX512)
  else()
    target_compile_options(edgerun_crypto PRIVATE -mavx2 -mavx512f -mavx512vl)
  endif()
elseif(ER_CRYPTO_ENABLE_AVX2 AND NOT ER_CRYPTO_DISABLE_SIMD)
  if(MSVC)
    target_compile_options(edgerun_crypto PRIVATE /arch:AVX2)
  else()
    target_compile_options(edgerun_crypto PRIVATE -mavx2)
  endif()
endif()

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  enable_testing()

  add_executable(test_blake3
    tests/test_blake3.c
  )
  target_link_libraries(test_blake3 PRIVATE edgerun_crypto)
  er_crypto_strict_c_warnings(test_blake3)

  add_test(NAME blake3 COMMAND test_blake3)

  add_executable(bench_blake3
    bench/bench_blake3.c
  )
  target_link_libraries(bench_blake3 PRIVATE edgerun_crypto)
  er_crypto_strict_c_warnings(bench_blake3)

  add_custom_target(bench
    COMMAND bench_blake3
    DEPENDS bench_blake3
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
  )
endif()
