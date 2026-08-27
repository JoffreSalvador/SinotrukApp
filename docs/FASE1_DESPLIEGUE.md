# Fase 1 — Backend Supabase: Despliegue y Verificación

## 1. Ejecutar el esquema SQL

1. Abre tu proyecto en https://supabase.com → **SQL Editor**.
2. Copia y ejecuta **completo** el archivo `flutter_supabase_full.sql`.
   (Es idempotente: borra todo lo anterior y crea la base nueva.)

## 2. Crear el admin inicial (bootstrap automático)

- Con la tabla `profiles` vacía, el primer registro se convierte automáticamente
  en `admin` (trigger `handle_new_user`).
- En la app (Fase 3+) aparecerá la pantalla "Primer acceso" solo mientras no
  exista ningún usuario; luego verás el login normal.
- **Importante:** después de crear el admin, deshabilita los registros abiertos:
  `Dashboard > Authentication > Providers > Email > Disable sign-ups`.

## 3. Desplegar las Edge Functions

Requiere [Deno](https://deno.com) y estar logueado con la CLI de Supabase:

```powershell
npm install -g supabase        # o: scoop install supabase
supabase login

# Desde la raíz del proyecto (C:\Users\Joffre\Desktop\SinotrukApp):
supabase functions deploy create-user     --project-ref TU_PROJECT_REF
supabase functions deploy reset-password  --project-ref TU_PROJECT_REF
supabase functions deploy delete-user     --project-ref TU_PROJECT_REF
```

Las funciones usan `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` que Supabase
inyecta automáticamente en el entorno serverless (no van en la app ni en `.env`).

### ¿Qué hace cada función?

| Función          | Body JSON                                    | Descripción |
|------------------|----------------------------------------------|-------------|
| `create-user`    | `{name, username, password, role?}`          | Crea conductor/admin con email sintético `u-<username>@sinotruk.app` |
| `reset-password` | `{user_id, new_password}`                    | Cambia la contraseña de cualquier usuario |
| `delete-user`    | `{user_id}`                                  | Elimina usuario completo (protege último admin y auto-borrado) |

Todas verifican que el llamador (JWT del header `Authorization`) sea un admin
activo antes de operar.

> Habilitar/deshabilitar usuarios NO requiere Edge Function: el admin actualiza
> directamente `profiles.is_active` (la política RLS `profiles_admin_manage`
> lo permite).

## 4. Variables de entorno para Flutter (Fase 2/3)

1. Copia `.env.example` como `.env`.
2. Completa con los valores de `Dashboard > Project Settings > API`:

```
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_ANON_KEY=eyJ...
```

`.env` está en `.gitignore`: nunca lo subas al repositorio. La anon key es
pública por diseño (la seguridad real la dan las políticas RLS).

## 5. Verificación rápida

En el SQL Editor, tras ejecutar el script:

```sql
-- Todas las tablas deben tener rowsecurity = true
select tablename, rowsecurity from pg_tables where schemaname = 'public';

-- Realtime activo en las 10 tablas
select count(*) from pg_publication_tables where pubname = 'supabase_realtime'; -- 10

-- Triggers del gerente instalados
select tgname from pg_trigger where tgname like 'trg_manager_%'; -- 3 filas

-- Aún no hay usuarios
select count(*) from auth.users where email like '%@sinotruk.app'; -- 0
```

Probar una Edge Function desplegada (con un JWT admin válido):

```powershell
curl -X POST "https://TU-PROYECTO.supabase.co/functions/v1/create-user" `
  -H "Authorization: Bearer JWT_DEL_ADMIN" `
  -H "Content-Type: application/json" `
  -d '{\"name\":\"Juan Perez\",\"username\":\"jperez\",\"password\":\"secret123\"}'
```

## Estructura entregada en Fase 1

```
flutter_supabase_full.sql            # Esquema + RLS + triggers gerente + bootstrap admin
supabase/
├── functions/
│   ├── _shared/admin.ts             # Helper service_role + requireAdmin + CORS
│   ├── create-user/index.ts
│   ├── reset-password/index.ts
│   └── delete-user/index.ts
.env.example                         # Plantilla de variables de entorno
.gitignore
```
