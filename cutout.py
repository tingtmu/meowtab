#!/usr/bin/env python
"""cutout.py - make cartoon stickers (dark outline on a near-uniform light
background) transparent and crop them to a tight square.

    python cutout.py images/dog_*.png     clean in place (original -> .bak-<timestamp>)
    python cutout.py a.png b.png --preview   write <stem>.preview.png on magenta, touch nothing
    python cutout.py x.png --no-seal      disable the virtual bottom seal

Already-transparent images only get the crop, so running twice is a no-op.
Method: background colour from the border median; flood-fill from the border
over pixels not "sealed" by the outline, so a white subject on white survives.
"""
import argparse
import glob
import os
import shutil
import sys
from datetime import datetime

import numpy as np
from PIL import Image, ImageDraw, ImageOps
from scipy import ndimage as ndi

INK_MAX = 110          # max(R,G,B) below this = ink
CHROMA_MIN = 25        # max-min above this (and not bg-coloured) = coloured fill
SEAL_R = 4             # closing radius for outline gaps (px at scale 1)
SEAL_GAP = 100         # bottom seal: strokes must be this far from centre (px at scale 1)
SEAL_THICK = 3         # bottom seal line thickness (px at scale 1)
REF_SIZE = 780         # subject size (px) that corresponds to scale 1
MIN_SPECK = 500        # opaque specks smaller than this are dropped (px^2 at scale 1)
EDGE_REACH = 3         # soft-edge width (px at scale 1)
TRANSP_ALPHA = 16      # alpha below this counts as transparent
TRANSP_SHARE = 0.01    # ... if more than this share of pixels is
CROP_ALPHA = 20        # content = alpha > ~8%
CROP_PAD = 0.03        # padding per side, share of content size
ALPHA_FORMATS = {".png", ".webp", ".tif", ".tiff"}


class Skip(Exception):
    """File cannot / should not be processed; message is the reason."""


# ---------- input ----------

def expand_args(patterns):
    """Expand globs ourselves (PowerShell doesn't); keep order, drop duplicates."""
    paths = []
    for pat in patterns:
        if glob.has_magic(pat):
            hits = sorted(p for p in glob.glob(pat) if not p.lower().endswith(".preview.png"))
            if not hits:
                print(f"{pat}: skipped (no files match)")
            paths += hits
        else:
            paths.append(pat)
    return list(dict.fromkeys(paths))


def load_rgba(path):
    img = ImageOps.exif_transpose(Image.open(path))
    return np.asarray(img.convert("RGBA")).copy()


def has_transparency(rgba):
    return (rgba[..., 3] < TRANSP_ALPHA).mean() > TRANSP_SHARE


def flatten_on_white(rgba):
    """Opaque RGB; any stray alpha is composited on white."""
    white = Image.new("RGBA", rgba.shape[1::-1], (255, 255, 255, 255))
    white.alpha_composite(Image.fromarray(rgba, "RGBA"))
    return np.asarray(white.convert("RGB")).astype(np.int16)


# ---------- background removal ----------

def estimate_background(rgb):
    """Median border colour, a tolerance from border noise, share of border that fits."""
    border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
    color = np.median(border, axis=0)
    dev = np.abs(border - color).max(axis=1)
    tol = float(np.clip(6 * np.median(dev) + 8, 12, 40))
    return color, tol, float((dev <= tol).mean())


def close_mask(mask, r):
    """Binary closing with a disk of radius r (distance-transform based, fast for big r)."""
    p = np.pad(mask, r + 2)
    dil = ndi.distance_transform_edt(~p) <= r
    return (ndi.distance_transform_edt(dil) > r)[r + 2:-(r + 2), r + 2:-(r + 2)]


def drop_small(mask, min_area):
    """Remove 8-connected components of mask smaller than min_area."""
    lab, n = ndi.label(mask, structure=np.ones((3, 3)))
    areas = np.bincount(lab.ravel(), minlength=n + 1)
    keep = areas >= min_area
    keep[0] = False
    return keep[lab]


def main_ink(ink):
    """Ink components that are at least 5% as big as the largest one (drops dust)."""
    lab, n = ndi.label(ink, structure=np.ones((3, 3)))
    areas = np.bincount(lab.ravel(), minlength=n + 1)
    areas[0] = 0
    return (areas >= 0.05 * areas.max())[lab] & ink if n else ink


def bottom_seal(ink, scale):
    """Thin line joining the lowest ink pixel of the left and right parts of the
    subject (for outlines left open at the bottom). None if it doesn't apply."""
    ys, xs = np.nonzero(ink)
    y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
    cx, gap = (x0 + x1) / 2, SEAL_GAP * scale
    ends = []
    for side in (xs < cx - gap, xs > cx + gap):
        if not side.any():
            return None
        i = np.argmax(np.where(side, ys, -1))
        ends.append((int(xs[i]), int(ys[i])))
    (xl, yl), (xr, yr) = ends
    h = y1 - y0 + 1
    if min(yl, yr) < y0 + 0.7 * h or abs(yl - yr) > 0.15 * h:  # must be bottom strokes
        return None
    line = Image.new("L", ink.shape[::-1], 0)
    ImageDraw.Draw(line).line([(xl, yl), (xr, yr)], fill=255, width=max(1, round(SEAL_THICK * scale)))
    return np.asarray(line) > 0


def stops_leak(region, features, min_features=3):
    """Is the area the seal protects really a subject body? It must be sizeable and
    border several separate ink/colour features (outline + face parts...); an empty
    hollow (e.g. the gap between two legs) is not sealed."""
    if region.sum() < 0.002 * region.size:
        return False
    lab, _ = ndi.label(features, structure=np.ones((3, 3)))
    touching = lab[ndi.binary_dilation(region, iterations=2) & features]
    return len(np.unique(touching[touching > 0])) >= min_features


def flood_from_border(sealed):
    """4-connected flood over unsealed pixels, seeded from the image border."""
    lab, _ = ndi.label(~sealed)
    edge = np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]])
    return np.isin(lab, np.unique(edge[edge > 0]))


def paint_gaps(rgb, gap, bg, ink_color):
    """Pale pixels in closed outline gaps that touch the background -> ink colour."""
    lab, _ = ndi.label(gap, structure=np.ones((3, 3)))
    touch = np.unique(lab[ndi.binary_dilation(bg, structure=np.ones((3, 3))) & gap])
    out = rgb.copy()
    out[np.isin(lab, touch[touch > 0])] = ink_color
    return out


def soft_edge(rgb, bg, bg_color, ink_color, reach):
    """Alpha (0-255) for background pixels near the subject, from their darkness."""
    near = bg & (ndi.distance_transform_edt(bg) <= reach)
    lum = rgb.mean(axis=2)
    top, low, margin = bg_color.mean(), ink_color.mean(), 10
    a = np.clip((top - lum - margin) / max(top - low - margin, 1), 0, 1)
    return np.where(near, a * 255, 0).astype(np.uint8)


def remove_background(rgb, use_seal=True):
    """rgb: HxWx3 int16. Returns (RGBA uint8, note)."""
    bg_color, tol, fit = estimate_background(rgb)
    if fit < 0.8:
        raise Skip("background not uniform (border colours vary)")
    if bg_color.mean() < 150:
        raise Skip("background is not light")
    near_bg = np.abs(rgb - bg_color).max(axis=2) <= tol
    ink = rgb.max(axis=2) < INK_MAX
    core = main_ink(ink)  # the outline, without dust, for measuring
    if not core.any():
        raise Skip("no dark outline found")
    ys, xs = np.nonzero(core)
    scale = float(np.clip(max(np.ptp(ys), np.ptp(xs)) / REF_SIZE, 0.05, 20))

    colored = (np.ptp(rgb, axis=2) > CHROMA_MIN) & ~near_bg
    closed = close_mask(ink, max(1, round(SEAL_R * scale)))
    sealed = closed | colored
    bg = flood_from_border(sealed)
    note = []
    line = bottom_seal(core, scale) if use_seal else None
    if line is not None:
        bg_sealed = flood_from_border(sealed | line)
        if stops_leak(bg & ~bg_sealed, ink | colored):
            bg = bg_sealed
            for _ in range(max(1, round(SEAL_THICK * scale))):  # peel bg-coloured line pixels
                bg = bg | (line & near_bg & ndi.binary_dilation(bg))
            note.append("bottom seal")
    if not bg.any():
        raise Skip("no background reachable from the border (subject touches all edges?)")

    ink_color = np.median(rgb[core], axis=0)
    rgb = paint_gaps(rgb, closed & ~ink & ~colored, bg, ink_color)
    speck = MIN_SPECK * (max(bg.shape) / 1000) ** 2  # dust size follows the image, not the subject
    bg = ~drop_small(~bg, speck)  # opaque specks -> background
    alpha = np.where(bg, 0, 255).astype(np.uint8)
    edge = soft_edge(rgb, bg, bg_color, ink_color, max(1.0, EDGE_REACH * scale))
    out = np.where(bg[..., None], ink_color, rgb)
    alpha = np.maximum(alpha, edge)
    rgba = np.dstack([out, alpha]).astype(np.uint8)
    note.insert(0, f"bg rgb({int(bg_color[0])},{int(bg_color[1])},{int(bg_color[2])}), tol {tol:.0f}")
    return rgba, ", ".join(note)


# ---------- crop / output ----------

def crop_square(rgba):
    """Tight square around alpha > ~8% content, 3% padding per side, no scaling."""
    ys, xs = np.nonzero(rgba[..., 3] > CROP_ALPHA)
    if ys.size == 0:
        raise Skip("nothing visible after processing")
    x0, y0 = int(xs.min()), int(ys.min())
    w, h = int(xs.max()) + 1 - x0, int(ys.max()) + 1 - y0
    m = max(w, h)
    side = m + 2 * round(m * CROP_PAD)
    left, top = x0 - (side - w) // 2, y0 - (side - h) // 2
    out = np.zeros((side, side, 4), np.uint8)
    sx0, sy0 = max(left, 0), max(top, 0)
    sx1, sy1 = min(left + side, rgba.shape[1]), min(top + side, rgba.shape[0])
    out[sy0 - top:sy1 - top, sx0 - left:sx1 - left] = rgba[sy0:sy1, sx0:sx1]
    return out


def on_magenta(rgba):
    base = Image.new("RGBA", rgba.shape[1::-1], (255, 0, 255, 255))
    base.alpha_composite(Image.fromarray(rgba, "RGBA"))
    return base.convert("RGB")


def process_file(path, args, stamp):
    """Returns the one-line status message for this file."""
    try:
        src = load_rgba(path)
    except Image.UnidentifiedImageError:
        raise Skip("not a readable image file")
    except Exception as e:  # truncated / corrupt / permission etc.
        raise Skip(f"cannot read image ({type(e).__name__}: {str(e)[:60]})")
    if has_transparency(src):
        result, what = src, "already transparent: crop only"
    else:
        result, what = remove_background(flatten_on_white(src), args.seal)
        what = f"cleaned ({what})"
    result = crop_square(result)
    size = f"{result.shape[1]}x{result.shape[0]}"

    if args.preview:
        out = os.path.splitext(path)[0] + ".preview.png"
        on_magenta(result).save(out)
        return f"{what} -> {size}, preview: {out}"
    if result.shape == src.shape and np.array_equal(result, src):
        return f"{what} -> {size}, unchanged"
    target, ext = path, os.path.splitext(path)[1].lower()
    backup = ""
    if ext in ALPHA_FORMATS:
        backup = f"{path}.bak-{stamp}"
        shutil.copy2(path, backup)
        backup = f", backup: {os.path.basename(backup)}"
    else:  # jpg/bmp can't hold alpha: write a sibling png, keep the original
        target = os.path.splitext(path)[0] + ".png"
        backup = f", wrote {os.path.basename(target)} (format has no alpha)"
    Image.fromarray(result, "RGBA").save(target)
    return f"{what} -> {size}{backup}"


def main(argv=None):
    ap = argparse.ArgumentParser(description="Remove light backgrounds from cartoon stickers and crop to a square.")
    ap.add_argument("files", nargs="+", help="image files or globs (e.g. dog_*.png)")
    ap.add_argument("--preview", action="store_true", help="write <stem>.preview.png (on magenta) instead of editing")
    ap.add_argument("--no-seal", dest="seal", action="store_false", help="disable the virtual bottom seal")
    args = ap.parse_args(argv)
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(errors="replace")
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    failed = 0
    for path in expand_args(args.files):
        name = os.path.basename(path)
        try:
            if not os.path.isfile(path):
                raise Skip("file not found")
            print(f"{name}: {process_file(path, args, stamp)}")
        except Skip as s:
            failed += 1
            print(f"{name}: skipped - {s}")
        except Exception as e:  # never kill the batch
            failed += 1
            print(f"{name}: skipped - unexpected error ({type(e).__name__}: {e})")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
