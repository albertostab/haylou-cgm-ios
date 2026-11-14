"""Build the user's reference design as an editable TBWF and honest previews.

The background has no baked-in readings. Custom arrows and a moving seconds
marker remain editor probes. This script never connects to or uploads a watch.
"""

import copy
import hashlib
import json
import math
import sys
import zipfile
from io import BytesIO
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT.parent / "tools"))
from tbwf import default_spec, text, solid, write_face, check_face, ZIP_DATE
from render_rules import draw_value, glyph_cell, digit_centre, whole_top, DATE_SET, STAT_SET

SIZE = 454
CREAM = 0xFFF7DFA8 - 2**32
ORANGE = 0xFFFF6515 - 2**32
TEAL = 0xFF55C7C6 - 2**32
FONTS = {
    "time": "RT2RetroTimeBlock.ttf", "header": "RT2RetroHeader.ttf",
    "stats": "RT2RetroStats.ttf", "value": "RT2RetroValue.ttf",
}
FONT_SHA256 = {
    "time": "d6f5baf73ae3db4328c669d3d7d27aa8ee6f843da6548c339eb683fcae714758",
    "header": "d0a208ab97d2533f7e12a20954480c544927e61216f2ee47c5c7f6b82fcfee40",
    "stats": "a28601578303d684caa8c71ea435dcffe1e0dc39a2f87f0d649260fc2b4a5ede",
    "value": "09234a584070abbd53704864dcdec081f193dc717a087898be9dae67dd4fb270",
}
DAYS = ["lun", "mar", "mer", "gio", "ven", "sab", "dom"]


def font_path(key):
    return ROOT / "font" / FONTS[key]


def top_for_baseline(baseline, size, key, charset=DATE_SET, whole=False):
    px = int(SIZE * size)
    top = whole_top(str(font_path(key)), px, charset) if whole else glyph_cell(str(font_path(key)), px, charset).top
    return baseline + top / SIZE


def layout():
    spec = default_spec()
    e = spec["elements"]
    for element in e.values():
        element["visible"] = False
    e["dial"]["visible"] = True

    def label(name, x, y, size, key, color=CREAM, anchor=32):
        e[name] = text(x, y, size, color, family="/font/" + FONTS[key], properties=anchor)

    header_size, header_baseline = .068, .173
    label("dayOfWeek", .318, top_for_baseline(header_baseline, header_size, "header", DAYS, True), header_size, "header", anchor=33)
    header_y = top_for_baseline(header_baseline, header_size, "header")
    label("day", .477, header_y, header_size, "header")
    label("dateSeparator", .538, header_y, header_size, "header")
    label("month", .607, header_y, header_size, "header", ORANGE)

    time_y, time_size = .216, .300
    label("hour", .475, time_y, time_size, "time", anchor=64)
    label("minute", .550, time_y, time_size, "time", anchor=16)
    middle = digit_centre(str(font_path("time")), int(SIZE * time_size), DATE_SET)
    colon_size = .290
    colon_h = glyph_cell(str(font_path("time")), int(SIZE * colon_size), ":").height
    label("timeSeparator", .512, time_y + (middle - colon_h / 2) / SIZE, colon_size, "time")

    value_size = .115
    label("weatherTemperature", .340, top_for_baseline(.550, value_size, "value"), value_size, "value")
    # The user's source photo is a design, not the numerical source. The
    # native temperature remains the existing approximate Fahrenheit value.
    e["weatherTemperatureUnitSign"]["visible"] = False
    e["weatherResource"]["visible"] = False

    # Native values inside the three rings. Rings themselves are decorative.
    for name, x in [("step", .289), ("heartRate", .504), ("calorie", .712)]:
        size = .058
        label(name, x, top_for_baseline(.817, size, "stats", STAT_SET), size, "stats")
    return spec


def arrow(code):
    # Original code-drawn glyphs; no weather icon or clinical reading baked in.
    n, scale = 64, 4
    art = Image.new("RGBA", (n * scale, n * scale))
    d = ImageDraw.Draw(art)
    color = "#55C7C6"

    def stroke(points):
        d.line([(int(x * scale), int(y * scale)) for x, y in points], fill=color,
               width=5 * scale, joint="curve")
        for x, y in [points[0], points[-1]]:
            r = 2.5 * scale
            d.ellipse((x*scale-r, y*scale-r, x*scale+r, y*scale+r), fill=color)

    if code == 1:
        stroke([(12, 32), (51, 32)]); stroke([(37, 18), (51, 32), (37, 46)])
    elif code == 2:
        stroke([(14, 50), (50, 14)]); stroke([(27, 14), (50, 14), (50, 37)])
    elif code == 3:
        stroke([(32, 52), (32, 12)]); stroke([(18, 26), (32, 12), (46, 26)])
    elif code == 4:
        stroke([(14, 14), (50, 50)]); stroke([(27, 50), (50, 50), (50, 27)])
    elif code == 5:
        stroke([(32, 12), (32, 52)]); stroke([(18, 38), (32, 52), (46, 38)])
    elif code == 6:
        for x in [21, 43]:
            stroke([(x, 12), (x, 50)]); stroke([(x-8, 40), (x, 50), (x+8, 40)])
    else:
        stroke([(24, 24), (40, 40)]); stroke([(24, 40), (40, 24)])
    return art.resize((n, n), Image.Resampling.LANCZOS)


def png(art):
    b = BytesIO()
    art.save(b, "PNG", optimize=True)
    return b.getvalue()


def pack(out, spec, dial, extra=None):
    # write_face bundles the time font; every other named font is added below.
    write_face(out, spec, dial, font_path("time"))
    with zipfile.ZipFile(out) as z:
        entries = {n: z.read(n) for n in z.namelist()}
    for filename in FONTS.values():
        path = ROOT / "font" / filename
        entries["/font/" + path.name] = path.read_bytes()
    for path in (ROOT / "licenses").glob("*.txt"):
        # Keep archives stable when Git checks text out with Windows CRLF.
        entries["licenses/" + path.name] = path.read_text(encoding="utf-8").replace("\r\n", "\n").encode("utf-8")
    entries.update(extra or {})
    with zipfile.ZipFile(out, "w") as z:
        for name in sorted(entries):
            info = zipfile.ZipInfo(name, ZIP_DATE)
            info.compress_type = zipfile.ZIP_DEFLATED
            z.writestr(info, entries[name])


def probe_spec(base):
    spec = copy.deepcopy(base)
    e = spec["elements"]
    e["weatherResource"] = {
        "resourceImage": {"resource": "/resourceImage/trend_arrows.png", "sections": 16,
                          "size": .095, "width": 64, "height": 1024, "mimeType": "image/png"},
        "color": solid(-1), "properties": 16, "visible": True, "x": .442, "y": .461,
    }
    e["secondHand"] = {
        "resourceImage": {"resource": "/resourceImage/secondHand.png", "sections": 1,
                          "size": 1.0, "width": SIZE, "height": SIZE, "pivotY": 0.0,
                          "mimeType": "image/png"},
        "color": solid(-1), "properties": 2, "visible": True, "x": .5, "y": .5,
    }
    return spec


def render(spec, dial, design=False):
    # Entirely synthetic demo values. They are not added to any TBWF JSON.
    values = {
        "dayOfWeek": ("sab", DAYS), "day": ("14", DATE_SET), "dateSeparator": ("/", "/"),
        "month": ("11", DATE_SET), "hour": ("10", DATE_SET), "timeSeparator": (":", ":"),
        "minute": ("48", DATE_SET), "weatherTemperature": ("112", DATE_SET),
        "step": ("8.542" if design else "8542", STAT_SET + "."),
        "heartRate": ("72", STAT_SET), "calorie": ("438", STAT_SET),
    }
    image = dial.copy()
    for name, (value, charset) in values.items():
        if design and name in ["dateSeparator", "month"]:
            continue
        e = spec["elements"][name]
        family = Path(e["font"]["family"]).name
        draw_value(image, e, value, charset, str(ROOT / "font" / family), name == "dayOfWeek")
    if design:
        # Full month names and grouping are design-only until a native format
        # setting is verified. The base TBWF uses native numeric day/month.
        f = ImageFont.truetype(str(font_path("header")), int(SIZE * .068))
        ImageDraw.Draw(image).text((.600 * SIZE, .173 * SIZE), "NOV", font=f,
                                   fill="#FF6515", anchor="ms")
        art = arrow(2).resize((43, 43), Image.Resampling.LANCZOS)
        image.paste(art, (round(.442 * SIZE), round(.461 * SIZE)), art)
    return image


def verify(out, is_probe):
    assert not check_face(out)
    with zipfile.ZipFile(out) as z:
        assert z.testzip() is None
        assert len(z.namelist()) == len(set(z.namelist()))
        spec = json.loads(z.read("TiBoWaFe.json"))
        assert len(spec["elements"]) == 30
        assert Image.open(BytesIO(z.read("/resourceImage/dial.png"))).size == (SIZE, SIZE)
        for name, e in spec["elements"].items():
            if "font" in e:
                # Hidden template elements use built-in fonts.
                family = e["font"]["family"]
                assert not family.startswith("/font/") or family in z.namelist(), name
            if e.get("visible") and "resourceImage" in e:
                assert e["resourceImage"]["resource"] in z.namelist(), name
        if is_probe:
            assert Image.open(BytesIO(z.read("/resourceImage/trend_arrows.png"))).size == (64, 1024)
        else:
            assert not spec["elements"]["weatherResource"]["visible"]
            assert not spec["elements"]["secondHand"]["visible"]
    return {
        "file": out.name, "bytes": out.stat().st_size,
        "sha256": hashlib.sha256(out.read_bytes()).hexdigest(),
        "zip_json_png_fonts": "passed",
        "editor_import": "NOT TESTED", "watch_upload": "NOT PERFORMED",
        "weather_on_home": "UNVERIFIED",
        "arrows": "EDITOR PROBE, UNVERIFIED" if is_probe else "not enabled",
        "native_second_hand": "EDITOR PROBE, UNVERIFIED" if is_probe else "not enabled",
        "native_month": "numeric; NOV in the design preview only",
        "native_steps": "ungrouped; 8.542 in the design preview only",
        "rings": "decorative, not live progress or heart-rate thresholds",
        "out_of_range_red": "NOT IMPLEMENTED on watch; native text colour is static",
        "data_source": "existing approximate weather temperature; no protocol changes",
    }


def main():
    for key in FONTS:
        assert hashlib.sha256(font_path(key).read_bytes()).hexdigest() == FONT_SHA256[key]
    # A normal asset conversion for the TBWF canvas, not a data screenshot.
    dial = Image.open(ROOT / "assets/retro-background.png").convert("RGB").resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    spec = layout()
    (ROOT / "TiBoWaFe.json").write_text(json.dumps(spec, indent=2)+"\n", encoding="utf-8", newline="\n")
    base = ROOT / "RT2-Retro.tbwf"
    pack(base, spec, dial)

    strip = Image.new("RGBA", (64, 1024))
    for code in range(16):
        art = arrow(code)
        strip.paste(art, (0, code * 64))
    second = Image.new("RGBA", (SIZE, SIZE))
    ImageDraw.Draw(second).ellipse((224, 6, 230, 12), fill="#F7DFA8")
    probe = ROOT / "RT2-Retro-Arrows-EDITOR-PROBE.tbwf"
    pack(probe, probe_spec(spec), dial, {"/resourceImage/trend_arrows.png": png(strip),
                                        "/resourceImage/secondHand.png": png(second)})

    native_preview = render(spec, dial)
    design = render(spec, dial, True)
    native_preview.resize((360,360), Image.Resampling.LANCZOS).save(ROOT / "RT2-Retro-base-DEMO.png")
    design.resize((360,360), Image.Resampling.LANCZOS).save(ROOT / "RT2-Retro-design-360-DEMO.png")
    design.resize((1080,1080), Image.Resampling.LANCZOS).save(ROOT / "RT2-Retro-design-DEMO.png")
    frames = []
    for second in range(60):
        frame = design.copy()
        a = math.radians(second * 6 - 90)
        x, y = .493 * SIZE + .473 * SIZE * math.cos(a), .491 * SIZE + .473 * SIZE * math.sin(a)
        ImageDraw.Draw(frame).ellipse((x-1.3,y-1.3,x+1.3,y+1.3), fill="#FFF0CA")
        frames.append(frame.resize((360,360), Image.Resampling.LANCZOS))
    frames[0].save(ROOT / "RT2-Retro-animation-DEMO.gif", save_all=True,
                   append_images=frames[1:], duration=1000, loop=0, disposal=2)
    report = [verify(base, False), verify(probe, True)]
    (ROOT / "validation.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8", newline="\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
