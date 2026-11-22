#!/usr/bin/env python3
"""Art pass sprite generator — match Town Center / Barracks textured style.

Warm wood, shading, dark outlines. Castle = textured Czech stone (largest).
Units match villager/soldier detail; team color on shield/banner (TEAM green).
Run: python tools/gen_art_pass_sprites.py
"""
from __future__ import annotations

import os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Palette aligned with barracks / town_center
OUT = (18, 14, 12, 255)
WOOD = (92, 58, 32, 255)
WOOD_DK = (58, 34, 18, 255)
WOOD_LT = (138, 96, 55, 255)
WOOD_HL = (168, 124, 78, 255)
THATCH = (196, 152, 58, 255)
THATCH_DK = (140, 100, 32, 255)
THATCH_LT = (220, 180, 90, 255)
SHINGLE = (168, 78, 42, 255)
SHINGLE_DK = (120, 48, 28, 255)
SHINGLE_LT = (198, 110, 60, 255)
STONE = (132, 128, 118, 255)
STONE_DK = (88, 84, 76, 255)
STONE_LT = (168, 164, 152, 255)
STONE_MOR = (62, 58, 52, 255)
IRON = (150, 154, 162, 255)
IRON_DK = (90, 94, 102, 255)
IRON_LT = (200, 204, 212, 255)
SKIN = (210, 170, 130, 255)
SKIN_DK = (170, 120, 90, 255)
HAIR = (70, 48, 28, 255)
BOOT = (48, 32, 22, 255)
HORSE = (120, 82, 48, 255)
HORSE_DK = (78, 50, 28, 255)
HORSE_LT = (150, 110, 70, 255)
# Team color — shield / banner / tunic accent (modulates for enemy red tint)
TEAM = (48, 150, 78, 255)
TEAM_DK = (28, 100, 50, 255)
TEAM_LT = (80, 190, 110, 255)
GRASS = (70, 130, 55, 255)
ORE = (170, 150, 70, 255)
ORE_DK = (110, 90, 40, 255)


def save(rel: str, img: Image.Image) -> None:
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print("wrote", rel, img.size)


def blank(w: int, h: int) -> Image.Image:
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def px(img: Image.Image, x: int, y: int, c) -> None:
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), c)


def rect(img: Image.Image, x0, y0, x1, y1, c) -> None:
    d = ImageDraw.Draw(img)
    d.rectangle([x0, y0, x1, y1], fill=c)


def outline_rect(img, x0, y0, x1, y1, fill, outline=OUT) -> None:
    rect(img, x0, y0, x1, y1, fill)
    d = ImageDraw.Draw(img)
    d.rectangle([x0, y0, x1, y1], outline=outline)


def log_wall(img, x0, y0, x1, y1) -> None:
    """Horizontal logs with shading + outline."""
    for y in range(y0, y1 + 1):
        band = (y - y0) % 5
        if band == 0:
            col = WOOD_DK
        elif band in (1, 2):
            col = WOOD_LT if (y // 5) % 2 == 0 else WOOD
        else:
            col = WOOD
        for x in range(x0, x1 + 1):
            # end-grain notch every few px
            if x in (x0, x1) or (x - x0) % 11 == 0 and band != 0:
                px(img, x, y, WOOD_DK)
            elif band == 1 and (x + y) % 7 == 0:
                px(img, x, y, WOOD_HL)
            else:
                px(img, x, y, col)
    d = ImageDraw.Draw(img)
    d.rectangle([x0, y0, x1, y1], outline=OUT)


def thatch_roof(img, points_top, y_eave, x_left, x_right) -> None:
    """Filled gable thatch with vertical straw texture."""
    d = ImageDraw.Draw(img)
    # triangle from peak points_top to eave
    peak = points_top
    poly = [peak, (x_right, y_eave), (x_left, y_eave)]
    d.polygon(poly, fill=THATCH, outline=OUT)
    # vertical straw
    for x in range(x_left + 1, x_right):
        # interpolate top y of roof at this x
        if x <= peak[0]:
            t = (x - x_left) / max(peak[0] - x_left, 1)
            y_top = int(y_eave + (peak[1] - y_eave) * t)
        else:
            t = (x - peak[0]) / max(x_right - peak[0], 1)
            y_top = int(peak[1] + (y_eave - peak[1]) * t)
        for y in range(y_top + 1, y_eave):
            if (x + y * 3) % 4 == 0:
                px(img, x, y, THATCH_DK)
            elif (x * 2 + y) % 5 == 0:
                px(img, x, y, THATCH_LT)
    d.line([peak, (x_left, y_eave)], fill=OUT)
    d.line([peak, (x_right, y_eave)], fill=OUT)
    d.line([(x_left, y_eave), (x_right, y_eave)], fill=OUT)


def shingle_roof(img, peak, y_eave, x_left, x_right) -> None:
    d = ImageDraw.Draw(img)
    poly = [peak, (x_right, y_eave), (x_left, y_eave)]
    d.polygon(poly, fill=SHINGLE, outline=OUT)
    for y in range(peak[1] + 2, y_eave, 3):
        for x in range(x_left + 2, x_right - 1):
            # stay inside triangle roughly
            if x <= peak[0]:
                t = (x - x_left) / max(peak[0] - x_left, 1)
                y_top = int(y_eave + (peak[1] - y_eave) * t)
            else:
                t = (x - peak[0]) / max(x_right - peak[0], 1)
                y_top = int(peak[1] + (y_eave - peak[1]) * t)
            if y <= y_top:
                continue
            if (x // 4 + y // 3) % 2 == 0:
                px(img, x, y, SHINGLE_DK)
            elif (x + y) % 6 == 0:
                px(img, x, y, SHINGLE_LT)
    d.line([peak, (x_left, y_eave)], fill=OUT)
    d.line([peak, (x_right, y_eave)], fill=OUT)


def stone_fill(img, x0, y0, x1, y1) -> None:
    for y in range(y0, y1 + 1):
        row = (y - y0) // 4
        for x in range(x0, x1 + 1):
            ox = ((row % 2) * 3)
            brick = ((x - x0 + ox) // 6)
            if (y - y0) % 4 == 0 or (x - x0 + ox) % 6 == 0:
                col = STONE_MOR
            elif (brick + row) % 3 == 0:
                col = STONE_LT
            elif (brick + row) % 3 == 1:
                col = STONE
            else:
                col = STONE_DK
            # warm tint variation
            if (x * 13 + y * 7) % 11 == 0 and col != STONE_MOR:
                col = (min(255, col[0] + 12), col[1], max(0, col[2] - 8), 255)
            px(img, x, y, col)
    d = ImageDraw.Draw(img)
    d.rectangle([x0, y0, x1, y1], outline=OUT)


def door(img, x0, y0, x1, y1) -> None:
    outline_rect(img, x0, y0, x1, y1, WOOD_DK)
    mid = (x0 + x1) // 2
    for y in range(y0 + 1, y1):
        px(img, mid, y, OUT)
    px(img, x1 - 2, (y0 + y1) // 2, WOOD_HL)


def window(img, x, y, w=5, h=6) -> None:
    outline_rect(img, x, y, x + w, y + h, (28, 32, 40, 255))
    px(img, x + 1, y + 1, (50, 60, 70, 255))


# ---------- Buildings ----------

def gen_stable() -> None:
    """LONG low stable + side pen with horse & hay — unique wide silhouette."""
    w, h = 128, 72
    img = blank(w, h)
    # long low barn body (wide rectangle, low roof)
    log_wall(img, 48, 28, 122, 64)
    # low shallow thatch (not tall gable)
    d = ImageDraw.Draw(img)
    d.polygon([(44, 30), (85, 8), (126, 30)], fill=THATCH, outline=OUT)
    for x in range(46, 125):
        t = (x - 44) / 41 if x < 85 else (126 - x) / 41
        y_top = int(30 - 22 * max(0.0, min(1.0, t if x < 85 else t)))
        if x <= 85:
            y_top = int(30 + (8 - 30) * (x - 44) / max(85 - 44, 1))
        else:
            y_top = int(8 + (30 - 8) * (x - 85) / max(126 - 85, 1))
        for y in range(y_top + 1, 30):
            if (x + y * 2) % 3 == 0:
                px(img, x, y, THATCH_DK)
            elif (x * 3 + y) % 5 == 0:
                px(img, x, y, THATCH_LT)
    d.line([(44, 30), (85, 8), (126, 30)], fill=OUT)
    # wide stall doors (3 bays) — reads as stable
    for bx in (54, 78, 102):
        outline_rect(img, bx, 40, bx + 16, 64, WOOD_DK)
        for y in range(42, 64):
            px(img, bx + 8, y, OUT)
    # hay loft opening
    outline_rect(img, 86, 32, 98, 40, (40, 30, 20, 255))
    # === PEN (left, dominant silhouette) ===
    for i, fx in enumerate(range(4, 50, 4)):
        outline_rect(img, fx, 36, fx + 2, 68, WOOD_LT if i % 2 else WOOD)
    rect(img, 4, 50, 50, 52, WOOD_DK)
    rect(img, 4, 62, 50, 64, WOOD_DK)
    # horse profile in pen (clear)
    outline_rect(img, 12, 44, 36, 56, HORSE)
    outline_rect(img, 34, 40, 46, 52, HORSE_LT)  # neck/head
    px(img, 44, 44, OUT)
    for lx in (14, 20, 28, 34):
        outline_rect(img, lx, 56, lx + 2, 66, HORSE_DK)
    for y in range(46, 56):
        px(img, 10, y, HAIR)  # tail
    # hay stack
    outline_rect(img, 4, 56, 14, 68, THATCH_LT)
    for y in range(57, 68):
        for x in range(5, 14):
            if (x + y) % 2:
                px(img, x, y, THATCH)
    for x in range(2, w - 2):
        if x % 2:
            px(img, x, h - 2, GRASS)
    save("assets/sprites/buildings/stable.png", img)


def gen_castle() -> None:
    """Czech stone castle — largest sprite for 160 footprint."""
    w, h = 156, 172
    img = blank(w, h)
    stone_fill(img, 18, 70, 138, 160)
    for cx in range(18, 139, 10):
        stone_fill(img, cx, 58, min(cx + 6, 138), 70)
        for x in range(cx + 1, min(cx + 6, 138)):
            px(img, x, 59, STONE_LT)
    stone_fill(img, 8, 28, 42, 160)
    for cx in range(8, 43, 7):
        stone_fill(img, cx, 16, min(cx + 4, 42), 28)
    shingle_roof(img, (25, 2), 20, 6, 44)
    stone_fill(img, 114, 28, 148, 160)
    for cx in range(114, 149, 7):
        stone_fill(img, cx, 16, min(cx + 4, 148), 28)
    shingle_roof(img, (131, 2), 20, 112, 150)
    stone_fill(img, 48, 48, 108, 160)
    shingle_roof(img, (78, 18), 50, 44, 112)
    rect(img, 52, 50, 104, 56, WOOD)
    for x in range(54, 104, 6):
        rect(img, x, 56, x + 1, 62, WOOD_DK)
    ImageDraw.Draw(img).rectangle([52, 50, 104, 56], outline=OUT)
    outline_rect(img, 68, 110, 88, 160, (24, 20, 16, 255))
    for dy, inset in [(0, 0), (1, 1), (2, 2), (3, 3)]:
        for x in range(68 + inset, 89 - inset):
            px(img, x, 110 + dy, WOOD_DK if dy > 1 else OUT)
    for y in range(118, 160):
        for x in range(70, 87):
            px(img, x, y, WOOD if (x - 70) % 4 else WOOD_DK)
    window(img, 56, 78, 8, 10)
    window(img, 92, 78, 8, 10)
    window(img, 18, 80, 6, 10)
    window(img, 128, 80, 6, 10)
    rect(img, 78, 22, 79, 46, WOOD_DK)
    for y in range(24, 40):
        for x in range(80, 96):
            px(img, x, y, TEAM if (x + y) % 2 == 0 else TEAM_LT)
    ImageDraw.Draw(img).rectangle([80, 24, 95, 39], outline=OUT)
    for x in range(4, w - 4):
        if x % 2:
            px(img, x, h - 3, GRASS)
    save("assets/sprites/buildings/castle.png", img)


def gen_mining_camp() -> None:
    """Mining: stone base shed + big ore cart + pickaxe + ore — not a wood hut."""
    w, h = 96, 90
    img = blank(w, h)
    # rocky ground / stone pad (unique vs lumber)
    stone_fill(img, 4, 70, 92, 86)
    # small shed BACK — short, stone+wood mix
    stone_fill(img, 28, 38, 72, 70)
    log_wall(img, 32, 34, 68, 50)
    # flat stone slab roof (not thatch) — unique silhouette
    outline_rect(img, 26, 28, 74, 36, STONE)
    for x in range(28, 74, 5):
        px(img, x, 30, STONE_LT)
        px(img, x + 1, 32, STONE_DK)
    ImageDraw.Draw(img).rectangle([26, 28, 74, 36], outline=OUT)
    # dark mine mouth
    outline_rect(img, 40, 48, 60, 70, (20, 16, 12, 255))
    # === DOMINANT: ore cart in front ===
    outline_rect(img, 8, 52, 40, 68, WOOD)
    for y in range(54, 68):
        if y % 3 == 0:
            for x in range(10, 40):
                px(img, x, y, WOOD_DK)
    # ore overflowing cart
    for i, (ox, oy) in enumerate([(12, 48), (18, 46), (24, 48), (30, 47), (16, 52), (26, 52)]):
        outline_rect(img, ox, oy, ox + 6, oy + 6, ORE if i % 2 == 0 else ORE_DK)
    # cart wheels
    outline_rect(img, 10, 66, 18, 78, BOOT)
    outline_rect(img, 30, 66, 38, 78, BOOT)
    px(img, 14, 71, IRON_LT)
    px(img, 34, 71, IRON_LT)
    # large pickaxe silhouette (right)
    d = ImageDraw.Draw(img)
    d.line([(78, 70), (88, 28)], fill=WOOD_LT, width=3)
    d.line([(82, 26), (94, 34)], fill=IRON, width=3)
    d.line([(82, 26), (94, 22)], fill=IRON_LT, width=2)
    # ore pile right
    for i, (ox, oy) in enumerate([(70, 72), (76, 74), (82, 72), (74, 78)]):
        outline_rect(img, ox, oy, ox + 7, oy + 6, ORE_DK if i % 2 else ORE)
    for x in range(2, w - 2):
        if x % 3:
            px(img, x, h - 2, GRASS)
    save("assets/sprites/buildings/mining_camp.png", img)


def gen_lumber_camp() -> None:
    """Lumber: OPEN shed (posts + roof only) + huge log pile + saw — not a closed hut."""
    w, h = 100, 88
    img = blank(w, h)
    # open shed: 4 posts + roof only (no front wall = unique)
    for px_x in (48, 90):
        outline_rect(img, px_x, 28, px_x + 4, 72, WOOD)
        for y in range(30, 72):
            px(img, px_x + 1, y, WOOD_LT)
    # cross beam
    outline_rect(img, 48, 28, 94, 34, WOOD_DK)
    # thatch roof over open bay
    thatch_roof(img, (71, 4), 30, 42, 98)
    # hanging saw blade (circular) — unique prop
    cx, cy, r = 70, 48, 10
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                px(img, x, y, IRON if ((x + y) % 3) else IRON_LT)
    ImageDraw.Draw(img).ellipse([cx - r, cy - r, cx + r, cy + r], outline=OUT)
    px(img, cx, cy, OUT)
    # === DOMINANT: log pile left (pyramid) ===
    rows = [
        [(6, 70, 28), (10, 70, 28), (14, 70, 28)],
        [(8, 64, 26), (12, 64, 26)],
        [(10, 58, 24)],
    ]
    for row in rows:
        for lx, ly, lw in [(a, b, c) for a, b, c in [(6, 70, 22), (14, 70, 22), (22, 70, 22),
                                                       (10, 64, 22), (18, 64, 22),
                                                       (14, 58, 22)]]:
            outline_rect(img, lx, ly, lx + lw, ly + 5, WOOD_LT)
            px(img, lx + 2, ly + 2, WOOD_HL)
            # end-grain rings
            outline_rect(img, lx, ly, lx + 3, ly + 5, WOOD)
    # sawhorse + plank in open bay
    ImageDraw.Draw(img).line([(50, 68), (62, 56)], fill=WOOD_DK, width=2)
    ImageDraw.Draw(img).line([(50, 68), (62, 76)], fill=WOOD_DK, width=2)
    ImageDraw.Draw(img).line([(48, 66), (88, 66)], fill=WOOD_LT, width=2)
    # stump far right
    outline_rect(img, 88, 68, 98, 80, WOOD)
    for x in range(4, w - 4):
        if x % 2:
            px(img, x, h - 2, GRASS)
    save("assets/sprites/buildings/lumber_camp.png", img)


def gen_blacksmith() -> None:
    """Blacksmith — open forge glow + chimney (keep distinct)."""
    w, h = 72, 100
    img = blank(w, h)
    stone_fill(img, 6, 78, 66, 94)
    log_wall(img, 8, 36, 64, 78)
    thatch_roof(img, (36, 4), 38, 4, 68)
    stone_fill(img, 48, 10, 60, 36)
    outline_rect(img, 46, 6, 62, 12, STONE_DK)
    outline_rect(img, 16, 48, 56, 78, (40, 28, 18, 255))
    outline_rect(img, 28, 54, 46, 70, STONE_DK)
    for y in range(58, 68):
        for x in range(32, 44):
            px(img, x, y, (240, 140, 40, 255) if (x + y) % 2 else (255, 200, 60, 255))
    outline_rect(img, 18, 68, 30, 76, IRON_DK)
    outline_rect(img, 16, 66, 32, 70, IRON)
    for x in range(4, w - 4):
        if x % 2:
            px(img, x, h - 2, GRASS)
    save("assets/sprites/buildings/blacksmith.png", img)


# ---------- Units ----------

FACINGS = ("down", "up", "left", "right")


def unit_canvas() -> Image.Image:
    return blank(36, 44)


def cav_canvas() -> Image.Image:
    """~1.5× infantry width for cavalry readability."""
    return blank(54, 48)


def wagon_canvas() -> Image.Image:
    return blank(48, 44)


def draw_legs(img, cx, y, facing) -> None:
    if facing in ("down", "up"):
        outline_rect(img, cx - 5, y, cx - 1, y + 8, BOOT)
        outline_rect(img, cx + 1, y, cx + 5, y + 8, BOOT)
    else:
        outline_rect(img, cx - 3, y, cx + 3, y + 8, BOOT)


def draw_torso(img, cx, y0, y1, facing, color=TEAM) -> None:
    if facing in ("down", "up"):
        outline_rect(img, cx - 6, y0, cx + 6, y1, color)
        for y in range(y0 + 1, y1):
            px(img, cx - 5, y, TEAM_DK if color == TEAM else WOOD_DK)
            px(img, cx + 5, y, TEAM_LT if color == TEAM else WOOD_LT)
    else:
        outline_rect(img, cx - 5, y0, cx + 5, y1, color)


def draw_head(img, cx, y, facing, helm=False) -> None:
    if helm:
        outline_rect(img, cx - 5, y, cx + 5, y + 8, IRON)
        for x in range(cx - 4, cx + 5):
            px(img, x, y + 1, IRON_LT)
        if facing != "up":
            outline_rect(img, cx - 3, y + 4, cx + 3, y + 8, SKIN)
            px(img, cx - 1, y + 6, OUT)
            px(img, cx + 1, y + 6, OUT)
    else:
        outline_rect(img, cx - 4, y, cx + 4, y + 8, SKIN)
        for x in range(cx - 3, cx + 4):
            px(img, x, y, HAIR)
        if facing != "up":
            px(img, cx - 1, y + 4, OUT)
            px(img, cx + 1, y + 4, OUT)


def draw_shield(img, x, y, facing) -> None:
    if facing == "left":
        return
    outline_rect(img, x, y, x + 9, y + 10, TEAM)
    for yy in range(y + 1, y + 10):
        for xx in range(x + 1, x + 9):
            if (xx + yy) % 3 == 0:
                px(img, xx, yy, TEAM_LT)
    outline_rect(img, x + 3, y + 3, x + 6, y + 6, IRON_LT)


def draw_banner_tiny(img, x, y) -> None:
    rect(img, x, y, x, y + 10, WOOD_DK)
    outline_rect(img, x + 1, y, x + 7, y + 6, TEAM)
    px(img, x + 2, y + 2, TEAM_LT)


def facing_variants(draw_fn, prefix: str, canvas_fn=unit_canvas) -> None:
    for facing in FACINGS:
        img = canvas_fn()
        draw_fn(img, facing)
        save(f"assets/sprites/units/{prefix}_{facing}.png", img)


def draw_horse(img, cx, cy, facing) -> None:
    """Clear horse silhouette — body, neck, head, legs, mane, tail."""
    d = ImageDraw.Draw(img)
    if facing in ("down", "up"):
        outline_rect(img, cx - 12, cy + 4, cx + 12, cy + 18, HORSE)
        for y in range(cy + 5, cy + 18):
            px(img, cx - 11, y, HORSE_DK)
            px(img, cx + 11, y, HORSE_LT)
        outline_rect(img, cx - 8, cy, cx + 8, cy + 6, HORSE_LT)
        if facing == "down":
            outline_rect(img, cx - 4, cy - 8, cx + 5, cy + 2, HORSE)
            outline_rect(img, cx - 2, cy - 14, cx + 8, cy - 6, HORSE_LT)
            px(img, cx + 6, cy - 10, OUT)
            for y in range(cy - 12, cy - 2):
                px(img, cx - 5, y, HAIR)
        else:
            outline_rect(img, cx - 5, cy - 6, cx + 4, cy + 2, HORSE)
            outline_rect(img, cx - 8, cy - 12, cx + 2, cy - 4, HORSE_LT)
            px(img, cx - 6, cy - 8, OUT)
            for y in range(cy - 10, cy - 1):
                px(img, cx + 3, y, HAIR)
        for lx in (cx - 10, cx - 3, cx + 3, cx + 10):
            outline_rect(img, lx, cy + 18, lx + 3, cy + 28, HORSE_DK)
            px(img, lx + 1, cy + 23, BOOT)
        for y in range(cy + 6, cy + 18):
            px(img, cx - 14, y, HAIR)
            px(img, cx - 15, y, HAIR)
    else:
        # side: long body
        outline_rect(img, cx - 16, cy + 4, cx + 12, cy + 18, HORSE)
        for y in range(cy + 5, cy + 17):
            px(img, cx - 15, y, HORSE_DK)
            px(img, cx + 11, y, HORSE_LT)
            if y % 4 == 0:
                for x in range(cx - 12, cx + 10):
                    px(img, x, y, HORSE_DK)
        if facing == "right":
            d.polygon(
                [(cx + 10, cy + 6), (cx + 18, cy - 4), (cx + 24, cy + 2),
                 (cx + 22, cy + 10), (cx + 10, cy + 12)],
                fill=HORSE_LT, outline=OUT,
            )
            outline_rect(img, cx + 20, cy, cx + 28, cy + 8, HORSE)
            px(img, cx + 26, cy + 3, OUT)
            px(img, cx + 27, cy + 5, OUT)
            for y in range(cy - 2, cy + 10):
                px(img, cx + 16, y, HAIR)
            for y in range(cy + 6, cy + 18):
                px(img, cx - 18, y, HAIR)
                px(img, cx - 19, y, HAIR)
        else:
            d.polygon(
                [(cx - 10, cy + 6), (cx - 18, cy - 4), (cx - 24, cy + 2),
                 (cx - 22, cy + 10), (cx - 10, cy + 12)],
                fill=HORSE_LT, outline=OUT,
            )
            outline_rect(img, cx - 28, cy, cx - 20, cy + 8, HORSE)
            px(img, cx - 26, cy + 3, OUT)
            for y in range(cy - 2, cy + 10):
                px(img, cx - 16, y, HAIR)
            for y in range(cy + 6, cy + 18):
                px(img, cx + 14, y, HAIR)
        for lx in (cx - 12, cx - 4, cx + 2, cx + 8):
            outline_rect(img, lx, cy + 18, lx + 3, cy + 28, HORSE_DK)
            px(img, lx + 1, cy + 23, BOOT)


def draw_rider(img, cx, cy, facing, armored: bool) -> None:
    body = IRON if armored else TEAM
    if facing in ("down", "up"):
        outline_rect(img, cx - 7, cy - 6, cx + 7, cy + 10, body)
        for y in range(cy - 5, cy + 10):
            px(img, cx - 6, y, IRON_DK if armored else TEAM_DK)
            px(img, cx + 6, y, IRON_LT if armored else TEAM_LT)
        if armored:
            rect(img, cx - 5, cy + 1, cx + 5, cy + 5, TEAM)
        draw_head(img, cx, cy - 16, facing, helm=True)
        draw_banner_tiny(img, cx + 10, cy - 18)
        ImageDraw.Draw(img).line([(cx + 6, cy + 2), (cx + 16, cy - 10)], fill=IRON_LT, width=2)
    else:
        rx = cx + (2 if facing == "right" else -2)
        outline_rect(img, rx - 6, cy - 6, rx + 6, cy + 10, body)
        if armored:
            rect(img, rx - 4, cy + 1, rx + 4, cy + 5, TEAM)
        else:
            for y in range(cy - 4, cy + 8):
                px(img, rx - 5, y, TEAM_DK)
        draw_head(img, rx, cy - 16, facing, helm=True)
        draw_shield(img, rx + (8 if facing == "right" else -16), cy - 4, facing)
        tip = rx + (18 if facing == "right" else -18)
        ImageDraw.Draw(img).line([(rx + 2, cy + 2), (tip, cy - 10)], fill=IRON_LT, width=2)


def draw_spearman(img, facing) -> None:
    """Long spear above head — unique silhouette."""
    cx = 18
    draw_legs(img, cx, 32, facing)
    outline_rect(img, cx - 7, 16, cx + 7, 32, TEAM)
    for y in range(17, 32):
        px(img, cx - 6, y, TEAM_DK)
        px(img, cx + 6, y, TEAM_LT)
    rect(img, cx - 6, 26, cx + 6, 28, WOOD_DK)
    draw_head(img, cx, 6, facing, helm=True)
    d = ImageDraw.Draw(img)
    # spear shaft extends well above head
    if facing == "right":
        d.line([(cx + 6, 30), (cx + 14, 0)], fill=WOOD_LT, width=2)
        outline_rect(img, cx + 12, 0, cx + 16, 4, IRON_LT)
        draw_shield(img, cx - 14, 18, facing)
    elif facing == "left":
        d.line([(cx - 6, 30), (cx - 14, 0)], fill=WOOD_LT, width=2)
        outline_rect(img, cx - 16, 0, cx - 12, 4, IRON_LT)
    elif facing == "down":
        d.line([(cx + 8, 32), (cx + 8, 0)], fill=WOOD_LT, width=2)
        outline_rect(img, cx + 6, 0, cx + 10, 3, IRON_LT)
        draw_shield(img, cx - 15, 18, facing)
    else:
        d.line([(cx - 8, 32), (cx - 8, 0)], fill=WOOD_LT, width=2)
        outline_rect(img, cx - 10, 0, cx - 6, 3, IRON_LT)


def draw_light_cavalry(img, facing) -> None:
    cx, cy = 27, 18
    draw_horse(img, cx, cy, facing)
    draw_rider(img, cx, cy, facing, armored=False)


def draw_knight(img, facing) -> None:
    cx, cy = 27, 18
    draw_horse(img, cx, cy, facing)
    draw_rider(img, cx, cy, facing, armored=True)


def draw_bradaticar(img, facing) -> None:
    """Bearded axe — wide blade silhouette."""
    cx = 18
    draw_legs(img, cx, 32, facing)
    outline_rect(img, cx - 7, 16, cx + 7, 32, TEAM)
    for y in range(17, 32):
        px(img, cx - 6, y, TEAM_DK)
    rect(img, cx - 6, 26, cx + 6, 28, WOOD_DK)
    draw_head(img, cx, 6, facing, helm=False)
    for x in range(cx - 3, cx + 4):
        px(img, x, 6, HAIR)
    d = ImageDraw.Draw(img)
    # large bearded axe head
    if facing == "right":
        d.line([(cx + 5, 24), (cx + 12, 8)], fill=WOOD_LT, width=2)
        d.polygon([(cx + 10, 2), (cx + 20, 10), (cx + 18, 16), (cx + 8, 8)], fill=IRON)
        for x in range(cx + 12, cx + 18):
            px(img, x, 12, IRON_LT)
        draw_shield(img, cx - 14, 18, facing)
    elif facing == "left":
        d.line([(cx - 5, 24), (cx - 12, 8)], fill=WOOD_LT, width=2)
        d.polygon([(cx - 10, 2), (cx - 20, 10), (cx - 18, 16), (cx - 8, 8)], fill=IRON)
    elif facing == "down":
        d.line([(cx + 7, 22), (cx + 12, 4)], fill=WOOD_LT, width=2)
        d.polygon([(cx + 8, 0), (cx + 20, 6), (cx + 18, 14), (cx + 6, 6)], fill=IRON)
        draw_shield(img, cx - 14, 18, facing)
    else:
        d.line([(cx - 7, 22), (cx - 12, 4)], fill=WOOD_LT, width=2)
        d.polygon([(cx - 8, 0), (cx - 20, 6), (cx - 18, 14), (cx - 6, 6)], fill=IRON)


def draw_druzinik(img, facing) -> None:
    draw_knight(img, facing)
    cx, cy = 27, 18
    if facing in ("down", "up"):
        outline_rect(img, cx - 9, cy + 6, cx + 9, cy + 14, TEAM_DK)
        for x in range(cx - 8, cx + 9):
            px(img, x, cy + 7, TEAM)


def draw_valecny_vuz(img, facing) -> None:
    """War wagon — obvious wheels + planked wall + gun slits."""
    if facing in ("down", "up"):
        # big wagon body
        outline_rect(img, 6, 8, 42, 30, WOOD)
        for y in range(10, 30, 3):
            for x in range(8, 42):
                px(img, x, y, WOOD_DK)
            px(img, 7, y, WOOD_LT)
        # crenellated top wall
        for mx in range(8, 42, 6):
            outline_rect(img, mx, 4, mx + 3, 10, WOOD_LT)
        # slits
        outline_rect(img, 12, 14, 18, 22, (16, 12, 10, 255))
        outline_rect(img, 30, 14, 36, 22, (16, 12, 10, 255))
        # LARGE wheels
        for wx in (4, 32):
            outline_rect(img, wx, 26, wx + 14, 42, BOOT)
            outline_rect(img, wx + 3, 29, wx + 11, 39, WOOD_DK)
            px(img, wx + 7, 33, IRON_LT)
            px(img, wx + 6, 34, IRON)
            px(img, wx + 8, 34, IRON)
            px(img, wx + 7, 32, IRON)
        # barrel
        outline_rect(img, 20, 0, 28, 8, IRON_DK)
        for x in range(21, 28):
            px(img, x, 2, IRON_LT)
        draw_banner_tiny(img, 40, 0)
    else:
        outline_rect(img, 2, 10, 46, 30, WOOD)
        for y in range(12, 30, 3):
            for x in range(4, 46):
                px(img, x, y, WOOD_DK)
        outline_rect(img, 2, 10, 8, 30, WOOD_LT)
        for mx in range(4, 44, 6):
            outline_rect(img, mx, 6, mx + 3, 12, WOOD_LT)
        outline_rect(img, 14, 14, 34, 24, (16, 12, 10, 255))
        for wx in (4, 30):
            outline_rect(img, wx, 26, wx + 14, 42, BOOT)
            px(img, wx + 7, 33, IRON_LT)
        if facing == "right":
            outline_rect(img, 44, 14, 50, 22, IRON_DK)
            for x in range(45, 50):
                px(img, x, 16, IRON_LT)
        else:
            outline_rect(img, 0, 14, 4, 22, IRON_DK)
        draw_banner_tiny(img, 20, 0)


def draw_lancknecht(img, facing) -> None:
    """Pike + colorful striped landsknecht garb."""
    cx = 18
    draw_legs(img, cx, 32, facing)
    # striped colorful tunic (red/yellow/team)
    outline_rect(img, cx - 7, 14, cx + 7, 32, (160, 40, 50, 255))
    for y in range(16, 30, 3):
        col = TEAM if (y // 3) % 2 == 0 else (220, 190, 50, 255)
        for x in range(cx - 6, cx + 7):
            px(img, x, y, col)
            px(img, x, y + 1, col)
    # puffed sleeves
    outline_rect(img, cx - 10, 16, cx - 6, 24, (220, 190, 50, 255))
    outline_rect(img, cx + 6, 16, cx + 10, 24, TEAM)
    draw_head(img, cx, 4, facing, helm=False)
    # fancy hat with plume
    outline_rect(img, cx - 6, 2, cx + 6, 8, (160, 40, 50, 255))
    for i in range(4):
        px(img, cx + 6 + i, 2 - i, TEAM_LT)
        px(img, cx + 6 + i, 3 - i, (220, 190, 50, 255))
    d = ImageDraw.Draw(img)
    # long pike
    if facing == "right":
        d.line([(cx + 8, 28), (cx + 16, 0)], fill=WOOD_LT, width=2)
        outline_rect(img, cx + 14, 0, cx + 17, 4, IRON)
        draw_shield(img, cx - 14, 18, facing)
    elif facing == "left":
        d.line([(cx - 8, 28), (cx - 16, 0)], fill=WOOD_LT, width=2)
        outline_rect(img, cx - 17, 0, cx - 14, 4, IRON)
    elif facing == "down":
        d.line([(cx + 8, 28), (cx + 8, 0)], fill=WOOD_LT, width=2)
        outline_rect(img, cx + 6, 0, cx + 10, 3, IRON)
        draw_shield(img, cx - 14, 18, facing)
    else:
        d.line([(cx - 8, 28), (cx - 8, 0)], fill=WOOD_LT, width=2)
        outline_rect(img, cx - 10, 0, cx - 6, 3, IRON)


def main() -> None:
    gen_stable()
    gen_castle()
    gen_mining_camp()
    gen_lumber_camp()
    gen_blacksmith()
    facing_variants(draw_spearman, "spearman")
    facing_variants(draw_bradaticar, "bojovnik_bradatice")
    facing_variants(draw_lancknecht, "lancknecht")
    facing_variants(draw_light_cavalry, "light_cavalry", cav_canvas)
    facing_variants(draw_knight, "knight", cav_canvas)
    facing_variants(draw_druzinik, "druzinik", cav_canvas)
    facing_variants(draw_valecny_vuz, "valecny_vuz", wagon_canvas)
    print("art pass sprites done")


if __name__ == "__main__":
    main()
