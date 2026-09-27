-- Direct revalidation path: this trigger calls the Vercel /api/revalidate
-- endpoint stored in Vault. There is intentionally no revalidate-web Edge
-- Function hop.
create or replace function public.notify_revalidation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_skill_slug text;
  v_category_slug text;
  v_url text;
  v_secret text;
begin
  select s.slug, c.slug into v_skill_slug, v_category_slug
  from public.skills s
  join public.categories c on c.id = s.category_id
  where s.id = coalesce(new.skill_id, old.skill_id);

  v_url := public.get_vault_secret('revalidate_url');
  v_secret := public.get_vault_secret('revalidate_secret');

  if v_url is not null and v_url <> '' and v_secret is not null and v_secret <> '' then
    perform net.http_post(
      url := v_url,
      headers := jsonb_build_object(
        'Content-Type','application/json',
        'x-revalidate-secret', v_secret
      ),
      body := jsonb_build_object('category', v_category_slug, 'skill', v_skill_slug)
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_lsr_revalidate on public.link_skill_relations;
create trigger trg_lsr_revalidate
after insert or update on public.link_skill_relations
for each row execute function public.notify_revalidation();

create or replace function public.enqueue_link_searcher_jobs()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_function_url text := public.get_vault_secret('supabase_functions_url');
  v_service_role_key text := public.get_vault_secret('service_role_key');
  v_skill record;
  v_day integer := extract(dow from now())::integer;
begin
  if v_function_url is null or v_function_url = '' or v_service_role_key is null or v_service_role_key = '' then
    return;
  end if;

  for v_skill in
    select id
    from public.skills
    where is_active
      and mod(abs(hashtext(id::text)), 7) = v_day
    order by created_at
    limit 3
  loop
    perform net.http_post(
      url := v_function_url || '/link-searcher',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || v_service_role_key
      ),
      body := jsonb_build_object('skill_id', v_skill.id)
    );
  end loop;
end;
$$;

create or replace function public.enqueue_link_checker_jobs()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_function_url text := public.get_vault_secret('supabase_functions_url');
  v_service_role_key text := public.get_vault_secret('service_role_key');
  v_relation record;
begin
  if v_function_url is null or v_function_url = '' or v_service_role_key is null or v_service_role_key = '' then
    return;
  end if;

  for v_relation in
    select id
    from public.link_skill_relations
    where is_active
      and coalesce(last_checked_at, 'epoch'::timestamptz) < now() - interval '30 days'
    order by coalesce(last_checked_at, 'epoch'::timestamptz)
    limit 50
  loop
    perform net.http_post(
      url := v_function_url || '/link-checker',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || v_service_role_key
      ),
      body := jsonb_build_object('relation_id', v_relation.id)
    );
  end loop;
end;
$$;

select cron.schedule(
  'link_searcher_daily',
  '0 4 * * *',
  $$select public.enqueue_link_searcher_jobs();$$
)
where not exists (select 1 from cron.job where jobname = 'link_searcher_daily');

select cron.schedule(
  'link_checker_weekly',
  '0 5 * * 0',
  $$select public.enqueue_link_checker_jobs();$$
)
where not exists (select 1 from cron.job where jobname = 'link_checker_weekly');

select cron.schedule(
  'cleanup_failed_runs',
  '0 3 * * *',
  $$update public.agent_runs set status = 'failed', error_message = 'Marked failed after 2h timeout', completed_at = now() where status = 'started' and started_at < now() - interval '2 hours';$$
)
where not exists (select 1 from cron.job where jobname = 'cleanup_failed_runs');
