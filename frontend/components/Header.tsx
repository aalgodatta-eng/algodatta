"use client";
import Image from "next/image";
import { usePathname } from "next/navigation";

export default function Header(){
  const pathname = usePathname();
  const logout = ()=>{ document.cookie="id_token=; Max-Age=0; path=/"; window.location.href="/login"; };
  const linkStyle=(p:string)=>({
    color:"#dcf1ff", marginRight:16, textDecoration:"none",
    fontWeight: pathname===p ? 700 : 400,
    borderBottom: pathname===p ? "2px solid #fff" : "none",
    paddingBottom: 4
  });
  return (
    <div style={{background:"#0c3c60",height:96,display:"flex",alignItems:"center",justifyContent:"center",position:"relative"}}>
      <div style={{position:"absolute",left:24,top:24}}>
        <a href="/dashboard" style={linkStyle("/dashboard")}>Dashboard</a>
        <a href="/dashboard/strategies" style={linkStyle("/dashboard/strategies")}>Strategies</a>
        <a href="/dashboard/executions" style={linkStyle("/dashboard/executions")}>Executions</a>
        <a href="/dashboard/reports" style={linkStyle("/dashboard/reports")}>Reports</a>
        <a href="/dashboard/broker" style={linkStyle("/dashboard/broker")}>Broker</a>
        <a href="/dashboard/about" style={linkStyle("/dashboard/about")}>About</a>
        <a href="/dashboard/contact" style={linkStyle("/dashboard/contact")}>Contact</a>
      </div>
      <div style={{display:"flex",flexDirection:"column",alignItems:"center",background:"#fff",padding:"10px 24px",borderRadius:38}}>
        <Image src="/logo.png" width={48} height={48} alt="AlgoDatta"/>
        <div style={{color:"#0c3c60",fontWeight:700,marginTop:4}}>AlgoDatta</div>
      </div>
      <div style={{position:"absolute",right:24}}>
        <button onClick={logout} style={{background:"#fff",color:"#0c3c60",border:"none",borderRadius:8,padding:"10px 16px",cursor:"pointer"}}>Logout</button>
      </div>
    </div>
  );
}
