# Account Structure Specification

## Purpose

Where AI coding agents get AWS access, and where the apps they build run in production. Agents work in a dedicated member account of the developer's AWS Organization, so that service control policies and budget actions can limit them, and the management account stays free of workloads. Production apps run in a second member account that agents can't sign in to.

Reasoning: decisions on [the agent account](https://github.com/ErikBean/research/blob/main/knowledge/projects/aws-agent-bootstrap/decisions/agents-work-in-member-account.md) and [the production account](https://github.com/ErikBean/research/blob/main/knowledge/projects/aws-agent-bootstrap/decisions/production-in-shared-account.md), which link the research behind them.

## Requirements

### Requirement: Agents work in a dedicated member account

The organization SHALL include a member account used only for agent work, referred to here as the agent account. Every IAM Identity Center permission set meant for agents SHALL be assigned to the agent account and to no other account.

#### Scenario: An agent signs in

- **WHEN** an agent signs in through IAM Identity Center with an agent permission set
- **THEN** the agent account is the only account it can open a session in

#### Scenario: Listing an agent permission set's assignments

- **WHEN** the account assignments of any agent permission set are listed
- **THEN** the agent account is the only account in the list

### Requirement: Agents have no access to the management account

No agent permission set SHALL be assigned to the organization's management account. The management account SHALL be used only for organization, billing and IAM Identity Center administration, by the developer.

#### Scenario: An agent tries to use the management account

- **WHEN** an agent attempts to sign in to the management account
- **THEN** IAM Identity Center offers it no role there

### Requirement: Production apps run in a shared production account

The organization SHALL include one member account for production workloads, referred to here as the production account, shared by every app. No agent permission set SHALL be assigned to it. Changes SHALL reach it only through each app's CI deploy role.

Reasoning: [decision](https://github.com/ErikBean/research/blob/main/knowledge/projects/aws-agent-bootstrap/decisions/production-in-shared-account.md).

#### Scenario: An agent tries to use the production account

- **WHEN** an agent attempts to sign in to the production account with an agent permission set
- **THEN** IAM Identity Center offers it no role there

#### Scenario: An app ships to production

- **WHEN** a pull request to an app's repo passes CI and is merged to its default branch
- **THEN** the app's CI deploy role deploys it to the production account

### Requirement: Pull request previews run in a separate preview account

The organization SHALL include one member account for pull request previews, referred to here as the preview account. Only CI SHALL deploy to it, through each app's preview deploy role. The agent user SHALL have only the Agent-ReadOnly permission set there, so agents can read logs and stack events but can't change a preview. Agent-Builder SHALL NOT be assigned to it.

Reasoning: [decision](https://github.com/ErikBean/research/blob/main/knowledge/projects/aws-agent-bootstrap/decisions/app-environments.md).

#### Scenario: An agent tries to change a preview

- **WHEN** an agent signs in to the preview account and tries to update a preview's stack or resources
- **THEN** it can only sign in with Agent-ReadOnly, and the change is denied

#### Scenario: An agent debugs a failed preview

- **WHEN** an agent reads a preview stack's events and its Lambda function's logs
- **THEN** the reads succeed

### Requirement: The developer can administer the member accounts

The developer's admin permission set SHALL be assigned to every member account: the agent, preview and production accounts, so that setup steps such as CDK bootstrap can run there without root credentials. It SHALL be assigned to the developer's own Identity Center user, never to the agent user, because a cached token can reach every role assigned to its user ([finding](https://github.com/ErikBean/research/blob/main/knowledge/tech/aws-agent-guardrails/findings/sso-token-reaches-every-assigned-role.md)).

#### Scenario: The developer bootstraps CDK

- **WHEN** the developer signs in to a member account with the admin permission set
- **THEN** they can deploy CloudFormation stacks and create IAM roles there, subject to the account's SCPs

#### Scenario: The agent user lists its roles

- **WHEN** the agent user's assignments are listed
- **THEN** they include no admin permission set in any account

### Requirement: The member accounts are governed by the organization

The agent, preview and production accounts SHALL be members of the developer's organization, each in its own organizational unit, so that service control policies attached to them, or to their organizational units, apply to every user and role in them.

Reasoning: SCPs don't affect the management account, only member accounts ([finding](https://github.com/ErikBean/research/blob/main/knowledge/tech/aws-agent-guardrails/findings/scps-skip-management-account.md)).

#### Scenario: An SCP applies to a member account

- **WHEN** an SCP that denies an action is attached to a member account, or to its organizational unit
- **THEN** a request for that action from any role in that account, including an agent's or a CI deploy role's, is denied
