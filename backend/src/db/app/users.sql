-- the main users table
create table app.users (
  user_id  bigserial primary key,
  email    citext not null,
  password text   not null,
  unique (email)
);

alter table app.users
  enable row level security;
alter table app.users
  force row level security;

-- RLS
create policy app_user_own_user on app.users
  using (user_id = auth.current_user_id());

create policy app_login_user on app.users
  using (auth.current_user_id() is null)
  with check (false);

create policy app_user_new_user on app.users
  with check (auth.current_user_id() is null);


-- password hashing
create or replace function app.cryptpassword() returns trigger
  language plpgsql as
$$
begin
  if tg_op = 'INSERT' or new.password <> old.password then
    new.password = crypt(new.password, gen_salt('bf'));
  end if;
  return new;
end;
$$;

create trigger cryptpassword
  before insert or update
  on app.users
  for each row
execute procedure app.cryptpassword();
