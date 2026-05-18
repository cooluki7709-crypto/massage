# Development Environment

Run the local tool check before starting a new phase:

```powershell
.\infra\scripts\check-dev-env.ps1
```

If Windows blocks `.ps1` execution:

```powershell
powershell -ExecutionPolicy Bypass -File .\infra\scripts\check-dev-env.ps1
```

Required tools:

- Node.js and npm for the monorepo, API, shared packages, and Admin Web.
- Git for GitHub backup, branch workflow, diffs, and stable commits.
- Docker Desktop for PostgreSQL/PostGIS, Redis, MinIO, Nginx, and production-style compose tests.
- Flutter and Dart for customer and provider mobile apps.

Recommended tools:

- Java 17 for Android build tooling.
- Android Studio for emulator, Android SDK, and Flutter device testing.

Current local status after setup:

- Git, Docker Desktop, Flutter, Dart, Node.js, npm, and Java are available.
- `verify-local.ps1 -WithServices` passes Docker, Prisma, API smoke, Admin build, and Flutter analyze checks.
- Android Studio remains optional but recommended for emulator/device testing and APK dynamic analysis.

If required tools are missing and Chocolatey is available, open PowerShell as Administrator and run:

```powershell
.\infra\scripts\check-dev-env.ps1 -Install
```

Execution-policy-safe install command:

```powershell
powershell -ExecutionPolicy Bypass -File .\infra\scripts\check-dev-env.ps1 -Install
```

For a dedicated installer that installs Git, Docker Desktop, and Flutter:

```powershell
powershell -ExecutionPolicy Bypass -File .\infra\scripts\install-dev-tools-admin.ps1
```

If Chocolatey reports a stale lock file under `C:\ProgramData\chocolatey\lib`, close other install windows and rerun:

```powershell
powershell -ExecutionPolicy Bypass -File .\infra\scripts\install-dev-tools-admin.ps1 -ClearChocolateyLocks
```

After installing Git, Docker Desktop, or Flutter, restart PowerShell so PATH changes are visible.

Docker Desktop may also require enabling WSL 2 and rebooting Windows before `docker --version` works.

## Local Verification

Run this before considering a phase stable:

```powershell
npm run verify:local
```

The verification script runs all checks that are possible on the current PC and marks unavailable checks as `SKIP`.

It currently covers:

- development tool availability
- Node script syntax checks
- environment template validation
- Prisma schema validation
- API typecheck and build
- Admin Web typecheck and build
- Git status when Git is available
- Docker Compose and smoke tests when Docker is available
- Flutter dependency/analyze checks when Flutter is available

After Docker Desktop is installed and running, use:

```powershell
powershell -ExecutionPolicy Bypass -File .\infra\scripts\verify-local.ps1 -WithServices
```

## Current Known Limitation

The Codex shell may not have Administrator privileges. If Chocolatey fails with an access error under `C:\ProgramData\chocolatey`, rerun the install command from an Administrator PowerShell window.
