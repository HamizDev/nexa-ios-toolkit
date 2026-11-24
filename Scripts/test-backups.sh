#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT HUP INT TERM
xcrun swiftc Nexa/Sources/AppPaths.swift Nexa/Sources/BackupManager.swift Nexa/Sources/BackupPackageLibrary.swift \
  Vendor/WCMigrate/BackupProgress.swift Tests/BackupRegression.swift -o "$WORK/backup-tests"
"$WORK/backup-tests"
