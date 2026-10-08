#!/bin/sh
# Pull the latest changes of the dotfiles git repo and reinstall the dotfiles.
#
# Usage: update.sh [-h|--help]
#
# The repo is updated with a fast-forward only pull, then its install.sh script
# is run. The repo must have a clean working directory.
#
# Options:
# - -h, --help: show usage.
#
# Environment:
# - DOTFILES_DIR: directory of the dotfiles git repo.
#   (default: directory of this script, once symlinks are resolved)
set -eu

# Resolve symlinks (the installed script is a symlink to the repo script)
script_path="$0"
while [ -L "${script_path}" ]; do
	link_target="$(readlink "${script_path}")"
	case "${link_target}" in
		/*) script_path="${link_target}" ;;
		*) script_path="$(dirname -- "${script_path}")/${link_target}" ;;
	esac
done

DOTFILES_DIR="${DOTFILES_DIR:-$(CDPATH= cd -- "$(dirname -- "${script_path}")" && pwd)}"

usage() {
	echo "Usage: ${0##*/} [-h|--help]"
}

while [ "$#" -gt 0 ]; do
	case "$1" in
		-h|--help)
			usage
			exit 0
			;;
		*)
			usage >&2
			exit 1
			;;
	esac
done

if ! git -C "${DOTFILES_DIR}" rev-parse --git-dir >/dev/null 2>&1; then
	echo "❌ Not a git repository: ${DOTFILES_DIR}" >&2
	exit 2
fi

if [ ! -f "${DOTFILES_DIR}/install.sh" ]; then
	echo "❌ Install script not found: ${DOTFILES_DIR}/install.sh" >&2
	exit 2
fi

if [ -n "$(git -C "${DOTFILES_DIR}" status --porcelain)" ]; then
	echo '❌ Working directory is not clean. Please commit or stash your changes before running this script.' >&2
	exit 1
fi

git -C "${DOTFILES_DIR}" pull --ff-only
echo '✅ Pulled latest changes.'

sh "${DOTFILES_DIR}/install.sh"
echo '✅ Reinstalled dotfiles.'

echo '👏 Done!'
