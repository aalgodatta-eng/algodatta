import { NextResponse } from "next/server";
const COGNITO_LOGIN_URL = "https://algodattalocal-1760330072.auth.ap-south-1.amazoncognito.com/login?client_id=1jv7qapheugsst70dha2ous88p&response_type=code&scope=email+openid+profile&redirect_uri=http://localhost:3000/dashboard";
export function middleware(req: Request) {
  const url = new URL(req.url);
  if (url.pathname === "/" || url.pathname === "/login") {
    return NextResponse.redirect(COGNITO_LOGIN_URL);
  }
  return NextResponse.next();
}
