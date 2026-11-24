#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT HUP INT TERM
SDK="$(xcrun --sdk macosx --show-sdk-path)"
for unit in WQArchive WQLocalization; do
    xcrun --sdk macosx clang -isysroot "$SDK" -fobjc-arc -fmodules -fblocks \
        -c "Vendor/WQFiles/$unit.m" -o "$WORK/$unit.o"
done
xcrun --sdk macosx swiftc -sdk "$SDK" \
    -import-objc-header Vendor/WQFiles/WQArchive.h \
    Nexa/Sources/AppPaths.swift Nexa/Sources/BackupManager.swift \
    Nexa/Sources/BackupPackageLibrary.swift Nexa/Sources/BackupZipTransport.swift \
    Nexa/Sources/NexaBackupZip.swift Vendor/WCMigrate/BackupProgress.swift \
    Tests/BackupZipNativeRegression.swift "$WORK/WQArchive.o" "$WORK/WQLocalization.o" \
    -lz -o "$WORK/native-zip-tests"
"$WORK/native-zip-tests"
