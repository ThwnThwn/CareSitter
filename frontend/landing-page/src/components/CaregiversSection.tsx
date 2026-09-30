'use client';

import React, { useState, useEffect } from 'react';
import Image from 'next/image';
import { motion } from 'framer-motion';
import {
  ShieldCheck,
  Clock,
  ChevronLeft,
  ChevronRight,
  Sparkles,
  Calendar,
  Award
} from 'lucide-react';

interface CaregiversSectionProps {
  onOpenBooking: (caregiver: string, service: string) => void;
}

const caregivers = [
  {
    id: 1,
    name: 'Hải Đường',
    title: 'Chuyên viên Chăm sóc Người cao tuổi',
    shortCategory: 'Người cao tuổi',
    badge: 'Senior Specialist',
    rating: '5.0',
    reviews: 68,
    matchRate: '99.8%',
    experience: '7 năm kinh nghiệm',
    bio: '7 năm kinh nghiệm điều dưỡng gia đình, kiên nhẫn, tâm lý và am hiểu chế độ dinh dưỡng người già.',
    skills: ['Tâm tình & Trò chuyện', 'Dinh dưỡng tiểu đường', 'Hỗ trợ vận động'],
    rate: '120.000đ',
    img: '/images/caregiver-1.jpg',
    status: 'Sẵn sàng nhận ca',
  },
  {
    id: 2,
    name: 'Trần Văn Nam',
    title: 'Điều dưỡng viên Hỗ trợ Y tế',
    shortCategory: 'Hỗ trợ y tế',
    badge: 'Certified Nurse',
    rating: '4.9',
    reviews: 92,
    matchRate: '99.5%',
    experience: '5 năm bệnh viện',
    bio: 'Hỗ trợ phục hồi vận động sau tai biến, đưa đón đi viện khám và nhắc nhở liệu trình thuốc chu đáo.',
    skills: ['Hỗ trợ vật lý trị liệu', 'Theo dõi đơn thuốc', 'Sơ cấp cứu khẩn cấp'],
    rate: '135.000đ',
    img: '/images/caregiver-2.jpg',
    status: 'Đang rảnh hôm nay',
  },
  {
    id: 3,
    name: 'Nguyễn Thị Bích',
    title: 'Bảo mẫu & Giáo dục Sớm',
    shortCategory: 'Trông giữ trẻ em',
    badge: 'Early Educator',
    rating: '4.95',
    reviews: 128,
    matchRate: '100%',
    experience: '6 năm mầm non',
    bio: 'Tốt nghiệp sư phạm mầm non, tận tình, sáng tạo và nhiều năng lượng tích cực vui vẻ với trẻ nhỏ.',
    skills: ['Phương pháp Montessori', 'Rèn nếp ăn ngủ', 'Kể chuyện song ngữ'],
    rate: '115.000đ',
    img: '/images/caregiver-3.jpg',
    status: 'Sẵn sàng nhận ca',
  },
  {
    id: 4,
    name: 'Lê Kim Oanh',
    title: 'Điều dưỡng Hậu phẫu & Chăm sóc Đặc biệt',
    shortCategory: 'Chăm sóc đặc biệt',
    badge: 'Post-Op Specialist',
    rating: '4.9',
    reviews: 45,
    matchRate: '99.2%',
    experience: '8 năm kinh nghiệm',
    bio: 'Kỹ năng vệ sinh, rửa vết thương, chăm sóc hỗ trợ người bệnh nhẹ nhàng, giàu tình thương.',
    skills: ['Chăm sóc vết thương', 'Vận động thụ động', 'Xoa bóp giảm đau'],
    rate: '140.000đ',
    img: '/images/caregiver-4.jpg',
    status: 'Sẵn sàng nhận ca',
  },
];

export default function CaregiversSection({ onOpenBooking }: CaregiversSectionProps) {
  const [activeIndex, setActiveIndex] = useState(0);
  const [isAutoPlaying, setIsAutoPlaying] = useState(true);

  // Auto-cycle sliding smartphones every 4.5 seconds (pausable on hover)
  useEffect(() => {
    if (!isAutoPlaying) return;
    const timer = setInterval(() => {
      setActiveIndex((prev) => (prev + 1) % caregivers.length);
    }, 4500);
    return () => clearInterval(timer);
  }, [isAutoPlaying]);

  const handlePrev = () => {
    setActiveIndex((prev) => (prev - 1 + caregivers.length) % caregivers.length);
  };

  const handleNext = () => {
    setActiveIndex((prev) => (prev + 1) % caregivers.length);
  };

  return (
    <section
      className="py-16 lg:py-20 bg-[#F0FDF4] border-t border-[#D1FAE5] relative overflow-hidden"
      id="caregivers"
      onMouseEnter={() => setIsAutoPlaying(false)}
      onMouseLeave={() => setIsAutoPlaying(true)}
    >
      {/* Background Soft Glow & Geometry */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[800px] h-[500px] bg-[#ECFDF5] rounded-full blur-3xl pointer-events-none -z-0" />
      <div className="geo-shape-1 absolute top-12 left-12 w-20 h-20 rounded-3xl bg-[#D1FAE5]/40 pointer-events-none" />
      <div className="geo-shape-2 absolute bottom-12 right-12 w-28 h-28 rounded-full bg-[#ECFDF5] border border-[#D1FAE5] pointer-events-none" />

      <div className="max-w-7xl mx-auto px-6 relative z-10">

        {/* Section Header */}
        <div className="flex flex-col md:flex-row md:items-end justify-between gap-6 mb-10">
          <div className="max-w-xl">
            <div className="inline-flex items-center gap-2 px-3.5 py-1 rounded-full bg-white border border-[#D1FAE5] text-[#00B14F] text-xs uppercase font-bold tracking-widest mb-2.5 shadow-xs">
              <Sparkles size={14} /> Jitter Sliding Smartphones
            </div>
            <h2 className="font-headline font-extrabold text-3xl sm:text-4xl lg:text-5xl text-[#0F291E] tracking-tight">
              Meet Our Top Caregivers
            </h2>
            <p className="text-[#4A6B5D] text-sm sm:text-base mt-2 leading-relaxed">
              Trải nghiệm lướt hồ sơ người chăm sóc tương tác 3D. 100% hồ sơ đã vượt qua kiểm định lý lịch tư pháp, phỏng vấn thực hành và đào tạo chuyên môn.
            </p>
          </div>

          {/* Navigation Controls & Indicators */}
          <div className="flex items-center gap-3">
            <div className="hidden sm:flex items-center gap-1.5 mr-2">
              {caregivers.map((_, i) => (
                <button
                  key={i}
                  onClick={() => setActiveIndex(i)}
                  className={`h-2 rounded-full transition-all duration-300 ${
                    activeIndex === i ? 'w-8 bg-[#00B14F]' : 'w-2 bg-[#D1FAE5] hover:bg-[#00B14F]/40'
                  }`}
                  aria-label={`Go to slide ${i + 1}`}
                />
              ))}
            </div>

            <button
              onClick={handlePrev}
              className="w-11 h-11 rounded-full bg-white border border-[#D1FAE5] text-[#0F291E] hover:text-[#00B14F] hover:border-[#00B14F] hover:shadow-md flex items-center justify-center transition-all active:scale-95"
              aria-label="Previous caregiver"
            >
              <ChevronLeft size={20} />
            </button>
            <button
              onClick={handleNext}
              className="w-11 h-11 rounded-full bg-[#00B14F] text-white hover:bg-[#009b45] hover:shadow-md flex items-center justify-center transition-all active:scale-95"
              aria-label="Next caregiver"
            >
              <ChevronRight size={20} />
            </button>
          </div>
        </div>

        {/* ======================================================== */}
        {/* SLIDING SMARTPHONES SHOWCASE (Jitter-inspired 3D Layout) */}
        {/* ======================================================== */}
        <div className="relative min-h-[560px] flex items-center justify-center py-2">

          <div className="w-full flex items-center justify-center gap-4 lg:gap-8 perspective-[1400px]">
            {caregivers.map((c, index) => {
              // Calculate relative offset from activeIndex
              let offset = index - activeIndex;
              if (offset < -1) offset += caregivers.length;
              if (offset > 2) offset -= caregivers.length;

              const isCenter = offset === 0;
              const isLeft = offset === -1 || (activeIndex === 0 && index === caregivers.length - 1);
              const isRight = offset === 1 || (activeIndex === caregivers.length - 1 && index === 0);

              const isVisible = isCenter || isLeft || isRight;

              let rotateY = 0;
              let rotateZ = 0;
              let scale = 0.88;
              let zIndex = 10;
              let opacity = 0.6;

              if (isCenter) {
                rotateY = 0;
                rotateZ = 0;
                scale = 1.02;
                zIndex = 30;
                opacity = 1;
              } else if (isLeft) {
                rotateY = 14;
                rotateZ = -3;
                scale = 0.88;
                zIndex = 20;
                opacity = 0.75;
              } else if (isRight) {
                rotateY = -14;
                rotateZ = 3;
                scale = 0.88;
                zIndex = 20;
                opacity = 0.75;
              }

              if (!isVisible) return null;

              return (
                <motion.div
                  key={c.id}
                  layout
                  initial={{ opacity: 0, y: 50, scale: 0.8 }}
                  animate={{
                    opacity,
                    scale,
                    rotateY,
                    rotateZ,
                    zIndex,
                    transition: {
                      type: 'spring',
                      stiffness: 120,
                      damping: 18,
                      mass: 0.8,
                    },
                  }}
                  whileHover={
                    isCenter
                      ? {
                          scale: 1.05,
                          y: -10,
                          rotateY: 2,
                          transition: { duration: 0.3 },
                        }
                      : { scale: 0.92, opacity: 0.95 }
                  }
                  onClick={() => setActiveIndex(index)}
                  className={`relative shrink-0 cursor-pointer select-none transition-shadow ${
                    isCenter ? 'drop-shadow-2xl' : 'drop-shadow-lg hidden sm:block'
                  }`}
                  style={{
                    transformStyle: 'preserve-3d',
                  }}
                >
                  {/* Smartphone Bezel Wrapper */}
                  <div className="w-[290px] sm:w-[315px] h-[535px] bg-slate-900 rounded-[44px] p-3 border-4 border-slate-700/80 relative overflow-hidden flex flex-col justify-between shadow-2xl">

                    {/* Speaker & Dynamic Island */}
                    <div className="absolute top-4 left-1/2 -translate-x-1/2 w-24 h-5 bg-black rounded-full z-40 flex items-center justify-center gap-1.5">
                      <div className="w-2 h-2 rounded-full bg-slate-900 border border-slate-800" />
                      <div className="w-2 h-2 rounded-full bg-emerald-950/80" />
                    </div>

                    {/* Smartphone Glass Screen */}
                    <div className="w-full h-full bg-white rounded-[34px] overflow-hidden flex flex-col pt-6 text-xs relative">

                      {/* Top Header inside Phone */}
                      <div className="px-3.5 py-1.5 flex items-center justify-between border-b border-slate-100 bg-[#F8FAFC]">
                        <div className="flex items-center gap-1.5 text-[10px] font-bold text-[#0F291E]">
                          <span className="w-1.5 h-1.5 rounded-full bg-[#00B14F] animate-ping" />
                          <span>{c.status}</span>
                        </div>
                        <div className="text-[9px] uppercase font-bold text-[#00B14F] bg-[#ECFDF5] px-1.5 py-0.5 rounded border border-[#D1FAE5]">
                          {c.badge}
                        </div>
                      </div>

                      {/* Caregiver Portrait with Overlay */}
                      <div className="relative w-full h-48 bg-slate-100 overflow-hidden">
                        <Image
                          src={c.img}
                          alt={c.name}
                          fill
                          className="object-cover transition-transform duration-700 hover:scale-110"
                        />
                        <div className="absolute inset-0 bg-gradient-to-t from-[#0F291E]/95 via-[#0F291E]/25 to-transparent flex flex-col justify-end p-3.5 text-white">
                          <div className="flex items-center gap-1.5 mb-0.5">
                            <span className="px-2 py-0.5 rounded-full bg-[#00B14F] text-[9px] font-bold uppercase tracking-wider">
                              Verified ✓
                            </span>
                            <span className="text-[10px] font-medium text-emerald-200">
                              {c.experience}
                            </span>
                          </div>
                          <h3 className="font-headline font-extrabold text-lg leading-tight">
                            {c.name}
                          </h3>
                          <div className="flex items-center text-amber-400 text-xs font-bold gap-1 mt-0.5">
                            <span>★</span>
                            <span className="text-white font-bold">{c.rating}</span>
                            <span className="text-slate-300 font-normal text-[10px]">({c.reviews})</span>
                            <span className="text-emerald-400 ml-auto font-bold text-[10px]">
                              {c.matchRate} khớp
                            </span>
                          </div>
                        </div>
                      </div>

                      {/* Phone Inner Body Content */}
                      <div className="p-3.5 flex-1 flex flex-col justify-between bg-white">
                        <div>
                          <div className="text-[10px] font-bold text-[#00B14F] uppercase tracking-wide mb-1">
                            {c.shortCategory}
                          </div>
                          <p className="text-[#4A6B5D] text-[11px] leading-relaxed line-clamp-2 mb-2.5">
                            {c.bio}
                          </p>

                          {/* Skill Tags Chips */}
                          <div className="flex flex-wrap gap-1">
                            {c.skills.map((skill, sIdx) => (
                              <span
                                key={sIdx}
                                className="px-1.5 py-0.5 rounded bg-[#F0FDF4] border border-[#D1FAE5] text-[#0F291E] text-[9px] font-medium"
                              >
                                {skill}
                              </span>
                            ))}
                          </div>
                        </div>

                        {/* Price & Action Button */}
                        <div className="pt-2.5 border-t border-slate-100 flex items-center justify-between">
                          <div>
                            <span className="text-[9px] uppercase font-bold text-[#4A6B5D] block">
                              Mức phí
                            </span>
                            <span className="font-headline font-extrabold text-sm text-[#00B14F]">
                              {c.rate}<span className="text-[9px] text-[#4A6B5D] font-normal">/h</span>
                            </span>
                          </div>

                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              onOpenBooking(c.name, c.title);
                            }}
                            className="btn-ripple px-3.5 py-1.5 rounded-lg bg-[#00B14F] hover:bg-[#009b45] active:scale-95 text-white font-headline font-bold text-xs shadow-xs transition-all flex items-center gap-1"
                          >
                            <Calendar size={12} /> Đặt Lịch
                          </button>
                        </div>
                      </div>

                    </div>
                  </div>
                </motion.div>
              );
            })}
          </div>

        </div>

        {/* Feature Highlights beneath showcase */}
        <div className="mt-8 grid grid-cols-1 sm:grid-cols-3 gap-5 pt-6 border-t border-[#D1FAE5]">
          <div className="flex items-center gap-3 p-3 rounded-2xl bg-white border border-[#D1FAE5]">
            <div className="w-9 h-9 rounded-xl bg-[#ECFDF5] text-[#00B14F] flex items-center justify-center font-bold">
              <ShieldCheck size={20} />
            </div>
            <div>
              <h4 className="text-xs font-bold text-[#0F291E]">100% Hồ sơ tư pháp</h4>
              <p className="text-[10px] text-[#4A6B5D]">Bộ Công An & Căn cước công dân</p>
            </div>
          </div>

          <div className="flex items-center gap-3 p-3 rounded-2xl bg-white border border-[#D1FAE5]">
            <div className="w-9 h-9 rounded-xl bg-[#ECFDF5] text-[#00B14F] flex items-center justify-center font-bold">
              <Award size={20} />
            </div>
            <div>
              <h4 className="text-xs font-bold text-[#0F291E]">Đào tạo nghiệp vụ chuẩn</h4>
              <p className="text-[10px] text-[#4A6B5D]">Sơ cấp cứu, dinh dưỡng & tâm lý</p>
            </div>
          </div>

          <div className="flex items-center gap-3 p-3 rounded-2xl bg-white border border-[#D1FAE5]">
            <div className="w-9 h-9 rounded-xl bg-[#ECFDF5] text-[#00B14F] flex items-center justify-center font-bold">
              <Clock size={20} />
            </div>
            <div>
              <h4 className="text-xs font-bold text-[#0F291E]">Đổi Caregiver linh hoạt</h4>
              <p className="text-[10px] text-[#4A6B5D]">Hỗ trợ đổi trong 15 phút nếu chưa ưng ý</p>
            </div>
          </div>
        </div>

      </div>
    </section>
  );
}
