#!/usr/bin/env python3
"""Host regression checks for the signed iPhone/Watch entitlement verifier."""
import plistlib
import subprocess
import sys
import tempfile
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "Scripts/validate_signed_bundle.py"
TEAM = "TEAM123456"
PHONE = "dev.example.nexa"
PHONE_GROUP = "group.dev.example.nexa"
WATCH_GROUP = "group.dev.example.nexa.watch"


def exercise(change=None, should_pass=True):
    fixture = {
        "phone_info": {"CFBundleIdentifier": PHONE},
        "watch_info": {
            "CFBundleIdentifier": PHONE + ".watchkitapp",
            "WKCompanionAppBundleIdentifier": PHONE,
        },
        "phone_entitlements": {
            "application-identifier": TEAM + "." + PHONE,
            "com.apple.developer.team-identifier": TEAM,
            "com.apple.security.application-groups": [PHONE_GROUP],
        },
        "watch_entitlements": {
            "application-identifier": TEAM + "." + PHONE + ".watchkitapp",
            "com.apple.developer.team-identifier": TEAM,
            "com.apple.security.application-groups": [WATCH_GROUP],
        },
    }
    if change is not None:
        target, key, value = change
        if value is None:
            fixture[target].pop(key, None)
        else:
            fixture[target][key] = value

    with tempfile.TemporaryDirectory() as temporary:
        command = [sys.executable, str(SCRIPT)]
        for key, value in fixture.items():
            path = Path(temporary) / (key + ".plist")
            with path.open("wb") as handle:
                plistlib.dump(value, handle)
            command.extend(("--" + key.replace("_", "-"), str(path)))
        command.extend(("--phone-bundle", PHONE, "--phone-group", PHONE_GROUP,
                        "--watch-group", WATCH_GROUP, "--team", TEAM))
        result = subprocess.run(command, capture_output=True, text=True, check=False)
        assert (result.returncode == 0) == should_pass, (
            result.stderr + result.stdout
        )


def main():
    exercise()
    exercise(("phone_entitlements", "com.apple.security.application-groups", None), False)
    exercise(("phone_entitlements", "com.apple.security.application-groups", ["group.wrong"]), False)
    exercise(("watch_entitlements", "com.apple.security.application-groups", ["group.wrong"]), False)
    exercise(("phone_entitlements", "com.apple.developer.team-identifier", "OTHER12345"), False)
    exercise(("watch_entitlements", "application-identifier", "TEAM123456.wrong"), False)
    exercise(("watch_info", "WKCompanionAppBundleIdentifier", "wrong.phone"), False)
    exercise(("phone_info", "CFBundleIdentifier", "wrong.phone"), False)
    exercise(("watch_entitlements", "com.apple.security.application-groups", ["$(UNSET)"]), False)
    print("PASS: signed IPA verifier accepts a valid pair and rejects eight invalid fixtures")


if __name__ == "__main__":
    main()
