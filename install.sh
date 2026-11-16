#!/bin/sh
set -eu

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
os="$(uname -s)"

# Copy the current $1 to a unique timestamped .bak if it differs from $2.
backup_if_different() {
	target="$1"
	new_file="$2"
	if [ -f "${target}" ] && ! cmp -s "${target}" "${new_file}"; then
		timestamp="$(date +%Y%m%d%H%M%S)"
		backup="${target}.bak.${timestamp}"
		index=0
		while [ -e "${backup}" ]; do
			index=$((index + 1))
			backup="${target}.bak.${timestamp}.${index}"
		done
		cp -p "${target}" "${backup}"
	fi
}

# home/.* -> $HOME, skipping the other OS's shell config.
install_dotfiles() {
	for src in "${script_dir}"/home/.[!.]*; do
		name="${src##*/}"
		case "${name}" in
			.zshrc|.zprofile) [ "${os}" = Darwin ] || continue ;;
			.bashrc) [ "${os}" != Darwin ] || continue ;;
		esac
		backup_if_different "${HOME}/${name}" "${src}"
		install -m 600 "${src}" "${HOME}/${name}"
	done
}

# bin/* -> ~/.local/bin
install_binaries() {
	bin_dir="${HOME}/.local/bin"
	mkdir -p "${bin_dir}"
	for src in "${script_dir}"/bin/*; do
		name="${src##*/}"
		backup_if_different "${bin_dir}/${name}" "${src}"
		install -m 755 "${src}" "${bin_dir}/${name}"
	done
}

# Devcontainers only: Machine settings override the synced user settings,
# so the host keeps its own values. Copy, or merge with jq (repo keys win).
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
		merged="$(mktemp)"
		if jq -s '.[0] + .[1]' "${settings_file}" "${source_file}" > "${merged}" 2>/dev/null; then
			cat "${merged}" > "${settings_file}"
		else
			echo "warning: could not merge ${settings_file} (not plain JSON?)" >&2
		fi
		rm -f "${merged}"
	else
		echo "warning: ${settings_file} exists and jq is missing, skipped" >&2
	fi
}

install_dotfiles
install_binaries
install_vscode_container_settings
