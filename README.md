# aws-agent-bootstrap

Specs and code for setting up an AWS account so one developer can let AI coding agents, such as Claude Code, create things in it without surprise costs, security holes or a mess to clean up.

The goal is that starting over with a fresh AWS account is a deploy plus a short runbook.

- Requirements: [`openspec/specs/`](openspec/specs)
- Research and decisions behind them: [ErikBean/research](https://github.com/ErikBean/research/tree/main/knowledge/tech/aws-agent-guardrails)

- Code: [`infra/`](infra) holds the CloudFormation templates, deployed by the scripts in [`scripts/`](scripts). Real account values are read from gitignored config in `config.local/`.
- Manual steps: [`RUNBOOK.md`](RUNBOOK.md)

Status: the agent account ([`account-structure`](openspec/specs/account-structure/spec.md)) has code. The other specs don't yet.

This repo is public and contains no values from a real account. See [AGENTS.md](AGENTS.md) for how that is kept true.
