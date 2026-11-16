# Agent Client Specification

## Purpose

How the developer's machine is set up so AI coding agents, such as Claude Code, get AWS access only through agent roles and GitHub access only through an agent GitHub App, and run inside a strict sandbox that keeps the developer's own credentials out of reach. These controls shape what agents try and protect the credentials themselves; the AWS-side specs are what AWS enforces.

Reasoning: [client setup decision](https://github.com/ErikBean/research/blob/main/knowledge/projects/aws-agent-bootstrap/decisions/agent-client-setup.md) and [GitHub access decision](https://github.com/ErikBean/research/blob/main/knowledge/projects/aws-agent-bootstrap/decisions/agent-github-access.md), which link the research behind them.

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

### Requirement: Agent sessions are short

The agent permission sets SHALL have a session duration of 4 hours, so credentials from them stop working within 4 hours.

#### Scenario: Reading the session duration

- **WHEN** the session duration of the builder or view-only permission set is read
- **THEN** it is 4 hours (`PT4H`)

### Requirement: The developer's admin session isn't left signed in

The developer SHALL sign out of their own Identity Center session (`aws sso logout`) when they finish administration, so no token for a user with admin assignments is in the cache while agents run. The runbook SHALL say so.

#### Scenario: Agents run after administration

- **WHEN** an agent session runs after the developer has finished administration
- **THEN** the AWS CLI's token cache holds no token for a user with admin assignments

### Requirement: Agent sessions see only agent profiles

Claude Code SHALL set `AWS_CONFIG_FILE` to a config file that defines only the agent user's sign-in and its builder and view-only profiles, and `AWS_PROFILE` to the builder profile.

#### Scenario: An agent lists AWS profiles

- **WHEN** an agent runs `aws configure list-profiles` in a session
- **THEN** only the agent profiles are listed

### Requirement: A strict sandbox

Claude Code SHALL run with the sandbox enabled, refusing to start if the sandbox is unavailable, with unsandboxed retries turned off. Sandboxed commands SHALL be allowed to reach `*.amazonaws.com`, `github.com`, `api.github.com`, `*.githubusercontent.com` and `registry.npmjs.org`, plus any hosts a project needs. Sandboxed commands SHALL be denied read access to the developer's admin session token file, the developer's SSH private keys and the agent GitHub App's private key, and SHALL NOT receive `SSH_AUTH_SOCK`. Sandboxed commands SHALL be able to write npm's cache (`~/.npm`) and, when the factory observer is on, its local bundle and notes (`~/.local/share/factory-observer`, `~/.local/state/factory-observer`).

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

#### Scenario: A command pushes with the developer's SSH key

- **WHEN** a sandboxed command runs `git ls-remote` or `git push` against GitHub over SSH
- **THEN** it fails, because neither the developer's key file nor their SSH agent is reachable

Reasoning: without these denies, a sandboxed `git` could still push with the developer's key ([finding](https://github.com/ErikBean/research/blob/main/knowledge/tech/github-agent-access/findings/sandbox-local-test-gh-ssh.md)).

### Requirement: No bypass mode

Claude Code SHALL set `permissions.disableBypassPermissionsMode` to `"disable"`.

#### Scenario: Starting in bypass mode

- **WHEN** Claude Code is started with `--dangerously-skip-permissions`
- **THEN** bypass mode isn't available

### Requirement: AWS credentials stay out of transcripts

Claude Code SHALL deny running `aws configure export-credentials`, `aws sso get-role-credentials` and `aws sts get-session-token`. It SHALL ask before reading files under `~/.aws`, through its Read tool (`Read(~/.aws/**)`) or a shell command that names them (`Bash(*.aws/*)`). The AWS CLI SHALL still be able to use its own config and token cache inside the sandbox.

These SHALL be ask rules, not deny rules. With the sandbox on, Claude Code adds Read deny rules to the sandbox's read blocks, which would stop the AWS CLI reading its own files ([finding](https://github.com/ErikBean/research/blob/main/knowledge/tech/aws-agent-guardrails/findings/claude-code-read-deny-scope.md)). A test on Claude Code 2.1.309 showed the Read ask rule alone doesn't stop `cat`, so the Bash ask rule is needed too ([finding](https://github.com/ErikBean/research/blob/main/knowledge/tech/aws-agent-guardrails/findings/claude-code-ask-rules-for-credentials-test.md)). These rules stop accidental exposure; they aren't a security boundary. Credential masking isn't required, for the reasons in the decision.

#### Scenario: Claude reads a file under ~/.aws

- **WHEN** Claude reads a file under `~/.aws` with its Read tool, or runs `cat` or `head` on one
- **THEN** Claude Code asks the developer first, and nothing from the file reaches the transcript unless they approve

#### Scenario: Claude runs a command that prints credentials

- **WHEN** Claude runs `aws configure export-credentials`
- **THEN** Claude Code denies the command

#### Scenario: The AWS CLI still works in the sandbox

- **WHEN** Claude runs `aws sts get-caller-identity` with the agent profile in a sandboxed command
- **THEN** it succeeds, using the cached sign-in

### Requirement: Agents reach GitHub only as an agent GitHub App

Agents SHALL reach GitHub only with installation tokens of a GitHub App owned by the developer, the agent app, installed on only the repositories agents work on. The agent app SHALL have Contents, Pull requests and Workflows write and read access to Actions and checks, and SHALL NOT have Administration or Variables permissions. It SHALL NOT be on any ruleset's bypass list. Repository administration, such as creating a repository, setting its variables, adding its rulesets and adding it to the agent app's installation, SHALL be done by the developer.

Reasoning: installation tokens expire after 1 hour and can't exceed the installation's repositories ([finding](https://github.com/ErikBean/research/blob/main/knowledge/tech/github-agent-access/findings/app-installation-tokens.md)); an actor allowed to bypass a ruleset for pull requests only can still merge past it ([finding](https://github.com/ErikBean/research/blob/main/knowledge/tech/github-agent-access/findings/ruleset-bypass-actors.md)).

#### Scenario: An agent opens a pull request

- **WHEN** an agent pushes a branch and opens a pull request on a repository in the agent app's installation
- **THEN** both succeed over HTTPS and the pull request is attributed to the agent app

#### Scenario: An agent works on a repository outside the installation

- **WHEN** an agent tries to push to a repository that isn't in the agent app's installation
- **THEN** the push fails

#### Scenario: An agent changes a ruleset

- **WHEN** an agent tries to change or delete a repository's ruleset
- **THEN** GitHub refuses, because the agent app has no Administration permission

### Requirement: Hooks mint agent GitHub tokens outside the sandbox

The agent app's private key SHALL be readable only by the developer's user and denied to sandboxed commands. Claude Code hooks, which run outside the sandbox, SHALL mint installation tokens from it into a token file that sandboxed commands can read but not write, and SHALL replace the token before it expires. A SessionStart hook SHALL make sandboxed commands read `GH_TOKEN` from that file through `CLAUDE_ENV_FILE`, and git SHALL use `GH_TOKEN` for HTTPS remotes on GitHub. The hook scripts SHALL live where sandboxed commands can't edit them, and SHALL NOT print the token.

Reasoning: a test showed hooks outside the sandbox can refresh a token that sandboxed commands read through `CLAUDE_ENV_FILE` ([finding](https://github.com/ErikBean/research/blob/main/knowledge/tech/github-agent-access/findings/claude-code-hook-token-refresh-test.md)).

#### Scenario: A session runs longer than an hour

- **WHEN** an agent pushes more than an hour after its session started
- **THEN** the push succeeds with a token minted within the last hour

#### Scenario: A command reads the app's private key

- **WHEN** a sandboxed command tries to read the agent app's private key
- **THEN** the read is denied

### Requirement: Each session's GitHub token covers only its project's repos

Each Claude Code session SHALL get its own token, kept in a token file for that session, so sessions running side by side don't share or overwrite tokens. The token SHALL cover only the repos of the folder the session started in, fixed for the session: the repos the developer maps to that folder in the hook's config, or else the GitHub repo the folder is in. A session started in a folder with neither SHALL get no token. The map SHALL live where sandboxed commands can't write it.

Reasoning: GitHub can narrow an installation token to named repositories when minting it ([finding](https://github.com/ErikBean/research/blob/main/knowledge/tech/github-agent-access/findings/app-installation-tokens.md)); scoping by the starting folder keeps a session from writing to repos it isn't working on, without a later change of folder widening it ([decision](https://github.com/ErikBean/research/blob/main/knowledge/projects/aws-agent-bootstrap/decisions/agent-github-access.md)).

#### Scenario: A session in one repo pushes to another

- **WHEN** a session started in one repo's folder tries to push to a different repo in the agent app's installation
- **THEN** GitHub refuses the push

#### Scenario: A session in a mapped parent folder

- **WHEN** a session starts in a folder the config maps to several repos
- **THEN** its token can write to exactly those repos

#### Scenario: Two sessions at once

- **WHEN** two sessions started in different repos run at the same time
- **THEN** each keeps its own token, scoped to its own repo
