#!/usr/bin/env python3
"""Builds Shellbee's App Store screenshots from raw simulator captures.

Each panel is a honey-toned backdrop with a faint honeycomb, a headline, and
the screenshot in a device frame. One dotted flight path runs across all the
panels of a set side by side, looping as it goes, with the bee at a
different point of it in every panel, so the set reads as one flight when
the App Store lays the panels out in a row.

    python3 marketing/app-store/make_screenshots.py

Raw captures live in raw/ (1320x2868 iPhone 6.9", 2064x2752 iPad 13");
output goes to out/iphone/ and out/ipad/ at the same sizes.
"""

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).parent
RAW = ROOT / "raw"
OUT = ROOT / "out"

FONT_BOLD = "/Library/Fonts/SF-Pro-Rounded-Bold.otf"
FONT_MEDIUM = "/Library/Fonts/SF-Pro-Rounded-Medium.otf"

INK = (38, 52, 58)            # the icon's slate, for text and the bee's stripes
SUBTLE = (92, 104, 108)
HONEY_TOP = (255, 247, 228)
HONEY_BOTTOM = (255, 214, 128)
COMB = (255, 196, 84)
BEE_YELLOW = (255, 190, 30)
TRAIL = (38, 52, 58, 150)
# Where the bee sits along each panel's stretch of the path (0-1), so it
# isn't in the same spot twice in a row.
BEE_STOPS = [0.66, 0.3, 0.78, 0.42, 0.7, 0.55]

IPHONE = [
    ("iphone-01-home", "Your Zigbee home,\nat a glance", "Bridges, health and what needs attention"),
    ("iphone-03-light", "Control every light", "Brightness, color and effects in one card"),
    ("iphone-02-devices", "All your devices,\none tap away", "Signal, status and battery for each one"),
    ("iphone-04-batteries", "Know which\nbatteries to replace", "Sorted by what to do next"),
    ("iphone-05-activity", "See what just\nhappened", "A live feed of every change"),
    ("iphone-06-group-honey", "Make it yours", "Groups, scenes and color themes"),
]

IPAD = [
    ("ipad-01-home", "Built for iPad", "Everything on your Zigbee network, side by side"),
    ("ipad-04-network-map", "See your whole mesh", "Every router and device, live"),
    ("ipad-02-devices", "Filter by anything", "Status, type, manufacturer and more"),
    ("ipad-03-activity", "Follow every event", "Live activity from your bridge"),
]


# ── Drawing helpers ───────────────────────────────────────────────────────

def backdrop(w, h):
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        t = y / (h - 1)
        c = tuple(round(a + (b - a) * t) for a, b in zip(HONEY_TOP, HONEY_BOTTOM))
        for x in range(w):
            px[x, y] = c
    return img


def honeycomb(img, x_offset):
    """A faint hexagon grid that continues across panels (`x_offset`)."""
    w, h = img.size
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    r = w * 0.055
    dx, dy = r * math.sqrt(3), r * 1.5
    row = 0
    y = -r
    while y < h + r:
        shift = (dx / 2) if row % 2 else 0
        x = -((x_offset + shift) % dx) - dx + shift * 0
        x = -((x_offset - shift) % dx)
        while x < w + dx:
            pts = [(x + r * math.cos(math.radians(60 * k + 30)), y + r * math.sin(math.radians(60 * k + 30)))
                   for k in range(6)]
            # Fade the comb out towards the top so the headline stays clean.
            alpha = int(46 * min(1, max(0, (y / h - 0.1) / 0.5)))
            if alpha:
                d.line(pts + [pts[0]], fill=COMB + (alpha,), width=max(2, int(w * 0.0025)))
            x += dx
        y += dy
        row += 1
    img.paste(layer, (0, 0), layer)


def rounded_mask(size, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=255)
    return m


def device(shot, width, radius_ratio, bezel_ratio):
    """The screenshot in a black device frame with a soft shadow."""
    scale = width / shot.width
    screen = shot.convert("RGB").resize((width, round(shot.height * scale)), Image.LANCZOS)
    bezel = round(width * bezel_ratio)
    outer = (screen.width + 2 * bezel, screen.height + 2 * bezel)
    r_out = round(outer[0] * radius_ratio)
    r_in = max(1, r_out - bezel)

    frame = Image.new("RGBA", outer, (0, 0, 0, 0))
    ImageDraw.Draw(frame).rounded_rectangle([0, 0, outer[0] - 1, outer[1] - 1], radius=r_out, fill=(22, 24, 26, 255))
    # A thin lighter rim so the frame reads as metal, not a hole.
    ImageDraw.Draw(frame).rounded_rectangle([2, 2, outer[0] - 3, outer[1] - 3], radius=r_out - 2,
                                            outline=(70, 74, 78, 255), width=max(2, bezel // 6))
    frame.paste(screen, (bezel, bezel), rounded_mask(screen.size, r_in))

    pad = round(width * 0.08)
    shadow = Image.new("RGBA", (outer[0] + 2 * pad, outer[1] + 2 * pad), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([pad, pad + pad // 3, pad + outer[0], pad + outer[1] + pad // 3],
                                             radius=r_out, fill=(80, 50, 0, 90))
    shadow = shadow.filter(ImageFilter.GaussianBlur(pad / 2.5))
    shadow.paste(frame, (pad, pad), frame)
    return shadow, pad


def bee(size, heading):
    """A friendly bee, drawn large and scaled down for smooth edges, facing
    `heading` radians (0 = flying right)."""
    S = 4
    n = size * S
    im = Image.new("RGBA", (n * 2, n * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx, cy = n, n
    bw, bh = n * 0.62, n * 0.44          # body half-extents

    # Wings behind the body, translucent.
    for dxw, tilt in ((-0.18, -1), (0.12, -1)):
        wx, wy = cx + dxw * n, cy - bh * 1.05
        d.ellipse([wx - n * 0.26, wy - n * 0.36, wx + n * 0.26, wy + n * 0.2],
                  fill=(255, 255, 255, 190), outline=INK + (255,), width=int(n * 0.045))

    # Stinger.
    d.polygon([(cx - bw * 0.98, cy - n * 0.07), (cx - bw * 1.28, cy), (cx - bw * 0.98, cy + n * 0.07)],
              fill=INK + (255,))
    # Body.
    d.ellipse([cx - bw, cy - bh, cx + bw, cy + bh], fill=BEE_YELLOW + (255,),
              outline=INK + (255,), width=int(n * 0.05))
    # Stripes, clipped to the body.
    stripes = Image.new("RGBA", im.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(stripes)
    for sx in (-0.42, -0.08):
        x0 = cx + sx * bw
        sd.rectangle([x0, cy - bh, x0 + bw * 0.2, cy + bh], fill=INK + (255,))
    body_mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(body_mask).ellipse([cx - bw, cy - bh, cx + bw, cy + bh], fill=255)
    im.paste(stripes, (0, 0), Image.composite(stripes, Image.new("RGBA", im.size), body_mask))

    # Head.
    hx, hr = cx + bw * 0.92, n * 0.3
    d.ellipse([hx - hr, cy - hr, hx + hr, cy + hr], fill=INK + (255,))
    d.ellipse([hx + hr * 0.15, cy - hr * 0.45, hx + hr * 0.55, cy - hr * 0.05], fill=(255, 255, 255, 255))
    # Antennae.
    for ay in (-1, 1):
        d.line([(hx + hr * 0.2, cy - hr * 0.7 * ay if ay < 0 else cy - hr * 0.8),
                (hx + hr * 1.3, cy - hr * (1.9 if ay < 0 else 1.5))],
               fill=INK + (255,), width=int(n * 0.045))
    im = im.rotate(-math.degrees(heading), resample=Image.BICUBIC, expand=False)
    return im.resize((size * 2 // 1, size * 2 // 1), Image.LANCZOS)


# ── The flight path ───────────────────────────────────────────────────────

def flight(t, w, h, band):
    """Position on the path at parameter t (in panel widths). A prolate
    trochoid: a wave that ties a loop once per panel."""
    omega = 2 * math.pi
    loop = 0.16
    x = (t - loop * math.sin(omega * t + 1.2)) * w
    y = band * h + 0.022 * h * math.cos(omega * t + 1.2) + 0.008 * h * math.sin(omega * t * 0.5)
    return x, y


def draw_trail(img, panel, w, h, band, t_end):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    dot = max(3, round(w * 0.006))
    gap = w * 0.018
    t, last = 0.0, None
    step = 0.0005
    while t <= t_end:
        x, y = flight(t, w, h, band)
        if last is None or math.dist((x, y), last) >= gap:
            lx = x - panel * w
            if -dot <= lx <= w + dot:
                d.ellipse([lx - dot, y - dot, lx + dot, y + dot], fill=TRAIL)
            last = (x, y)
        t += step
    img.paste(layer, (0, 0), layer)


def place_bee(img, panel, w, h, band, t_bee, size):
    x, y = flight(t_bee, w, h, band)
    x2, y2 = flight(t_bee + 0.002, w, h, band)
    heading = math.atan2(y2 - y, x2 - x)
    b = bee(size, heading)
    img.paste(b, (round(x - panel * w - b.width / 2), round(y - b.height / 2)), b)


# ── Panels ────────────────────────────────────────────────────────────────

def panel(spec, index, count, *, w, h, device_width, radius, bezel, top, band, title_size, bee_size):
    name, title, subtitle = spec
    img = backdrop(w, h)
    honeycomb(img, index * w)

    d = ImageDraw.Draw(img)
    f_title = ImageFont.truetype(FONT_BOLD, title_size)
    f_sub = ImageFont.truetype(FONT_MEDIUM, round(title_size * 0.42))
    y = round(h * 0.055)
    d.multiline_text((w / 2, y), title, font=f_title, fill=INK, anchor="ma", align="center", spacing=title_size * 0.12)
    tb = d.multiline_textbbox((w / 2, y), title, font=f_title, anchor="ma", align="center", spacing=title_size * 0.12)
    d.text((w / 2, tb[3] + title_size * 0.38), subtitle, font=f_sub, fill=SUBTLE, anchor="ma")

    shot = Image.open(RAW / f"{name}.png")
    framed, pad = device(shot, device_width, radius, bezel)
    img.paste(framed, (round((w - framed.width) / 2), round(top - pad)), framed)

    # The path runs through every panel so it joins up edge to edge; the
    # bee sits at a different point of it in each, and the trail stops at
    # the bee only in the last panel, where the flight ends.
    t_bee = index + BEE_STOPS[index % len(BEE_STOPS)]
    draw_trail(img, index, w, h, band, t_bee - 0.03 if index == count - 1 else count + 1)
    place_bee(img, index, w, h, band, t_bee, round(w * bee_size))
    return img


def build(specs, folder, **kw):
    out = OUT / folder
    out.mkdir(parents=True, exist_ok=True)
    for i, spec in enumerate(specs):
        img = panel(spec, i, len(specs), **kw)
        path = out / f"{i + 1:02d}-{spec[0].split('-', 2)[-1]}.png"
        img.convert("RGB").save(path, optimize=True)
        print(path.relative_to(ROOT), img.size)


if __name__ == "__main__":
    build(IPHONE, "iphone", w=1320, h=2868, device_width=960, radius=0.145, bezel=0.03,
          top=round(2868 * 0.235), band=0.252, title_size=118, bee_size=0.1)
    build(IPAD, "ipad", w=2064, h=2752, device_width=1520, radius=0.05, bezel=0.022,
          top=round(2752 * 0.215), band=0.24, title_size=140, bee_size=0.066)
