# Spend Controls Specification

## Purpose

How spending in the agent account is limited. Always-on SCPs block expensive things outright, with no billing delay. A monthly budget reacts to the bill and, at its limit, stops new resources automatically until the developer reverses it.

Reasoning: [decision](https://github.com/ErikBean/research/blob/main/knowledge/projects/aws-agent-bootstrap/decisions/spend-controls.md), which links the research behind it.

## Requirements

### Requirement: Work is limited to two Regions

An SCP on the agent account SHALL deny actions requested in any Region other than `us-east-1` and `us-west-2`, except for global services that must be exempt for the account to work, such as IAM, STS, CloudFront, Route 53, Organizations, Budgets and Cost Explorer.

Reasoning: [finding](https://github.com/ErikBean/research/blob/main/knowledge/tech/aws-agent-guardrails/findings/cost-shaped-scp-examples.md). AWS's example exemption list may not include every global service, so a denied global action is a reason to extend the list.

#### Scenario: Creating a resource in another Region

- **WHEN** an agent creates a Lambda function in `eu-west-1`
- **THEN** the request is denied

#### Scenario: Working in an allowed Region

- **WHEN** an agent creates a Lambda function in `us-west-2`
- **THEN** the Region SCP doesn't deny it

#### Scenario: Using a global service

- **WHEN** an agent creates a CloudFront distribution
- **THEN** the Region SCP doesn't deny it

### Requirement: No EC2 instances

An SCP on the agent account SHALL deny launching EC2 instances by any API, including on-demand, Spot and fleet requests. Other EC2 actions, such as managing VPCs, subnets and security groups, SHALL remain available.

#### Scenario: Launching an instance

- **WHEN** an agent calls `ec2:RunInstances` for any instance type
- **THEN** the request is denied

#### Scenario: Creating a security group

- **WHEN** an agent creates a security group for a Lambda function in a VPC
- **THEN** the EC2 SCP doesn't deny it

### Requirement: No Bedrock model use

An SCP on the agent account SHALL deny invoking any Amazon Bedrock model, through both the `bedrock` and `bedrock-mantle` endpoints.

#### Scenario: Invoking a model

- **WHEN** an agent invokes any Bedrock model
- **THEN** the request is denied

### Requirement: No services with large fixed costs

An SCP on the agent account SHALL deny creating these resources: NAT gateways, Elastic Load Balancing load balancers, Amazon SageMaker resources, Amazon Redshift clusters and workgroups, Amazon EMR clusters, Amazon MSK clusters, Amazon OpenSearch Service domains and collections, and Amazon RDS or Aurora databases.

Reasoning: they bill whether or not anything uses them, and a NAT gateway alone costs more than the monthly budget ([finding](https://github.com/ErikBean/research/blob/main/knowledge/tech/aws-web-hosting/findings/fixed-monthly-charges.md)).

#### Scenario: Creating a NAT gateway

- **WHEN** an agent creates a NAT gateway, directly or through a CDK deploy
- **THEN** the request is denied

#### Scenario: Creating a DynamoDB table

- **WHEN** an agent creates a DynamoDB table
- **THEN** the fixed-cost SCP doesn't deny it

### Requirement: A $10 monthly budget with alerts

The agent account SHALL have a monthly cost budget of $10, with email alerts to the developer at $5 actual and $8 forecasted spend.

#### Scenario: Forecast passes $8

- **WHEN** forecasted spend for the month passes $8
- **THEN** the developer gets an email

### Requirement: The budget stops new resources automatically, and the developer can reverse it

When actual spend passes $10, a budget action SHALL attach a deny SCP to the agent account automatically, without waiting for approval. While it is attached, roles in the agent account SHALL NOT be able to create or start resources, and SHALL still be able to read and delete them. The developer SHALL be able to remove the deny by reversing the action in AWS Budgets.

Reasoning: [finding](https://github.com/ErikBean/research/blob/main/knowledge/tech/aws-agent-guardrails/findings/budget-action-approval-and-reversal.md). Budgets reacts hours after spending, so the cutoff lands above $10 ([finding](https://github.com/ErikBean/research/blob/main/knowledge/tech/aws-agent-guardrails/findings/budgets-lag-behind-usage.md)). Reversing removes the cap for the rest of the month; to allow a higher ceiling, raise the budget instead.

Untested: AWS says SCP-type actions reset at the start of each budget period, but not whether that detaches the deny SCP. This must be tested in the agent account, and the runbook must say what to do on the 1st of the month.

#### Scenario: Spending passes $10

- **WHEN** actual spend for the month passes $10 and Budgets next updates
- **THEN** the deny SCP is attached to the agent account and the developer is notified

#### Scenario: An agent works while the deny is attached

- **WHEN** an agent tries to create a Lambda function while the deny SCP is attached
- **THEN** the request is denied
- **AND** reading and deleting existing resources still works

#### Scenario: The developer reverses the deny

- **WHEN** the developer reverses the budget action
- **THEN** the deny SCP is detached and agents can create resources again
