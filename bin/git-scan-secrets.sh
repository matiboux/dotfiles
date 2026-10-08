#!/bin/sh
# Scan for secrets with gitleaks (the binary if in PATH, else the docker image).
#
# Usage: git-scan-secrets.sh [-h|--help] [-s|--stateless] [-u|--update-baseline]
#
# By default, scans the full git history.
#
# Options:
# - -h, --help: show usage.
# - -s, --stateless: scan only the working directory (no git history).
# - -u, --update-baseline: regenerate the baseline from current findings.
#   Review the diff before committing it: it accepts everything present,
#   real secrets included.
#
# Environment:
# - SECRETS_SCAN_BASELINE_PATH: optional gitleaks baseline (relative to the repo root) of
#   reviewed false positives, so only new findings fail. Always excluded from the scan.
# - SECRETS_SCAN_ALLOWLIST_REGEXES: comma-separated regexes to always ignore, added to the
#   default that matches placeholder names like SECRET_API_KEY.
# - SECRETS_SCAN_GITLEAKS_IMAGE_TAG: tag of the zricethezav/gitleaks image (default: latest).
set -u

mode='scan'
scan_target='git'

usage() {
	echo "Usage: ${0##*/} [-h|--help] [-s|--stateless] [-u|--update-baseline]"
}

while [ "$#" -gt 0 ]; do
	arg="$1"
	case "${arg}" in
		-h|--help)
			usage
			exit 0
			;;
		-s|--stateless)
			scan_target='dir'
			;;
		-u|--update-baseline)
			mode='update-baseline'
			;;
		--)
			shift
			break
			;;
		*)
			usage >&2
			exit 1
			;;
	esac
	shift
done

# No positional arguments are accepted, including after `--`.
if [ "$#" -gt 0 ]; then
	usage >&2
	exit 1
fi

WORKING_DIR="${WORKING_DIR:-$(pwd)}"
repo_dir="$(CDPATH= cd -- "${WORKING_DIR}" && pwd)"

baseline_path="${SECRETS_SCAN_BASELINE_PATH:-}"
[ -z "${baseline_path}" ] && baseline_path='.gitleaks-baseline.json'
has_baseline='false'
[ -f "${repo_dir}/${baseline_path}" ] && has_baseline='true'

gitleaks_image_tag="${SECRETS_SCAN_GITLEAKS_IMAGE_TAG:-}"
[ -z "${gitleaks_image_tag}" ] && gitleaks_image_tag='latest'

# Escape a string for use inside a TOML/regex literal.
escape_regex() {
	printf '%s' "$1" | sed -e 's/[.[\*^$()+?{}|\\]/\\&/g'
}

# The baseline stores raw matches, so scanning it would report every baselined finding again.
baseline_path_regex="$(escape_regex "${baseline_path}")"

# A baseline entry can't cover placeholders in `dir` scans: its fingerprint is
# commit-based, while `dir` fingerprints are path-based.
allowlist_regexes="${SECRETS_SCAN_ALLOWLIST_REGEXES:-(SECRET|TEST|YOUR)_(CLIENT|API)_(SECRET|KEY|TOKEN)}"
allowlist_regexes_toml=''
old_ifs="${IFS}"
IFS=','
for pattern in ${allowlist_regexes}; do
	[ -z "${pattern}" ] && continue
	allowlist_regexes_toml="${allowlist_regexes_toml}'''${pattern}''', "
done
IFS="${old_ifs}"

gitleaks_config_content="$(cat <<EOF
[extend]
useDefault = true

[allowlist]
paths = ['''${baseline_path_regex}''']
regexes = [${allowlist_regexes_toml}]
EOF
)"
gitleaks_config_b64="$(printf '%s' "${gitleaks_config_content}" | base64 | tr -d '\n')"

gitleaks_config_file=''
cleanup() {
	[ -n "${gitleaks_config_file}" ] && rm -f "${gitleaks_config_file}"
}
trap cleanup EXIT

# Gitleaks arguments
if [ "${mode}" = 'update-baseline' ]; then
	host_args="--report-format json --report-path ${repo_dir}/${baseline_path}"
	container_args="--report-format json --report-path /repo/${baseline_path}"
elif [ "${has_baseline}" = 'true' ]; then
	host_args="--baseline-path ${repo_dir}/${baseline_path} --verbose"
	container_args="--baseline-path /repo/${baseline_path} --verbose"
else
	host_args='--verbose'
	container_args='--verbose'
fi

if command -v gitleaks >/dev/null 2>&1; then
	gitleaks_config_file="$(mktemp)"
	printf '%s\n' "${gitleaks_config_content}" > "${gitleaks_config_file}"
	host_args="${host_args} --config ${gitleaks_config_file}"
	run_gitleaks() {
		gitleaks "${scan_target}" "${repo_dir}" --no-banner ${host_args}
	}
elif command -v docker >/dev/null 2>&1; then
	docker_image="zricethezav/gitleaks:${gitleaks_image_tag}"
	if docker run --rm -v "${repo_dir}:/probe" --entrypoint sh "${docker_image}" -c 'test -d /probe/.git' >/dev/null 2>&1; then
		gitleaks_config_file="$(mktemp)"
		printf '%s\n' "${gitleaks_config_content}" > "${gitleaks_config_file}"
		container_args="${container_args} --config /gitleaks.toml"
		run_gitleaks() {
			docker run --rm \
				-e GIT_DISCOVERY_ACROSS_FILESYSTEM=1 \
				-v "${repo_dir}:/repo" \
				-v "${gitleaks_config_file}:/gitleaks.toml:ro" \
				"${docker_image}" \
				"${scan_target}" /repo --no-banner ${container_args}
		}
	else
		# Bind mount is not available, so we stream an archive of the repo
		# directory to the container and use it for the scan. The gitleaks
		# config is embedded as base64 since it cannot be bind-mounted here.
		if [ "${mode}" = 'update-baseline' ]; then
			run_gitleaks() {
				local container_id="$(
					docker create -i --entrypoint sh "${docker_image}" \
						-c "mkdir -p /repo && tar -xf - -C /repo && printf '%s' '${gitleaks_config_b64}' | base64 -d > /tmp/gitleaks.toml && gitleaks ${scan_target} /repo --no-banner --config /tmp/gitleaks.toml ${container_args}"
				)"
				[ -z "${container_id}" ] && return 2
				tar -cf - -C "${repo_dir}" . | docker start -ai "${container_id}"
				local gitleaks_rc=$?
				[ "${gitleaks_rc}" -ge 2 ] && return "${gitleaks_rc}"
				local gitleaks_baseline="$(mktemp)"
				docker cp "${container_id}:/repo/${baseline_path}" "${gitleaks_baseline}" > /dev/null 2>&1
				if [ $? -eq 0 ]; then
					mv "${gitleaks_baseline}" "${repo_dir}/${baseline_path}" > /dev/null 2>&1
				else
					rm -f "${gitleaks_baseline}" > /dev/null 2>&1
					gitleaks_rc=2
				fi
				docker rm -f "${container_id}" > /dev/null 2>&1
				return "${gitleaks_rc}"
			}
		else
			run_gitleaks() {
				tar -cf - -C "${repo_dir}" . \
				| docker run --rm -i \
					--entrypoint sh \
					"${docker_image}" \
					-c "mkdir -p /repo && tar -xf - -C /repo && printf '%s' '${gitleaks_config_b64}' | base64 -d > /tmp/gitleaks.toml && gitleaks ${scan_target} /repo --no-banner --config /tmp/gitleaks.toml ${container_args}"
			}
		fi
	fi
else
	echo '⚠️  Skipped scan: Neither Gitleaks nor Docker found on PATH' >&2
	exit 0
fi

if [ "${scan_target}" = 'dir' ]; then
	echo 'Scanning for secrets in workdir (stateless, no git history)...'
else
	echo 'Scanning for committed secrets in git repo history...'
fi

echo ''
if [ "${mode}" = 'update-baseline' ]; then
	echo "📋 Regenerating gitleaks baseline at ${baseline_path}..."
else
	if [ "${has_baseline}" = 'true' ]; then
		echo "📋 Running gitleaks (baseline: ${baseline_path})..."
	else
		echo '📋 Running gitleaks (no baseline found)...'
	fi
fi
run_gitleaks
gitleaks_rc=$?

echo ''
if [ "${mode}" = 'update-baseline' ]; then
	if [ "${gitleaks_rc}" -ge 2 ] || [ ! -f "${repo_dir}/${baseline_path}" ]; then
		echo '❌ Baseline generation failed'
		exit 1
	fi
	echo "✅ Baseline written to ${baseline_path}"
	exit 0
fi
if [ "${gitleaks_rc}" -ne 0 ]; then
	echo '❌ New secrets found'
else
	echo '✅ No new secrets found'
fi
exit "${gitleaks_rc}"
