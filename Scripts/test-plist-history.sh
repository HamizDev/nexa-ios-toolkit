#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT HUP INT TERM
swiftc Nexa/Sources/NexaPlistHistory.swift Tests/PlistHistoryRegression.swift -o "$WORK/plist-history-tests"
"$WORK/plist-history-tests"
