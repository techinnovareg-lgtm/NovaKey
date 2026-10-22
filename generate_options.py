import math
from PIL import Image, ImageDraw, ImageFilter

def generate_option_a(size=512):
    """Opción A: Bóveda Criptográfica Hexagonal (Cyber Vault)"""
    canvas_size = size * 4
    scale = canvas_size / 512.0
    img = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    cx, cy = canvas_size / 2.0, canvas_size / 2.0
    r_outer = 220 * scale

    # 1. Hexágono exterior (Bóveda acorazada)
    hex_pts = []
    for i in range(6):
        angle = math.radians(60 * i - 30)
        hex_pts.append((cx + r_outer * math.cos(angle), cy + r_outer * math.sin(angle)))

    draw.polygon(hex_pts, fill=(15, 23, 42, 255))
    draw.line(hex_pts + [hex_pts[0]], fill=(30, 58, 138, 255), width=int(12 * scale), joint="round")

    # 2. Hexágono interior con gradiente simulado
    r_mid = 185 * scale
    hex_mid = []
    for i in range(6):
        angle = math.radians(60 * i - 30)
        hex_mid.append((cx + r_mid * math.cos(angle), cy + r_mid * math.sin(angle)))
    draw.polygon(hex_mid, fill=(29, 78, 216, 255))

    # Facetas 3D de la bóveda (luz y sombra)
    draw.polygon([hex_mid[0], hex_mid[1], (cx, cy)], fill=(37, 99, 235, 255))
    draw.polygon([hex_mid[1], hex_mid[2], (cx, cy)], fill=(30, 64, 175, 255))
    draw.polygon([hex_mid[2], hex_mid[3], (cx, cy)], fill=(23, 37, 84, 255))
    draw.polygon([hex_mid[3], hex_mid[4], (cx, cy)], fill=(30, 58, 138, 255))
    draw.polygon([hex_mid[4], hex_mid[5], (cx, cy)], fill=(37, 99, 235, 255))
    draw.polygon([hex_mid[5], hex_mid[0], (cx, cy)], fill=(59, 130, 246, 255))

    # 3. Cerrojo circular central (Acero blanco & Cian)
    r_core = 85 * scale
    draw.ellipse([cx - r_core, cy - r_core, cx + r_core, cy + r_core], fill=(11, 17, 32, 255), outline=(56, 189, 248, 255), width=int(8 * scale))

    # Ojo de cerradura en blanco puro
    key_top_r = 26 * scale
    draw.ellipse([cx - key_top_r, cy - 35 * scale - key_top_r, cx + key_top_r, cy - 35 * scale + key_top_r], fill=(255, 255, 255, 255))
    slot_pts = [
        (cx - 14 * scale, cy - 25 * scale),
        (cx + 14 * scale, cy - 25 * scale),
        (cx + 20 * scale, cy + 35 * scale),
        (cx - 20 * scale, cy + 35 * scale),
    ]
    draw.polygon(slot_pts, fill=(255, 255, 255, 255))

    return img.resize((size, size), Image.Resampling.LANCZOS)

def generate_option_b(size=512):
    """Opción B: Escudo Heráldico de Seguridad con Llave Maestra de Alta Precisión (The Shield-Key Synergy)"""
    canvas_size = size * 4
    scale = canvas_size / 512.0
    img = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    cx = canvas_size / 2.0
    cy = canvas_size / 2.0

    # 1. Contenedor de Marca: Squircle Suave (#0B1120 Deep Slate)
    pad = 24 * scale
    r_corner = 96 * scale
    draw.rounded_rectangle([pad, pad, canvas_size - pad, canvas_size - pad], radius=r_corner, fill=(11, 17, 32, 255))
    draw.rounded_rectangle([pad, pad, canvas_size - pad, canvas_size - pad], radius=r_corner, outline=(30, 58, 138, 255), width=int(6 * scale))

    # 2. Escudo Heráldico Curvo Suave (Sin aristas quebradas)
    # Generamos curva suave usando puntos de Bezier/interpolados
    top_y = 80 * scale
    w_shield = 165 * scale
    mid_y = 230 * scale
    bottom_y = 435 * scale

    shield_pts = []
    # Borde superior (arco suave)
    steps = 20
    for i in range(steps + 1):
        t = i / float(steps)
        # De izquierda a derecha con curvatura sutil
        x = (cx - w_shield) + t * (2 * w_shield)
        # curva de catenaria invertida sutil
        y = top_y + 12 * scale * (1 - 4 * (t - 0.5)**2)
        shield_pts.append((x, y))

    # Borde lateral derecho (caída recta con redondeo)
    for i in range(steps + 1):
        t = i / float(steps)
        x = (cx + w_shield) - t * (w_shield * 0.08)
        y = top_y + 12 * scale + t * (mid_y - (top_y + 12 * scale))
        shield_pts.append((x, y))

    # Borde inferior derecho hacia la punta (curva elegante)
    for i in range(steps + 1):
        t = i / float(steps)
        # Bézier cúbica de (cx + w_shield * 0.92, mid_y) a (cx, bottom_y)
        # Control point: (cx + w_shield * 0.7, mid_y + 130 * scale)
        p0 = (cx + w_shield * 0.92, mid_y)
        p1 = (cx + w_shield * 0.65, mid_y + 120 * scale)
        p2 = (cx, bottom_y)
        bx = (1-t)**2 * p0[0] + 2*(1-t)*t * p1[0] + t**2 * p2[0]
        by = (1-t)**2 * p0[1] + 2*(1-t)*t * p1[1] + t**2 * p2[1]
        shield_pts.append((bx, by))

    # Borde inferior izquierdo desde la punta hacia arriba
    for i in range(steps + 1):
        t = i / float(steps)
        p0 = (cx, bottom_y)
        p1 = (cx - w_shield * 0.65, mid_y + 120 * scale)
        p2 = (cx - w_shield * 0.92, mid_y)
        bx = (1-t)**2 * p0[0] + 2*(1-t)*t * p1[0] + t**2 * p2[0]
        by = (1-t)**2 * p0[1] + 2*(1-t)*t * p1[1] + t**2 * p2[1]
        shield_pts.append((bx, by))

    # Lateral izquierdo
    for i in range(steps + 1):
        t = i / float(steps)
        x = (cx - w_shield * 0.92) - (1-t) * (w_shield * 0.08)
        y = mid_y - t * (mid_y - (top_y + 12 * scale))
        shield_pts.append((x, y))

    # Relleno del Escudo: Azul Royal Tecnológico (#2563EB)
    draw.polygon(shield_pts, fill=(37, 99, 235, 255))

    # Sombra media lateral derecha (elegancia geométrica sin ruido)
    half_clip = [(cx, top_y)]
    for pt in shield_pts:
        if pt[0] >= cx:
            half_clip.append(pt)
    half_clip.append((cx, bottom_y))
    
    half_overlay = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    half_draw = ImageDraw.Draw(half_overlay)
    half_draw.polygon(half_clip, fill=(0, 0, 0, 38))
    img = Image.alpha_composite(img, half_overlay)
    draw = ImageDraw.Draw(img)

    # Borde exterior del escudo: Azul Claro (#60A5FA)
    draw.line(shield_pts + [shield_pts[0]], fill=(96, 165, 250, 255), width=int(8 * scale), joint="round")

    # 3. Llave Maestra Central en Blanco Nieve (#FFFFFF) con Silueta Impecable
    # Cabeza de la llave (Anillo superior)
    key_y = 195 * scale
    r_key_outer = 56 * scale
    r_key_inner = 24 * scale

    draw.ellipse([cx - r_key_outer, key_y - r_key_outer, cx + r_key_outer, key_y + r_key_outer], fill=(255, 255, 255, 255))
    draw.ellipse([cx - r_key_inner, key_y - r_key_inner, cx + r_key_inner, key_y + r_key_inner], fill=(30, 58, 138, 255))

    # Vástago de la llave (Stem)
    stem_w = 16 * scale
    stem_bottom = 365 * scale
    draw.rounded_rectangle([cx - stem_w, key_y + r_key_outer - 6 * scale, cx + stem_w, stem_bottom], radius=5 * scale, fill=(255, 255, 255, 255))

    # Dientes de seguridad modernos (Right side)
    # Diente 1 (Inferior)
    t1_y = stem_bottom - 28 * scale
    t1_w = 40 * scale
    t1_h = 22 * scale
    draw.rounded_rectangle([cx + stem_w - 4 * scale, t1_y, cx + stem_w + t1_w, t1_y + t1_h], radius=4 * scale, fill=(255, 255, 255, 255))

    # Diente 2 (Medio)
    t2_y = t1_y - 34 * scale
    t2_w = 26 * scale
    t2_h = 18 * scale
    draw.rounded_rectangle([cx + stem_w - 4 * scale, t2_y, cx + stem_w + t2_w, t2_y + t2_h], radius=4 * scale, fill=(255, 255, 255, 255))

    # Detalle Nova (Estrella de 4 puntas en el centro del ojo, color Cian Eléctrico #38BDF8)
    star_r = 13 * scale
    star_in = 4 * scale
    star_pts = []
    for i in range(8):
        ang = i * math.pi / 4.0
        r_now = star_r if i % 2 == 0 else star_in
        star_pts.append((cx + r_now * math.cos(ang), key_y + r_now * math.sin(ang)))
    draw.polygon(star_pts, fill=(56, 189, 248, 255))

    return img.resize((size, size), Image.Resampling.LANCZOS)

def generate_option_c(size=512):
    """Opción C: Candado de Alta Seguridad con Estrella Nova (Cyber Padlock)"""
    canvas_size = size * 4
    scale = canvas_size / 512.0
    img = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    cx = canvas_size / 2.0
    cy = canvas_size / 2.0

    # 1. Contenedor Squircle
    pad = 24 * scale
    r_corner = 96 * scale
    draw.rounded_rectangle([pad, pad, canvas_size - pad, canvas_size - pad], radius=r_corner, fill=(11, 17, 32, 255))
    draw.rounded_rectangle([pad, pad, canvas_size - pad, canvas_size - pad], radius=r_corner, outline=(30, 58, 138, 255), width=int(6 * scale))

    # 2. Grillete / Arco del Candado (Shackle de Acero Titanio)
    shackle_w = 190 * scale
    shackle_h = 160 * scale
    shackle_top = 80 * scale
    shackle_thickness = 34 * scale

    draw.arc(
        [cx - shackle_w / 2, shackle_top, cx + shackle_w / 2, shackle_top + shackle_h],
        start=180, end=0,
        fill=(148, 163, 184, 255),
        width=int(shackle_thickness)
    )
    # Piernas del grillete
    draw.rectangle([cx - shackle_w / 2, shackle_top + shackle_h / 2, cx - shackle_w / 2 + shackle_thickness, 220 * scale], fill=(148, 163, 184, 255))
    draw.rectangle([cx + shackle_w / 2 - shackle_thickness, shackle_top + shackle_h / 2, cx + shackle_w / 2, 220 * scale], fill=(148, 163, 184, 255))

    # 3. Cuerpo del Candado (Azul Royal Acorazado)
    body_top = 200 * scale
    body_bottom = 430 * scale
    body_w = 260 * scale
    draw.rounded_rectangle(
        [cx - body_w / 2, body_top, cx + body_w / 2, body_bottom],
        radius=28 * scale,
        fill=(29, 78, 216, 255),
        outline=(59, 130, 246, 255),
        width=int(8 * scale)
    )

    # 4. Ojo de Cerradura Nova (Blanco puro + Estrella)
    keyhole_y = 305 * scale
    draw.ellipse([cx - 30 * scale, keyhole_y - 30 * scale, cx + 30 * scale, keyhole_y + 30 * scale], fill=(255, 255, 255, 255))
    slot_pts = [
        (cx - 16 * scale, keyhole_y),
        (cx + 16 * scale, keyhole_y),
        (cx + 24 * scale, keyhole_y + 55 * scale),
        (cx - 24 * scale, keyhole_y + 55 * scale),
    ]
    draw.polygon(slot_pts, fill=(255, 255, 255, 255))

    # Estrella Nova en el centro del ojo
    star_r = 14 * scale
    star_in = 4.5 * scale
    star_pts = []
    for i in range(8):
        ang = i * math.pi / 4.0
        r_now = star_r if i % 2 == 0 else star_in
        star_pts.append((cx + r_now * math.cos(ang), keyhole_y + r_now * math.sin(ang)))
    draw.polygon(star_pts, fill=(56, 189, 248, 255))

    return img.resize((size, size), Image.Resampling.LANCZOS)

if __name__ == "__main__":
    opt_a = generate_option_a(512)
    opt_a.save("option_a_cyber_vault.png")

    opt_b = generate_option_b(512)
    opt_b.save("option_b_shield_key.png")

    opt_c = generate_option_c(512)
    opt_c.save("option_c_cyber_padlock.png")

    # Generar muestras en tamaño favicon 32x32 para prueba de legibilidad micro
    opt_a.resize((32, 32), Image.Resampling.LANCZOS).save("option_a_favicon32.png")
    opt_b.resize((32, 32), Image.Resampling.LANCZOS).save("option_b_favicon32.png")
    opt_c.resize((32, 32), Image.Resampling.LANCZOS).save("option_c_favicon32.png")

    print("All 3 options and their favicon previews generated successfully.")
