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