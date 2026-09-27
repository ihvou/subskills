export type SkillLevel = "beginner" | "intermediate" | "advanced";
export type ResourceSort = "newest" | "popular";
export type ResourceSourceFilter = "all" | "youtube" | "tiktok" | "instagram";
export type ResourceSource = "youtube" | "tiktok" | "instagram" | "other";
export type LibraryCatalogStatus = "private" | "in_review" | "in_catalog" | "not_added";

export type SuggestionType =
  | "LINK_ADD"
  | "LINK_ATTACH_SKILL"
  | "LINK_DETACH_SKILL"
  | "LINK_UPVOTE_SKILL"
  | "SOURCE_ADD"
  | "SKILL_CREATE"
  | "SKILL_DELETE";

export type SuggestionStatus = "pending" | "approved" | "declined" | "auto_approved";

export type OriginType = "agent" | "admin" | "human" | "import";

export interface CategorySummary {
  id: string;
  slug: string;
  name: string;
  description: string | null;
  updated_at?: string | null;
}

export interface SkillSummary {
  id: string;
  category_id: string;
  category_slug: string;
  slug: string;
  name: string;
  description: string | null;
  resource_count: number;
  subskill_difficulty?: number | null;
  learning_order?: number | null;
  preview_thumbnails?: string[];
  updated_at?: string | null;
}

export interface LinkResource {
  id: string;
  /** Blank on public pages: the server swaps it for `go` before the page is sent. */
  url: string;
  canonical_url: string;
  /** `/go#…` token for the video (see outbound.ts). Set on public pages instead of the URLs. */
  go?: string | null;
  domain: string;
  title: string | null;
  description: string | null;
  thumbnail_url: string | null;
  thumbnail_storage_path?: string | null;
  duration_seconds?: number | null;
  like_count?: number | null;
  comment_count?: number | null;
  share_count?: number | null;
  favorite_count?: number | null;
  creator_handle?: string | null;
  creator_url?: string | null;
  scoring_strategy?: "transcript_llm" | "engagement_authority";
  content_type: "video" | "article" | "podcast" | "course" | null;
  created_at?: string | null;
  contributor_profile?: ContributorProfileSummary | null;
}

export interface SkillResource {
  id: string;
  link_skill_relation_id?: string | null;
  personal_list_id?: string | null;
  catalog_status?: LibraryCatalogStatus | null;
  list_sort_order?: number | null;
  suggestion_status?: SuggestionStatus | string | null;
  relation_published?: boolean | null;
  public_note: string | null;
  skill_level: SkillLevel | null;
  upvote_count: number;
  downvote_count?: number;
  vote_score?: number;
  value_score?: number | null;
  curator_score?: number | null;
  curator_reviews?: number | null;
  user_score?: number | null;
  combined_score?: number | null;
  rank_key?: number | null;
  coach_take?: string | null;
  /**
   * Newest first. Absent when the page didn't load comments (the library, or the
   * comments table not yet there); the card then shows `coach_take` as the Reviewer's.
   */
  comments?: ResourceComment[];
  created_at?: string | null;
  link: LinkResource;
  skill?: Pick<SkillSummary, "id" | "slug" | "name" | "category_slug"> & {
    category_name?: string | null;
  };
}

export interface ResourceComment {
  id: string;
  /** "Moderator" or "Reviewer" for the coach's two; a username once people can post (M170). */
  author: string;
  body: string;
  created_at: string | null;
}

export interface ContributorProfileSummary {
  id: string;
  slug: string;
  display_name: string;
  avatar_url?: string | null;
  accepted_count?: number;
}

export interface TriangulationVote {
  model: string;
  approve: boolean;
  confidence: number;
  reason: string;
}

export interface ScoreResult {
  relevance: number;
  teaching_quality: number;
  demo_vs_talk: number;
  level: SkillLevel;
  public_note: string;
  evidence_quote: string;
}
