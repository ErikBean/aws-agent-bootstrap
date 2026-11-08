# Security Baseline Specification

## Purpose

The free or nearly free security controls on the organization and its member accounts, the agent and production accounts: an audit trail, checks for external access, public-access settings that the agent account can't change, and a resource perimeter that keeps other AWS accounts out of the agent account's resources.

Reasoning: [decision](https://github.com/ErikBean/research/blob/main/knowledge/projects/aws-agent-bootstrap/decisions/security-baseline.md), which links the research behind it, and the [production account decision](https://github.com/ErikBean/research/blob/main/knowledge/projects/aws-agent-bootstrap/decisions/production-account-guardrails.md).

## Requirements

### Requirement: Root users are protected

The management account's root user SHALL have MFA registered. Neither member account SHALL have root user credentials.

#### Scenario: Checking a member account's root user

- **WHEN** the root credential status of a member account is checked from the management account
- **THEN** it has no password, access keys or MFA device

### Requirement: An organization trail records all management events

One CloudTrail organization trail SHALL record management events in all Regions for every account in the organization, delivering to an S3 bucket in the management account. No other trail SHALL record management events, so that only the free first copy is used. No agent permission set SHALL have access to the bucket.

Reasoning: managing the trail and its bucket counts as organization administration under [account-structure](../account-structure/spec.md).

#### Scenario: An agent creates a resource

- **WHEN** an agent creates a Lambda function in the agent account
- **THEN** the call is recorded in the trail's bucket

#### Scenario: An agent tries to reach the logs

- **WHEN** an agent tries to read or delete objects in the trail's bucket
- **THEN** the request is denied

### Requirement: External access is reported

Each member account SHALL have an IAM Access Analyzer external access analyzer.

#### Scenario: An agent shares a bucket outside the organization

- **WHEN** a resource in a member account is made accessible to a principal outside the organization
- **THEN** Access Analyzer reports a finding

### Requirement: Public-access settings are locked

Declarative policies SHALL apply to both member accounts:

- an Amazon S3 policy turning on all four S3 Block Public Access settings
- an EC2 policy setting VPC Block Public Access to block inbound internet traffic (`block_ingress`), blocking new public sharing of AMIs, and blocking public sharing of EBS snapshots

#### Scenario: An agent turns off S3 Block Public Access

- **WHEN** a role in the agent account tries to change the account's or a bucket's S3 Block Public Access settings
- **THEN** the change has no effect, because the organization's policy overrides it

#### Scenario: An agent shares an AMI publicly

- **WHEN** a role in the agent account tries to make an AMI public
- **THEN** the request fails

### Requirement: Resources accept only principals from the organization

Each member account SHALL have a resource control policy based on AWS's identity-perimeter example, with its `EnforceOrgIdentities` and `EnforceConfusedDeputyProtection` statements, the organization's ID, and no trusted third-party accounts. A statement limiting `sts:AssumeRoleWithWebIdentity` to the developer's own tenant SHALL be added before any OIDC deploy role, such as one for GitHub Actions, is created.

The RCP SHALL be attached to each member account while it has no workloads, and tested then, because the IAM policy simulator doesn't support RCPs.

Reasoning: [finding](https://github.com/ErikBean/research/blob/main/knowledge/tech/aws-agent-guardrails/findings/identity-perimeter-rcp-pattern.md).

#### Scenario: Another account tries to assume an agent role

- **WHEN** a principal in an AWS account outside the organization calls `sts:AssumeRole` on a role in the agent account whose trust policy allows it
- **THEN** the request is denied

#### Scenario: A bucket policy grants another account

- **WHEN** a bucket policy in the agent account grants `s3:GetObject` to an account outside the organization, and that account tries to read an object
- **THEN** the request is denied

#### Scenario: CloudFront serves a private bucket

- **WHEN** a CloudFront distribution in the agent account reads its S3 origin through origin access control
- **THEN** the request is allowed

### Requirement: The management account gets Free Tier alerts

The management account SHALL be opted in to AWS Free Tier usage alerts.

#### Scenario: Usage nears a Free Tier limit

- **WHEN** usage of a service passes 85% of its Free Tier limit
- **THEN** the developer gets an email
