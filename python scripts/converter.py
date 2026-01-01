import os
import re
import subprocess
from PIL import Image, ImageOps

# Input path
input_folder = input("Enter path to folder with .svg files: ").strip('"')
if not os.path.isdir(input_folder):
    print(f"❌ Folder not found: {input_folder}")
    exit(1)

# Icon size
try:
    icon_size = int(input("Enter icon size (e.g., 38 for 38x38): "))
except ValueError:
    print("❌ Invalid size input.")
    exit(1)

# Inversion option
invert_input = input("Invert non-transparent pixels to white? [0 - Yes / 1 - No] (Enter = Yes): ").strip()
preprocess_white = (invert_input != "1")
post_invert = (invert_input == "1")

# Stroke width
stroke_input = input("Enter stroke width in px (default = 1.0): ").strip()
try:
    stroke_width = float(stroke_input) if stroke_input else 1.0
except ValueError:
    print("❌ Invalid stroke width input.")
    exit(1)

# Inkscape path
inkscape_path = r"C:\Program Files\Inkscape\bin\inkscape.exe"

# Output folder
output_folder = os.path.join(input_folder, f"output_bmp_{icon_size}x{icon_size}")
os.makedirs(output_folder, exist_ok=True)

# Header file
header_filename = os.path.basename(os.path.normpath(input_folder)) + ".h"
header_path = os.path.join(output_folder, header_filename)

def sanitize_name(name):
    return re.sub(r'\W+', '_', name)

def reduce_stroke(svg_path, new_stroke_width):
    with open(svg_path, "r", encoding="utf-8") as f:
        svg_data = f.read()

    # Заменим все stroke-width="..." на новое значение
    svg_data = re.sub(r'stroke-width\s*=\s*["\']([\d.]+)["\']',
                      f'stroke-width="{new_stroke_width}"',
                      svg_data)

    temp_svg_path = svg_path + "_mod.svg"
    with open(temp_svg_path, "w", encoding="utf-8") as f:
        f.write(svg_data)

    return temp_svg_path

def convert_svg_to_png(svg_path, png_path, size):
    subprocess.run([
        inkscape_path,
        svg_path,
        '--export-type=png',
        f'--export-width={size}',
        f'--export-height={size}',
        f'--export-filename={png_path}',
        '--export-background-opacity=0',
        '--export-dpi=96'
    ], check=True)

with open(header_path, "w", encoding="utf-8") as header_file:
    header_file.write(f"// Auto-generated header for icons in {input_folder}\n")
    header_file.write("#pragma once\n\n")

    for filename in os.listdir(input_folder):
        if filename.lower().endswith(".svg"):
            input_path = os.path.join(input_folder, filename)
            base_name = os.path.splitext(filename)[0]
            var_name = sanitize_name(base_name)

            temp_png = os.path.join(output_folder, f"{var_name}_temp.png")
            output_bmp = os.path.join(output_folder, f"{var_name}.bmp")

            try:
                # Сначала уменьшаем stroke
                thin_svg = reduce_stroke(input_path, stroke_width)

                # PNG экспорт
                convert_svg_to_png(thin_svg, temp_png, icon_size)
                os.remove(thin_svg)

                # Открываем PNG
                img = Image.open(temp_png).convert("RGBA")

                # Всегда делаем белыми непрозрачные пиксели
                data = img.getdata()
                new_data = []
                for pixel in data:
                    if pixel[3] > 0:
                        new_data.append((255, 255, 255, 255))  # white
                    else:
                        new_data.append((0, 0, 0, 0))  # transparent
                img.putdata(new_data)

                background = Image.new("RGBA", img.size, (0, 0, 0, 255))  # black bg
                result = Image.alpha_composite(background, img).convert("RGB")

                if post_invert:
                    result = ImageOps.invert(result)

                result.save(output_bmp, format="BMP")

                # XBM-конвертация
                bw = result.convert("L").point(lambda x: 0 if x < 128 else 255, mode='1')
                pixels = bw.load()

                byte_data = []
                for y in range(icon_size):
                    for x_byte in range(0, icon_size, 8):
                        byte = 0
                        for bit in range(8):
                            x = x_byte + bit
                            if x < icon_size and pixels[x, y] == 0:
                                byte |= (1 << bit)
                        byte_data.append(byte)

                # Запись в .h
                header_file.write(f"const unsigned char {var_name}_icon[] PROGMEM = {{\n")
                for i in range(0, len(byte_data), 12):
                    line = ', '.join(f"0x{b:02X}" for b in byte_data[i:i+12])
                    header_file.write(f"  {line},\n")
                header_file.write("};\n\n")

                os.remove(temp_png)
                print(f"✅ {filename} → BMP + XBM")

            except Exception as e:
                print(f"❌ Error: {filename}: {e}")

print(f"\n✅ Done. Header file: {header_path}")
