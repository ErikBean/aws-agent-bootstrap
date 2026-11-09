#!/usr/bin/env bash
# Deploy the management-account parts of the security baseline: the
# organization trail, the declarative public-access policies and the
# identity-perimeter RCP. Run in the management account after
# scripts/enable-policy-types.sh, and while the member accounts have no
# workloads. Access Analyzer is deployed separately, in each member account.
set -euo pipefail
cd "$(dirname "$0")/.."

scripts/test-rcp-identity-perimeter.sh

org_id=$(aws organizations describe-organization --query "Organization.Id" --output text)
output() {
  aws cloudformation describe-stacks --stack-name agent-account-structure \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text
}
ous="$(output AgentsOuId),$(output PreviewOuId),$(output ProductionOuId)"

aws cloudformation deploy --template-file infra/org-trail.yaml \
  --stack-name organization-trail --no-fail-on-empty-changeset \
  --parameter-overrides OrganizationId="$org_id"

aws cloudformation deploy --template-file infra/public-access-policies.yaml \
  --stack-name public-access-policies --no-fail-on-empty-changeset \
  --parameter-overrides TargetIds="$ous"

aws cloudformation deploy --template-file infra/rcp-identity-perimeter.yaml \
  --stack-name identity-perimeter-rcp --no-fail-on-empty-changeset \
  --parameter-overrides OrganizationId="$org_id" TargetIds="$ous"

scripts/check-security-baseline.sh
