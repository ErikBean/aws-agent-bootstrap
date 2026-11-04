#!/usr/bin/env python3
"""Fail if tracked (or staged) files contain values tied to a real AWS account.

Usage:
  scripts/check-private.py            scan all tracked files
  scripts/check-private.py --staged   scan the staged version of staged files

See AGENTS.md for what counts as private and what to use instead.
"""
import re
import subprocess
import sys

# AWS's documentation placeholder account IDs, safe to commit.
PLACEHOLDER_ACCOUNTS = {"111122223333", "444455556666", "123456789012", "000000000000"}

PATTERNS = {
    "AWS account ID": re.compile(r"(?<![0-9])[0-9]{12}(?![0-9])"),
    "organization ID": re.compile(r"\bo-[a-z0-9]{10,32}\b"),
    "organization root ID": re.compile(r"\br-[a-z0-9]{4,32}\b"),
    "OU ID": re.compile(r"\bou-[a-z0-9]{4,32}-[a-z0-9]{8,32}\b"),
    "Identity Center instance ID": re.compile(r"\bssoins-[a-z0-9]{16}\b"),
    "Identity Center store ID": re.compile(r"\bd-[a-z0-9]{10}\b"),
    "access key ID": re.compile(r"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b"),
    "email address": re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"),
}

# Addresses that identify no one.
SAFE_EMAIL = re.compile(r"@(example\.(com|org|net)|users\.noreply\.github\.com|anthropic\.com)$", re.I)

# This file describes the patterns, so it is the one file not scanned.
SELF = "scripts/check-private.py"


def git(*args):
    return subprocess.run(["git", *args], check=True, capture_output=True, text=True).stdout


def files_to_scan(staged):
    if staged:
        names = git("diff", "--cached", "--name-only", "--diff-filter=ACMR").split("\n")
        return [(n, git("show", f":{n}")) for n in names if n and n != SELF]
    result = []
    for n in git("ls-files").split("\n"):
        if n and n != SELF:
            try:
                result.append((n, open(n, encoding="utf-8").read()))
            except (UnicodeDecodeError, FileNotFoundError):
                pass
    return result


def problems(text):
    for lineno, line in enumerate(text.split("\n"), 1):
        for label, pattern in PATTERNS.items():
            for match in pattern.finditer(line):
                value = match.group(0)
                if label == "AWS account ID" and value in PLACEHOLDER_ACCOUNTS:
                    continue
                if label == "email address" and SAFE_EMAIL.search(value):
                    continue
                yield lineno, label, value


def main():
    staged = "--staged" in sys.argv[1:]
    found = 0
    for name, text in files_to_scan(staged):
        for lineno, label, value in problems(text):
            print(f"{name}:{lineno}: possible {label}: {value}")
            found += 1
    if found:
        print(f"\n{found} possible private value(s). Replace them with placeholders; see AGENTS.md.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
