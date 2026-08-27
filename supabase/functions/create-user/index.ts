// Crea un usuario (conductor) con username + password definidos por el admin.
// Body: { name, username, password, role?: 'driver' | 'admin' }
import { corsHeaders, jsonResponse, requireAdmin, syntheticEmail } from "../_shared/admin.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders() });
  if (req.method !== "POST") return jsonResponse({ error: "Método no permitido" }, 405);

  const adminOrError = await requireAdmin(req);
  if (adminOrError instanceof Response) return adminOrError;
  const { admin } = adminOrError;

  let body: { name?: string; username?: string; password?: string; role?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "JSON inválido" }, 400);
  }

  const name = body.name?.trim();
  const username = body.username?.trim().toLowerCase();
  const password = body.password ?? "";
  const role = body.role === "admin" ? "admin" : "driver";

  if (!name || !username || !password) {
    return jsonResponse({ error: "name, username y password son obligatorios" }, 400);
  }
  if (!/^[a-z0-9._-]{3,30}$/.test(username)) {
    return jsonResponse(
      { error: "El usuario debe tener 3-30 caracteres (letras, números, . _ -)" },
      400
    );
  }
  if (password.length < 6) {
    return jsonResponse({ error: "La contraseña debe tener al menos 6 caracteres" }, 400);
  }

  // Validar que el username no exista ya en profiles
  const { data: existing } = await admin
    .from("profiles")
    .select("id")
    .eq("username", username)
    .maybeSingle();
  if (existing) {
    return jsonResponse({ error: `El usuario "${username}" ya existe` }, 409);
  }

  const { data, error } = await admin.auth.admin.createUser({
    email: syntheticEmail(username),
    password,
    email_confirm: true,
    user_metadata: { name, username, role },
  });

  if (error) return jsonResponse({ error: error.message }, 400);

  return jsonResponse({ user: { id: data.user.id, username, name, role } });
});
