import type { Metadata } from "next";
import { GoRedirect } from "@/components/GoRedirect";

// Forwards an encoded video link (/go#<token>, see OutboundLink). A plain click on
// a card never lands here; a middle-click, "open in new tab" or a pasted link does.
// Static: the token is after `#`, so the server never sees it and one cached page
// serves every video. Not for search engines (robots.txt blocks /go too), and no
// referrer, matching the noreferrer the card links carry.
export const metadata: Metadata = {
  title: "Opening video",
  robots: { index: false, follow: false },
  referrer: "no-referrer",
};

export default function GoPage() {
  return <GoRedirect />;
}
