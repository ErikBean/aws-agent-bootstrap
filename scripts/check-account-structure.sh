#!/usr/bin/env bash
# Check the account-structure spec's scenarios against the real organization:
# each agent permission set is assigned to the agent account and no other, so
# never to the management or production account.
# Prints which accounts each permission set is provisioned to, and exits 1 on a mismatch.
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; source config.local/account-structure.env; set +a

agent_account=$(aws cloudformation describe-stacks --stack-name agent-account-structure \
  --query "Stacks[0].Outputs[?OutputKey=='AgentAccountId'].OutputValue" --output text)

status=0
for ps in "$BUILDER_PERMISSION_SET_ARN" "$READONLY_PERMISSION_SET_ARN"; do
  name=$(aws sso-admin describe-permission-set --instance-arn "$IDENTITY_CENTER_INSTANCE_ARN" \
    --permission-set-arn "$ps" --query PermissionSet.Name --output text)
  accounts=$(aws sso-admin list-accounts-for-provisioned-permission-set \
    --instance-arn "$IDENTITY_CENTER_INSTANCE_ARN" --permission-set-arn "$ps" \
    --query AccountIds --output text)
  if [[ $accounts == "$agent_account" ]]; then
    echo "ok   $name: agent account only"
  else
    echo "FAIL $name: provisioned to $accounts, expected only the agent account"
    status=1
  fi
done
exit $status
