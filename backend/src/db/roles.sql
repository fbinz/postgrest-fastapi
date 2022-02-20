-- developer role, needs to be set up once, manually, since sqitch will use this role when applying
-- migrations
create role developer login password 'iamthedeveloper' createrole createdb;
comment on role developer is
  'Non-superuser role, that should be used during development and migrations to create build everyhing up.';

grant all privileges on database app_db to developer;
-- grant usage on schema api, helpers, auth, app to developer;
-- grant execute on all functions in schema api, helpers, auth, app to developer;

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
alter default privileges for role janitor revoke execute on functions from public;
