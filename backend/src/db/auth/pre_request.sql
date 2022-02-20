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
    select current_setting('request.cookies', true)::json->>'session_token'
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