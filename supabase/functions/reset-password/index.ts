// Resetea la contraseña de un usuario.
// Body: { user_id, new_password }
import { corsHeaders, jsonResponse, requireAdmin } from "../_shared/admin.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders() });
  if (req.method !== "POST") return jsonResponse({ error: "Método no permitido" }, 405);

  const adminOrError = await requireAdmin(req);
  if (adminOrError instanceof Response) return adminOrError;
  const { admin } = adminOrError;

  let body: { user_id?: string; new_password?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "JSON inválido" }, 400);
  }

  const userId = body.user_id?.trim();
  const newPassword = body.new_password ?? "";

  if (!userId || newPassword.length < 6) {
    return jsonResponse(
      { error: "user_id es obligatorio y new_password debe tener al menos 6 caracteres" },
      400
    );
  }

  const { error } = await admin.auth.admin.updateUserById(userId, {
    password: newPassword,
  });
  if (error) return jsonResponse({ error: error.message }, 400);

  return jsonResponse({ ok: true });
});
