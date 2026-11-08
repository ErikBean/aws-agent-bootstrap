#!/usr/bin/env bash
# Check the account-structure spec's scenarios against the real organization:
# Agent-Builder is assigned only to the agent account, and Agent-ReadOnly only
# to the agent and preview accounts, so neither ever reaches the management or
# production account.
# Prints which accounts each permission set is provisioned to, and exits 1 on a mismatch.
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; source config.local/account-structure.env; set +a

output() {
  aws cloudformation describe-stacks --stack-name agent-account-structure \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text
}
agent_account=$(output AgentAccountId)
preview_account=$(output PreviewAccountId)
sorted() { tr -s '[:space:]' '\n' <<<"$*" | grep -v '^$' | sort | tr '\n' ' '; }

status=0
check() { # permission-set-arn expected-account-ids...
  local ps=$1; shift
  name=$(aws sso-admin describe-permission-set --instance-arn "$IDENTITY_CENTER_INSTANCE_ARN" \
    --permission-set-arn "$ps" --query PermissionSet.Name --output text)
  accounts=$(aws sso-admin list-accounts-for-provisioned-permission-set \
    --instance-arn "$IDENTITY_CENTER_INSTANCE_ARN" --permission-set-arn "$ps" \
    --query AccountIds --output text)
  if [[ $(sorted "$accounts") == "$(sorted "$@")" ]]; then
    echo "ok   $name: $*"
  else
    echo "FAIL $name: provisioned to $accounts, expected $*"
    status=1
  fi
}
check "$BUILDER_PERMISSION_SET_ARN" "$agent_account"
check "$READONLY_PERMISSION_SET_ARN" "$agent_account" "$preview_account"
exit $status
