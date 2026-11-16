#!/usr/bin/env node
// Claude Code hook: gives each session a GitHub App installation token scoped to the
// repos of the folder the session started in, minted from a private key the sandbox
// can't read. Never prints the token.
//
//   session-start  Fix the session's repos, tell Claude Code to read GH_TOKEN from the
//                  session's token file before every Bash command, and mint a token.
//   pre-bash       Re-mint the session's token when it has less than 10 minutes left.
//   resolve [dir]  Print the repos a session started in dir would get. For checking the map.
//
// Which repos a session gets, from its project folder (fixed for the session):
//   1. The folder's entry in "workspaces" in config.json, if it has one.
//   2. Otherwise, if the folder is in a git repo whose origin is on github.com, that repo.
//   3. Otherwise none: GH_TOKEN is empty.
// GitHub refuses repos that aren't in the app's installation, which also means no token.
//
// Config, not secret: ~/.config/agent-github/config.json
//   {"appId": "...", "installationId": "...", "workspaces": {"/abs/folder": ["repo", ...]}}
// Private key:        ~/.config/agent-github/app.pem  (chmod 600, denied to the sandbox)
// Per-session token:  ~/.cache/agent-github/sessions/<session id>/token
import { createSign } from "node:crypto";
import { execFileSync } from "node:child_process";
import {
  appendFileSync, mkdirSync, readFileSync, readdirSync, realpathSync, renameSync, rmSync, statSync, writeFileSync,
} from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const home = homedir();
const configDir = join(home, ".config", "agent-github");
const sessionsDir = join(home, ".cache", "agent-github", "sessions");
const REFRESH_MARGIN_MS = 10 * 60 * 1000;
const STALE_SESSION_MS = 24 * 60 * 60 * 1000;

function fail(message) {
  // Shown to the developer as a hook error; never includes the token or key.
  process.stderr.write(`agent-github-token: ${message}\n`);
  process.exit(1);
}

function readConfig() {
  try {
    return JSON.parse(readFileSync(join(configDir, "config.json"), "utf8"));
  } catch (e) {
    fail(`can't read ${join(configDir, "config.json")} (${e.code ?? e.message})`);
  }
}

function realDir(dir) {
  try { return realpathSync(dir); } catch { return dir; }
}

function reposFor(dir, config) {
  const real = realDir(dir);
  for (const [folder, repos] of Object.entries(config.workspaces ?? {})) {
    if (realDir(folder) === real) return repos.map((r) => r.split("/").pop());
  }
  try {
    const url = execFileSync("git", ["-C", real, "remote", "get-url", "origin"], {
      encoding: "utf8", stdio: ["ignore", "pipe", "ignore"],
    }).trim();
    const m = url.match(/github\.com[:/][^/]+\/([^/]+?)(?:\.git)?\/?$/);
    return m ? [m[1]] : [];
  } catch {
    return [];
  }
}

function sessionPaths(sessionId) {
  if (!/^[A-Za-z0-9_-]+$/.test(sessionId ?? "")) fail("hook input has no usable session_id");
  const dir = join(sessionsDir, sessionId);
  return { dir, token: join(dir, "token"), meta: join(dir, "meta.json") };
}

function readMeta(paths) {
  try { return JSON.parse(readFileSync(paths.meta, "utf8")); } catch { return null; }
}

function writeSession(paths, token, meta) {
  mkdirSync(paths.dir, { recursive: true, mode: 0o700 });
  writeFileSync(`${paths.token}.tmp`, token, { mode: 0o600 });
  renameSync(`${paths.token}.tmp`, paths.token);
  writeFileSync(paths.meta, JSON.stringify(meta), { mode: 0o600 });
}

function appJwt(appId, pem) {
  const b64 = (obj) => Buffer.from(JSON.stringify(obj)).toString("base64url");
  const now = Math.floor(Date.now() / 1000);
  const unsigned = `${b64({ alg: "RS256", typ: "JWT" })}.${b64({ iat: now - 60, exp: now + 540, iss: String(appId) })}`;
  const signature = createSign("RSA-SHA256").update(unsigned).sign(pem, "base64url");
  return `${unsigned}.${signature}`;
}

async function mint(paths, repos, config) {
  if (repos.length === 0) {
    writeSession(paths, "", { repos, expiresAt: null });
    return;
  }
  let pem;
  try {
    pem = readFileSync(join(configDir, "app.pem"), "utf8");
  } catch (e) {
    fail(`can't read ${join(configDir, "app.pem")} (${e.code ?? e.message})`);
  }
  const res = await fetch(`https://api.github.com/app/installations/${config.installationId}/access_tokens`, {
    method: "POST",
    headers: {
      Accept: "application/vnd.github+json",
      Authorization: `Bearer ${appJwt(config.appId, pem)}`,
      "X-GitHub-Api-Version": "2026-03-10",
      "User-Agent": "agent-github-token-hook",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ repositories: repos }),
  }).catch((e) => fail(`request failed: ${e.message}`));
  if (!res.ok) {
    // Most often a repo that isn't in the app's installation. Leave the session with no token.
    writeSession(paths, "", { repos, expiresAt: null, error: `${res.status} ${res.statusText}` });
    fail(`GitHub returned ${res.status} ${res.statusText} for repos ${repos.join(", ")}; this session has no GitHub token`);
  }
  const { token, expires_at } = await res.json();
  if (!token || !expires_at) fail("GitHub's response had no token");
  writeSession(paths, token, { repos, expiresAt: expires_at });
}

function needsRefresh(meta) {
  if (!meta) return true;
  if (meta.repos.length === 0 || meta.error) return false; // nothing to mint, or already refused
  return Date.parse(meta.expiresAt) - Date.now() < REFRESH_MARGIN_MS;
}

function cleanStaleSessions(keep) {
  let entries = [];
  try { entries = readdirSync(sessionsDir); } catch { return; }
  for (const name of entries) {
    if (name === keep) continue;
    const dir = join(sessionsDir, name);
    try {
      if (Date.now() - statSync(dir).mtimeMs > STALE_SESSION_MS) rmSync(dir, { recursive: true, force: true });
    } catch { /* another session may be cleaning up too */ }
  }
}

function readHookInput() {
  try { return JSON.parse(readFileSync(0, "utf8") || "{}"); } catch { return {}; }
}

const mode = process.argv[2];
if (mode === "resolve") {
  const dir = process.argv[3] ?? process.cwd();
  console.log(JSON.stringify({ dir: realDir(dir), repos: reposFor(dir, readConfig()) }));
} else if (mode === "session-start" || mode === "pre-bash") {
  const input = readHookInput();
  const paths = sessionPaths(input.session_id);
  const config = readConfig();
  let meta = readMeta(paths);
  if (mode === "session-start") {
    if (!process.env.CLAUDE_ENV_FILE) fail("CLAUDE_ENV_FILE isn't set");
    appendFileSync(process.env.CLAUDE_ENV_FILE, `export GH_TOKEN="$(cat "${paths.token}" 2>/dev/null)"\n`);
    cleanStaleSessions(input.session_id);
    if (!meta) {
      // The project folder fixes the session's repos; a later cd doesn't change them.
      const projectDir = process.env.CLAUDE_PROJECT_DIR || input.cwd || process.cwd();
      await mint(paths, reposFor(projectDir, config), config);
      meta = readMeta(paths);
    }
  } else if (!meta) {
    // Hooks were added mid-session: scope to the project folder now.
    const projectDir = process.env.CLAUDE_PROJECT_DIR || input.cwd || process.cwd();
    await mint(paths, reposFor(projectDir, config), config);
    meta = readMeta(paths);
  }
  if (needsRefresh(meta)) await mint(paths, meta.repos, config);
} else {
  fail(`unknown mode ${mode ?? "(none)"}; use session-start, pre-bash or resolve`);
}
