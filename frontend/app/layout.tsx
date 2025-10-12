import Header from "../components/Header";
import Footer from "../components/Footer";

export const metadata = { title: "AlgoDatta" };

export default function RootLayout({children}:{children:React.ReactNode}){
  return (
    <html lang="en">
      <body style={{margin:0,fontFamily:"Inter,Arial"}}>
        <Header />
        {children}
        <Footer />
      </body>
    </html>
  );
}
