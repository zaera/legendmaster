import xml.etree.ElementTree as ET

tree = ET.parse("legend_font.xml")
root = tree.getroot()

chars = root.find("chars")

print("var GLYPHS = {")
for ch in chars.findall("char"):
    cid = int(ch.attrib["id"])
    x = ch.attrib["x"]
    y = ch.attrib["y"]
    w = ch.attrib["width"]
    h = ch.attrib["height"]
    xa = ch.attrib["xadvance"]

    print(f"    {cid} => [{x}, {y}, {w}, {h}, {xa}],")
print("};")