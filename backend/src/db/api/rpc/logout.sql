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