#!/usr/bin/env bash
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
UPSTREAM_REPO=${BLAKE3_UPSTREAM_REPO:-https://github.com/BLAKE3-team/BLAKE3.git}
UPSTREAM_DIR=${BLAKE3_UPSTREAM_DIR:-"$ROOT_DIR/.build/blake3-upstream"}
UPSTREAM_REF=${BLAKE3_UPSTREAM_REF:-}
BUILD_DIR=${BLAKE3_SOTA_BUILD_DIR:-"$ROOT_DIR/.build/blake3-sota"}
HOST_CC=${HOST_CC:-clang}
HOST_CXX=${HOST_CXX:-clang++}
HOST_LDFLAGS=${HOST_LDFLAGS:-}
CCACHE=${CCACHE:-}

if [ -z "$CCACHE" ] && command -v ccache >/dev/null 2>&1; then
  CCACHE=ccache
fi

mkdir -p "$ROOT_DIR/.build" "$BUILD_DIR"

if [ ! -d "$UPSTREAM_DIR/.git" ]; then
  echo "Fetching upstream BLAKE3 into $UPSTREAM_DIR"
  git clone --depth 1 "$UPSTREAM_REPO" "$UPSTREAM_DIR"
elif [ "${BLAKE3_UPSTREAM_UPDATE:-0}" = "1" ]; then
  echo "Updating upstream BLAKE3 in $UPSTREAM_DIR"
  git -C "$UPSTREAM_DIR" fetch --depth 1 origin
  git -C "$UPSTREAM_DIR" checkout --detach FETCH_HEAD
fi

if [ -n "$UPSTREAM_REF" ]; then
  git -C "$UPSTREAM_DIR" fetch --depth 1 origin "$UPSTREAM_REF"
  git -C "$UPSTREAM_DIR" checkout --detach FETCH_HEAD
fi

UPSTREAM_COMMIT=$(git -C "$UPSTREAM_DIR" rev-parse --short HEAD)
echo "Upstream BLAKE3 commit: $UPSTREAM_COMMIT"

UPSTREAM_C="$UPSTREAM_DIR/c"
BENCH_SRC="$ROOT_DIR/edgerun-crypto/bench/bench_blake3_upstream.c"
COMMON_SRCS="$UPSTREAM_C/blake3.c $UPSTREAM_C/blake3_dispatch.c $UPSTREAM_C/blake3_portable.c"
ASM_SRCS="$UPSTREAM_C/blake3_sse2_x86-64_unix.S $UPSTREAM_C/blake3_sse41_x86-64_unix.S $UPSTREAM_C/blake3_avx2_x86-64_unix.S $UPSTREAM_C/blake3_avx512_x86-64_unix.S"

echo
echo "== upstream official C, amd64 asm =="
$CCACHE "$HOST_CC" -O3 -DNDEBUG -std=c11 -Wall -Wextra -I"$UPSTREAM_C" \
  -o "$BUILD_DIR/bench_blake3_upstream" \
  "$BENCH_SRC" $COMMON_SRCS $ASM_SRCS $HOST_LDFLAGS
"$BUILD_DIR/bench_blake3_upstream"

if pkg-config --exists tbb >/dev/null 2>&1; then
  echo
  echo "== upstream official C, amd64 asm + TBB =="
  TBB_FLAGS=$(pkg-config --cflags --libs tbb)
  TBB_OBJS=(
    "$BUILD_DIR/bench_blake3_upstream_tbb.o"
    "$BUILD_DIR/blake3_tbb.o"
    "$BUILD_DIR/blake3_tbb_blake3.o"
    "$BUILD_DIR/blake3_tbb_dispatch.o"
    "$BUILD_DIR/blake3_tbb_portable.o"
    "$BUILD_DIR/blake3_tbb_sse2.o"
    "$BUILD_DIR/blake3_tbb_sse41.o"
    "$BUILD_DIR/blake3_tbb_avx2.o"
    "$BUILD_DIR/blake3_tbb_avx512.o"
  )
  $CCACHE "$HOST_CC" -O3 -DNDEBUG -DBLAKE3_USE_TBB -std=c11 -Wall -Wextra -I"$UPSTREAM_C" -c "$BENCH_SRC" -o "${TBB_OBJS[0]}"
  $CCACHE "$HOST_CXX" -O3 -DNDEBUG -DBLAKE3_USE_TBB -std=c++17 -Wall -Wextra -fno-exceptions -fno-rtti -I"$UPSTREAM_C" -c "$UPSTREAM_C/blake3_tbb.cpp" -o "${TBB_OBJS[1]}"
  $CCACHE "$HOST_CC" -O3 -DNDEBUG -DBLAKE3_USE_TBB -std=c11 -Wall -Wextra -I"$UPSTREAM_C" -c "$UPSTREAM_C/blake3.c" -o "${TBB_OBJS[2]}"
  $CCACHE "$HOST_CC" -O3 -DNDEBUG -DBLAKE3_USE_TBB -std=c11 -Wall -Wextra -I"$UPSTREAM_C" -c "$UPSTREAM_C/blake3_dispatch.c" -o "${TBB_OBJS[3]}"
  $CCACHE "$HOST_CC" -O3 -DNDEBUG -DBLAKE3_USE_TBB -std=c11 -Wall -Wextra -I"$UPSTREAM_C" -c "$UPSTREAM_C/blake3_portable.c" -o "${TBB_OBJS[4]}"
  $CCACHE "$HOST_CC" -O3 -DNDEBUG -DBLAKE3_USE_TBB -c "$UPSTREAM_C/blake3_sse2_x86-64_unix.S" -o "${TBB_OBJS[5]}"
  $CCACHE "$HOST_CC" -O3 -DNDEBUG -DBLAKE3_USE_TBB -c "$UPSTREAM_C/blake3_sse41_x86-64_unix.S" -o "${TBB_OBJS[6]}"
  $CCACHE "$HOST_CC" -O3 -DNDEBUG -DBLAKE3_USE_TBB -c "$UPSTREAM_C/blake3_avx2_x86-64_unix.S" -o "${TBB_OBJS[7]}"
  $CCACHE "$HOST_CC" -O3 -DNDEBUG -DBLAKE3_USE_TBB -c "$UPSTREAM_C/blake3_avx512_x86-64_unix.S" -o "${TBB_OBJS[8]}"
  $CCACHE "$HOST_CXX" -O3 -DNDEBUG -o "$BUILD_DIR/bench_blake3_upstream_tbb" "${TBB_OBJS[@]}" $TBB_FLAGS $HOST_LDFLAGS
  "$BUILD_DIR/bench_blake3_upstream_tbb"
else
  echo
  echo "== upstream official C, TBB skipped: pkg-config could not find tbb =="
fi
