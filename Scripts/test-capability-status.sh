#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT HUP INT TERM
swiftc Nexa/Sources/NexaCapabilityStatus.swift Tests/CapabilityStatusRegression.swift -o "$WORK/capability-tests"
"$WORK/capability-tests"
