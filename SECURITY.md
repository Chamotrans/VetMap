# Security Policy — VetMap

## Secrets Never To Commit

| File | Contains |
|------|----------|
| `GoogleService-Info.plist` | Firebase API key, GCM sender ID, Google App ID |
| `*.xcprivacy` with real data | Privacy manifest |
| Any `.plist` with API keys | Service credentials |

## Git Hooks (Recommended)

### Pre-commit hook

```bash
# .git/hooks/pre-commit
#!/bin/bash
# Block GoogleService-Info.plist with real API keys

if git diff --cached --name-only | grep -q "GoogleService-Info.plist"; then
    if git show :GoogleService-Info.plist | grep -q 'AIzaSy\|YOUR_API_KEY'; then
        if git show :GoogleService-Info.plist | grep -qv 'YOUR_API_KEY'; then
            echo "❌ BLOCKED: Real GoogleService-Info.plist detected in commit!"
            echo "   This file must NOT be committed with real keys."
            echo "   Run: git reset HEAD GoogleService-Info.plist"
            exit 1
        fi
    fi
fi
```

### Install

```bash
cp .git/hooks/pre-commit.sample .git/hooks/pre-commit
# Add the above script to .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

## Rules

1. **`.gitignore` MUST include `GoogleService-Info.plist`** — verified in every new project
2. **`git add -A` never used** — always `git add <specific>` or `git add -p` with diff review
3. **Real secrets downloaded to `~/Downloads/` first** — then manually copied, never piped directly
4. **`git diff --staged` before every commit** — visually verify no secrets
5. **Sensitive commits blocked by pre-commit hook** — automated safety net
6. **If leaked: immediate rotation + history scrub** — as done June 6, 2026

## Current Status

- [x] Old key `AIzaSyAk...` revoked in Google Cloud Console
- [x] New key installed locally (gitignored)
- [x] All 14 commits scrubbed via filter-branch
- [x] GitHub history clean
- [x] `.gitignore` updated
- [x] BUILD SUCCEEDED with new key
