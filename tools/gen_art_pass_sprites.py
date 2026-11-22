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
    """Wooden stable with horse pen + thatch — ~100×88 for 80 footprint."""
    w, h = 108, 88
    img = blank(w, h)
    # pen fence (front-left)
    for i, fx in enumerate(range(4, 42, 5)):
        rect(img, fx, 58, fx + 2, 84, WOOD_LT if i % 2 == 0 else WOOD)
        px(img, fx, 57, OUT)
        px(img, fx + 1, 57, OUT)
        px(img, fx + 2, 57, OUT)
    rect(img, 4, 70, 42, 71, WOOD_DK)  # rail
    # horse in pen
    rect(img, 14, 64, 34, 74, HORSE)
    rect(img, 32, 62, 40, 70, HORSE_LT)  # head
    px(img, 38, 64, OUT)  # eye
    for lx in (16, 22, 28, 32):
        rect(img, lx, 74, lx + 2, 82, HORSE_DK)
    # main barn
    log_wall(img, 40, 34, 102, 78)
    thatch_roof(img, (71, 6), 36, 36, 106)
    door(img, 62, 48, 82, 78)
    window(img, 48, 44)
    window(img, 88, 44)
    # hay bale
    outline_rect(img, 44, 68, 56, 78, THATCH_LT)
    for y in range(69, 78):
        for x in range(45, 56):
            if (x + y) % 3 == 0:
                px(img, x, y, THATCH)
    # grass strip
    for x in range(2, w - 2):
        if (x % 3) != 0:
            px(img, x, h - 2, GRASS)
    save("assets/sprites/buildings/stable.png", img)


def gen_castle() -> None:
    """Czech stone castle — largest sprite (~156×172) for 160 footprint."""
    w, h = 156, 172
    img = blank(w, h)
    # curtain wall base
    stone_fill(img, 18, 70, 138, 160)
    # crenellations on wall top
    for cx in range(18, 139, 10):
        stone_fill(img, cx, 58, min(cx + 6, 138), 70)
        # merlon cap highlight
        for x in range(cx + 1, min(cx + 6, 138)):
            px(img, x, 59, STONE_LT)
    # left tower
    stone_fill(img, 8, 28, 42, 160)
    for cx in range(8, 43, 7):
        stone_fill(img, cx, 16, min(cx + 4, 42), 28)
    shingle_roof(img, (25, 2), 20, 6, 44)
    # right tower
    stone_fill(img, 114, 28, 148, 160)
    for cx in range(114, 149, 7):
        stone_fill(img, cx, 16, min(cx + 4, 148), 28)
    shingle_roof(img, (131, 2), 20, 112, 150)
    # keep / gatehouse
    stone_fill(img, 48, 48, 108, 160)
    shingle_roof(img, (78, 18), 50, 44, 112)
    # wooden gallery under keep eaves
    rect(img, 52, 50, 104, 56, WOOD)
    for x in range(54, 104, 6):
        rect(img, x, 56, x + 1, 62, WOOD_DK)
    ImageDraw.Draw(img).rectangle([52, 50, 104, 56], outline=OUT)
    # gate
    outline_rect(img, 68, 110, 88, 160, (24, 20, 16, 255))
    # arch
    for dy, inset in [(0, 0), (1, 1), (2, 2), (3, 3)]:
        for x in range(68 + inset, 89 - inset):
            px(img, x, 110 + dy, WOOD_DK if dy > 1 else OUT)
    # door wood
    for y in range(118, 160):
        for x in range(70, 87):
            px(img, x, y, WOOD if (x - 70) % 4 else WOOD_DK)
    # windows
    window(img, 56, 78, 8, 10)
    window(img, 92, 78, 8, 10)
    window(img, 18, 80, 6, 10)
    window(img, 128, 80, 6, 10)
    # team banner on keep
    rect(img, 78, 22, 79, 46, WOOD_DK)
    for y in range(24, 40):
        for x in range(80, 96):
            px(img, x, y, TEAM if (x + y) % 2 == 0 else TEAM_LT)
    ImageDraw.Draw(img).rectangle([80, 24, 95, 39], outline=OUT)
    # grass
    for x in range(4, w - 4):
        if x % 2:
            px(img, x, h - 3, GRASS)
    save("assets/sprites/buildings/castle.png", img)


def gen_mining_camp() -> None:
    """Mining camp — ore piles + pickaxe, not a lumber clone. ~80×84."""
    w, h = 84, 86
    img = blank(w, h)
    # stone foundation
    stone_fill(img, 8, 58, 76, 78)
    log_wall(img, 12, 30, 72, 60)
    thatch_roof(img, (42, 4), 32, 8, 76)
    # open shed / dark mouth
    outline_rect(img, 28, 40, 56, 60, (30, 24, 18, 255))
    # ore piles
    for ox, oy in [(6, 64), (58, 62)]:
        for i in range(10):
            x = ox + (i % 5) * 3
            y = oy + (i // 5) * 4
            outline_rect(img, x, y, x + 4, y + 4, ORE if i % 2 == 0 else ORE_DK)
    # pickaxe
    ImageDraw.Draw(img).line([(64, 48), (74, 36)], fill=WOOD_LT, width=2)
    ImageDraw.Draw(img).line([(70, 34), (78, 38)], fill=IRON, width=2)
    # cart
    outline_rect(img, 30, 66, 50, 78, WOOD)
    outline_rect(img, 28, 72, 34, 80, BOOT)
    outline_rect(img, 46, 72, 52, 80, BOOT)
    for x in range(10, w - 10):
        if x % 3:
            px(img, x, h - 2, GRASS)
    save("assets/sprites/buildings/mining_camp.png", img)


def gen_lumber_camp() -> None:
    """Refresh lumber camp in same generator for consistency."""
    w, h = 84, 86
    img = blank(w, h)
    log_wall(img, 14, 28, 74, 64)
    thatch_roof(img, (44, 4), 30, 10, 78)
    outline_rect(img, 30, 40, 58, 64, (32, 24, 16, 255))
    # log pile
    for i, (lx, ly) in enumerate([(4, 58), (8, 62), (12, 58), (6, 66), (10, 70)]):
        outline_rect(img, lx, ly, lx + 14, ly + 5, WOOD_LT if i % 2 else WOOD)
        px(img, lx + 1, ly + 2, WOOD_HL)
    # sawhorse
    ImageDraw.Draw(img).line([(50, 70), (70, 58)], fill=WOOD_DK, width=2)
    ImageDraw.Draw(img).line([(50, 70), (70, 78)], fill=WOOD_DK, width=2)
    ImageDraw.Draw(img).line([(48, 68), (72, 68)], fill=WOOD_LT, width=2)
    # stump + axe
    outline_rect(img, 66, 70, 78, 82, WOOD)
    ImageDraw.Draw(img).line([(72, 60), (72, 72)], fill=WOOD_DK, width=2)
    ImageDraw.Draw(img).line([(68, 60), (76, 62)], fill=IRON, width=2)
    for x in range(8, w - 8):
        if x % 3:
            px(img, x, h - 2, GRASS)
    save("assets/sprites/buildings/lumber_camp.png", img)


def gen_blacksmith() -> None:
    """Blacksmith refresh — open forge, warm wood, matches TC style."""
    w, h = 72, 100
    img = blank(w, h)
    # stone base
    stone_fill(img, 6, 78, 66, 94)
    log_wall(img, 8, 36, 64, 78)
    thatch_roof(img, (36, 4), 38, 4, 68)
    # chimney
    stone_fill(img, 48, 10, 60, 36)
    outline_rect(img, 46, 6, 62, 12, STONE_DK)
    # open front
    outline_rect(img, 16, 48, 56, 78, (40, 28, 18, 255))
    # forge glow
    outline_rect(img, 28, 54, 46, 70, STONE_DK)
    for y in range(58, 68):
        for x in range(32, 44):
            px(img, x, y, (240, 140, 40, 255) if (x + y) % 2 else (255, 200, 60, 255))
    # anvil
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


def draw_legs(img, cx, y, facing) -> None:
    if facing in ("down", "up"):
        outline_rect(img, cx - 5, y, cx - 1, y + 8, BOOT)
        outline_rect(img, cx + 1, y, cx + 5, y + 8, BOOT)
    else:
        outline_rect(img, cx - 3, y, cx + 3, y + 8, BOOT)


def draw_torso(img, cx, y0, y1, facing, color=TEAM) -> None:
    if facing in ("down", "up"):
        outline_rect(img, cx - 6, y0, cx + 6, y1, color)
        # fold shading
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
        # face opening
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
    """Round shield with TEAM face."""
    if facing == "left":
        return  # behind
    outline_rect(img, x, y, x + 9, y + 10, TEAM)
    for yy in range(y + 1, y + 10):
        for xx in range(x + 1, x + 9):
            if (xx + yy) % 3 == 0:
                px(img, xx, yy, TEAM_LT)
    # boss
    outline_rect(img, x + 3, y + 3, x + 6, y + 6, IRON_LT)


def draw_banner_tiny(img, x, y) -> None:
    rect(img, x, y, x, y + 10, WOOD_DK)
    outline_rect(img, x + 1, y, x + 7, y + 6, TEAM)
    px(img, x + 2, y + 2, TEAM_LT)


def facing_variants(draw_fn, prefix: str) -> None:
    for facing in FACINGS:
        img = unit_canvas()
        draw_fn(img, facing)
        save(f"assets/sprites/units/{prefix}_{facing}.png", img)


def draw_horse(img, cx, cy, facing) -> None:
    """Readable horse: body, neck, head, legs, mane, tail."""
    d = ImageDraw.Draw(img)
    if facing in ("down", "up"):
        # body oval-ish via stacked rects
        outline_rect(img, cx - 9, cy + 2, cx + 9, cy + 14, HORSE)
        for y in range(cy + 3, cy + 14):
            px(img, cx - 8, y, HORSE_DK)
            px(img, cx + 8, y, HORSE_LT)
            if (y % 3) == 0:
                px(img, cx, y, HORSE_DK)
        # chest / rump
        outline_rect(img, cx - 7, cy, cx + 7, cy + 4, HORSE_LT)
        if facing == "down":
            # neck up toward viewer-ish
            outline_rect(img, cx - 3, cy - 6, cx + 4, cy + 2, HORSE)
            for y in range(cy - 5, cy + 1):
                px(img, cx - 2, y, HORSE_DK)
            # head
            outline_rect(img, cx - 2, cy - 12, cx + 6, cy - 5, HORSE_LT)
            px(img, cx + 4, cy - 9, OUT)  # eye
            px(img, cx + 5, cy - 7, OUT)  # nostril
            # mane
            for y in range(cy - 10, cy - 2):
                px(img, cx - 3, y, HAIR)
                if y % 2:
                    px(img, cx - 4, y, HAIR)
        else:
            outline_rect(img, cx - 4, cy - 4, cx + 3, cy + 2, HORSE)
            outline_rect(img, cx - 6, cy - 10, cx + 2, cy - 3, HORSE_LT)
            px(img, cx - 4, cy - 7, OUT)
            for y in range(cy - 8, cy - 1):
                px(img, cx + 2, y, HAIR)
        # legs with joints
        for i, lx in enumerate((cx - 7, cx - 2, cx + 2, cx + 7)):
            outline_rect(img, lx, cy + 14, lx + 2, cy + 22, HORSE_DK)
            px(img, lx, cy + 18, BOOT)
        # tail
        for y in range(cy + 4, cy + 14):
            px(img, cx - 11, y, HAIR)
            if y % 2:
                px(img, cx - 12, y, HAIR)
    else:
        # side profile — classic horse silhouette
        outline_rect(img, cx - 12, cy + 2, cx + 10, cy + 14, HORSE)
        for y in range(cy + 3, cy + 13):
            px(img, cx - 11, y, HORSE_DK)
            px(img, cx + 9, y, HORSE_LT)
        if facing == "right":
            # neck + head to the right
            d.polygon(
                [(cx + 8, cy + 4), (cx + 14, cy - 2), (cx + 18, cy + 2), (cx + 16, cy + 8), (cx + 8, cy + 10)],
                fill=HORSE_LT, outline=OUT,
            )
            outline_rect(img, cx + 16, cy, cx + 22, cy + 6, HORSE)
            px(img, cx + 20, cy + 2, OUT)
            px(img, cx + 21, cy + 4, OUT)
            for y in range(cy - 1, cy + 8):
                px(img, cx + 13, y, HAIR)
            # tail left
            for y in range(cy + 4, cy + 14):
                px(img, cx - 14, y, HAIR)
                px(img, cx - 15, y, HAIR)
        else:
            d.polygon(
                [(cx - 8, cy + 4), (cx - 14, cy - 2), (cx - 18, cy + 2), (cx - 16, cy + 8), (cx - 8, cy + 10)],
                fill=HORSE_LT, outline=OUT,
            )
            outline_rect(img, cx - 22, cy, cx - 16, cy + 6, HORSE)
            px(img, cx - 20, cy + 2, OUT)
            for y in range(cy - 1, cy + 8):
                px(img, cx - 13, y, HAIR)
            for y in range(cy + 4, cy + 14):
                px(img, cx + 12, y, HAIR)
        for lx in (cx - 8, cx - 2, cx + 3, cx + 8):
            outline_rect(img, lx, cy + 14, lx + 2, cy + 22, HORSE_DK)
            px(img, lx, cy + 18, BOOT)


def draw_spearman(img, facing) -> None:
    cx = 18
    draw_legs(img, cx, 32, facing)
    # tunic with shading like soldier
    outline_rect(img, cx - 7, 16, cx + 7, 32, TEAM)
    for y in range(17, 32):
        px(img, cx - 6, y, TEAM_DK)
        px(img, cx + 6, y, TEAM_LT)
        if y % 4 == 0:
            for x in range(cx - 4, cx + 5):
                px(img, x, y, TEAM_DK)
    # belt
    rect(img, cx - 6, 26, cx + 6, 28, WOOD_DK)
    draw_head(img, cx, 6, facing, helm=True)
    d = ImageDraw.Draw(img)
    if facing == "right":
        d.line([(cx + 6, 28), (cx + 16, 2)], fill=WOOD_LT, width=2)
        outline_rect(img, cx + 14, 0, cx + 17, 5, IRON_LT)
        draw_shield(img, cx - 14, 18, facing)
    elif facing == "left":
        d.line([(cx - 6, 28), (cx - 16, 2)], fill=WOOD_LT, width=2)
        outline_rect(img, cx - 17, 0, cx - 14, 5, IRON_LT)
    elif facing == "down":
        d.line([(cx + 8, 30), (cx + 8, 1)], fill=WOOD_LT, width=2)
        outline_rect(img, cx + 6, 0, cx + 10, 4, IRON_LT)
        draw_shield(img, cx - 15, 18, facing)
    else:
        d.line([(cx - 8, 30), (cx - 8, 1)], fill=WOOD_LT, width=2)
        outline_rect(img, cx - 10, 0, cx - 6, 4, IRON_LT)


def draw_rider(img, cx, cy, facing, armored: bool) -> None:
    body = IRON if armored else TEAM
    if facing in ("down", "up"):
        outline_rect(img, cx - 6, cy - 4, cx + 6, cy + 10, body)
        for y in range(cy - 3, cy + 10):
            px(img, cx - 5, y, IRON_DK if armored else TEAM_DK)
            px(img, cx + 5, y, IRON_LT if armored else TEAM_LT)
        if armored:
            rect(img, cx - 4, cy + 2, cx + 4, cy + 5, TEAM)
        draw_head(img, cx, cy - 14, facing, helm=True)
        draw_banner_tiny(img, cx + 8, cy - 16)
        ImageDraw.Draw(img).line([(cx + 5, cy + 2), (cx + 13, cy - 8)], fill=IRON_LT, width=2)
    else:
        rx = cx + (1 if facing == "right" else -1)
        outline_rect(img, rx - 5, cy - 4, rx + 5, cy + 10, body)
        if armored:
            rect(img, rx - 3, cy + 2, rx + 3, cy + 5, TEAM)
        else:
            for y in range(cy - 2, cy + 8):
                px(img, rx - 4, y, TEAM_DK)
        draw_head(img, rx, cy - 14, facing, helm=True)
        draw_shield(img, rx + (7 if facing == "right" else -15), cy - 2, facing)
        tip = rx + (15 if facing == "right" else -15)
        ImageDraw.Draw(img).line([(rx + 2, cy + 2), (tip, cy - 8)], fill=IRON_LT, width=2)


def draw_light_cavalry(img, facing) -> None:
    cx, cy = 18, 20
    draw_horse(img, cx, cy, facing)
    draw_rider(img, cx, cy, facing, armored=False)


def draw_knight(img, facing) -> None:
    cx, cy = 18, 20
    draw_horse(img, cx, cy, facing)
    draw_rider(img, cx, cy, facing, armored=True)


def draw_bradaticar(img, facing) -> None:
    cx = 18
    draw_legs(img, cx, 32, facing)
    draw_torso(img, cx, 18, 32, facing, TEAM)
    draw_head(img, cx, 8, facing, helm=False)
    # hair more
    for x in range(cx - 3, cx + 4):
        px(img, x, 8, HAIR)
    d = ImageDraw.Draw(img)
    # bearded axe
    if facing == "right":
        d.line([(cx + 5, 24), (cx + 14, 10)], fill=WOOD_LT, width=2)
        d.polygon([(cx + 12, 6), (cx + 18, 12), (cx + 14, 14), (cx + 10, 8)], fill=IRON)
        draw_shield(img, cx - 14, 20, facing)
    elif facing == "left":
        d.line([(cx - 5, 24), (cx - 14, 10)], fill=WOOD_LT, width=2)
        d.polygon([(cx - 12, 6), (cx - 18, 12), (cx - 14, 14), (cx - 10, 8)], fill=IRON)
    elif facing == "down":
        d.line([(cx + 7, 22), (cx + 12, 6)], fill=WOOD_LT, width=2)
        d.polygon([(cx + 10, 2), (cx + 16, 8), (cx + 12, 10), (cx + 8, 4)], fill=IRON)
        draw_shield(img, cx - 14, 20, facing)
    else:
        d.line([(cx - 7, 22), (cx - 12, 6)], fill=WOOD_LT, width=2)
        d.polygon([(cx - 10, 2), (cx - 16, 8), (cx - 12, 10), (cx - 8, 4)], fill=IRON)


def draw_druzinik(img, facing) -> None:
    # elite cavalry — knight base + longer TEAM cloak
    draw_knight(img, facing)
    cx, cy = 18, 20
    if facing in ("down", "up"):
        outline_rect(img, cx - 8, cy + 4, cx + 8, cy + 12, TEAM_DK)
        for x in range(cx - 7, cx + 8):
            px(img, x, cy + 5, TEAM)


def draw_valecny_vuz(img, facing) -> None:
    """War wagon — wheeled wooden box with slits + team banner."""
    if facing in ("down", "up"):
        outline_rect(img, 8, 26, 28, 32, WOOD_DK)
        for wx in (6, 24):
            outline_rect(img, wx, 28, wx + 10, 40, BOOT)
            px(img, wx + 4, 33, IRON_LT)
            px(img, wx + 5, 34, IRON)
            px(img, wx + 3, 34, IRON)
        outline_rect(img, 6, 10, 30, 28, WOOD)
        for y in range(12, 28):
            px(img, 7, y, WOOD_DK)
            px(img, 29, y, WOOD_LT)
            if y % 3 == 0:
                for x in range(8, 30):
                    px(img, x, y, WOOD_DK)
        outline_rect(img, 8, 6, 28, 12, WOOD_LT)
        for x in range(10, 28, 3):
            px(img, x, 8, WOOD_HL)
        outline_rect(img, 11, 14, 15, 20, (20, 16, 12, 255))
        outline_rect(img, 21, 14, 25, 20, (20, 16, 12, 255))
        outline_rect(img, 15, 2, 21, 8, IRON_DK)
        for x in range(16, 21):
            px(img, x, 3, IRON_LT)
        draw_banner_tiny(img, 28, 0)
    else:
        outline_rect(img, 4, 12, 32, 30, WOOD)
        for y in range(14, 30):
            if y % 3 == 0:
                for x in range(6, 32):
                    px(img, x, y, WOOD_DK)
            px(img, 5, y, WOOD_DK)
        outline_rect(img, 4, 12, 9, 30, WOOD_LT)
        outline_rect(img, 12, 16, 26, 24, (20, 16, 12, 255))
        for wx in (6, 22):
            outline_rect(img, wx, 28, wx + 10, 40, BOOT)
            px(img, wx + 4, 33, IRON_LT)
        if facing == "right":
            outline_rect(img, 30, 16, 35, 22, IRON_DK)
            for x in range(31, 35):
                px(img, x, 17, IRON_LT)
        else:
            outline_rect(img, 1, 16, 6, 22, IRON_DK)
        draw_banner_tiny(img, 16, 2)


def draw_lancknecht(img, facing) -> None:
    cx = 18
    draw_legs(img, cx, 32, facing)
    # striped landsknecht tunic
    draw_torso(img, cx, 18, 32, facing, TEAM)
    for y in range(20, 30, 3):
        for x in range(cx - 5, cx + 6):
            if (y // 3) % 2 == 0:
                px(img, x, y, (200, 180, 60, 255))
    draw_head(img, cx, 8, facing, helm=False)
    # fancy hat
    outline_rect(img, cx - 6, 6, cx + 6, 10, (160, 40, 50, 255))
    px(img, cx + 6, 4, TEAM_LT)
    d = ImageDraw.Draw(img)
    if facing == "right":
        d.line([(cx + 5, 22), (cx + 16, 4)], fill=WOOD_LT, width=2)
        outline_rect(img, cx + 14, 2, cx + 17, 6, IRON)
        draw_shield(img, cx - 14, 20, facing)
    elif facing == "left":
        d.line([(cx - 5, 22), (cx - 16, 4)], fill=WOOD_LT, width=2)
        outline_rect(img, cx - 17, 2, cx - 14, 6, IRON)
    elif facing == "down":
        d.line([(cx + 6, 20), (cx + 6, 2)], fill=WOOD_LT, width=2)
        outline_rect(img, cx + 4, 0, cx + 8, 3, IRON)
        draw_shield(img, cx - 14, 20, facing)
    else:
        d.line([(cx - 6, 20), (cx - 6, 2)], fill=WOOD_LT, width=2)
        outline_rect(img, cx - 8, 0, cx - 4, 3, IRON)


def main() -> None:
    gen_stable()
    gen_castle()
    gen_mining_camp()
    gen_lumber_camp()
    gen_blacksmith()
    facing_variants(draw_spearman, "spearman")
    facing_variants(draw_light_cavalry, "light_cavalry")
    facing_variants(draw_knight, "knight")
    facing_variants(draw_bradaticar, "bojovnik_bradatice")
    facing_variants(draw_druzinik, "druzinik")
    facing_variants(draw_valecny_vuz, "valecny_vuz")
    facing_variants(draw_lancknecht, "lancknecht")
    print("art pass sprites done")


if __name__ == "__main__":
    main()
