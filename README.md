# NovaKey: Gestor de Accesos y Bóveda Cero-Conocimiento (Zero-Knowledge)

[![Seguridad Criptográfica](https://img.shields.io/badge/Criptograf%C3%ADa-Argon2id%20%7C%20AES--256--GCM-0284C7?style=for-the-badge&logo=shield)](https://tech-innova.online)
[![Flutter Multiplataforma](https://img.shields.io/badge/Flutter-3.22+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Supabase Realtime](https://img.shields.io/badge/Supabase-PostgreSQL%20RLS-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com)
[![2FA Email SMTP](https://img.shields.io/badge/Resend-PIN%206--D%C3%ADgitos-000000?style=for-the-badge&logo=resend&logoColor=white)](https://resend.com)
[![Licencia Comercial](https://img.shields.io/badge/Desarrollado%20por-Tech%20Innova-F59E0B?style=for-the-badge)](https://tech-innova.online)

**NovaKey** es una solución empresarial y personal multiplataforma (**Web, Android y Windows**) para la custodia, gestión y sincronización en tiempo real de contraseñas, notas y credenciales de acceso bajo la premisa de **Cero Conocimiento (*Zero-Knowledge Architecture*)**.

---

## 🌟 Características Principales

1. **Bóveda Zero-Knowledge de Grado Militar**:
   - Cifrado simétrico `AES-256-GCM` con Nonce único de 96 bits y Tag de autenticación de 128 bits.
   - Derivación de claves con `Argon2id` (costo de memoria 64MB) + `HKDF` (RFC 5869) con sal aleatoria de 256 bits por usuario.
   - El servidor de base de datos **nunca almacena ni recibe la clave maestra**.
2. **Soporte para Dispositivos Físicos y Fotografías**:
   - Captura y adjunta fotos de etiquetas físicas de routers, cajas de switch o equipos de red.
   - Las imágenes se cifran de extremo a extremo en el dispositivo cliente con la misma clave maestra.
3. **Autenticación en Dos Pasos (2FA) con PIN al Correo**:
   - Detección de nuevos dispositivos con despacho automático de PIN de 6 dígitos mediante servidor transaccional Resend con dominio verificado `tech-innova.online`.
4. **Tablero de Mando Superadmin a Pantalla Completa**:
   - Vista administrativa dedicada para los administradores de Tech Innova (`tech.innova.reg@gmail.com`).
   - Métricas KPI en tiempo real: Clientes totales, activos, por vencer, vencidos, archivados e ingresos recurrentes.
   - CRUD de clientes, asignación de planes, prórrogas (+1 mes o +1 año con 2 meses gratis), reseteo de contraseñas y archivado individual o masivo.
5. **Esquema de Planes y Métodos de Pago**:
   - Planes: **Starter (Gratis)**, **Pro Individual** y **Business / Pyme** con selector mensual y anual (17% de ahorro).
   - Canales de contacto directos: WhatsApp `+51 947 515 529` y correo `tech.innova.reg@gmail.com`.
   - Métodos de pago disponibles: **Yape, Plin, SIP Interbancario, BCP, Interbank y Binance USDT**.
6. **Notificación de Bienvenida Interactiva**:
   - Celebración automática con resumen de beneficios al iniciar sesión tras contratar o actualizar su plan.
7. **Importación Inteligente (.txt / Excel)**:
   - Procesador sintáctico para importar contraseñas con herencia contextual de títulos y previsualización editable.
8. **Suite de Pruebas de Calidad**:
   - 39 pruebas automatizadas pasando exitosamente (Unitarias, Integración, Criptografía, Fuzzing, Rendimiento y Humo).

---

## 🏗️ Arquitectura del Sistema

```text
App_GestionarPasswords/
├── .github/
│   └── workflows/
│       └── build_deploy.yml       # Automatización CI/CD
├── docs/
│   ├── hito_arquitectura_novakey.md  # Documentación detallada del hito v1.0.0
│   └── propuesta_planes_superadmin.md # Modelo de negocio y planes
├── supabase/
│   └── migrations/
│       └── 20261014_init_security_vault_schema.sql  # DDL con RLS y Realtime
├── client/
│   ├── assets/
│   │   └── images/
│   │       ├── novakey_logo.png   # Logotipo oficial NovaKey
│   │       └── logo_TI.png        # Logotipo corporativo Tech Innova
│   ├── lib/
│   │   ├── core/
│   │   │   ├── crypto/            # Argon2id, HKDF, AES-256-GCM
│   │   │   ├── security/          # Biometría, auto-lock y 2FA EmailPinService
│   │   │   └── widgets/           # NovaKeyLogo y componentes compartidos
│   │   ├── features/
│   │   │   ├── auth/              # Pantallas de login, registro y PIN
│   │   │   ├── subscription/      # Planes, Superadmin Dashboard y Perfil
│   │   │   └── vault/             # Bóveda, categorías, fotos y sincronización
│   │   └── main.dart              # Enrutador inteligente (Superadmin vs Bóveda)
│   └── test/                      # 39 pruebas automatizadas (Atlassian QA)
└── README.md
```

---

## 🚀 Despliegue y Ejecución Local

### Prerrequisitos
* Flutter SDK (3.22.0 o superior)
* Conexión a Internet para sincronización con Supabase

### Ejecutar Pruebas Automatizadas
```bash
cd client
flutter test
```
*Resultado esperado:* `All 39 tests passed!`.

### Ejecutar Aplicación Web
```bash
cd client
flutter run -d chrome
```
O compilar la versión optimizada para producción:
```bash
flutter build web --release
```

### Ejecutar Aplicación Android
```bash
cd client
flutter run -d android
```

---

## 🛡️ Soporte y Contacto Corporativo

**Tech Innova · Soluciones Tecnológicas & Ciberseguridad**  
* 📱 **WhatsApp de Atención**: +51 947 515 529  
* ✉️ **Correo Oficial**: tech.innova.reg@gmail.com  
* 🌐 **Sitio Web**: [tech-innova.online](https://tech-innova.online)
