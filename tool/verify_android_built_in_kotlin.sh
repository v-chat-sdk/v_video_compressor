#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
flutter_bin="${FLUTTER_BIN:-flutter}"
fixture_parent="$(mktemp -d "${TMPDIR:-/tmp}/vvc-built-in-kotlin.XXXXXX")"
fixture_dir="$fixture_parent/app"

cleanup() {
  rm -rf "$fixture_parent"
}
trap cleanup EXIT

"$flutter_bin" create \
  --empty \
  --org com.v_chat_sdk \
  --platforms android \
  --project-name vvc_built_in_kotlin \
  "$fixture_dir"

(
  cd "$fixture_dir"
  "$flutter_bin" pub add "v_video_compressor@{path: $repo_root}"

  sed -i.bak '/org.jetbrains.kotlin.android/d' android/settings.gradle.kts
  rm android/settings.gradle.kts.bak
  sed -i.bak \
    's/android.builtInKotlin=false/android.builtInKotlin=true/' \
    android/gradle.properties
  rm android/gradle.properties.bak

  grep -Fq 'android.builtInKotlin=true' android/gradle.properties
  if grep -Eq 'kotlin-android|org.jetbrains.kotlin.android' \
    android/settings.gradle.kts android/app/build.gradle.kts; then
    echo 'The built-in Kotlin fixture still applies KGP.' >&2
    exit 1
  fi

  build_args=(build apk --debug)
  if [[ "${FLUTTER_ANDROID_SKIP_BUILD_DEPENDENCY_VALIDATION:-false}" == "true" ]]; then
    build_args+=(--android-skip-build-dependency-validation)
  fi
  "$flutter_bin" "${build_args[@]}"
)
