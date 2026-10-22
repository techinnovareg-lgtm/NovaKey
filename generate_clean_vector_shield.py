import math
from PIL import Image, ImageDraw

def generate_clean_vector_shield(size=512):
    canvas_size = size * 4
    scale = canvas_size / 512.0
    
    img = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    cx = canvas_size / 2.0
    cy = canvas_size / 2.0
    
    # 1. Base Squircle (Deep Charcoal Navy #0A0F1D)
    pad = 20 * scale
    r_corner = 110 * scale
    draw.rounded_rectangle(
        [pad, pad, canvas_size - pad, canvas_size - pad],
        radius=r_corner,
        fill=(10, 15, 29, 255)
    )
    # Borde exterior de precisión fina (#1E293B)
    draw.rounded_rectangle(
        [pad, pad, canvas_size - pad, canvas_size - pad],
        radius=r_corner,
        outline=(30, 41, 59, 255),
        width=int(4 * scale)
    )
    
    # 2. Escudo Proporcionado (Geometría Continua de Escudo Suizo Moderno)
    top_y = 65 * scale
    w_half = 175 * scale
    h_total = 385 * scale
    bottom_y = top_y + h_total
    
    # Generar puntos de alta densidad para curvas sedosas
    steps = 60
    right_pts = []
    
    # Curva superior: leve arco cóncavo moderno (de centro a hombro derecho)
    for i in range(steps + 1):
        t = i / float(steps)
        x = cx + t * w_half
        # Arco sutil
        y = top_y + 16 * scale * (t ** 1.8)
        right_pts.append((x, y))
        
    # Curva lateral: desde el hombro hasta el vértice inferior con curvatura áurea
    p0 = right_pts[-1]
    p1 = (cx + w_half * 0.95, top_y + h_total * 0.55)
    p2 = (cx, bottom_y)
    
    for i in range(1, steps + 1):
        t = i / float(steps)
        bx = (1-t)**2 * p0[0] + 2*(1-t)*t * p1[0] + t**2 * p2[0]
        by = (1-t)**2 * p0[1] + 2*(1-t)*t * p1[1] + t**2 * p2[1]
        right_pts.append((bx, by))
        
    left_pts = []
    for pt in reversed(right_pts):
        lx = cx - (pt[0] - cx)
        left_pts.append((lx, pt[1]))
        
    full_shield = right_pts + left_pts[1:-1]
    
    # Escudo exterior de borde sutil (#3B82F6 con 4px de grosor)
    # Dibujar escudo base en Azul Eléctrico
    draw.polygon(full_shield, fill=(59, 130, 246, 255))
    
    # Escudo interior en Azul Royal (#1D4ED8) ligeramente encogido para crear un bisel perfecto
    inner_right = []
    scale_down = 0.965
    for pt in right_pts:
        ix = cx + (pt[0] - cx) * scale_down
        iy = (cy + 10 * scale) + (pt[1] - (cy + 10 * scale)) * scale_down
        inner_right.append((ix, iy))
    inner_left = []
    for pt in reversed(inner_right):
        lx = cx - (pt[0] - cx)
        inner_left.append((lx, pt[1]))
    inner_shield = inner_right + inner_left[1:-1]
    draw.polygon(inner_shield, fill=(29, 78, 216, 255))
    
    # Sombra derecha geométrica limpia (división vertical en el eje Y)
    half_overlay = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    half_draw = ImageDraw.Draw(half_overlay)
    half_right_pts = [(cx, top_y)] + right_pts + [(cx, bottom_y)]
    half_draw.polygon(half_right_pts, fill=(0, 0, 0, 40))
    img = Image.alpha_composite(img, half_overlay)
    draw = ImageDraw.Draw(img)
    
    # 3. La Llave Maestra (Blanco Puro #FFFFFF con Proporción Áurea)
    key_center_y = 200 * scale
    r_outer = 60 * scale
    r_inner = 26 * scale
    
    # Cabeza de la llave
    draw.ellipse(
        [cx - r_outer, key_center_y - r_outer, cx + r_outer, key_center_y + r_outer],
        fill=(255, 255, 255, 255)
    )
    # Ojo de cerradura
    draw.ellipse(
        [cx - r_inner, key_center_y - r_inner, cx + r_inner, key_center_y + r_inner],
        fill=(15, 23, 42, 255)
    )
    
    # Vástago de la llave (Stem)
    stem_w = 19 * scale
    stem_bottom = 375 * scale
    draw.rounded_rectangle(
        [cx - stem_w, key_center_y + r_outer - 10 * scale, cx + stem_w, stem_bottom],
        radius=6 * scale,
        fill=(255, 255, 255, 255)
    )
    
    # Dientes de seguridad modernos (Right side)
    # Diente 1 (Inferior largo)
    t1_y = stem_bottom - 34 * scale
    t1_h = 24 * scale
    t1_w = 48 * scale
    draw.rounded_rectangle(
        [cx + stem_w - 4 * scale, t1_y, cx + stem_w + t1_w, t1_y + t1_h],
        radius=5 * scale,
        fill=(255, 255, 255, 255)
    )
    
    # Diente 2 (Superior intermedio)
    t2_y = t1_y - 40 * scale
    t2_h = 20 * scale
    t2_w = 32 * scale
    draw.rounded_rectangle(
        [cx + stem_w - 4 * scale, t2_y, cx + stem_w + t2_w, t2_y + t2_h],
        radius=4 * scale,
        fill=(255, 255, 255, 255)
    )
    
    # 4. Detalle Nova: Estrella de 4 puntas en el centro del ojo (Cian Eléctrico #38BDF8)
    star_r = 14 * scale
    star_in = 4.5 * scale
    star_pts = []
    for i in range(8):
        ang = i * math.pi / 4.0
        r_now = star_r if i % 2 == 0 else star_in
        star_pts.append((cx + r_now * math.cos(ang), key_center_y + r_now * math.sin(ang)))
    draw.polygon(star_pts, fill=(56, 189, 248, 255))
    
    return img.resize((size, size), Image.Resampling.LANCZOS)

if __name__ == "__main__":
    icon = generate_clean_vector_shield(512)
    icon.save("novakey_vector_shield.png")
    print("Vector shield generated.")
