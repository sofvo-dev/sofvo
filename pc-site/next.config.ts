import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  compress: true,
  basePath: "/pc",
  output: "export",
  trailingSlash: true,
  skipTrailingSlashRedirect: true,
  images: {
    unoptimized: true,
    remotePatterns: [
      { protocol: "https", hostname: "firebasestorage.googleapis.com" },
      { protocol: "https", hostname: "lh3.googleusercontent.com" },
    ],
  },
  experimental: {
    optimizePackageImports: ["firebase/firestore", "firebase/auth"],
  },
};

export default nextConfig;
