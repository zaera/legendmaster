import tkinter as tk
from tkinter import filedialog
import re

# === НАСТРОЙКИ ===
pixel_scale = 5  # масштаб пикселей на экране
# =================

def ask_for_size():
    try:
        width = int(input("Enter default WIDTH (e.g. 38): ") or "38")
        height = int(input("Enter default HEIGHT (e.g. 38): ") or "38")
        return width, height
    except ValueError:
        print("❌ Invalid input. Using default 38x38.")
        return 38, 38

def parse_symbols_h(content, default_width, default_height):
    pattern = re.compile(
        r'const\s+unsigned\s+char\s+(\w+)_icon\[\]\s+PROGMEM\s*=\s*\{(.*?)\};',
        re.DOTALL
    )
    icons = []
    for name, body in pattern.findall(content):
        hex_values = re.findall(r'0x[0-9A-Fa-f]{2}', body)
        byte_array = [int(h, 16) for h in hex_values]
        icons.append({
            "name": name,
            "width": default_width,
            "height": default_height,
            "bytes": byte_array
        })
    return icons

def parse_xbm_array(content):
    pattern = re.compile(
        r'#define\s+(\w+)_width\s+(\d+)\s+'
        r'#define\s+\1_height\s+(\d+)\s+'
        r'static\s+unsigned\s+char\s+\1_bits\[\]\s*=\s*\{(.*?)\};',
        re.DOTALL
    )
    icons = []
    for name, width, height, body in pattern.findall(content):
        hex_values = re.findall(r'0x[0-9A-Fa-f]{2}', body)
        byte_array = [int(h, 16) for h in hex_values]
        icons.append({
            "name": name,
            "width": int(width),
            "height": int(height),
            "bytes": byte_array
        })
    return icons

def show_gallery(icons):
    index = 0

    def render():
        canvas.delete("all")
        label.config(text=f"{icons[index]['name']} ({icons[index]['width']}x{icons[index]['height']})")

        width = icons[index]['width']
        height = icons[index]['height']
        data = icons[index]['bytes']
        bytes_per_row = (width + 7) // 8

        for y in range(height):
            for x_byte in range(bytes_per_row):
                byte_index = y * bytes_per_row + x_byte
                if byte_index >= len(data):
                    continue
                byte = data[byte_index]
                for bit in range(8):
                    x = x_byte * 8 + bit
                    if x >= width:
                        continue
                    if (byte >> bit) & 1:
                        canvas.create_rectangle(
                            x * pixel_scale, y * pixel_scale,
                            (x + 1) * pixel_scale, (y + 1) * pixel_scale,
                            fill='black', outline='black'
                        )

    def next_icon(event=None):
        nonlocal index
        index = (index + 1) % len(icons)
        render()

    def prev_icon(event=None):
        nonlocal index
        index = (index - 1 + len(icons)) % len(icons)
        render()

    root = tk.Tk()
    root.title("XBM Icon Gallery")

    label = tk.Label(root, text="", font=("Arial", 14))
    label.pack()

    canvas = tk.Canvas(root, width=icons[0]['width'] * pixel_scale,
                       height=icons[0]['height'] * pixel_scale, bg='white')
    canvas.pack()

    root.bind("<Right>", next_icon)
    root.bind("<Left>", prev_icon)

    render()
    root.mainloop()

# === ВЫБОР ФАЙЛА ===
file_path = filedialog.askopenfilename(title="Select .h file", filetypes=[("Header Files", "*.h")])
if not file_path:
    print("No file selected.")
else:
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Автоопределение формата и размеров
    if "PROGMEM" in content:
        default_width, default_height = ask_for_size()
        icons = parse_symbols_h(content, default_width, default_height)
    else:
        icons = parse_xbm_array(content)

    if icons:
        show_gallery(icons)
    else:
        print("No icons found.")
