#!/usr/bin/env python3
"""Renders the MacPleco app icon into Resources/AppIcon.iconset.

Written against the standard library alone — no Pillow, no cairo — because the
icon is a handful of filled paths and a gradient, and a dependency that has to
be installed in CI to draw them would be the more fragile choice.

Anti-aliasing is scanline coverage: four sample rows per output row, with
fractional coverage at both ends of every span.

    python3 scripts/make-icon.py
"""

import math
import os
import struct
import zlib

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Resources", "AppIcon.iconset")

# macOS draws app icons inside a squircle that leaves a margin on all sides.
MARGIN = 100 / 1024.0
BODY = 1.0 - 2 * MARGIN

SAMPLES = 4


# --------------------------------------------------------------------------
# Path building
# --------------------------------------------------------------------------

class Path:
    """Collects points, flattening curves as they are added."""

    def __init__(self):
        self.points = []

    def move(self, x, y):
        self.points.append((x, y))
        return self

    def line(self, x, y):
        self.points.append((x, y))
        return self

    def quad(self, cx, cy, x, y, steps=24):
        x0, y0 = self.points[-1]
        for i in range(1, steps + 1):
            t = i / steps
            u = 1 - t
            self.points.append((
                u * u * x0 + 2 * u * t * cx + t * t * x,
                u * u * y0 + 2 * u * t * cy + t * t * y,
            ))
        return self

    def cubic(self, c1x, c1y, c2x, c2y, x, y, steps=28):
        x0, y0 = self.points[-1]
        for i in range(1, steps + 1):
            t = i / steps
            u = 1 - t
            self.points.append((
                u ** 3 * x0 + 3 * u * u * t * c1x + 3 * u * t * t * c2x + t ** 3 * x,
                u ** 3 * y0 + 3 * u * u * t * c1y + 3 * u * t * t * c2y + t ** 3 * y,
            ))
        return self


def squircle(cx, cy, half, exponent=5.0, steps=480):
    """Apple's rounded-rect is closer to a superellipse than to a rounded box."""
    path = Path()
    for i in range(steps):
        theta = 2 * math.pi * i / steps
        c, s = math.cos(theta), math.sin(theta)
        x = cx + half * math.copysign(abs(c) ** (2.0 / exponent), c)
        y = cy + half * math.copysign(abs(s) ** (2.0 / exponent), s)
        if i == 0:
            path.move(x, y)
        else:
            path.line(x, y)
    return path


def circle(cx, cy, r, steps=64):
    path = Path()
    for i in range(steps):
        theta = 2 * math.pi * i / steps
        x, y = cx + r * math.cos(theta), cy + r * math.sin(theta)
        path.move(x, y) if i == 0 else path.line(x, y)
    return path


def pleco(scale, ox, oy):
    """A stylised plecostomus in side view, facing left.

    The silhouette leans on the three features that make the fish readable at a
    glance: the blunt sucker-mouth snout, the tall swept dorsal sail, and the
    forked tail. Everything else is smoothed away so the shape survives being
    drawn sixteen pixels wide.
    """
    def p(x, y):
        return (ox + x * scale, oy + y * scale)

    path = Path()
    sx, sy = p(0.13, 0.545)
    path.move(sx, sy)
    # Head and back rising to the dorsal fin.
    path.cubic(*p(0.17, 0.455), *p(0.27, 0.425), *p(0.355, 0.425))
    # Dorsal sail — the feature that says "pleco" rather than "fish", so it
    # rises steeply at the front and sweeps back instead of being a hump.
    path.line(*p(0.330, 0.420))
    path.cubic(*p(0.360, 0.205), *p(0.445, 0.158), *p(0.532, 0.205))
    path.cubic(*p(0.600, 0.243), *p(0.636, 0.330), *p(0.650, 0.412))
    # Back running to the tail.
    path.cubic(*p(0.697, 0.428), *p(0.743, 0.448), *p(0.778, 0.476))
    # Forked tail.
    path.line(*p(0.92, 0.335))
    path.quad(*p(0.865, 0.545), *p(0.92, 0.755))
    path.line(*p(0.775, 0.615))
    # Belly back toward the head.
    path.cubic(*p(0.70, 0.665), *p(0.60, 0.695), *p(0.475, 0.695))
    # Pectoral fin.
    path.line(*p(0.415, 0.695))
    path.quad(*p(0.35, 0.815), *p(0.255, 0.735))
    path.quad(*p(0.215, 0.705), *p(0.205, 0.675))
    # Snout.
    path.cubic(*p(0.16, 0.655), *p(0.13, 0.605), *p(0.13, 0.545))
    return path


# --------------------------------------------------------------------------
# Rasterising
# --------------------------------------------------------------------------

def rasterize(paths, size):
    """Returns a per-pixel coverage buffer in 0.0...1.0."""
    coverage = [0.0] * (size * size)
    edges = []
    for path in paths:
        pts = path.points
        for i in range(len(pts)):
            x0, y0 = pts[i]
            x1, y1 = pts[(i + 1) % len(pts)]
            if y0 != y1:
                edges.append((x0, y0, x1, y1))

    if not edges:
        return coverage

    weight = 1.0 / SAMPLES
    for row in range(size):
        base = row * size
        for s in range(SAMPLES):
            y = row + (s + 0.5) / SAMPLES
            crossings = []
            for (x0, y0, x1, y1) in edges:
                if (y0 <= y < y1) or (y1 <= y < y0):
                    crossings.append(x0 + (y - y0) / (y1 - y0) * (x1 - x0))
            if not crossings:
                continue
            crossings.sort()
            for i in range(0, len(crossings) - 1, 2):
                a, b = crossings[i], crossings[i + 1]
                a = max(0.0, a)
                b = min(float(size), b)
                if b <= a:
                    continue
                ia, ib = int(a), int(b)
                if ia == ib:
                    coverage[base + ia] += (b - a) * weight
                    continue
                coverage[base + ia] += (ia + 1 - a) * weight
                for x in range(ia + 1, min(ib, size)):
                    coverage[base + x] += weight
                if ib < size:
                    coverage[base + ib] += (b - ib) * weight

    return [min(1.0, c) for c in coverage]


def lerp(a, b, t):
    return a + (b - a) * t


def light_rays(size):
    """Two soft shafts of light angling down from the upper left."""
    def quad(points):
        path = Path()
        path.move(*points[0])
        for point in points[1:]:
            path.line(*point)
        return path

    def scaled(points):
        return [(x * size, y * size) for (x, y) in points]

    wide = quad(scaled([(0.30, -0.05), (0.52, -0.05), (0.30, 1.05), (0.12, 1.05)]))
    slim = quad(scaled([(0.58, -0.05), (0.70, -0.05), (0.52, 1.05), (0.42, 1.05)]))
    return rasterize([wide], size), rasterize([slim], size)


def render(size):
    half = BODY * size / 2.0
    center = size / 2.0

    shell = rasterize([squircle(center, center, half)], size)
    fish_scale = BODY * size
    fish_ox = center - fish_scale / 2.0
    fish_oy = center - fish_scale / 2.0
    body = rasterize([pleco(fish_scale, fish_ox, fish_oy)], size)

    eye = rasterize([
        circle(
            fish_ox + 0.245 * fish_scale,
            fish_oy + 0.515 * fish_scale,
            max(0.9, 0.036 * fish_scale),
        )
    ], size)
    eye_glint = rasterize([
        circle(
            fish_ox + 0.253 * fish_scale,
            fish_oy + 0.505 * fish_scale,
            max(0.5, 0.012 * fish_scale),
        )
    ], size)

    # Bubbles rising from the snout.
    bubbles = rasterize([
        circle(fish_ox + 0.155 * fish_scale, fish_oy + 0.360 * fish_scale, max(0.8, 0.020 * fish_scale)),
        circle(fish_ox + 0.205 * fish_scale, fish_oy + 0.265 * fish_scale, max(0.6, 0.014 * fish_scale)),
        circle(fish_ox + 0.165 * fish_scale, fish_oy + 0.180 * fish_scale, max(0.5, 0.009 * fish_scale)),
    ], size)

    ray_wide, ray_slim = light_rays(size)

    pixels = bytearray()
    for y in range(size):
        pixels.append(0)  # PNG filter type 0 for each row
        v = y / max(1, size - 1)
        for x in range(size):
            index = y * size + x
            u = x / max(1, size - 1)

            # Deep water: lit near the surface, near-black at the floor, with a
            # gentle diagonal lift so the face is not flat.
            diagonal = u * 0.35 + (1 - v) * 0.65
            r = lerp(6, 34, diagonal ** 1.35)
            g = lerp(20, 96, diagonal ** 1.2)
            b = lerp(38, 122, diagonal ** 1.1)

            # Light shafts, fading with depth.
            ray = ray_wide[index] * 0.10 + ray_slim[index] * 0.07
            if ray > 0:
                fade = max(0.0, 1.0 - v * 1.1)
                r = lerp(r, 210, ray * fade)
                g = lerp(g, 240, ray * fade)
                b = lerp(b, 250, ray * fade)

            # Fish: bright aqua, brighter along its top edge.
            cover = body[index]
            if cover > 0:
                fr, fg, fb = 118, 236, 214
                shade = 1.0 - 0.28 * v
                fr, fg, fb = fr * shade, fg * shade + 8, fb * shade + 6
                r = lerp(r, fr, cover)
                g = lerp(g, fg, cover)
                b = lerp(b, fb, cover)

            if eye[index] > 0:
                r = lerp(r, 8, eye[index])
                g = lerp(g, 26, eye[index])
                b = lerp(b, 44, eye[index])
            if eye_glint[index] > 0:
                r = lerp(r, 235, eye_glint[index] * 0.9)
                g = lerp(g, 250, eye_glint[index] * 0.9)
                b = lerp(b, 250, eye_glint[index] * 0.9)

            bubble = bubbles[index] * max(0.0, 1.0 - cover)
            if bubble > 0:
                r = lerp(r, 205, bubble * 0.55)
                g = lerp(g, 242, bubble * 0.55)
                b = lerp(b, 238, bubble * 0.55)

            # Corner vignette for depth.
            dx, dy = u - 0.5, v - 0.5
            dim = 1.0 - 0.20 * min(1.0, (dx * dx + dy * dy) * 2.6)
            r, g, b = r * dim, g * dim, b * dim

            alpha = shell[index]
            pixels.extend((
                int(max(0, min(255, r))),
                int(max(0, min(255, g))),
                int(max(0, min(255, b))),
                int(alpha * 255),
            ))

    return bytes(pixels)


def write_png(path, size, raw):
    def chunk(tag, data):
        payload = tag + data
        return struct.pack(">I", len(data)) + payload + struct.pack(">I", zlib.crc32(payload) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", header)
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as handle:
        handle.write(png)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    targets = [
        (16, "icon_16x16.png"),
        (32, "icon_16x16@2x.png"),
        (32, "icon_32x32.png"),
        (64, "icon_32x32@2x.png"),
        (128, "icon_128x128.png"),
        (256, "icon_128x128@2x.png"),
        (256, "icon_256x256.png"),
        (512, "icon_256x256@2x.png"),
        (512, "icon_512x512.png"),
        (1024, "icon_512x512@2x.png"),
    ]

    cache = {}
    for size, name in targets:
        if size not in cache:
            cache[size] = render(size)
            print(f"  rendered {size}x{size}")
        write_png(os.path.join(OUT_DIR, name), size, cache[size])

    print(f"Wrote {len(targets)} images to {os.path.normpath(OUT_DIR)}")


if __name__ == "__main__":
    main()
