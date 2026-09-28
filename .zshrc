# ~/.zshrc

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

precmd() {
	prompt_git_status
	prompt_git_info=''
	if [ -n "${prompt_git_branch}" ]; then
		prompt_git_info="%F{red}(${prompt_git_branch}"
		if [ "${prompt_git_unstaged}" -eq 1 ]; then
			prompt_git_info+='%F{yellow}*'
		fi
		if [ "${prompt_git_staged}" -eq 1 ]; then
			prompt_git_info+='%F{green}+'
		fi
		if [ "${prompt_git_ahead}" -eq 1 ]; then
			prompt_git_info+='%F{yellow}^'
		fi
		prompt_git_info+='%F{red})'
	fi
}

# [ user time dir (branch+) ]$
PROMPT='%F{black}[ %F{cyan}%n %F{8}%* %F{yellow}%1~ ${prompt_git_info}${prompt_git_info:+ }%F{black}]%(!.#.$) %f'

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
