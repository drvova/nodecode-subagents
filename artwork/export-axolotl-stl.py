from __future__ import annotations

import json
import math
import re
import struct
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SVG_PATH = ROOT / "media" / "nodecode-axolotl.svg"
PIXELS_PATH = ROOT / "axo-pixels.json"
STL_PATH = ROOT / "media" / "nodecode-axolotl.stl"
RECTANGLE = re.compile(
    r"M(?P<x>-?\d+(?:\.\d+)?)\s+(?P<y>-?\d+(?:\.\d+)?)"
    r"h(?P<w>-?\d+(?:\.\d+)?)v(?P<h>-?\d+(?:\.\d+)?)"
    r"h(?P<close>-?\d+(?:\.\d+)?)z"
)
SVG_NS = "{http://www.w3.org/2000/svg}"


def read_source() -> tuple[float, float, list[dict[str, object]]]:
    root = ET.parse(SVG_PATH).getroot()
    _, _, width, height = (float(value) for value in root.attrib["viewBox"].split())
    layers = []
    paths = root.findall(f"{SVG_NS}path")
    if not paths:
        raise ValueError(f"No mascot paths found in {SVG_PATH}")

    for path in paths:
        data = path.attrib["d"]
        matches = list(RECTANGLE.finditer(data))
        if len(matches) != data.count("M"):
            raise ValueError(f"Unsupported non-rectangular path in {SVG_PATH}: {data[:80]}")

        rectangles = []
        for match in matches:
            x, y, rect_width, rect_height, close_width = (
                float(match.group(name)) for name in ("x", "y", "w", "h", "close")
            )
            if rect_width <= 0 or rect_height <= 0 or not math.isclose(rect_width + close_width, 0, abs_tol=1e-8):
                raise ValueError(f"Invalid pixel rectangle: {match.group(0)}")
            rectangles.append([x, y, rect_width, rect_height])

        layers.append({"fill": path.attrib["fill"], "rectangles": rectangles})

    return width, height, layers


def stl_normal(triangle: tuple[tuple[float, float, float], ...]) -> tuple[float, float, float]:
    a, b, c = triangle
    u = (b[0] - a[0], b[1] - a[1], b[2] - a[2])
    v = (c[0] - a[0], c[1] - a[1], c[2] - a[2])
    n = (u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0])
    length = math.sqrt(sum(component * component for component in n)) or 1
    return tuple(component / length for component in n)


def rectangle_triangles(x: float, y: float, width: float, height: float, depth_min: float, depth_max: float):
    # Model space is centred and scaled to 100 SVG units per scene unit.
    x0, x1 = (x - 156) / 100, (x + width - 156) / 100
    y0, y1 = (133 - y - height) / 100, (133 - y) / 100
    z0, z1 = depth_min, depth_max
    corners = (
        (x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
        (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1),
    )
    faces = (
        (0, 2, 1), (0, 3, 2),
        (4, 5, 6), (4, 6, 7),
        (0, 1, 5), (0, 5, 4),
        (1, 2, 6), (1, 6, 5),
        (2, 3, 7), (2, 7, 6),
        (3, 0, 4), (3, 4, 7),
    )
    return [tuple(corners[index] for index in face) for face in faces]


def write_stl(layers: list[dict[str, object]]) -> int:
    triangles = []
    for layer_index, layer in enumerate(layers):
        z0 = -0.08 + layer_index * 0.015
        z1 = z0 + 0.16
        for x, y, width, height in layer["rectangles"]:
            triangles.extend(rectangle_triangles(x, y, width, height, z0, z1))

    with STL_PATH.open("wb") as model:
        model.write(b"Nodecode official SVG geometry, extruded pixel layers".ljust(80, b"\0"))
        model.write(struct.pack("<I", len(triangles)))
        for triangle in triangles:
            normal = stl_normal(triangle)
            # STL viewers use Z-up; the live SVG and animation use Y-up.
            vertices = tuple((x, -z, y) for x, y, z in triangle)
            n = (normal[0], -normal[2], normal[1])
            model.write(struct.pack("<12fH", *n, *vertices[0], *vertices[1], *vertices[2], 0))
    return len(triangles)


def main() -> None:
    width, height, layers = read_source()
    PIXELS_PATH.write_text(
        json.dumps({"source": "media/nodecode-axolotl.svg", "viewBox": [width, height], "layers": layers}, indent=2) + "\n",
        encoding="utf-8",
    )
    triangle_count = write_stl(layers)
    print(f"Parsed {len(layers)} official SVG paths and {sum(len(layer['rectangles']) for layer in layers)} exact pixel rectangles")
    print(f"Wrote {PIXELS_PATH} and {STL_PATH} ({triangle_count:,} triangles)")


if __name__ == "__main__":
    main()
