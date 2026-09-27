insert into storage.buckets (id, name, public)
values ('link-thumbnails', 'link-thumbnails', true)
on conflict (id) do update set public = true;

create policy "link thumbnails are publicly readable"
on storage.objects for select
to anon, authenticated
using (bucket_id = 'link-thumbnails');

create policy "service role manages link thumbnails"
on storage.objects for all
to service_role
using (bucket_id = 'link-thumbnails')
with check (bucket_id = 'link-thumbnails');
