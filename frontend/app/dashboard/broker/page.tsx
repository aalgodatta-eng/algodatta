"use client";
import { useEffect, useState } from "react";

type Broker = { broker_name:string; client_id:string; auth_token:string; connected_at:string };

export default function BrokerIntegration(){
  const [brokerName, setBrokerName] = useState("");
  const [clientId, setClientId] = useState("");
  const [accessToken, setAccessToken] = useState("");
  const [status, setStatus] = useState<"idle"|"success"|"error">("idle");
  const [broker, setBroker] = useState<Broker | null>(null);
  const api = process.env.NEXT_PUBLIC_API_BASE || "http://localhost:8000";

  async function refresh(){
    try{
      const r = await fetch(`${api}/api/broker2`);
      if (r.ok) {
        const d = await r.json();
        setBroker(d.brokers && d.brokers.length ? d.brokers[0] : null);
      }
    }catch{}
  }

  async function submit(){
    try{
      const r = await fetch(`${api}/api/broker2`, {
        method: "POST",
        headers: {"Content-Type":"application/json"},
        body: JSON.stringify({ broker_name: brokerName, client_id: clientId, auth_token: accessToken })
      });
      setStatus(r.ok ? "success" : "error");
      if (r.ok) { await refresh(); }
    }catch{ setStatus("error"); }
  }

  useEffect(()=>{ refresh(); },[]);

  return (
    <div style={{padding:40}}>
      <h2>Broker Integration</h2>
      <input placeholder="Broker Name" value={brokerName} onChange={e=>setBrokerName(e.target.value)}
             style={{display:"block",width:"100%",padding:12,marginBottom:12,border:"1px solid #cfd7e6",borderRadius:6}}/>
      <input placeholder="Client ID" value={clientId} onChange={e=>setClientId(e.target.value)}
             style={{display:"block",width:"100%",padding:12,marginBottom:12,border:"1px solid #cfd7e6",borderRadius:6}}/>
      <input type="password" placeholder="Access Token" value={accessToken} onChange={e=>setAccessToken(e.target.value)}
             style={{display:"block",width:"100%",padding:12,marginBottom:20,border:"1px solid #cfd7e6",borderRadius:6}}/>
      <button onClick={submit} style={{width:"100%",padding:12,background:"#0c3c60",color:"#fff",border:"none",borderRadius:6}}>
        Submit
      </button>
      {status==="success" && <p style={{color:"green",marginTop:12}}>Integration with {brokerName} Successful ✔</p>}
      {status==="error"   && <p style={{color:"red",marginTop:12}}>Integration with {brokerName} Failed ❌</p>}
      <div style={{marginTop:24}}>
        <h4>Linked Broker</h4>
        {!broker ? <p style={{opacity:.7}}>No broker linked yet.</p> :
          <div style={{border:"1px solid #e6ebf2",borderRadius:8,padding:12}}>
            <div><strong>Broker:</strong> {broker.broker_name}</div>
            <div><strong>Client ID:</strong> {broker.client_id}</div>
            <div><strong>Access Token:</strong> ••••••••••</div>
            <div style={{fontSize:"0.85em",color:"#666"}}><strong>Linked at:</strong> {broker.connected_at}</div>
          </div>}
      </div>
    </div>
  );
}
