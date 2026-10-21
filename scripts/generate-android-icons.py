"""Generate Android launcher resources from the shared Carline DSM icon."""
from pathlib import Path
import sys
from PIL import Image

source = Path(sys.argv[1])
res = Path(sys.argv[2])
icon = Image.open(source).convert("RGBA")
if icon.size != (512, 512):
    raise SystemExit("Expected a 512px square brand icon")
for density, size in {"mdpi":48,"hdpi":72,"xhdpi":96,"xxhdpi":144,"xxxhdpi":192}.items():
    folder = res / ("mipmap-" + density)
    folder.mkdir(parents=True, exist_ok=True)
    for name in ("ic_launcher", "ic_launcher_round", "ic_launcher_foreground"):
        icon.resize((size, size), Image.Resampling.LANCZOS).save(folder / (name + ".png"))
# Adaptive icons have a 108dp canvas and a 66dp safe area.
canvas = Image.new("RGBA", (432, 432), "#111827")
foreground = icon.resize((264,264), Image.Resampling.LANCZOS)
canvas.alpha_composite(foreground, (84,84))
folder = res / "drawable-nodpi"
folder.mkdir(parents=True, exist_ok=True)
canvas.save(folder / "carline_launcher_foreground.png")
adaptive = res / "mipmap-anydpi-v26"
adaptive.mkdir(parents=True, exist_ok=True)
xml = '<?xml version="1.0" encoding="utf-8"?>\n<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android"><background android:drawable="@color/carline_icon_background"/><foreground android:drawable="@drawable/carline_launcher_foreground"/></adaptive-icon>\n'
for name in ("ic_launcher", "ic_launcher_round"):
    (adaptive / (name + ".xml")).write_text(xml)
values = res / "values"
values.mkdir(parents=True, exist_ok=True)
(values / "carline_icon_colors.xml").write_text('<resources><color name="carline_icon_background">#111827</color></resources>\n')
print("Carline DSM launcher icons generated:", source.name)
