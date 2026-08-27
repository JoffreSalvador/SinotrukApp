-- ============================================================================
-- SINOTRUK TRANSPORT - SCRIPT COMPLETO PARA FLUTTER + SUPABASE
-- ============================================================================
-- Ejecutar COMPLETO en el SQL Editor de un proyecto Supabase LIMPIO o
-- existente. Es idempotente: borra todo lo anterior y crea la base nueva.
--
-- CONTENIDO:
--   1. Limpieza total
--   2. Enums
--   3. Tablas e indices
--   4. Funciones auxiliares + trigger de perfiles
--   5. Row Level Security (RLS)
--   6. Privilegios (GRANT) para roles anon/authenticated/service_role
--   7. Supabase Realtime (sincronizacion en vivo)
--
-- NOTAS IMPORTANTES PARA EL DESARROLLO EN FLUTTER:
--
-- * LOGIN POR USERNAME: los usuarios se crean con email sintetico
--       u-<username>@sinotruk.app
--   El prefijo "u-" es OBLIGATORIO: GoTrue rechaza local parts reservados
--   como "admin@" ("Email address is invalid").
--   El login en Flutter: supabase.auth.signInWithPassword(
--       email: 'u-$username@sinotruk.app', password: ...);
--
-- * PERFIL AUTOMATICO: el trigger on_auth_user_created crea la fila en
--   public.profiles a partir de user_metadata al registrar cualquier
--   usuario. Al crear usuarios pasa SIEMPRE metadata:
--       { 'name': ..., 'username': ..., 'role': 'admin'|'driver' }
--
-- * CREAR/ELIMINAR USUARIOS Y RESETEAR PASSWORDS requieren service_role:
--   hazlo con Edge Functions (Deno) invocadas desde Flutter con la sesion
--   del admin. NUNCA incluyas la service_role key en la app.
--
-- * ADMIN INICIAL (BOOTSTRAP AUTOMATICO): con la tabla profiles VACIA,
--   el primer registro que haga la app (pantalla de "Primer acceso") se
--   convierte automaticamente en admin gracias al trigger handle_new_user.
--   Tras crearlo, DESHABILITA los registros abiertos en:
--     Supabase Dashboard > Authentication > Providers > Email > Disable sign-ups
--   Los demas usuarios se crean desde la app via Edge Functions
--   (ver supabase/functions/).
--
-- * CUENTA CON EL GERENTE: los triggers trg_manager_on_* generan
--   automaticamente por cada viaje el 10% "por pagar" y una fila "por
--   cobrar" por cada pasajero/encomienda pagado con Empresa (source='auto').
--   El admin puede ademas añadir valores manuales (source='manual').
-- ============================================================================

-- ============================================================================
-- SECCION 1: LIMPIEZA TOTAL
-- ============================================================================
-- Retira las tablas de la publication de Realtime SOLO si estan presentes
-- (en una base limpia no lo estan y un drop directo daria error 42704).
do $$
declare
    t text;
begin
    foreach t in array array[
        'profiles', 'vehicles', 'vehicle_assignments', 'vehicle_expenses',
        'trips', 'trip_passengers', 'trip_packages', 'trip_expenses',
        'driver_accounts', 'manager_accounts'
    ] loop
        if exists (
            select 1 from pg_publication_tables
            where pubname = 'supabase_realtime'
              and schemaname = 'public'
              and tablename = t
        ) then
            execute format(
                'alter publication supabase_realtime drop table public.%I', t
            );
        end if;
    end loop;
end
$$;

drop table if exists public.trip_packages cascade;
drop table if exists public.trip_passengers cascade;
drop table if exists public.trip_expenses cascade;
drop table if exists public.trips cascade;
drop table if exists public.driver_accounts cascade;
drop table if exists public.manager_accounts cascade;
drop table if exists public.vehicle_assignments cascade;
drop table if exists public.vehicle_expenses cascade;
drop table if exists public.vehicles cascade;
drop table if exists public.profiles cascade;

drop type if exists public.payment_type cascade;
drop type if exists public.expense_category cascade;
drop type if exists public.driver_tx_type cascade;
drop type if exists public.manager_tx_type cascade;

drop function if exists public.handle_new_user() cascade;
drop function if exists public.is_admin() cascade;
drop function if exists public.is_driver() cascade;
drop function if exists public.sync_manager_entries(uuid) cascade;

-- Usuarios sinteticos de instancias anteriores
delete from auth.users where email like '%@sinotruk.app';

-- ============================================================================
-- SECCION 2: ENUMS
-- ============================================================================
create type public.payment_type as enum ('Efectivo', 'Empresa');
create type public.expense_category as enum ('Gasolina', 'Conductor', 'Peajes', 'Otros');
create type public.driver_tx_type as enum ('PagoRecibido', 'PagoRealizado');
create type public.manager_tx_type as enum (
    'PagoRecibido', 'PagoRealizado', 'ManualPorPagar', 'ManualPorCobrar'
);

-- ============================================================================
-- SECCION 3: TABLAS E INDICES
-- ============================================================================

-- Perfiles ligados 1:1 a auth.users
create table public.profiles (
    id          uuid primary key references auth.users(id) on delete cascade,
    name        varchar not null,
    username    varchar unique not null,
    role        varchar not null check (role in ('admin', 'driver')),
    is_active   boolean not null default true,
    created_at  timestamptz not null default now()
);
comment on column public.profiles.role      is '''admin'' o ''driver''';
comment on column public.profiles.is_active is 'Habilitado/deshabilitado por el administrador';

create table public.vehicles (
    id         uuid primary key default gen_random_uuid(),
    plate      varchar unique not null,
    brand      varchar,
    model      varchar,
    created_at timestamptz not null default now()
);

create table public.vehicle_assignments (
    id              uuid primary key default gen_random_uuid(),
    vehicle_id      uuid not null references public.vehicles(id) on delete cascade,
    driver_id       uuid not null references public.profiles(id) on delete cascade,
    is_active       boolean not null default true,
    assigned_date   date not null default current_date,
    unassigned_date date
);

create table public.vehicle_expenses (
    id           uuid primary key default gen_random_uuid(),
    vehicle_id   uuid not null references public.vehicles(id) on delete cascade,
    expense_date date not null,
    detail       varchar not null,
    amount       numeric(10,2) not null check (amount >= 0),
    created_at   timestamptz not null default now()
);

create table public.trips (
    id           uuid primary key default gen_random_uuid(),
    driver_id    uuid not null references public.profiles(id) on delete cascade,
    trip_date    date not null default current_date,
    observations text,
    created_at   timestamptz not null default now()
);

create table public.trip_passengers (
    id             uuid primary key default gen_random_uuid(),
    trip_id        uuid not null references public.trips(id) on delete cascade,
    departure      varchar not null,
    arrival        varchar not null,
    cost           numeric(10,2) not null check (cost >= 0),
    payment_method payment_type not null
);

create table public.trip_packages (
    id             uuid primary key default gen_random_uuid(),
    trip_id        uuid not null references public.trips(id) on delete cascade,
    departure      varchar not null,
    arrival        varchar not null,
    cost           numeric(10,2) not null check (cost >= 0),
    payment_method payment_type not null
);

create table public.trip_expenses (
    id       uuid primary key default gen_random_uuid(),
    trip_id  uuid not null references public.trips(id) on delete cascade,
    category expense_category not null,
    detail   varchar,
    amount   numeric(10,2) not null check (amount >= 0),
    constraint detail_required_for_otros check (category <> 'Otros' or detail is not null)
);
comment on column public.trip_expenses.detail is 'Requerido si la categoria es Otros';

create table public.driver_accounts (
    id         uuid primary key default gen_random_uuid(),
    driver_id  uuid not null references public.profiles(id) on delete cascade,
    tx_type    driver_tx_type not null,
    tx_date    date not null default current_date,
    detail     varchar not null,
    amount     numeric(10,2) not null check (amount >= 0),
    created_at timestamptz not null default now()
);

create table public.manager_accounts (
    id              uuid primary key default gen_random_uuid(),
    tx_type         manager_tx_type not null,
    tx_date         date not null default current_date,
    detail          varchar not null,
    amount          numeric(10,2) not null check (amount >= 0),
    -- 'manual' (ingresado por el admin) o 'auto' (generado por trigger)
    source          varchar not null default 'manual'
                    check (source in ('manual', 'auto')),
    related_trip_id uuid references public.trips(id) on delete cascade,
    created_at      timestamptz not null default now()
);

create index idx_trips_driver_date        on public.trips(driver_id, trip_date desc);
create index idx_trips_date               on public.trips(trip_date desc);
create index idx_passengers_trip          on public.trip_passengers(trip_id);
create index idx_packages_trip            on public.trip_packages(trip_id);
create index idx_trip_expenses_trip       on public.trip_expenses(trip_id);
create index idx_vehicle_expenses_vehicle on public.vehicle_expenses(vehicle_id, expense_date desc);
create index idx_assignments_driver       on public.vehicle_assignments(driver_id, is_active);
create index idx_driver_accounts_driver   on public.driver_accounts(driver_id, tx_date desc);
create index idx_manager_accounts_date    on public.manager_accounts(tx_date desc);
create index idx_manager_accounts_trip    on public.manager_accounts(related_trip_id);

-- ============================================================================
-- SECCION 4: FUNCIONES Y TRIGGER DE PERFILES
-- ============================================================================

-- Rol del usuario actual (security definer evita recursion de RLS)
create or replace function public.is_admin()
returns boolean
language sql stable security definer set search_path = public as $$
    select exists (
        select 1 from public.profiles
        where id = auth.uid() and role = 'admin' and is_active
    );
$$;

create or replace function public.is_driver()
returns boolean
language sql stable security definer set search_path = public as $$
    select exists (
        select 1 from public.profiles
        where id = auth.uid() and role = 'driver' and is_active
    );
$$;

-- Permite a la app (incluso anonima) saber si aun no existe ningun usuario,
-- para mostrar la pantalla de "Primer acceso" (bootstrap del admin).
create or replace function public.app_needs_bootstrap()
returns boolean
language sql stable security definer set search_path = public as $$
    select not exists (select 1 from public.profiles limit 1);
$$;

grant execute on function public.app_needs_bootstrap() to anon, authenticated;

-- Perfil automatico al registrarse (null-safe: sin metadata usa el email).
-- BOOTSTRAP DEL ADMIN: si la tabla profiles esta VACIA, el primer usuario
-- registrado se convierte automaticamente en 'admin' sin importar la
-- metadata enviada. A partir del segundo registro, todos son 'driver'
-- salvo que los cree un admin via Edge Function.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    v_is_first boolean;
begin
    select not exists (select 1 from public.profiles) into v_is_first;

    insert into public.profiles (id, name, username, role, is_active)
    values (
        new.id,
        coalesce(nullif(new.raw_user_meta_data ->> 'name', ''),
                 split_part(new.email, '@', 1)),
        coalesce(nullif(new.raw_user_meta_data ->> 'username', ''),
                 split_part(new.email, '@', 1)),
        case when v_is_first then 'admin'
             else coalesce(nullif(new.raw_user_meta_data ->> 'role', ''), 'driver')
        end,
        true  -- todos nacen habilitados; el admin puede deshabilitar luego
    );
    return new;
end;
$$;

create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();

-- ============================================================================
-- SECCION 4B: ASIENTOS AUTOMATICOS DE LA CUENTA CON EL GERENTE
-- ============================================================================
-- Por cada viaje se recalculan (borrando y regenerando las filas 'auto'):
--   * ManualPorPagar : 10% del ingreso total del viaje (pasajeros+encomiendas)
--   * ManualPorCobrar: una fila por cada pasajero/encomienda con pago 'Empresa'
-- Las filas manuales que añada el admin NUNCA se tocan (source='manual').
create or replace function public.sync_manager_entries()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    p_trip_id   uuid := coalesce(new.id, old.id);
    v_trip_date date;
    v_income    numeric(10,2);
begin
    select trip_date into v_trip_date from public.trips where id = p_trip_id;
    if v_trip_date is null then
        return null;  -- el viaje fue borrado; la FK en cascade limpia las filas auto
    end if;

    delete from public.manager_accounts
    where source = 'auto' and related_trip_id = p_trip_id;

    select coalesce(sum(cost), 0) into v_income
    from public.trip_passengers where trip_id = p_trip_id;
    v_income := v_income + coalesce((
        select sum(cost) from public.trip_packages where trip_id = p_trip_id
    ), 0);

    if v_income > 0 then
        insert into public.manager_accounts
            (tx_type, tx_date, detail, amount, source, related_trip_id)
        values ('ManualPorPagar', v_trip_date,
                '10% gerente - viaje ' || p_trip_id,
                round(v_income * 0.10, 2), 'auto', p_trip_id);
    end if;

    insert into public.manager_accounts
        (tx_type, tx_date, detail, amount, source, related_trip_id)
    select 'ManualPorCobrar', v_trip_date,
           'Empresa: ' || departure || ' -> ' || arrival,
           cost, 'auto', p_trip_id
    from public.trip_passengers
    where trip_id = p_trip_id and payment_method = 'Empresa';

    insert into public.manager_accounts
        (tx_type, tx_date, detail, amount, source, related_trip_id)
    select 'ManualPorCobrar', v_trip_date,
           'Empresa (encomienda): ' || departure || ' -> ' || arrival,
           cost, 'auto', p_trip_id
    from public.trip_packages
    where trip_id = p_trip_id and payment_method = 'Empresa';

    return null;
end;
$$;

create trigger trg_manager_on_trips
    after insert or update or delete on public.trips
    for each row execute function public.sync_manager_entries();

create trigger trg_manager_on_passengers
    after insert or update or delete on public.trip_passengers
    for each row execute function public.sync_manager_entries();

create trigger trg_manager_on_packages
    after insert or update or delete on public.trip_packages
    for each row execute function public.sync_manager_entries();

-- ============================================================================
-- SECCION 5: ROW LEVEL SECURITY
-- ============================================================================
alter table public.profiles            enable row level security;
alter table public.vehicles            enable row level security;
alter table public.vehicle_assignments enable row level security;
alter table public.vehicle_expenses    enable row level security;
alter table public.trips               enable row level security;
alter table public.trip_passengers     enable row level security;
alter table public.trip_packages       enable row level security;
alter table public.trip_expenses       enable row level security;
alter table public.driver_accounts     enable row level security;
alter table public.manager_accounts    enable row level security;

-- ---------- profiles ----------
create policy "profiles_select_own_or_admin" on public.profiles
    for select using (id = auth.uid() or public.is_admin());

create policy "profiles_admin_manage" on public.profiles
    for all using (public.is_admin()) with check (public.is_admin());

-- ---------- vehicles ----------
create policy "vehicles_read_authenticated" on public.vehicles
    for select using (auth.role() = 'authenticated');

create policy "vehicles_admin_write" on public.vehicles
    for all using (public.is_admin()) with check (public.is_admin());

-- ---------- vehicle_assignments ----------
create policy "assignments_read_authenticated" on public.vehicle_assignments
    for select using (auth.role() = 'authenticated');

create policy "assignments_admin_write" on public.vehicle_assignments
    for all using (public.is_admin()) with check (public.is_admin());

-- ---------- vehicle_expenses ----------
create policy "vehicle_expenses_admin_all" on public.vehicle_expenses
    for all using (public.is_admin()) with check (public.is_admin());

-- ---------- trips ----------
create policy "trips_insert_own" on public.trips
    for insert with check (driver_id = auth.uid() and public.is_driver());

create policy "trips_select_own_or_admin" on public.trips
    for select using (driver_id = auth.uid() or public.is_admin());

create policy "trips_update_own_or_admin" on public.trips
    for update using (driver_id = auth.uid() or public.is_admin())
    with check (driver_id = auth.uid() or public.is_admin());

create policy "trips_delete_own_or_admin" on public.trips
    for delete using (driver_id = auth.uid() or public.is_admin());

-- ---------- trip_passengers / trip_packages / trip_expenses ----------
create policy "passengers_trip_owner_all" on public.trip_passengers
    for all using (
        exists (select 1 from public.trips t
                where t.id = trip_id and (t.driver_id = auth.uid() or public.is_admin()))
    ) with check (
        exists (select 1 from public.trips t
                where t.id = trip_id and (t.driver_id = auth.uid() or public.is_admin()))
    );

create policy "packages_trip_owner_all" on public.trip_packages
    for all using (
        exists (select 1 from public.trips t
                where t.id = trip_id and (t.driver_id = auth.uid() or public.is_admin()))
    ) with check (
        exists (select 1 from public.trips t
                where t.id = trip_id and (t.driver_id = auth.uid() or public.is_admin()))
    );

create policy "trip_expenses_trip_owner_all" on public.trip_expenses
    for all using (
        exists (select 1 from public.trips t
                where t.id = trip_id and (t.driver_id = auth.uid() or public.is_admin()))
    ) with check (
        exists (select 1 from public.trips t
                where t.id = trip_id and (t.driver_id = auth.uid() or public.is_admin()))
    );

-- ---------- driver_accounts ----------
create policy "driver_accounts_insert_own" on public.driver_accounts
    for insert with check (driver_id = auth.uid() and public.is_driver());

create policy "driver_accounts_select_own_or_admin" on public.driver_accounts
    for select using (driver_id = auth.uid() or public.is_admin());

create policy "driver_accounts_update_own" on public.driver_accounts
    for update using (driver_id = auth.uid())
    with check (driver_id = auth.uid());

create policy "driver_accounts_delete_own" on public.driver_accounts
    for delete using (driver_id = auth.uid());

-- ---------- manager_accounts ----------
create policy "manager_accounts_admin_all" on public.manager_accounts
    for all using (public.is_admin()) with check (public.is_admin());

-- ============================================================================
-- SECCION 6: PRIVILEGIOS (GRANT)
-- Sin esto Postgres rechaza con "permission denied" ANTES de evaluar RLS.
-- ============================================================================
grant usage on schema public to anon, authenticated, service_role;
grant all on all tables in schema public to anon, authenticated, service_role;
grant all on all sequences in schema public to anon, authenticated, service_role;
grant all on all functions in schema public to anon, authenticated, service_role;

alter default privileges for role postgres in schema public
    grant all on tables to anon, authenticated, service_role;
alter default privileges for role postgres in schema public
    grant all on sequences to anon, authenticated, service_role;
alter default privileges for role postgres in schema public
    grant all on functions to anon, authenticated, service_role;

-- ============================================================================
-- SECCION 7: SUPABASE REALTIME (datos en vivo en todos los dispositivos)
-- ============================================================================
alter publication supabase_realtime add table public.profiles;
alter publication supabase_realtime add table public.vehicles;
alter publication supabase_realtime add table public.vehicle_assignments;
alter publication supabase_realtime add table public.vehicle_expenses;
alter publication supabase_realtime add table public.trips;
alter publication supabase_realtime add table public.trip_passengers;
alter publication supabase_realtime add table public.trip_packages;
alter publication supabase_realtime add table public.trip_expenses;
alter publication supabase_realtime add table public.driver_accounts;
alter publication supabase_realtime add table public.manager_accounts;

-- Para recibir old_record en eventos DELETE (necesario para cascadas en app)
alter table public.profiles            replica identity full;
alter table public.vehicles            replica identity full;
alter table public.vehicle_assignments replica identity full;
alter table public.vehicle_expenses    replica identity full;
alter table public.trips               replica identity full;
alter table public.trip_passengers     replica identity full;
alter table public.trip_packages       replica identity full;
alter table public.trip_expenses       replica identity full;
alter table public.driver_accounts     replica identity full;
alter table public.manager_accounts    replica identity full;

-- ============================================================================
-- FIN. Verificaciones rapidas:
--   select tablename, rowsecurity from pg_tables where schemaname='public';
--   select * from pg_publication_tables where pubname='supabase_realtime';
--   select count(*) from auth.users where email like '%@sinotruk.app'; -- 0
--
-- SIGUIENTE PASO: ejecutar la app, usar "Primer acceso" para crear el admin,
-- luego deshabilitar sign-ups abiertos en el Dashboard.
-- ============================================================================
