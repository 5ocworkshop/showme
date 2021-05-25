#/usr/bin/env bash
_showme() {
local cur prev

  COMPREPLY=()
  cur=${COMP_WORDS[COMP_CWORD]}
  prev=${COMP_WORDS[COMP_CWORD-1]}

  if [ $COMP_CWORD -eq 1 ]; then
    COMPREPLY=( $(compgen -W "$(showme options)" -- $cur) )
  elif [ $COMP_CWORD -eq 2 ]; then
    case "$prev" in
      "ini")
        COMPREPLY=( $(compgen -W "$(showme options-ini)" -- $cur) )
        ;;
      "deploy")
        COMPREPLY=( $(compgen -W "all current" -- $cur) )
        ;;
      *)
        ;;
    esac
  fi

  return 0
} &&
complete -F _showme showme

