"""Export the existing raster artwork; never redraw the logo or its frame."""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
source = Image.open(ROOT / "assets/branding/driveit_icon_master.png").convert("RGBA")
rgb = np.asarray(source)[:, :, :3].astype(np.int16)
bright = rgb.max(axis=2)
chroma = bright - rgb.min(axis=2)
# The existing continuous neon rim is a barrier. Flood only from the exterior,
# leaving the enclosed dark navy artwork and every logo pixel untouched.
barrier = Image.fromarray(((bright >= 150) & (chroma >= 80)).astype(np.uint8) * 255).copy()
ImageDraw.floodfill(barrier, (0, 0), 128, thresh=0)
inside = np.asarray(barrier) != 128
if inside.mean() < 0.5:
    raise ValueError("The source neon rim is not closed; refusing a destructive cutout.")
alpha = Image.fromarray(inside.astype(np.uint8) * 255)
# Retain a narrow rim of original glow and antialias the cutout boundary.
alpha = alpha.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(0.6))
source.putalpha(alpha)
artwork = source.crop(alpha.getbbox())
side = max(artwork.size)
square = Image.new("RGBA", (side, side))
square.alpha_composite(artwork, ((side - artwork.width) // 2, (side - artwork.height) // 2))
artwork = square
generated = ROOT / "assets/branding/generated"
native = ROOT / "android/app/src/main/res/drawable-nodpi"
generated.mkdir(parents=True, exist_ok=True)
native.mkdir(parents=True, exist_ok=True)
for name in ("driveit_launcher_edgefit", "driveit_splash_edgefit"):
    # Transparent corners follow the actual rim, with no rectangular padding.
    path = generated / f"{name}.png"
    artwork.save(path)
    (native / path.name).write_bytes(path.read_bytes())

# Legacy launchers use the same cutout, not the old black square.
for density, size in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)):
    icon = Image.new("RGBA", (size, size))
    scaled = artwork.copy()
    scaled.thumbnail((size, size), Image.Resampling.LANCZOS)
    icon.alpha_composite(scaled, ((size - scaled.width) // 2, (size - scaled.height) // 2))
    folder = ROOT / f"android/app/src/main/res/mipmap-{density}"
    for name in ("ic_launcher.png", "ic_launcher_round.png"):
        icon.save(folder / name)
print(f"Exported existing artwork: {artwork.size}, alpha exterior, unchanged source.")
