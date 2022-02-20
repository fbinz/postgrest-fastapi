drop function if exists helpers.info_all();
create or replace function helpers.info_all()
  returns table (
    schema text,
    name   text,
    type   text,
    owner  text,
    info   text
  )
  language sql
as
$$
select *
from
  helpers.info_tables()
union all
select *
from
  helpers.info_udfs()
order by
  schema, type;
$$