#!/usr/bin/env bash
# Set the builder permission set's inline policy from
# infra/agent-builder-inline-policy.json, after its simulator test passes, set
# both agent permission sets to 4-hour sessions (agent-client spec), and
# reprovision them to every account they're assigned to. Run in the management
# account.
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; source config.local/account-structure.env; set +a

scripts/test-agent-permissions.sh

aws sso-admin put-inline-policy-to-permission-set \
  --instance-arn "$IDENTITY_CENTER_INSTANCE_ARN" \
  --permission-set-arn "$BUILDER_PERMISSION_SET_ARN" \
  --inline-policy file://infra/agent-builder-inline-policy.json

for ps in "$BUILDER_PERMISSION_SET_ARN" "$READONLY_PERMISSION_SET_ARN"; do
  aws sso-admin update-permission-set \
    --instance-arn "$IDENTITY_CENTER_INSTANCE_ARN" \
    --permission-set-arn "$ps" \
    --session-duration PT4H
  aws sso-admin provision-permission-set \
    --instance-arn "$IDENTITY_CENTER_INSTANCE_ARN" \
    --permission-set-arn "$ps" \
    --target-type ALL_PROVISIONED_ACCOUNTS \
    --query "PermissionSetProvisioningStatus.Status" --output text
  aws sso-admin describe-permission-set \
    --instance-arn "$IDENTITY_CENTER_INSTANCE_ARN" \
    --permission-set-arn "$ps" \
    --query "PermissionSet.[Name, SessionDuration]" --output text
done
