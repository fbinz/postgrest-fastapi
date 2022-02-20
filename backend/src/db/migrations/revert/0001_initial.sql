-- Revert app:0001_initial from pg

BEGIN;

drop schema api, app, auth, helpers cascade;
drop owned by janitor;
drop role web_anon, web_authenticator, web_user, janitor;
drop extension pgcrypto, citext;

COMMIT;
