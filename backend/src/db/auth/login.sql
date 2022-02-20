create or replace function auth.login(email text, password text) returns text
  security definer
  language plpgsql
as
$$
declare
  current_user_id bigint;
  current_token   text;
begin

  -- find user
  select user_id
  from app.users
  where users.email = login.email
    and users.password = crypt(login.password, users.password)
  into current_user_id;

  -- create new session for user
  insert into auth.active_sessions(user_id) values (current_user_id) returning token into current_token;

  -- set user id setting
  perform set_config('auth.user_id', current_user_id::text, true);

  -- return token
  return current_token;
end
$$;

comment on function auth.login is
    'Returns the token for a newly created session or null on failure.';

grant execute on function auth.login(text, text) to web_anon;

