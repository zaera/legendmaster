import subprocess
from pathlib import Path

INKSCAPE = r"C:\Program Files\Inkscape\bin\inkscape.exe"

BASE_DIR = Path(r"C:\Users\punishman\Documents\GitHub\legendmaster\o_legends\symbols-isom2024")
OUT_DIR = BASE_DIR / "png"
OUT_DIR.mkdir(exist_ok=True)

SIZE = 64

for svg in BASE_DIR.glob("*.svg"):
    out_png = OUT_DIR / (svg.stem + ".png")

    print(f"▶ {svg.name}")

    try:
        # SVG -> PNG
        # чёрная иконка на БЕЛОМ фоне
        subprocess.run([
            INKSCAPE,
            str(svg),
            "--export-type=png",
            f"--export-filename={out_png}",
            f"--export-width={SIZE}",
            f"--export-height={SIZE}",
            "--export-background=#FFFFFF",
            "--export-background-opacity=1"
        ], check=True)

        print(f"  ✓ создано: {out_png.name}")

    except subprocess.CalledProcessError as e:
        print(f"  ✖ ошибка\n{e}")

print("\nГОТОВО. В папке png — только нужные файлы.")
