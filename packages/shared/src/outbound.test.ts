import { describe, expect, it } from "vitest";
import { decodeOutboundToken, encodeOutboundToken, isEncodedVideoUrl, outboundHref } from "./outbound";

const videos = [
  "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
  "https://youtu.be/dQw4w9WgXcQ?t=42",
  "https://m.youtube.com/watch?v=abc&list=PL_ünïcode",
  "https://www.tiktok.com/@coach/video/7300000000000000000",
  "https://www.instagram.com/reel/C1a2b3c4d5e/",
];

describe("outbound tokens", () => {
  it("round-trips a video on every encoded host", () => {
    for (const url of videos) {
      expect(decodeOutboundToken(encodeOutboundToken(url))).toBe(url);
    }
  });

  it("keeps the address out of the token", () => {
    for (const url of videos) {
      expect(encodeOutboundToken(url)).not.toMatch(/youtu|tiktok|instagram|watch|reel|http/i);
    }
  });

  it("is stable for one video and differs between videos from the first characters", () => {
    const a = encodeOutboundToken("https://www.youtube.com/watch?v=aaaaaaaaaaa");
    const b = encodeOutboundToken("https://www.youtube.com/watch?v=bbbbbbbbbbb");
    expect(encodeOutboundToken("https://www.youtube.com/watch?v=aaaaaaaaaaa")).toBe(a);
    expect(a?.slice(0, 8)).not.toBe(b?.slice(0, 8));
  });

  it("leaves every other site alone", () => {
    expect(encodeOutboundToken("https://example.com/article")).toBeNull();
    expect(encodeOutboundToken(null)).toBeNull();
    expect(isEncodedVideoUrl("https://notyoutube.com/watch?v=x")).toBe(false);
    expect(isEncodedVideoUrl("https://youtube.com.evil.example/watch?v=x")).toBe(false);
    expect(isEncodedVideoUrl("javascript:alert(1)//youtube.com")).toBe(false);
  });

  it("refuses a tampered, empty or foreign token instead of forwarding somewhere else", () => {
    const token = encodeOutboundToken(videos[0])!;
    const flipped = token.slice(0, 10) + (token[10] === "A" ? "B" : "A") + token.slice(11);
    expect(decodeOutboundToken(flipped)).toBeNull();
    expect(decodeOutboundToken("")).toBeNull();
    expect(decodeOutboundToken("2" + token.slice(1))).toBeNull();
    expect(decodeOutboundToken("1***")).toBeNull();
  });

  it("builds the /go href", () => {
    expect(outboundHref("1abc")).toBe("/go#1abc");
  });
});
