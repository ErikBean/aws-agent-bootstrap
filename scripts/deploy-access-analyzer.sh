#!/usr/bin/env bash
# Deploy an external access analyzer in one member account, in both Regions the
# account may use. Run once per member account, with an Admin profile for that
# account:
#   scripts/deploy-access-analyzer.sh <aws-profile>
set -euo pipefail
cd "$(dirname "$0")/.."
profile=${1:?usage: $0 <aws-profile for a member account>}

for region in us-east-1 us-west-2; do
  aws cloudformation deploy --template-file infra/access-analyzer.yaml \
    --stack-name access-analyzer --no-fail-on-empty-changeset \
    --profile "$profile" --region "$region"
done
