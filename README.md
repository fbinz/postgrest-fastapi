### Migrations

Since the approach used here is 'database-first', tables, view and 
stored procedures are actually part of our source code and should be managed 
using a version control system.
To do this, we use the sqitch migration tool, which helps to manage migrations.

The current approach - which still has to prove itself - is to manage all 
tables, views and procedures in .sql files which are grouped into directories 
loosely corresponding to some kind of hierarchy (i.e. first by schema, then 
by functionality if needed).
During development, changes can directly be made to the running database. 
Once the feature is complete, we can check commit diff to see what has 
changed and create a new migration based on this information.
Usually the changes should be quite small, so it should be easy enough to 
track it manually.
Only the very first migration, which sets everything up, is quite elaborate.

To interact with the database the "developer" role should be used. This 
won't exist initially and needs to be created after the database is first 
created.
It can be created using the following commands:
```sql
create role developer login password 'iamthedeveloper' createrole createdb;
grant all privileges on database app_db to developer;
```

### Roles

One of the core principles of [PostgREST](https://postgrest.org) is the usage of
roles to determine privileges. A role can act as a classic user (i.e. someone
who can log in) or as a group (i.e. a group of permissions given to a set of
users).

In the context of a web application a user is typically someone who can log into
using some frontend and with some kind of user profile. While it would be
possible, these users are typically not directly mapped to the database roles.
Instead, there is a single role (i.e. called web_user) that will be used,
whenever a request to the database is made from an authenticated web user.

To authorize access to databases, different mechanisms can be used. One very
powerful one is the concept of row level security (RLS). Following this
approach, every table has associated policies which manage read and write
privileges to individual rows.

To use this approach safely, it is important to know that RLS does not apply for
superusers or the owner of a table. Thus, if a table is created while logged in
as the superuser, the RLS policies will always be ignored. Since views will
always be executed using the view owners' role, they will also ignore RLS by
default.

To prevent this from happening, take care of the following steps:

1. Don't log in as superuser, but instead using the special "developer" role
2. For tables with RLS, always enable force RLS using both
    1. `alter table my_table enable row level security;`
    2. `alter table my_table force row level security;`