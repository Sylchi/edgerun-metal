#!/usr/bin/env zsh
# Analyze x86_64 assembly project for dead code and duplication.
# Usage: ./scripts/asm-analyze.sh [--dead] [--dup] [--all]
#   --dead    Find unused global symbols and internal labels
#   --dup     Find duplicated instruction blocks and %defines
#   --all     Run all checks (default)

set -euo pipefail
cd "$(dirname "$0")/.."

ASM_DIR="asm/x86_64"
TEST_DIR="asm/test"
INC_DIR="asm"

bold()   { printf '\033[1m%s\033[0m\n' "$1"; }
red()    { printf '\033[31m%s\033[0m\n' "$1"; }
green()  { printf '\033[32m%s\033[0m\n' "$1"; }
yellow() { printf '\033[33m%s\033[0m\n' "$1"; }

# ─── 1. Dead Code Analysis ──────────────────────────────────
find_dead_code() {
  local rc=0
  bold "═══ Dead Code Analysis ═══"

  # Collect all global symbols from production files
  typeset -A production_globals
  typeset -A global_file
  for f in "$ASM_DIR"/*.asm "$INC_DIR"/macros.inc(N); do
    [[ -f "$f" ]] || continue
    while IFS=':' read -r line rest; do
      local name="${rest##* }"
      [[ -z "$name" ]] && continue
      [[ "$name" =~ [[:space:]] ]] && continue
      production_globals[$name]=1
      global_file[$name]="$f:$line"
    done < <(grep -n '^[[:space:]]*global[[:space:]]' "$f" 2>/dev/null || true)
  done

  # Collect all externs from test files + kernel_main
  typeset -A used_externs
  for f in "$TEST_DIR"/*.asm "$ASM_DIR"/kernel_main.asm(N); do
    [[ -f "$f" ]] || continue
    while IFS=':' read -r line rest; do
      local name="${rest##* }"
      [[ -z "$name" ]] && continue
      used_externs[$name]=1
    done < <(grep -n '^[[:space:]]*extern[[:space:]]' "$f" 2>/dev/null || true)
  done

  # Collect call/jmp references to global names across ALL asm files
  typeset -A called_globals
  for f in "$ASM_DIR"/*.asm "$TEST_DIR"/*.asm "$INC_DIR"/macros.inc(N); do
    [[ -f "$f" ]] || continue
    while IFS= read -r line; do
      for name in "${(k)production_globals}"; do
        if grep -qE '(^|[^a-zA-Z_])'"$name"'([^a-zA-Z_0-9]|$)' <<< "$line" 2>/dev/null; then
          called_globals[$name]=1
        fi
      done
    done < <(grep -E '(call|jmp|j[abglenopsz][a-z]*)[[:space:]]+[a-zA-Z_]' "$f" 2>/dev/null || true)
  done

  local found_unused=0
  for name in "${(k)production_globals}"; do
    if [[ -z "${used_externs[$name]-}" && -z "${called_globals[$name]-}" ]]; then
      if [[ "$name" != _* ]]; then
        yellow "  UNUSED GLOBAL: ${global_file[$name]}  ($name)"
        found_unused=1
        rc=1
      fi
    fi
  done
  [[ $found_unused -eq 0 ]] && green "  No unreferenced globals found"

  # Check for production .asm files not listed in Makefile ASM_OBJS
  local asm_objs
  asm_objs=$(grep -oP '(?<=\.build/asm/)\w+(?=\.o)' Makefile 2>/dev/null | sort -u)
  for f in "$ASM_DIR"/*.asm(N); do
    local base="${f##*/}"
    local name="${base%.asm}"
    [[ "$name" == kernel_main ]] && continue
    if ! grep -q "$name" <<< "$asm_objs" 2>/dev/null; then
      yellow "  UNUSED ASM FILE (no Makefile rule): $f"
      rc=1
    fi
  done

  return $rc
}

# ─── 2. Duplicate Code Detection ────────────────────────────
find_duplicates() {
  local rc=0
  bold "═══ Duplicate Code Analysis ═══"

  local tmpdir
  tmpdir=$(mktemp -d)
  trap "rm -rf '$tmpdir'" EXIT

  # Strip instruction files to opcode mnemonics only
  for f in "$ASM_DIR"/*.asm(N); do
    [[ -f "$f" ]] || continue
    local base="${f##*/}"
    perl -ne '
      next if /^\s*;/;
      next if /^\s*[a-zA-Z_.][a-zA-Z0-9_.]*:/;
      next if /^\s*%/;
      next if /^\s*global\s/;
      next if /^\s*extern\s/;
      next if /^\s*section\s/;
      s/;.*//;
      s/#.*//;
      s/^\s+//;
      s/\s.*$//;
      next unless length > 0;
      next if /^[.a-zA-Z]/ || /^[0-9]+:$/;
      print "$_\n";
    ' "$f" > "$tmpdir/${base}.ops"
  done

  # Look for repeated 5+ opcode sequences across file pairs
  local files=($ASM_DIR/*.asm(N))
  for ((i=0; i<${#files}; i++)); do
    local f1="${files[$((i+1))]}"
    local b1="${f1##*/}"
    local ops1="$tmpdir/${b1}.ops"
    [[ -s "$ops1" ]] || continue

    for ((j=i+1; j<${#files}; j++)); do
      local f2="${files[$((j+1))]}"
      local b2="${f2##*/}"
      local ops2="$tmpdir/${b2}.ops"
      [[ -s "$ops2" ]] || continue

      # Join opcodes with newline and find common substrings of length >= 5
      local seqlen=$(perl -e '
        open(A, "<'"$ops1"'") or die; my @a = map { chomp; $_ } <A>; close A;
        open(B, "<'"$ops2"'") or die; my @b = map { chomp; $_ } <B>; close B;
        my $max = 0; my $cur = 0;
        my (%seen_a, %seen_b);
        for (@a) { $seen_a{$_}++ }
        for (@b) { 
          if ($seen_a{$_}) { $cur++; $max = $cur if $cur > $max }
          else { $cur = 0 }
        }
        print $max;
      ' 2>/dev/null || echo 0)
      if [[ $seqlen -ge 5 ]]; then
        yellow "  DUPLICATE BLOCK ($b1 ↔ $b2): ${seqlen} consecutive same opcodes"
        rc=1
      fi
    done
  done

  # Check for duplicated %define constants across files
  bold "  ── Duplicated %%defines ──"
  typeset -A define_defs
  for f in "$ASM_DIR"/*.asm "$INC_DIR"/macros.inc(N); do
    [[ -f "$f" ]] || continue
    while IFS=':' read -r line rest; do
      local defline="${rest#%define }"
      defline="${defline%%;*}"
      # Extract just the constant name
      defline="${defline%%[[:space:]]*}"
      [[ -z "$defline" ]] && continue
      if [[ "$defline" != *'?'* ]]; then
        if [[ -n "${define_defs[$defline]-}" ]]; then
          local prev="${define_defs[$defline]}"
          yellow "  DUPLICATE '${defline}': $f:$line  (also in $prev)"
          rc=1
        else
          define_defs[$defline]="$f:$line"
        fi
      fi
    done < <(grep -n '^[[:space:]]*%define[[:space:]]' "$f" 2>/dev/null || true)
  done
  green "  Total unique %%defines: ${#define_defs}"

  # Unused %defines
  bold "  ── Unused %%defines ──"
  local unused=0
  for name in "${(k)define_defs}"; do
    local loc="${define_defs[$name]}"
    local used=0
    for sf in "$ASM_DIR"/*.asm "$TEST_DIR"/*.asm "$INC_DIR"/macros.inc(N); do
      [[ -f "$sf" ]] || continue
      local cnt=$(grep -c "\b${name}\b" "$sf" 2>/dev/null || echo 0)
      used=$((used + cnt))
    done
    # used=1 means only the definition line itself
    if [[ $used -le 1 ]]; then
      yellow "  UNUSED: ${loc}  ($name)"
      unused=1
    fi
  done
  [[ $unused -eq 0 ]] && green "  All %%defines are referenced"

  # Check for %define that shadows another (same name, diff value)
  bold "  ── Shadowed/Conflicting %%defines ──"
  typeset -A define_values
  for f in "$ASM_DIR"/*.asm "$INC_DIR"/macros.inc(N); do
    [[ -f "$f" ]] || continue
    while IFS=':' read -r line rest; do
      local rest_trimmed="${rest#%define }"
      local name="${rest_trimmed%%[[:space:]]*}"
      local value="${rest_trimmed#$name}"
      value="${value##[[:space:]]}"
      value="${value%%;*}"
      if [[ -n "${define_values[$name]-}" ]]; then
        local prev_val="${define_values[$name]}"
        if [[ "$prev_val" != "$value" ]]; then
          yellow "  CONFLICT: '${name}' = \"${value}\" at $f:$line"
          yellow "         was \"${prev_val}\" from earlier include"
          rc=1
        fi
      else
        define_values[$name]="$value"
      fi
    done < <(grep -n '^[[:space:]]*%define[[:space:]]' "$f" 2>/dev/null || true)
  done

  return $rc
}

# ─── Main ────────────────────────────────────────────────────
mode="${1:---all}"
case "$mode" in
  --dead) find_dead_code ;;
  --dup)  find_duplicates ;;
  --all|*)
    find_dead_code || true
    find_duplicates || true
    ;;
esac
