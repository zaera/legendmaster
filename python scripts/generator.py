import os
import re
from PIL import Image

# Ask user for folder path
input_folder = input("Enter path to folder with .bmp files: ").strip('"')
if not os.path.isdir(input_folder):
    print(f"❌ Folder not found: {input_folder}")
    exit(1)

# Generate .h file path based on folder name
header_filename = os.path.basename(os.path.normpath(input_folder)) + ".h"
header_path = os.path.join(input_folder, header_filename)

# Utility to make valid C variable names
def sanitize_name(name):
    return re.sub(r'\W+', '_', name)

# Write header file
with open(header_path, "w", encoding="utf-8") as header_file:
    header_file.write(f"// Auto-generated XBM header from BMP files in {input_folder}\n")
    header_file.write("#pragma once\n\n")

    for filename in os.listdir(input_folder):
        if filename.lower().endswith(".bmp"):
            bmp_path = os.path.join(input_folder, filename)
            base_name = os.path.splitext(filename)[0]
            var_name = sanitize_name(base_name)

            try:
                img = Image.open(bmp_path).convert("L")
                bw = img.point(lambda x: 0 if x < 128 else 255, mode='1')
                width, height = bw.size
                pixels = bw.load()

                # Convert to byte array
                byte_data = []
                for y in range(height):
                    for x_byte in range(0, width, 8):
                        byte = 0
                        for bit in range(8):
                            x = x_byte + bit
                            if x < width and pixels[x, y] == 0:
                                byte |= (1 << bit)
                        byte_data.append(byte)

                # Write array
                header_file.write(f"const unsigned char {var_name}_icon[] PROGMEM = {{\n")
                for i in range(0, len(byte_data), 12):
                    line = ', '.join(f"0x{b:02X}" for b in byte_data[i:i+12])
                    header_file.write(f"  {line},\n")
                header_file.write("};\n\n")

                print(f"✅ Processed {filename}")

            except Exception as e:
                print(f"❌ Failed to process {filename}: {e}")

print(f"\n✅ Done! Header saved to: {header_path}")
