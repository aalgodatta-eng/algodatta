'use client';
import { useEffect, useState } from 'react';

export default function Dashboard() {
  const [msg, setMsg] = useState("Loading...");

  useEffect(() => {
    fetch(`${process.env.NEXT_PUBLIC_API_BASE}/api/v1/strategies`, { credentials: "include" })
      .then(async r => {
        if (!r.ok) throw new Error(await r.text());
        return r.json();
      })
      .then(data => setMsg(data.msg))
      .catch(() => setMsg("Not logged in"));
  }, []);

  return (
    <div style={{padding:'40px'}}>
      <h2>AlgoDatta Dashboard</h2>
      <p>{msg}</p>
    </div>
  );
}
