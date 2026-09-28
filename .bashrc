# ~/.bashrc

# Skip processing if not running interactively
case $- in
	*i*) ;;
	*) return ;;
esac

## ---
## Bash history

HISTCONTROL='ignoreboth'
HISTFILE="${HOME}/.bash_history"
HISTFILESIZE='2000'
HISTSIZE='1000'

# Append to the history file, don't overwrite it
shopt -s histappend

# Check the window size after each command
shopt -s checkwinsize

# Match all files and zero or more directories and subdirectories
#shopt -s globstar

## ---
## Update PATH for custom binaries

if [ -d "${HOME}/bin" ] ; then
	export PATH="${HOME}/bin:${PATH}"
fi

if [ -d "${HOME}/.local/bin" ] ; then
	export PATH="${HOME}/.local/bin:${PATH}"
fi

export LANG='en_US.UTF-8'

# export EDITOR='vim'
# export EDITOR='emacs'

## ---
## Custom Prompt Strings

prompt_git_status() {
	prompt_git_branch=''
	prompt_git_unstaged=0
	prompt_git_staged=0
	prompt_git_ahead=0
	local git_status line record_kind xy_status remainder ahead behind index_status worktree_status

	if git_status="$(git status --porcelain=v2 --branch 2> /dev/null)"; then
		while IFS= read -r line; do
			case "${line}" in
				'# branch.head '*)
					prompt_git_branch="${line#'# branch.head '}"
					[ "${prompt_git_branch}" = '(detached)' ] && prompt_git_branch='HEAD'
					;;
				'# branch.ab '*)
					read -r record_kind remainder ahead behind <<< "${line}"
					ahead="${ahead#+}"
					if [ "${ahead}" -gt 0 ] 2> /dev/null; then
						prompt_git_ahead=1
					fi
					;;
				'1 '*|'2 '*|'u '*)
					read -r record_kind xy_status remainder <<< "${line}"
					index_status="${xy_status%?}"
					worktree_status="${xy_status#?}"
					[ "${index_status}" = '.' ] || prompt_git_staged=1
					[ "${worktree_status}" = '.' ] || prompt_git_unstaged=1
					;;
				'? '*)
					prompt_git_unstaged=1
					;;
			esac
		done <<< "${git_status}"
	fi
}

ps1_generator() {
	prompt_git_status

	PS1='${debian_chroot:+($debian_chroot) }'
	PS1+='\[\e[1;30m\][ '

	# User
	# PS1+='\[\e[1;36m\]\u\[\e[1;30m\]@\[\e[1;30m\]\h '
	PS1+='\[\e[1;36m\]\u '

	# Time
	PS1+='\[\e[0;90m\]\t '

	# Directory
	PS1+='\[\e[1;33m\]\W '

	if [ -n "${prompt_git_branch}" ]; then
		PS1+="\[\e[1;31m\](${prompt_git_branch}"
		if [ "${prompt_git_unstaged}" -eq 1 ]; then
			PS1+='\[\e[1;33m\]*'
		fi
		if [ "${prompt_git_staged}" -eq 1 ]; then
			PS1+='\[\e[1;32m\]+'
		fi
		if [ "${prompt_git_ahead}" -eq 1 ]; then
			PS1+='\[\e[1;33m\]^'
		fi
		PS1+='\[\e[1;31m\])'
	fi

	# ]$
	PS1+='\[\e[1;30m\] ]\$ \[\e[m\]'
}
PROMPT_COMMAND='ps1_generator'

## ---
## Color support

# Enable color support of ls
# Add handy aliases
if [ -x /usr/bin/dircolors ]; then
	test -r "${HOME}/.dircolors" && eval "$(dircolors -b "${HOME}/.dircolors")" || eval "$(dircolors -b)"
	alias ls='ls --color=auto'
	alias dir='dir --color=auto'
	alias vdir='vdir --color=auto'

	alias grep='grep --color=auto'
	alias fgrep='fgrep --color=auto'
	alias egrep='egrep --color=auto'
fi

# Custom ls colors
export LS_COLORS="${LS_COLORS}:di=0;95:ex=0;92"

## ---
## Alias definitions

# Import aliases from .bash_aliases
if [ -f "${HOME}/.bash_aliases" ]; then
	. "${HOME}/.bash_aliases"
fi

# Enable programmable completion features
if ! shopt -oq posix; then
	if [ -f /usr/share/bash-completion/bash_completion ]; then
		. /usr/share/bash-completion/bash_completion
	elif [ -f /etc/bash_completion ]; then
		. /etc/bash_completion
	fi
fi
