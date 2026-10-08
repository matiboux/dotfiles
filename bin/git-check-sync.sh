#!/bin/sh
# List the local branches of the git repo in the current directory that are not
# in sync with a remote.
#
# Usage: git-check-sync.sh [-f|--fetch] [-h|--help]
#
# A local branch is compared with its upstream branch or, if it has none, with
# the first remote branch of the same name. Reported states:
# - ahead: local commits not pushed yet.
# - behind: remote commits not pulled yet.
# - diverged: both ahead and behind.
# - gone: the upstream branch no longer exists on the remote.
# - no remote: no upstream and no remote branch of the same name.
#
# Options:
# - -f, --fetch: fetch all remotes first, to compare with up-to-date remote branches.
# - -h, --help: show usage.
#
# Environment:
# - WORKING_DIR: directory of the git repo.
#   (default: shell current directory)
#
# Exit status is 1 if at least one branch is not in sync, else 0.
set -u

fetch='false'

usage() {
	echo "Usage: ${0##*/} [-f|--fetch] [-h|--help]"
}

while [ "$#" -gt 0 ]; do
	case "$1" in
		-f|--fetch)
			fetch='true'
			;;
		-h|--help)
			usage
			exit 0
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
if ! git -C "${WORKING_DIR}" rev-parse --git-dir >/dev/null 2>&1; then
	echo "❌ Not a git repository: ${WORKING_DIR}" >&2
	exit 2
fi

git_repo() {
	git -C "${WORKING_DIR}" "$@"
}

if [ "${fetch}" = 'true' ]; then
	git_repo fetch --all --quiet || echo '⚠️  Failed to fetch some remotes' >&2
fi

current_branch="$(git_repo branch --show-current)"
unsynced_count=0
gone_count=0
total_count=0

# Fields are separated by a space, as branch names cannot contain one.
branches="$(git_repo for-each-ref --format='%(refname:short) %(upstream)' refs/heads/)"

while read -r branch upstream; do
	[ -z "${branch}" ] && continue
	total_count=$((total_count + 1))

	# An upstream can be a local branch: only remote branches are relevant here
	remote_ref=''
	case "${upstream}" in
		refs/remotes/*)
			remote_ref="${upstream#refs/remotes/}"
			;;
	esac
	if [ -z "${remote_ref}" ]; then
		# No remote upstream: fall back to a remote branch of the same name
		remote_ref="$(git_repo for-each-ref --format='%(refname:short)' refs/remotes/ | grep -m 1 "^[^/]*/${branch}$")"
	fi

	if [ -z "${remote_ref}" ]; then
		state='no remote'
	elif ! git_repo show-ref --verify --quiet "refs/remotes/${remote_ref}"; then
		state="gone (${remote_ref})"
		gone_count=$((gone_count + 1))
	else
		read -r ahead behind <<EOF
$(git_repo rev-list --left-right --count "${branch}...${remote_ref}")
EOF
		if [ "${ahead}" -gt 0 ] && [ "${behind}" -gt 0 ]; then
			state="diverged from ${remote_ref} (ahead ${ahead}, behind ${behind})"
		elif [ "${ahead}" -gt 0 ]; then
			state="ahead of ${remote_ref} by ${ahead}"
		elif [ "${behind}" -gt 0 ]; then
			state="behind ${remote_ref} by ${behind}"
		else
			continue
		fi
	fi

	if [ "${unsynced_count}" -eq 0 ]; then
		echo 'Local branches not in sync with a remote:'
	fi
	unsynced_count=$((unsynced_count + 1))

	marker=' '
	[ "${branch}" = "${current_branch}" ] && marker='*'
	echo "  ${marker} ${branch}: ${state}"
done <<EOF
${branches}
EOF

echo ''
if [ "${unsynced_count}" -gt 0 ]; then
	echo "⚠️  ${unsynced_count}/${total_count} local branches not in sync"
	if [ "${gone_count}" -gt 0 ]; then
		gone_label='branches'
		[ "${gone_count}" -eq 1 ] && gone_label='branch'
		echo "ℹ️  ${gone_count} ${gone_label} gone from remote: consider running git-clean-synced-branches"
	fi
	exit 1
fi
echo "✅ All ${total_count} local branches in sync"
