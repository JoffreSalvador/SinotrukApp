// Elimina un usuario por completo (auth.users + profiles en cascada).
// Protege contra auto-borrado y contra borrar al último admin.
// Body: { user_id }
import { corsHeaders, jsonResponse, requireAdmin } from "../_shared/admin.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders() });
  if (req.method !== "POST") return jsonResponse({ error: "Método no permitido" }, 405);

  const adminOrError = await requireAdmin(req);
  if (adminOrError instanceof Response) return adminOrError;
  const { admin, callerId } = adminOrError;

  let body: { user_id?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "JSON inválido" }, 400);
  }

  const userId = body.user_id?.trim();
  if (!userId) return jsonResponse({ error: "user_id es obligatorio" }, 400);
  if (userId === callerId) {
    return jsonResponse({ error: "No puedes eliminar tu propia cuenta" }, 400);
  }

  // ¿Es el último admin activo?
  const { data: target } = await admin
    .from("profiles")
    .select("role")
    .eq("id", userId)
    .single();

  if (target?.role === "admin") {
    const { count } = await admin
      .from("profiles")
      .select("id", { count: "exact", head: true })
      .eq("role", "admin")
      .eq("is_active", true);
    if ((count ?? 0) <= 1) {
      return jsonResponse({ error: "No se puede eliminar el último administrador" }, 400);
    }
  }

  const { error } = await admin.auth.admin.deleteUser(userId);
  if (error) return jsonResponse({ error: error.message }, 400);

  return jsonResponse({ ok: true });
});
