"""Inspect the actual device binary and record what the build does not prove."""

import hashlib
import json
from pathlib import Path
import plistlib
import subprocess
import sys
import zipfile

app, ipa, output = map(Path, sys.argv[1:4])
with (app / "Info.plist").open("rb") as stream:
    info = plistlib.load(stream)
executable = app / info["CFBundleExecutable"]
arch = subprocess.check_output(["lipo", "-archs", str(executable)], text=True).strip()
if "arm64" not in arch.split():
    raise SystemExit("Missing physical-device arm64 binary")
if info.get("CFBundleSupportedPlatforms") != ["iPhoneOS"]:
    raise SystemExit("This is not an iPhoneOS device app")
with zipfile.ZipFile(ipa) as archive:
    if archive.testzip() is not None:
        raise SystemExit("IPA ZIP integrity failed")
    if "Payload/Trio.app/Info.plist" not in archive.namelist():
        raise SystemExit("Missing app payload")
config = json.loads((Path(__file__).parent / "config.json").read_text(encoding="utf-8"))
manifest = {
    "source": "https://github.com/nightscout/Trio",
    "release": "v1.0.2",
    "source_commit": config["upstream_commit"],
    "algorithm_or_driver_changes": False,
    "code_signing": "disabled; user must sign separately",
    "team_identifier": "provided" if config.get("apple_team_id") else "COMPILATION PLACEHOLDER, not the user's Team ID",
    "bundle_identifier": info["CFBundleIdentifier"],
    "version": info.get("CFBundleShortVersionString"),
    "minimum_ios": info.get("MinimumOSVersion"),
    "architectures": arch,
    "sha256": hashlib.sha256(ipa.read_bytes()).hexdigest(),
    "sha256_scope": "unsigned artifact; signing changes these bytes",
    "ios_27_2_1_device_test": "NOT PERFORMED",
    "sideloadly_signature_and_app_groups": "NOT VERIFIED",
    "dexcom_g7_readings_and_background": "NOT TESTED",
    "omnipod5_pairing_or_delivery": "NOT PERFORMED",
    "status": "technical build; NOT proof of readiness for insulin delivery",
}
output.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
print(json.dumps(manifest, indent=2))
