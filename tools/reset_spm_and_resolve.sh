#!/usr/bin/env bash
# Run when Xcode is stuck on "Fetching Firebase iOS SDK" and Stop does nothing.
# Usage: quit Xcode completely (Cmd+Q), then in Terminal:
#   chmod +x tools/reset_spm_and_resolve.sh
#   ./tools/reset_spm_and_resolve.sh

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> 1) Stopping Xcode and stuck SwiftPM helpers (ignore 'no matching processes')"
pkill -9 Xcode 2>/dev/null || true
sleep 1
pkill -9 -f "swift-package" 2>/dev/null || true
pkill -9 -f "SWBBuildService" 2>/dev/null || true

echo "==> 2) Clearing SwiftPM cache (bad/partial downloads)"
rm -rf "${HOME}/Library/Caches/org.swift.swiftpm"

echo "==> 3) Clearing this project's DerivedData (forces clean package checkouts)"
rm -rf "${HOME}/Library/Developer/Xcode/DerivedData"/QuestMode-*

echo "==> 4) Resolving packages using ONLY versions in Package.resolved (no upgrade checks)"
# -onlyUsePackageVersionsFromResolvedFile: do not hit the network for newer semver
# -skipPackageUpdates: do not refresh remotes when not required
xcodebuild -project QuestMode.xcodeproj \
  -scheme QuestMode \
  -resolvePackageDependencies \
  -onlyUsePackageVersionsFromResolvedFile \
  -skipPackageUpdates

echo ""
echo "Done. Open QuestMode.xcodeproj and press Cmd+B. If Xcode still spins, wait for step 4's downloads to finish once (Firebase is large)."
