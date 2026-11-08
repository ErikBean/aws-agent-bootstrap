#!/usr/bin/env bash
# Test the spend-controls SCP, then attach it to the Agents and Production OUs.
# Run in the management account.
set -euo pipefail
cd "$(dirname "$0")/.."

scripts/test-scp-spend-controls.sh

output() {
  aws cloudformation describe-stacks --stack-name agent-account-structure \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text
}
aws cloudformation deploy \
  --template-file infra/scp-spend-controls.yaml \
  --stack-name spend-controls-scp \
  --no-fail-on-empty-changeset \
  --parameter-overrides TargetIds="$(output AgentsOuId),$(output ProductionOuId)"
