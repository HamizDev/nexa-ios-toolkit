#!/usr/bin/env python3
"""Check actual codesign entitlements for an iPhone + embedded Watch pair."""
from __future__ import annotations

import argparse
import plistlib
import sys
from pathlib import Path


def plist(path: str) -> dict:
    with Path(path).open("rb") as handle:
        value = plistlib.load(handle)
    if not isinstance(value, dict):
        raise ValueError(f"{path}: expected a property list dictionary")
    return value


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def check(info: dict, entitlement: dict, bundle: str, group: str, team: str, label: str) -> None:
    require(info.get("CFBundleIdentifier") == bundle, f"{label}: bundle identifier mismatch")
    require(entitlement.get("application-identifier") == f"{team}.{bundle}",
            f"{label}: signed application identifier mismatch")
    require(entitlement.get("com.apple.developer.team-identifier") == team,
            f"{label}: signed Team ID mismatch")
    groups = entitlement.get("com.apple.security.application-groups")
    require(isinstance(groups, list) and all(isinstance(v, str) for v in groups),
            f"{label}: malformed or missing signed App Groups")
    require(group in groups, f"{label}: required App Group is not signed")
    require(all("$(" not in v for v in groups), f"{label}: unresolved App Group variable")


def validate(args: argparse.Namespace) -> None:
    phone = plist(args.phone_info)
    watch = plist(args.watch_info)
    watch_id = args.phone_bundle + ".watchkitapp"
    check(phone, plist(args.phone_entitlements), args.phone_bundle,
          args.phone_group, args.team, "iPhone")
    check(watch, plist(args.watch_entitlements), watch_id,
          args.watch_group, args.team, "Watch")
    require(watch.get("WKCompanionAppBundleIdentifier") == args.phone_bundle,
            "Watch: companion app identifier mismatch")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    for field in ("phone-info", "watch-info", "phone-entitlements",
                  "watch-entitlements", "phone-bundle", "phone-group",
                  "watch-group", "team"):
        parser.add_argument("--" + field, required=True)
    try:
        validate(parser.parse_args())
    except (OSError, plistlib.InvalidFileException, ValueError) as error:
        print("ERROR: signed bundle validation failed:", error, file=sys.stderr)
        return 1
    print("PASS: actual signed iPhone/Watch Team IDs, bundle IDs and App Groups match")
    return 0


if __name__ == "__main__":
    sys.exit(main())
