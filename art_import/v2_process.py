#!/usr/bin/env python3
"""v2: cut generated sheets (original pipeline: key, defringe, crop, NN scale, shared palette)."""
import importlib.util, sys
from pathlib import Path
import numpy as np
from PIL import Image
WORK = Path("/workspace/ceske-srdce-art/work")
spec = importlib.util.spec_from_file_location("polish", WORK / "polish.py")
pol = importlib.util.module_from_spec(spec); sys.modules["polish"] = pol; spec.loader.exec_module(pol)
fin = pol.fin
def apply_palette_hue(rgba, palette):
    pal = np.array(palette, dtype=np.int32)
    pal_green = (pal[:, 1] > pal[:, 2] + 8) & (pal[:, 1] >= pal[:, 0] - 18) & (pal[:, 1] > 28)
    out = rgba.copy(); a = out[..., 3] > 0
    pix = out[..., :3][a].astype(np.int32)
    d = ((pix[:, None, :] - pal[None, :, :]) ** 2).sum(axis=2).astype(np.float32)
    r, g, b = pix[:, 0], pix[:, 1], pix[:, 2]
    foliage = (g > b + 12) & (g >= r + 4) & (g > 40) & (b < 80)
    pen = np.zeros_like(d); pen[:, ~pal_green] = 90.0 ** 2
    d = d + pen * foliage[:, None]
    redish = np.array([(c[0] - c[1]) > 75 and c[0] > 90 for c in palette])
    is_red = ((r - g) > 72) & (r > 95) & (g < 0.45 * r) & (b < g + 25)
    pen2 = np.zeros_like(d); pen2[:, redish] = 1e9
    d = d + pen2 * ((~is_red) | (not ALLOW_RED[0]))[:, None]
    out[..., :3][a] = pal[d.argmin(axis=1)].astype(np.uint8)
    return out
pol.apply_palette_hue = apply_palette_hue
ALLOW_RED=[True]
OUT = Path("/workspace/ceske-srdce-art/v2/sprites")
pal_img = Image.open(WORK / "palette.png").convert("RGB")
PALETTE = [pal_img.getpixel((i * 16 + 8, 8)) for i in range(32)]
DEBUG = Path("/workspace/ceske-srdce-art/v2/debug"); DEBUG.mkdir(parents=True, exist_ok=True)

def cuts(sheet, min_area=400, gap=14, expect=None, row_slop=60):
    k = fin.load_keyed(sheet)
    k = fin.drop_specks(k, 30)
    boxes = fin.sort_reading_order(fin.components(k, min_area, gap), row_slop)
    print(sheet, [(b[0], b[1], b[2] - b[0], b[3] - b[1]) for b in boxes])
    if expect: assert len(boxes) == expect, (sheet, len(boxes))
    return [fin.cut_box(k, b) for b in boxes]

def finish(arr):
    arr = arr.copy()
    for _ in range(2):
        a = arr[..., 3] > 0
        r, g, b = [arr[..., i].astype(int) for i in range(3)]
        nb = np.zeros_like(a)
        nb[1:] |= ~a[:-1]; nb[:-1] |= ~a[1:]; nb[:, 1:] |= ~a[:, :-1]; nb[:, :-1] |= ~a[:, 1:]
        pink = a & nb & (r > g + 35) & (b > g + 15)
        arr[pink, 3] = 0
    arr = pol.extra_defringe(arr)
    arr = fin.drop_specks(arr, 3)
    q = pol.apply_palette_hue(arr, PALETTE)
    q[..., 3] = np.where(q[..., 3] > 0, 255, 0)
    return fin.crop_rgba(q, pad=0)

def on_canvas(sp, W, H):
    h, w = sp.shape[:2]
    W, H = max(W, w), max(H, h)
    c = np.zeros((H, W, 4), np.uint8)
    x = (W - w) // 2
    c[H - h:, x:x + w] = sp
    return c

def save(name, arr):
    p = OUT / name; Image.fromarray(arr).save(p); print(" ", name, arr.shape[1], "x", arr.shape[0])

def fit(cut, W, H):
    h, w = cut.shape[:2]; f = min(W / w, H / h)
    return fin.scale_factor(cut, f)

def building(cut, name, W, H, canvas=True):
    sp = finish(fit(cut, W, H))
    save(name, on_canvas(sp, W, H) if canvas else sp)

# --- buildings
c = cuts("v2_stable_mining.jpg", gap=22)
c = sorted(c, key=lambda a: -a.size)[:2]  # two biggest; order by x handled below
cs = cuts("v2_stable_mining.jpg", gap=22)
cs = sorted(cs, key=lambda a: -a.size)[:2]
stable, mining = (cs[0], cs[1]) if cs[0].shape[1] > cs[1].shape[1] else (cs[1], cs[0])
ALLOW_RED[0]=False
building(stable, "buildings/stable.png", 128, 72)
mining = sorted(cuts("v2_mining.jpg", gap=20), key=lambda a: -a.size)[0]
building(mining, "buildings/mining_camp.png", 96, 90)
lm = cuts("sheet_lumber_mill.png.jpg", min_area=300, gap=18)
lm = sorted(lm, key=lambda a: -a.size)[:2]
# lumber camp is the wider one
lumber = lm[0] if lm[0].shape[1] > lm[1].shape[1] else lm[1]
building(lumber, "buildings/lumber_camp.png", 100, 88)
castle = sorted(cuts("v2_castle.jpg", gap=20), key=lambda a: -a.size)[0]
building(castle, "buildings/castle.png", 156, 172)
st = sorted(cuts("v2_smith_tower.jpg", gap=30), key=lambda a: -a.size)[:2]
smith, tower = (st[0], st[1]) if st[0].shape[1] > st[1].shape[1] else (st[1], st[0])
ALLOW_RED[0]=True
building(smith, "buildings/blacksmith.png", 72, 100)
# watch tower: 40 px footprint width (posts), taller sprite
ALLOW_RED[0]=False
sp = finish(fin.scale_to_width(tower, 44)); save("buildings/watch_tower.png", sp)
wl = cuts("v2_walls.jpg", gap=16)
wl = sorted(sorted(wl, key=lambda a: -a.size)[:3], key=lambda a: a.shape[1])
# by x order instead
wl_all = cuts("v2_walls.jpg", gap=16)
big = sorted(wl_all, key=lambda a: -a.size)[:3]
# reading order kept in wl_all; filter
wl = [a for a in wl_all if any(a is b for b in big)]
save("buildings/palisade.png", finish(fin.scale_to_width(wl[0], 40)))
save("buildings/stone_wall.png", finish(fin.scale_to_width(wl[1], 40)))
save("buildings/gate.png", finish(fin.scale_to_width(wl[2], 120)))

ALLOW_RED[0]=True
# --- units
def body_h(cut):
    h, w = cut.shape[:2]
    col = cut[:, int(w * 0.30):int(w * 0.70), 3] > 0
    rows = np.where(col.any(axis=1))[0]
    return int(rows[-1] - rows[0] + 1)

def unit(name, front, side, back, factor, W, H, mirror_side=True, right=None):
    imgs = {"down": front, "left": side, "right": right if right is not None else side[:, ::-1].copy(), "up": back}
    sps = {d: finish(fin.scale_factor(a, factor)) for d, a in imgs.items()}
    CW = max(W, *[s.shape[1] for s in sps.values()]); CH = max(H, *[s.shape[0] for s in sps.values()])
    for d, s in sps.items(): save(f"units/{name}_{d}.png", on_canvas(s, CW, CH))

bo = cuts("v2_bojovnik.jpg", gap=10, expect=4)
unit("bojovnik_bradatice", bo[0], bo[1], bo[3], 40 / body_h(bo[0]), 36, 44)
inf = cuts("v2_infantry.jpg", gap=8, row_slop=80)
lk = inf[4:8]
# lancknecht body height: measure without pike -> use torso column centre
f_lk = 40 / (body_h(lk[0]) * 0.88)
unit("lancknecht", lk[0], lk[1], lk[3], f_lk, 36, 44)
cav = cuts("v2_cavalry.jpg", gap=10, row_slop=80, expect=8)
fc = 54 / cav[1].shape[1]
unit("light_cavalry", cav[0], cav[1], cav[3], fc, 54, 48)
unit("knight", cav[4], cav[5], cav[7], 54 / cav[5].shape[1], 54, 48)
dw = cuts("v2_druzinik_wagon.jpg", gap=10, row_slop=80)
unit("druzinik", dw[0], dw[1], dw[3], 54 / dw[1].shape[1], 54, 48)
wg = cuts("v2_wagon.jpg", gap=12, expect=4)
unit("valecny_vuz", wg[0], wg[1], wg[3], 56 / wg[1].shape[1], 48, 44)
print("DONE")
