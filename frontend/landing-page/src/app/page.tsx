'use client';

import React, { useState } from 'react';
import CustomCursor from '@/components/CustomCursor';
import ScrollProgressBar from '@/components/ScrollProgressBar';
import Header from '@/components/Header';
import HeroSection from '@/components/HeroSection';
import StatsSection from '@/components/StatsSection';
import HowItWorksSection from '@/components/HowItWorksSection';
import CaregiversSection from '@/components/CaregiversSection';
import FeaturesSection from '@/components/FeaturesSection';
import TestimonialsSection from '@/components/TestimonialsSection';
import DownloadCTASection from '@/components/DownloadCTASection';
import Footer from '@/components/Footer';
import QuickBookModal from '@/components/QuickBookModal';

export default function LandingPage() {
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [modalCaregiver, setModalCaregiver] = useState('Chuyên viên CareSitter');
  const [modalService, setModalService] = useState('Chăm sóc người cao tuổi');

  const handleOpenBooking = (caregiver?: string, service?: string) => {
    if (caregiver) setModalCaregiver(caregiver);
    if (service) setModalService(service);
    setIsModalOpen(true);
  };

  const handleCloseBooking = () => {
    setIsModalOpen(false);
  };

  return (
    <main className="relative min-h-screen flex flex-col bg-white">
      {/* Interactive Micro-Elements */}
      <ScrollProgressBar />
      <CustomCursor />

      {/* Navigation Header */}
      <Header onOpenBooking={() => handleOpenBooking()} />

      {/* Core Sections */}
      <HeroSection onOpenBooking={handleOpenBooking} />
      <StatsSection />
      <HowItWorksSection />
      <CaregiversSection onOpenBooking={handleOpenBooking} />
      <FeaturesSection onOpenBooking={() => handleOpenBooking()} />
      <TestimonialsSection />
      <DownloadCTASection />

      {/* Comprehensive Footer */}
      <Footer />

      {/* Interactive Quick Booking Modal Dialog */}
      <QuickBookModal
        isOpen={isModalOpen}
        onClose={handleCloseBooking}
        caregiverName={modalCaregiver}
        serviceCategory={modalService}
      />
    </main>
  );
}
