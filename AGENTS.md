# Working in this repository

## User's standing preference

Commit and push completed requested changes to `origin` before finishing a coding task, unless the user explicitly asks otherwise. Report the branch and commit pushed. If access blocks a push, report the specific blocker. Do not force-push or include unrelated user changes.

Use the existing isolated checkout. Do not create an additional Git worktree unless the user asks.

## Validation

- Web: `npm test`, `npm run build`, and relevant `npm run test:e2e` checks.
- Native domain logic: `./ios/scripts/test-core.sh`.
- After adding or removing native Swift files: regenerate with `python3 ios/scripts/generate-xcode-project.py`, then check with `--check`.
- Native UI, Apple SDK compilation, signing, and StoreKit runtime validation require macOS/Xcode. Do not describe Linux parsing or core tests as a successful native app build.

Keep signing credentials, environment secrets, dependency/build caches, and user-specific Xcode files out of commits. See `ios/README.md` and `ios/Documentation/RELEASE.md` for the native release workflow.
