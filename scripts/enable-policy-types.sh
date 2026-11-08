#!/usr/bin/env bash
# Enable the organization policy types this setup uses on the organization
# root: SCPs, RCPs, EC2 declarative policies and S3 policies. Safe to rerun.
# Run in the management account before deploying any SCP, RCP or declarative
# policy.
set -euo pipefail

root=$(aws organizations list-roots --query "Roots[0].Id" --output text)
enabled=$(aws organizations list-roots \
  --query "Roots[0].PolicyTypes[?Status=='ENABLED'].Type" --output text)

for type in SERVICE_CONTROL_POLICY RESOURCE_CONTROL_POLICY DECLARATIVE_POLICY_EC2 S3_POLICY; do
  if grep -qw "$type" <<<"$enabled"; then
    echo "already enabled: $type"
  else
    aws organizations enable-policy-type --root-id "$root" --policy-type "$type" \
      --query "Root.PolicyTypes[?Type=='$type'].Status" --output text
  fi
done
