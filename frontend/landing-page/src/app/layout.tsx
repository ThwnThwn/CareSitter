import type { Metadata, Viewport } from "next";
import { Be_Vietnam_Pro, Plus_Jakarta_Sans, Space_Grotesk, Inter } from "next/font/google";
import "./globals.css";

const beVietnamPro = Be_Vietnam_Pro({
  weight: ['300', '400', '500', '600', '700', '800'],
  subsets: ['latin', 'vietnamese'],
  variable: '--font-be-vietnam-pro',
  display: 'swap',
});

const plusJakartaSans = Plus_Jakarta_Sans({
  weight: ['600', '700', '800'],
  subsets: ['latin'],
  variable: '--font-plus-jakarta',
  display: 'swap',
});

const spaceGrotesk = Space_Grotesk({
  weight: ['600', '700'],
  subsets: ['latin'],
  variable: '--font-space-grotesk',
  display: 'swap',
});

const inter = Inter({
  weight: ['300', '400', '500', '600', '700'],
  subsets: ['latin', 'vietnamese'],
  variable: '--font-inter',
  display: 'swap',
});

export const metadata: Metadata = {
  title: "CareSitter — Nền Tảng Chăm Sóc Đáng Tin Cậy Cho Gia Đình | Smart Family Care",
  description: "Kết nối người chăm sóc đã xác minh 100% lý lịch tư pháp cho người thân, người cao tuổi, trẻ nhỏ trong vòng 8 phút.",
  keywords: ["CareSitter", "chăm sóc người già", "trông trẻ", "chăm sóc tại nhà", "điều dưỡng gia đình", "caregiver việt nam"],
  authors: [{ name: "CareSitter Team" }],
  icons: {
    icon: "/favicon.ico",
  },
  openGraph: {
    title: "CareSitter — Nền Tảng Chăm Sóc Đáng Tin Cậy Cho Gia Đình",
    description: "Kết nối người chăm sóc đã xác minh 100% lý lịch tư pháp trong vòng 8 phút.",
    type: "website",
    locale: "vi_VN",
  },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  maximumScale: 5,
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="vi"
      className={`scroll-smooth ${beVietnamPro.variable} ${plusJakartaSans.variable} ${spaceGrotesk.variable} ${inter.variable}`}
    >
      <body className="bg-white text-[#0F291E] antialiased selection:bg-[#D1FAE5] selection:text-[#00B14F]">
        {children}
      </body>
    </html>
  );
}
