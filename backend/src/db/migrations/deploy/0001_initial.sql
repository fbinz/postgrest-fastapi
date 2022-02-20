-- Deploy app:0001_initial to pg

begin;

-- create extensions
create extension pgcrypto;
create extension citext;

--- Create roles
-- authentication roles
create role web_authenticator noinherit login password 'iamtheauthenticator';
comment on role web_authenticator is
  'Role that serves as an entry-point for API servers such as PostgREST.';

create role web_anon nologin noinherit;
comment on role web_anon is
  'The role that PostgREST will switch to when a user is not authenticated.';

create role web_user nologin noinherit;
comment on role web_user is
  'Role that PostgREST will switch to for authenticated web users.';

grant web_anon, web_user to web_authenticator;

-- helper roles
create role janitor login password 'iamthejanitor';
grant janitor to developer;
alter default privileges for role janitor revoke execute on functions from public;

--- Create schemas with initial functions
create schema helpers authorization developer;

comment on schema helpers is
  'Schema that contains helper functions, which are useful during development of the application.';

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
select ns.nspname                               as schema,
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
from pg_class cls
       inner join pg_namespace ns on (cls.relnamespace = ns.oid)
where nspname !~ '^pg_'
  and nspname <> 'information_schema'
  and relkind in ('r', 'v', 'f', 's')
  and pg_get_userbyid(cls.relowner) <> 'postgres';
$$;


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
select pg_namespace.nspname              as schema,
       pg_proc.proname                   as name,
       'function'                        as type,
       pg_get_userbyid(pg_proc.proowner) as owner,
       ''                                as info
from pg_proc
       left join pg_namespace on pg_proc.pronamespace = pg_namespace.oid
       left join pg_language on pg_proc.prolang = pg_language.oid
       left join pg_type on pg_type.oid = pg_proc.prorettype
where pg_namespace.nspname not in ('pg_catalog', 'information_schema', 'public');
$$;


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
order by schema, type;
$$;

-- app schema
create schema app authorization developer;

comment on schema app is
  'Schema that contains the state and business logic of the application';

create schema auth authorization developer;

comment on schema auth is
  'Schema that contains functionality related to authentication';

grant usage on schema auth to web_anon, web_user;

-- helper function to get current user id
create function auth.current_user_id() returns integer
  language sql
as
$$
select nullif(current_setting('auth.user_id', true), '')::integer
$$;

grant execute on function auth.current_user_id() to web_user;


-- the main users table
create table app.users (
  user_id  bigserial primary key,
  email    citext not null,
  password text   not null,
  unique (email)
);

alter table app.users
  enable row level security;
alter table app.users
  force row level security;

-- RLS
create policy app_user_own_user on app.users
  using (user_id = auth.current_user_id());

create policy app_login_user on app.users
  using (auth.current_user_id() is null)
  with check (false);

create policy app_user_new_user on app.users
  with check (auth.current_user_id() is null);


-- password hashing
create or replace function app.cryptpassword() returns trigger
  language plpgsql as
$$
begin
  if tg_op = 'INSERT' or new.password <> old.password then
    new.password = crypt(new.password, gen_salt('bf'));
  end if;
  return new;
end;
$$;

create trigger cryptpassword
  before insert or update
  on app.users
  for each row
execute procedure app.cryptpassword();


-- sessions
create table auth.sessions (
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


create or replace function auth.login(email text, password text) returns text
  security definer
  language plpgsql
as
$$
declare
  current_user_id bigint;
  current_token   text;
begin

  -- find user
  select user_id
  from app.users
  where users.email = login.email
    and users.password = crypt(login.password, users.password)
  into current_user_id;

  -- create new session for user
  insert into auth.active_sessions(user_id) values (current_user_id) returning token into current_token;

  -- set user id setting
  perform set_config('auth.user_id', current_user_id::text, true);

  -- return token
  return current_token;
end
$$;

comment on function auth.login is
  'Returns the token for a newly created session or null on failure.';

grant execute on function auth.login(text, text) to web_anon;


-- logout
create or replace function auth.logout(token text)
  returns void
  language plpgsql
  security definer
as
$$
begin

  update auth.sessions
  set expires = clock_timestamp()
  where sessions.token = logout.token;
end
$$;

comment on function auth.logout is
  'Expire the given session.';

grant execute on function auth.logout(text) to web_user;


-- helper function to get the current session user
create function auth.session_user_id(session_token text)
  returns integer
  language sql
  security definer
as
$$
select user_id
from auth.active_sessions
where token = session_token;
$$;

comment on function auth.session_user_id is
  'Returns the id of the user currently authenticated, given a session token';

grant execute on function auth.session_user_id(text) to web_anon;

-- the actual hook
create or replace function auth.pre_request()
  returns void
  language plpgsql
as
$$
declare
  session_token   text;
  session_user_id int;
begin
  select current_setting('request.cookies', true)::json ->> 'session_token'
  into session_token;

  select auth.session_user_id(session_token)
  into session_user_id;

  if session_user_id is not null then
    set local role to web_user;
    perform set_config('auth.user_id', session_user_id::text, true);
  else
    set local role to web_anon;
    perform set_config('auth.user_id', '', true);
  end if;
end;
$$;

comment on function auth.pre_request is
  'Sets the role and user_id based on the session token given as a cookie.';

grant execute on function auth.pre_request() to web_anon;


-- refresh sessions
create function auth.refresh_session(session_token text)
  returns void
  language sql
  security definer
as
$$
update auth.sessions
set expires = default
where token = session_token
  and expires > clock_timestamp()
$$;

comment on function auth.refresh_session is
  'Extend the expiration time of the given session.';

grant execute on function auth.refresh_session(text) to web_user;

-- schema api

create schema api authorization developer;

comment on schema api is
  'Schema that defines an API suitable to be exposed through PostgREST';

grant usage on schema api to developer, web_anon, web_user;

-- basic endpoints

create or replace function api.login(email text, password text)
  returns void
  language plpgsql
  security definer
as
$$
declare
  session_token text;
begin
  select auth.login(email, password) into session_token;

  if session_token is null then
    raise insufficient_privilege
      using detail = 'invalid credentials';
  end if;

  perform set_config(
      'response.headers',
      '[{"Set-Cookie": "session_token='
        || session_token
        || '; Path=/; Max-Age=600; HttpOnly"}]',
      true
    );
end;
$$;

comment on function api.login(text, text) is
  'Creates a new session given valid credentials.';

grant execute on function api.login(text, text) to web_anon, web_user;


create or replace function api.logout()
  returns void
  language plpgsql
as
$$
begin
  perform auth.logout(
      current_setting('request.cookies', true)::json ->> 'session_token'
    );

  perform set_config(
      'response.headers',
      '[{"Set-Cookie": "session_token=; Path=/"}]',
      true
    );
end ;
$$;

comment on function api.logout() is
  'Expires the given session and resets the session cookie.';

grant execute on function api.logout() to web_user;


create function api.refresh_session()
  returns void
  language plpgsql
as
$$
declare
  session_token text;
begin
  select current_setting('request.cookies', false)::json->>'session_token'
  into strict session_token;

  perform auth.refresh_session(session_token);

  perform set_config(
      'response.headers',
      '[{"Set-Cookie": "session_token='
        || session_token
        || '; Path=/; Max-Age=600; HttpOnly"}]',
      true
    );
end;
$$;

comment on function api.refresh_session() is
  'Reset the expiration time of the given session.';

grant execute on function api.refresh_session() to web_user;


create or replace function api.register(email text, password text)
  returns void
  security definer
  language plpgsql
as
$$
begin
  insert into app.users(email, password)
  values (register.email, register.password);

  perform api.login(email, password);
end;
$$;

comment on function api.register(text, text) is
  'Registers a new user and creates a new session for that account.';

grant execute on function api.register(text, text) to web_anon;

create view api.users as
select user_id,
       email
from app.users;

grant select, update(email) on api.users to web_user;

create type api.user as
(
  user_id bigint,
  email   citext
);

create function api.current_user()
  returns api.user
  language sql
  security definer
as
$$
select user_id, email
from app.users
where user_id = auth.current_user_id();
$$;

comment on function api.current_user is
  'Information about the currently authenticated user';

grant execute on function api.current_user() to web_user;

commit;
