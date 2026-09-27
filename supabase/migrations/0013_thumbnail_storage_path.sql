begin;

alter table public.links
add column if not exists thumbnail_storage_path text;

insert into storage.buckets (id, name, public)
values ('thumbnails', 'thumbnails', true)
on conflict (id) do update set public = true;

drop policy if exists "cached thumbnails are publicly readable" on storage.objects;
create policy "cached thumbnails are publicly readable"
on storage.objects for select
to anon, authenticated
using (bucket_id = 'thumbnails');

drop policy if exists "service role manages cached thumbnails" on storage.objects;
create policy "service role manages cached thumbnails"
on storage.objects for all
to service_role
using (bucket_id = 'thumbnails')
with check (bucket_id = 'thumbnails');

commit;
