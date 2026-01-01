import subprocess
from pathlib import Path

TTF = Path("orienteering_legend.ttf")

OUT_DIR = Path("glyphs_png")
OUT_DIR.mkdir(exist_ok=True)

TMP_CHAR = Path("_char.txt")

# --- настройки ---
START = 0xE100
COUNT = 171
W = 38
H = 38
POINTSIZE = 38
# ------------------

if not TTF.exists():
    raise SystemExit(f"Не найден TTF: {TTF.resolve()}")

def render_one(codepoint: int, out_png: Path):
    # пишем символ в UTF-8 файл
    TMP_CHAR.write_text(chr(codepoint), encoding="utf-8")

    cmd = [
        "magick",
        "-background", "black",
        "-fill", "white",
        "-font", str(TTF),
        "-pointsize", str(POINTSIZE),
        "-antialias", "off",
        "-gravity", "center",
        f"label:@{TMP_CHAR}",
        "-extent", f"{W}x{H}",
        str(out_png)
    ]

    subprocess.run(
        cmd,
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE  # если вдруг упадёт — увидим
    )

print(f"Рендерю {COUNT} глифов из {hex(START)}..{hex(START+COUNT-1)}")

for i in range(COUNT):
    cp = START + i
    out = OUT_DIR / f"{cp:04X}.png"
    render_one(cp, out)

TMP_CHAR.unlink(missing_ok=True)

print("ГОТОВО:", OUT_DIR.resolve())
