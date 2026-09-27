const DEFAULT_WEB_BASE_URL = "https://subskills.xyz";

export function webBaseUrl() {
  return (process.env.EXPO_PUBLIC_WEB_BASE_URL ?? DEFAULT_WEB_BASE_URL).replace(/\/+$/, "");
}

export function webUrl(path: string) {
  const normalizedPath = path.startsWith("/") ? path : `/${path}`;
  return `${webBaseUrl()}${normalizedPath}`;
}
