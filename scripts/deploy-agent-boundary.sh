#!/usr/bin/env bash
# Deploy the agent boundary to one member account, then bootstrap CDK there with
# the boundary on all bootstrap roles. Run once per member account, and again to
# re-bootstrap; both steps are idempotent.
#
# With --ci-bootstrap, also bootstrap a second time with the qualifier "ci", as
# the stack CDKToolkit-ci, for stages only CI deploys. Use it where dev shares an
# account with preview or prod, as in interim management-account mode. The
# builder is denied the ci bootstrap's roles.
#
# Usage: scripts/deploy-agent-boundary.sh <admin-profile> [region] [--ci-bootstrap]
set -euo pipefail
cd "$(dirname "$0")/.."
profile=${1:?usage: $0 <admin-profile> [region] [--ci-bootstrap]}
region=${2:-us-east-1}
ci=${3:-}
aws=(aws --profile "$profile" --region "$region")

"${aws[@]}" cloudformation deploy \
  --template-file infra/agent-boundary.yaml \
  --stack-name agent-boundary \
  --no-fail-on-empty-changeset

# Same as `cdk bootstrap --custom-permissions-boundary agent-boundary
# --apply-permissions-boundary-to-all-roles`, from the pinned template.
bootstrap() { # stack-name qualifier
  "${aws[@]}" cloudformation deploy \
    --template-file infra/cdk-bootstrap-template.yaml \
    --stack-name "$1" \
    --capabilities CAPABILITY_NAMED_IAM \
    --no-fail-on-empty-changeset \
    --parameter-overrides \
      Qualifier="$2" \
      InputPermissionsBoundary=agent-boundary \
      ApplyPermissionsBoundaryToAllRoles=true \
      CloudFormationExecutionPolicies=arn:aws:iam::aws:policy/AdministratorAccess
}

bootstrap CDKToolkit hnb659fds
if [[ $ci == --ci-bootstrap ]]; then
  bootstrap CDKToolkit-ci ci
elif [[ -n $ci ]]; then
  echo "Unknown option: $ci" >&2; exit 2
fi
