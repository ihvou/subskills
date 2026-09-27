import { revalidatePath } from "next/cache";
import { NextResponse } from "next/server";

export async function POST(request: Request) {
  const secret = request.headers.get("x-revalidate-secret");
  if (!process.env.REVALIDATE_SECRET || secret !== process.env.REVALIDATE_SECRET) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const body = (await request.json().catch(() => ({}))) as {
    category?: string;
    skill?: string;
  };
  if (!body.category) return NextResponse.json({ error: "category is required" }, { status: 400 });

  revalidatePath(`/${body.category}`);
  if (body.skill) revalidatePath(`/${body.category}/${body.skill}`);
  revalidatePath("/sitemap.xml");

  return NextResponse.json({ revalidated: true, category: body.category, skill: body.skill ?? null });
}
