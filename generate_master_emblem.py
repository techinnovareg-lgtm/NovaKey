import math
from PIL import Image, ImageDraw

def generate_perfect_shield_key(size=512):
    # Render at 4x (2048x2048) for supersampled, flawless anti-aliasing
    canvas_size = size * 4
    scale = canvas_size / 512.0
    
    img = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    cx = canvas_size / 2.0
    cy = canvas_size / 2.0
    
    # 1. Base Squircle (Deep Navy Slate #0A0F1D)
    pad = 20 * scale
    r_corner = 110 * scale
    draw.rounded_rectangle(
        [pad, pad, canvas_size - pad, canvas_size - pad],
        radius=r_corner,
        fill=(10, 15, 29, 255)
    )
    # Borde sutil exterior (Slate Blue #1E293B)
    draw.rounded_rectangle(
        [pad, pad, canvas_size - pad, canvas_size - pad],
        radius=r_corner,
        outline=(30, 41, 59, 255),
        width=int(6 * scale)
    )

    # 2. Escudo de Seguridad con Simetría Bilateral Perfecta (Matemáticamente idéntico en ambos lados)
    # Dimensiones ópticas: Ancho máximo = 330px, Alto = 370px
    top_y = 70 * scale
    shoulder_y = 175 * scale
    bottom_y = 442 * scale
    max_half_w = 165 * scale
    
    # Generar puntos del lado derecho
    right_points = []
    
    # Curva superior desde el centro hacia el hombro derecho
    steps = 30
    for i in range(steps + 1):
        t = i / float(steps)
        # sutil curva en la parte superior: desde x=0 hasta x=max_half_w
        x = cx + t * max_half_w
        # curvatura sutil (arco suave)
        y = top_y + (12 * scale) * (1.0 - math.cos(t * math.pi / 2.0))
        right_points.append((x, y))
        
    # Caída vertical suave hasta el hombro
    right_points.append((cx + max_half_w, shoulder_y))
    
    # Curva convexa Bézier desde el hombro hasta el vértice inferior
    p0 = (cx + max_half_w, shoulder_y)
    p1 = (cx + max_half_w * 0.82, shoulder_y + 160 * scale)
    p2 = (cx, bottom_y)
    
    for i in range(1, steps + 1):
        t = i / float(steps)
        bx = (1-t)**2 * p0[0] + 2*(1-t)*t * p1[0] + t**2 * p2[0]
        by = (1-t)**2 * p0[1] + 2*(1-t)*t * p1[1] + t**2 * p2[1]
        right_points.append((bx, by))
        
    # Construir el polígono completo por simetría exacta
    left_points = []
    # Invertir puntos derechos (excepto el primero y el último que son x=cx)
    for pt in reversed(right_points):
        lx = cx - (pt[0] - cx)
        left_points.append((lx, pt[1]))
        
    # Escudo completo cerrado
    shield_pts = right_points + left_points[1:-1]
    
    # Relleno del Escudo: Azul Royal Intenso (#1D4ED8)
    draw.polygon(shield_pts, fill=(29, 78, 216, 255))
    
    # Sombra sutil en la mitad derecha (Efecto facetado tecnológico 50% limpio)
    half_right_pts = [(cx, top_y)] + right_points
    half_overlay = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    half_draw = ImageDraw.Draw(half_overlay)
    half_draw.polygon(half_right_pts, fill=(0, 0, 0, 42))
    img = Image.alpha_composite(img, half_overlay)
    draw = ImageDraw.Draw(img)
    
    # Borde de luz perimetral del escudo: Azul Eléctrico (#3B82F6)
    draw.line(shield_pts + [shield_pts[0]], fill=(59, 130, 246, 255), width=int(10 * scale), joint="round")
    
    # 3. La Llave Maestra (Blanco Puro #FFFFFF - Ópticamente Centrada)
    # Centro de la cabeza de la llave
    key_y = 195 * scale
    r_outer = 56 * scale
    r_inner = 24 * scale
    
    # Cabeza de la llave (Anillo exterior)
    draw.ellipse(
        [cx - r_outer, key_y - r_outer, cx + r_outer, key_y + r_outer],
        fill=(255, 255, 255, 255)
    )
    # Ojo de cerradura (Perforación interna en Azul Oscuro #0F172A)
    draw.ellipse(
        [cx - r_inner, key_y - r_inner, cx + r_inner, key_y + r_inner],
        fill=(15, 23, 42, 255)
    )
    
    # Vástago de la llave (Stem)
    stem_w = 17 * scale
    stem_top = key_y + r_outer - 6 * scale
    stem_bottom = 370 * scale
    draw.rounded_rectangle(
        [cx - stem_w, stem_top, cx + stem_w, stem_bottom],
        radius=5 * scale,
        fill=(255, 255, 255, 255)
    )
    
    # Dientes de la llave (Bits de precisión tecnológica en el lado derecho)
    # Diente inferior principal
    t1_y = stem_bottom - 32 * scale
    t1_h = 24 * scale
    t1_w = 44 * scale
    draw.rounded_rectangle(
        [cx + stem_w - 4 * scale, t1_y, cx + stem_w + t1_w, t1_y + t1_h],
        radius=5 * scale,
        fill=(255, 255, 255, 255)
    )
    
    # Diente superior secundario
    t2_y = t1_y - 38 * scale
    t2_h = 20 * scale
    t2_w = 28 * scale
    draw.rounded_rectangle(
        [cx + stem_w - 4 * scale, t2_y, cx + stem_w + t2_w, t2_y + t2_h],
        radius=4 * scale,
        fill=(255, 255, 255, 255)
    )
    
    # 4. Detalle "Nova": Estrella de 4 puntas en el centro del ojo (Cian Neón Puro #38BDF8)
    star_r = 13.5 * scale
    star_in = 4.2 * scale
    star_pts = []
    for i in range(8):
        ang = i * math.pi / 4.0
        r_now = star_r if i % 2 == 0 else star_in
        star_pts.append((cx + r_now * math.cos(ang), key_y + r_now * math.sin(ang)))
    draw.polygon(star_pts, fill=(56, 189, 248, 255))
    
    # Reducción de escala de ultra alta fidelidad (Lanczos)
    return img.resize((size, size), Image.Resampling.LANCZOS)

if __name__ == "__main__":
    master_icon = generate_perfect_shield_key(512)
    master_icon.save("novakey_master_emblem.png", "PNG")
    master_icon.resize((32, 32), Image.Resampling.LANCZOS).save("novakey_master_fav32.png", "PNG")
    master_icon.resize((16, 16), Image.Resampling.LANCZOS).save("novakey_master_fav16.png", "PNG")
    print("Master emblem and favicon benchmarks generated.")
