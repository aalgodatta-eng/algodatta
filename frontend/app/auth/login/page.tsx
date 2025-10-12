"use client";
export default function LoginPage(){
  const login=()=>{ window.location.href="/api/auth/dummy"; };
  return (
    <div style={{minHeight:"100vh",display:"flex",justifyContent:"center",alignItems:"center"}}>
      <div style={{background:"#fff",padding:32,borderRadius:12,boxShadow:"0 4px 20px rgba(0,0,0,0.12)",textAlign:"center"}}>
        <img src="/logo.png" width="100" height="100" alt="AlgoDatta"/>
        <h1 style={{margin:"16px 0",color:"#0c3c60"}}>AlgoDatta</h1>
        <button onClick={login} style={{width:"100%",padding:12,background:"#0c3c60",color:"#fff",border:"none",borderRadius:6}}>
          Login
        </button>
      </div>
    </div>
  );
}
