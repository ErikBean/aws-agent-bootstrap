# Working in this repo

This repo sets up an AWS account so AI coding agents can work in it safely. It holds:

- `openspec/`: requirements as [OpenSpec](https://github.com/Fission-AI/OpenSpec) specs. `specs/` is what the account must look like now; `changes/` holds proposed changes.
- The code that builds the account, once its specs are settled.
- `RUNBOOK.md`, once there are steps that can't be automated.

## Research lives elsewhere

The reasoning behind each requirement is in [ErikBean/research](https://github.com/ErikBean/research): findings in `knowledge/tech/aws-agent-guardrails/`, and decisions in `knowledge/projects/aws-agent-bootstrap/`. Specs cite those files by GitHub URL. If a spec or the code changes what's true, update the research there rather than copying it here.

## This repo is public: keep private values out

Never commit:

- AWS account IDs, organization IDs (`o-...`), root IDs (`r-...`), OU IDs (`ou-...`), Identity Center instance or store IDs (`ssoins-...`, `d-...`), or ARNs containing any of these
- Email addresses, names, user names or phone numbers
- Access keys, secrets, tokens, or anything from `~/.aws/`
- Output from commands run against a real account, such as `aws sts get-caller-identity`

Instead:

- In specs, docs and tests, use AWS's documentation placeholders: account IDs `111122223333` and `444455556666`, and `example.com` addresses.
- In code, read real values from environment variables or a gitignored local file. Anything matching `*.local.*`, `.env` or `config.local/` is ignored.

`scripts/check-private.py` scans for these values. It runs before each commit once hooks are turned on, and in CI on every push:

```bash
git config core.hooksPath .githooks   # once per clone
python3 scripts/check-private.py      # scan all tracked files
```

If it flags something that isn't private, change the text to a placeholder rather than weakening the check.
