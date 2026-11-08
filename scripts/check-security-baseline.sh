#!/usr/bin/env bash
# Read-only checks of the management-account parts of the security baseline.
# Run in the management account.
set -euo pipefail

echo "Trails recording management events (expect only organization-trail):"
aws cloudtrail describe-trails --include-shadow-trails \
  --query "trailList[].[Name, IsOrganizationTrail, IsMultiRegionTrail, HomeRegion]" --output table

echo "Policy types on the organization root:"
aws organizations list-roots --query "Roots[0].PolicyTypes[].[Type, Status]" --output table

echo "Centralized root access for member accounts:"
aws iam list-organizations-features --query "EnabledFeatures" --output text
