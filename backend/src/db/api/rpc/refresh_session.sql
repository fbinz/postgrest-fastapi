create or replace function api.refresh_session()
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