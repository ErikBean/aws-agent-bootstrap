#!/usr/bin/env bash
# Simulate the agent boundary SCP before attaching it, as the deploy-permissions
# spec requires. SimulateCustomPolicy evaluates the SCP's statements alongside an
# allow-all policy, so each case shows whether the SCP denies the request.
# Needs credentials for any account; it calls only iam:SimulateCustomPolicy.
set -euo pipefail
cd "$(dirname "$0")/.."

scp=$(python3 - <<'PY'
import json, yaml
class Loader(yaml.SafeLoader): pass
Loader.add_multi_constructor("!", lambda loader, suffix, node: None)
t = yaml.load(open("infra/scp-agent-boundary.yaml"), Loader=Loader)
print(json.dumps(t["Resources"]["AgentBoundaryScp"]["Properties"]["Content"]))
PY
)
allow_all='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":"*","Resource":"*"}]}'

# Placeholder account; the SCP matches any account.
acct=111122223333
boundary="arn:aws:iam::$acct:policy/agent-boundary"
admin="arn:aws:iam::$acct:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_Admin_0123456789abcdef"
builder="arn:aws:iam::$acct:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_Agent-Builder_0123456789abcdef"

fails=0
check() { # expected action resource [context entries...]
  local expected=$1 action=$2 resource=$3; shift 3
  local got
  got=$(aws iam simulate-custom-policy \
    --policy-input-list "$allow_all" "$scp" \
    --action-names "$action" --resource-arns "$resource" \
    ${1:+--context-entries "$@"} \
    --query "EvaluationResults[0].EvalDecision" --output text)
  if [[ $got == "$expected" ]]; then echo "ok   $action $*: $got"; else echo "FAIL $action $*: $got, expected $expected"; fails=1; fi
}
ctx() { echo "ContextKeyName=$1,ContextKeyValues=$2,ContextKeyType=string"; }

check allowed      iam:CreateRole "arn:aws:iam::$acct:role/app" "$(ctx iam:PermissionsBoundary "$boundary")"
check explicitDeny iam:CreateRole "arn:aws:iam::$acct:role/app" "$(ctx iam:PermissionsBoundary "arn:aws:iam::$acct:policy/other")"
check explicitDeny iam:CreateRole "arn:aws:iam::$acct:role/app"
check explicitDeny iam:PutRolePermissionsBoundary "arn:aws:iam::$acct:role/app" "$(ctx iam:PermissionsBoundary "arn:aws:iam::$acct:policy/other")"
check explicitDeny iam:DeleteRolePermissionsBoundary "arn:aws:iam::$acct:role/app"
check allowed      iam:CreatePolicyVersion "$boundary" "$(ctx aws:PrincipalArn "$admin")"
check explicitDeny iam:CreatePolicyVersion "$boundary" "$(ctx aws:PrincipalArn "$builder")"
check allowed      iam:CreatePolicyVersion "arn:aws:iam::$acct:policy/app-policy" "$(ctx aws:PrincipalArn "$builder")"
exit $fails
