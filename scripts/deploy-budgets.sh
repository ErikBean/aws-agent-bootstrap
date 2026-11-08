#!/usr/bin/env bash
# Test the budget deny SCP, then deploy the member accounts' budgets and the
# agent account's budget action. Run in the management account, after the
# account-structure stack exists.
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; source config.local/account-structure.env; set +a

scripts/test-scp-budget-deny.sh

output() {
  aws cloudformation describe-stacks --stack-name agent-account-structure \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text
}
aws cloudformation deploy \
  --template-file infra/budgets.yaml \
  --stack-name member-account-budgets \
  --capabilities CAPABILITY_IAM \
  --no-fail-on-empty-changeset \
  --parameter-overrides \
    AgentAccountId="$(output AgentAccountId)" \
    ProductionAccountId="$(output ProductionAccountId)" \
    AlertEmail="$BUDGET_ALERT_EMAIL"
