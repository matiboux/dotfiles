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

autoload -Uz compinit
compinit

# Docker CLI completions
if [ -d "${HOME}/.docker/completions" ]; then
	fpath=("${HOME}/.docker/completions" "${fpath[@]}")
fi

## ---
## Custom prompt

setopt PROMPT_SUBST
autoload -Uz vcs_info
zstyle ':vcs_info:git:*' formats '(%b)%c%u'
zstyle ':vcs_info:*' check-for-changes true
zstyle ':vcs_info:*' unstagedstr '%F{yellow}+'
zstyle ':vcs_info:*' stagedstr '%F{green}+'

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
