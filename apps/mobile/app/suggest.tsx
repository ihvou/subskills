import { useEffect, useMemo, useState } from "react";
import { Alert, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";
import { useLocalSearchParams, useRouter } from "expo-router";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { Check } from "lucide-react-native";
import type { SkillLevel } from "@skillsaggregator/shared";
import { PageHeader } from "@/components/PageHeader";
import { Screen } from "@/components/Screen";
import { SkeletonList } from "@/components/SkeletonList";
import { getCategories, getSkillsForCategory } from "@/lib/data";
import { useAuth } from "@/lib/auth";
import { colors, radius, spacing, typography } from "@/lib/theme";
import { track } from "@/lib/analytics";
import {
  addPendingSubmission,
  failPendingSubmission,
  resolvePendingSubmission,
} from "@/lib/pendingSubmissions";
import { sendSuggestion, type SuggestionRequest } from "@/lib/submitSuggestion";

const LEVELS: Array<{ value: SkillLevel; label: string }> = [
  { value: "beginner", label: "Beginner" },
  { value: "intermediate", label: "Intermediate" },
  { value: "advanced", label: "Advanced" },
];

export default function SuggestScreen() {
  const router = useRouter();
  const queryClient = useQueryClient();
  const { category, skill, url: initialUrl } = useLocalSearchParams<{ category?: string; skill?: string; url?: string }>();
  const { profile, ensureSession } = useAuth();
  const [categorySlug, setCategorySlug] = useState(category ?? "badminton");
  const [skillId, setSkillId] = useState("");
  const [url, setUrl] = useState(typeof initialUrl === "string" ? initialUrl : "");
  const [fallbackTitle, setFallbackTitle] = useState("");
  const [note, setNote] = useState("");
  const [level, setLevel] = useState<SkillLevel | "">("");
  const [addToWatchLater, setAddToWatchLater] = useState(true);
  // Off when the form was opened by a share (M163): a link shared in from another
  // app is the user keeping something for themselves, and the iOS share sheet
  // already defaults this toggle off. A `url` param only arrives through a share —
  // Android's ACTION_SEND intent and the iOS inbox fallback — so the in-app
  // Suggest buttons, which are for suggesting to the catalogue, keep it on.
  const [suggestToCatalog, setSuggestToCatalog] = useState(
    !(typeof initialUrl === "string" && initialUrl.length > 0),
  );

  const categoriesQuery = useQuery({
    queryKey: ["suggest-categories"],
    queryFn: getCategories,
    staleTime: 300000,
  });
  const skillsQuery = useQuery({
    queryKey: ["suggest-skills", categorySlug],
    queryFn: () => getSkillsForCategory(categorySlug),
    staleTime: 300000,
  });

  const selectedCategory = useMemo(
    () => categoriesQuery.data?.find((item) => item.slug === categorySlug) ?? null,
    [categoriesQuery.data, categorySlug],
  );
  const skills = skillsQuery.data?.skills ?? [];

  useEffect(() => {
    const initialSkill = skills.find((item) => item.slug === skill) ?? skills[0];
    setSkillId(initialSkill?.id ?? "");
  }, [skill, skills]);

  useEffect(() => {
    if (typeof category === "string" && category) setCategorySlug(category);
  }, [category]);

  useEffect(() => {
    if (typeof initialUrl === "string" && initialUrl) setUrl(initialUrl);
  }, [initialUrl]);

  const urlSource = useMemo(() => {
    try {
      const hostname = new URL(url).hostname.replace(/^www\./, "").toLowerCase();
      if (hostname === "youtu.be" || hostname === "youtube.com" || hostname.endsWith(".youtube.com")) return "youtube";
      if (hostname === "tiktok.com" || hostname.endsWith(".tiktok.com")) return "tiktok";
      if (hostname === "instagram.com" || hostname.endsWith(".instagram.com")) return "instagram";
    } catch {
      return null;
    }
    return "other";
  }, [url]);
  const showFallbackTitle = url.trim().length > 0 && urlSource !== "youtube";

  async function submit() {
    const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL?.replace(/\/+$/, "");
    const anonKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY;
    if (!supabaseUrl || !anonKey) {
      Alert.alert("Suggestions unavailable", "Supabase is not configured for this build.");
      return;
    }
    if (!selectedCategory || !skillId || !url.trim()) {
      Alert.alert("Missing details", "Add a URL and choose the target skill.");
      return;
    }
    if (!addToWatchLater && !suggestToCatalog) {
      Alert.alert("Missing choice", "Choose Watch later, catalogue review, or both.");
      return;
    }
    // Everything below is deliberately NOT awaited. The chain behind this —
    // session, Turnstile, rate limit, oEmbed, several database round trips, then
    // a second edge function over HTTP — takes seconds, and none of it is work
    // the user needs to watch. The link is accepted here and appears in Watch
    // later straight away as a visibly-loading row; the request runs behind it.
    const request: SuggestionRequest = {
      add_to_watch_later: addToWatchLater,
      suggest_to_catalog: suggestToCatalog,
      category_id: selectedCategory.id,
      skill_id: skillId,
      payload_json: {
        url: url.trim(),
        canonical_url: url.trim(),
        target_skill_id: skillId,
        title: showFallbackTitle && fallbackTitle.trim() ? fallbackTitle.trim() : null,
        public_note: note.trim() || null,
        skill_level: level || null,
        language: "en",
      },
    };
    const pendingId = addPendingSubmission({
      url: url.trim(),
      title: request.payload_json.title,
      skillName: skills.find((item) => item.id === skillId)?.name ?? null,
      request,
    });

    track("suggestion_submitted", {
      suggested_to_catalog: suggestToCatalog,
      source: urlSource ?? "other",
    });

    // No success dialog. "Suggest" already says the catalogue copy is reviewed
    // rather than published, and a modal reading "Submitted for review" lands as
    // a refusal even when the link WAS saved. Failures now surface on the row
    // itself, where the user can retry, instead of in an alert over this form.
    //
    // This screen is reachable with NO back stack — a share-target launch, or a
    // deep link — where router.back() is a no-op and would strand the user on a
    // form they have already submitted.
    if (router.canGoBack()) router.back();
    else router.replace("/(tabs)/library");

    void (async () => {
      try {
        const activeSession = await ensureSession("suggest_resource");
        const result = await sendSuggestion(request, {
          accessToken: activeSession.access_token,
          originName: profile
            ? `mobile_${profile.slug}`
            : activeSession.user.is_anonymous
              ? "mobile_anonymous"
              : "mobile_authenticated",
        });
        resolvePendingSubmission(pendingId);
        console.info("[suggest] submitted", { ...result, suggestToCatalog });
        void queryClient.invalidateQueries({ queryKey: ["user-library"] });
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        // The row carries the failure and offers Retry. Alerting here would fire
        // over whatever screen the user has moved on to.
        failPendingSubmission(pendingId, message);
        console.warn("[suggest] submission failed", { error: message });
      }
    })();
  }

  const loading = categoriesQuery.isLoading || skillsQuery.isLoading;

  return (
    <Screen edges={["top", "bottom"]}>
      <PageHeader
        title="Suggest a link"
        subtitle="Save a training link, submit it for review, or both."
        showBack
      />
      {loading ? (
        <SkeletonList count={2} />
      ) : (
        <ScrollView contentContainerStyle={styles.form} showsVerticalScrollIndicator={false}>
          <Text style={styles.label}>URL</Text>
          <TextInput
            value={url}
            onChangeText={setUrl}
            autoCapitalize="none"
            keyboardType="url"
            placeholder="https://..."
            placeholderTextColor={colors.faint}
            style={styles.input}
          />

          {showFallbackTitle ? (
            <>
              <Text style={styles.label}>Title</Text>
              <TextInput
                value={fallbackTitle}
                onChangeText={(value) => setFallbackTitle(value.slice(0, 180))}
                placeholder="Optional fallback title"
                placeholderTextColor={colors.faint}
                style={styles.input}
                maxLength={180}
              />
            </>
          ) : null}

          <View style={styles.intentGroup}>
            <ToggleRow
              label="Add to my Watch later"
              value={addToWatchLater}
              onChange={() => setAddToWatchLater((current) => !current)}
            />
            <ToggleRow
              label="Also suggest to the catalogue"
              value={suggestToCatalog}
              onChange={() => setSuggestToCatalog((current) => !current)}
            />
          </View>

          <Text style={styles.label}>Category</Text>
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.chips}>
            {(categoriesQuery.data ?? []).map((item) => (
              <Pressable
                key={item.id}
                onPress={() => setCategorySlug(item.slug)}
                style={[styles.chip, item.slug === categorySlug && styles.chipActive]}
              >
                <Text style={[styles.chipText, item.slug === categorySlug && styles.chipTextActive]}>
                  {item.name}
                </Text>
              </Pressable>
            ))}
          </ScrollView>

          <Text style={styles.label}>Skill</Text>
          <View style={styles.skillGrid}>
            {skills.map((item) => (
              <Pressable
                key={item.id}
                onPress={() => setSkillId(item.id)}
                style={[styles.skillChip, item.id === skillId && styles.chipActive]}
              >
                <Text style={[styles.chipText, item.id === skillId && styles.chipTextActive]}>
                  {item.name}
                </Text>
              </Pressable>
            ))}
          </View>

          <Text style={styles.label}>Level</Text>
          <View style={styles.chips}>
            <Pressable
              onPress={() => setLevel("")}
              style={[styles.chip, level === "" && styles.chipActive]}
            >
              <Text style={[styles.chipText, level === "" && styles.chipTextActive]}>Not sure</Text>
            </Pressable>
            {LEVELS.map((item) => (
              <Pressable
                key={item.value}
                onPress={() => setLevel(item.value)}
                style={[styles.chip, level === item.value && styles.chipActive]}
              >
                <Text style={[styles.chipText, level === item.value && styles.chipTextActive]}>
                  {item.label}
                </Text>
              </Pressable>
            ))}
          </View>

          <Text style={styles.label}>Public note</Text>
          <TextInput
            value={note}
            onChangeText={(value) => setNote(value.slice(0, 140))}
            multiline
            maxLength={140}
            placeholder="Why is this useful?"
            placeholderTextColor={colors.faint}
            style={[styles.input, styles.textArea]}
          />
          <Text style={styles.count}>{note.length}/140</Text>

          <Pressable
            onPress={submit}
            disabled={!addToWatchLater && !suggestToCatalog}
            style={({ pressed }) => [
              styles.submit,
              pressed && styles.pressed,
              !addToWatchLater && !suggestToCatalog && styles.disabled,
            ]}
          >
            <Text style={styles.submitText}>Save / suggest link</Text>
          </Pressable>
        </ScrollView>
      )}
    </Screen>
  );
}

function ToggleRow({
  label,
  value,
  onChange,
}: {
  label: string;
  value: boolean;
  onChange: () => void;
}) {
  return (
    <Pressable
      onPress={onChange}
      style={({ pressed }) => [styles.toggleRow, pressed && styles.pressed]}
      accessibilityRole="checkbox"
      accessibilityState={{ checked: value }}
    >
      <View style={[styles.checkbox, value && styles.checkboxActive]}>
        {value ? <Check size={15} color={colors.surface} strokeWidth={3} /> : null}
      </View>
      <Text style={styles.toggleText}>{label}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  form: {
    gap: spacing.sm,
    paddingBottom: spacing.xxl,
  },
  label: {
    marginTop: spacing.sm,
    fontSize: 13,
    fontWeight: "800",
    color: colors.ink,
  },
  input: {
    minHeight: 46,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: colors.divider,
    borderRadius: radius.sm,
    paddingHorizontal: spacing.md,
    color: colors.ink,
    fontSize: 16,
    backgroundColor: colors.surface,
  },
  textArea: {
    minHeight: 96,
    paddingTop: spacing.sm,
    textAlignVertical: "top",
  },
  count: {
    alignSelf: "flex-end",
    ...typography.meta,
    color: colors.faint,
  },
  intentGroup: {
    gap: spacing.xs,
    marginTop: spacing.xs,
  },
  toggleRow: {
    minHeight: 46,
    flexDirection: "row",
    alignItems: "center",
    gap: spacing.sm,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: colors.divider,
    borderRadius: radius.sm,
    paddingHorizontal: spacing.md,
    backgroundColor: colors.surface,
  },
  checkbox: {
    width: 22,
    height: 22,
    alignItems: "center",
    justifyContent: "center",
    borderWidth: 1.5,
    borderColor: colors.divider,
    borderRadius: 5,
    backgroundColor: colors.surface,
  },
  checkboxActive: {
    borderColor: colors.accent,
    backgroundColor: colors.accent,
  },
  toggleText: {
    flex: 1,
    color: colors.ink,
    fontSize: 14,
    fontWeight: "800",
  },
  chips: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: spacing.xs,
  },
  chip: {
    minHeight: 36,
    alignItems: "center",
    justifyContent: "center",
    paddingHorizontal: spacing.md,
    borderRadius: radius.pill,
    backgroundColor: colors.surface,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: colors.divider,
  },
  chipActive: {
    backgroundColor: colors.ink,
    borderColor: colors.ink,
  },
  chipText: {
    fontSize: 13,
    fontWeight: "800",
    color: colors.muted,
  },
  chipTextActive: {
    color: colors.surface,
  },
  skillGrid: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: spacing.xs,
  },
  skillChip: {
    minHeight: 36,
    alignItems: "center",
    justifyContent: "center",
    paddingHorizontal: spacing.md,
    borderRadius: radius.sm,
    backgroundColor: colors.surface,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: colors.divider,
  },
  submit: {
    minHeight: 48,
    alignItems: "center",
    justifyContent: "center",
    borderRadius: radius.sm,
    backgroundColor: colors.ink,
    marginTop: spacing.md,
  },
  submitText: {
    color: colors.surface,
    fontSize: 15,
    fontWeight: "800",
  },
  pressed: {
    opacity: 0.7,
  },
  disabled: {
    opacity: 0.5,
  },
});
