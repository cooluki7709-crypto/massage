# Git Workflow

## Branches

- `main` - deployable stable history
- `develop` - integrated next release
- `feature/*` - new scoped features
- `fix/*` - non-urgent bug fixes
- `hotfix/*` - urgent production fixes

## Commit Style

- `feat(auth): add OTP login flow`
- `feat(matching): implement provider join logic`
- `fix(chat): resolve websocket reconnect issue`
- `chore(infra): add docker compose services`

## Phase Discipline

- Keep each phase commit-ready.
- Prefer small increments over large rewrites.
- Preserve working versions before refactors.
- Never commit `.env`, secrets, extracted APK assets, or proprietary reference media.

