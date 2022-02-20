-- helper function to get current user id
create function auth.current_user_id() returns integer
  language sql
as
$$
select nullif(current_setting('auth.user_id', true), '')::integer
$$;

grant execute on function auth.current_user_id() to web_user;

