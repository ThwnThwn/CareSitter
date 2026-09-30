'use client';

import React from 'react';
import { SearchCheck, Brain, MessageSquare, Clock, ShieldCheck, Lock } from 'lucide-react';

export default function HowItWorksSection() {
  return (
    <section className="py-24 lg:py-32 relative bg-white" id="how-it-works">
      <div className="max-w-7xl mx-auto px-6">

        {/* Section Header */}
        <div className="text-center max-w-2xl mx-auto mb-20">
          <div className="text-xs uppercase font-bold text-[#00B14F] tracking-widest mb-3">
            Quy trình đặt ca thông minh
          </div>
          <h2 className="font-headline font-extrabold text-3xl sm:text-4xl lg:text-5xl text-[#0F291E] tracking-tight">
            Simple. Fast. Safe.
          </h2>
          <p className="text-[#4A6B5D] text-base sm:text-lg mt-4">
            Trải nghiệm tìm kiếm và kết nối người chăm sóc hoàn tất chỉ trong 3 bước chạm đơn giản.
          </p>
        </div>

        {/* 3 Step Cards Grid with Connecting Dashed Line */}
        <div className="relative grid grid-cols-1 md:grid-cols-3 gap-8 items-stretch">

          {/* Connecting Line (Desktop) */}
          <div className="hidden md:block absolute top-1/2 left-[15%] right-[15%] h-0.5 -translate-y-12 pointer-events-none -z-0">
            <svg className="w-full h-4" overflow="visible">
              <line
                className="line-draw-active"
                stroke="#00B14F"
                strokeDasharray="8 8"
                strokeWidth="2"
                x1="0"
                x2="100%"
                y1="0"
                y2="0"
              />
            </svg>
          </div>

          {/* Step 1 Card */}
          <div className="flat-card flat-card-hover rounded-3xl p-8 relative flex flex-col justify-between">
            <div className="absolute top-6 right-6 w-9 h-9 rounded-full bg-[#ECFDF5] border border-[#D1FAE5] text-[#00B14F] font-headline font-extrabold text-sm flex items-center justify-center">
              01
            </div>
            <div>
              <div className="w-16 h-16 rounded-2xl bg-[#ECFDF5] border border-[#D1FAE5] flex items-center justify-center text-[#00B14F] mb-8">
                <SearchCheck size={32} className="step-icon-wobble" />
              </div>
              <h3 className="font-headline font-bold text-2xl text-[#0F291E] mb-3">
                Post Your Need
              </h3>
              <p className="text-[#4A6B5D] text-sm sm:text-base leading-relaxed">
                Describe care requirements in 30 seconds: chọn đối tượng (người già, trẻ nhỏ, hỗ trợ đặc biệt), thời gian, và các yêu cầu sinh hoạt riêng.
              </p>
            </div>
            <div className="mt-8 pt-4 border-t border-[#D1FAE5] flex items-center gap-2 text-xs font-bold text-[#00B14F]">
              <Clock size={16} /> Điền form dưới 1 phút
            </div>
          </div>

          {/* Step 2 Card */}
          <div className="flat-card flat-card-hover rounded-3xl p-8 relative flex flex-col justify-between">
            <div className="absolute top-6 right-6 w-9 h-9 rounded-full bg-[#ECFDF5] border border-[#D1FAE5] text-[#00B14F] font-headline font-extrabold text-sm flex items-center justify-center">
              02
            </div>
            <div>
              <div className="w-16 h-16 rounded-2xl bg-[#ECFDF5] border border-[#D1FAE5] flex items-center justify-center text-[#00B14F] mb-8">
                <Brain size={32} className="step-icon-pulse" />
              </div>
              <h3 className="font-headline font-bold text-2xl text-[#0F291E] mb-3">
                Match Instantly
              </h3>
              <p className="text-[#4A6B5D] text-sm sm:text-base leading-relaxed">
                Thuật toán AI tự động gợi ý và ghép nối ngay với các Caregiver đã được kiểm định lý lịch 100%, gần nhà bạn nhất với điểm đánh giá từ 4.8★ trở lên.
              </p>
            </div>
            <div className="mt-8 pt-4 border-t border-[#D1FAE5] flex items-center gap-2 text-xs font-bold text-[#00B14F]">
              <ShieldCheck size={16} /> Xác thực hồ sơ chuẩn chỉ
            </div>
          </div>

          {/* Step 3 Card */}
          <div className="flat-card flat-card-hover rounded-3xl p-8 relative flex flex-col justify-between">
            <div className="absolute top-6 right-6 w-9 h-9 rounded-full bg-[#ECFDF5] border border-[#D1FAE5] text-[#00B14F] font-headline font-extrabold text-sm flex items-center justify-center">
              03
            </div>
            <div>
              <div className="w-16 h-16 rounded-2xl bg-[#ECFDF5] border border-[#D1FAE5] flex items-center justify-center text-[#00B14F] mb-8 relative">
                <MessageSquare size={32} />
                {/* Typing dots */}
                <div className="absolute bottom-2 right-2 flex gap-0.5">
                  <span className="w-1.5 h-1.5 rounded-full bg-[#00B14F] typing-dot-1" />
                  <span className="w-1.5 h-1.5 rounded-full bg-[#00B14F] typing-dot-2" />
                  <span className="w-1.5 h-1.5 rounded-full bg-[#00B14F] typing-dot-3" />
                </div>
              </div>
              <h3 className="font-headline font-bold text-2xl text-[#0F291E] mb-3">
                Book &amp; Chat
              </h3>
              <p className="text-[#4A6B5D] text-sm sm:text-base leading-relaxed">
                Xác nhận đặt lịch minh bạch, thanh toán an toàn qua ví/thẻ và nhắn tin, gọi điện trực tiếp hoặc theo dõi lộ trình di chuyển của sitter theo thời gian thực.
              </p>
            </div>
            <div className="mt-8 pt-4 border-t border-[#D1FAE5] flex items-center gap-2 text-xs font-bold text-[#00B14F]">
              <Lock size={16} /> Bảo vệ quyền lợi 100%
            </div>
          </div>

        </div>

      </div>
    </section>
  );
}
