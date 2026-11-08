#!/usr/bin/env bash
# Validate and simulate the SCP the agent account's budget action attaches. It
# must stop Identity Center and CDK roles creating or starting things while
# letting them read and delete, and must not affect app roles. Needs
# credentials for any account; calls only read-only APIs.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/lib-policy.sh

scp=$(policy_content infra/budgets.yaml BudgetDenyScp)
allow_all='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":"*","Resource":"*"}]}'
validate_scp "$scp"

acct=111122223333
builder="arn:aws:iam::$acct:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_Agent-Builder_0123456789abcdef"
cfn_exec="arn:aws:iam::$acct:role/cdk-hnb659fds-cfn-exec-role-$acct-us-east-1"
app="arn:aws:iam::$acct:role/agent/my-app-function-role"

fails=0
check() { # expected action principal
  local expected=$1 action=$2 principal=$3 got
  got=$(aws iam simulate-custom-policy --policy-input-list "$allow_all" "$scp" \
    --action-names "$action" --resource-arns "*" \
    --context-entries "ContextKeyName=aws:PrincipalArn,ContextKeyValues=$principal,ContextKeyType=string" \
    --query "EvaluationResults[0].EvalDecision" --output text)
  if [[ $got == "$expected" ]]; then echo "ok   $action as ${principal##*/}: $got"
  else echo "FAIL $action as ${principal##*/}: $got, expected $expected"; fails=1; fi
}

# People and deploys can't create, start or update
check explicitDeny lambda:CreateFunction "$builder"
check explicitDeny cloudformation:CreateStack "$builder"
check explicitDeny cloudformation:ExecuteChangeSet "$builder"
check explicitDeny dynamodb:CreateTable "$cfn_exec"
check explicitDeny states:StartExecution "$builder"
# ...but can read and delete, including cdk destroy
check allowed      lambda:GetFunction "$builder"
check allowed      cloudformation:DescribeStacks "$builder"
check allowed      cloudformation:DeleteStack "$builder"
check allowed      lambda:DeleteFunction "$cfn_exec"
check allowed      dynamodb:DeleteTable "$cfn_exec"
check allowed      iam:DeleteRole "$cfn_exec"
# Running apps aren't affected
check allowed      dynamodb:PutItem "$app"
check allowed      logs:CreateLogStream "$app"
check allowed      states:StartExecution "$app"
exit $fails
