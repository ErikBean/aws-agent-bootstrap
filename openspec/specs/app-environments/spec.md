# App Environments Specification

## Purpose

How one app built by the factory moves from an agent's work to production across the member accounts: a `dev` stage the agent deploys per branch in the agent account, a preview per pull request that only CI deploys in the preview account, and `prod` in the production account. It also covers how a pull request shows production changes without production credentials, and how leftovers are cleaned up.

Reasoning: [decision](https://github.com/ErikBean/research/blob/main/knowledge/projects/aws-agent-bootstrap/decisions/app-environments.md), which links the research behind it.

This spec says what an app's repo and the factory must achieve. The `factory-repo-setup` skill and the factory's stage skills, in ErikBean/factory-skills, implement it for each repo.

## Requirements

### Requirement: One app, three stages

Each app's CDK app SHALL take a stage name, `dev`, `preview` or `prod`, and deploy the same stacks with stage-specific names. Stack names SHALL include the branch for `dev` and the pull request number for `preview`, so concurrent work doesn't collide. Nothing in the production account SHALL depend on a resource in the agent or preview account.

#### Scenario: Two features in flight

- **WHEN** an agent deploys `dev` from two branches of the same app
- **THEN** each branch gets its own stacks, and neither deploy changes the other's

### Requirement: The agent deploys and tests dev before review

During a factory run, the implementer SHALL deploy the branch's `dev` stage to the agent account, signed in as the agent user, and run a smoke test against the deployed app. The factory's review SHALL see the result.

#### Scenario: A factory run reaches review

- **WHEN** the implementer finishes a change
- **THEN** the branch's `dev` stage is deployed in the agent account, a smoke test has run against it, and the review stage sees what it reported

### Requirement: CI deploys a preview for each pull request

For each open pull request, CI SHALL deploy the `preview` stage to the preview account through the app's preview deploy role, and post the preview's URL on the pull request. Only CI SHALL deploy to the preview account. The preview deploy role SHALL trust only pull request workflows from the app's own repository, SHALL carry the agent boundary, and SHALL be able to assume only the CDK bootstrap roles in the preview account.

Before the first preview deploy role is created, the identity-perimeter RCP SHALL trust the developer's GitHub owner, as [security-baseline](../security-baseline/spec.md) requires. Previews are the first test of that statement.

#### Scenario: A pull request is opened

- **WHEN** a pull request is opened or updated
- **THEN** CI deploys its preview to the preview account and the pull request shows the preview's URL

#### Scenario: A fork opens a pull request

- **WHEN** a pull request comes from a fork of the repository
- **THEN** its workflow can't assume the preview deploy role

### Requirement: Pull requests show production changes without production credentials

On each merge to the default branch, the deploy workflow SHALL save the `prod` stage's synthesized templates as a build artifact. Pull request CI SHALL synthesize the `prod` stage and compare it with the last saved templates, with no AWS credentials, and show the differences on the pull request.

Reasoning: `cdk diff` runs the pull request's own code, which agents write, so a production-read role available to pull request workflows would be an indirect path from agents to production.

#### Scenario: A pull request changes production infrastructure

- **WHEN** a pull request adds, removes or changes a resource in the `prod` stage
- **THEN** the pull request shows the difference against the last production deploy

#### Scenario: Pull request workflows have no production credentials

- **WHEN** the production diff job runs
- **THEN** it has no AWS credentials for any account

### Requirement: dev and preview stages clean up after themselves

The `dev` and `preview` stages SHALL delete their data with their stacks, using a destroy removal policy and automatic emptying of buckets. A preview SHALL be destroyed when its pull request closes. The factory's ship stage SHALL destroy the branch's `dev` stack once its pull request merges or closes.

#### Scenario: A pull request closes

- **WHEN** a pull request is merged or closed
- **THEN** its preview stack is destroyed and leaves no resources behind

#### Scenario: The ship stage finishes

- **WHEN** the factory's ship stage completes for a branch
- **THEN** that branch's `dev` stack in the agent account is destroyed

### Requirement: A weekly report of resources outside any stack

A scheduled job SHALL run weekly in the agent account and email the developer a list of resources that aren't part of any CloudFormation stack. It SHALL NOT delete anything until a later change to this spec allows it.

Reasoning: agents may create resources directly with the AWS CLI while experimenting, and nothing else would remove them.

#### Scenario: An agent leaves a test bucket behind

- **WHEN** an agent creates an S3 bucket with the AWS CLI and doesn't delete it
- **THEN** the next weekly report lists it, and nothing deletes it
