"""Set only the ordinary developer identifier for an unsigned source build.

No algorithm, pump/CGM driver, entitlement or safety check is edited. A missing
real Team ID produces a compilation check, not an installation-ready claim.
"""

import json
from pathlib import Path
import re
import subprocess
import sys

control = Path(__file__).resolve().parent
config = json.loads((control / "config.json").read_text(encoding="utf-8"))
root = Path(sys.argv[1]).resolve()
actual = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()
if actual != config["upstream_commit"]:
    raise SystemExit("Source commit differs from the pinned official release")

team = config.get("apple_team_id")
if team is not None and re.fullmatch(r"[A-Z0-9]{10}", team) is None:
    raise SystemExit("Apple Team ID must contain exactly 10 uppercase letters/digits")
if team is None:
    team = "TRIOUNSIGN"
    print("::warning::No real Team ID: compilation-check identifier only. Signing/App Group validation is still required.")

override = root / "ConfigOverride.xcconfig"
if override.exists():
    raise SystemExit("Refusing to replace a pre-existing signing override")
override.write_text(f"DEVELOPER_TEAM = {team}\n", encoding="utf-8", newline="\n")
print("Official release pin verified; normal ConfigOverride.xcconfig prepared. No signing credentials used.")
