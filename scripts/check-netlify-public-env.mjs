const required = ["NEXT_PUBLIC_SUPABASE_URL", "NEXT_PUBLIC_SUPABASE_ANON_KEY"];

if (process.env.NETLIFY !== "true") {
  process.exit(0);
}

const missing = required.filter((name) => !process.env[name]);
if (missing.length === 0) {
  process.exit(0);
}

console.error("[netlify-env] Missing public Supabase env vars for the client bundle:");
for (const name of missing) console.error(`- ${name}`);
console.error(
  "[netlify-env] Set these in Netlify with Builds scope, then run Clear cache and deploy site.",
);
process.exit(1);
