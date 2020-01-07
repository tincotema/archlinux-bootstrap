#
# /etc/bash.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

[[ $DISPLAY ]] && shopt -s checkwinsize

PS1='[\u@\h \W]\$ '

case ${TERM} in
  xterm*|rxvt*|Eterm|aterm|kterm|gnome*)
    PROMPT_COMMAND=${PROMPT_COMMAND:+$PROMPT_COMMAND; }'printf "\033]0;%s@%s:%s\007" "${USER}" "${HOSTNAME%%.*}" "${PWD/#$HOME/\~}"'

    ;;
  screen*)
    PROMPT_COMMAND=${PROMPT_COMMAND:+$PROMPT_COMMAND; }'printf "\033_%s@%s:%s\033\\" "${USER}" "${HOSTNAME%%.*}" "${PWD/#$HOME/\~}"'
    ;;
esac

[ -r /usr/share/bash-completion/bash_completion   ] && . /usr/share/bash-completion/bash_completion

# Preprocess PS1 as much as possible
_genthree_preprocess_ps()
{
	# Start with empty PS1
	unset PS1
	unset _genthree_PS1

	# Change the window title of X terminals
	case ${TERM} in
		[aEkx]term*|rxvt*|gnome*|konsole*|interix)
			_genthree_PS1+='\[]0;\u@\h:\w\007\]' ;;
		screen*)
			_genthree_PS1+='\[k\u@\h:\w\\\]' ;;
	esac

	# Define colors
	if ${use_color}; then
		_genthree_color_reset='\[[m\]'

		if [[ ${EUID} == 0 ]]; then
			local _genthree_color_user='\[[0;31m\]'
			local _genthree_color_host='\[[1;31m\]'
		else
			local _genthree_color_user='\[[0;36m\]'
			local _genthree_color_host='\[[1;36m\]'
		fi

		_genthree_color_ssh='\[[1;32m\]'
		_genthree_color_pwd='\[[1;34m\]'
		_genthree_color_git='\[[35m\]'
		_genthree_color_sign='\[[m\]'
	fi

	_genthree_PS1+="${_genthree_color_user}"'\u'"${_genthree_color_host}"'@\h '
}

# Execute function then unset it
_genthree_preprocess_ps
unset -f _genthree_preprocess_ps


# Function to set PS1
_genthree_set_ps()
{
	PS1="${_genthree_PS1}"

	if [[ -n ${SSH_CONNECTION} ]]; then
		PS1+="${_genthree_color_ssh}"'ssh '
	fi

	PS1+="${_genthree_color_pwd}"'\w '

	local branch ahead_count
	if branch="$(command git symbolic-ref --short HEAD 2>/dev/null || command git rev-parse --short HEAD 2>/dev/null)"; then
		if ahead_count="$(command git rev-list --count "origin/${branch}..${branch}" 2>/dev/null)" && [[ ${ahead_count} -gt 0 ]]; then
			ahead_count="+${ahead_count} "
		else
			ahead_count=""
		fi

		PS1+="${_genthree_color_git}"'\[[22m\]|\[[1m\]'" ${branch} "'\[[22m\]'"${ahead_count}"
	fi

	PS1+="${_genthree_color_sign}"'\$ '"${_genthree_color_reset}"
}

# Set PS1 once at startup (else it would be unset and e.g. bash_completion would think the bash is not interactive)
export -f _genthree_set_ps
_genthree_set_ps


# environment
export MAKEFLAGS="-j$(($(nproc || echo 2) + 1))"
export PROMPT_COMMAND='_genthree_set_ps; history -a'


# history
export HISTCONTROL="ignoredups:ignorespace"
export HISTIGNORE='?:??: *:rm *:rmd *:git fixup*:git stash?*:git checkout -f*'

export HISTFILESIZE=""
export HISTSIZE=""


# aliases
alias ls="ls -aF --group-directories-first --show-control-chars --quoting-style=escape --color=auto"
alias l="ls -laF --group-directories-first --show-control-chars --quoting-style=escape --color=auto"
alias t="tree -C -F --dirsfirst -L 2"
alias tt="tree -C -F --dirsfirst -L 3 --filelimit 16"
alias ttt="tree -C -F --dirsfirst -L 6 --filelimit 16"
alias md="mkdir"
alias rmd="rm -d"
mcd() { mkdir "$@" && cd "$_"; }
export -f mcd

alias cp="cp -vi"
alias mv="mv -vi"
alias rm="rm -vI"
alias chmod="chmod -vc"
alias chown="chown -vc"

alias T="tmux attach-session -t share1 || tmux new-session -s share1"
alias TT="tmux attach-session -t share2 || tmux new-session -s share2"

alias vim="nvim"
# aliases when X is running
# if xset q &>/dev/null ; then
# fi
