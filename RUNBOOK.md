# Runbook

Steps for building the account that aren't fully automated. Run them from a clone of this repo, signed in to the management account with an admin role.

## Create the agent account

This implements [`account-structure`](openspec/specs/account-structure/spec.md): a member account used only by agents, in an `Agents` OU, with the agent permission sets assigned to it and to no other account.

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
   | `BUILDER_PERMISSION_SET_ARN`, `READONLY_PERMISSION_SET_ARN` | `aws sso-admin list-permission-sets --instance-arn <instance-arn>`, then `aws sso-admin describe-permission-set` on each to find `Agent-Builder` and `Agent-ReadOnly` |
   | `PRINCIPAL_ID` | `aws identitystore list-users --identity-store-id <store-id>`, where the store ID is in `list-instances` |

   `AGENT_ACCOUNT_EMAIL` must be an address no other AWS account uses. A plus-address of an inbox you already read works.

3. **Deploy:**

   ```bash
   scripts/deploy-account-structure.sh
   ```

   Creating the account takes a few minutes. The stack retains the account and the OU, so deleting the stack never closes the account.

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

6. **Point local profiles at the agent account.** In `~/.aws/config`, set `sso_account_id` in the agent profiles to the new account's ID, from the stack's `AgentAccountId` output.

The new account's root user has no password. Leave it that way. Use the management account's admin role or `OrganizationAccountAccessRole` if you ever need admin access to the agent account.
