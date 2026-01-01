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
