# Agent Permissions Specification

## Purpose

What the builder permission set, the IAM Identity Center permission set agents use to create things, may do with IAM in the agent account. Agents create roles only through CDK deploys, which [deploy-permissions](../deploy-permissions/spec.md) covers. Directly, the builder may only pass existing agent roles to a short list of services.

Reasoning: [decision](https://github.com/ErikBean/research/blob/main/knowledge/projects/aws-agent-bootstrap/decisions/builder-has-no-direct-iam.md), which links the research behind it.

## Requirements

### Requirement: The builder can't manage IAM roles or policies directly

The builder permission set SHALL NOT allow creating, updating or deleting IAM roles, users, groups or policies, or attaching or detaching policies, other than the service-linked role actions included in `PowerUserAccess`.

#### Scenario: An agent tries to create a role from the CLI

- **WHEN** an agent signed in with the builder permission set calls `iam:CreateRole`
- **THEN** the request is denied

#### Scenario: An agent creates a role through CDK

- **WHEN** an agent with the builder permission set deploys a CDK app that defines a role
- **THEN** the role is created by CloudFormation under the agent boundary, as deploy-permissions requires

### Requirement: The builder may pass only agent roles, only to allowed services

The builder permission set SHALL allow `iam:PassRole` only on roles whose path is `/agent/`, and only when `iam:PassedToService` is one of the allowed services below. It SHALL NOT allow passing any other role.

Allowed services:

- `lambda.amazonaws.com`

Adding a service is a change to this spec.

Reasoning: [finding](https://github.com/ErikBean/research/blob/main/knowledge/tech/aws-agent-guardrails/findings/passrole-scoping.md).

#### Scenario: Passing an agent role to an allowed service

- **WHEN** the builder passes a role under `/agent/` to a service on the allowed list
- **THEN** the request is allowed

#### Scenario: Passing a role outside the agent path

- **WHEN** the builder passes a role that isn't under `/agent/`, such as a CDK bootstrap role
- **THEN** the request is denied

#### Scenario: Passing an agent role to another service

- **WHEN** the builder passes a role under `/agent/` to a service not on the allowed list
- **THEN** the request is denied
