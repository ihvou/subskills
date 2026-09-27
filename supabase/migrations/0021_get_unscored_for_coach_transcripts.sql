begin;

-- Changing a RETURNS TABLE shape requires replacing the function definition.
drop function if exists public.get_unscored_for_coach(text, integer);

create function public.get_unscored_for_coach(
  p_coach_role text,
  p_limit integer default 10
) returns table (
  relation_id uuid,
  source text,
  title text,
  description text,
  url text,
  duration_seconds numeric,
  like_count integer,
  comment_count integer,
  share_count integer,
  favorite_count integer,
  creator_handle text,
  skill_name text,
  category_name text,
  transcript text
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_limit integer;
begin
  if p_coach_role not in ('relevance', 'value') then
    raise exception 'invalid coach_role: %', p_coach_role;
  end if;

  v_limit := least(greatest(coalesce(p_limit, 10), 1), 100);

  return query
    select
      lsr.id as relation_id,
      case
        when lower(l.domain) like '%tiktok.com%' or lower(l.url) like '%tiktok.com%' then 'tiktok'
        when lower(l.domain) like '%youtube.com%'
          or lower(l.domain) like '%youtu.be%'
          or lower(l.url) like '%youtube.com%'
          or lower(l.url) like '%youtu.be%' then 'youtube'
        else 'other'
      end as source,
      l.title,
      l.description,
      l.canonical_url as url,
      l.duration_seconds,
      l.like_count,
      l.comment_count,
      l.share_count,
      l.favorite_count,
      l.creator_handle,
      s.name as skill_name,
      c.name as category_name,
      lt.transcript_text as transcript
    from public.link_skill_relations lsr
    join public.links l on l.id = lsr.link_id
    join public.skills s on s.id = lsr.skill_id
    join public.categories c on c.id = s.category_id
    left join public.link_transcripts lt on lt.link_id = l.id
    where lsr.is_active = true
      and l.is_active = true
      and s.is_active = true
      and c.is_active = true
      and not exists (
        select 1
          from public.curator_votes cv
         where cv.link_skill_relation_id = lsr.id
           and cv.coach_role = p_coach_role
      )
    order by lsr.created_at asc, lsr.id asc
    limit v_limit;
end;
$fn$;

comment on function public.get_unscored_for_coach(text, integer) is
  'Returns active unvoted coach queue rows. Transcript text is exposed only through this security-definer RPC; link_transcripts remains private.';

revoke all on function public.get_unscored_for_coach(text, integer) from public;
grant execute on function public.get_unscored_for_coach(text, integer) to anon, authenticated;

commit;
