-- sessions
create table auth.sessions
(
    token   text        not null primary key default encode(gen_random_bytes(32), 'base64'),
    user_id integer     not null references app.users,
    created timestamptz not null             default clock_timestamp(),
    expires timestamptz not null             default clock_timestamp() + '15min'::interval,
    check (expires > created)
);

comment on table auth.sessions is
    'User sessions, both active and expired ones.';

create view auth.active_sessions as
select token,
       user_id,
       created,
       expires
from auth.sessions
where expires > clock_timestamp()
        with local check option;

create index on auth.sessions (expires); -- to enable finding expired session fast

create function auth.clean_sessions()
    returns void
    language sql
    security definer
as
$$
delete
from auth.sessions
where expires < clock_timestamp() - '1day'::interval;
$$;

grant usage on schema auth to janitor;
grant execute on function auth.clean_sessions() to janitor;

