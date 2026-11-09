#!/usr/bin/env bash
# Validate and simulate the spend-controls SCP before attaching it. Needs
# credentials for any account; calls only accessanalyzer:ValidatePolicy and
# iam:SimulateCustomPolicy, both read-only.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/lib-policy.sh

scp=$(policy_content infra/scp-spend-controls.yaml SpendControlsScp)
allow_all='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":"*","Resource":"*"}]}'
validate_scp "$scp"

fails=0
check() { # expected action region
  local expected=$1 action=$2 region=$3 got
  got=$(aws iam simulate-custom-policy --policy-input-list "$allow_all" "$scp" \
    --action-names "$action" --resource-arns "*" \
    --context-entries "ContextKeyName=aws:RequestedRegion,ContextKeyValues=$region,ContextKeyType=string" \
    --query "EvaluationResults[0].EvalDecision" --output text)
  if [[ $got == "$expected" ]]; then echo "ok   $action in $region: $got"
  else echo "FAIL $action in $region: $got, expected $expected"; fails=1; fi
}

# Regions
check explicitDeny lambda:CreateFunction eu-west-1
check allowed      lambda:CreateFunction us-west-2
check allowed      lambda:CreateFunction us-east-1
check allowed      cloudfront:CreateDistribution eu-west-1   # global service
check allowed      iam:CreateRole eu-west-1                  # global service
# EC2 instances, but not the rest of EC2
check explicitDeny ec2:RunInstances us-east-1
check explicitDeny ec2:CreateFleet us-east-1
check allowed      ec2:CreateSecurityGroup us-east-1
# Bedrock
check explicitDeny bedrock:InvokeModel us-east-1
check explicitDeny bedrock-mantle:CreateInference us-east-1
# Fixed-cost services, but not DynamoDB
check explicitDeny ec2:CreateNatGateway us-east-1
check explicitDeny elasticloadbalancing:CreateLoadBalancer us-east-1
check explicitDeny rds:CreateDBInstance us-east-1
check explicitDeny sagemaker:CreateEndpoint us-east-1
check allowed      dynamodb:CreateTable us-east-1
exit $fails
