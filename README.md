# aws-agent-bootstrap

Requirements and account-level setup for an AWS account where one developer lets AI coding agents, such as Claude Code, create things without surprise costs, security holes or a mess to clean up.

It's a reference for other projects and tools. The specs say what a safe agent account and machine look like. The code here sets up the account itself, once per account. Setting up each project repo, such as its deploy role and CI, is done by the `factory-repo-setup` skill in [ErikBean/factory-skills](https://github.com/ErikBean/factory-skills), following these specs. There's no app code here.

- Requirements: [`openspec/specs/`](openspec/specs)
- Research and decisions behind them: [ErikBean/research](https://github.com/ErikBean/research/tree/main/knowledge/tech/aws-agent-guardrails)

- Code: [`infra/`](infra) holds the CloudFormation templates, deployed by the scripts in [`scripts/`](scripts). Real account values are read from gitignored config in `config.local/`.
- Manual steps: [`RUNBOOK.md`](RUNBOOK.md)

Status: [`account-structure`](openspec/specs/account-structure/spec.md), [`deploy-permissions`](openspec/specs/deploy-permissions/spec.md) and [`agent-permissions`](openspec/specs/agent-permissions/spec.md) have code. Until the organization's account quota allows member accounts, the runbook's interim section runs agents and apps in the management account.

This repo is public and contains no values from a real account. See [AGENTS.md](AGENTS.md) for how that is kept true.
