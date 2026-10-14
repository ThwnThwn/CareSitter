


import CaregiversSection from "@/components/CaregiversSection";
import DownloadCTASection from "@/components/DownloadCTASection";
import FeaturesSection from "@/components/FeaturesSection";
import Footer from "@/components/Footer";
import Header from "@/components/Header";
import HeroSection from "@/components/HeroSection";
import HowItWorksSection from "@/components/HowItWorksSection";
import ConsultationProvider from "@/features/consultation/ConsultationProvider";
import ScrollMotion from "@/components/ScrollMotion";
import StatsSection from "@/components/StatsSection";
import TestimonialsSection from "@/components/TestimonialsSection";

export default function LandingPage() {
  return (
    <ConsultationProvider>
      <a className="skip-link" href="#main-content">
        Bỏ qua điều hướng
      </a>
      <ScrollMotion />
      <Header />

      <main id="main-content">
        <HeroSection />
        <StatsSection />
        <FeaturesSection />
        <HowItWorksSection />
        <CaregiversSection />
        <TestimonialsSection />
        <DownloadCTASection />
      </main>

      <Footer />
    </ConsultationProvider>
  );
}
