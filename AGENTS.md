# AGENTS.md

## Purpose

This file defines how Codex/AI agents should work inside this Flutter project.

Keep work focused, reviewable, and aligned with the product direction.

This file is not the full PRD. Product details live in:

```text
docs/Match_A_Man_PRD.md
```

Only read the PRD when product behavior is unclear or when the human explicitly asks for product-level decisions.

## Project Constitution

Match A Man is a social sports and events mobile app.

It is not a dating app.

The product should feel:

- social
- energetic
- sporty
- modern
- trustworthy

The app is event-centered. Social features must support the event loop, not replace it.

Do not remove, shrink, or argue against planned MVP+ scope unless the human explicitly asks for scope review.

Do not introduce major new product areas unless explicitly requested.

## Fixed Stack

Use:

- Flutter
- Riverpod
- Supabase
- go_router

Supabase is used for:

- Auth
- Database
- Initial storage/media

Firebase may be used later only for push notifications if explicitly requested.

Package name:

```text
match_a_man
```

## Architecture

Use Shallow Feature-First Architecture.

Required flow:

```text
Page -> Provider -> Service -> Supabase/Firebase
```

Rules:

- Pages render UI and call provider methods.
- Pages must not call Supabase/Firebase directly.
- Providers manage loading, error, success, and state.
- Providers must not write raw Supabase queries.
- Services talk to Supabase/Firebase.
- Services must not contain UI code.
- Models stay inside their feature folder.
- Do not create heavy Clean Architecture.
- Do not create `domain`, `usecases`, `datasources`, `repository_impls`, or `mappers`.
- Do not create abstract classes unless there are at least two real implementations.
- Avoid generic abstractions before the third real repetition.
- Keep files small and readable.
- If a page grows too much, extract widgets into that feature's `widgets/` folder.
- Shared widgets go to `lib/core/widgets/`.
- Design tokens go to `lib/core/theme/`.

## Folder Rules

Use feature-first structure.

Typical feature shape:

```text
lib/features/<feature>/
  <feature>_page.dart
  <feature>_provider.dart
  <feature>_service.dart
  <feature>_models.dart
  widgets/
```

Shared app-level code goes to:

```text
lib/core/
lib/services/
```

Rules:

- Feature-specific widgets stay inside that feature's `widgets/` folder.
- Shared reusable widgets go to `lib/core/widgets/`.
- Design tokens go to `lib/core/theme/`.
- Feature models stay inside the feature folder.
- Do not create global model folders unless explicitly requested.

## Task Scope Rules

Edit only files explicitly listed in the task.

Prefer related file bundles instead of huge feature-wide changes.

Good bundles:

- router bundle:
  - `route_names.dart`
  - `app_router.dart`

- Supabase config bundle:
  - `env.dart`
  - `supabase_service.dart`

- service bundle:
  - `<feature>_models.dart`
  - `<feature>_service.dart`

- provider bundle:
  - `<feature>_models.dart`
  - `<feature>_provider.dart`

- UI bundle:
  - `<feature>_page.dart`
  - directly used widgets inside that feature

Avoid mixing unrelated layers in one task.

Bad bundles:

- router + service + provider + UI + tests all at once
- events + feed
- auth + profile + events
- pubspec changes + large feature implementation
- native platform files + Dart feature code

Default task size:

```text
4-6 related files max
```

More files require explicit human approval.

## Editing Rules

- Only edit files explicitly listed in the task.
- Do not touch unrelated files.
- Do not modify `.env`, `.env.*`, `ios/`, `android/`, `web/`, `macos/`, `windows/`, `linux/`, `build/`, `.dart_tool/`, Firebase config files, or native platform files unless explicitly allowed.
- Do not add packages unless explicitly requested.
- Do not commit automatically.
- Prefer clean complete edits over messy partial patches.
- Remove duplicate imports, duplicate classes, duplicate methods, and leftover old code.
- Keep imports clean and relative paths correct.
- Do not print full file contents unless explicitly asked.
- Do not rewrite working files for cosmetic reasons only.
- Do not rename files unless explicitly requested.

## Pubspec Rules

When editing `pubspec.yaml`:

- There must be only one `dependencies:` section.
- There must be only one `dev_dependencies:` section.
- Do not duplicate packages.
- Do not add unnecessary packages.
- Keep YAML valid.
- If dependencies change, Codex may run:

```text
flutter pub get
```

## UI Rules

Use existing design system files when available:

- `AppColors`
- `AppTextStyles`
- `AppSpacing`
- `AppRadius`
- `AppTheme`
- `AppButton`
- `AppTextField`

Do not invent random colors, spacing, radius, typography, button styles, or input styles when existing tokens are available.

UI should feel:

- social
- energetic
- sporty
- modern
- trustworthy

It must not feel like a cheap dating app.

## Quality Rules

After meaningful code changes, Codex may run:

```text
flutter analyze
```

The human will run:

```text
flutter test
git status
git diff --stat
git add .
git commit -m "<clear commit message>"
git push
```

Before reporting completion, Codex should check for:

- duplicate imports
- duplicate methods/classes
- broken relative imports
- stale Flutter template code
- invalid YAML
- unnecessary files
- unrelated changes
- mixed old/new code
- merge conflict markers

Do not treat Git diff colors as errors.

In Git diff:

- green means added lines
- red means removed lines
- `+38 -7` means 38 lines added and 7 lines removed

Real errors come from:

- `flutter analyze`
- `flutter test`
- compiler output
- runtime errors
- invalid YAML
- duplicate code that breaks compilation

## Git Rules

The human controls all Git operations.

Codex must not run:

```text
git add
git commit
git push
```

Codex must not commit automatically.

Do not continue to a new feature when the working tree is dirty unless the human explicitly says so.

## Output Rules

Keep responses short.

After each task, report only:

- changed files
- commands run
- analyze result
- errors, if any
- short summary

Do not report `flutter test` unless the human explicitly asked Codex to run it.

Do not print full diffs unless explicitly asked.

Do not print full file contents unless explicitly asked.

Do not repeat the PRD unless explicitly asked.

## Product Source of Truth

If product behavior is unclear, check:

```text
docs/Match_A_Man_PRD.md
```

Do not guess product behavior when the PRD has a clear answer.

If the PRD and the current task conflict, stop and ask the human.

If AGENTS.md and the PRD conflict, prefer the PRD for product decisions and AGENTS.md for coding/workflow rules.