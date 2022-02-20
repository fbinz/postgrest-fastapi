create view api.users as
select user_id,
       email
from app.users;

grant select, update(email) on api.users to web_user;

