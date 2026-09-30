'use client';

import React, { useState, useEffect } from 'react';
import { Heart, Menu, X, ShieldCheck } from 'lucide-react';

interface HeaderProps {
  onOpenBooking: () => void;
}

export default function Header({ onOpenBooking }: HeaderProps) {
  const [isScrolled, setIsScrolled] = useState(false);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  useEffect(() => {
    const handleScroll = () => {
      if (window.scrollY > 20) {
        setIsScrolled(true);
      } else {
        setIsScrolled(false);
      }
    };

    window.addEventListener('scroll', handleScroll, { passive: true });
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  return (
    <>
      <header
        id="main-header"
        className={`fixed top-0 left-0 right-0 z-50 bg-white border-b transition-all duration-300 ${
          isScrolled ? 'border-[#D1FAE5] shadow-sm py-2' : 'border-[#D1FAE5] py-3'
        }`}
      >
        <div className="max-w-7xl mx-auto px-6 h-14 sm:h-16 flex items-center justify-between">
          {/* Logo */}
          <a href="#" className="flex items-center gap-3 group hover-target">
            <div className="w-10 h-10 rounded-xl bg-[#00B14F] p-0.5 flex items-center justify-center group-hover:scale-105 transition-transform duration-300 shadow-sm">
              <div className="w-full h-full bg-white rounded-[10px] flex items-center justify-center">
                <Heart className="w-5 h-5 text-[#00B14F] fill-[#00B14F]" />
              </div>
            </div>
            <div className="flex flex-col">
              <span className="font-headline font-extrabold text-xl tracking-tight text-[#0F291E] flex items-center gap-1">
                CareSitter
                <span className="w-2 h-2 rounded-full bg-[#00B14F] animate-pulse" />
              </span>
              <span className="text-[9px] uppercase tracking-widest text-[#4A6B5D] font-bold">
                Smart Family Care
              </span>
            </div>
          </a>

          {/* Desktop Navigation */}
          <nav className="hidden md:flex items-center gap-8 text-sm font-semibold text-[#0F291E]">
            <a href="#how-it-works" className="hover:text-[#00B14F] transition-colors hover-target">
              Quy trình
            </a>
            <a href="#caregivers" className="hover:text-[#00B14F] transition-colors hover-target">
              Đội ngũ Caregiver
            </a>
            <a href="#features" className="hover:text-[#00B14F] transition-colors hover-target">
              Tính năng vượt trội
            </a>
            <a href="#testimonials" className="hover:text-[#00B14F] transition-colors hover-target">
              Đánh giá
            </a>
          </nav>

          {/* Action Buttons */}
          <div className="flex items-center gap-3">
            <button
              onClick={onOpenBooking}
              className="hidden lg:inline-flex items-center gap-1.5 text-xs font-bold uppercase tracking-wider text-[#00B14F] px-4 py-2 rounded-full border border-[#D1FAE5] bg-[#ECFDF5] hover:bg-[#D1FAE5] transition-colors hover-target btn-ripple"
            >
              <ShieldCheck size={16} /> 100% Kiểm định
            </button>
            <a
              href="#download"
              className="px-5 py-2.5 rounded-full font-headline font-bold text-xs uppercase tracking-wider bg-[#00B14F] text-white hover:bg-[#009b45] active:scale-95 transition-all hover-target btn-ripple shadow-sm"
            >
              Tải ứng dụng
            </a>

            {/* Mobile Menu Button */}
            <button
              onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
              className="md:hidden w-10 h-10 rounded-full border border-[#D1FAE5] bg-[#F0FDF4] flex items-center justify-center text-[#0F291E]"
              aria-label="Toggle menu"
            >
              {mobileMenuOpen ? <X size={20} /> : <Menu size={20} />}
            </button>
          </div>
        </div>
      </header>

      {/* Mobile Menu Drawer */}
      {mobileMenuOpen && (
        <div className="fixed inset-0 top-16 z-40 bg-white/95 backdrop-blur-md md:hidden p-6 flex flex-col justify-between border-b border-[#D1FAE5] animate-fadeIn">
          <nav className="flex flex-col gap-5 text-lg font-bold text-[#0F291E] pt-4">
            <a
              href="#how-it-works"
              onClick={() => setMobileMenuOpen(false)}
              className="hover:text-[#00B14F] transition-colors py-2 border-b border-slate-100"
            >
              Quy trình đặt ca
            </a>
            <a
              href="#caregivers"
              onClick={() => setMobileMenuOpen(false)}
              className="hover:text-[#00B14F] transition-colors py-2 border-b border-slate-100"
            >
              Đội ngũ Caregiver tiêu biểu
            </a>
            <a
              href="#features"
              onClick={() => setMobileMenuOpen(false)}
              className="hover:text-[#00B14F] transition-colors py-2 border-b border-slate-100"
            >
              Tính năng an toàn
            </a>
            <a
              href="#testimonials"
              onClick={() => setMobileMenuOpen(false)}
              className="hover:text-[#00B14F] transition-colors py-2 border-b border-slate-100"
            >
              Đánh giá từ gia đình
            </a>
          </nav>
          <div className="space-y-3 pt-6 border-t border-[#D1FAE5]">
            <button
              onClick={() => {
                setMobileMenuOpen(false);
                onOpenBooking();
              }}
              className="w-full py-3.5 rounded-full border border-[#00B14F] text-[#00B14F] font-bold text-sm bg-[#ECFDF5]"
            >
              Đặt Ca Nhanh
            </button>
            <a
              href="#download"
              onClick={() => setMobileMenuOpen(false)}
              className="w-full py-3.5 rounded-full bg-[#00B14F] text-white font-bold text-sm flex items-center justify-center"
            >
              Tải App Ngay
            </a>
          </div>
        </div>
      )}
    </>
  );
}
