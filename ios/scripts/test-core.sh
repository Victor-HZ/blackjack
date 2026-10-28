#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -n "${SWIFT_BIN:-}" ]]; then
  swift_command="$SWIFT_BIN"
elif command -v swift >/dev/null 2>&1; then
  swift_command="$(command -v swift)"
elif [[ -x /workspace/.toolchains/swift-6.2/usr/bin/swift ]]; then
  swift_command='/workspace/.toolchains/swift-6.2/usr/bin/swift'
else
  echo 'Swift is required. Install Xcode on macOS or run ios/scripts/install-swift-linux.sh on Linux x86_64.' >&2
  exit 1
fi
swift_cache_root="${STUDIO_SWIFT_CACHE:-/tmp/blackjack-studio-swift}"
mkdir -p "$swift_cache_root"
export CLANG_MODULE_CACHE_PATH="$swift_cache_root/modules"
export SWIFTPM_MODULECACHE_OVERRIDE="$swift_cache_root/modules"
for package in BlackjackCore TrainingCore StudioCore; do
  "$swift_command" test --package-path "$project_root/Packages/$package" \
    --cache-path "$swift_cache_root/cache" --config-path "$swift_cache_root/config" \
    --security-path "$swift_cache_root/security" --jobs 3
done
