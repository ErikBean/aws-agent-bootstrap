#!/usr/bin/env bash
# Validate the identity-perimeter RCP with Access Analyzer before attaching it.
# The IAM policy simulator doesn't support RCPs, so this checks only that the
# policy is valid. Its behaviour is tested on the empty member accounts after
# attaching it; see RUNBOOK.md. Calls only accessanalyzer:ValidatePolicy.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/lib-policy.sh

validate_policy RESOURCE_CONTROL_POLICY \
  "$(policy_content infra/rcp-identity-perimeter.yaml IdentityPerimeterRcp)"
