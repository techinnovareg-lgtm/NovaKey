import math
from PIL import Image, ImageDraw, ImageFont

# Import our generators from earlier
from generate_options import generate_option_a, generate_option_c
from generate_clean_vector_shield import generate_clean_vector_shield
from generate_refined_suite import generate_micro_favicon

def build_showcase():
    w, h = 1200, 680
    canvas = Image.new("RGBA", (w, h), (11, 15, 25, 255))
    draw = ImageDraw.Draw(canvas)
    
    # Header bar
    draw.rectangle([0, 0, w, 90], fill=(15, 23, 42, 255))
    draw.line([(0, 90), (w, 90)], fill=(30, 41, 59, 255), width=2)
    
    # Header Title
    # Use default bitmap font or draw text
    # Let's draw clean text
    # In PIL default font is fine, or we can draw custom banners
    
    # 3 columns for Options A, B, C
    col_w = 340
    gap = 40
    start_x = 40
    
    # Generate high-res 512 images
    opt_a = generate_option_a(512).resize((240, 240), Image.Resampling.LANCZOS)
    opt_b = generate_clean_vector_shield(512).resize((240, 240), Image.Resampling.LANCZOS)
    opt_c = generate_option_c(512).resize((240, 240), Image.Resampling.LANCZOS)
    
    # Favicon tests (scaled up 3x for display: 32x32 -> 96x96 with nearest for crisp pixels or Lanczos)
    fav_a = generate_option_a(32).resize((80, 80), Image.Resampling.NEAREST)
    fav_b = generate_micro_favicon(32).resize((80, 80), Image.Resampling.NEAREST)
    fav_c = generate_option_c(32).resize((80, 80), Image.Resampling.NEAREST)
    
    cards = [
        ("OPCIÓN A: BÓVEDA ACORAZADA", "Enfoque: Criptografía & Bóveda Fría", opt_a, fav_a, False, (56, 189, 248)),
        ("OPCIÓN B: ESCUDO & LLAVE MAESTRA", "Enfoque: Protección & Acceso Total [SELECCIONADA]", opt_b, fav_b, True, (37, 99, 235)),
        ("OPCIÓN C: CANDADO CYBER-NOVA", "Enfoque: Bloqueo Tradicional & Clave", opt_c, fav_c, False, (148, 163, 184)),
    ]
    
    for idx, (title, subtitle, img_512, img_fav, is_winner, accent_color) in enumerate(cards):
        col_x = start_x + idx * (col_w + gap)
        card_rect = [col_x, 110, col_x + col_w, h - 30]
        
        bg_card = (19, 26, 43, 255) if not is_winner else (20, 35, 68, 255)
        border_card = (37, 99, 235, 255) if is_winner else (30, 41, 59, 255)
        
        draw.rounded_rectangle(card_rect, radius=16, fill=bg_card, outline=border_card, width=3 if is_winner else 1)
        
        if is_winner:
            # Winner badge at top
            badge_rect = [col_x + 50, 96, col_x + col_w - 50, 124]
            draw.rounded_rectangle(badge_rect, radius=8, fill=(37, 99, 235, 255))
        
        # Paste 512 (scaled to 240) image
        icon_x = col_x + (col_w - 240) // 2
        icon_y = 150
        canvas.paste(img_512, (icon_x, icon_y), img_512)
        
        # Micro favicon box
        fav_box_y = 440
        fav_box_rect = [col_x + 30, fav_box_y, col_x + col_w - 30, fav_box_y + 110]
        draw.rounded_rectangle(fav_box_rect, radius=12, fill=(11, 15, 25, 255), outline=(30, 41, 59, 255), width=1)
        
        # Paste Favicon test
        canvas.paste(img_fav, (col_x + 50, fav_box_y + 15), img_fav)
        
    canvas.save("design_options_showcase.png")
    print("Showcase generated at design_options_showcase.png")

def deploy_assets():
    # 1. Generate master 512
    emblem_512 = generate_clean_vector_shield(512)
    emblem_512.save("client/assets/images/novakey_logo.png")
    emblem_512.save("client/web/icons/Icon-512.png")
    
    # 2. Generate 192
    emblem_192 = generate_clean_vector_shield(192)
    emblem_192.save("client/web/icons/Icon-192.png")
    
    # 3. Generate micro-optimized favicon 64x64
    fav_64 = generate_micro_favicon(64)
    fav_64.save("client/web/favicon.png")
    
    print("Assets deployed to client/assets/images and client/web.")

if __name__ == "__main__":
    build_showcase()
    deploy_assets()
