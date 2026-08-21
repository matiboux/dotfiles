#!/bin/sh
set -eu

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

if [ -f "${HOME}/.gitconfig" ]; then
	timestamp="$(date +%Y%m%d%H%M%S)"
	backup_path="${HOME}/.gitconfig.bak.${timestamp}"
	backup_index=0
	while [ -e "$backup_path" ]; do
		backup_index=$((backup_index + 1))
		backup_path="${HOME}/.gitconfig.bak.${timestamp}.${backup_index}"
	done
	cp -p "${HOME}/.gitconfig" "$backup_path"
fi

install -m 600 "${script_dir}/.gitconfig" "${HOME}/.gitconfig"
install -m 600 "${script_dir}/.gitconfig.work" "${HOME}/.gitconfig.work"
