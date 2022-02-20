create schema api authorization developer;

comment on schema api is
    'Schema that defines an API suitable to be exposed through PostgREST';

grant usage on schema api to developer, web_anon, web_user;
