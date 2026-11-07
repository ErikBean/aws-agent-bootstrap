# Client setup

Example files for the developer's machine, as the [agent-client spec](../openspec/specs/agent-client/spec.md) requires. They hold placeholders only.

- `claude-settings.example.json`: merge into `~/.claude/settings.json`. Replace `YOUR_USER`, and replace `ADMIN_SESSION_TOKEN_FILE` with the name of the file that appears in `~/.aws/sso/cache` when you sign in to your own admin session.
- `aws-agent-config.example`: copy to `~/.aws/agent-config` and fill in your start URL, the agent account ID and permission set names.

`111122223333` is AWS's documentation placeholder account ID.
