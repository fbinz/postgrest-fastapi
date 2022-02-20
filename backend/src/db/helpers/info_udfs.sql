drop function helpers.info_udfs();
create or replace function helpers.info_udfs()
  returns table
  (
    schema text,
    name   text,
    type   text,
    owner  text,
    info   text
  )
  language sql
as
$$
select
  pg_namespace.nspname              as schema,
  pg_proc.proname                   as name,
  'function'                        as type,
  pg_get_userbyid(pg_proc.proowner) as owner,
  ''                                as info
from
  pg_proc
    left join pg_namespace on pg_proc.pronamespace = pg_namespace.oid
    left join pg_language on pg_proc.prolang = pg_language.oid
    left join pg_type on pg_type.oid = pg_proc.prorettype
where
    pg_namespace.nspname not in ('pg_catalog', 'information_schema', 'public');
$$;