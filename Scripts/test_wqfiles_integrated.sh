#!/usr/bin/env bash
# Tests upstream C/Objective-C units compiled into Nexa.
# The entire WQFiles stress suite remains a separate upstream acceptance gate.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
UP="$ROOT/ThirdParty/WQFiles"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT
mkdir -p "$OUT/fixtures"
export TMPDIR="$OUT/fixtures/"
SDK="$(xcrun --sdk macosx --show-sdk-path)"

run_test() {
  local name="$1"; shift
  printf '\n== %s ==\n' "$name"
  (
    cd "$UP"
    xcrun --sdk macosx clang -fobjc-arc -fmodules \
      -fmodules-cache-path="$OUT/Modules" \
      -isysroot "$SDK" -Wall -Wextra -Werror -I. "$@" \
      -framework Foundation -o "$OUT/$name"
  )
  "$OUT/$name"
}

run_test WQCoreTests WQCore.m tests/WQCoreTests.m
run_test WQAccessSafetyTests tests/WQAccessSafetyTests.m
run_test WQAccessMutationTests WQLocalization.m tests/WQAccessMutationTests.m WQCore.m
run_test WQArchiveTests WQArchive.m WQLocalization.m tests/WQArchiveTests.m -lz
run_test WQHexViewerHelpersTests tests/WQHexViewerHelpersTests.m
run_test WQPlistEditorSupportTests tests/WQPlistEditorSupportTests.m

echo "PASS: WQFiles source units used by Nexa"
