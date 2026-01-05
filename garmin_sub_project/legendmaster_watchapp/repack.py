from PIL import Image

# --- НАСТРОЙКИ ---
input_file = "legend_font.png"
output_png = "legend_font_new.png"
output_fnt = "legend_font_new.fnt"

tile_size = 38
cols_input = 19    # Твоя текущая ширина в иконках
cols_output = 6    # Новая ширина (228 px) - идеально для Fenix 3
total_to_keep = 180 # Оставляем 180 иконок (удаляем 10 последних)

def repack():
    img = Image.open(input_file).convert("RGB")
    
    # 1. Нарезаем иконки (идем по старой сетке 19x10)
    all_tiles = []
    for y in range(0, img.height, tile_size):
        for x in range(0, img.width, tile_size):
            if len(all_tiles) < total_to_keep:
                tile = img.crop((x, y, x + tile_size, y + tile_size))
                all_tiles.append(tile)

    # 2. Новое полотно
    rows_output = len(all_tiles) // cols_output
    new_width = cols_output * tile_size # 228 px
    new_height = rows_output * tile_size # 1140 px
    new_img = Image.new("RGB", (new_width, new_height), (0, 0, 0))

    # 3. Генерация FNT и сборка
    fnt_lines = [
        'info face="LegendFont" size=38 bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=0 padding=0,0,0,0 spacing=0,0 outline=0',
        f'common lineHeight=38 base=30 scaleW={new_width} scaleH={new_height} pages=1 packed=0 alphaChnl=0 redChnl=4 greenChnl=4 blueChnl=4',
        f'page id=0 file="{output_png}"',
        f'chars count={len(all_tiles)}'
    ]

    start_id = 57345 # 0xE001
    for i, tile in enumerate(all_tiles):
        out_x = (i % cols_output) * tile_size
        out_y = (i // cols_output) * tile_size
        new_img.paste(tile, (out_x, out_y))
        fnt_lines.append(f'char id={start_id + i} x={out_x} y={out_y} width=38 height=38 xoffset=0 yoffset=0 xadvance=38 page=0 chnl=0')

    # 4. Сохранение (PNG-8, 4 цвета для экономии RAM)
    new_img = new_img.convert("P", palette=Image.ADAPTIVE, colors=4)
    new_img.save(output_png)
    
    with open(output_fnt, "w") as f:
        f.write("\n".join(fnt_lines))

    print(f"Готово! Оставлено 180 иконок. Размер: {new_width}x{new_height}px.")

if __name__ == "__main__":
    repack()