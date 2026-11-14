"""Read and write .tbwf watch faces, the editable projects Hello Haylou imports.

A .tbwf is a ZIP of TiBoWaFe.json, images and optional fonts. Positions are fractions of the screen.
See docs/tbwf-format.md.
"""

import copy
import json
import zipfile
from collections.abc import Callable
from dataclasses import dataclass
from io import BytesIO
from pathlib import Path

from PIL import Image

DIAL_SIZE = 454
SPEC_NAME = "TiBoWaFe.json"
DIAL_NAME = "/resourceImage/dial.png"
FONT_DIR = "/font/"
WHITE = -1
GOLD = -15795
BLANK_RESOURCE = 24
BATTERY_LEVELS = range(0, 101, 10)
HANDS = ("hourHand", "minuteHand", "secondHand")
ZIP_DATE = (1980, 1, 1, 0, 0, 0)  # A fixed date, so the same face always gives the same bytes.


def solid(color: int) -> dict:
    return {"colors": [color], "gradient": "solid", "positions": [0.0]}


def text(
    x: float,
    y: float,
    size: float,
    color: int = WHITE,
    family: str = "sans-serif-medium",
    visible: bool = True,
    properties: int | None = None,
) -> dict:
    element = {
        "font": {"family": family, "size": size},
        "color": solid(color),
        "visible": visible,
        "x": x,
        "y": y,
    }
    if properties is not None:
        element["properties"] = properties
    return element


def icon(
    resource: str, sections: int, size: float, x: float, y: float, color: int = GOLD, visible: bool = True
) -> dict:
    return {
        "resourceIcon": {"resource": resource, "sections": sections, "size": size},
        "color": solid(color),
        "visible": visible,
        "x": x,
        "y": y,
    }


def hand(name: str, width: int, height: int, pivot: float, size: float) -> dict:
    return {
        "resourceImage": {
            "height": height,
            "mimeType": "image/png",
            "pivotY": pivot,
            "resource": "/resourceImage/%s.png" % name,
            "sections": 1,
            "size": size,
            "width": width,
        },
        "color": solid(WHITE),
        "properties": 2,
        "visible": False,
        "x": 0.5,
        "y": 0.5,
    }


def folder(name: str, sections: int, size: float) -> dict:
    return {
        "resourceImage": {"resource": "/resourceImage/%s/" % name, "sections": sections, "size": size},
        "color": solid(0),
        "visible": False,
        "x": 0.5,
        "y": 0.5,
    }


def default_spec() -> dict:
    """A plain digital layout listing all 30 elements, which the app expects even when hidden."""
    big = 0.17
    small = 0.058
    time_y = 0.615
    row1, row2 = 0.80, 0.875
    return {
        "aspectRatio": 1.0,
        "caseShape": "round",
        "version": 1,
        "elements": {
            "dial": {
                "resourceImage": {
                    "height": DIAL_SIZE,
                    "mimeType": "image/png",
                    "resource": DIAL_NAME,
                    "sections": 1,
                    "size": 1.0,
                    "width": DIAL_SIZE,
                },
                "color": solid(0),
                "visible": True,
            },
            "hour": text(0.255, time_y, big, properties=16),
            "timeSeparator": text(0.485, time_y - 0.01, big, GOLD, properties=16),
            "minute": text(0.535, time_y, big, properties=16),
            "second": text(0.775, 0.275, 0.1, visible=False),
            "dayOfWeek": text(0.33, row1, small, GOLD, properties=33),
            "month": text(0.455, row1, small, GOLD, properties=16),
            "dateSeparator": text(0.535, row1, small, GOLD),
            "day": text(0.565, row1, small, GOLD, properties=16),
            "year": text(0.775, 0.476, small, visible=False),
            "yearSeparator": text(0.757, 0.483, small, visible=False),
            "step": text(0.255, row2, small, properties=16),
            "stepResource": icon("stepResource_ic_wf_step_foot_print.png", 1, 0.05, 0.20, row2 + 0.005),
            "heartRateResource": icon(
                "heartRateResource_ic_wf_heart_rate_favorite.png", 1, 0.05, 0.44, row2 + 0.005, -65536
            ),
            "heartRate": text(0.495, row2, small, properties=16),
            "battery": text(0.62, row2, small, properties=16),
            "batteryPercentSign": text(0.71, row2 + 0.01, 0.04),
            "calorie": text(0.77, 0.537, 0.06, visible=False),
            "calorieResource": icon(
                "calorieResource_ic_wf_calorie_burn.png", 1, 0.07, 0.691, 0.52, visible=False
            ),
            "distance": text(0.77, 0.637, 0.06, visible=False),
            "distanceResource": icon(
                "distanceResource_ic_wf_distance_map_marker.png", 1, 0.07, 0.691, 0.625, visible=False
            ),
            "weatherTemperature": text(0.47, 0.27, small, visible=False),
            "weatherTemperatureUnitSign": text(0.515, 0.275, small, visible=False),
            "weatherResource": icon(
                "weatherResource_ic_wf_anim_weather_fill.png", 16, 0.075, 0.46, 0.19, visible=False
            ),
            "stepGoalProgressResource": icon(
                "stepGoalProgressResource_ic_wf_anim_goal_circular.png", 11, 0.26, 0.13, 0.25, visible=False
            ),
            "hourHand": hand("hourHand", 39, 194, -0.13948497, 0.4613734),
            "minuteHand": hand("minuteHand", 42, 235, -0.12446352, 0.49356225),
            "secondHand": hand("secondHand", 33, 292, -0.1416309, 0.52575105),
            "connectionResource": folder("connectionResource", 2, 0.054),
            "batteryResource": folder("batteryResource", 11, 0.17),
        },
    }


def png(image: Image.Image) -> bytes:
    buffer = BytesIO()
    image.save(buffer, "PNG")
    return buffer.getvalue()


def blank(width: int, height: int) -> bytes:
    return png(Image.new("RGBA", (width, height)))


def _add(archive: zipfile.ZipFile, name: str, data: str | bytes) -> None:
    info = zipfile.ZipInfo(name, ZIP_DATE)
    info.compress_type = zipfile.ZIP_DEFLATED
    info.create_system = 0
    info.external_attr = 0o600 << 16
    archive.writestr(info, data)


def write_face(
    path: str | Path,
    spec: dict,
    dial: Image.Image,
    font: str | Path | None = None,
    battery: Callable[[int], Image.Image] | None = None,
) -> None:
    """Write a .tbwf. `font` is bundled and set on every text element that doesn't name a file.

    `battery` draws the icon for a level (0, 10 ... 100); without it those images are blank.
    """
    spec = copy.deepcopy(spec)
    family = font_data = None
    if font:
        font_data = Path(font).read_bytes()
        family = FONT_DIR + Path(font).name
        for element in spec["elements"].values():
            if "font" in element and not element["font"]["family"].startswith(FONT_DIR):
                element["font"]["family"] = family
    with zipfile.ZipFile(path, "w") as z:
        _add(z, SPEC_NAME, json.dumps(spec, indent=2))
        _add(z, DIAL_NAME, png(dial))
        if family:
            _add(z, family, font_data)
        for name in HANDS:
            size = spec["elements"][name]["resourceImage"]
            _add(z, "/resourceImage/%s.png" % name, blank(size["width"], size["height"]))
        for name in ("connected", "disconnected"):
            art = blank(BLANK_RESOURCE, BLANK_RESOURCE)
            _add(z, "/resourceImage/connectionResource/%s.png" % name, art)
        for level in BATTERY_LEVELS:
            art = png(battery(level)) if battery else blank(BLANK_RESOURCE, BLANK_RESOURCE)
            _add(z, "/resourceImage/batteryResource/percent_%d.png" % level, art)


@dataclass
class Face:
    spec: dict
    dial: Image.Image
    files: dict[str, bytes]

    def battery_image(self, level: int) -> Image.Image | None:
        element = self.spec["elements"].get("batteryResource", {})
        name = "/resourceImage/batteryResource/percent_%d.png" % level
        if not element.get("visible") or name not in self.files:
            return None
        return Image.open(BytesIO(self.files[name])).convert("RGBA")

    def extract_font(self, folder_path: str | Path) -> str | None:
        """Save the bundled font to a folder and return its path, or None if there isn't one."""
        for name, data in self.files.items():
            if name.startswith(FONT_DIR) and not name.endswith("/"):
                out = Path(folder_path) / Path(name).name
                out.write_bytes(data)
                return str(out)
        return None


def _read_files(path: str | Path) -> dict[str, bytes]:
    with zipfile.ZipFile(path) as archive:
        return {name: archive.read(name) for name in archive.namelist()}


def _shape_problems(spec: object) -> list[str]:
    if not isinstance(spec, dict) or not isinstance(spec.get("elements"), dict):
        return ["%s has no elements" % SPEC_NAME]
    return ["%s is not an element" % n for n, e in spec["elements"].items() if not isinstance(e, dict)]


def read_face(path: str | Path) -> Face:
    files = _read_files(path)
    for name in (SPEC_NAME, DIAL_NAME):
        if name not in files:
            raise ValueError("%s has no %s" % (path, name))
    spec = json.loads(files[SPEC_NAME])
    problems = _shape_problems(spec)
    if problems:
        raise ValueError("; ".join(problems))
    return Face(spec, Image.open(BytesIO(files[DIAL_NAME])).convert("RGB"), files)


def check_face(path: str | Path) -> list[str]:
    """What would stop the app loading this face, or show up wrong. An empty list is good."""
    try:
        files = _read_files(path)
        spec = json.loads(files[SPEC_NAME])
    except (OSError, zipfile.BadZipFile, KeyError, ValueError) as error:
        return ["not a readable .tbwf: %s" % error]
    problems = _shape_problems(spec)
    if not isinstance(spec, dict) or not isinstance(spec.get("elements"), dict):
        return problems
    elements = spec["elements"]
    problems += ["missing element: %s" % name for name in default_spec()["elements"].keys() - elements.keys()]
    for name, element in elements.items():
        font = element.get("font") if isinstance(element, dict) else None
        family = font.get("family") if isinstance(font, dict) else None
        if isinstance(family, str) and family.startswith(FONT_DIR) and family not in files:
            problems.append("%s names a font that isn't in the file: %s" % (name, family))
    if DIAL_NAME not in files:
        return sorted(problems + ["missing %s" % DIAL_NAME])
    try:
        size = Image.open(BytesIO(files[DIAL_NAME])).size
    except OSError as error:
        return sorted(problems + ["unreadable dial: %s" % error])
    if size != (DIAL_SIZE, DIAL_SIZE):
        problems.append("dial is %dx%d, not %dx%d" % (*size, DIAL_SIZE, DIAL_SIZE))
    return sorted(problems)
