# ~/.zshrc
# Interactive shell setup for macOS (zsh)

## ---
## Zsh history

HISTFILE="${HOME}/.zsh_history"
HISTSIZE='1000'
SAVEHIST='2000'

setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt APPEND_HISTORY

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

## ---
## Completion

# Docker CLI completions
# The following lines have been added by Docker Desktop to enable Docker CLI completions.
if [ -d "${HOME}/.docker/completions" ]; then
	fpath=("${HOME}/.docker/completions" "${fpath[@]}")
fi
# End of Docker CLI completions

autoload -Uz compinit
compinit

## ---
## Custom prompt

setopt PROMPT_SUBST
autoload -Uz vcs_info
zstyle ':vcs_info:git:*' formats '(%b)%u%c%m'
zstyle ':vcs_info:*' check-for-changes true
zstyle ':vcs_info:*' unstagedstr '%F{yellow}*'
zstyle ':vcs_info:*' stagedstr '%F{green}+'

zstyle ':vcs_info:git*+set-message:*' hooks git-untracked git-unpushed

# Also treat untracked files as unstaged changes, like VS Code does
+vi-git-untracked() {
	if [ -n "$(git status --porcelain 2> /dev/null | grep -m 1 '^??')" ]; then
		hook_com[unstaged]='%F{yellow}*'
	fi
}

# Flag unpushed commits (branches with commits not on any remote)
+vi-git-unpushed() {
	if [ -n "$(git log --branches --not --remotes 2> /dev/null)" ]; then
		hook_com[misc]='%F{yellow}^'
	fi
}

precmd() {
	vcs_info
}

# [ user time dir (branch+) ]$
PROMPT='%F{black}[ %F{cyan}%n %F{yellow}%* %F{yellow}%1~ %F{red}${vcs_info_msg_0_}%F{black}]%(!.#.$) %f'

## ---
## Color support

export CLICOLOR='1'
export LSCOLORS='GxFxCxDxBxegedabagaced'

alias ls='ls -G'
alias grep='grep --color=auto'

## ---
## Alias definitions

# Import aliases from .zsh_aliases
if [ -f "${HOME}/.zsh_aliases" ]; then
	. "${HOME}/.zsh_aliases"
fi
