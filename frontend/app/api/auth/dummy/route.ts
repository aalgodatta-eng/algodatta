import { NextRequest, NextResponse } from "next/server";
export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET(req: NextRequest) {
  const res = NextResponse.redirect(new URL("/dashboard", req.url));
  res.cookies.set("id_token","dummy-token",{ httpOnly: true, sameSite: "lax", path: "/" });
  return res;
}
export {};
