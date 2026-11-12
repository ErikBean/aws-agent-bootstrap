#!/usr/bin/env bash
# Interim management-account mode: assign the agent permission sets to the agent
# user in the management account. Run in the management account with the Admin
# profile, after scripts/apply-agent-permissions.sh, so the builder already has
# its denies when the agent user first gets it.
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; source config.local/account-structure.env; set +a

account=$(aws sts get-caller-identity --query Account --output text)
management=$(aws organizations describe-organization --query Organization.MasterAccountId --output text)
if [[ $account != "$management" ]]; then
  echo "Run this with a profile for the management account." >&2; exit 1
fi

aws cloudformation deploy \
  --template-file infra/interim-assignments.yaml \
  --stack-name interim-agent-assignments \
  --no-fail-on-empty-changeset \
  --parameter-overrides \
    ManagementAccountId="$account" \
    IdentityCenterInstanceArn="$IDENTITY_CENTER_INSTANCE_ARN" \
    BuilderPermissionSetArn="$BUILDER_PERMISSION_SET_ARN" \
    ReadOnlyPermissionSetArn="$READONLY_PERMISSION_SET_ARN" \
    AgentPrincipalId="$AGENT_PRINCIPAL_ID" \
    AdminPrincipalId="$ADMIN_PRINCIPAL_ID"

# Who holds each agent permission set in the management account. Only the
# agent user should be listed; remove anyone else, as the runbook says.
for ps in "$BUILDER_PERMISSION_SET_ARN" "$READONLY_PERMISSION_SET_ARN"; do
  name=$(aws sso-admin describe-permission-set --instance-arn "$IDENTITY_CENTER_INSTANCE_ARN" \
    --permission-set-arn "$ps" --query PermissionSet.Name --output text)
  holders=$(aws sso-admin list-account-assignments --instance-arn "$IDENTITY_CENTER_INSTANCE_ARN" \
    --account-id "$account" --permission-set-arn "$ps" \
    --query "AccountAssignments[].PrincipalId" --output text)
  for h in $holders; do
    if [[ $h == "$AGENT_PRINCIPAL_ID" ]]; then echo "ok   $name: agent user"
    else echo "FAIL $name: also assigned to principal $h"; fi
  done
done
