#!/bin/sh
set -eu

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

install -m 600 "${script_dir}/.gitconfig.work" "${HOME}/.gitconfig.work"
