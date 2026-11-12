#!/usr/bin/env bash
# Check the deploy-permissions spec in one member account: every CDK bootstrap
# role carries the agent boundary, in CDKToolkit and in CDKToolkit-ci if it
# exists, and creating a role without the boundary is denied.
# The last check really calls iam:CreateRole; if it unexpectedly succeeds, the
# role is deleted straight away. It needs the boundary SCP, so it's skipped in
# the management account, where SCPs don't apply.
#
# Usage: scripts/check-deploy-permissions.sh <admin-profile-for-the-member-account> [region]
set -euo pipefail
profile=${1:?usage: $0 <admin-profile> [region]}
region=${2:-us-east-1}
aws=(aws --profile "$profile" --region "$region")
account=$("${aws[@]}" sts get-caller-identity --query Account --output text)
boundary="arn:aws:iam::$account:policy/agent-boundary"
status=0

roles=""
for stack in CDKToolkit CDKToolkit-ci; do
  if ! "${aws[@]}" cloudformation describe-stacks --stack-name "$stack" >/dev/null 2>&1; then
    [[ $stack == CDKToolkit ]] && { echo "FAIL no CDKToolkit stack"; status=1; }
    continue
  fi
  roles+=" $("${aws[@]}" cloudformation describe-stack-resources --stack-name "$stack" \
    --query "StackResources[?ResourceType=='AWS::IAM::Role'].PhysicalResourceId" --output text)"
done
for role in $roles; do
  got=$("${aws[@]}" iam get-role --role-name "$role" \
    --query "Role.PermissionsBoundary.PermissionsBoundaryArn" --output text)
  if [[ $got == "$boundary" ]]; then echo "ok   $role carries the agent boundary"
  else echo "FAIL $role has boundary $got"; status=1; fi
done

management=$("${aws[@]}" organizations describe-organization \
  --query Organization.MasterAccountId --output text 2>/dev/null || true)
if [[ $management == "$account" ]]; then
  echo "skip the unbounded-role check: this is the management account, where the boundary SCP doesn't apply"
  exit $status
fi

trust='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
if out=$("${aws[@]}" iam create-role --role-name agent-boundary-check-unbounded \
    --assume-role-policy-document "$trust" 2>&1); then
  echo "FAIL created a role without the agent boundary; deleting it"
  "${aws[@]}" iam delete-role --role-name agent-boundary-check-unbounded
  status=1
elif [[ $out == *AccessDenied* ]]; then
  echo "ok   creating a role without the agent boundary is denied"
else
  echo "FAIL unexpected error: $out"; status=1
fi
exit $status
