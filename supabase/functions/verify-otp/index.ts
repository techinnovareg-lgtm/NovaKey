// ============================================================================
// SUPABASE EDGE FUNCTION: Verificación de Desafío OTP / PIN y Autorización
// Ruta: supabase/functions/verify-otp/index.ts
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface VerifyPayload {
  email: string;
  pin: string;
  purpose: "new_device" | "recovery" | "critical_action" | "login_pin";
  deviceFingerprint?: string;
  deviceName?: string;
  platform?: "android" | "windows" | "web";
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const { email, pin, purpose, deviceFingerprint, deviceName, platform }: VerifyPayload =
      await req.json();

    if (!email || !pin || !purpose) {
      return new Response(JSON.stringify({ error: "Faltan parámetros requeridos" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 1. Obtener usuario
    const { data: userProfile, error: userError } = await supabase
      .from("user_profiles")
      .select("id, email")
      .eq("email", email.toLowerCase().trim())
      .single();

    if (userError || !userProfile) {
      return new Response(JSON.stringify({ error: "Usuario o código inválido" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 2. Buscar desafío activo y vigente
    const { data: challenge, error: challengeError } = await supabase
      .from("otp_challenges")
      .select("*")
      .eq("user_id", userProfile.id)
      .eq("purpose", purpose)
      .eq("is_consumed", false)
      .gt("expires_at", new Date().toISOString())
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (challengeError || !challenge) {
      return new Response(JSON.stringify({ error: "El código ha expirado o no existe." }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 3. Validar límite de intentos
    if (challenge.attempts >= challenge.max_attempts) {
      await supabase
        .from("otp_challenges")
        .update({ is_consumed: true })
        .eq("id", challenge.id);

      return new Response(
        JSON.stringify({ error: "Has superado el número máximo de intentos. Solicita un nuevo código." }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 4. Calcular hash del PIN enviado
    const encoder = new TextEncoder();
    const data = encoder.encode(pin + userProfile.id);
    const hashBuffer = await crypto.subtle.digest("SHA-256", data);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    const calculatedHash = hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");

    if (calculatedHash !== challenge.code_hash) {
      // Incrementar contador de intentos fallidos
      await supabase
        .from("otp_challenges")
        .update({ attempts: challenge.attempts + 1 })
        .eq("id", challenge.id);

      const remaining = challenge.max_attempts - (challenge.attempts + 1);
      return new Response(
        JSON.stringify({ error: `Código incorrecto. Intentos restantes: ${remaining}` }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 5. Consumir el código exitosamente
    await supabase
      .from("otp_challenges")
      .update({ is_consumed: true })
      .eq("id", challenge.id);

    // 6. Si el propósito era nuevo dispositivo, registrar o actualizar el dispositivo como confiable
    if (purpose === "new_device" && deviceFingerprint) {
      await supabase.from("user_devices").upsert(
        {
          user_id: userProfile.id,
          device_fingerprint: deviceFingerprint,
          device_name: deviceName ?? "Dispositivo Desconocido",
          platform: platform ?? "other",
          is_trusted: true,
          last_sync: new Date().toISOString(),
        },
        { onConflict: "user_id, device_fingerprint" }
      );
    }

    return new Response(
      JSON.stringify({ success: true, message: "Verificación de PIN completada con éxito." }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error: any) {
    console.error("Error en verify-otp:", error.message);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
