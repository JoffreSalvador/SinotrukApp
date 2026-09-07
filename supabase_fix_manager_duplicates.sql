-- ============================================================================
-- Limpieza de filas 'auto' DUPLICADAS en public.manager_accounts
-- Ejecutar en el SQL Editor del dashboard de Supabase, por pasos.
-- ============================================================================

-- PASO 1 (solo lectura): ver cuántas filas 'auto' duplicadas hay.
-- Duplicada = mismo viaje, tipo, fecha, detalle y valor, quedándose con la
-- más antigua (created_at, id).
select count(*) as duplicadas_para_borrar from (
  select id, row_number() over (
    partition by related_trip_id, tx_type, tx_date, detail, amount
    order by created_at, id
  ) as rn
  from public.manager_accounts
  where source = 'auto'
) d where rn > 1;

-- PASO 2 (borrado): conserva una fila por grupo y elimina el resto.
-- Las filas manuales (source='manual') NUNCA se tocan.
delete from public.manager_accounts
where id in (
  select id from (
    select id, row_number() over (
      partition by related_trip_id, tx_type, tx_date, detail, amount
      order by created_at, id
    ) as rn
    from public.manager_accounts
    where source = 'auto'
  ) d where rn > 1
);

-- PASO 3 (verificación): debe devolver 0.
select count(*) as duplicadas_restantes from (
  select id, row_number() over (
    partition by related_trip_id, tx_type, tx_date, detail, amount
    order by created_at, id
  ) as rn
  from public.manager_accounts
  where source = 'auto'
) d where rn > 1;

-- ============================================================================
-- NOTA: la app ya ignora las filas 'auto' de la tabla (las calcula en
-- cliente), así que este borrado solo deja la tabla limpia; lo que se ve
-- en la pestaña Gerente queda correcto con o sin este script.
-- El trigger sync_manager_entries() de flutter_supabase_full.sql ya incluye
-- candado anti-duplicados para futuras escrituras (aplicar ese archivo o el
-- fragmento del candado si el trigger en la nube es anterior).
-- ============================================================================
