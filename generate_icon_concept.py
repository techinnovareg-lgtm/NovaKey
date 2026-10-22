import math
from PIL import Image, ImageDraw

def create_novakey_icon(size=512):
    # Generar a 4x (2048x2048) con supersampling para bordes ultra nítidos
    canvas_size = size * 4
    scale = canvas_size / 512.0
    
    img = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # 1. Fondo: Squircle moderno con gradiente radial sutil de seguridad
    # Margen exterior de seguridad (padding 28px en escala 512)
    pad = 28 * scale
    x0, y0 = pad, pad
    x1, y1 = canvas_size - pad, canvas_size - pad
    corner_radius = 100 * scale
    
    # Dibujar base del contenedor redondeado (Deep Slate Navy #0B1120)
    draw.rounded_rectangle([x0, y0, x1, y1], radius=corner_radius, fill=(11, 17, 32, 255))
    
    # Borde exterior de precisión (Royal Blue #1E3A8A)
    border_w = int(7 * scale)
    draw.rounded_rectangle([x0, y0, x1, y1], radius=corner_radius, outline=(30, 58, 138, 255), width=border_w)
    
    # Borde de luz superior interno sutil (Cyan Tech highlight #38BDF8 con opacidad)
    inner_pad = pad + border_w
    inner_radius = max(1, corner_radius - border_w)
    draw.rounded_rectangle(
        [inner_pad, inner_pad, canvas_size - inner_pad, canvas_size - inner_pad],
        radius=inner_radius,
        outline=(56, 189, 248, 40),
        width=int(2 * scale)
    )

    # 2. El Escudo Central (Proporciones Áureas: Ancho = 260px, Alto = 310px en escala 512)
    # Centro óptico (X=256, Y=258 con compensación óptica vertical)
    cx = 256 * scale
    top_y = 105 * scale
    shoulder_y = 185 * scale
    bottom_y = 415 * scale
    half_w = 135 * scale
    
    # Puntos del escudo geométrico
    # Vértice superior curvado / estilizado
    shield_pts = [
        (cx, top_y + 10 * scale),               # Centro superior con sutil declive
        (cx + half_w * 0.5, top_y),            # Cresta superior derecha
        (cx + half_w, top_y + 15 * scale),     # Hombro superior derecho
        (cx + half_w, shoulder_y),             # Hombro lateral derecho
        (cx + half_w * 0.75, shoulder_y + 90 * scale),
        (cx, bottom_y),                        # Punta inferior del escudo
        (cx - half_w * 0.75, shoulder_y + 90 * scale),
        (cx - half_w, shoulder_y),             # Hombro lateral izquierdo
        (cx - half_w, top_y + 15 * scale),     # Hombro superior izquierdo
        (cx - half_w * 0.5, top_y),            # Cresta superior izquierda
    ]
    
    # Relleno del Escudo: Azul Royal Intenso (#1D4ED8 / #2563EB)
    draw.polygon(shield_pts, fill=(29, 78, 216, 255))
    
    # Borde del escudo: Azul Eléctrico (#3B82F6)
    draw.line(shield_pts + [shield_pts[0]], fill=(59, 130, 246, 255), width=int(8 * scale), joint="round")
    
    # Faceta derecha de volumen sutil (sombra angular 50% para dar tridimensionalidad tecnológica limpia)
    right_facet = [
        (cx, top_y + 10 * scale),
        (cx + half_w * 0.5, top_y),
        (cx + half_w, top_y + 15 * scale),
        (cx + half_w, shoulder_y),
        (cx + half_w * 0.75, shoulder_y + 90 * scale),
        (cx, bottom_y),
    ]
    # Sombra derecha elegante
    facet_overlay = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    facet_draw = ImageDraw.Draw(facet_overlay)
    facet_draw.polygon(right_facet, fill=(0, 0, 0, 35))
    img = Image.alpha_composite(img, facet_overlay)
    draw = ImageDraw.Draw(img)

    # 3. La Llave Maestra Central (Blanco Puro #FFFFFF con alto contraste y proporciones doradas)
    # Cabeza de la llave (Anillo superior)
    key_center_y = 200 * scale
    outer_r = 48 * scale
    inner_r = 22 * scale
    
    # Anillo exterior blanco
    draw.ellipse(
        [cx - outer_r, key_center_y - outer_r, cx + outer_r, key_center_y + outer_r],
        fill=(255, 255, 255, 255)
    )
    
    # Ojo de cerradura / perforación del anillo (Azul Royal oscuro del escudo #172554)
    draw.ellipse(
        [cx - inner_r, key_center_y - inner_r, cx + inner_r, key_center_y + inner_r],
        fill=(23, 37, 84, 255)
    )
    
    # Vástago de la Llave (Shaft vertical)
    stem_top = key_center_y + outer_r * 0.6
    stem_bottom = 355 * scale
    stem_w = 14 * scale
    
    draw.rounded_rectangle(
        [cx - stem_w, stem_top, cx + stem_w, stem_bottom],
        radius=4 * scale,
        fill=(255, 255, 255, 255)
    )
    
    # Dientes de la Llave (Bits de seguridad con proporciones asimétricas de precisión técnica)
    # Diente inferior principal (hacia la derecha)
    tooth1_y = stem_bottom - 24 * scale
    tooth1_h = 18 * scale
    tooth1_w = 34 * scale
    draw.rounded_rectangle(
        [cx + stem_w - 2 * scale, tooth1_y, cx + stem_w + tooth1_w, tooth1_y + tooth1_h],
        radius=3 * scale,
        fill=(255, 255, 255, 255)
    )
    
    # Diente secundario intermedio (hacia la derecha)
    tooth2_y = tooth1_y - 28 * scale
    tooth2_h = 15 * scale
    tooth2_w = 22 * scale
    draw.rounded_rectangle(
        [cx + stem_w - 2 * scale, tooth2_y, cx + stem_w + tooth2_w, tooth2_y + tooth2_h],
        radius=3 * scale,
        fill=(255, 255, 255, 255)
    )

    # 4. Detalle "Nova" de Seguridad: Pequeña estrella de 4 puntas en el centro del ojo (Cian Neón sutil #38BDF8)
    star_r = 11 * scale
    star_inner = 3.5 * scale
    star_pts = []
    for i in range(8):
        angle = i * math.pi / 4.0
        r_current = star_r if i % 2 == 0 else star_inner
        star_pts.append((cx + r_current * math.cos(angle), key_center_y + r_current * math.sin(angle)))
    draw.polygon(star_pts, fill=(56, 189, 248, 255))
    
    # Redimensionar con filtro Lanczos para calidad ultra suave y definida
    final_img = img.resize((size, size), Image.Resampling.LANCZOS)
    return final_img

if __name__ == "__main__":
    icon512 = create_novakey_icon(512)
    icon512.save("novakey_concept_b.png", "PNG")
    print("Concept B icon generated successfully.")
