import "./globals.css";
import type { Metadata, Viewport } from "next";
import type { CSSProperties, ReactNode } from "react";
import { Providers } from "@/components/providers/providers";
import { fontVariables } from "@/lib/fonts";
import { site } from "@/lib/site";
import { pressSpring } from "@/lib/spring";

export const metadata: Metadata = {
  metadataBase: new URL(site.url),
  title: site.title,
  description: site.description,
  applicationName: site.name,
  alternates: { canonical: "/" },
  openGraph: {
    type: "website",
    url: "/",
    siteName: site.name,
    title: site.title,
    description: site.description,
  },
  twitter: {
    card: "summary_large_image",
    title: site.title,
    description: site.description,
  },
};

export const viewport: Viewport = {
  themeColor: "#000000",
  colorScheme: "dark",
};

const springStyle = {
  "--spring-press": pressSpring.easing,
  "--spring-press-duration": `${pressSpring.duration}s`,
} as CSSProperties;

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en" className={fontVariables} style={springStyle}>
      <body>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
