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

install_dotfile() {
	name="$1"
	backup_if_different "${HOME}/${name}" "${script_dir}/${name}"
	install -m 600 "${script_dir}/${name}" "${HOME}/${name}"
}

install_dotfile .gitconfig
install_dotfile .gitconfig.work

# Shell config depends on the OS
case "$(uname -s)" in
	Darwin)
		install_dotfile .zshrc
		install_dotfile .zprofile
		;;
	*)
		install_dotfile .bashrc
		;;
esac
