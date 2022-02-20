create type api.user as
(
    user_id bigint,
    email   citext
);

create function api.current_user()
    returns api.user
    language sql
    security definer
as
$$
select user_id, email
from app.users
where user_id = auth.current_user_id();
$$;

comment on function api.current_user is
    'Information about the currently authenticated user';

grant execute on function api.current_user() to web_user;