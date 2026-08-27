// Cliente con service_role + verificación de que el llamador es un admin.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

export function corsHeaders(): Record<string, string> {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
}

export function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(), "Content-Type": "application/json" },
  });
}

/**
 * Devuelve el cliente service_role y los datos del admin que llama,
 * o una Response de error si la petición no proviene de un admin activo.
 */
export async function requireAdmin(
  req: Request
): Promise<
  { admin: ReturnType<typeof createClient>; callerId: string } | Response
> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse({ error: "Falta el header Authorization" }, 401);
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    { auth: { autoRefreshToken: false, persistSession: false } }
  );

  const token = authHeader.replace("Bearer ", "");
  const { data: userData, error: userError } =
    await admin.auth.getUser(token);
  if (userError || !userData.user) {
    return jsonResponse({ error: "Token inválido" }, 401);
  }

  const { data: profile, error: profileError } = await admin
    .from("profiles")
    .select("role, is_active")
    .eq("id", userData.user.id)
    .single();

  if (profileError || !profile || profile.role !== "admin" || !profile.is_active) {
    return jsonResponse({ error: "Solo un administrador puede hacer esto" }, 403);
  }

  return { admin, callerId: userData.user.id };
}

/** Email sintético consistente con la convención del esquema. */
export function syntheticEmail(username: string): string {
  return `u-${username.trim().toLowerCase()}@sinotruk.app`;
}
