"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { decodeOutboundToken } from "@skillsaggregator/shared";

/**
 * Decodes the token after `#` and forwards to the video, replacing /go in the
 * history so Back doesn't bounce the viewer through it again. A token that
 * won't decode, or decodes to anything but a video (decodeOutboundToken checks
 * the host), stops here rather than forwarding somewhere unexpected.
 */
export function GoRedirect() {
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    const url = decodeOutboundToken(window.location.hash.slice(1));
    if (url) {
      window.location.replace(url);
    } else {
      setFailed(true);
    }
  }, []);

  return (
    <div className="mx-auto flex max-w-xl flex-col gap-3 px-4 py-24 text-center">
      {failed ? (
        <>
          <h1 className="text-2xl font-extrabold text-ink">This link doesn&apos;t work</h1>
          <p className="text-base text-muted">
            It may have been cut off when it was copied. Find the video on its sub-skill page instead.
          </p>
          <Link href="/" className="focus-ring mx-auto mt-2 rounded-md bg-ink px-4 py-2 text-sm font-bold text-surface">
            Go to Subskills
          </Link>
        </>
      ) : (
        <p className="text-base text-muted">Opening the video…</p>
      )}
    </div>
  );
}
