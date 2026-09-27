"use client";

import { useState, useTransition, type FormEvent } from "react";
import { AlertCircle, CheckCircle2, LoaderCircle, Play } from "lucide-react";
import type { SkillSummary } from "@skillsaggregator/shared";
import { runLinkSearcher } from "@/app/admin/actions";

interface RunNowFormProps {
  skills: SkillSummary[];
}

export function RunNowForm({ skills }: RunNowFormProps) {
  const [isPending, startTransition] = useTransition();
  const [message, setMessage] = useState<{ type: "success" | "error"; text: string } | null>(null);

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    setMessage(null);
    startTransition(async () => {
      try {
        const result = await runLinkSearcher(formData);
        setMessage({
          type: "success",
          text: result.demo
            ? "Demo run acknowledged."
            : `Run started${result.run_id ? ` (${result.run_id.slice(0, 8)})` : ""}.`,
        });
      } catch (error) {
        setMessage({
          type: "error",
          text: error instanceof Error ? error.message : "Run failed to start.",
        });
      }
    });
  }

  return (
    <form onSubmit={handleSubmit} className="rounded-lg border border-ink/10 bg-white p-4 shadow-sm">
      <div className="flex flex-col gap-3 sm:flex-row">
        <label className="sr-only" htmlFor="skill_id">
          Skill
        </label>
        <select
          id="skill_id"
          name="skill_id"
          className="focus-ring min-h-11 flex-1 rounded-md border border-ink/15 bg-white px-3 text-sm"
          defaultValue={skills[0]?.id}
          disabled={isPending || skills.length === 0}
        >
          {skills.map((skill) => (
            <option key={skill.id} value={skill.id}>
              {skill.name}
            </option>
          ))}
        </select>
        <button
          type="submit"
          disabled={isPending || skills.length === 0}
          className="focus-ring inline-flex min-h-11 items-center justify-center gap-2 rounded-md bg-court px-4 text-sm font-semibold text-white hover:bg-ink disabled:cursor-not-allowed disabled:opacity-50"
        >
          {isPending ? (
            <LoaderCircle className="h-4 w-4 animate-spin" aria-hidden="true" />
          ) : (
            <Play className="h-4 w-4" aria-hidden="true" />
          )}
          {isPending ? "Starting" : "Run now"}
        </button>
      </div>
      {message ? (
        <p
          className={`mt-3 flex items-center gap-2 text-sm ${
            message.type === "success" ? "text-court" : "text-red-700"
          }`}
          role={message.type === "error" ? "alert" : "status"}
        >
          {message.type === "success" ? (
            <CheckCircle2 className="h-4 w-4" aria-hidden="true" />
          ) : (
            <AlertCircle className="h-4 w-4" aria-hidden="true" />
          )}
          {message.text}
        </p>
      ) : null}
    </form>
  );
}
