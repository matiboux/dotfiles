# ~/.bashrc

# If not running interactively, don't do anything
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

ps1_generator() {

	PS1='${debian_chroot:+($debian_chroot) }'
	PS1+='\[\e[1;30m\][ '

	# User
	# PS1+='\[\e[1;36m\]\u\[\e[1;30m\]@\[\e[1;30m\]\h '
	PS1+='\[\e[1;36m\]\u '

	# Time
	PS1+='\[\e[0;90m\]\t '

	# Directory
	PS1+='\[\e[1;33m\]\W '

	if [ -d .git ] || git rev-parse --abbrev-ref HEAD > /dev/null 2>&1; then

		# Append git current branch
		branch_name=$(git symbolic-ref -q HEAD)
		branch_name=${branch_name##refs/heads/}
		branch_name=${branch_name:-HEAD}
		PS1+="\[\e[1;31m\](${branch_name}\[\e[1;31m\])"

		# Append git status information
		gitstatusshort=$(git status -s)
		if [ -n "${gitstatusshort}" ]; then
			# Unstaged changes, including untracked files
			if echo "${gitstatusshort}" | grep -qE '^\?\?|^.[MD]'; then
				PS1+='\[\e[1;33m\]*'
			fi
			# Staged changes
			if echo "${gitstatusshort}" | grep -q '^[MARCD]'; then
				PS1+='\[\e[1;32m\]+'
			fi
		fi
		if [ -n "$(git log --branches --not --remotes)" ]; then
			# Unsynced branches (unpushed commits)
			PS1+='\[\e[1;33m\]^'
		fi

		# Trailing space
		PS1+=' '
	fi

	# ]$
	PS1+='\[\e[1;30m\]]\$ \[\e[m\]'
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
