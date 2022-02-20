create or replace function api.register(email text, password text)
    returns void
    security definer
    language plpgsql
as
$$
begin
    insert into app.users(email, password)
    values (register.email, register.password);

    perform api.login(email, password);
end;
$$;

comment on function api.register(text, text) is
    'Registers a new user and creates a new session for that account.';

grant execute on function api.register(text, text) to web_anon;
