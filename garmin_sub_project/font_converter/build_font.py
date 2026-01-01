import os
import re
import json
import shutil
import subprocess
from pathlib import Path
from PIL import Image

# ===================== НАСТРОЙКИ =====================
H_FILE = Path("symbols-isom2024.h")

WIDTH = 38
HEIGHT = 38
BYTES_PER_ROW = (WIDTH + 7) // 8  # 5
BYTES_PER_ICON = BYTES_PER_ROW * HEIGHT  # 190

UNICODE_START = 0xE100  # Private Use Area для Garmin

OUT_DIR = Path("out")
OUT_PNG = OUT_DIR / "out_png"
OUT_SVG = OUT_DIR / "out_svg"      # теперь делаем SVG сами (pixel-perfect)
OUT_FONT = OUT_DIR / "out_font"

FONT_TTF = OUT_FONT / "orienteering_legend.ttf"
MAPPING_JSON = OUT_FONT / "mapping.json"

# FontForge (CLI). Укажи свой путь.
FONTFORGE_EXE = Path(r"C:\Program Files\FontForgeBuilds\bin\fontforge.exe")

# Pixel->SVG режим:
#  - "rect": <rect> для каждого слитого прямоугольника (лучше для ортогональных форм)
#  - "path": один общий <path> (обычно легче для некоторых импортёров, но rect тоже ок)
SVG_MODE = "rect"

# Записывать ли отладочную инфу по каждому символу
VERBOSE = False
# ======================================================


def find_exe(name: str):
    p = shutil.which(name)
    return Path(p) if p else None


def decode_1bpp_xbm_u8g2(data_bytes):
    """
    XBM / U8g2 drawXBM format:
    - row-major
    - LSB first
    - bit 0 = leftmost pixel
    В PIL Image(mode '1'): 0=black, 1=white.
    """
    if len(data_bytes) != BYTES_PER_ICON:
        raise ValueError("Invalid icon size")

    img = Image.new("1", (WIDTH, HEIGHT), 1)  # белый фон
    px = img.load()

    for y in range(HEIGHT):
        row_base = y * BYTES_PER_ROW
        for x in range(WIDTH):
            b = data_bytes[row_base + (x // 8)]
            bit = (b >> (x % 8)) & 1  # LSB-first
            px[x, y] = 1 if bit else 0

    return img


def save_preview_png(mask_img: Image.Image, png_path: Path):
    """
    mask_img: mode '1' (0 black, 1 white)
    делаем PNG для просмотра: белое на чёрном (как у тебя было)
    """
    preview = Image.new("L", (WIDTH, HEIGHT), 0)
    px_in = mask_img.load()
    px_out = preview.load()
    for y in range(HEIGHT):
        for x in range(WIDTH):
            px_out[x, y] = 255 if px_in[x, y] == 1 else 0
    png_path.parent.mkdir(parents=True, exist_ok=True)
    preview.save(png_path)


def merge_black_pixels_to_rects(mask_img: Image.Image):
    """
    Pixel-perfect объединение:
    1) ищем горизонтальные сегменты чёрных пикселей
    2) объединяем одинаковые сегменты по вертикали
    Возвращает список прямоугольников: (x, y, w, h) в координатах пикселей.
    """
    w, h = mask_img.size
    px = mask_img.load()

    # 1) собрать горизонтальные сегменты
    runs = []
    for y in range(h):
        x = 0
        while x < w:
            if px[x, y] == 0:  # black
                x0 = x
                while x < w and px[x, y] == 0:
                    x += 1
                runs.append([x0, y, x - x0, 1])  # (x,y,width,height=1)
            else:
                x += 1

    # 2) объединение по вертикали одинаковых (x, width)
    runs.sort(key=lambda r: (r[0], r[2], r[1]))  # x, w, y
    rects = []
    i = 0
    while i < len(runs):
        x, y, rw, rh = runs[i]
        y_next = y + 1
        j = i + 1
        # тянем вниз пока следующий run имеет тот же x и rw и y_next
        while j < len(runs):
            x2, y2, rw2, rh2 = runs[j]
            if x2 == x and rw2 == rw and y2 == y_next:
                rh += 1
                y_next += 1
                j += 1
            else:
                break
        rects.append((x, y, rw, rh))
        i = j

    return rects


def write_pixel_perfect_svg(mask_img: Image.Image, svg_path: Path, mode="rect"):
    """
    Делает SVG строго по пикселям (никаких трассировок).
    В SVG координаты: (0..WIDTH, 0..HEIGHT), один пиксель = 1 единица.
    Чёрные пиксели = заливка (fill="black").
    """
    rects = merge_black_pixels_to_rects(mask_img)
    svg_path.parent.mkdir(parents=True, exist_ok=True)

    w, h = mask_img.size

    if mode not in ("rect", "path"):
        mode = "rect"

    with svg_path.open("w", encoding="utf-8") as f:
        f.write('<?xml version="1.0" encoding="UTF-8"?>\n')
        f.write(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" ')
        f.write('shape-rendering="crispEdges">\n')
        # crispEdges помогает браузерам держать пиксельность при просмотре

        if mode == "rect":
            f.write('<g fill="black" stroke="none">\n')
            for x, y, rw, rh in rects:
                f.write(f'  <rect x="{x}" y="{y}" width="{rw}" height="{rh}"/>\n')
            f.write('</g>\n')
        else:
            # path-режим: каждый прямоугольник как отдельный subpath
            # Это тоже пиксель-перфект, но меньше тегов.
            f.write('<path fill="black" stroke="none" d="')
            parts = []
            for x, y, rw, rh in rects:
                x2 = x + rw
                y2 = y + rh
                # M x y  H x2  V y2  H x  Z
                parts.append(f'M{x} {y}H{x2}V{y2}H{x}Z')
            f.write(" ".join(parts))
            f.write('"/>\n')

        f.write('</svg>\n')

    if VERBOSE:
        print(f"SVG rects: {len(rects)} -> {svg_path.name}")


def make_fontforge_script():
    """
    FontForge script читает out_svg/*.svg (pixel-perfect) и генерит TTF.
    """
    return r'''
import os
import fontforge

EM_SIZE = 1024
UNICODE_START = 0xE100

base = os.path.dirname(__file__)
svg_dir = os.path.join(os.path.dirname(base), "out_svg")
out_ttf = os.path.join(base, "orienteering_legend.ttf")

font = fontforge.font()
font.encoding = "UnicodeFull"
font.em = EM_SIZE
font.ascent = 850
font.descent = 174
font.fontname = "OrienteeringLegend"
font.familyname = "Orienteering Legend"
font.fullname = "Orienteering Legend"

code = UNICODE_START

files = [f for f in os.listdir(svg_dir) if f.lower().endswith(".svg")]
files.sort()

for f in files:
    name = os.path.splitext(f)[0]
    glyphname = "i_" + name
    path = os.path.join(svg_dir, f)

    g = font.createChar(code, glyphname)
    g.importOutlines(path)

    # Для пиксельных ортогональных форм:
    g.removeOverlap()
    g.correctDirection()

    xmin, ymin, xmax, ymax = g.boundingBox()
    size = max(xmax - xmin, ymax - ymin)
    if size <= 0:
        code += 1
        continue

    # Масштабируем так, чтобы вписать по большей стороне в EM_SIZE
    scale = EM_SIZE / float(size)
    g.transform((scale, 0, 0, scale, 0, 0))

    # Центрируем
    xmin, ymin, xmax, ymax = g.boundingBox()
    dx = (EM_SIZE - (xmax - xmin)) / 2.0 - xmin
    dy = (EM_SIZE - (ymax - ymin)) / 2.0 - ymin
    g.transform((1, 0, 0, 1, dx, dy))

    g.width = EM_SIZE
    code += 1

font.generate(out_ttf)
font.close()
print("TTF:", out_ttf)
'''.lstrip()


def main():
    if not H_FILE.exists():
        raise SystemExit(f"Не найден файл: {H_FILE.resolve()}")

    OUT_PNG.mkdir(parents=True, exist_ok=True)
    OUT_SVG.mkdir(parents=True, exist_ok=True)
    OUT_FONT.mkdir(parents=True, exist_ok=True)

    # Проверим fontforge.exe
    if FONTFORGE_EXE is None:
        ff = find_exe("fontforge.exe") or find_exe("fontforge")
        if ff:
            globals()["FONTFORGE_EXE"] = ff

    text = H_FILE.read_text(encoding="utf-8", errors="ignore")

    icon_re = re.compile(
        r"const\s+unsigned\s+char\s+([A-Za-z0-9_]+)_icon\[\]\s+PROGMEM\s*=\s*\{(.*?)\};",
        re.S
    )
    hex_re = re.compile(r"0x([0-9A-Fa-f]{1,2})")

    icons = []
    for m in icon_re.finditer(text):
        name = m.group(1)
        body = m.group(2)
        bytes_list = [int(h, 16) for h in hex_re.findall(body)]
        if len(bytes_list) != BYTES_PER_ICON:
            continue
        icons.append((name, bytes_list))

    if not icons:
        raise SystemExit("Не нашел ни одной иконки 38x38 (190 байт). Проверь файл .h.")

    print(f"Найдено иконок: {len(icons)}")

    # 1) PNG + 2) Pixel-perfect SVG
    for name, data in icons:
        img = decode_1bpp_xbm_u8g2(data)

        save_preview_png(img, OUT_PNG / f"{name}.png")
        write_pixel_perfect_svg(img, OUT_SVG / f"{name}.svg", mode=SVG_MODE)

    print(f"PNG: {OUT_PNG.resolve()}")
    print(f"SVG (pixel-perfect): {OUT_SVG.resolve()}")

    # mapping.json
    mapping = []
    code = UNICODE_START
    for name, _ in icons:
        mapping.append({
            "name": name,
            "glyph": f"i_{name}",
            "unicode_dec": code,
            "unicode_hex": hex(code),
            "unicode_escape": "\\u%04X" % code
        })
        code += 1
    MAPPING_JSON.write_text(json.dumps(mapping, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"mapping.json: {MAPPING_JSON.resolve()}")

    # 3) FontForge -> TTF
    if FONTFORGE_EXE and FONTFORGE_EXE.exists():
        print(f"FontForge найден: {FONTFORGE_EXE}")
        ff_script = OUT_FONT / "_build_font_ff.py"
        ff_script.write_text(make_fontforge_script(), encoding="utf-8")
        subprocess.run([str(FONTFORGE_EXE), "-script", str(ff_script)], check=True)
        print(f"TTF готов: {FONT_TTF.resolve()}")
    else:
        print("TTF не собираю: fontforge.exe не найден. Укажи FONTFORGE_EXE в настройках.")

    print("ГОТОВО.")


if __name__ == "__main__":
    main()
