create schema auth authorization developer;

comment on schema auth is
  'Schema that contains functionality related to authentication';

grant usage on schema auth to web_anon, web_user;
