import {
  badmintonCategory,
  fallbackCategories,
  fallbackResources,
  fallbackSkills,
  sortResources,
  type CategorySummary,
  type ContributorProfileSummary,
  type LinkResource,
  type ResourceSort,
  type SkillResource,
  type SkillSummary,
} from "@skillsaggregator/shared";
import { getSupabase } from "./supabase";
import { normalizeThumbnailUrl } from "./thumbnails";

export type DiscoverSkillTile = {
  skill: SkillSummary;
  latest_thumbnail: string | null;
};

export type DiscoverCategorySection = {
  category: CategorySummary;
  skills: DiscoverSkillTile[];
};

/**
 * Curriculum order — the sequence someone would actually work through a sport,
 * which is what `learning_order` records. Queries return skills by name, and
 * alphabetical order is meaningless for skills: it is why Discover showed Padel
 * "How to choose a padel racket" and hid "Volley technique" at #24 of 24 behind
 * a 12-skill cap. Falls back to name so a category nobody has ordered still
 * comes out stable rather than arbitrary.
 */
export function byLearningOrder(a: SkillSummary, b: SkillSummary): number {
  const left = a.learning_order ?? Number.MAX_SAFE_INTEGER;
  const right = b.learning_order ?? Number.MAX_SAFE_INTEGER;
  return left === right ? a.name.localeCompare(b.name) : left - right;
}

export type SkillSummaryPoint = { point: string; support: number };
export type SkillTechniqueSummary = {
  consensus: SkillSummaryPoint[];
  mistakes: SkillSummaryPoint[];
  source_count: number;
  used_count: number;
  generated_at: string;
};

export type UserSkillProgress = {
  skill_id: string;
  total_count: number;
  watched_count: number;
  target: number;
  completed: boolean;
  percent: number;
};

const RESOURCE_LINK_SELECT =
  "id, url, canonical_url, domain, title, description, thumbnail_url, thumbnail_storage_path, duration_seconds, like_count, comment_count, share_count, favorite_count, creator_handle, creator_url, scoring_strategy, content_type, created_at, contributor_profile:contributor_profiles(id, slug, display_name, avatar_url, accepted_count)";
const RELATION_VOTE_SELECT = "upvote_count, downvote_count, vote_score, value_score, curator_score, curator_reviews, user_score, combined_score, rank_key, coach_take";

function shapeLinkWithContributor<
  TLink extends {
    id: string;
    contributor_profile?: unknown;
    domain?: string | null;
    title?: string | null;
    description?: string | null;
    thumbnail_url?: string | null;
    thumbnail_storage_path?: string | null;
    canonical_url?: string | null;
    url?: string | null;
    duration_seconds?: number | null;
    like_count?: number | null;
    comment_count?: number | null;
    share_count?: number | null;
    favorite_count?: number | null;
    creator_handle?: string | null;
    creator_url?: string | null;
    created_at?: string | null;
    scoring_strategy?: string | null;
    content_type?: string | null;
  },
>(link: TLink) {
  const contributor = Array.isArray(link.contributor_profile)
    ? link.contributor_profile[0]
    : link.contributor_profile;
  const normalizedContributor: ContributorProfileSummary | null =
    contributor && typeof contributor === "object" && "id" in contributor
      ? {
          id: String(contributor.id),
          slug:
            "slug" in contributor && typeof contributor.slug === "string"
              ? contributor.slug
              : "",
          display_name:
            "display_name" in contributor && typeof contributor.display_name === "string"
              ? contributor.display_name
              : "Contributor",
          avatar_url:
            "avatar_url" in contributor && typeof contributor.avatar_url === "string"
              ? contributor.avatar_url
              : null,
          accepted_count:
            "accepted_count" in contributor && typeof contributor.accepted_count === "number"
              ? contributor.accepted_count
              : 0,
        }
      : null;
  const url = link.url ?? link.canonical_url ?? "";
  return {
    ...link,
    url,
    canonical_url: link.canonical_url ?? url,
    domain: link.domain ?? "",
    title: link.title ?? null,
    description: link.description ?? null,
    thumbnail_url: normalizeThumbnailUrl(
      link.thumbnail_storage_path ?? link.thumbnail_url ?? null,
      link.canonical_url ?? url,
      link.thumbnail_storage_path ? link.thumbnail_url ?? null : null,
    ),
    ...(link.scoring_strategy === "transcript_llm" || link.scoring_strategy === "engagement_authority"
      ? { scoring_strategy: link.scoring_strategy }
      : {}),
    content_type:
      link.content_type === "video" ||
      link.content_type === "article" ||
      link.content_type === "podcast" ||
      link.content_type === "course"
        ? link.content_type
        : null,
    contributor_profile: normalizedContributor,
  } satisfies LinkResource;
}

function relationVotes(relation: {
  upvote_count?: number | null;
  downvote_count?: number | null;
  vote_score?: number | null;
  value_score?: number | null;
  curator_score?: number | null;
  curator_reviews?: number | null;
  user_score?: number | null;
  combined_score?: number | null;
  rank_key?: number | null;
  coach_take?: string | null;
}) {
  const upvoteCount = relation.upvote_count ?? 0;
  const downvoteCount = relation.downvote_count ?? 0;
  return {
    upvote_count: upvoteCount,
    downvote_count: downvoteCount,
    vote_score: relation.vote_score ?? Math.max(0, upvoteCount - downvoteCount),
    value_score: relation.value_score ?? null,
    curator_score: relation.curator_score ?? null,
    curator_reviews: relation.curator_reviews ?? null,
    user_score: relation.user_score ?? null,
    combined_score: relation.combined_score ?? relation.curator_score ?? null,
    rank_key: relation.rank_key ?? relation.combined_score ?? relation.curator_score ?? null,
    coach_take: relation.coach_take ?? null,
  };
}

const RELATION_PAGE_SIZE = 1000;

type SupabaseClient = NonNullable<ReturnType<typeof getSupabase>>;

type LatestSkillThumbnailRow = {
  skill_id: string;
  thumbnail_url: string | null;
  thumbnail_storage_path: string | null;
  canonical_url: string | null;
  url: string | null;
};

type SkillSummaryRow = {
  consensus?: unknown;
  mistakes?: unknown;
  source_count?: number | null;
  used_count?: number | null;
  generated_at?: string | null;
};

type UserSkillProgressRow = {
  skill_id: string;
  total_count?: number | null;
  watched_count?: number | null;
  target?: number | null;
  completed?: boolean | null;
};

type LinkRow = {
  id: string;
  url?: string | null;
  canonical_url?: string | null;
  domain?: string | null;
  title?: string | null;
  description?: string | null;
  thumbnail_url?: string | null;
  thumbnail_storage_path?: string | null;
  duration_seconds?: number | null;
  like_count?: number | null;
  comment_count?: number | null;
  share_count?: number | null;
  favorite_count?: number | null;
  creator_handle?: string | null;
  creator_url?: string | null;
  scoring_strategy?: string | null;
  content_type?: string | null;
  created_at?: string | null;
  contributor_profile?: unknown;
};

type RelationWithSkillId = {
  id: string;
  link_id?: string | null;
  skill_id?: string | null;
  public_note?: string | null;
  skill_level?: SkillResource["skill_level"];
  upvote_count?: number | null;
  downvote_count?: number | null;
  vote_score?: number | null;
  value_score?: number | null;
  curator_score?: number | null;
  curator_reviews?: number | null;
  user_score?: number | null;
  combined_score?: number | null;
  rank_key?: number | null;
  coach_take?: string | null;
  created_at?: string | null;
  links?: LinkRow | LinkRow[] | null;
};

type LibraryResourceRow = {
  library_view?: "saved" | "watched" | string | null;
  bookmark_id?: string | null;
  list_sort_order?: number | string | null;
  library_added_at?: string | null;
  watched_at?: string | null;
  catalog_status?: SkillResource["catalog_status"];
  link_skill_relation_id?: string | null;
  relation_published?: boolean | null;
  suggestion_status?: SkillResource["suggestion_status"];
  public_note?: string | null;
  skill_level?: SkillResource["skill_level"];
  upvote_count?: number | null;
  downvote_count?: number | null;
  vote_score?: number | null;
  value_score?: number | null;
  curator_score?: number | null;
  curator_reviews?: number | null;
  user_score?: number | null;
  combined_score?: number | null;
  rank_key?: number | null;
  coach_take?: string | null;
  relation_created_at?: string | null;
  link_id: string;
  url?: string | null;
  canonical_url?: string | null;
  domain?: string | null;
  title?: string | null;
  description?: string | null;
  thumbnail_url?: string | null;
  thumbnail_storage_path?: string | null;
  duration_seconds?: number | null;
  like_count?: number | null;
  comment_count?: number | null;
  share_count?: number | null;
  favorite_count?: number | null;
  creator_handle?: string | null;
  creator_url?: string | null;
  scoring_strategy?: string | null;
  content_type?: string | null;
  link_created_at?: string | null;
  contributor_profile_id?: string | null;
  contributor_slug?: string | null;
  contributor_display_name?: string | null;
  contributor_avatar_url?: string | null;
  contributor_accepted_count?: number | null;
  skill_id?: string | null;
  skill_slug?: string | null;
  skill_name?: string | null;
  category_slug?: string | null;
  category_name?: string | null;
};

function unwrapRow<T>(value: T | T[] | null | undefined): T | null {
  return Array.isArray(value) ? value[0] ?? null : value ?? null;
}

function shapeSummaryPoints(value: unknown): SkillSummaryPoint[] {
  if (!Array.isArray(value)) return [];
  return value.flatMap((item) => {
    if (!item || typeof item !== "object" || !("point" in item)) return [];
    const point = typeof item.point === "string" ? item.point.trim() : "";
    if (!point) return [];
    const support =
      "support" in item && typeof item.support === "number" && Number.isFinite(item.support)
        ? item.support
        : 0;
    return [{ point, support }];
  });
}

function shapeSkillTechniqueSummary(row: SkillSummaryRow | null | undefined): SkillTechniqueSummary | null {
  if (!row) return null;
  const consensus = shapeSummaryPoints(row.consensus);
  if (consensus.length === 0 || !row.generated_at) return null;
  return {
    consensus,
    mistakes: shapeSummaryPoints(row.mistakes),
    source_count: row.source_count ?? 0,
    used_count: row.used_count ?? 0,
    generated_at: row.generated_at,
  };
}

function shapeSkillProgress(row: UserSkillProgressRow): UserSkillProgress {
  const total = Math.max(0, row.total_count ?? 0);
  const watched = Math.max(0, row.watched_count ?? 0);
  const target = Math.max(0, row.target ?? Math.min(3, total));
  return {
    skill_id: row.skill_id,
    total_count: total,
    watched_count: watched,
    target,
    completed: Boolean(row.completed),
    percent: target > 0 ? Math.min(100, Math.round((Math.min(watched, target) / target) * 100)) : 0,
  };
}

async function fetchActiveSkillRelations(
  supabase: SupabaseClient,
  skillIds: string[],
  options: {
    perSkill?: number;
    sort?: ResourceSort;
    level?: string;
    source?: string;
  } = {},
): Promise<RelationWithSkillId[]> {
  if (skillIds.length === 0) return [];

  const sort = normalizeSort(options.sort);
  if (typeof options.perSkill === "number") {
    const { data, error } = await supabase
      .rpc("get_ranked_skill_relations", {
        p_skill_ids: skillIds,
        p_per_skill: options.perSkill,
        p_sort: sort,
        p_level: options.level ?? "all",
        p_source: options.source ?? "all",
      })
      .select(
        `id, skill_id, public_note, skill_level, ${RELATION_VOTE_SELECT}, created_at, links!inner(${RESOURCE_LINK_SELECT})`,
      );

    if (error) {
      console.warn("mobile_ranked_skill_relations_load_failed", {
        message: error.message,
        skillCount: skillIds.length,
        perSkill: options.perSkill,
        sort,
      });
      return [];
    }

    return (data ?? []) as RelationWithSkillId[];
  }

  const relations: RelationWithSkillId[] = [];
  for (let from = 0; ; from += RELATION_PAGE_SIZE) {
    const to = from + RELATION_PAGE_SIZE - 1;
    const { data, error } = await supabase
      .from("link_skill_relations")
      .select(
        `id, skill_id, public_note, skill_level, ${RELATION_VOTE_SELECT}, created_at, links!inner(${RESOURCE_LINK_SELECT})`,
      )
      .in("skill_id", skillIds)
      .eq("is_active", true)
      .eq("published", true)
      .eq("links.is_active", true)
      .order(sort === "newest" ? "created_at" : "rank_key", { ascending: false, nullsFirst: false })
      .order("created_at", { ascending: false })
      .order("id", { ascending: true })
      .range(from, to);

    if (error) {
      console.warn("mobile_skill_relations_page_load_failed", error.message);
      break;
    }
    const page = (data ?? []) as RelationWithSkillId[];
    relations.push(...page);
    if (page.length < RELATION_PAGE_SIZE) break;
  }
  return relations;
}

/**
 * Newest thumbnail for MANY skills in one round-trip.
 *
 * This used to be one request per skill; with ~152 active skills that was ~152 REST
 * round-trips on every cold start (~10s of skeletons on Discover). The RPC does the
 * same `distinct on (skill_id) ... order by created_at desc` server-side.
 */
async function fetchLatestSkillThumbnails(
  supabase: SupabaseClient,
  skillIds: string[],
): Promise<Map<string, string | null>> {
  const result = new Map<string, string | null>();
  if (skillIds.length === 0) return result;

  const { data, error } = await supabase.rpc("get_latest_skill_thumbnails", {
    p_skill_ids: skillIds,
  });
  if (error) {
    console.warn("mobile_latest_skill_thumbnails_failed", error.message);
    return result;
  }

  for (const row of (data ?? []) as LatestSkillThumbnailRow[]) {
    result.set(
      row.skill_id,
      normalizeThumbnailUrl(
        row.thumbnail_storage_path ?? row.thumbnail_url ?? null,
        row.canonical_url ?? row.url ?? null,
        row.thumbnail_storage_path ? row.thumbnail_url ?? null : null,
      ),
    );
  }
  return result;
}

function shapeRelationResource(
  relation: RelationWithSkillId,
  skill: Pick<SkillSummary, "id" | "slug" | "name" | "category_slug"> & {
    category_name?: string | null;
  },
): SkillResource | null {
  const link = unwrapRow(relation.links);
  if (!link) return null;
  return {
    id: relation.id,
    link_skill_relation_id: relation.id,
    public_note: relation.public_note ?? null,
    skill_level: relation.skill_level ?? null,
    ...relationVotes(relation),
    created_at: relation.created_at ?? link.created_at ?? null,
    link: shapeLinkWithContributor(link),
    skill: {
      id: skill.id,
      slug: skill.slug,
      name: skill.name,
      category_slug: skill.category_slug,
      category_name: skill.category_name ?? null,
    },
  };
}

function normalizeCatalogStatus(value: LibraryResourceRow["catalog_status"]) {
  return value === "private" || value === "in_review" || value === "in_catalog" || value === "not_added"
    ? value
    : null;
}

function numericSortOrder(value: number | string | null | undefined) {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim()) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function shapeLibraryResource(row: LibraryResourceRow): SkillResource | null {
  if (!row.link_id) return null;
  const contributor = row.contributor_profile_id
    ? {
        id: row.contributor_profile_id,
        slug: row.contributor_slug ?? "",
        display_name: row.contributor_display_name ?? "Contributor",
        avatar_url: row.contributor_avatar_url ?? null,
        accepted_count: row.contributor_accepted_count ?? 0,
      }
    : null;
  const resource: SkillResource = {
    id: row.bookmark_id ?? row.link_skill_relation_id ?? row.link_id,
    link_skill_relation_id: row.link_skill_relation_id ?? null,
    personal_list_id: row.bookmark_id ?? null,
    catalog_status: normalizeCatalogStatus(row.catalog_status),
    list_sort_order: numericSortOrder(row.list_sort_order),
    suggestion_status: row.suggestion_status ?? null,
    relation_published: row.relation_published ?? null,
    public_note: row.public_note ?? null,
    skill_level: row.skill_level ?? null,
    ...relationVotes(row),
    created_at: row.relation_created_at ?? row.link_created_at ?? row.library_added_at ?? null,
    link: shapeLinkWithContributor({
      id: row.link_id,
      url: row.url ?? row.canonical_url ?? "",
      canonical_url: row.canonical_url ?? row.url ?? "",
      domain: row.domain ?? "",
      title: row.title ?? null,
      description: row.description ?? null,
      thumbnail_url: row.thumbnail_url ?? null,
      thumbnail_storage_path: row.thumbnail_storage_path ?? null,
      duration_seconds: row.duration_seconds ?? null,
      like_count: row.like_count ?? null,
      comment_count: row.comment_count ?? null,
      share_count: row.share_count ?? null,
      favorite_count: row.favorite_count ?? null,
      creator_handle: row.creator_handle ?? null,
      creator_url: row.creator_url ?? null,
      scoring_strategy: row.scoring_strategy ?? null,
      content_type: row.content_type ?? null,
      created_at: row.link_created_at ?? null,
      contributor_profile: contributor,
    }),
  };
  if (row.skill_id && row.skill_slug && row.skill_name) {
    resource.skill = {
      id: row.skill_id,
      slug: row.skill_slug,
      name: row.skill_name,
      category_slug: row.category_slug ?? "",
      category_name: row.category_name ?? null,
    };
  }
  return resource;
}

function fallbackSkillsForCategory(categorySlug: string) {
  return fallbackSkills.filter((skill) => skill.category_slug === categorySlug);
}

function fallbackCategoryBySlug(categorySlug: string) {
  return fallbackCategories.find((category) => category.slug === categorySlug) ?? null;
}

function withResourceSummaries(skills: SkillSummary[]) {
  return skills.map((skill) => {
    const resources = fallbackResources[skill.slug] ?? [];
    return {
      ...skill,
      resource_count: resources.length,
      preview_thumbnails: resources
        .flatMap((resource) => resource.link.thumbnail_url ? [resource.link.thumbnail_url] : [])
        .slice(0, 3),
    };
  });
}

function normalizeSort(sort: ResourceSort | undefined): ResourceSort {
  return sort === "newest" ? "newest" : "popular";
}

export async function getCategories(): Promise<CategorySummary[]> {
  const supabase = getSupabase();
  if (!supabase) return fallbackCategories;

  const { data } = await supabase
    .from("categories")
    .select("id, slug, name, description, updated_at")
    .eq("is_active", true)
    .order("name");

  return data?.length ? data : fallbackCategories;
}

export async function getCategory(categorySlug = badmintonCategory.slug): Promise<CategorySummary | null> {
  const supabase = getSupabase();
  if (!supabase) return fallbackCategoryBySlug(categorySlug);

  const { data } = await supabase
    .from("categories")
    .select("id, slug, name, description, updated_at")
    .eq("slug", categorySlug)
    .eq("is_active", true)
    .maybeSingle();

  return data ?? fallbackCategoryBySlug(categorySlug);
}

export async function getSkillsForCategory(categorySlug: string): Promise<{
  category: CategorySummary | null;
  skills: SkillSummary[];
}> {
  const supabase = getSupabase();
  if (!supabase) {
    const category = fallbackCategoryBySlug(categorySlug);
    return { category, skills: category ? withResourceSummaries(fallbackSkillsForCategory(category.slug)) : [] };
  }

  // One round trip for the category AND its skills, via an embedded inner join
  // on the slug. This used to be two sequential queries — getCategory, then
  // skills by category_id — and on this project each round trip costs 400-1200ms
  // regardless of payload (measured: a 0.3KB category lookup took 776ms), so the
  // extra hop was pure latency. The join costs ~19KB against 12KB for skills
  // alone, which is nothing next to a whole round trip.
  // supabase-js cannot infer the shape of an embedded select built from a
  // string, so the row type is declared here rather than fought with generics.
  type SkillRowWithCategory = {
    id: string;
    category_id: string;
    slug: string;
    name: string;
    description: string | null;
    subskill_difficulty: number | null;
    learning_order: number | null;
    updated_at: string | null;
    category: CategorySummary | null;
  };

  const { data: rawRows } = await supabase
    .from("skills")
    .select(
      "id, category_id, slug, name, description, subskill_difficulty, learning_order, updated_at," +
        " category:categories!inner(id, slug, name, description, updated_at)",
    )
    .eq("category.slug", categorySlug)
    .eq("is_active", true)
    .order("name");

  const data = (rawRows ?? []) as unknown as SkillRowWithCategory[];
  const embeddedCategory = data[0]?.category ?? null;
  const category = embeddedCategory ?? fallbackCategoryBySlug(categorySlug);
  if (!category) return { category: null, skills: [] };

  const skillIds = (data ?? []).map((skill) => skill.id);
  const { data: resourceCounts } = skillIds.length
    ? await supabase.rpc("get_skill_resource_counts", { p_skill_ids: skillIds })
    : { data: [] };

  const counts = new Map<string, number>();
  for (const count of resourceCounts ?? []) {
    counts.set(count.skill_id, Number(count.resource_count));
  }

  return {
    category,
    skills: data.map(({ category: _embedded, ...skill }) => ({
      ...skill,
      category_slug: category.slug,
      resource_count: counts.get(skill.id) ?? 0,
      preview_thumbnails: [],
    })),
  };
}

export async function getSkillResources(categorySlug: string, skillSlug: string, sortInput?: ResourceSort): Promise<{
  category: CategorySummary | null;
  skill: SkillSummary | null;
  resources: SkillResource[];
  summary: SkillTechniqueSummary | null;
}> {
  const sort = normalizeSort(sortInput);
  const supabase = getSupabase();
  if (!supabase) {
    const category = fallbackCategoryBySlug(categorySlug);
    const skill = fallbackSkillsForCategory(categorySlug).find((item) => item.slug === skillSlug) ?? null;
    const resources = skill
      ? sortResources(
          (fallbackResources[skillSlug] ?? []).map((resource) => ({
            ...resource,
            skill: {
              id: skill.id,
              slug: skill.slug,
              name: skill.name,
              category_slug: skill.category_slug,
              category_name: category?.name ?? null,
            },
          })),
          sort,
        )
      : [];
    return { category, skill, resources, summary: null };
  }

  const { data: skill } = await supabase
    .from("skills")
    .select("id, category_id, slug, name, description, subskill_difficulty, learning_order, updated_at, categories!inner(id, slug, name, description, updated_at)")
    .eq("slug", skillSlug)
    .eq("categories.slug", categorySlug)
    .eq("is_active", true)
    .maybeSingle();

  if (!skill) return { category: null, skill: null, resources: [], summary: null };
  const category = Array.isArray(skill.categories) ? skill.categories[0] : skill.categories;
  if (!category) return { category: null, skill: null, resources: [], summary: null };

  const [{ data: relations }, { data: summaryRow, error: summaryError }] = await Promise.all([
    supabase
      .from("link_skill_relations")
      .select(`id, public_note, skill_level, ${RELATION_VOTE_SELECT}, created_at, links!inner(${RESOURCE_LINK_SELECT})`)
      .eq("skill_id", skill.id)
      .eq("is_active", true)
      .eq("published", true)
      .eq("links.is_active", true)
      .order(sort === "newest" ? "created_at" : "rank_key", { ascending: false, nullsFirst: false })
      .order("created_at", { ascending: false })
      .order("id", { ascending: true }),
    supabase
      .from("skill_summaries")
      .select("consensus, mistakes, source_count, used_count, generated_at")
      .eq("skill_id", skill.id)
      .maybeSingle(),
  ]);

  if (summaryError) {
    console.warn("mobile_skill_summary_load_failed", {
      skillId: skill.id,
      message: summaryError.message,
    });
  }

  return {
    category,
    skill: {
      id: skill.id,
      category_id: skill.category_id,
      category_slug: category.slug,
      slug: skill.slug,
      name: skill.name,
      description: skill.description,
      resource_count: relations?.length ?? 0,
      subskill_difficulty: skill.subskill_difficulty ?? null,
      learning_order: skill.learning_order ?? null,
      updated_at: skill.updated_at,
    },
    resources: ((relations ?? []) as RelationWithSkillId[]).flatMap((relation) => {
      const resource = shapeRelationResource(relation, {
        id: skill.id,
        slug: skill.slug,
        name: skill.name,
        category_slug: category.slug,
        category_name: category.name,
      });
      return resource ? [resource] : [];
    }),
    summary: shapeSkillTechniqueSummary(summaryRow as SkillSummaryRow | null),
  };
}

export async function getDiscoverSections(perCategorySkills: number | null = null): Promise<DiscoverCategorySection[]> {
  const supabase = getSupabase();
  const categories = await getCategories();

  if (!supabase) {
    return categories.map((category) => {
      const skills = fallbackSkillsForCategory(category.slug);
      return {
        category,
        skills: skills.slice(0, perCategorySkills ?? undefined).map((skill) => {
          const resources = fallbackResources[skill.slug] ?? [];
          const latestResource = resources.find((resource) => resource.link.thumbnail_url);
          const latest = latestResource
            ? normalizeThumbnailUrl(latestResource.link.thumbnail_url, latestResource.link.url ?? null)
            : null;
          return { skill, latest_thumbnail: latest };
        }),
      };
    });
  }

  // For each category we want active skills and their latest resource thumbnail.
  // Resolve the skill lists first, then fetch every thumbnail in ONE round-trip —
  // doing it per skill meant ~152 sequential-ish REST calls on a cold start.
  const categorySkills = await Promise.all(
    categories.map(async (category) => {
      const { skills } = await getSkillsForCategory(category.slug);
      return {
        category,
        skills: [...skills]
          .filter((skill) => skill.resource_count > 0)
          // Sort BEFORE the cap. The cap is fine for a horizontal rail, but
          // combined with alphabetical order it hid over half of every large
          // category behind an arbitrary cut.
          .sort(byLearningOrder)
          .slice(0, perCategorySkills ?? undefined),
      };
    }),
  );

  const latestThumbBySkill = await fetchLatestSkillThumbnails(
    supabase,
    categorySkills.flatMap((entry) => entry.skills.map((skill) => skill.id)),
  );

  const sections = categorySkills.map(({ category, skills }) => ({
    category,
    skills: skills.map((skill) => ({
      skill,
      latest_thumbnail: latestThumbBySkill.get(skill.id) ?? null,
    })) as DiscoverSkillTile[],
  }));

  return sections.filter((section) => section.skills.length > 0);
}

export async function getCategoryWithSkillResources(
  categorySlug: string,
): Promise<{
  category: CategorySummary | null;
  skills: SkillSummary[];
  resources: SkillResource[];
}> {
  const { category, skills } = await getSkillsForCategory(categorySlug);
  if (!category) return { category: null, skills: [], resources: [] };

  const supabase = getSupabase();
  // Beginner first, the same order Discover and onboarding use. getSkillsForCategory
  // returns the database's alphabetical order, which is why the sport page opened on
  // "Catching kicks" while Discover led with "Stance" — a tester spotted the
  // disagreement. Sorted here rather than inside getSkillsForCategory because the
  // Suggest form's skill picker shares that function, and a picker is easier to scan A-Z.
  const skillsWithResources = skills
    .filter((skill) => skill.resource_count > 0)
    .sort(byLearningOrder);
  if (!supabase) {
    const resources = sortResources(
      skillsWithResources.flatMap((skill) =>
        (fallbackResources[skill.slug] ?? []).map((resource) => ({
          ...resource,
          skill: {
            id: skill.id,
            slug: skill.slug,
            name: skill.name,
            category_slug: skill.category_slug,
            category_name: category.name,
          },
        })),
      ),
      "popular",
    );
    return { category, skills: skillsWithResources, resources };
  }

  if (skillsWithResources.length === 0) {
    return { category, skills: skillsWithResources, resources: [] };
  }

  const skillById = new Map(skillsWithResources.map((skill) => [skill.id, skill]));
  const resources = sortResources(
    (await fetchActiveSkillRelations(supabase, skillsWithResources.map((skill) => skill.id), {
      perSkill: 8,
      sort: "popular",
    })).flatMap(
      (relation) => {
        const skill = relation.skill_id ? skillById.get(relation.skill_id) : null;
        if (!skill) return [];
        const resource = shapeRelationResource(relation, {
          id: skill.id,
          slug: skill.slug,
          name: skill.name,
          category_slug: skill.category_slug,
          category_name: category.name,
        });
        return resource ? [resource] : [];
      },
    ),
    "popular",
  );

  return { category, skills: skillsWithResources, resources };
}

export type UserLibraryView = "saved" | "watched";

export async function getUserLibraryResources(
  _userId: string,
  view: UserLibraryView,
): Promise<SkillResource[]> {
  const supabase = getSupabase();
  if (!supabase) return [];

  const { data, error } = await supabase.rpc("get_user_library_resources", {
    p_view: view,
  });
  if (error) {
    console.warn("mobile_user_library_state_load_failed", {
      view,
      message: error.message,
    });
    throw error;
  }

  return ((data ?? []) as LibraryResourceRow[])
    .map(shapeLibraryResource)
    .filter((resource): resource is SkillResource => Boolean(resource));
}

export async function getUserSkillProgress(skillIds: string[]): Promise<UserSkillProgress[]> {
  const supabase = getSupabase();
  const uniqueSkillIds = [...new Set(skillIds)].filter(Boolean);
  if (!supabase || uniqueSkillIds.length === 0) return [];

  const { data, error } = await supabase.rpc("get_user_skill_progress", {
    p_skill_ids: uniqueSkillIds,
  });
  if (error) {
    console.warn("mobile_user_skill_progress_load_failed", {
      message: error.message,
      skillCount: uniqueSkillIds.length,
    });
    return [];
  }

  return ((data ?? []) as UserSkillProgressRow[]).map(shapeSkillProgress);
}
