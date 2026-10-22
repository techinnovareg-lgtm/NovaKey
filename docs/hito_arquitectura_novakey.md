# NovaKey - Documentación Técnica del Hito v1.0.0 Enterprise
**Fecha del Hito:** 22 de Octubre de 2026  
**Empresa Desarrolladora:** Tech Innova ([tech-innova.online](https://tech-innova.online))  
**Soporte Oficial:** WhatsApp: +51 947 515 529 | Correo: tech.innova.reg@gmail.com  
**Versión del Hito:** v1.0.0-Enterprise-Milestone  

---

## 1. Resumen Ejecutivo y Alcance del Hito

NovaKey es una plataforma de ciberseguridad y custodia de credenciales multiplataforma (**Web, Android y Windows**) basada en el estándar estricto de **Cero Conocimiento (*Zero-Knowledge Architecture*)**. En este hito se consolida la arquitectura completa del producto:

1. **Bóveda Cero Conocimiento**: Cifrado y descifrado exclusivamente del lado del cliente. Ni el servidor central (Supabase) ni Tech Innova tienen acceso a las claves maestras ni a los datos en texto plano.
2. **Autenticación Biométrica y 2FA con PIN de 6 dígitos**: Despacho de códigos PIN de un solo uso por correo transaccional verificado en Namecheap y Resend bajo el dominio oficial `tech-innova.online`.
3. **Tablero de Mando del Superadministrador (Pantalla Completa)**: Acceso directo por credenciales (`tech.innova.reg@gmail.com` y `carlos.amambal@tech-innova.online`) con diseño oficial NovaKey e identidad corporativa de Tech Innova.
4. **Sistema de Suscripciones y Planes Comerciales**: Planes *Starter (Gratuito)*, *Pro Individual* y *Business / Pyme* en modalidades Mensual y Anual (con ahorro del 17% / 2 meses gratis).
5. **Canales de Pago Directos y Factibles**: Yape, Plin, SIP Interbancario, BCP, Interbank y Binance USDT.
6. **Gestión de Ciclo de Vida de Clientes**: Depuración, archivado individual, archivado masivo de cuentas vencidas y eliminación permanente con confirmación de seguridad.
7. **Notificación Interactiva de Felicitación**: Alerta automática *"¡Felicidades, has contratado tu Plan [Plan]!"* en el siguiente inicio de sesión tras ser aprovisionado.
8. **Cobertura de Pruebas Exhaustiva**: 39 pruebas automatizadas aprobadas (unitarias, criptográficas, funcionales, humo y rendimiento).

---

## 2. Arquitectura de Ciberseguridad Zero-Knowledge

```
+-----------------------------------------------------------------------------------+
|                            DISPOSITIVO CLIENTE (WEB / ANDROID)                    |
|                                                                                   |
|  [Contraseña Maestra] + [Sal Única CSPRNG (256-bit)]                              |
|                           │                                                       |
|                           ▼                                                       |
|              Argon2id (m=64MB, t=3, p=4)                                          |
|                           │                                                       |
|                           ▼                                                       |
|                 [Clave Raíz Derivada]                                             |
|                           │                                                       |
|             HKDF (RFC 5869 / SHA-256)                                             |
|              ├───> Master Encryption Key (AES-256-GCM) ───> Cifra Bóveda en RAM  |
|              └───> Auth Verifier Hash (SHA-256) ──────────> Verifica en Servidor  |
+-----------------------------------------------------------------------------------+
                                    │ (Solo viaja texto cifrado + Auth Hash)
                                    ▼
+-----------------------------------------------------------------------------------+
|                        INFRAESTRUCTURA DE NUBE SUPABASE                           |
|                                                                                   |
|  • PostgreSQL con Row Level Security (RLS) estricto por usuario autenticado.      |
|  • Replicación Realtime WebSocket de registros cifrados `vault_items`.            |
|  • Almacena únicamente: `ciphertext`, `iv` (96-bit), `tag` (128-bit) y `salt`.   |
|  • INMUNIDAD TOTAL: Una fuga de base de datos es matemáticamente inservible.      |
+-----------------------------------------------------------------------------------+
```

### Especificaciones de Seguridad Criptográfica
* **Algoritmo Simétrico**: `AES-256-GCM` (Galois/Counter Mode) con etiquetas de autenticación de 128 bits para detectar manipulación (*tamper resistance*).
* **Vector de Inicialización**: Nonce/IV único de 96 bits por cada credencial o nota, previniendo ataques de repetición y reutilización de flujos.
* **Fotos de Etiquetas Físicas**: Las imágenes de etiquetas adhesivas tomadas con la cámara del dispositivo móvil se codifican en Base64 y se cifran con la misma clave maestra antes de abandonar la memoria volátil.
* **Auto-Lock y Purgado de Memoria**: Temporizador de autobloqueo configurable (1, 2, 5, 15 min o desactivado) que invoca `zeroize` y libera las claves en RAM ante inactividad o cierre de sesión.

---

## 3. Sistema de 2FA y Verificación de Correo (Resend SMTP)

* **Dominio Transaccional**: `tech-innova.online`
* **Registros DNS Verificados en Namecheap**:
  * SPF: `v=spf1 include:amazonses.com ~all`
  * DKIM: `resend._domainkey.tech-innova.online` (CNAME `dkim.resend.com`)
  * DMARC: `_dmarc.tech-innova.online` (`v=DMARC1; p=none; ...`)
  * MX: `feedback-smtp.us-east-1.amazonses.com`
* **Generación de PIN**: Códigos criptográficos aleatorios de 6 dígitos numéricos con expiración de 5 minutos y consumo único (*anti-replay attack*).
* **Plantilla HTML Responsiva**: Envío de correos estilizados con branding corporativo de NovaKey y Tech Innova, alertando el propósito (nuevo dispositivo, cambio de contraseña o restablecimiento).

---

## 4. Estructura de Planes y Canales de Pago

| Plan | Destinado a | Contraseñas | Fotos Etiquetas | Sincronización | Precio Mensual | Precio Anual (17% OFF) |
|---|---|---|---|---|---|---|
| **Starter** | Uso personal básico | Hasta 30 | Hasta 3 | Web + Android | **Gratis** | **Gratis de por vida** |
| **Pro Individual** | Profesionales / Avanzados | Ilimitadas | Ilimitadas | Multi-dispositivo | **S/ 9.90 / mes** | **S/ 99.00 / año** (2 meses gratis) |
| **Business** | Equipos y Empresas | Ilimitadas | Ilimitadas | Prioritaria + SLA | **S/ 29.90 / mes** | **S/ 299.00 / año** (2 meses gratis) |

### Canales de Contacto para Activación
* **WhatsApp Soporte & Ventas**: `+51 947 515 529`
* **Correo Oficial**: `tech.innova.reg@gmail.com`

### Medios de Pago Disponibles
* 🟣 **Yape**
* 🔵 **Plin**
* 🏛️ **SIP Interbancario**
* 🟧 **BCP (Banco de Crédito del Perú)**
* 🟩 **Interbank**
* 🪙 **Binance (USDT Crypto)**

---

## 5. Panel de Superadministrador (Tablero de Mando Full Screen)

### Credenciales de Acceso Maestro
* `tech.innova.reg@gmail.com`
* `carlos.amambal@tech-innova.online`

### Características Implementadas
1. **Acceso Exclusivo y Directo**:
   * Al iniciar sesión con las credenciales maestras, la aplicación abre automáticamente el **Tablero de Mando a Pantalla Completa**.
   * La bóveda personal del Superadmin está accesible mediante el botón *"Mi Bóveda de Contraseñas"* en la barra superior (lógica inversa).
2. **Identidad Visual Oficial**:
   * Logotipo e isologo oficial de **NovaKey** en la parte superior izquierda.
   * Insignia técnica `TECH INNOVA · GLOBAL ADMIN`.
   * Pie de página corporativo inferior con el isotipo de **Tech Innova**, contactos oficiales y sello de verificación Zero-Knowledge.
3. **Métricas KPI en Tiempo Real**:
   * Clientes Totales.
   * Suscripciones Activas.
   * Por Vencer (≤ 7 días).
   * Vencidas / Sin Renovar.
   * Cuentas Archivadas.
   * Ingresos Recurrentes Estimados.
4. **CRUD y Acciones Administrativas por Cuenta**:
   * **Asignar / Cambiar Plan**: Modal con selección de plan (Starter, Pro, Business) y ciclo (Mensual, Anual, Vitalicio) con cálculo automático de fecha de caducidad.
   * **Ampliar Contrato**: Adición directa de +1 Mes o +1 Año con 2 meses bonificados.
   * **Restablecer Contraseña**: Despacho de código PIN de autorización al correo del cliente.
   * **Archivar / Desarchivar**: Marcado de cuenta inactiva por vencimiento para pausar sincronización.
   * **Archivado Masivo**: Botón dinámico `Archivar Vencidos (N)` para procesamiento en lote.
   * **Eliminación Definitiva**: Borrado seguro del registro con advertencia destructiva.

---

## 6. Procedimiento de Contingencia y Recuperación (Disaster Recovery)

En caso de cualquier eventualidad o fallo en futuros desarrollos, este hito se encuentra respaldado en tres niveles:

### Nivel A: Restauración mediante Etiqueta Git
El repositorio local cuenta con la etiqueta de hito `v1.0.0-milestone`:
```bash
# Para consultar el estado del hito:
git tag -l -n9 "v1.0.0-milestone"

# Para regresar el proyecto a este estado exacto:
git checkout v1.0.0-milestone
```

### Nivel B: Restauración mediante Archivo Backup
Existe un archivo comprimido de contingencia ubicado en:
`backups/novakey_backup_hito_v1.0.0.zip`

Para restaurar manualmente:
1. Extraer el contenido del archivo zip sobre la carpeta del proyecto.
2. Ejecutar `flutter pub get` dentro de la carpeta `client/`.
3. Compilar con `flutter build web --release` o `flutter run -d windows`.

### Nivel C: Verificación de Integridad del Build
Para confirmar que el código restaurado está 100% operativo:
```bash
cd client
flutter test
flutter build web --release
```
Resultado esperado: **`All 39 tests passed!`** y **`Built build\web`**.
