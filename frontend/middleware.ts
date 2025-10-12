import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

export function middleware(req: NextRequest) {
  const token=req.cookies.get("id_token");
  const url=req.nextUrl;
  if (url.pathname === "/") return NextResponse.redirect(new URL("/login", url));
  if (url.pathname.startsWith("/dashboard") && !token) return NextResponse.redirect(new URL("/login", url));
  return NextResponse.next();
}
export const config = { matcher: ["/", "/dashboard/:path*"] };
