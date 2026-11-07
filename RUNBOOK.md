# Runbook

Steps for building the account that aren't fully automated. Run them from a clone of this repo, signed in to the management account with an admin role.

## Create the agent and production accounts

This implements [`account-structure`](openspec/specs/account-structure/spec.md): a member account used only by agents, in an `Agents` OU, and a production account shared by every app, in a `Production` OU. The agent permission sets are assigned to the agent account and no other. The admin permission set is assigned to both.

A new organization may be limited to fewer accounts than this needs. Check before deploying:

```bash
aws service-quotas get-service-quota --service-code organizations --quota-code L-E619E033 --region us-east-1
```

The value must be at least the number of accounts already in the organization plus two. If it's lower, request an increase in Service Quotas from the management account. Requests at or below AWS's default of 10 may be refused there, in which case ask for the lowest value it accepts, or open an Account and billing support case.

1. **Sign in** to the management account through IAM Identity Center:

   ```bash
   aws sso login --sso-session <session>
   ```

   On a machine without a browser, add `--use-device-code` and open the link on another device.

2. **Fill in the config.** Copy `config/account-structure.env.example` to `config.local/account-structure.env`, which git ignores. These commands give the values:

   | Value | Command |
   | --- | --- |
   | `ORGANIZATION_ROOT_ID` | `aws organizations list-roots --query "Roots[0].Id"` |
   | `IDENTITY_CENTER_INSTANCE_ARN` | `aws sso-admin list-instances --query "Instances[0].InstanceArn"` |
   | `BUILDER_PERMISSION_SET_ARN`, `READONLY_PERMISSION_SET_ARN`, `ADMIN_PERMISSION_SET_ARN` | `aws sso-admin list-permission-sets --instance-arn <instance-arn>`, then `aws sso-admin describe-permission-set` on each to find `Agent-Builder`, `Agent-ReadOnly` and `Admin` |
   | `AGENT_PRINCIPAL_ID`, `ADMIN_PRINCIPAL_ID` | `aws identitystore list-users --identity-store-id <store-id>`, where the store ID is in `list-instances`. The agent principal is the dedicated agent user; see [`agent-client`](openspec/specs/agent-client/spec.md). The admin principal is your own user. They must differ, and the stack refuses to deploy if they don't. |

   `AGENT_ACCOUNT_EMAIL` and `PRODUCTION_ACCOUNT_EMAIL` must each be an address no other AWS account uses. A plus-address of an inbox you already read works.

3. **Deploy:**

   ```bash
   scripts/deploy-account-structure.sh
   ```

   Creating the accounts takes a few minutes. The stack retains the accounts and the OUs, so deleting the stack never closes an account.

4. **Remove the agent permission sets from every other account.** Assignments made before this stack existed, such as to the management account, aren't managed by it. For each agent permission set, list where it's provisioned:

   ```bash
   aws sso-admin list-accounts-for-provisioned-permission-set \
     --instance-arn <instance-arn> --permission-set-arn <permission-set-arn>
   ```

   For each account other than the agent account, delete the assignment:

   ```bash
   aws sso-admin delete-account-assignment \
     --instance-arn <instance-arn> --permission-set-arn <permission-set-arn> \
     --principal-id <principal-id> --principal-type USER \
     --target-id <other-account-id> --target-type AWS_ACCOUNT
   ```

5. **Check** that each agent permission set now reaches only the agent account:

   ```bash
   scripts/check-account-structure.sh
   ```

6. **Point local profiles at the agent account.** In `~/.aws/config`, set `sso_account_id` in the agent profiles to the new account's ID, from the stack's `AgentAccountId` output. Add admin profiles for the agent and production accounts, using the `Admin` role and the `AgentAccountId` and `ProductionAccountId` outputs.

The new accounts' root users have no password. Leave it that way. Use the management account's admin role or `OrganizationAccountAccessRole` if you ever need admin access without Identity Center.

## Put CDK deploys under the agent boundary

This implements [`deploy-permissions`](openspec/specs/deploy-permissions/spec.md) in both member accounts. Run it after the accounts exist and your admin profiles point at them.

1. **Deploy the boundary and bootstrap CDK** in each member account:

   ```bash
   scripts/deploy-agent-boundary.sh <agent-account-admin-profile>
   scripts/deploy-agent-boundary.sh <production-account-admin-profile>
   ```

   This creates the `agent-boundary` policy, then deploys the `CDKToolkit` stack from the pinned template in `infra/cdk-bootstrap-template.yaml`, with the boundary on all bootstrap roles. Running it again re-bootstraps with the same settings. Don't run `cdk bootstrap` against these accounts without `--custom-permissions-boundary agent-boundary --apply-permissions-boundary-to-all-roles`, because it would drop the boundary from the roles.

2. **Test and attach the SCP**, from the management account:

   ```bash
   scripts/deploy-scp-agent-boundary.sh
   ```

   It runs `scripts/test-scp-agent-boundary.sh` first, which simulates the SCP against the cases the spec names, and attaches the SCP to the `Agents` and `Production` OUs only if every case passes. You can run the test on its own at any time.

3. **Check** each member account:

   ```bash
   scripts/check-deploy-permissions.sh <agent-account-admin-profile>
   scripts/check-deploy-permissions.sh <production-account-admin-profile>
   ```

   It confirms every bootstrap role carries the boundary, then tries to create a role without the boundary and expects it to be denied. Run it only after step 2, because before the SCP is attached your admin role is allowed to create that role. If it ever succeeds, the script deletes the role and reports a failure.

## Set the agent permission sets

This implements [`agent-permissions`](openspec/specs/agent-permissions/spec.md). The `Agent-Builder` permission set keeps AWS's `PowerUserAccess` managed policy, which grants no IAM role or policy management and no `iam:PassRole`. Its inline policy, in `infra/agent-builder-inline-policy.json`, adds two statements:

- A deny on AWS Marketplace subscriptions.
- `iam:PassRole` for roles under `/agent/`, only to the services the spec allows.

From the management account:

```bash
scripts/apply-agent-permissions.sh
```

It runs `scripts/test-agent-permissions.sh` first, which simulates `PowerUserAccess` plus the inline policy against the spec's scenarios, and applies the policy only if every case passes. It then sets both `Agent-Builder` and `Agent-ReadOnly` to 4-hour sessions, as [`agent-client`](openspec/specs/agent-client/spec.md) requires, reprovisions them to every account they're assigned to, and prints each one's name and session duration. To allow another service, change the spec first, then the `iam:PassedToService` list in the policy.
