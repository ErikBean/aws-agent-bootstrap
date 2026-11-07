# Agent Client Specification

## Purpose

How the developer's machine is set up so AI coding agents, such as Claude Code, get AWS access only through agent roles, and run inside a strict sandbox. These controls shape what agents try and protect the credentials themselves; the AWS-side specs are what AWS enforces.

Reasoning: [decision](https://github.com/ErikBean/research/blob/main/knowledge/projects/aws-agent-bootstrap/decisions/agent-client-setup.md), which links the research behind it.

Example files: [`client/claude-settings.example.json`](../../../client/claude-settings.example.json) and [`client/aws-agent-config.example`](../../../client/aws-agent-config.example).

## Requirements

### Requirement: Agents sign in as a dedicated agent user

IAM Identity Center SHALL have a user used only by agents, the agent user. Its only assignments SHALL be the builder and view-only permission sets in the agent account. Agent sessions SHALL sign in to AWS only as the agent user.

Reasoning: a cached Identity Center token can likely obtain credentials for every role assigned to the signed-in user, whichever profile requested it ([finding](https://github.com/ErikBean/research/blob/main/knowledge/tech/aws-agent-guardrails/findings/sso-token-reaches-every-assigned-role.md)).

#### Scenario: An agent lists the roles it can reach

- **WHEN** an agent uses its cached token to list the accounts and roles available to it
- **THEN** the only results are the builder and view-only roles in the agent account

#### Scenario: An agent tries to get admin credentials

- **WHEN** an agent requests credentials for an admin permission set with its cached token
- **THEN** the request fails, because the agent user has no such assignment

### Requirement: The developer's admin session isn't left signed in

The developer SHALL sign out of their own Identity Center session (`aws sso logout`) when they finish administration, so no token for a user with admin assignments is in the cache while agents run. The runbook SHALL say so.

### Requirement: Agent sessions see only agent profiles

Claude Code SHALL set `AWS_CONFIG_FILE` to a config file that defines only the agent user's sign-in and its builder and view-only profiles, and `AWS_PROFILE` to the builder profile.

#### Scenario: An agent lists AWS profiles

- **WHEN** an agent runs `aws configure list-profiles` in a session
- **THEN** only the agent profiles are listed

### Requirement: A strict sandbox

Claude Code SHALL run with the sandbox enabled, refusing to start if the sandbox is unavailable, with unsandboxed retries turned off. Sandboxed commands SHALL be allowed to reach `*.amazonaws.com`, plus any hosts a project needs. Sandboxed commands SHALL be denied read access to the developer's admin session token file.

Reasoning: the sandbox covers only shell commands; MCP servers, hooks and Claude's file tools run outside it ([finding](https://github.com/ErikBean/research/blob/main/knowledge/tech/aws-agent-guardrails/findings/claude-code-sandbox-shell-only.md)).

#### Scenario: The sandbox can't start

- **WHEN** Claude Code starts on a machine where the sandbox can't run
- **THEN** Claude Code refuses to start rather than running commands unsandboxed

#### Scenario: A command is blocked by the sandbox

- **WHEN** a sandboxed command fails because the sandbox blocked it
- **THEN** Claude Code doesn't retry it outside the sandbox

#### Scenario: A command reads the admin token

- **WHEN** a sandboxed command tries to read the developer's admin session token file
- **THEN** the read is denied

### Requirement: No bypass mode

Claude Code SHALL set `permissions.disableBypassPermissionsMode` to `"disable"`.

#### Scenario: Starting in bypass mode

- **WHEN** Claude Code is started with `--dangerously-skip-permissions`
- **THEN** bypass mode isn't available
