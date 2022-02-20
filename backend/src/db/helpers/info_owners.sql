drop function helpers.info_tables();
create or replace function helpers.info_tables()
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
  ns.nspname                               as schema,
  cls.relname                              as name,
  case
    when relkind = 'r' then 'table'
    when relkind = 'v' then 'view'
    when relkind = 'f' then 'foreign table'
    when relkind = 's' then 'sequence'
    else 'unknown (' || relkind || ')' end as type,
  pg_get_userbyid(cls.relowner)            as owner,
  case
    when relforcerowsecurity then 'rls!'
    when relrowsecurity then 'rls'
    else ''
    end                                    as info
from
  pg_class cls
    inner join pg_namespace ns on (cls.relnamespace = ns.oid)
where
    nspname !~ '^pg_'
and nspname <> 'information_schema'
and relkind in ('r', 'v', 'f', 's')
and pg_get_userbyid(cls.relowner) <> 'postgres';
$$;