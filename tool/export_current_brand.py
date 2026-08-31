"""Export the original full logo and its launcher-only upper symbol."""
from pathlib import Path
import shutil

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
source_path = ROOT / "assets/branding/driveit_logo_current.png"
native = ROOT / "android/app/src/main/res/drawable-nodpi"
shutil.copyfile(source_path, native / source_path.name)
with Image.open(source_path) as source:
    artwork = source.convert("RGBA")
    # The transparent separation above DRIVEIT is at y=900 in the 1254px source.
    # Extract existing pixels only: no repainting, masking or color changes.
    symbol = artwork.crop((0, 0, artwork.width, 900))
    symbol = symbol.crop(symbol.getbbox())
    side = max(symbol.size)
    launcher = Image.new("RGBA", (side, side))
    launcher.alpha_composite(symbol, ((side - symbol.width) // 2, (side - symbol.height) // 2))
    launcher.save(native / "driveit_launcher_symbol.png")
    for density, size in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)):
        scaled = launcher.copy()
        scaled.thumbnail((size, size), Image.Resampling.LANCZOS)
        icon = Image.new("RGBA", (size, size), (0, 0, 0, 255))
        icon.alpha_composite(scaled, ((size - scaled.width) // 2, (size - scaled.height) // 2))
        folder = ROOT / f"android/app/src/main/res/mipmap-{density}"
        for name in ("ic_launcher.png", "ic_launcher_round.png"):
            icon.save(folder / name)
    print(f"Exported approved PNG {source.size}; source preserved unchanged.")
