# ~/.bashrc

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# ---
# Bash history

HISTCONTROL=ignoreboth
HISTFILE=~/.bash_history
HISTFILESIZE=2000
HISTSIZE=1000

# Append to the history file, don't overwrite it
shopt -s histappend

# Check the window size after each command
shopt -s checkwinsize

# Match all files and zero or more directories and subdirectories
#shopt -s globstar

# ---
# Update PATH for custom binaries

if [ -d ~/bin ] ; then
	export PATH='~/bin:'$PATH
fi

if [ -d ~/afs/bin ] ; then
	export PATH='~/afs/bin:'$PATH
fi

if [ -d ~/.local/bin ] ; then
	export PATH='~/.local/bin:'$PATH
fi

export LANG=en_US.utf8
export NNTPSERVER="news.epita.fr"

# export EDITOR=vim
# export EDITOR=emacs

# ---
# Custom Prompt Strings

PS0=''
ps1_generator() {

	PS1='${debian_chroot:+($debian_chroot) }'
	PS1+='\[\e[1;30m\][ '
	
	# User
	# PS1+='\[\e[1;36m\]\u\[\e[1;30m\]@\[\e[1;30m\]\h '
	PS1+='\[\e[1;36m\]\u '
	
	# Time
	PS1+='\[\e[0;33m\]\t '
	
	# Directory
	PS1+='\[\e[1;33m\]\W '

	if [[ -d .git || $(git rev-parse --abbrev-ref HEAD 2> /dev/null) ]]; then
	
		# Append git current branch
		branch_name=$(git symbolic-ref -q HEAD)
		branch_name=${branch_name##refs/heads/}
		branch_name=${branch_name:-HEAD}
		PS1+='\[\e[1;31m\]('$branch_name'\[\e[1;31m\])'

		# Append git status information
		gitstatusshort=$(git status -s)
		if [[ $gitstatusshort ]]; then
			if [[ $(echo "$gitstatusshort" | grep '^[MARCD]') ]]; then
				PS1+='\[\e[1;32m\]'
			else
				PS1+='\[\e[1;33m\]'
			fi
			# Modified files
			PS1+='+'
		fi
		if [[ $(git log --branches --not --remotes) ]]; then
			# Unsynced branches
			PS1+='\[\e[1;33m\]*'
		fi

		# Trailing space
		PS1+=' '
	fi
	
	# ]$
	PS1+='\[\e[1;30m\]]\$ \[\e[m\]'
}
PROMPT_COMMAND=ps1_generator

# ---
# Color support

# Enable color support of ls
# Add handy aliases
if [ -x /usr/bin/dircolors ]; then
	test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
	alias ls='ls --color=auto'
	alias dir='dir --color=auto'
	alias vdir='vdir --color=auto'

	alias grep='grep --color=auto'
	alias fgrep='fgrep --color=auto'
	alias egrep='egrep --color=auto'
fi

# Color support for less
# export LESS_TERMCAP_mb=$'\E[01;31m'       # begin blinking
# export LESS_TERMCAP_md=$'\E[01;38;5;74m'  # begin bold
# export LESS_TERMCAP_me=$'\E[0m'           # end mode
# export LESS_TERMCAP_se=$'\E[0m'           # end standout-mode
# export LESS_TERMCAP_so=$'\E[38;5;246m'    # begin standout-mode - info box
# export LESS_TERMCAP_ue=$'\E[0m'           # end underline
# export LESS_TERMCAP_us=$'\E[04;38;5;146m' # begin underline

# Custom ls colors
export LS_COLORS=$LS_COLORS:'di=0;95:ex=0;92'

# ---
# Alias definitions

# Git alias for managing dotfiles
alias dotfiles='/usr/bin/git --git-dir="'$HOME'/.dotfiles/" --work-tree="'$HOME'"'
alias gitdf='dotfiles'

# Import aliases from .bash_aliases
if [ -f ~/.bash_aliases ]; then
	. ~/.bash_aliases
fi

# Enable programmable completion features
if ! shopt -oq posix; then
	if [ -f /usr/share/bash-completion/bash_completion ]; then
		. /usr/share/bash-completion/bash_completion
	elif [ -f /etc/bash_completion ]; then
		. /etc/bash_completion
	fi
fi

export PGDATA="$HOME/postgres_data"
export PGHOST="/tmp"
