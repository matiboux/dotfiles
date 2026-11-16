#!/bin/sh
set -eu

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

backup_if_different() {
	src_path="$1"
	new_path="$2"
	if [ -f "${src_path}" ] && ! cmp -s "${src_path}" "${new_path}"; then
		timestamp="$(date +%Y%m%d%H%M%S)"
		backup_path="${src_path}.bak.${timestamp}"
		backup_index=0
		while [ -e "${backup_path}" ]; do
			backup_index=$((backup_index + 1))
			backup_path="${src_path}.bak.${timestamp}.${backup_index}"
		done
		cp -p "${src_path}" "${backup_path}"
	fi
}

# Install every file of home/ into $HOME, except the other OS's shell config
install_dotfiles() {
	for dotfile_path in "${script_dir}"/home/.[!.]*; do
		name="${dotfile_path##*/}"
		case "${name}" in
			.zshrc|.zprofile) [ "$(uname -s)" = Darwin ] || continue ;;
			.bashrc) [ "$(uname -s)" != Darwin ] || continue ;;
		esac
		backup_if_different "${HOME}/${name}" "${dotfile_path}"
		install -m 600 "${dotfile_path}" "${HOME}/${name}"
	done
}

install_binaries() {
	bin_dir="${HOME}/.local/bin"
	mkdir -p "${bin_dir}"
	for binary_path in "${script_dir}"/bin/*; do
		name="${binary_path##*/}"
		backup_if_different "${bin_dir}/${name}" "${binary_path}"
		install -m 755 "${binary_path}" "${bin_dir}/${name}"
	done
}

# Devcontainers only: VS Code remote Machine settings override the (synced)
# user settings, so the host keeps its own values.
# Source: vscode/machine-settings.json, copied or merged (repo keys win).
install_vscode_container_settings() {
	if [ ! -f /.dockerenv ] && [ -z "${REMOTE_CONTAINERS:-}" ]; then
		return 0
	fi
	source_file="${script_dir}/vscode/machine-settings.json"
	[ -f "${source_file}" ] || return 0
	settings_dir="${HOME}/.vscode-server/data/Machine"
	settings_file="${settings_dir}/settings.json"
	mkdir -p "${settings_dir}"
	if [ ! -s "${settings_file}" ]; then
		cp "${source_file}" "${settings_file}"
	elif command -v jq >/dev/null 2>&1; then
		settings_tmp="$(mktemp)"
		if jq -s '.[0] + .[1]' "${settings_file}" "${source_file}" > "${settings_tmp}" 2>/dev/null; then
			cat "${settings_tmp}" > "${settings_file}"
		else
			echo "warning: could not merge ${settings_file} (not plain JSON?)" >&2
		fi
		rm -f "${settings_tmp}"
	else
		echo "warning: ${settings_file} exists and jq is missing, skipped" >&2
	fi
}

install_dotfiles
install_binaries
install_vscode_container_settings
