import math
from PIL import Image, ImageDraw

def draw_smooth_shield(draw, cx, top_y, w_half, h_total, fill_color, outline_color=None, outline_w=0):
    """
    Dibuja un escudo con arcos continuos de alta precisión y sin esquinas quebradas.
    cx: centro horizontal
    top_y: inicio superior
    w_half: mitad del ancho en hombros
    h_total: altura total del escudo
    """
    bottom_y = top_y + h_total
    shoulder_y = top_y + h_total * 0.32
    
    # Puntos paramétricos suaves
    steps = 40
    right_pts = []
    
    # 1. Curva superior: arco suave desde el centro hacia el hombro derecho
    for i in range(steps + 1):
        t = i / float(steps)
        x = cx + t * w_half
        # Arco suave con caída de 14px hacia los hombros
        y = top_y + 14 * (t ** 2)
        right_pts.append((x, y))
        
    # 2. Curva lateral convexa continua desde el hombro derecho hacia el vértice inferior
    p0 = (cx + w_half, top_y + 14)
    # Puntos de control Bézier para caída elegante y firme
    p1 = (cx + w_half * 0.96, shoulder_y + h_total * 0.28)
    p2 = (cx, bottom_y)
    
    for i in range(1, steps + 1):
        t = i / float(steps)
        bx = (1-t)**2 * p0[0] + 2*(1-t)*t * p1[0] + t**2 * p2[0]
        by = (1-t)**2 * p0[1] + 2*(1-t)*t * p1[1] + t**2 * p2[1]
        right_pts.append((bx, by))
        
    # 3. Puntos izquierdos por simetría bilateral matemática exacta
    left_pts = []
    for pt in reversed(right_pts):
        lx = cx - (pt[0] - cx)
        left_pts.append((lx, pt[1]))
        
    full_shield = right_pts + left_pts[1:-1]
    
    # Dibujar relleno
    draw.polygon(full_shield, fill=fill_color)
    
    if outline_color and outline_w > 0:
        draw.line(full_shield + [full_shield[0]], fill=outline_color, width=outline_w, joint="round")
        
    return full_shield, right_pts

def generate_master_shield_key(size=512):
    canvas_size = size * 4
    scale = canvas_size / 512.0
    
    img = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    cx = canvas_size / 2.0
    cy = canvas_size / 2.0
    
    # 1. Contenedor Squircle Deep Navy (#080D1A)
    pad = 22 * scale
    r_corner = 112 * scale
    draw.rounded_rectangle(
        [pad, pad, canvas_size - pad, canvas_size - pad],
        radius=r_corner,
        fill=(8, 13, 26, 255)
    )
    # Borde exterior de titanio azul (#1E293B)
    draw.rounded_rectangle(
        [pad, pad, canvas_size - pad, canvas_size - pad],
        radius=r_corner,
        outline=(30, 41, 59, 255),
        width=int(6 * scale)
    )
    
    # 2. Escudo Heráldico Curvo
    top_y = 65 * scale
    w_half = 175 * scale
    h_total = 380 * scale
    
    # Dibujar escudo base
    shield_pts, right_pts = draw_smooth_shield(
        draw=draw,
        cx=cx,
        top_y=top_y,
        w_half=w_half,
        h_total=h_total,
        fill_color=(29, 78, 216, 255), # Azul Royal #1D4ED8
        outline_color=(59, 130, 246, 255), # Azul Eléctrico #3B82F6
        outline_w=int(10 * scale)
    )
    
    # Sombra derecha facetada 50%
    half_overlay = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    half_draw = ImageDraw.Draw(half_overlay)
    half_right_pts = [(cx, top_y)] + right_pts
    half_draw.polygon(half_right_pts, fill=(0, 0, 0, 40))
    img = Image.alpha_composite(img, half_overlay)
    draw = ImageDraw.Draw(img)
    
    # 3. Llave Maestra (Blanco Nieve #FFFFFF con Ojo Centrado)
    key_center_y = 195 * scale
    r_outer = 58 * scale
    r_inner = 25 * scale
    
    # Cabeza anular exterior
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
    stem_w = 18 * scale
    stem_bottom = 372 * scale
    draw.rounded_rectangle(
        [cx - stem_w, key_center_y + r_outer - 8 * scale, cx + stem_w, stem_bottom],
        radius=5 * scale,
        fill=(255, 255, 255, 255)
    )
    
    # Dientes de seguridad modernos (Right side)
    # Diente 1 (Inferior largo)
    t1_y = stem_bottom - 32 * scale
    t1_h = 24 * scale
    t1_w = 46 * scale
    draw.rounded_rectangle(
        [cx + stem_w - 4 * scale, t1_y, cx + stem_w + t1_w, t1_y + t1_h],
        radius=5 * scale,
        fill=(255, 255, 255, 255)
    )
    
    # Diente 2 (Superior intermedio)
    t2_y = t1_y - 38 * scale
    t2_h = 20 * scale
    t2_w = 30 * scale
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

def generate_micro_favicon(size=32):
    """
    Favicon optimizado a micro-escala (16x16, 32x32, 64x64).
    Aprovecha el 100% del lienzo para que el escudo y la llave sean gigantes,
    nítidos y legibles en cualquier pestaña de navegador sin bordes residuales.
    """
    canvas_size = 256
    scale = canvas_size / 32.0
    
    img = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    cx = canvas_size / 2.0
    
    # Escudo a pantalla completa (Full Canvas Shield)
    top_y = 6 * scale
    w_half = 14.5 * scale
    h_total = 25 * scale
    
    shield_pts, right_pts = draw_smooth_shield(
        draw=draw,
        cx=cx,
        top_y=top_y,
        w_half=w_half,
        h_total=h_total,
        fill_color=(29, 78, 216, 255),
        outline_color=(96, 165, 250, 255),
        outline_w=int(1.8 * scale)
    )
    
    # Sombra derecha facetada
    half_overlay = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    half_draw = ImageDraw.Draw(half_overlay)
    half_right_pts = [(cx, top_y)] + right_pts
    half_draw.polygon(half_right_pts, fill=(0, 0, 0, 45))
    img = Image.alpha_composite(img, half_overlay)
    draw = ImageDraw.Draw(img)
    
    # Llave central blanca ultra contrastada
    key_y = 14 * scale
    r_outer = 4.6 * scale
    r_inner = 1.8 * scale
    
    draw.ellipse([cx - r_outer, key_y - r_outer, cx + r_outer, key_y + r_outer], fill=(255, 255, 255, 255))
    draw.ellipse([cx - r_inner, key_y - r_inner, cx + r_inner, key_y + r_inner], fill=(15, 23, 42, 255))
    
    stem_w = 1.6 * scale
    stem_bottom = 25.5 * scale
    draw.rectangle([cx - stem_w, key_y + r_outer - 1 * scale, cx + stem_w, stem_bottom], fill=(255, 255, 255, 255))
    
    # Dientes gruesos visibles a 16px
    t1_y = stem_bottom - 2.8 * scale
    draw.rectangle([cx + stem_w - 0.5 * scale, t1_y, cx + stem_w + 3.8 * scale, stem_bottom], fill=(255, 255, 255, 255))
    
    t2_y = t1_y - 3.4 * scale
    draw.rectangle([cx + stem_w - 0.5 * scale, t2_y, cx + stem_w + 2.5 * scale, t2_y + 2.0 * scale], fill=(255, 255, 255, 255))
    
    return img.resize((size, size), Image.Resampling.LANCZOS)

if __name__ == "__main__":
    emblem = generate_master_shield_key(512)
    emblem.save("novakey_perfect_emblem.png")
    
    fav32 = generate_micro_favicon(32)
    fav32.save("novakey_micro_fav32.png")
    
    fav64 = generate_micro_favicon(64)
    fav64.save("novakey_micro_fav64.png")
    
    print("Perfect emblem and micro-favicons successfully generated.")
