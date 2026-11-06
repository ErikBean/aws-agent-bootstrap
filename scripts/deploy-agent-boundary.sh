#!/usr/bin/env bash
# Deploy the agent boundary to one member account, then bootstrap CDK there with
# the boundary on all bootstrap roles. Run once per member account, and again to
# re-bootstrap; both steps are idempotent.
#
# Usage: scripts/deploy-agent-boundary.sh <admin-profile-for-the-member-account> [region]
set -euo pipefail
cd "$(dirname "$0")/.."
profile=${1:?usage: $0 <admin-profile> [region]}
region=${2:-us-east-1}
aws=(aws --profile "$profile" --region "$region")

"${aws[@]}" cloudformation deploy \
  --template-file infra/agent-boundary.yaml \
  --stack-name agent-boundary \
  --no-fail-on-empty-changeset

# Same as `cdk bootstrap --custom-permissions-boundary agent-boundary
# --apply-permissions-boundary-to-all-roles`, from the pinned template.
"${aws[@]}" cloudformation deploy \
  --template-file infra/cdk-bootstrap-template.yaml \
  --stack-name CDKToolkit \
  --capabilities CAPABILITY_NAMED_IAM \
  --no-fail-on-empty-changeset \
  --parameter-overrides \
    InputPermissionsBoundary=agent-boundary \
    ApplyPermissionsBoundaryToAllRoles=true \
    CloudFormationExecutionPolicies=arn:aws:iam::aws:policy/AdministratorAccess
