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
check() { # expected action resource [passed-to-service] [stage tag]
  local expected=$1 action=$2 resource=$3 service=${4:-} stage=${5:-} got ctx=()
  [[ -n $service ]] && ctx+=("ContextKeyName=iam:PassedToService,ContextKeyValues=$service,ContextKeyType=string")
  [[ -n $stage ]] && ctx+=("ContextKeyName=aws:ResourceTag/stage,ContextKeyValues=$stage,ContextKeyType=string")
  got=$(aws iam simulate-custom-policy --policy-input-list "$poweruser" "$inline" \
    --action-names "$action" --resource-arns "$resource" \
    ${ctx[@]+--context-entries "${ctx[@]}"} \
    --query "EvaluationResults[0].EvalDecision" --output text)
  if [[ $got == "$expected" ]]; then echo "ok   $action $resource $service $stage: $got"
  else echo "FAIL $action $resource $service $stage: $got, expected $expected"; fails=1; fi
}

check implicitDeny iam:CreateRole "arn:aws:iam::$acct:role/agent/app"
check implicitDeny iam:AttachRolePolicy "arn:aws:iam::$acct:role/agent/app"
check implicitDeny iam:CreatePolicy "arn:aws:iam::$acct:policy/app"
check allowed      iam:PassRole "arn:aws:iam::$acct:role/agent/app" lambda.amazonaws.com
check implicitDeny iam:PassRole "arn:aws:iam::$acct:role/cdk-hnb659fds-cfn-exec-role-$acct-us-east-1" lambda.amazonaws.com
check implicitDeny iam:PassRole "arn:aws:iam::$acct:role/agent/app" ecs-tasks.amazonaws.com
check explicitDeny aws-marketplace:Subscribe "*"

# Interim management-account mode: no identity, budget, trail or billing changes.
check explicitDeny sso:CreateAccountAssignment "*"
check explicitDeny sso:AttachManagedPolicyToPermissionSet "*"
check explicitDeny identitystore:CreateUser "*"
check explicitDeny budgets:ModifyBudget "*"
check explicitDeny budgets:DeleteBudgetAction "*"
check allowed      budgets:ViewBudget "*"
check explicitDeny cloudtrail:StopLogging "*"
check explicitDeny cloudtrail:DeleteTrail "*"
check allowed      cloudtrail:LookupEvents "*"
check explicitDeny ce:DeleteAnomalyMonitor "*"

# CI-deployed stages: the ci bootstrap's roles and anything tagged prod or preview.
check explicitDeny sts:AssumeRole "arn:aws:iam::$acct:role/cdk-ci-deploy-role-$acct-us-east-1"
check allowed      sts:AssumeRole "arn:aws:iam::$acct:role/cdk-hnb659fds-deploy-role-$acct-us-east-1"
check explicitDeny cloudformation:DeleteStack "arn:aws:cloudformation:us-east-1:$acct:stack/app/1" "" prod
check explicitDeny s3:PutObject "arn:aws:s3:::app-site/index.html" "" preview
check allowed      cloudformation:DeleteStack "arn:aws:cloudformation:us-east-1:$acct:stack/app-dev-main/1" "" dev
exit $fails
