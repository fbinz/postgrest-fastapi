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

