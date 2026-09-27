"use client";

import { useState } from "react";
import { Apple, Play } from "lucide-react";

/**
 * Two "download the app" CTAs for the home hero. iOS went live on 2026-09-24 and
 * links straight to the store; the id-only URL lets Apple redirect to the
 * visitor's own storefront. Android is still in closed testing, so that button
 * reveals a "coming soon" notice — swap it for the Play URL once it ships.
 */
const APP_STORE_URL = "https://apps.apple.com/app/id6810049311";

export function AppDownloadButtons() {
  const [showNotice, setShowNotice] = useState(false);

  const buttonClass =
    "focus-ring inline-flex items-center justify-center gap-2 rounded-md bg-ink px-4 py-2.5 text-sm font-bold text-surface transition hover:opacity-90";

  return (
    <div>
      <div className="flex flex-wrap items-center gap-3">
        <a href={APP_STORE_URL} className={buttonClass}>
          <Apple className="h-4 w-4" />
          App Store
        </a>
        <button type="button" onClick={() => setShowNotice(true)} className={buttonClass}>
          <Play className="h-4 w-4" />
          Google Play
        </button>
      </div>
      {showNotice ? (
        <p role="status" className="mt-3 text-sm font-medium text-ink">
          The Android app is in closed testing — coming very soon.
        </p>
      ) : null}
    </div>
  );
}
