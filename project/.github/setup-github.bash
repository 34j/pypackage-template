#!/bin/bash
owner=$1
repo=$2
shortDescription=$3
ownerRepo=$owner/$repo

# create repo
gh repo create $ownerRepo -d $shortDescription --public --remote=origin --source=. --push

# squash merge
gh repo edit --delete-branch-on-merge --enable-projects=false --enable-wiki=false --enable-merge-commit=false --enable-squash-merge --enable-rebase-merge=false

# set secrets
gh secret set PYPI_TOKEN -b $PYPI_TOKEN
gh secret set GH_PAT -b $GITHUB_TOKEN

# set workflow permissions
gh api --method PUT -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" "repos/$ownerRepo/actions/permissions/workflow" -f default_workflow_permissions="read" -F can_approve_pull_request_reviews=true

# set branch protection
# https://docs.github.com/ja/rest/branches/branch-protection?apiVersion=2022-11-28#update-branch-protection
echo "Setting branch protection rules for $ownerRepo"
curl -L \
-X PUT \
-H "Accept: application/vnd.github+json" \
-H "Authorization: Bearer $GITHUB_TOKEN" \
-H "X-GitHub-Api-Version: 2022-11-28" \
https://api.github.com/repos/$ownerRepo/branches/BRANCH/protection \
-d '{"required_status_checks":{"strict":false,"contexts":[]},"enforce_admins":false,"required_pull_request_reviews":{},"restrictions":{},"required_linear_history":false,"allow_force_pushes":true,"allow_deletions":true,"block_creations":false,"required_conversation_resolution":false,"lock_branch":false,"allow_fork_syncing":true}'

# install GitHub Apps
echo "Installing GitHub Apps"

# get installation ids for Renovate, pre-commit.ci and repository id
# AllContributors and Codecov can be globally installed
installationIds=$(echo $PYPACKAGE_TEMPLATE_INSTALLATION_IDS | tr "," "\n")
repositoryId=$(gh api "repos/$ownerRepo" --jq '.id')

# https://docs.github.com/ja/rest/apps/installations?apiVersion=2022-11-28#add-a-repository-to-an-app-installation
for installationId in $installationIds; do
  gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "user/installations/$installationId/repositories/$repositoryId"
done
