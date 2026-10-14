-- ============================================================================
-- ARQUITECTURA DE SEGURIDAD ZERO-KNOWLEDGE: ESQUEMA DE BASE DE DATOS SUPABASE
-- Proyecto: Gestor de Accesos y Contraseñas Multidispositivo
-- Autor: Comité de Ciberseguridad & DBA
-- ============================================================================

-- 1. Extensiones requeridas
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. Esquema de Perfiles de Usuario y Parámetros KDF (Argon2id)
-- Ningún dato sensible en plano: solo parámetros criptográficos públicos por usuario.
CREATE TABLE IF NOT EXISTS public.user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL UNIQUE,
    auth_salt TEXT NOT NULL,                     -- Sal criptográfica única (CSPRNG 256 bits)
    kdf_algorithm TEXT NOT NULL DEFAULT 'argon2id',
    kdf_iterations INT NOT NULL DEFAULT 3,       -- Costo temporal
    kdf_memory INT NOT NULL DEFAULT 65536,       -- Costo de memoria (64 MB)
    kdf_parallelism INT NOT NULL DEFAULT 4,      -- Grado de paralelismo
    is_mfa_enforced BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW())
);

COMMENT ON TABLE public.user_profiles IS 'Metadatos criptográficos de derivación de claves por usuario';

-- 3. Tabla de Dispositivos Registrados (Control de Acceso y Sesión)
CREATE TABLE IF NOT EXISTS public.user_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    device_fingerprint TEXT NOT NULL,            -- Hash SHA-256 de identificador de hardware
    device_name TEXT NOT NULL,                   -- Ej: "Samsung Galaxy S23", "ThinkPad Windows 11"
    platform TEXT NOT NULL CHECK (platform IN ('android', 'windows', 'web', 'other')),
    is_trusted BOOLEAN NOT NULL DEFAULT FALSE,   -- Requiere confirmación de OTP para pasar a TRUE
    last_ip_address TEXT,
    last_sync TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
    UNIQUE(user_id, device_fingerprint)
);

COMMENT ON TABLE public.user_devices IS 'Catálogo de dispositivos autorizados y de confianza por usuario';

-- 4. Bóveda de Accesos y Credenciales Cifradas (Zero-Knowledge Vault)
CREATE TABLE IF NOT EXISTS public.vault_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    
    -- Metadatos indexables cifrados de forma determinista o seudónima si se requiere búsqueda
    title_ciphertext TEXT NOT NULL,              -- Título o servicio cifrado (Base64)
    payload_ciphertext TEXT NOT NULL,            -- Credenciales completas (JSON cifrado en AES-256-GCM)
    nonce TEXT NOT NULL,                         -- Vector de inicialización de 96 bits (Base64)
    auth_tag TEXT NOT NULL,                      -- Tag de autenticación GCM de 128 bits (Base64)
    
    -- Atributos de sincronización y estado
    category TEXT NOT NULL DEFAULT 'login',      -- 'login', 'note', 'card', 'identity'
    is_favorite BOOLEAN NOT NULL DEFAULT FALSE,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,   -- Soft-delete para propagación offline
    version INT NOT NULL DEFAULT 1,              -- Concurrencia optimista
    client_updated_at TIMESTAMPTZ NOT NULL,      -- Timestamp asignado por el dispositivo emisor
    server_updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW())
);

CREATE INDEX IF NOT EXISTS idx_vault_items_user_id ON public.vault_items(user_id);
CREATE INDEX IF NOT EXISTS idx_vault_items_sync ON public.vault_items(user_id, server_updated_at);

COMMENT ON TABLE public.vault_items IS 'Cargas útiles (payloads) cifradas de extremo a extremo sin visibilidad para el servidor';

-- 5. Retos de Verificación OTP / PIN por Correo
CREATE TABLE IF NOT EXISTS public.otp_challenges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    code_hash TEXT NOT NULL,                     -- Hash SHA-256 del PIN de 6 dígitos con salt
    purpose TEXT NOT NULL CHECK (purpose IN ('new_device', 'recovery', 'critical_action', 'login_pin')),
    device_fingerprint TEXT,
    attempts INT NOT NULL DEFAULT 0,
    max_attempts INT NOT NULL DEFAULT 3,
    is_consumed BOOLEAN NOT NULL DEFAULT FALSE,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW())
);

CREATE INDEX IF NOT EXISTS idx_otp_challenges_lookup ON public.otp_challenges(user_id, purpose, is_consumed);

-- ============================================================================
-- POLÍTICAS DE AISLAMIENTO: ROW LEVEL SECURITY (RLS)
-- ============================================================================

ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vault_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.otp_challenges ENABLE ROW LEVEL SECURITY;

-- Políticas para user_profiles
CREATE POLICY "Users can only read own profile"
    ON public.user_profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can only update own profile"
    ON public.user_profiles FOR UPDATE
    USING (auth.uid() = id);

-- Políticas para user_devices
CREATE POLICY "Users can view own devices"
    ON public.user_devices FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own devices"
    ON public.user_devices FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can modify own devices"
    ON public.user_devices FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can remove own devices"
    ON public.user_devices FOR DELETE
    USING (auth.uid() = user_id);

-- Políticas para vault_items
CREATE POLICY "Users can view own vault items"
    ON public.vault_items FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own vault items"
    ON public.vault_items FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own vault items"
    ON public.vault_items FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own vault items"
    ON public.vault_items FOR DELETE
    USING (auth.uid() = user_id);

-- Políticas para otp_challenges (Solo accesible por service_role / edge functions por máxima seguridad)
CREATE POLICY "Service role manages otp challenges"
    ON public.otp_challenges FOR ALL
    USING (auth.jwt() ->> 'role' = 'service_role');

-- ============================================================================
-- TRIGGERS Y FUNCIONES DE AUDITORÍA
-- ============================================================================

CREATE OR REPLACE FUNCTION public.handle_vault_item_update()
RETURNS TRIGGER AS $$
BEGIN
    NEW.version = OLD.version + 1;
    NEW.server_updated_at = TIMEZONE('utc'::text, NOW());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_vault_items_versioning ON public.vault_items;
CREATE TRIGGER trg_vault_items_versioning
    BEFORE UPDATE ON public.vault_items
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_vault_item_update();

-- Publicar en Supabase Realtime para sincronización instantánea
ALTER PUBLICATION supabase_realtime ADD TABLE public.vault_items;
ALTER PUBLICATION supabase_realtime ADD TABLE public.user_devices;
