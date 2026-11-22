"""Generate castle + unique-unit pixel sprites (40 px unit grid)."""
from PIL import Image, ImageDraw
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def save(rel, img):
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print("wrote", rel, img.size)


def gen_castle():
    w, h = 140, 160
    cast = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(cast)
    stone = (118, 118, 128, 255)
    stone_dk = (88, 88, 98, 255)
    stone_lt = (150, 150, 158, 255)
    wood = (92, 62, 38, 255)
    wood_lt = (130, 90, 55, 255)
    roof = (140, 48, 42, 255)
    roof_dk = (100, 32, 28, 255)
    d.rectangle([28, 48, 112, 148], fill=stone)
    for y in range(52, 148, 8):
        d.line([(28, y), (112, y)], fill=stone_dk)
    for x in range(32, 112, 12):
        for y in range(52, 148, 16):
            d.line([(x, y), (x, min(y + 8, 148))], fill=stone_dk)
    for tx in (18, 102):
        d.rectangle([tx, 28, tx + 20, 148], fill=stone)
        d.rectangle([tx - 2, 20, tx + 22, 36], fill=stone_lt)
        for cx in range(tx, tx + 20, 5):
            d.rectangle([cx, 14, cx + 3, 22], fill=stone)
    d.rectangle([58, 100, 82, 148], fill=wood)
    d.rectangle([62, 108, 78, 148], fill=(40, 28, 18, 255))
    d.rectangle([68, 120, 72, 128], fill=wood_lt)
    d.polygon([(24, 48), (70, 18), (116, 48)], fill=roof)
    d.line([(24, 48), (70, 18), (116, 48)], fill=roof_dk)
    d.rectangle([40, 44, 100, 52], fill=wood)
    for wx, wy in [(44, 70), (86, 70), (44, 92), (86, 92)]:
        d.rectangle([wx, wy, wx + 10, wy + 14], fill=(30, 30, 40, 255))
    d.line([(70, 18), (70, 4)], fill=wood, width=1)
    d.polygon([(70, 4), (86, 8), (70, 12)], fill=(200, 40, 40, 255))
    save("assets/sprites/buildings/castle.png", cast)


def blank():
    return Image.new("RGBA", (40, 40), (0, 0, 0, 0))


def facing_variants(draw_fn, prefix):
    for facing in ("down", "up", "left", "right"):
        img = blank()
        draw_fn(ImageDraw.Draw(img), facing)
        save(f"assets/sprites/units/{prefix}_{facing}.png", img)


def draw_brad(d, facing):
    body = (70, 110, 70, 255)
    head = (200, 180, 150, 255)
    axe = (160, 160, 170, 255)
    haft = (110, 80, 45, 255)
    if facing in ("down", "up"):
        d.ellipse([14, 22, 26, 36], fill=(90, 70, 50, 255))
        d.rectangle([15, 12, 25, 26], fill=body)
        d.ellipse([15, 4, 25, 14], fill=head)
        d.line([(26, 16), (34, 8)], fill=haft, width=2)
        d.polygon([(32, 4), (38, 10), (34, 12), (30, 6)], fill=axe)
    else:
        d.ellipse([12, 24, 28, 36], fill=(90, 70, 50, 255))
        d.rectangle([14, 12, 26, 26], fill=body)
        d.ellipse([14, 4, 26, 14], fill=head)
        if facing == "right":
            d.line([(26, 16), (36, 10)], fill=haft, width=2)
            d.polygon([(34, 4), (40, 10), (36, 12), (32, 6)], fill=axe)
        else:
            d.line([(14, 16), (4, 10)], fill=haft, width=2)
            d.polygon([(6, 4), (0, 10), (4, 12), (8, 6)], fill=axe)


def draw_druz(d, facing):
    horse = (120, 90, 60, 255)
    horse_dk = (80, 55, 35, 255)
    rider = (60, 70, 120, 255)
    helm = (180, 180, 190, 255)
    blade = (200, 200, 210, 255)
    if facing in ("down", "up"):
        d.ellipse([8, 18, 32, 34], fill=horse)
        d.rectangle([10, 28, 14, 38], fill=horse_dk)
        d.rectangle([26, 28, 30, 38], fill=horse_dk)
        d.rectangle([16, 10, 24, 22], fill=rider)
        d.ellipse([16, 2, 24, 12], fill=helm)
        d.line([(24, 14), (32, 6)], fill=blade, width=2)
    else:
        d.ellipse([4, 16, 36, 32], fill=horse)
        for lx in (8, 16, 24, 30):
            d.rectangle([lx, 30, lx + 3, 38], fill=horse_dk)
        if facing == "right":
            d.ellipse([30, 14, 38, 24], fill=horse)
            d.rectangle([14, 8, 26, 20], fill=rider)
            d.ellipse([18, 2, 26, 10], fill=helm)
            d.line([(26, 12), (36, 6)], fill=blade, width=2)
        else:
            d.ellipse([2, 14, 10, 24], fill=horse)
            d.rectangle([14, 8, 26, 20], fill=rider)
            d.ellipse([14, 2, 22, 10], fill=helm)
            d.line([(14, 12), (4, 6)], fill=blade, width=2)


def draw_vuz(d, facing):
    wood = (110, 80, 45, 255)
    wood_dk = (70, 50, 30, 255)
    iron = (90, 90, 100, 255)
    wheel = (50, 40, 30, 255)
    if facing in ("down", "up"):
        d.rectangle([8, 10, 32, 30], fill=wood)
        d.rectangle([8, 10, 32, 14], fill=wood_dk)
        d.rectangle([14, 16, 18, 22], fill=(30, 30, 35, 255))
        d.rectangle([22, 16, 26, 22], fill=(30, 30, 35, 255))
        d.ellipse([8, 28, 16, 38], fill=wheel)
        d.ellipse([24, 28, 32, 38], fill=wheel)
        d.rectangle([18, 6, 22, 12], fill=iron)
    else:
        d.rectangle([6, 12, 34, 28], fill=wood)
        d.rectangle([6, 12, 10, 28], fill=wood_dk)
        d.rectangle([14, 16, 28, 22], fill=(30, 30, 35, 255))
        d.ellipse([8, 26, 16, 36], fill=wheel)
        d.ellipse([24, 26, 32, 36], fill=wheel)
        if facing == "right":
            d.rectangle([32, 16, 38, 20], fill=iron)
        else:
            d.rectangle([2, 16, 8, 20], fill=iron)


def draw_lanc(d, facing):
    body = (160, 40, 50, 255)
    slash = (220, 200, 80, 255)
    head = (200, 180, 150, 255)
    pike = (170, 170, 180, 255)
    if facing in ("down", "up"):
        d.rectangle([15, 12, 25, 28], fill=body)
        d.rectangle([15, 18, 25, 22], fill=slash)
        d.ellipse([15, 4, 25, 14], fill=head)
        d.ellipse([14, 26, 20, 36], fill=(60, 50, 40, 255))
        d.ellipse([20, 26, 26, 36], fill=(60, 50, 40, 255))
        d.line([(20, 8), (20, 0)], fill=pike, width=2)
        d.polygon([(18, 0), (22, 0), (20, 4)], fill=pike)
    else:
        d.rectangle([14, 12, 26, 28], fill=body)
        d.rectangle([14, 18, 26, 22], fill=slash)
        d.ellipse([14, 4, 26, 14], fill=head)
        d.ellipse([12, 26, 20, 36], fill=(60, 50, 40, 255))
        d.ellipse([20, 26, 28, 36], fill=(60, 50, 40, 255))
        if facing == "right":
            d.line([(26, 10), (38, 4)], fill=pike, width=2)
        else:
            d.line([(14, 10), (2, 4)], fill=pike, width=2)


if __name__ == "__main__":
    gen_castle()
    facing_variants(draw_brad, "bojovnik_bradatice")
    facing_variants(draw_druz, "druzinik")
    facing_variants(draw_vuz, "valecny_vuz")
    facing_variants(draw_lanc, "lancknecht")
    print("done")
