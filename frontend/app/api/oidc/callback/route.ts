import { NextRequest, NextResponse } from "next/server";

export async function GET(req: NextRequest) {
  const url = new URL(req.url);
  const code = url.searchParams.get("code");
  if (!code) return NextResponse.redirect(new URL("/login", req.url));

  const tokenUrl = `${process.env.NEXT_PUBLIC_COGNITO_DOMAIN}/oauth2/token`;
  const body = new URLSearchParams({
    grant_type: "authorization_code",
    client_id: process.env.NEXT_PUBLIC_COGNITO_CLIENT_ID!,
    code,
    redirect_uri: process.env.NEXT_PUBLIC_OIDC_REDIRECT_URI_LOCAL!,
  });

  const resp = await fetch(tokenUrl, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: body.toString(),
  });

  if (!resp.ok) return NextResponse.redirect(new URL("/login", req.url));
  const tokens = await resp.json();

  // Set secure cookies then send to /dashboard
  const res = NextResponse.redirect(new URL("/dashboard", req.url));
  res.cookies.set("id_token", tokens.id_token, { httpOnly: true, sameSite: "lax", path: "/" });
  res.cookies.set("access_token", tokens.access_token, { httpOnly: true, sameSite: "lax", path: "/" });
  if (tokens.refresh_token) {
    res.cookies.set("refresh_token", tokens.refresh_token, { httpOnly: true, sameSite: "lax", path: "/" });
  }
  return res;
}
