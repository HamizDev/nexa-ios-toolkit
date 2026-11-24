#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT HUP INT TERM
swiftc Nexa/Sources/BackupZipTransport.swift Tests/BackupZipTransportRegression.swift -o "$WORK/backup-zip-tests"
"$WORK/backup-zip-tests"
