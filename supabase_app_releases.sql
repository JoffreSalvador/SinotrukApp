-- ============================================================================
-- Sistema de actualización in-app: tabla de releases
-- Ejecutar UNA vez en el SQL Editor del dashboard de Supabase.
-- ============================================================================

create table if not exists public.app_releases (
    id           uuid primary key default gen_random_uuid(),
    version      varchar not null,
    build_number integer not null,
    apk_url      text not null,
    changelog    text not null default '',
    created_at   timestamptz not null default now()
);

-- La app consulta la última versión ANTES de iniciar sesión, por eso la
-- lectura debe estar permitida para anon y authenticated. Solo lectura:
-- las filas se insertan desde este dashboard (service_role / dueño).
alter table public.app_releases enable row level security;

drop policy if exists "app_releases_read_all" on public.app_releases;
create policy "app_releases_read_all" on public.app_releases
    for select to anon, authenticated
    using (true);

-- ============================================================================
-- Por cada versión publicada, insertar UNA fila (ajusta los valores):
--
--   insert into public.app_releases (version, build_number, apk_url, changelog)
--   values (
--     '1.1.0',
--     2,
--     'https://github.com/TU-USUARIO/TU-REPO/releases/download/v1.1.0/app-release.apk',
--     'Qué cambió en esta versión...'
--   );
--
-- Reglas:
--   * build_number debe ser MAYOR al de la versión instalada para que la
--     app ofrezca actualizar (es el versionCode del pubspec: 1.0.0+1 => 1).
--   * Si te equivocas en una fila, bórrala o inserta una correctiva; la app
--     siempre usa la de mayor build_number.
-- ============================================================================
