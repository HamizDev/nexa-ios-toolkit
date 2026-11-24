#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT HUP INT TERM
swiftc Nexa/Sources/BackupPackageLibrary.swift Tests/BackupPackageRegression.swift -o "$WORK/backup-package-tests"
"$WORK/backup-package-tests"
