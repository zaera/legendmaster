import os
import xml.etree.ElementTree as ET

ICON_DIR = "png"
OUT_XML = "legend_font.xml"

ICON_SIZE = 38
COLUMNS = 19

START_CODEPOINT = 0xE001  # Private Use Area

files = sorted(os.listdir(ICON_DIR))

font = ET.Element("font")

chars = ET.SubElement(font, "chars")
chars.set("count", str(len(files)))

for i, fname in enumerate(files):
    code = START_CODEPOINT + i

    x = (i % COLUMNS) * ICON_SIZE
    y = (i // COLUMNS) * ICON_SIZE

    ch = ET.SubElement(chars, "char")
    ch.set("id", str(code))
    ch.set("x", str(x))
    ch.set("y", str(y))
    ch.set("width", str(ICON_SIZE))
    ch.set("height", str(ICON_SIZE))
    ch.set("xadvance", str(ICON_SIZE))

tree = ET.ElementTree(font)
tree.write(OUT_XML, encoding="utf-8", xml_declaration=True)

print("OK:", OUT_XML)
