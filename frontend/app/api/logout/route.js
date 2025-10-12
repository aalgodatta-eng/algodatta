import { NextResponse } from "next/server";
export async function POST() {
  const res = NextResponse.redirect(new URL("/", "http://localhost:3000"));
  ["id_token","access_token","refresh_token"].forEach(n => res.cookies.set(n, "", { path: "/", maxAge: 0 }));
  return res;
}
