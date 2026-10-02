"use client";

import { useState } from "react";
import CaregiversSection from "@/components/CaregiversSection";
import DownloadCTASection from "@/components/DownloadCTASection";
import FeaturesSection from "@/components/FeaturesSection";
import Footer from "@/components/Footer";
import Header from "@/components/Header";
import HeroSection from "@/components/HeroSection";
import HowItWorksSection from "@/components/HowItWorksSection";
import QuickBookModal from "@/components/QuickBookModal";
import ScrollMotion from "@/components/ScrollMotion";
import StatsSection from "@/components/StatsSection";
import TestimonialsSection from "@/components/TestimonialsSection";

export default function LandingPage() {
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [modalCaregiver, setModalCaregiver] = useState(
    "Chuyên viên CareSitter",
  );
  const [modalService, setModalService] = useState(
    "Chăm sóc người cao tuổi",
  );

  const handleOpenBooking = (caregiver?: string, service?: string) => {
    setModalCaregiver(caregiver ?? "Chuyên viên CareSitter");
    setModalService(service ?? "Chăm sóc người cao tuổi");
    setIsModalOpen(true);
  };

  return (
    <>
      <a className="skip-link" href="#main-content">
        Bỏ qua điều hướng
      </a>
      <ScrollMotion />
      <Header onOpenBooking={() => handleOpenBooking()} />

      <main id="main-content">
        <HeroSection onOpenBooking={handleOpenBooking} />
        <StatsSection />
        <FeaturesSection />
        <HowItWorksSection />
        <CaregiversSection onOpenBooking={handleOpenBooking} />
        <TestimonialsSection />
        <DownloadCTASection onOpenBooking={() => handleOpenBooking()} />
      </main>

      <Footer />
      {isModalOpen ? (
        <QuickBookModal
          isOpen
          onClose={() => setIsModalOpen(false)}
          caregiverName={modalCaregiver}
          serviceCategory={modalService}
        />
      ) : null}
    </>
  );
}
