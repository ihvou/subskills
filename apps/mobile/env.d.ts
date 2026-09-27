declare namespace NodeJS {
  interface ProcessEnv {
    EXPO_PUBLIC_SUPABASE_URL?: string;
    EXPO_PUBLIC_SUPABASE_ANON_KEY?: string;
    EXPO_PUBLIC_WEB_BASE_URL?: string;
  }
}

declare const process: {
  env: NodeJS.ProcessEnv;
};
