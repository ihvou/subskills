begin;

create or replace function public.apply_tiktok_link_metadata(
  p_link_id uuid,
  p_creator_platform text,
  p_creator_handle text,
  p_creator_nickname text,
  p_creator_bio text,
  p_creator_bio_link text,
  p_followers_count integer,
  p_following_count integer,
  p_videos_count integer,
  p_verified boolean,
  p_authority_score numeric,
  p_duration_seconds numeric,
  p_like_count integer,
  p_comment_count integer,
  p_share_count integer,
  p_favorite_count integer,
  p_creator_url text,
  p_scoring_strategy text,
  p_thumbnail_storage_path text,
  p_thumbnail_url text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_creator_id uuid;
begin
  if nullif(p_creator_handle, '') is not null then
    insert into public.creators (
      platform,
      handle,
      nickname,
      bio,
      bio_link,
      followers_count,
      following_count,
      videos_count,
      verified,
      authority_score,
      last_probed_at,
      is_active
    )
    values (
      coalesce(nullif(p_creator_platform, ''), 'tiktok'),
      lower(regexp_replace(p_creator_handle, '^@', '')),
      nullif(p_creator_nickname, ''),
      nullif(p_creator_bio, ''),
      nullif(p_creator_bio_link, ''),
      p_followers_count,
      p_following_count,
      p_videos_count,
      coalesce(p_verified, false),
      p_authority_score,
      now(),
      true
    )
    on conflict (platform, handle) do update set
      nickname = excluded.nickname,
      bio = excluded.bio,
      bio_link = excluded.bio_link,
      followers_count = excluded.followers_count,
      following_count = excluded.following_count,
      videos_count = excluded.videos_count,
      verified = excluded.verified,
      authority_score = excluded.authority_score,
      last_probed_at = excluded.last_probed_at,
      is_active = true
    returning id into v_creator_id;
  end if;

  update public.links
  set
    duration_seconds = p_duration_seconds,
    like_count = p_like_count,
    comment_count = p_comment_count,
    share_count = p_share_count,
    favorite_count = p_favorite_count,
    creator_handle = nullif(p_creator_handle, ''),
    creator_url = nullif(p_creator_url, ''),
    creator_id = v_creator_id,
    scoring_strategy = coalesce(nullif(p_scoring_strategy, ''), 'engagement_authority'),
    thumbnail_storage_path = nullif(p_thumbnail_storage_path, ''),
    thumbnail_url = nullif(p_thumbnail_url, ''),
    preview_status = case
      when nullif(p_thumbnail_storage_path, '') is not null or nullif(p_thumbnail_url, '') is not null then 'fetched'
      else 'pending'
    end,
    fetched_at = case
      when nullif(p_thumbnail_storage_path, '') is not null or nullif(p_thumbnail_url, '') is not null then now()
      else null
    end
  where id = p_link_id;

  if not found then
    raise exception 'Link % not found', p_link_id using errcode = 'P0002';
  end if;

  return v_creator_id;
end;
$$;

grant execute on function public.apply_tiktok_link_metadata(
  uuid,
  text,
  text,
  text,
  text,
  text,
  integer,
  integer,
  integer,
  boolean,
  numeric,
  numeric,
  integer,
  integer,
  integer,
  integer,
  text,
  text,
  text,
  text
) to service_role;

commit;
