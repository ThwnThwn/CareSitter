'use client';

import React, { useState } from 'react';
import Image from 'next/image';
import {
  Zap,
  ShieldCheck,
  ChevronDown,
  Bell,
  UserCheck,
  Heart,
  Calendar,
  MessageSquare,
  User
} from 'lucide-react';

interface HeroSectionProps {
  onOpenBooking: (caregiver?: string, service?: string) => void;
}

export default function HeroSection({ onOpenBooking }: HeroSectionProps) {
  const [selectedService, setSelectedService] = useState('elderly');
  const [phoneTapped, setPhoneTapped] = useState(false);

  return (
    <section className="min-h-[calc(100vh-70px)] flex items-center relative pt-28 pb-16 lg:py-24 overflow-hidden bg-white">
      {/* Background Subtle Geometry & Radial Glow */}
      <div className="absolute top-1/4 left-1/2 -translate-x-1/2 w-[700px] h-[500px] bg-[#ECFDF5]/50 rounded-full blur-3xl pointer-events-none -z-10" />

      <div className="max-w-7xl mx-auto px-6 w-full">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 lg:gap-8 items-center">

          {/* Left 58% Content */}
          <div className="lg:col-span-7 flex flex-col items-start space-y-6 sm:space-y-7 z-10">

            {/* Badge with breathing scale */}
            <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-[#ECFDF5] border border-[#D1FAE5] animate-badge-breath">
              <span className="w-2 h-2 rounded-full bg-[#00B14F] animate-ping" />
              <span className="text-xs uppercase font-bold text-[#00B14F] tracking-wider">
                Nền tảng đặt chăm sóc #1 Việt Nam
              </span>
            </div>

            {/* Headline with Word Reveal */}
            <h1 className="font-headline font-extrabold text-4xl sm:text-5xl lg:text-[68px] leading-[1.08] tracking-[-0.03em] text-[#0F291E]">
              <span className="word-reveal" style={{ animationDelay: '150ms' }}>Find</span>{' '}
              <span className="word-reveal" style={{ animationDelay: '300ms' }}>Trusted</span>{' '}
              <span className="word-reveal" style={{ animationDelay: '450ms' }}>Care,</span>
              <br />
              <span className="word-reveal text-[#00B14F]" style={{ animationDelay: '600ms' }}>In</span>{' '}
              <span className="word-reveal text-[#00B14F]" style={{ animationDelay: '750ms' }}>Minutes.</span>
            </h1>

            {/* Subheadline */}
            <p className="text-base sm:text-lg lg:text-xl text-[#4A6B5D] font-normal max-w-xl leading-relaxed">
              Kết nối người chăm sóc đã xác minh 100% lý lịch tư pháp cho người thân của bạn — người cao tuổi, trẻ nhỏ và chăm sóc đặc biệt. Đặt lịch chỉ trong 3 chạm.
            </p>

            {/* CTA Buttons */}
            <div className="flex flex-wrap items-center gap-4 pt-2 w-full sm:w-auto">
              {/* App Store Button */}
              <a
                href="#download"
                className="hover-target btn-ripple group flex items-center gap-3.5 px-7 py-4 rounded-full bg-[#00B14F] text-white font-headline font-bold text-sm tracking-wide hover:bg-[#009b45] active:scale-95 transition-all shadow-md"
              >
                <svg className="w-6 h-6 fill-current transition-transform group-hover:scale-110" viewBox="0 0 24 24">
                  <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M15.97 6.37c.61-.75 1.04-1.8 1.01-2.87-.9.04-2 .6-2.65 1.35-.58.65-1.09 1.71-1.01 2.76.99.08 2.04-.49 2.65-1.24z" />
                </svg>
                <div className="text-left leading-tight">
                  <div className="text-[10px] uppercase font-semibold tracking-wider text-[#ECFDF5]">Download on</div>
                  <div className="text-base font-extrabold text-white">App Store</div>
                </div>
              </a>

              {/* Google Play Button */}
              <a
                href="#download"
                className="hover-target btn-ripple group flex items-center gap-3.5 px-7 py-4 rounded-full bg-white text-[#0F291E] font-headline font-bold text-sm tracking-wide border-2 border-[#D1FAE5] hover:border-[#00B14F] hover:bg-[#F0FDF4] active:scale-95 transition-all shadow-sm"
              >
                <svg className="w-6 h-6 fill-current text-[#00B14F] transition-transform group-hover:scale-110" viewBox="0 0 24 24">
                  <path d="M3.609 1.814L13.792 12 3.61 22.186a2.38 2.38 0 0 1-.61-.989V2.803c.174-.383.39-.73.61-.989zm11.603 11.604l2.568-2.568-11.75-6.784 9.182 9.352zm2.568-2.568l-2.568-2.569 2.568-2.568 3.522 2.033c1.004.58 1.004 1.523 0 2.103l-3.522 3.002zm-5.137-5.137L3.46 2.16 15.21 8.944l-2.567 2.369z" />
                </svg>
                <div className="text-left leading-tight">
                  <div className="text-[10px] uppercase font-semibold tracking-wider text-[#4A6B5D]">Get it on</div>
                  <div className="text-base font-extrabold text-[#0F291E]">Google Play</div>
                </div>
              </a>
            </div>

            {/* Trust proof avatar group */}
            <div className="flex items-center gap-4 pt-3">
              <div className="flex -space-x-3">
                <div className="w-10 h-10 rounded-full border-2 border-white overflow-hidden relative shadow-sm">
                  <Image src="/images/caregiver-1.jpg" alt="Caregiver Hải Đường" fill className="object-cover" />
                </div>
                <div className="w-10 h-10 rounded-full border-2 border-white overflow-hidden relative shadow-sm">
                  <Image src="/images/caregiver-2.jpg" alt="Caregiver Trần Văn Nam" fill className="object-cover" />
                </div>
                <div className="w-10 h-10 rounded-full border-2 border-white overflow-hidden relative shadow-sm">
                  <Image src="/images/caregiver-3.jpg" alt="Caregiver Nguyễn Thị Bích" fill className="object-cover" />
                </div>
                <div className="w-10 h-10 rounded-full border-2 border-white bg-[#00B14F] flex items-center justify-center text-xs font-bold text-white shadow-sm">
                  +50k
                </div>
              </div>
              <div className="text-xs text-[#4A6B5D] font-medium">
                <div className="flex items-center text-amber-500 gap-1 font-bold">
                  <span>★</span><span>★</span><span>★</span><span>★</span><span>★</span>
                  <span className="text-[#0F291E] ml-1 font-bold">4.9/5</span>
                </div>
                <span>Từ hơn 12,000+ gia đình tin dùng</span>
              </div>
            </div>

          </div>

          {/* Right 42% Phone Mockup Visual */}
          <div className="lg:col-span-5 flex justify-center items-center relative phone-3d-wrapper">

            {/* Floating Glass Badges */}
            <div className="hidden sm:flex absolute -left-8 top-16 z-20 flat-card px-4 py-3 rounded-2xl items-center gap-3 floating-card-wobble">
              <div className="w-10 h-10 rounded-xl bg-[#ECFDF5] text-[#00B14F] flex items-center justify-center font-bold">
                <Zap size={20} />
              </div>
              <div>
                <div className="text-[10px] uppercase text-[#4A6B5D] font-bold">Thời gian kết nối</div>
                <div className="text-sm font-headline font-bold text-[#0F291E]">&lt; 8 Phút Có Ngay</div>
              </div>
            </div>

            <div className="hidden sm:flex absolute -right-6 bottom-20 z-20 flat-card px-4 py-3 rounded-2xl items-center gap-3 floating-card-wobble">
              <div className="w-10 h-10 rounded-xl bg-[#ECFDF5] text-[#00B14F] flex items-center justify-center font-bold">
                <ShieldCheck size={20} />
              </div>
              <div>
                <div className="text-[10px] uppercase text-[#4A6B5D] font-bold">Bảo chứng an toàn</div>
                <div className="text-sm font-headline font-bold text-[#0F291E]">100% Lý Lịch Tư Pháp</div>
              </div>
            </div>

            {/* 3D Phone Shell */}
            <div
              onClick={() => setPhoneTapped(!phoneTapped)}
              className="hero-phone-mockup mockup-floating-active w-[310px] h-[630px] bg-slate-900 rounded-[52px] p-3.5 border-4 border-slate-700/80 shadow-2xl relative overflow-hidden select-none cursor-pointer"
            >
              {/* Dynamic Island */}
              <div className="absolute top-6 left-1/2 -translate-x-1/2 w-28 h-6 bg-black rounded-full z-40 flex items-center justify-center gap-2">
                <div className="w-2.5 h-2.5 rounded-full bg-slate-900 border border-slate-800" />
                <div className="w-2.5 h-2.5 rounded-full bg-emerald-950/80" />
              </div>

              {/* Inner Screen */}
              <div className="w-full h-full bg-[#F8FAFC] text-slate-800 rounded-[40px] overflow-hidden flex flex-col pt-8 pb-3 text-xs">

                {/* App Header */}
                <div className="px-4 py-2 flex items-center justify-between border-b border-slate-100 bg-white">
                  <div>
                    <span className="text-[10px] text-slate-400 block font-medium">Vị trí chăm sóc</span>
                    <span className="font-bold text-slate-800 flex items-center gap-0.5 text-xs">
                      Quận 7, TP.HCM <ChevronDown size={14} className="text-[#00B14F]" />
                    </span>
                  </div>
                  <div className="w-7 h-7 rounded-full bg-slate-100 flex items-center justify-center text-slate-600 relative">
                    <Bell size={14} />
                    <span className="absolute top-1 right-1 w-1.5 h-1.5 bg-[#00B14F] rounded-full" />
                  </div>
                </div>

                {/* Mini App Hero Card */}
                <div className="p-3">
                  <div className="relative rounded-2xl overflow-hidden h-28 shadow-sm">
                    <Image
                      src="/images/app-hero.jpg"
                      alt="CareSitter lifestyle"
                      fill
                      className="object-cover"
                    />
                    <div className="absolute inset-0 bg-[#0F291E]/60 p-3 flex flex-col justify-end">
                      <span className="text-[9px] font-bold text-[#ECFDF5] uppercase tracking-wider">
                        ★ Đồng hành tin cậy
                      </span>
                      <p className="text-white text-xs font-bold leading-tight mt-0.5">
                        Chăm sóc từ tâm, an lòng con cháu
                      </p>
                    </div>
                  </div>
                </div>

                {/* Quick Services Tabs */}
                <div className="px-3 flex gap-2">
                  <button
                    onClick={(e) => { e.stopPropagation(); setSelectedService('elderly'); }}
                    className={`flex-1 rounded-xl p-2 text-center transition-all ${
                      selectedService === 'elderly'
                        ? 'bg-[#ECFDF5] border border-[#00B14F] text-[#00B14F]'
                        : 'bg-white border border-[#D1FAE5] text-slate-700'
                    }`}
                  >
                    <UserCheck size={16} className="mx-auto" />
                    <span className="text-[9px] font-bold block mt-1">Người già</span>
                  </button>

                  <button
                    onClick={(e) => { e.stopPropagation(); setSelectedService('kids'); }}
                    className={`flex-1 rounded-xl p-2 text-center transition-all ${
                      selectedService === 'kids'
                        ? 'bg-amber-50 border border-amber-400 text-amber-800'
                        : 'bg-white border border-[#D1FAE5] text-slate-700'
                    }`}
                  >
                    <Heart size={16} className="mx-auto text-amber-600" />
                    <span className="text-[9px] font-bold block mt-1">Trẻ em</span>
                  </button>

                  <button
                    onClick={(e) => { e.stopPropagation(); setSelectedService('special'); }}
                    className={`flex-1 rounded-xl p-2 text-center transition-all ${
                      selectedService === 'special'
                        ? 'bg-[#F0FDF4] border border-[#00B14F] text-[#00B14F]'
                        : 'bg-white border border-[#D1FAE5] text-slate-700'
                    }`}
                  >
                    <ShieldCheck size={16} className="mx-auto" />
                    <span className="text-[9px] font-bold block mt-1">Đặc biệt</span>
                  </button>
                </div>

                {/* Mini Caregiver List */}
                <div className="px-3 pt-3 flex-1 flex flex-col justify-between">
                  <div className="flex items-center justify-between pb-1">
                    <span className="font-bold text-[11px] text-slate-800">Caregiver sẵn sàng gần bạn</span>
                    <span className="text-[9px] text-[#00B14F] font-semibold">Xem thêm</span>
                  </div>

                  <div className="space-y-2">
                    {/* Mini Card 1 */}
                    <div
                      onClick={(e) => {
                        e.stopPropagation();
                        onOpenBooking('Hải Đường', 'Chăm sóc người cao tuổi');
                      }}
                      className="bg-white p-2 rounded-xl border border-[#D1FAE5] flex items-center gap-2 hover:border-[#00B14F] transition-all"
                    >
                      <div className="w-9 h-9 rounded-full overflow-hidden relative shrink-0">
                        <Image src="/images/caregiver-1.jpg" alt="Hải Đường" fill className="object-cover" />
                      </div>
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center justify-between">
                          <h4 className="font-bold text-[10px] text-slate-800 truncate">Hải Đường</h4>
                          <span className="text-[9px] text-amber-500 font-bold flex items-center">
                            ★ 5.0
                          </span>
                        </div>
                        <p className="text-[9px] text-[#4A6B5D] truncate">Tâm tình &amp; Chăm sinh hoạt</p>
                      </div>
                      <span className="bg-[#00B14F] text-white text-[9px] font-bold px-2 py-1 rounded-lg">
                        Đặt
                      </span>
                    </div>

                    {/* Mini Card 2 */}
                    <div
                      onClick={(e) => {
                        e.stopPropagation();
                        onOpenBooking('Nguyễn Thị Bích', 'Bảo mẫu & Trẻ nhỏ');
                      }}
                      className="bg-white p-2 rounded-xl border border-[#D1FAE5] flex items-center gap-2 hover:border-[#00B14F] transition-all"
                    >
                      <div className="w-9 h-9 rounded-full overflow-hidden relative shrink-0">
                        <Image src="/images/caregiver-3.jpg" alt="Nguyễn Thị Bích" fill className="object-cover" />
                      </div>
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center justify-between">
                          <h4 className="font-bold text-[10px] text-slate-800 truncate">Nguyễn Thị Bích</h4>
                          <span className="text-[9px] text-amber-500 font-bold flex items-center">
                            ★ 4.95
                          </span>
                        </div>
                        <p className="text-[9px] text-[#4A6B5D] truncate">Bảo mẫu &amp; Dạy học sớm</p>
                      </div>
                      <span className="bg-[#00B14F] text-white text-[9px] font-bold px-2 py-1 rounded-lg">
                        Đặt
                      </span>
                    </div>
                  </div>

                  {/* Mini Bottom App Bar */}
                  <div className="pt-2 border-t border-slate-100 flex justify-around text-slate-400">
                    <Heart size={16} className="text-[#00B14F] fill-[#00B14F]" />
                    <Calendar size={16} />
                    <MessageSquare size={16} />
                    <User size={16} />
                  </div>
                </div>

              </div>
            </div>

          </div>

        </div>
      </div>
    </section>
  );
}
