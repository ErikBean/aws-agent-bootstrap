#!/usr/bin/env bash
# Deploy infra/account-structure.yaml to the management account.
# Reads real values from config.local/account-structure.env, which is gitignored.
set -euo pipefail
cd "$(dirname "$0")/.."

config=config.local/account-structure.env
if [[ ! -f $config ]]; then
  echo "Missing $config. Copy config/account-structure.env.example and fill it in." >&2
  exit 1
fi
set -a; source "$config"; set +a

aws cloudformation deploy \
  --template-file infra/account-structure.yaml \
  --stack-name agent-account-structure \
  --no-fail-on-empty-changeset \
  --parameter-overrides \
    OrganizationRootId="$ORGANIZATION_ROOT_ID" \
    AgentAccountName="$AGENT_ACCOUNT_NAME" \
    AgentAccountEmail="$AGENT_ACCOUNT_EMAIL" \
    IdentityCenterInstanceArn="$IDENTITY_CENTER_INSTANCE_ARN" \
    BuilderPermissionSetArn="$BUILDER_PERMISSION_SET_ARN" \
    ReadOnlyPermissionSetArn="$READONLY_PERMISSION_SET_ARN" \
    PrincipalId="$PRINCIPAL_ID" \
    PrincipalType="$PRINCIPAL_TYPE"

aws cloudformation describe-stacks \
  --stack-name agent-account-structure \
  --query "Stacks[0].Outputs" --output table
