#!/usr/bin/env bash
# Simulate the builder permission set, PowerUserAccess plus
# infra/agent-builder-inline-policy.json, against the agent-permissions spec's
# scenarios. Calls only read-only IAM APIs and iam:SimulateCustomPolicy.
set -euo pipefail
cd "$(dirname "$0")/.."

arn=arn:aws:iam::aws:policy/PowerUserAccess
version=$(aws iam get-policy --policy-arn $arn --query Policy.DefaultVersionId --output text)
poweruser=$(aws iam get-policy-version --policy-arn $arn --version-id "$version" \
  --query PolicyVersion.Document --output json)
inline=$(python3 -c 'import json; print(json.dumps(json.load(open("infra/agent-builder-inline-policy.json"))))')

acct=111122223333
fails=0
check() { # expected action resource [passed-to-service]
  local expected=$1 action=$2 resource=$3 service=${4:-} got
  got=$(aws iam simulate-custom-policy --policy-input-list "$poweruser" "$inline" \
    --action-names "$action" --resource-arns "$resource" \
    ${service:+--context-entries "ContextKeyName=iam:PassedToService,ContextKeyValues=$service,ContextKeyType=string"} \
    --query "EvaluationResults[0].EvalDecision" --output text)
  if [[ $got == "$expected" ]]; then echo "ok   $action $resource $service: $got"
  else echo "FAIL $action $resource $service: $got, expected $expected"; fails=1; fi
}

check implicitDeny iam:CreateRole "arn:aws:iam::$acct:role/agent/app"
check implicitDeny iam:AttachRolePolicy "arn:aws:iam::$acct:role/agent/app"
check implicitDeny iam:CreatePolicy "arn:aws:iam::$acct:policy/app"
check allowed      iam:PassRole "arn:aws:iam::$acct:role/agent/app" lambda.amazonaws.com
check implicitDeny iam:PassRole "arn:aws:iam::$acct:role/cdk-hnb659fds-cfn-exec-role-$acct-us-east-1" lambda.amazonaws.com
check implicitDeny iam:PassRole "arn:aws:iam::$acct:role/agent/app" ecs-tasks.amazonaws.com
check explicitDeny aws-marketplace:Subscribe "*"
exit $fails
