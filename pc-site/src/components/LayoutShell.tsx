"use client";

import { usePathname } from "next/navigation";
import Sidebar from "./Sidebar";

const noSidebarPaths = ["/login", "/register"];

export default function LayoutShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const showSidebar = !noSidebarPaths.includes(pathname);

  return (
    <div className="flex min-h-screen">
      {showSidebar && <Sidebar />}
      <main className={`flex-1 ${showSidebar ? "ml-60" : ""}`}>
        {children}
      </main>
    </div>
  );
}
