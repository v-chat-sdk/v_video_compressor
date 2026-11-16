# Repository Guidelines

## Project Structure & Module Organization

This package is a Flutter plugin with three implementation layers:

- `lib/` contains the public Dart API, platform interface, method-channel adapter, models, logging, and progress-stream management.
- `android/src/main/kotlin/` and `ios/v_video_compressor/Sources/v_video_compressor/` contain the native compression engines, channel handlers, and mirrored models.
- `test/` holds Dart unit and method-channel tests. Android native tests live under `android/src/test/`.
- `example/` is the runnable Flutter app; its `test/` and `integration_test/` directories cover widgets and device-level behavior. Screenshots are stored in `example/screenshots/`.

Keep platform contracts synchronized. A new model field or channel method normally requires matching Dart, Kotlin, and Swift updates.

## Flutter 3.50 verification workflow

Use the installed project-compatible Flutter 3.50/Dart 3.14 SDK. Keep direct `material_ui`/`cupertino_ui` dependencies consistent with their imports; design widgets no longer come from `flutter/material.dart` or `flutter/cupertino.dart`. Prefer neutral Flutter libraries when design widgets are unnecessary. Preserve this project's architecture and public contracts.

Resolve dependencies from each affected package root with `flutter pub get --no-example`. For a design migration, run `dart fix --apply --code=migrate_design_widgets` and review its output. After every code edit, run these commands sequentially from the affected package root:

```sh
dart fix --apply
dart format .
flutter analyze
```

Fix and format must finish before analysis or tests. Analyzer-only verification is the default. Run a focused test or build when requested or needed to prove a specific behavior change; choose the smallest useful check. Passing analysis does not prove runtime, provider, native linking, or integration behavior. Never suppress maintained-source diagnostics to obtain a pass. Preserve tool-owned generated files.

This repository has no existing web runner. Do not add one merely to validate a migration.

Use a reachable physical Android device only when web is unsupported and device execution is requested. No emulator or simulator is authorized. This Linux VPS cannot execute native iOS/macOS builds or assume access to a phone attached to the Mac. Observe the global 500 MB download rule and preserve existing edits, credentials, caches, and running sessions. Do not push, publish, deploy, or run native builds without task authorization.

Use one handwritten class/widget per file; a StatefulWidget and its paired State may share a file. Apply SOLID without speculative abstractions. Keep UI, coordination, domain behavior, transport, persistence, and provider mechanics in their existing layers; use explicit types and correct async ownership/disposal. Do not impose another project’s state management or architecture.


## Coding Style & Naming Conventions

Use null-safe, idiomatic Dart with two-space indentation and let `dart format` decide layout. Follow `flutter_lints`; use `snake_case.dart` filenames, `UpperCamelCase` types, and `lowerCamelCase` members. Follow existing Kotlin and Swift formatting in native files. Reuse `VVideoLogger` instead of ad-hoc prints, and preserve the established `VVideo*` naming prefix for public plugin types.

## Testing Guidelines

Use `flutter_test`; name Dart files `*_test.dart` and native tests `*Test.kt` or `*Tests.swift`. Add focused tests for validation, serialization, channel payloads, progress events, cancellation, and error paths. Integration tests that exercise real compression require a device or simulator. No coverage threshold is automated, so do not reduce coverage for changed behavior.

## Commit & Pull Request Guidelines

Recent history favors concise prefixes such as `feat:`, `fix:`, `docs:`, and `chore(release):`; use an imperative, specific subject. Pull requests should explain behavior and compatibility impact, link relevant issues, list platforms tested and commands run, and include screenshots for example-app UI changes. Call out any channel-schema, permission, or minimum-platform changes explicitly.
