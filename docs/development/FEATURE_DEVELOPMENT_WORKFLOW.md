# Feature Development Workflow

Applies to humans and AI agents. Complements the session workflow in [AGENTS.md](../../AGENTS.md).

## 1. Steps

1. **Pick the task** from [IMPLEMENTATION_PLAN](IMPLEMENTATION_PLAN.md) for the current milestone in [PROJECT_STATUS](../project/PROJECT_STATUS.md). No task → write one first (small, verifiable).
2. **Read** (minimum): PRD entry + FEATURE_SPECIFICATIONS entry + the architecture doc for the area + API.md if the bridge is involved + DESIGN/SCREEN_SPECIFICATIONS if UI.
3. **Inspect code** in the area; search for existing functionality before writing new.
4. **Plan** in the PR/commit description or chat: files to touch, public API changes, test plan, risks, what will need the phone. Get approval for anything that changes architecture, dependencies, permissions, DB schema or the bridge contract.
5. **Write tests first or alongside** at the lowest suitable layer (Dart unit → widget → Kotlin unit → instrumented → manual device checklist).
6. **Implement** the smallest change that satisfies the acceptance criteria; keep Dart/Kotlin/docs for the bridge in one change.
7. **Verify locally:**
   ```bash
   cd apps/mobile
   dart format --output=none --set-exit-if-changed .
   flutter analyze
   flutter test
   (cd android && ./gradlew :camanime_engine:testDebugUnitTest)
   flutter build apk --debug
   ```
   Then run on the phone for 📱 tasks and execute the relevant checklist in [TESTING](TESTING.md).
8. **Acceptance:** tick each `AC-*`/task criterion with evidence (command output, log excerpt, measurement). Unverified → leave open and say why.
9. **Docs:** update affected docs, [PROJECT_STATUS](../project/PROJECT_STATUS.md), [CHANGELOG](../project/CHANGELOG.md), OPEN_QUESTIONS if a question was answered or created.
10. **Commit** (see §2) only when the owner asks, or when the task says so.

## 2. Git workflow

- Branches: `main` is always buildable. Work on `feat/<task-id>-<slug>` or `fix/<slug>`; merge by squash or fast-forward after verification. A single developer may commit on `main` for docs-only changes.
- Commits: `type(scope): summary`, imperative, ≤ 72 chars; body explains why; reference the task ID (`T-M1-09`) and AC IDs.
- One concern per commit; formatting-only changes are separate.
- Never commit: build output, `local.properties`, keystores, `.env`, large raw benchmark captures, unverified model files.
- Tags: `v<major>.<minor>.<patch>` for releases; milestone tags `m1-done` optional.
- Never rewrite published history; never force-push `main`.

## 3. Definition of ready / done

- **Ready:** task has acceptance criteria, dependencies done, docs identified.
- **Done:** all verification executed; tests green; analyzers clean; docs updated; device-only items explicitly marked pending or confirmed by the owner.

## 4. Handling uncertainty

- API unsure → read official docs/source; cite the page in the commit/PR; do not guess.
- Measurement needed → follow [PERFORMANCE](../performance/PERFORMANCE.md) methodology; record device, build mode, commit.
- Decision with trade-offs → write/update an ADR before coding.
