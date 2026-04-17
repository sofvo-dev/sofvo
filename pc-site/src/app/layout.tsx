import type { Metadata } from "next";
import "./globals.css";
import { AuthProvider } from "@/contexts/AuthContext";
import LayoutShell from "@/components/LayoutShell";

export const metadata: Metadata = {
  title: "Sofvo PC - ソフトバレーボール大会管理",
  description:
    "ソフトバレーボール大会の管理・スコア・順位をリアルタイムで表示するPC版サイト",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="ja">
      <head>
        <link rel="preconnect" href="https://firestore.googleapis.com" />
        <link rel="preconnect" href="https://www.googleapis.com" />
        <link rel="dns-prefetch" href="https://firestore.googleapis.com" />
        <script
          dangerouslySetInnerHTML={{
            __html: `(function(){try{
var PC=1024;
var manual=localStorage.getItem('sofvo-ui');
var p=location.pathname;
var onPc=p==='/pc'||p.indexOf('/pc/')===0;
if(manual==='mobile'&&onPc){
  var rest=p.replace(/^\\/pc/,'')||'/';
  location.replace(rest+location.search+location.hash);return;
}
if(manual==='pc')return;
if(!manual&&window.innerWidth<PC&&onPc){
  var rest2=p.replace(/^\\/pc/,'')||'/';
  location.replace(rest2+location.search+location.hash);
}
}catch(e){}})();`,
          }}
        />
      </head>
      <body className="antialiased">
        <AuthProvider>
          <LayoutShell>{children}</LayoutShell>
        </AuthProvider>
      </body>
    </html>
  );
}
