#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT HUP INT TERM
swiftc Nexa/Sources/NexaFileLibrary.swift Tests/FileLibraryRegression.swift -o "$WORK/file-library-tests"
"$WORK/file-library-tests"
