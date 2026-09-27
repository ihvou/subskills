begin;

create extension if not exists pgtap;

select plan(2);

set local request.jwt.claims = '{"email":"self-promoted@example.com","user_metadata":{"role":"moderator"}}';
select is(public.is_moderator(), false, 'user_metadata role does not grant moderator access');

insert into public.moderators (email, is_active)
values ('allowed@example.com', true)
on conflict (email) do update set is_active = true;

set local request.jwt.claims = '{"email":"allowed@example.com","user_metadata":{}}';
select is(public.is_moderator(), true, 'moderators table grants moderator access');

select * from finish();
rollback;
