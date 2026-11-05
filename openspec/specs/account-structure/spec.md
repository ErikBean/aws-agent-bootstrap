# Account Structure Specification

## Purpose

Where AI coding agents get AWS access. Agents work in a dedicated member account of the developer's AWS Organization, so that service control policies and budget actions can limit them, and the management account stays free of workloads.

Reasoning: [decision](https://github.com/ErikBean/research/blob/main/knowledge/projects/aws-agent-bootstrap/decisions/agents-work-in-member-account.md), which links the research behind it.

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

### Requirement: The agent account is governed by the organization

The agent account SHALL be a member of the developer's organization, so that service control policies attached to it, or to an organizational unit containing it, apply to every user and role in it.

Reasoning: SCPs don't affect the management account, only member accounts ([finding](https://github.com/ErikBean/research/blob/main/knowledge/tech/aws-agent-guardrails/findings/scps-skip-management-account.md)).

#### Scenario: An SCP applies to the agent account

- **WHEN** an SCP that denies an action is attached to the agent account
- **THEN** a request for that action from any role in the agent account, including an agent's, is denied
