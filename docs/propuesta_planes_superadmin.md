# Propuesta de Planes de Suscripción, Rol Superadmin y Gestión Multi-Dispositivo para NovaKey

Basado en el análisis de los líderes de la industria en gestión de contraseñas de **Zero-Knowledge** (**Bitwarden**, **1Password** y **Proton Pass**), adaptado a la arquitectura tecnológica de **Tech Innova** (Flutter Web + Android + Supabase + Resend).

---

## 1. Benchmarking de la Industria

| Plataforma | Modelo de Planes | Precios Promedio | Soporte Multi-Dispositivo | Características Clave |
| :--- | :--- | :--- | :--- | :--- |
| **Bitwarden** | Freemium | Gratis / \$1.65/mes (Premium) / \$4/mes (Familia) | Ilimitado (Web, Desktop, Móvil) | 2FA avanzado, reportes de salud, almacenamiento cifrado de archivos |
| **1Password** | Solo Pago (14 días gratis) | \$2.99/mes (Individual) / \$4.49/mes (Familia) | Ilimitado en todos los dispositivos | Modo Viaje, Watchtower (fugas), llaves de paso (Passkeys) |
| **Proton Pass** | Freemium | Gratis / €1.99/mes (Pass Plus) / €4.99/mes (Familia) | Ilimitado con sincronización en tiempo real | Alias de correo oculto (Hide-my-email), 2FA TOTP integrado |

### Conclusiones Estratégicas para NovaKey:
1. **Acceso Multi-Dispositivo Universal (Cross-Platform)**: Tanto en la versión gratuita como en los planes de pago, los usuarios deben poder sincronizar su bóveda **indistintamente en PC (Web) y Móviles (Android)** en tiempo real sin recargos por tipo de dispositivo.
2. **Diferenciadores de Valor para Monetización**:
   - Cantidad de credenciales / notas seguras.
   - Capacidad de almacenamiento para **fotos de etiquetas físicas** (fotos de routers, cámaras, placas de equipos).
   - Generación de respaldos automáticos en la nube vs local.
   - Acceso a herramientas de auditoría (detección de contraseñas débiles o reutilizadas).
   - Bóvedas compartidas (en planes Familiares / Pyme).

---

## 2. Estructura de Planes Propuesta para NovaKey

```
┌─────────────────────────┬─────────────────────────┬─────────────────────────┐
│     PLAN STARTER        │      PLAN PRO           │      PLAN BUSINESS      │
│        (GRATIS)         │       (S/ 9.90 / mes)   │      (S/ 29.90 / mes)   │
├─────────────────────────┼─────────────────────────┼─────────────────────────┤
│ • Hasta 30 credenciales │ • Credenciales ILIMITADAS│ • Credenciales ILIMITADAS│
│ • Web + Android         │ • Web + Android         │ • Web + Android         │
│ • Cifrado AES-256-GCM   │ • Cifrado AES-256-GCM   │ • Cifrado AES-256-GCM   │
│ • Hasta 3 fotos etiquetas│ • Fotos ILIMITADAS      │ • Fotos ILIMITADAS      │
│ • Autenticación PIN OTP │ • 2FA + Biometría       │ • Multi-usuario (hasta 5)│
│ • Exportación JSON local│ • Exportación Excel/JSON│ • Panel Admin para Pymes │
│                         │ • Auditoría de robustez │ • Soporte prioritario   │
└─────────────────────────┴─────────────────────────┴─────────────────────────┘
```

---

## 3. Arquitectura del Rol Superadmin (Administrador Central)

El Superadmin es el encargado de:
1. **Crear y Aprobar Nuevas Cuentas**:
   - Crear usuarios ingresando su correo y asignándoles un Plan (Starter, Pro, Business).
   - Definir fecha de vencimiento o renovación de suscripción.
2. **Gestionar Estados de Acceso**:
   - **Activo**: Acceso normal a la sincronización en tiempo real.
   - **Suspendido / Moroso**: Bloqueo temporal de sincronización en la nube (el usuario mantiene acceso local de solo lectura a sus contraseñas por ética y seguridad).
   - **Restablecer 2FA**: Permitir desautorizar dispositivos si el usuario perdió su celular o correo.
3. **Métricas y Monitoreo del Negocio**:
   - Total de usuarios registrados y activos.
   - Distribución de usuarios por plan.
   - Tasa de renovación y alertas de vencimiento de suscripciones.

### Modelo de Datos en Base de Datos (Supabase):
```sql
-- Tabla de suscripciones y perfiles gestionados por Superadmin
create table if not exists public.user_profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    email text unique not null,
    role text not null default 'user', -- 'user' | 'superadmin'
    plan_tier text not null default 'starter', -- 'starter' | 'pro' | 'business'
    subscription_status text not null default 'active', -- 'active' | 'past_due' | 'canceled'
    max_items int not null default 30, -- límite según plan (ej. 999999 para pro)
    max_photos int not null default 3,
    subscription_expires_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);
```

---

## 4. Nueva Experiencia de Usuario: Menú de Perfil Superior Derecho

En la barra superior derecha de la aplicación se integrará un componente interactivo con el avatar o iniciales del usuario (`UserAvatarMenu`):
- **Encabezado con datos**:
  - Correo electrónico autenticado.
  - Insignia (Badge) del plan actual (ej. `PLAN PRO` en azul o `SUPERADMIN` en dorado).
  - Estado del cifrado Zero-Knowledge.
- **Acciones Rápidas**:
  1. **Cambiar Contraseña Maestra**: Con verificación por PIN al correo.
  2. **Configuración de Autobloqueo**: Selector de tiempo (1 min, 2 min, 5 min, 15 min, Nunca).
  3. **Ver Planes y Suscripción**: Modal con los detalles de su plan y opción de upgrade.
  4. **Panel Superadmin** *(visible únicamente para usuarios con rol Superadmin)*: Para crear usuarios y asignar planes.
  5. **Cerrar Sesión / Salir**:
     - Limpia de inmediato las llaves criptográficas de la memoria RAM.
     - Detiene WebSockets y listeners en tiempo real.
     - Cierra sesión en Supabase Auth y redirige a la pantalla de bienvenida.
