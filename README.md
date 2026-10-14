# SafeVault: Gestor de Accesos y Contraseñas Multidispositivo (Zero-Knowledge)

[![CI/CD Security & Build Pipeline](https://github.com/tu-usuario/App_GestionarPasswords/actions/workflows/ci.yml/badge.svg)](https://github.com/tu-usuario/App_GestionarPasswords/actions)
![License](https://img.shields.io/badge/License-MIT-blue.svg)
![Flutter](https://img.shields.io/badge/Flutter-3.22+-02569B?logo=flutter&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-PostgreSQL%20RLS-3ECF8E?logo=supabase&logoColor=white)
![Security](https://img.shields.io/badge/Security-Argon2id%20%7C%20AES--256--GCM-critical)

Aplicación multiplataforma (**Android, Windows, Web/Nube**) para la custodia y sincronización de contraseñas, notas y credenciales bajo el estándar de **Cero Conocimiento (*Zero-Knowledge Architecture*)**.

---

## 🔒 Pilares de Seguridad y Criptografía

1. **Arquitectura Cero Conocimiento (*Zero-Knowledge*)**:
   - El servidor (Supabase) **nunca recibe la Contraseña Maestra ni la Clave de Cifrado**.
   - Toda operación de cifrado y descifrado se realiza **exclusivamente en el dispositivo cliente** (memoria volátil).
2. **Derivación de Claves de Grado Militar (`Argon2id` + `HKDF`)**:
   - Cada usuario cuenta con una **Sal aleatoria (CSPRNG de 256 bits)** generada al registrarse.
   - Algoritmo `Argon2id` con alto costo de memoria RAM para neutralizar ataques por GPU/ASIC.
   - Bifurcación HKDF (RFC 5869) para separar el hash de autenticación (`Auth Hash`) de la clave de cifrado de la bóveda (`Master Encryption Key`).
3. **Cifrado Autenticado Simétrico (`AES-256-GCM`)**:
   - Vector de inicialización / Nonce único de 96 bits por cada elemento de la bóveda.
   - Tag de integridad y autenticación de 128 bits para detectar cualquier manipulación de datos.
4. **Protección Biométrica y de Hardware Seguro**:
   - **Android**: Integración con **Android Keystore** y `BiometricPrompt` (Huella / Rostro).
   - **Windows**: Integración con **Windows Hello** respaldado por TPM y DPAPI (*Data Protection API*).
   - **Protección de Memoria**: Limpieza automática de búferes (`zeroize`) al bloquear o salir de la aplicación.
5. **Autenticación Fuera de Banda (OTP / PIN)**:
   - Detección de nuevos dispositivos o accesos no reconocidos con disparo automático de un PIN de 6 dígitos al correo registrado vía Edge Functions.

---

## 🏗️ Estructura del Proyecto

```text
App_GestionarPasswords/
├── .github/
│   └── workflows/
│       └── ci.yml             # Pipeline de análisis de seguridad, linting y compilación
├── supabase/
│   ├── migrations/
│   │   └── 20261014_init_security_vault_schema.sql  # DDL con RLS y Realtime
│   └── functions/
│       ├── send-otp/          # Edge Function Deno: Envío de PIN vía Resend
│       └── verify-otp/        # Edge Function Deno: Validación y registro de dispositivos
├── client/                    # Aplicación Flutter Unificada (Android, Windows, Web)
│   ├── lib/
│   │   ├── core/
│   │   │   ├── crypto/        # Motor Argon2id, HKDF, AES-256-GCM
│   │   │   └── security/      # Biometría (Windows Hello / Keystore) y SecureStorage
│   │   ├── features/
│   │   │   ├── auth/          # Pantallas de autenticación y enrolamiento biométrico
│   │   │   └── vault/         # Bóveda, sincronización en tiempo real y generador
│   │   └── main.dart          # Entrada principal y gestión de estado en memoria
│   └── test/
│       └── crypto_engine_test.dart  # Pruebas unitarias de vectores criptográficos
└── README.md
```

---

## 🚀 Despliegue en Infraestructura Zero-Cost / Low-Cost

Todo el proyecto puede ejecutarse y desplegarse en niveles gratuitos de alta disponibilidad:

### 1. Configurar Supabase (PostgreSQL BaaS)
1. Crea un proyecto gratuito en [supabase.com](https://supabase.com).
2. En el panel **SQL Editor**, copia y ejecuta el script:
   `supabase/migrations/20261014_init_security_vault_schema.sql`.
3. Activa la extensión de replicación en tiempo real para la tabla `vault_items`.

### 2. Configurar Resend (Correos Transaccionales)
1. Obtén tu API Key gratuita en [resend.com](https://resend.com) (3,000 correos/mes gratis).
2. Agrega el secreto a tu proyecto de Supabase:
   ```bash
   supabase secrets set RESEND_API_KEY=tu_api_key_aqui
   ```
3. Despliega las funciones Edge:
   ```bash
   supabase functions deploy send-otp
   supabase functions deploy verify-otp
   ```

### 3. Ejecutar la Aplicación Cliente

Para ejecutar en **Windows Desktop**:
```bash
cd client
flutter run -d windows
```

Para ejecutar en **Android**:
```bash
cd client
flutter run -d android
```

Para ejecutar en **Navegador Web**:
```bash
cd client
flutter run -d chrome
```

---

## 🧪 Pruebas Automatizadas

Para validar los vectores criptográficos de derivación y cifrado:

```bash
cd client
flutter test
```
