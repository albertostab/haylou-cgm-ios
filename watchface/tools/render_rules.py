"""Preview a face's main text elements, following the drawing rules of Hello Haylou 3.7.19.

The rules are in docs/drawing-rules.md. They were read from the app and have not yet been measured
against a real screen, so report any difference you see. Icons, hands and weather aren't drawn.
"""

import tempfile
from collections import namedtuple
from functools import cache
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from tbwf import DIAL_SIZE, read_face

LEFT, CENTRE, RIGHT = 16, 32, 64
ANCHOR_MASK = 112
PREVIEW_SIZE = 240
INK_THRESHOLD = 64
# EEE from the phone's locale; a box must hold whichever language the app uses.
DAYS_EN = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
DAYS_PT = ["dom.", "seg.", "ter.", "qua.", "qui.", "sex.", "sáb."]
NUMBER = "0123456789"
# What the app measures per element, separators included, not only what the element shows.
# The repeated colon matches what the app measures.
DATE_SET = NUMBER + ",-:/"
STAT_SET = NUMBER + ",- ::/"
CHARSETS = {
    "hour": DATE_SET,
    "minute": DATE_SET,
    "day": DATE_SET,
    "month": DATE_SET,
    "battery": STAT_SET + " ",
    "step": STAT_SET,
    "heartRate": STAT_SET,
    "timeSeparator": ":",
    "dateSeparator": "/",
    "batteryPercentSign": "%",
    "dayOfWeek": DAYS_EN + DAYS_PT,
}
SAMPLE_VALUES = {
    "hour": "10",
    "timeSeparator": ":",
    "minute": "48",
    "dayOfWeek": "Fri",
    "month": "10",
    "dateSeparator": "/",
    "day": "30",
    "battery": "80",
    "batteryPercentSign": "%",
    "step": "8542",
    "heartRate": "72",
}

Cell = namedtuple("Cell", "width top height")


def size_px(element: dict, width: int = DIAL_SIZE) -> int:
    return int(width * element["font"]["size"])


def require_font(path: str | Path) -> None:
    if not Path(path).is_file():
        raise FileNotFoundError("font not found: %s" % path)


@cache
def ink_box(font_path: str, size: int, value: str) -> tuple[int, int, int, int]:
    """Ink bounds from the origin on the baseline, like Android's getTextBounds.

    PIL's own getbbox runs to the advance width, so draw the text and measure that.
    """
    pad = size * 2
    canvas = Image.new("L", (pad * 2 + size * max(len(value), 1) * 2, pad * 2))
    font = ImageFont.truetype(font_path, size)
    ImageDraw.Draw(canvas).text((pad, pad), value, font=font, fill=255, anchor="ls")
    box = canvas.point(lambda v: 255 if v > INK_THRESHOLD else 0).getbbox() or (pad, pad, pad, pad)
    return box[0] - pad, box[1] - pad, box[2] - pad, box[3] - pad


def glyph_cell(font_path: str, size: int, chars: str | list[str]) -> Cell:
    """The cell a set needs. A string counts per character; a list holds whole strings."""
    boxes = [ink_box(font_path, size, c) for c in chars]
    top = min(box[1] for box in boxes)
    return Cell(max(box[2] - box[0] for box in boxes), top, max(box[3] for box in boxes) - top)


def whole_top(font_path: str, size: int, names: list[str]) -> int:
    """The top of a whole-string element, which starts from the font's ascent, not its ink."""
    ascent = ImageFont.truetype(font_path, size).getmetrics()[0]
    return min(-ascent, glyph_cell(font_path, size, names).top)


def digit_centre(font_path: str, size: int, charset: str) -> float:
    """How far below y the digits' middle lands, given the set's taller glyphs."""
    digits = glyph_cell(font_path, size, NUMBER)
    return digits.top - glyph_cell(font_path, size, charset).top + digits.height / 2


def _rgb(element: dict) -> tuple[int, int, int]:
    color = element["color"]["colors"][0] & 0xFFFFFF
    return color >> 16, color >> 8 & 255, color & 255


def draw_value(
    canvas: Image.Image,
    element: dict,
    value: str,
    charset: str | list[str],
    font_path: str,
    whole: bool = False,
) -> None:
    size = size_px(element, canvas.width)
    font = ImageFont.truetype(font_path, size)
    cell = glyph_cell(font_path, size, charset)
    d = ImageDraw.Draw(canvas)
    x, y = element["x"] * canvas.width, element["y"] * canvas.width
    anchor = element.get("properties", 0) & ANCHOR_MASK
    if whole:
        left, _, right, _ = ink_box(font_path, size, value)
        spare = cell.width - (right - left)
        gap = spare / 2 if anchor == CENTRE else spare if anchor == RIGHT else 0
        baseline = y - whole_top(font_path, size, charset)
        d.text((x + gap - left, baseline), value, font=font, fill=_rgb(element), anchor="ls")
        return
    baseline = y - cell.top
    wide = len(value) * cell.width
    offset = -wide / 2 if anchor == CENTRE else -wide if anchor == RIGHT else 0
    for i, c in enumerate(value):
        left, _, right, _ = ink_box(font_path, size, c)
        at = x + offset + i * cell.width + (cell.width - (right - left)) / 2 - left
        d.text((at, baseline), c, font=font, fill=_rgb(element), anchor="ls")


def draw_face(dial: Image.Image, spec: dict, values: dict, font_path: str) -> Image.Image:
    """Draw `values` on the dial, cut to the round screen. An Image value pastes at its element."""
    img = dial.convert("RGB")
    for name, value in values.items():
        try:
            element = spec["elements"][name]
            if not element["visible"]:
                continue
            if isinstance(value, Image.Image):
                img.paste(value, (int(element["x"] * DIAL_SIZE), int(element["y"] * DIAL_SIZE)), value)
            else:
                draw_value(img, element, value, CHARSETS[name], font_path, name == "dayOfWeek")
        except (KeyError, TypeError, AttributeError) as error:
            raise ValueError("can't draw %s: %r" % (name, error)) from error
    mask = Image.new("L", img.size)
    ImageDraw.Draw(mask).ellipse((0, 0, img.width - 1, img.height - 1), fill=255)
    out = Image.new("RGB", img.size)
    out.paste(img, mask=mask)
    return out


def preview_face(path: str | Path, out: str | Path, font: str | Path | None = None) -> list[str]:
    """Save a screen-sized preview and return the visible elements it couldn't draw.

    Built-in fonts aren't available on a PC, so give `font` as a stand-in for those. Only one font
    is used, even if the face bundles more.
    """
    if font:
        require_font(font)
    face = read_face(path)
    values = dict(SAMPLE_VALUES)
    gauge = face.battery_image(80)
    if gauge:
        values["batteryResource"] = gauge
    with tempfile.TemporaryDirectory() as folder:
        font_path = str(font) if font else face.extract_font(folder)
        if font_path is None:
            raise ValueError("this face uses built-in fonts: pass a stand-in font")
        image = draw_face(face.dial, face.spec, values, font_path)
    image.resize((PREVIEW_SIZE, PREVIEW_SIZE), Image.LANCZOS).save(out)
    elements = face.spec["elements"]
    return sorted(n for n, e in elements.items() if e.get("visible") and n != "dial" and n not in values)
