alter table public.link_skill_relations
  add column if not exists value_score real
    check (value_score is null or (value_score >= 0 and value_score <= 1)),
  add column if not exists relevance real
    check (relevance is null or (relevance >= 0 and relevance <= 1)),
  add column if not exists teaching_quality real
    check (teaching_quality is null or (teaching_quality >= 0 and teaching_quality <= 1));

comment on column public.link_skill_relations.value_score is
  'Nullable 0-1 combined relevance x teaching-quality score used to rank guided learning-path resources.';
comment on column public.link_skill_relations.relevance is
  'Nullable 0-1 skill relevance component retained for scoring transparency.';
comment on column public.link_skill_relations.teaching_quality is
  'Nullable 0-1 teaching quality component retained for scoring transparency.';

create index if not exists idx_link_skill_relations_value_score
  on public.link_skill_relations (skill_id, skill_level, value_score desc nulls last)
  where is_active;
