import { z } from "zod";

export const skillLevelSchema = z.enum(["beginner", "intermediate", "advanced"]);

export const suggestionTypeSchema = z.enum([
  "LINK_ADD",
  "LINK_ATTACH_SKILL",
  "LINK_DETACH_SKILL",
  "LINK_UPVOTE_SKILL",
  "SOURCE_ADD",
  "SKILL_CREATE",
  "SKILL_DELETE",
]);

export const suggestionStatusSchema = z.enum([
  "pending",
  "approved",
  "declined",
  "auto_approved",
]);

export const originTypeSchema = z.enum(["agent", "admin", "human", "import"]);

const uuidish = z.string().uuid();

export const linkAddPayloadSchema = z.object({
  url: z.string().url(),
  canonical_url: z.string().url(),
  domain: z.string().min(1).optional(),
  title: z.string().min(1).nullable().optional(),
  description: z.string().nullable().optional(),
  thumbnail_url: z.string().url().nullable().optional(),
  thumbnail_dynamic_url: z.string().url().nullable().optional(),
  thumbnail_storage_path: z.string().min(1).nullable().optional(),
  thumbnail_cache_status: z.enum(["cached", "failed"]).nullable().optional(),
  thumbnail_cache_error: z.string().max(500).nullable().optional(),
  thumbnail_cache_attempted_at: z.string().datetime().nullable().optional(),
  content_type: z.enum(["video", "article", "podcast", "course"]).nullable().optional(),
  language: z.string().min(2).max(12).default("en"),
  target_skill_id: uuidish,
  public_note: z.string().max(140).nullable().optional(),
  skill_level: skillLevelSchema.nullable().optional(),
  duration_seconds: z.number().min(0).nullable().optional(),
  like_count: z.number().int().min(0).nullable().optional(),
  comment_count: z.number().int().min(0).nullable().optional(),
  share_count: z.number().int().min(0).nullable().optional(),
  favorite_count: z.number().int().min(0).nullable().optional(),
  creator_handle: z.string().min(1).max(120).nullable().optional(),
  creator_url: z.string().url().nullable().optional(),
  creator_platform: z.enum(["youtube", "tiktok", "instagram"]).nullable().optional(),
  creator_profile: z.record(z.unknown()).nullable().optional(),
  scoring_strategy: z.enum(["transcript_llm", "engagement_authority"]).default("transcript_llm").optional(),
  review_lane: z.enum(["coach", "founder", "agent", "private"]).optional(),
});

export const linkAttachSkillPayloadSchema = z.object({
  link_id: uuidish,
  target_skill_id: uuidish,
  public_note: z.string().max(180).nullable().optional(),
  skill_level: skillLevelSchema.nullable().optional(),
});

export const linkDetachSkillPayloadSchema = z.object({
  link_id: uuidish,
  target_skill_id: uuidish,
  reason: z.string().min(1).max(600),
});

export const linkUpvoteSkillPayloadSchema = z.object({
  link_id: uuidish,
  target_skill_id: uuidish,
  reason: z.string().min(1).max(600).optional(),
});

export const skillCreatePayloadSchema = z.object({
  category_id: uuidish,
  name: z.string().min(2).max(120),
  description: z.string().max(1000).nullable().optional(),
});

export const sourceAddPayloadSchema = z.object({
  source_type: z.enum(["youtube_channel", "domain", "rss", "tiktok_search"]),
  identifier: z.string().min(1).max(500),
  display_name: z.string().min(1).max(200),
  category_id: uuidish.nullable().optional(),
  discovery_score: z.number().min(0).max(20).nullable().optional(),
  discovery_evidence_json: z.record(z.unknown()).nullable().optional(),
});

export const skillDeletePayloadSchema = z.object({
  skill_id: uuidish,
  reason: z.string().min(1).max(600),
});

export const suggestionPayloadByType = {
  LINK_ADD: linkAddPayloadSchema,
  LINK_ATTACH_SKILL: linkAttachSkillPayloadSchema,
  LINK_DETACH_SKILL: linkDetachSkillPayloadSchema,
  LINK_UPVOTE_SKILL: linkUpvoteSkillPayloadSchema,
  SOURCE_ADD: sourceAddPayloadSchema,
  SKILL_CREATE: skillCreatePayloadSchema,
  SKILL_DELETE: skillDeletePayloadSchema,
} as const;

export const submitSuggestionSchema = z.object({
  type: suggestionTypeSchema,
  requested_status: suggestionStatusSchema.optional(),
  status: suggestionStatusSchema.default("pending"),
  origin_type: originTypeSchema.default("agent"),
  origin_name: z.string().max(120).nullable().optional(),
  category_id: uuidish.nullable().optional(),
  skill_id: uuidish.nullable().optional(),
  link_id: uuidish.nullable().optional(),
  author_internal_user_id: uuidish.nullable().optional(),
  submitted_by_user_id: uuidish.nullable().optional(),
  add_to_watch_later: z.boolean().optional(),
  suggest_to_catalog: z.boolean().optional(),
  turnstile_token: z.string().min(1).max(2048).nullable().optional(),
  payload_json: z.unknown(),
  evidence_json: z.record(z.unknown()).nullable().optional(),
  triangulation_json: z.record(z.unknown()).nullable().optional(),
  confidence: z.number().min(0).max(1).nullable().optional(),
});

export const scoreResultSchema = z.object({
  relevance: z.number().min(0).max(1),
  teaching_quality: z.number().min(0).max(1),
  demo_vs_talk: z.number().min(0).max(1),
  level: skillLevelSchema,
  public_note: z.string().min(1).max(140),
  evidence_quote: z.string().min(1).max(200),
});

export const triangulationVoteSchema = z.object({
  approve: z.boolean(),
  confidence: z.number().min(0).max(1),
  reason: z.string().min(1).max(200),
});

export type SubmitSuggestionInput = z.infer<typeof submitSuggestionSchema>;
export type LinkAddPayload = z.infer<typeof linkAddPayloadSchema>;
export type LinkAttachSkillPayload = z.infer<typeof linkAttachSkillPayloadSchema>;
export type LinkDetachSkillPayload = z.infer<typeof linkDetachSkillPayloadSchema>;
export type LinkUpvoteSkillPayload = z.infer<typeof linkUpvoteSkillPayloadSchema>;
export type SourceAddPayload = z.infer<typeof sourceAddPayloadSchema>;
