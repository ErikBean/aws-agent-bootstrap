# shellcheck shell=bash
# Shared helpers for the SCP test scripts. Source it; don't run it.

# Print the JSON content of an AWS::Organizations::Policy resource in a template.
policy_content() { # template resource
  python3 - "$1" "$2" <<'PY'
import json, sys, yaml
class Loader(yaml.SafeLoader): pass
Loader.add_multi_constructor("!", lambda loader, suffix, node: None)
t = yaml.load(open(sys.argv[1]), Loader=Loader)
print(json.dumps(t["Resources"][sys.argv[2]]["Properties"]["Content"]))
PY
}

# Fail if Access Analyzer's free policy validation reports any error or
# security warning for an SCP. Suggestions and plain warnings are printed only.
validate_scp() { # policy-json
  local findings
  findings=$(aws accessanalyzer validate-policy --policy-type SERVICE_CONTROL_POLICY \
    --policy-document "$1" \
    --query "findings[].[findingType, issueCode, findingDetails]" --output text)
  if [[ -n $findings ]]; then echo "$findings"; fi
  if grep -qE '^(ERROR|SECURITY_WARNING)' <<<"$findings"; then
    echo "FAIL validate-policy reported errors"; return 1
  fi
  echo "ok   validate-policy"
}
