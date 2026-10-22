import os
import shutil
import subprocess

build_dir = r"D:\Proyectos Desarrollo\Antigravity\HRA.estadistica\App_GestionarPasswords\client\build\web"
temp_dir = os.path.join(os.environ["TEMP"], "novakey_web_deploy")

if os.path.exists(temp_dir):
    shutil.rmtree(temp_dir, ignore_errors=True)

shutil.copytree(build_dir, temp_dir, dirs_exist_ok=True)

# Agregar archivo CNAME para el subdominio personalizado
with open(os.path.join(temp_dir, "CNAME"), "w", encoding="utf-8") as f:
    f.write("novakey.tech-innova.online\n")

os.chdir(temp_dir)
subprocess.run(["git", "init"], check=True)
subprocess.run(["git", "checkout", "-b", "gh-pages"], check=True)
subprocess.run(["git", "add", "."], check=True)
subprocess.run(["git", "commit", "-m", "deploy: NovaKey Web production release"], check=True)
subprocess.run(["git", "remote", "add", "origin", "https://github.com/techinnovareg-lgtm/NovaKey.git"], check=True)
subprocess.run(["git", "push", "origin", "gh-pages", "--force"], check=True)
print("SUCCESS_DEPLOYED_GH_PAGES")
