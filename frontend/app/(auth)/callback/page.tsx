"use client";
import { useEffect } from "react";

export default function CallbackPage() {
  useEffect(() => {
    const url = new URL(window.location.href);
    const code = url.searchParams.get("code");
    if (code) {
      fetch(`/api/auth/callback?code=${code}`)
        .then((r) => {
          if (r.redirected) window.location.href = r.url;
        })
        .catch(() => alert("Login failed"));
    }
  }, []);
  return <p className="p-4 text-gray-700">Processing Cognito login...</p>;
}
