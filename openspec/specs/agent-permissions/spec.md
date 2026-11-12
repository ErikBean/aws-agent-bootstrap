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

### Requirement: The builder can't change identity, budgets, the audit trail or billing

The builder permission set SHALL deny IAM Identity Center, Identity Store and directory actions, and changes to Budgets, CloudTrail, billing, payments, tax, Cost Explorer and Free Tier alerts. Reading budgets and trail events stays allowed.

Reasoning: `PowerUserAccess` allows these ([finding](https://github.com/ErikBean/research/blob/main/knowledge/tech/aws-agent-guardrails/findings/poweruser-allows-identity-center-and-audit-changes.md)), and no SCP covers the management account ([decision](https://github.com/ErikBean/research/blob/main/knowledge/projects/aws-agent-bootstrap/decisions/interim-management-account.md)).

#### Scenario: An agent tries to assign itself a permission set

- **WHEN** the builder calls `sso:CreateAccountAssignment`
- **THEN** the request is denied

#### Scenario: An agent tries to stop the trail or change a budget

- **WHEN** the builder calls `cloudtrail:StopLogging` or `budgets:ModifyBudget`
- **THEN** the request is denied

#### Scenario: An agent reads a budget

- **WHEN** the builder calls `budgets:ViewBudget`
- **THEN** the request is allowed

### Requirement: The builder can't deploy or change stages only CI deploys

The builder permission set SHALL deny `sts:AssumeRole` on the `ci` qualifier's CDK bootstrap roles, and every action on resources tagged `stage=prod` or `stage=preview`. The tag deny covers only actions that support the `aws:ResourceTag` condition key.

Reasoning: this matters where `dev` shares an account with `preview` or `prod` ([decision](https://github.com/ErikBean/research/blob/main/knowledge/projects/aws-agent-bootstrap/decisions/interim-management-account.md)).

#### Scenario: An agent deploys to prod from its machine

- **WHEN** the builder tries to assume a `cdk-ci-*` role
- **THEN** the request is denied

#### Scenario: An agent changes a prod stack directly

- **WHEN** the builder calls a CloudFormation action on a stack tagged `stage=prod`
- **THEN** the request is denied

#### Scenario: An agent works on its own dev stack

- **WHEN** the builder calls a CloudFormation action on a stack tagged `stage=dev`
- **THEN** the request is allowed
