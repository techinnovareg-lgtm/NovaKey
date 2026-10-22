import os
import shutil
import subprocess

def deploy_unified():
    root_dir = r"d:\Proyectos Desarrollo\Antigravity\HRA.estadistica\App_GestionarPasswords"
    landing_dir = os.path.join(root_dir, "landing")
    web_dir = os.path.join(root_dir, "client", "build", "web")
    apk_file = os.path.join(root_dir, "release", "NovaKey-v1.0.0.apk")
    temp_dir = os.path.join(os.environ["TEMP"], "novakey_unified_deploy")

    print(f"[*] Limpiando directorio temporal: {temp_dir}")
    if os.path.exists(temp_dir):
        shutil.rmtree(temp_dir, ignore_errors=True)
    os.makedirs(temp_dir, exist_ok=True)

    print("[*] Copiando Landing Page a la raíz...")
    shutil.copytree(landing_dir, temp_dir, dirs_exist_ok=True)

    print("[*] Copiando Aplicación Web Flutter a /app/...")
    app_target_dir = os.path.join(temp_dir, "app")
    os.makedirs(app_target_dir, exist_ok=True)
    shutil.copytree(web_dir, app_target_dir, dirs_exist_ok=True)

    # 404 handler for Flutter Web routing under /app/
    flutter_index = os.path.join(app_target_dir, "index.html")
    flutter_404 = os.path.join(app_target_dir, "404.html")
    if os.path.exists(flutter_index) and not os.path.exists(flutter_404):
        shutil.copyfile(flutter_index, flutter_404)

    # Nota: El APK se sirve desde GitHub Releases para aprovechar CDN sin sobrecargar gh-pages
    # apk_file se descarga directamente desde https://github.com/techinnovareg-lgtm/NovaKey/releases

    print("[*] Escribiendo CNAME para novakey.tech-innova.online...")
    with open(os.path.join(temp_dir, "CNAME"), "w", encoding="utf-8") as f:
        f.write("novakey.tech-innova.online\n")

    # .nojekyll para asegurar que archivos con guiones bajos o assets de Flutter se sirvan correctamente
    with open(os.path.join(temp_dir, ".nojekyll"), "w", encoding="utf-8") as f:
        f.write("")

    print("[*] Publicando en rama gh-pages...")
    os.chdir(temp_dir)
    subprocess.run(["git", "init"], check=True)
    subprocess.run(["git", "checkout", "-b", "gh-pages"], check=True)
    subprocess.run(["git", "add", "."], check=True)
    subprocess.run(["git", "commit", "-m", "deploy: NovaKey Landing + Web Vault (/app/) + APK v1.0.0"], check=True)
    subprocess.run(["git", "remote", "add", "origin", "https://github.com/techinnovareg-lgtm/NovaKey.git"], check=True)
    subprocess.run(["git", "push", "origin", "gh-pages", "--force"], check=True)
    print("SUCCESS_UNIFIED_DEPLOY_COMPLETE")

if __name__ == "__main__":
    deploy_unified()
