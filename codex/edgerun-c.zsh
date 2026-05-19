# Source this file from zsh to add the interactive Codex C convenience command.
#
# Example ~/.zshrc line:
#   source /path/to/repo/codex/edgerun-c.zsh
#
# Then prompt the graphical agent from any directory with:
#   c fix the failing ui-core render test
#   c --root /path/to/repo inspect the metal boot path
#
# Use `c term ...` for terminal prompt mode, `c repl` for the underlying REPL,
# or `c raw ...` to pass exact arguments through to the compiled binary.

typeset -g __EDGERUN_C_ZSH_PATH=${${(%):-%N}:A}

c() {
  emulate -L zsh
  setopt no_unset

  local script_path repo_root binary sdl_shell root prompt
  local -a prompt_words passthrough

  script_path=${__EDGERUN_C_ZSH_PATH}
  repo_root=${script_path:h:h}
  binary=${repo_root}/.build/codex
  sdl_shell=${repo_root}/.build/edgerun-ui-core-sdl/er_ui_sdl_shell
  root=${PWD}
  prompt_words=()
  passthrough=()

  case ${1:-} in
    --help|-h)
      print 'usage: c [--root PATH] [--] PROMPT WORDS...'
      print '       c term [--root PATH] [--] PROMPT WORDS...'
      print '       c repl [PATH]'
      print '       c raw [codex binary arguments...]'
      print ''
      print 'Prompts open the SDL Codex workspace and default to the current directory as root.'
      print 'The wrapper builds .build/codex and the SDL shell when missing or stale.'
      return 0
      ;;
    term)
      shift
      if [[ ! -x ${binary} || ${repo_root}/codex/src/edgerun_c_agent.c -nt ${binary} || ${repo_root}/codex/src/edgerun_c.c -nt ${binary} ]]; then
        command make -C ${repo_root}/codex || return $?
      fi
      if [[ ${1:-} == --root ]]; then
        if (( $# < 3 )); then
          print -u2 'c term: --root requires PATH and prompt text'
          return 2
        fi
        root=$2
        shift 2
      fi
      if [[ ${1:-} == -- ]]; then
        shift
      fi
      if (( $# == 0 )); then
        print -u2 'c term: prompt text is required'
        return 2
      fi
      prompt_words=( "$@" )
      prompt=${(j: :)prompt_words}
      command ${binary} --root ${root} --prompt ${prompt}
      return $?
      ;;
    repl)
      shift
      if [[ ! -x ${binary} || ${repo_root}/codex/src/edgerun_c_agent.c -nt ${binary} || ${repo_root}/codex/src/edgerun_c.c -nt ${binary} ]]; then
        command make -C ${repo_root}/codex || return $?
      fi
      if (( $# > 0 )); then
        root=$1
      fi
      command ${binary} --root ${root}
      return $?
      ;;
    raw)
      shift
      if [[ ! -x ${binary} || ${repo_root}/codex/src/edgerun_c_agent.c -nt ${binary} || ${repo_root}/codex/src/edgerun_c.c -nt ${binary} ]]; then
        command make -C ${repo_root}/codex || return $?
      fi
      passthrough=( "$@" )
      command ${binary} ${passthrough[@]}
      return $?
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

  if [[ ! -x ${binary} || ${repo_root}/codex/src/edgerun_c_agent.c -nt ${binary} || ${repo_root}/codex/src/edgerun_c.c -nt ${binary} ]]; then
    command make -C ${repo_root}/codex || return $?
  fi

  if [[ ! -x ${sdl_shell} || ${repo_root}/edgerun-ui-core/tools/er_ui_sdl_shell.c -nt ${sdl_shell} || ${repo_root}/edgerun-ui-core/CMakeLists.txt -nt ${sdl_shell} ]]; then
    command make -C ${repo_root} ui-core-sdl-build || return $?
  fi

  if (( $# == 0 )); then
    command ${sdl_shell} --root ${root}
    return $?
  fi

  if [[ ${1:-} == -- ]]; then
    shift
  fi

  if (( $# == 0 )); then
    print -u2 'c: prompt text is required'
    return 2
  fi

  prompt_words=( "$@" )
  prompt=${(j: :)prompt_words}
  command ${sdl_shell} --root ${root} --prompt ${prompt}
}
