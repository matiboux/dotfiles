#!/bin/sh
# Delete the local branches of the git repo in the current directory that are
# synced with a remote or gone from it, and prune stale remote-tracking branches.
#
# Usage: git-clean-synced-branches.sh [-h|--help] [-n|--dry-run] [-y|--yes]
#
# Remotes are fetched first. A local branch is compared with its upstream branch
# or, if it has none, with the first remote branch of the same name (same as
# git-check-sync.sh). Branches handled:
# - synced: same commit as the remote branch, so nothing is lost. Force-deleted.
# - gone: the upstream branch no longer exists on the remote. Deleted only if
#   fully merged into the current branch (git branch -d), else kept.
# Primary branches (dev, staging, main, master) and branches without a remote
# are never deleted.
#
# The current branch is deleted last, after switching to the first primary branch
# found. If it is synced, it is kept as long as a remote branch still points to
# its commit. Deleted branches are recreated on checkout when needed.
#
# Options:
# - -h, --help: show usage.
# - -n, --dry-run: list the branches that would be deleted, without deleting or pruning.
# - -y, --yes: do not ask for confirmation.
#
# Environment:
# - WORKING_DIR: directory of the git repo.
#   (default: shell current directory)
set -u

# Branches that are never deleted, in order of preference to switch to
PRIMARY_BRANCHES='dev staging main master'

dry_run='false'
assume_yes='false'

usage() {
	echo "Usage: ${0##*/} [-h|--help] [-n|--dry-run] [-y|--yes]"
}

while [ "$#" -gt 0 ]; do
	case "$1" in
		-h|--help)
			usage
			exit 0
			;;
		-n|--dry-run)
			dry_run='true'
			;;
		-y|--yes)
			assume_yes='true'
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

# Delete a local branch with the given git branch flag (-d or -D).
delete_branch() {
	if git_repo branch "$1" "$2" >/dev/null 2>&1; then
		echo " * Deleted local branch '$2'."
	else
		echo " * ⚠️  Kept local branch '$2': not fully merged, delete it manually with git branch -D"
	fi
}

nl='
'
current_branch="$(git_repo branch --show-current)"

# ---

if ! git_repo fetch --all --quiet; then
	echo '❌ Failed to fetch remotes' >&2
	exit 2
fi
echo '✅ Fetched all remotes.'

# ---

# List branches to delete, one "<kind> <branch>" per line (kind: synced or gone)
candidates=''
current_kind=''
branches="$(git_repo for-each-ref --format='%(refname:short) %(upstream)' refs/heads/)"

while read -r branch upstream; do
	[ -z "${branch}" ] && continue
	case " ${PRIMARY_BRANCHES} " in
		*" ${branch} "*) continue ;;
	esac

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
	[ -z "${remote_ref}" ] && continue

	if ! git_repo show-ref --verify --quiet "refs/remotes/${remote_ref}"; then
		kind='gone'
	elif [ "$(git_repo rev-parse "refs/heads/${branch}")" = "$(git_repo rev-parse "refs/remotes/${remote_ref}")" ]; then
		kind='synced'
	else
		continue
	fi

	candidates="${candidates:+${candidates}${nl}}${kind} ${branch}"
	if [ "${branch}" = "${current_branch}" ]; then
		current_kind="${kind}"
	fi
done <<EOF
${branches}
EOF

if [ -z "${candidates}" ]; then
	echo 'ℹ️  No local branch to delete.'
else
	echo 'The following local branches will be deleted (gone ones only if fully merged):'
	while read -r kind branch; do
		note=''
		if [ "${branch}" = "${current_branch}" ]; then
			if [ "${kind}" = 'synced' ]; then
				note=' (current branch, only if no remote branch points to its commit)'
			else
				note=' (current branch, after switching to a primary branch)'
			fi
		fi
		echo "  - ${branch} [${kind}]${note}"
	done <<EOF
${candidates}
EOF

	if [ "${dry_run}" = 'true' ]; then
		echo 'ℹ️  Dry run: nothing deleted nor pruned.'
		exit 0
	fi

	if [ "${assume_yes}" != 'true' ]; then
		printf 'Are you sure you want to delete these branches locally? (Y/n): '
		read -r confirm
		if [ -n "${confirm}" ] && [ "${confirm}" != 'y' ] && [ "${confirm}" != 'Y' ]; then
			echo '👋 Aborting local branches cleanup.'
			exit 0
		fi
	fi

	# Delete local branches, except the current one
	while read -r kind branch; do
		[ "${branch}" = "${current_branch}" ] && continue
		if [ "${kind}" = 'synced' ]; then
			delete_branch -D "${branch}"
		else
			delete_branch -d "${branch}"
		fi
	done <<EOF
${candidates}
EOF
	echo '✅ Cleaned up local branches.'
fi

# ---

if [ "${dry_run}" = 'true' ]; then
	echo 'ℹ️  Dry run: nothing pruned.'
	exit 0
fi

# Prune remote-tracking branches
while read -r remote; do
	[ -z "${remote}" ] && continue
	git_repo remote prune "${remote}" >/dev/null
	echo " * Pruned remote-tracking branches for remote '${remote}'."
done <<EOF
$(git_repo remote)
EOF
echo '✅ Pruned all remote-tracking branches.'

# ---

[ -z "${current_kind}" ] && exit 0

# A synced current branch is kept while a remote branch still points to its commit
if [ "${current_kind}" = 'synced' ]; then
	current_commit="$(git_repo rev-parse "refs/heads/${current_branch}")"
	if git_repo for-each-ref --format='%(objectname)' refs/remotes/ | grep -q "^${current_commit}$"; then
		echo "ℹ️  Current branch '${current_branch}' not deleted as it still exists on remote."
		exit 0
	fi
fi

# Find a primary branch to switch to, from a local or a remote branch
primary_branch=''
for branch in ${PRIMARY_BRANCHES}; do
	if git_repo show-ref --verify --quiet "refs/heads/${branch}" \
	|| git_repo for-each-ref --format='%(refname:short)' refs/remotes/ | grep -q "^[^/]*/${branch}$"; then
		primary_branch="${branch}"
		break
	fi
done
if [ -z "${primary_branch}" ]; then
	echo "ℹ️  Current branch '${current_branch}' not deleted as no primary branch was found to switch to."
	exit 0
fi

if ! git_repo switch "${primary_branch}" >/dev/null 2>&1; then
	echo "⚠️  Current branch '${current_branch}' not deleted as switching to '${primary_branch}' failed." >&2
	exit 1
fi
echo "ℹ️  Switched to primary branch '${primary_branch}'."
git_repo merge --ff-only '@{upstream}' >/dev/null 2>&1 || true

if [ "${current_kind}" = 'synced' ]; then
	delete_branch -D "${current_branch}"
else
	delete_branch -d "${current_branch}"
fi
