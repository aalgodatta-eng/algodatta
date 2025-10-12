import { NextResponse } from "next/server";

export async function GET(req) {
  const url = new URL(req.url);
  const code = url.searchParams.get("code");
  if (!code) return NextResponse.json({ error: "Missing code" }, { status: 400 });

  const tokenUrl = `${process.env.NEXT_PUBLIC_COGNITO_DOMAIN}/oauth2/token`;
  const body = new URLSearchParams({
    grant_type: "authorization_code",
    client_id: process.env.NEXT_PUBLIC_COGNITO_CLIENT_ID,
    code,
    redirect_uri: process.env.NEXT_PUBLIC_OIDC_REDIRECT_URI_LOCAL
  });

  const resp = await fetch(tokenUrl, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: body.toString()
  });

  if (!resp.ok) {
    const err = await resp.text();
    return NextResponse.json({ error: "Token exchange failed", details: err }, { status: 401 });
  }

  const tokens = await resp.json();
  const res = NextResponse.redirect(new URL("/dashboard", req.url));
  const cookieOpts = { httpOnly: true, secure: true, sameSite: "lax", path: "/" };
  res.cookies.set("id_token", tokens.id_token, cookieOpts);
  res.cookies.set("access_token", tokens.access_token, cookieOpts);
  if (tokens.refresh_token) res.cookies.set("refresh_token", tokens.refresh_token, cookieOpts);
  return res;
}
