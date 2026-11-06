# Deploy Permissions Specification

## Purpose

What a deploy can create when it runs with the AWS CDK in a member account: the agent account, where agents deploy, and the production account, where CI deploys. Deploys work, but everything they run as or create is capped by one permissions boundary that nothing in the account can remove or weaken.

Reasoning: [decision](https://github.com/ErikBean/research/blob/main/knowledge/projects/aws-agent-bootstrap/decisions/cdk-deploys-under-permissions-boundary.md), which links the research behind it. It covers the production account too, because [production apps deploy there through CDK](https://github.com/ErikBean/research/blob/main/knowledge/projects/aws-agent-bootstrap/decisions/production-in-shared-account.md).

The boundary is referred to here as the agent boundary. It's a customer managed policy named `agent-boundary` in each member account.

## Requirements

### Requirement: An owned agent boundary with anti-escape rules

Each member account SHALL have a customer managed policy, the agent boundary, maintained by the account-level setup, not by any app. Starting from the AWS CDK's example boundary, it SHALL deny:

- creating an IAM role or user unless the agent boundary is its permissions boundary
- setting any permissions boundary other than the agent boundary on a role or user
- creating, deleting or setting the default version of the agent boundary policy, or deleting it
- removing a permissions boundary from any role or user

It MAY also deny services or actions, as other specs require.

#### Scenario: A deploy creates a role without the boundary

- **WHEN** a deploy tries to create an IAM role without the agent boundary attached
- **THEN** the request is denied

#### Scenario: A deploy tries to weaken the boundary

- **WHEN** any role carrying the agent boundary tries to edit the agent boundary policy, attach a different boundary, or remove a boundary
- **THEN** the request is denied

### Requirement: CDK bootstrap roles carry the agent boundary

Each member account SHALL be bootstrapped with the agent boundary as the custom permissions boundary, applied to all bootstrap roles, not only the CloudFormation execution role. Re-bootstrapping SHALL keep both settings.

Reasoning: by default CDK's execution role has `AdministratorAccess` with no boundary ([finding](https://github.com/ErikBean/research/blob/main/knowledge/tech/aws-agent-guardrails/findings/cdk-bootstrap-roles-admin-by-default.md)), and the boundary reaches the other bootstrap roles only with `--apply-permissions-boundary-to-all-roles` ([finding](https://github.com/ErikBean/research/blob/main/knowledge/tech/aws-agent-guardrails/findings/cdk-boundary-on-all-bootstrap-roles.md)).

#### Scenario: Inspecting the bootstrap roles

- **WHEN** the permissions boundary of each CDK bootstrap role in a member account is read
- **THEN** every one is the agent boundary

#### Scenario: Re-bootstrapping

- **WHEN** a member account is bootstrapped again through the account-level setup
- **THEN** the bootstrap roles still carry the agent boundary

### Requirement: CDK apps attach the boundary to the roles they create

Every CDK app deployed to a member account SHALL set the `@aws-cdk/core:permissionsBoundary` context key to the agent boundary.

Reasoning: [finding](https://github.com/ErikBean/research/blob/main/knowledge/tech/aws-agent-guardrails/findings/cdk-boundary-app-wide.md). An open CDK bug (aws/aws-cdk#30179) leaves a custom-resource role out; under the agent boundary that deploy fails rather than creating an unbounded role.

#### Scenario: An app deploys a Lambda function with its own role

- **WHEN** an app that sets the context key deploys a function whose role it defines
- **THEN** the function's role carries the agent boundary

### Requirement: An SCP backs up the anti-escape rules

The member accounts SHALL have an SCP that denies the same anti-escape actions as the agent boundary, so they hold even if the boundary policy is changed by an administrator in the account. The SCP MAY let the developer's admin permission set edit the boundary policy, so the boundary can change through this repo's code. It SHALL NOT exempt anyone from the denial of creating a role or user without the agent boundary.

This requirement takes effect only after a policy simulator test, using `SimulateCustomPolicy` with the draft SCP and a supplied `iam:PermissionsBoundary` value, shows that the SCP denies role creation without the agent boundary and allows it with the boundary. That SCPs evaluate this condition key is inferred, not yet tested ([finding](https://github.com/ErikBean/research/blob/main/knowledge/tech/aws-agent-guardrails/findings/scp-can-require-permissions-boundary.md)).

#### Scenario: Testing the SCP before attaching it

- **WHEN** the draft SCP is simulated for `iam:CreateRole` with `iam:PermissionsBoundary` set to a policy other than the agent boundary
- **THEN** the simulation returns a deny

#### Scenario: An administrator role in a member account loosens the boundary

- **WHEN** a role in a member account without the agent boundary edits the boundary policy, and a deploy then tries to create a role without the boundary
- **THEN** the SCP still denies the role creation
