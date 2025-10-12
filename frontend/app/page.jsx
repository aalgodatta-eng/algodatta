'use client';
import Image from "next/image";

export default function Home() {
  const domain = process.env.NEXT_PUBLIC_COGNITO_DOMAIN;
  const clientId = process.env.NEXT_PUBLIC_COGNITO_CLIENT_ID;
  const redirectUri = process.env.NEXT_PUBLIC_OIDC_REDIRECT_URI_LOCAL;

  const loginUrl = `${domain}/login?client_id=${clientId}&response_type=code&scope=openid+email+profile&redirect_uri=${encodeURIComponent(redirectUri)}`;
  const signupUrl = `${domain}/signup?client_id=${clientId}&redirect_uri=${encodeURIComponent(redirectUri)}`;
  const forgotPasswordUrl = `${domain}/forgotPassword?client_id=${clientId}&redirect_uri=${encodeURIComponent(redirectUri)}`;

  return (
    <div style={{
      display: "flex", justifyContent: "center", alignItems: "center",
      height: "100vh", background: "linear-gradient(180deg, #ffffff 50%, #0c3c60 50%)"
    }}>
      <div style={{
        width: 380, backgroundColor: "white", borderRadius: 12, padding: 32,
        boxShadow: "0px 4px 20px rgba(0,0,0,0.1)", textAlign: "center"
      }}>
        <Image src="/logo.png" alt="AlgoDatta" width={96} height={96} />
        <h1 style={{ margin: "16px 0", fontSize: 28, color: "#0c3c60" }}>AlgoDatta</h1>

        <div style={{ textAlign: "left", marginBottom: 16 }}>
          <label style={{ fontSize: 14, color: "#333" }}>Email/Username</label>
          <input type="text" placeholder="Email/Username" style={{
            width: "100%", padding: 10, borderRadius: 6, border: "1px solid #ccc", marginTop: 6
          }}/>
        </div>

        <div style={{ textAlign: "left", marginBottom: 24 }}>
          <label style={{ fontSize: 14, color: "#333" }}>Password</label>
          <input type="password" placeholder="Password" style={{
            width: "100%", padding: 10, borderRadius: 6, border: "1px solid #ccc", marginTop: 6
          }}/>
        </div>

        <a href={loginUrl} style={{ textDecoration: "none" }}>
          <button style={{
            width: "100%", padding: 12, backgroundColor: "#0c3c60", color: "white",
            fontWeight: "bold", border: "none", borderRadius: 6, cursor: "pointer"
          }}>Login</button>
        </a>

        <div style={{ display: "flex", justifyContent: "space-between", marginTop: 12, fontSize: 14 }}>
          <a href={forgotPasswordUrl} style={{ color: "#0c3c60", textDecoration: "none" }}>Forgot password?</a>
          <a href={signupUrl} style={{ color: "#0c3c60", textDecoration: "none" }}>Sign up</a>
        </div>
      </div>
    </div>
  );
}
