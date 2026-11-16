# Client setup

Example files for the developer's machine, as the [agent-client spec](../openspec/specs/agent-client/spec.md) requires. They hold placeholders only.

- `claude-settings.example.json`: merge into `~/.claude/settings.json`. Replace `YOUR_USER` and `YOUR_SSH_KEY` (each private key in `~/.ssh`), and replace `ADMIN_SESSION_TOKEN_FILE` with the name of the file that appears in `~/.aws/sso/cache` when you sign in to your own admin session.
- `aws-agent-config.example`: copy to `~/.aws/agent-config` and fill in your start URL, the agent account ID and permission set names.
- `agent-github-token.mjs`: the Claude Code hook that mints the agent GitHub App's installation tokens, one per session, scoped to the repos of the folder the session started in. Copy it to `~/.claude/hooks/`, where sandboxed commands can't edit it; `claude-settings.example.json` runs it at session start and before each Bash command. `node ~/.claude/hooks/agent-github-token.mjs resolve <folder>` shows which repos a session started there would get.
- `agent-github-config.example.json`: copy to `~/.config/agent-github/config.json` and fill in the app ID, the installation ID, and any folders that should map to several repos. The app's private key goes next to it as `app.pem`, readable only by you.

`111122223333` is AWS's documentation placeholder account ID.
