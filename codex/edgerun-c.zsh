# Source this file from zsh to add the interactive Codex C convenience command.
#
# Example ~/.zshrc line:
#   source /path/to/repo/codex/edgerun-c.zsh
#
# Then prompt the agent from any directory with:
#   c fix the failing ui-core render test
#   c --root /path/to/repo inspect the metal boot path
#
# Use `c repl` for the underlying REPL, or `c raw ...` to pass exact arguments
# through to the compiled binary.

c() {
  emulate -L zsh
  setopt no_unset

  local script_path repo_root binary root prompt
  local -a prompt_words passthrough

  script_path=${${(%):-%N}:A}
  repo_root=${script_path:h:h}
  binary=${repo_root}/.build/codex
  root=${PWD}
  prompt_words=()
  passthrough=()

  if [[ ! -x ${binary} || ${repo_root}/codex/src/edgerun_c_agent.c -nt ${binary} || ${repo_root}/codex/src/edgerun_c.c -nt ${binary} ]]; then
    command make -C ${repo_root}/codex || return $?
  fi

  if (( $# == 0 )); then
    command ${binary} --root ${root}
    return $?
  fi

  case $1 in
    repl)
      shift
      if (( $# > 0 )); then
        root=$1
      fi
      command ${binary} --root ${root}
      return $?
      ;;
    raw)
      shift
      passthrough=( "$@" )
      command ${binary} ${passthrough[@]}
      return $?
      ;;
    --help|-h)
      print 'usage: c [--root PATH] [--] PROMPT WORDS...'
      print '       c repl [PATH]'
      print '       c raw [codex binary arguments...]'
      print ''
      print 'Prompts default to the current directory as the repository root.'
      print 'The wrapper builds .build/codex when the binary is missing or stale.'
      return 0
      ;;
    --root)
      if (( $# < 3 )); then
        print -u2 'c: --root requires PATH and prompt text'
        return 2
      fi
      root=$2
      shift 2
      ;;
  esac

  if [[ ${1:-} == -- ]]; then
    shift
  fi

  if (( $# == 0 )); then
    print -u2 'c: prompt text is required'
    return 2
  fi

  prompt_words=( "$@" )
  prompt=${(j: :)prompt_words}
  command ${binary} --root ${root} --prompt ${prompt}
}
