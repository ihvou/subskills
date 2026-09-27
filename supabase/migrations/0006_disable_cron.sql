-- Cloud collection agents are dormant for the local-first MVP.
-- Keep the failed-run cleanup job, but remove automatic link search/check jobs.

revoke execute on function public.get_vault_secret(text) from public, anon, authenticated;
grant execute on function public.get_vault_secret(text) to service_role;

do $$
begin
  perform cron.unschedule('link_searcher_daily');
exception
  when others then
    null;
end;
$$;

do $$
begin
  perform cron.unschedule('link_checker_weekly');
exception
  when others then
    null;
end;
$$;
