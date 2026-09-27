"use client";

import type { AnchorHTMLAttributes, MouseEvent, ReactNode } from "react";
import { decodeOutboundToken, outboundHref } from "@skillsaggregator/shared";

interface OutboundLinkProps
  extends Omit<AnchorHTMLAttributes<HTMLAnchorElement>, "href" | "target" | "rel"> {
  /** The video's /go token (LinkResource.go). Without one, `href` is used as-is. */
  go?: string | null;
  href: string;
  children: ReactNode;
}

/**
 * A link to a video that never prints the video's address. The href is
 * /go#<token>: a plain click decodes it here and opens the video straight away,
 * and anything else (middle-click, "open in new tab", a copied link) loads the
 * /go page, which decodes it and forwards. Links that aren't encoded, such as
 * articles, behave like any other external link.
 */
export function OutboundLink({ go, href, onClick, children, ...rest }: OutboundLinkProps) {
  if (!go) {
    return (
      <a href={href} target="_blank" rel="noreferrer" onClick={onClick} {...rest}>
        {children}
      </a>
    );
  }

  const token = go;
  function open(event: MouseEvent<HTMLAnchorElement>) {
    onClick?.(event);
    if (
      event.defaultPrevented ||
      event.button !== 0 ||
      event.metaKey ||
      event.ctrlKey ||
      event.shiftKey ||
      event.altKey
    ) {
      return;
    }
    const url = decodeOutboundToken(token);
    // A token that won't decode still opens /go, which says the link is broken.
    if (!url) return;
    event.preventDefault();
    window.open(url, "_blank", "noopener,noreferrer");
  }

  return (
    <a href={outboundHref(token)} target="_blank" rel="nofollow noreferrer" onClick={open} {...rest}>
      {children}
    </a>
  );
}
