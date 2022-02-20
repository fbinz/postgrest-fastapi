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
