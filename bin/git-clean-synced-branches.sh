#!/bin/sh
set -e

if [ -z "${WORKING_DIR}" ]; then
	WORKING_DIR="$(pwd)"
fi

# ---

# Get current branch name
CURRENT_BRANCH="$(git branch --show-current)"

# List primary branches that should not be deleted
PRIMARY_BRANCHES="$(cat <<EOF
dev
staging
main
master
EOF
)"

# List protected branches that should not be deleted
PROTECTED_BRANCHES="$(cat <<EOF
${PRIMARY_BRANCHES}
${CURRENT_BRANCH}
EOF
)"

# ---

# Fetch latest updates from all remotes
git fetch --all

echo '✅  Fetched all remotes.'

# ---

# List secondary branches synced with their remote counterparts (from any remote)
SYNCED_BRANCHES="$(
	while IFS= read -r SYNCED_BRANCH; do
		echo "$PRIMARY_BRANCHES" | grep -q "^$SYNCED_BRANCH$" && continue
		BRANCH_COMMIT=$(git rev-parse $SYNCED_BRANCH 2>/dev/null || echo "")
		[ -z "$BRANCH_COMMIT" ] && continue
		REMOTE_MATCH=$(
			git for-each-ref --format='%(refname:short) %(objectname)' refs/remotes/ \
			| awk -v commit="$BRANCH_COMMIT" '$2 == commit {print $1}'
		)
		[ -z "$REMOTE_MATCH" ] && continue
		if echo "$REMOTE_MATCH" | grep -q "/$SYNCED_BRANCH$"; then
			echo "$SYNCED_BRANCH"
		fi
	done <<EOF
$(git for-each-ref --format='%(refname:short)' refs/heads/)
EOF
)"

if [ -n "$SYNCED_BRANCHES" ]; then

	# Confirm local synced branches deletion
	echo 'The following local branches are synced with their remote counterparts and will be deleted:'
	echo "${SYNCED_BRANCHES}" | while IFS= read -r BRANCH; do
		[ -z "$BRANCH" ] && continue
		if [ "$BRANCH" = "$CURRENT_BRANCH" ]; then
			echo "  - ${BRANCH} (only if removed from remote)"
		else
			echo "  - ${BRANCH}"
		fi
	done
	read -p 'Are you sure you want to delete these branches locally? (Y/n): ' CONFIRM

	if [ -n "$CONFIRM" ] && [ "${CONFIRM}" != "y" ] && [ "${CONFIRM}" != "Y" ]; then
		echo '👋  Aborting local branches cleanup.'
		exit 0
	fi

	# Delete local synced branches
	while IFS= read -r BRANCH; do
		[ -z "$BRANCH" ] && continue
		[ "$BRANCH" = "$CURRENT_BRANCH" ] && continue
		git branch -D "${BRANCH}" > /dev/null
		echo " * Deleted local synced branch '${BRANCH}'."
	done <<EOF
${SYNCED_BRANCHES}
EOF

fi

echo '✅  Deleted local synced branches.'

# ---

# Prune remote-tracking branches
while read -r REMOTE; do
	git remote prune "${REMOTE}" > /dev/null
	echo " * Pruned remote-tracking branches for remote '${REMOTE}'."
done <<EOF
$(git remote)
EOF

echo '✅  Pruned all remote-tracking branches.'

# ---

if [ -n "$CURRENT_BRANCH" ] \
&& echo "$SYNCED_BRANCHES" | grep -q "^${CURRENT_BRANCH}$"; then
	delete_current_branch() {
		# Current branch is synced with remote, check if it still exists on remote
		CURRENT_COMMIT=$(git rev-parse $CURRENT_BRANCH 2>/dev/null || echo "")
		REMOTE_MATCH=$(
			git for-each-ref --format='%(refname:short) %(objectname)' refs/remotes/ \
			| awk -v commit="$CURRENT_COMMIT" '$2 == commit {print $1}'
		)
		if [ -n "$REMOTE_MATCH" ]; then
			# Current branch still exists on remote
			echo "ℹ️  Branch '${CURRENT_BRANCH}' not deleted as it still exists on remote."
			return 0
		fi
		# Switch to a primary branch and delete the current branch
		FOUND_PRIMARY_BRANCH=''
		FOUND_PRIMARY_REMOTE=''
		while IFS= read -r branch; do
			FOUND_PRIMARY_REMOTE="$(
				git for-each-ref --format='%(refname:short)' refs/remotes/ \
				| grep -m 1 "/${branch}$" \
				|| echo ""
			)"
			if [ -n "$FOUND_PRIMARY_REMOTE" ] \
			|| git show-ref --verify --quiet "refs/heads/${branch}"; then
				FOUND_PRIMARY_BRANCH="${branch}"
				break
			fi
		done <<EOF
${PRIMARY_BRANCHES}
EOF
		if [ -z "$FOUND_PRIMARY_BRANCH" ]; then
			# Cannot find a primary branch to switch to, skip deletion
			return 0
		fi
		git switch "${FOUND_PRIMARY_BRANCH}" > /dev/null 2>&1
		echo "ℹ️  Switched to primary branch '${FOUND_PRIMARY_BRANCH}'."
		git merge --ff-only "${FOUND_PRIMARY_REMOTE}" > /dev/null 2>&1 || true
		git branch -D "${CURRENT_BRANCH}" > /dev/null
		echo "✅  Deleted previous current branch '${CURRENT_BRANCH}'."
	}
	delete_current_branch
fi
