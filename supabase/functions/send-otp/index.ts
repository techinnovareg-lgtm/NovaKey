// ============================================================================
// SUPABASE EDGE FUNCTION: Envío Seguro de PIN / OTP vía Resend (Deno)
// Ruta: supabase/functions/send-otp/index.ts
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface RequestPayload {
  email: string;
  purpose: "new_device" | "recovery" | "critical_action" | "login_pin";
  deviceFingerprint?: string;
  deviceName?: string;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const resendApiKey = Deno.env.get("RESEND_API_KEY") ?? "";

    if (!resendApiKey) {
      throw new Error("Falta configurar la variable RESEND_API_KEY en Supabase Vault");
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    const { email, purpose, deviceFingerprint, deviceName }: RequestPayload = await req.json();

    if (!email || !purpose) {
      return new Response(JSON.stringify({ error: "Email y purpose son requeridos" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 1. Obtener usuario asociado al email
    const { data: userProfile, error: userError } = await supabase
      .from("user_profiles")
      .select("id, email")
      .eq("email", email.toLowerCase().trim())
      .single();

    if (userError || !userProfile) {
      // Por seguridad para prevenir enumeración de correos, retornar respuesta genérica
      return new Response(
        JSON.stringify({ message: "Si el correo está registrado, se ha enviado un PIN." }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Generar PIN criptográfico de 6 dígitos (CSPRNG)
    const array = new Uint32Array(1);
    crypto.getRandomValues(array);
    const pin = (100000 + (array[0] % 900000)).toString();

    // 3. Hashear el PIN con SHA-256 antes de persistir
    const encoder = new TextEncoder();
    const data = encoder.encode(pin + userProfile.id);
    const hashBuffer = await crypto.subtle.digest("SHA-256", data);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    const codeHash = hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");

    // 4. Invalidar códigos previos no consumidos para este usuario y propósito
    await supabase
      .from("otp_challenges")
      .update({ is_consumed: true })
      .eq("user_id", userProfile.id)
      .eq("purpose", purpose)
      .eq("is_consumed", false);

    // 5. Insertar nuevo desafío válido por 5 minutos
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000).toISOString();
    const { error: insertError } = await supabase.from("otp_challenges").insert({
      user_id: userProfile.id,
      code_hash: codeHash,
      purpose: purpose,
      device_fingerprint: deviceFingerprint ?? null,
      expires_at: expiresAt,
    });

    if (insertError) {
      throw insertError;
    }

    // 6. Despachar correo electrónico mediante API transaccional de Resend
    const emailSubject =
      purpose === "new_device"
        ? "🔐 Código de Seguridad para Nuevo Dispositivo"
        : "🔑 Código de Verificación de Acceso";

    const emailHtml = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 8px;">
        <h2 style="color: #1a73e8; text-align: center;">Bóveda Segura de Contraseñas</h2>
        <p>Hola,</p>
        <p>Se ha solicitado un código de verificación para tu cuenta registrada (<strong>${email}</strong>)${
          deviceName ? ` desde el dispositivo <strong>${deviceName}</strong>` : ""
        }.</p>
        <div style="text-align: center; margin: 30px 0;">
          <span style="font-size: 32px; font-weight: bold; letter-spacing: 6px; padding: 12px 24px; background: #f1f3f4; border-radius: 6px; color: #202124;">
            ${pin}
          </span>
        </div>
        <p style="color: #d93025; font-size: 14px;"><strong>Importante:</strong> Este código expira en 5 minutos. Nunca compartas este código con nadie.</p>
        <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;" />
        <p style="font-size: 12px; color: #70757a; text-align: center;">Si no realizaste esta solicitud, tu cuenta puede estar en riesgo. Accede de inmediato para cambiar tu Contraseña Maestra.</p>
      </div>
    `;

    const resendRes = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${resendApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: "Seguridad Bóveda <onboarding@resend.dev>",
        to: [email],
        subject: emailSubject,
        html: emailHtml,
      }),
    });

    if (!resendRes.ok) {
      const errDetail = await resendRes.text();
      console.error("Error al enviar con Resend:", errDetail);
      throw new Error("No se pudo despachar el correo transaccional.");
    }

    return new Response(
      JSON.stringify({ message: "Código enviado con éxito", expiresAt }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error: any) {
    console.error("Error en send-otp:", error.message);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
