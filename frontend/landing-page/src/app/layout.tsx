import type { Metadata, Viewport } from "next";
import { Be_Vietnam_Pro, IBM_Plex_Mono, Noto_Serif_Display } from "next/font/google";
import { SITE_URL } from "@/lib/site";
import "./globals.css";

const beVietnamPro = Be_Vietnam_Pro({
  weight: ["400", "500", "600", "700"],
  subsets: ["latin", "latin-ext", "vietnamese"],
  variable: "--font-body-family",
  display: "swap",
});

const notoSerifDisplay = Noto_Serif_Display({
  weight: "variable",
  style: ["normal", "italic"],
  subsets: ["latin", "latin-ext", "vietnamese"],
  variable: "--font-display-family",
  display: "swap",
});

const ibmPlexMono = IBM_Plex_Mono({
  weight: ["500", "600"],
  subsets: ["latin", "latin-ext", "vietnamese"],
  variable: "--font-ibm-plex-mono",
  display: "swap",
});

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: "CareSitter — Người thân được chăm, bạn được an lòng",
  description:
    "Kết nối gia đình với người chăm sóc tại nhà đã được xác minh. Đặt ca minh bạch, theo dõi rõ ràng và hỗ trợ xuyên suốt.",
  keywords: [
    "CareSitter",
    "chăm sóc người cao tuổi",
    "người chăm sóc tại nhà",
    "đồng hành sinh hoạt",
    "caregiver Việt Nam",
  ],
  authors: [{ name: "CareSitter Team" }],
  openGraph: {
    title: "CareSitter — Người thân được chăm, bạn được an lòng",
    description:
      "Tìm người chăm sóc tại nhà phù hợp, đã được xác minh và có quy trình theo dõi minh bạch.",
    type: "website",
    locale: "vi_VN",
  },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  maximumScale: 5,
  themeColor: "#F5F3EE",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="vi"
      className={`${beVietnamPro.variable} ${notoSerifDisplay.variable} ${ibmPlexMono.variable}`}
    >
      <body>{children}</body>
    </html>
  );
}
