import { NextRequest, NextResponse } from "next/server";

function decodeJwtPayload(token: string) {
  const part = token.split(".")[1];
  if (!part) return {};
  const json = Buffer.from(part.replace(/-/g, "+").replace(/_/g, "/"), "base64").toString("utf-8");
  return JSON.parse(json);
}

export async function GET(req: NextRequest) {
  const id = req.cookies.get("id_token")?.value;
  if (!id) return NextResponse.json({ user: null }, { status: 401 });
  const claims = decodeJwtPayload(id);
  return NextResponse.json({ user: { email: claims.email, username: claims["cognito:username"] || claims["username"] || claims["sub"] } });
}
