#!/usr/bin/env bash
# Set the builder permission set's inline policy from
# infra/agent-builder-inline-policy.json, after its simulator test passes, and
# reprovision it to every account it's assigned to. Run in the management account.
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; source config.local/account-structure.env; set +a

scripts/test-agent-permissions.sh

aws sso-admin put-inline-policy-to-permission-set \
  --instance-arn "$IDENTITY_CENTER_INSTANCE_ARN" \
  --permission-set-arn "$BUILDER_PERMISSION_SET_ARN" \
  --inline-policy file://infra/agent-builder-inline-policy.json

aws sso-admin provision-permission-set \
  --instance-arn "$IDENTITY_CENTER_INSTANCE_ARN" \
  --permission-set-arn "$BUILDER_PERMISSION_SET_ARN" \
  --target-type ALL_PROVISIONED_ACCOUNTS \
  --query "PermissionSetProvisioningStatus.Status" --output text
