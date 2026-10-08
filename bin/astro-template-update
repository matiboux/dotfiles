#!/usr/bin/env bash
set -e

if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
	echo "Usage: $(basename "$0") <first_path> <second_path>"
	echo "Compares two paths and prints the differences."
	exit 0
fi

PROJECT_PATH="$1"
if [ -z "$PROJECT_PATH" ]; then
	# Use the current directory if no path is provided
	PROJECT_PATH="$(pwd)"
fi

APP_DIR="$2"
if [ -z "$APP_DIR" ]; then
	# Use the default app directory if no second path is provided
	APP_DIR='app'
fi

# ---

# Script inputs:
DEFAULT_GIT_REMOTE='origin'
DEFAULT_GIT_BRANCH='dev'
UPDATE_GIT_BRANCH='feat/update-astro-template'

if [ -z "${WORKING_DIR}" ]; then
  WORKING_DIR="$(pwd)"
fi

PRIMARY_GIT_BRANCHES="$(cat <<EOF
dev
staging
main
master
EOF
)"

# ---

TEMPLATE_PATH=''
ERR_FILE=''

cleanup_trap() {
	if [ -n "${TEMPLATE_PATH}" ] && [ "${TEMPLATE_PATH#/tmp}" != "${TEMPLATE_PATH}" ]; then
		rm -rf -- "${TEMPLATE_PATH}"
	fi
	if [ -n "${ERR_FILE}" ] && [ "${ERR_FILE#/tmp}" != "${ERR_FILE}" ]; then
		rm -f -- "${ERR_FILE}"
	fi
}

trap 'cleanup_trap' EXIT INT TERM

sanitize_err() {
	tr '\n' ' ' <"$1" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//'
}

# ---

CURRENT_BRANCH="$(git -C "${PROJECT_PATH}" branch --show-current)"

if [ "${CURRENT_BRANCH}" = "${UPDATE_GIT_BRANCH}" ]; then

	echo '✅  Already on update branch '${UPDATE_GIT_BRANCH}'.'

else

	# Check if the working directory is clean
	if [ -n "$(git -C "${PROJECT_PATH}" status --porcelain)" ]; then
		echo '❌  Working directory is not clean. Please commit or stash your changes before running this script.'
		exit 1
	fi

	# Fetch latest updates from remote
	git -C "${PROJECT_PATH}" fetch "${DEFAULT_GIT_REMOTE}"

	if echo "${PRIMARY_GIT_BRANCHES}" | grep -q -w "${CURRENT_BRANCH}"; then
		# Current branch is a primary branch

		# Merge with latest updates from remote
		git -C "${PROJECT_PATH}" merge --ff-only "${DEFAULT_GIT_REMOTE}/${CURRENT_BRANCH}"

		# Create update branch from the current branch
		git -C "${PROJECT_PATH}" checkout -b "${UPDATE_GIT_BRANCH}" "${CURRENT_BRANCH}"

		echo '✅  Checked out update branch '${UPDATE_GIT_BRANCH}' (created from current branch).'

	else

		# Create the update branch from first found remote-tracking branch in order of priority
		echo "${PRIMARY_GIT_BRANCHES}" | while IFS= read -r branch; do
			if git -C "${PROJECT_PATH}" show-ref --verify --quiet "refs/remotes/${DEFAULT_GIT_REMOTE}/${branch}"; then
				git -C "${PROJECT_PATH}" checkout -b "${UPDATE_GIT_BRANCH}" "refs/remotes/${DEFAULT_GIT_REMOTE}/${branch}"
				break
			fi
		done

		# Verify that the update branch was created and checked out
		if [ "$(git -C "${PROJECT_PATH}" branch --show-current)" != "${UPDATE_GIT_BRANCH}" ]; then
			echo "❌  Failed to check out update branch '${UPDATE_GIT_BRANCH}'."
			exit 1
		fi

		echo '✅  Checked out update branch '${UPDATE_GIT_BRANCH}' (created from remote-tracking branch).'

	fi

fi

# ---

if [ ! -f "${PROJECT_PATH}/.env" ]; then
	PROJECT_SLUG=''
else
	# Get the project slug from the .env file
	PROJECT_SLUG="$(
		grep -E '^IMAGES_PREFIX=' "${PROJECT_PATH}/.env" \
		| cut -d '=' -f 2- | sed -E "s/^['\"]|['\"]$//g"
	)"
fi

if [ ! -f "${PROJECT_PATH}/${APP_DIR}/src/site.ts" ]; then
	SITE_TITLE=''
	GITHUB_REPO_PATH=''
else
	# Get the site title from the site.ts file
	SITE_TITLE="$(
		grep -E "^[[:space:]]*title:[[:space:]]*['\"]" "${PROJECT_PATH}/${APP_DIR}/src/site.ts" \
		| env LC_ALL=C sed -E "s/^[[:space:]]*title:[[:space:]]*['\"]([^'\"]*)['\"],?.*$/\1/"
	)"

	# Get the github repository path from the site.ts file
	GITHUB_REPO_PATH="$(
		grep -E "^[[:space:]]*\|\|[[:space:]]+['\"]https?://github\\.com/" "${PROJECT_PATH}/${APP_DIR}/src/site.ts" \
		| env LC_ALL=C sed -E "s/^[[:space:]]*\|\|[[:space:]]+['\"]https?:\/\/github\\.com\/([^'\"/]+\/[^'\"/]+).*/\1/"
	)"
fi

echo '✅  Fetched project information.'

# ---

TEMPLATE_PATH="$(mktemp -d)"
ERR_FILE="$(mktemp)"

if ! git clone \
	--depth 1 \
	git@github.com:matiboux/astro-template.git \
	"${TEMPLATE_PATH}" \
	> /dev/null 2> "${ERR_FILE}" \
	; then

	err_text="$(sanitize_err "${ERR_FILE}")"
	echo '❌  Failed to clone Astro template repository'
	[ -n "${err_text}" ] && echo "${err_text}" >&2
	exit 1
fi

echo '✅  Cloned Astro template repository.'

# ---

sanitize_sed_part() {
	echo "$1" | sed -E 's/([\/&])/\\\1/g'
}
SED_ARGS=()
[ -n "${GITHUB_REPO_PATH}" ] && SED_ARGS+=( -e "s/matiboux\/astro-template/$(sanitize_sed_part "${GITHUB_REPO_PATH}")/g" )
[ -n "${SITE_TITLE}" ] && SED_ARGS+=( -e "s/Astro Template/$(sanitize_sed_part "${SITE_TITLE}")/g" )
[ -n "${PROJECT_SLUG}" ] && SED_ARGS+=( -e "s/astro-template/$(sanitize_sed_part "${PROJECT_SLUG}")/g" )

if [ ${#SED_ARGS[@]} -gt 0 ]; then
	while IFS= read -r -d '' file; do

		# Skip binary files (e.g. images)
		if ! LC_ALL=C grep -Iq . "${file}"; then
			continue
		fi

		update_file="$(mktemp)" || {
			echo "❌  Failed to create temporary file for updating '${file}'."
			exit 1
		}

		env LC_ALL=C sed "${SED_ARGS[@]}" -- "${file}" > "${update_file}" || {
			echo "❌  Failed to update file '${file}'."
			rm -f -- "${update_file}"
			exit 1
		}

		# Preserve executable permission bit
		[ -x "${file}" ] && chmod +x "${update_file}"

		# Replace original file with updated file
		mv "${update_file}" "${file}"

	done < <(find "${TEMPLATE_PATH}" -type f -print0)
fi

echo '✅  Updated template files with project information.'

# ---

cp "${TEMPLATE_PATH}/.editorconfig" "${PROJECT_PATH}/"
cp "${TEMPLATE_PATH}/.env"* "${PROJECT_PATH}/"
cp "${TEMPLATE_PATH}/.gitignore" "${PROJECT_PATH}/"
cp "${TEMPLATE_PATH}/docker-compose"* "${PROJECT_PATH}/"
cp "${TEMPLATE_PATH}/Makefile" "${PROJECT_PATH}/"
cp "${TEMPLATE_PATH}/README.md" "${PROJECT_PATH}/"

mkdir -p "${PROJECT_PATH}/.devcontainer/"
cp "${TEMPLATE_PATH}/.devcontainer/"*.* "${PROJECT_PATH}/.devcontainer/"

mkdir -p "${PROJECT_PATH}/.github/workflows/"
cp "${TEMPLATE_PATH}/.github/workflows/"*.* "${PROJECT_PATH}/.github/workflows/"

mkdir -p "${PROJECT_PATH}/.github/workflows/scripts/"
cp "${TEMPLATE_PATH}/.github/workflows/scripts/"*.* "${PROJECT_PATH}/.github/workflows/scripts/"

mkdir -p "${PROJECT_PATH}/.vscode/"
cp "${TEMPLATE_PATH}/.vscode/extensions.json" "${PROJECT_PATH}/.vscode/"

mkdir -p "${PROJECT_PATH}/${APP_DIR}/"
cp "${TEMPLATE_PATH}/app/.dockerignore" "${PROJECT_PATH}/${APP_DIR}/"
cp "${TEMPLATE_PATH}/app/Dockerfile" "${PROJECT_PATH}/${APP_DIR}/"
cp "${TEMPLATE_PATH}/app/"*.* "${PROJECT_PATH}/${APP_DIR}/"

mkdir -p "${PROJECT_PATH}/${APP_DIR}/docker/"
cp "${TEMPLATE_PATH}/app/docker/"*.* "${PROJECT_PATH}/${APP_DIR}/docker/"

mkdir -p "${PROJECT_PATH}/${APP_DIR}/nginx/"
cp "${TEMPLATE_PATH}/app/nginx/"*.* "${PROJECT_PATH}/${APP_DIR}/nginx/"

mkdir -p "${PROJECT_PATH}/${APP_DIR}/src/"
cp "${TEMPLATE_PATH}/app/src/"*.* "${PROJECT_PATH}/${APP_DIR}/src/"

mkdir -p "${PROJECT_PATH}/${APP_DIR}/src/i18n/"
cp "${TEMPLATE_PATH}/app/src/i18n/"*.* "${PROJECT_PATH}/${APP_DIR}/src/i18n/"

mkdir -p "${PROJECT_PATH}/${APP_DIR}/src/i18n/locales/"
cp "${TEMPLATE_PATH}/app/src/i18n/locales/"*.* "${PROJECT_PATH}/${APP_DIR}/src/i18n/locales/"

mkdir -p "${PROJECT_PATH}/${APP_DIR}/src/layouts/"
cp "${TEMPLATE_PATH}/app/src/layouts/"*.* "${PROJECT_PATH}/${APP_DIR}/src/layouts/"

mkdir -p "${PROJECT_PATH}/${APP_DIR}/src/styles/"
cp "${TEMPLATE_PATH}/app/src/styles/"*.* "${PROJECT_PATH}/${APP_DIR}/src/styles/"

mkdir -p "${PROJECT_PATH}/${APP_DIR}/test/"
cp -r "${TEMPLATE_PATH}/app/test/"* "${PROJECT_PATH}/${APP_DIR}/test/"

mkdir -p "${PROJECT_PATH}/scripts/"
cp "${TEMPLATE_PATH}/scripts/"*.* "${PROJECT_PATH}/scripts/"

echo '✅  Copied template files to project.'

# ---

# Set template commit hash in project
COMMIT_HASH=$(git -C "${TEMPLATE_PATH}" rev-parse HEAD)
echo "${COMMIT_HASH}" > "${PROJECT_PATH}/${APP_DIR}/.astro-template"

# Git add template commit hash file
git -C "${PROJECT_PATH}" add "${APP_DIR}/.astro-template"

# Commit if there are staged changes
if [ -n "$(git -C "${PROJECT_PATH}" diff --cached --name-only)" ]; then
	git -C "${PROJECT_PATH}" commit -m 'Set astro template commit hash'
fi

echo "✅  Set template commit hash in project: '${COMMIT_HASH}'"

# ---

echo '👏  Done!'
echo '📝  Please review the changes and restore your custom files as necessary.'
