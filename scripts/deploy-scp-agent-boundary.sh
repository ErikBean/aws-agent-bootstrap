#!/usr/bin/env bash
# Test the agent boundary SCP in the policy simulator, then attach it to the
# Agents and Production OUs. Run in the management account, after every member
# account has the agent boundary and its CDK bootstrap.
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; source config.local/account-structure.env; set +a

scripts/test-scp-agent-boundary.sh

output() {
  aws cloudformation describe-stacks --stack-name agent-account-structure \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text
}
aws cloudformation deploy \
  --template-file infra/scp-agent-boundary.yaml \
  --stack-name agent-boundary-scp \
  --no-fail-on-empty-changeset \
  --parameter-overrides TargetIds="$(output AgentsOuId),$(output ProductionOuId)"
