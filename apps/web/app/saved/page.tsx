import type { Metadata } from "next";
import { SavedResourceBrowser } from "@/components/SavedResourceBrowser";

export const metadata: Metadata = {
  title: "Library | Subskills",
  description: "Watch later and watched resources tied to your account.",
};

export default function SavedPage() {
  return <SavedResourceBrowser />;
}
