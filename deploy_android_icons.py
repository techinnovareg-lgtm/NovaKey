import os
from PIL import Image

def deploy_android_icons():
    base_res = "client/android/app/src/main/res"
    src_icon = "client/assets/images/novakey_logo.png"
    
    if not os.path.exists(src_icon):
        print("Source icon not found:", src_icon)
        return
        
    img = Image.open(src_icon)
    
    densities = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    
    for folder, size in densities.items():
        dir_path = os.path.join(base_res, folder)
        os.makedirs(dir_path, exist_ok=True)
        out_path = os.path.join(dir_path, "ic_launcher.png")
        resized = img.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(out_path, "PNG")
        print(f"Generated {out_path} ({size}x{size})")

if __name__ == "__main__":
    deploy_android_icons()
