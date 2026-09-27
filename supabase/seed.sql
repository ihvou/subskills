insert into public.moderators (email)
select lower(trim(email))
from unnest(string_to_array(coalesce(current_setting('app.moderator_emails', true), ''), ',')) email
where trim(email) <> ''
on conflict (email) do update set is_active = true;
