'use client';

import React, { useState } from 'react';
import {
  Compass,
  MapPin,
  ShieldCheck,
  MessageSquareText,
  CheckCheck,
  CalendarDays,
  Sparkles
} from 'lucide-react';

interface FeaturesSectionProps {
  onOpenBooking: () => void;
}

export default function FeaturesSection({ onOpenBooking }: FeaturesSectionProps) {
  const [selectedDay, setSelectedDay] = useState(4);
  const shiftHours = 4;

  return (
    <section className="py-24 lg:py-32 relative bg-white" id="features">
      <div className="max-w-7xl mx-auto px-6">

        {/* Section Header */}
        <div className="text-center max-w-2xl mx-auto mb-16">
          <div className="text-xs uppercase font-bold text-[#00B14F] tracking-widest mb-3">
            Công nghệ tiên tiến
          </div>
          <h2 className="font-headline font-extrabold text-3xl sm:text-4xl lg:text-5xl text-[#0F291E] tracking-tight">
            An Tâm Tuyệt Đối Với CareSitter
          </h2>
          <p className="text-[#4A6B5D] text-base mt-4">
            Được kiến tạo từ nhu cầu thực tế của hàng chục nghìn gia đình Việt, mang lại sự tiện nghi và minh bạch tối đa.
          </p>
        </div>

        {/* Asymmetric Bento Grid */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">

          {/* Large Card: Real-time GPS Tracking */}
          <div className="lg:col-span-2 bento-card rounded-3xl p-8 relative overflow-hidden flex flex-col justify-between min-h-[380px]">
            {/* Simulated Map Background */}
            <div className="absolute inset-0 opacity-40 pointer-events-none">
              <svg height="100%" width="100%" xmlns="http://www.w3.org/2000/svg">
                <defs>
                  <pattern id="mapGrid" width="40" height="40" patternUnits="userSpaceOnUse">
                    <path d="M 40 0 L 0 0 0 40" fill="none" stroke="#D1FAE5" strokeWidth="1.5" />
                  </pattern>
                </defs>
                <rect width="100%" height="100%" fill="url(#mapGrid)" />
                <path
                  d="M 50 180 Q 250 80 450 250 T 850 120"
                  fill="none"
                  stroke="#00B14F"
                  strokeWidth="3"
                  strokeDasharray="6,6"
                  opacity="0.6"
                />
              </svg>
            </div>

            {/* Animated Radar Pin in map */}
            <div className="absolute right-8 sm:right-14 top-14 flex items-center justify-center pointer-events-none">
              <div className="radar-circle w-28 h-28 rounded-full border-2 border-[#00B14F] absolute" />
              <div className="pin-drop-anim w-12 h-12 rounded-full bg-[#ECFDF5] border border-[#D1FAE5] flex items-center justify-center shadow-md">
                <div className="w-8 h-8 rounded-full bg-[#00B14F] flex items-center justify-center text-white">
                  <MapPin size={18} />
                </div>
              </div>
            </div>

            <div className="relative z-10 max-w-md">
              <div className="w-14 h-14 rounded-2xl bg-[#ECFDF5] border border-[#D1FAE5] text-[#00B14F] flex items-center justify-center mb-6">
                <Compass size={28} />
              </div>
              <span className="text-xs uppercase text-[#00B14F] font-bold tracking-wider">
                Định vị thông minh
              </span>
              <h3 className="font-headline font-extrabold text-2xl sm:text-3xl text-[#0F291E] mt-1 mb-3">
                Real-time GPS Tracking
              </h3>
              <p className="text-[#4A6B5D] text-sm sm:text-base leading-relaxed">
                Theo dõi sát sao từng khoảnh khắc: sitter đã xuất phát, đến nơi làm việc hay đang đưa người thân đi dạo. Báo cáo hình ảnh hoạt động định kỳ theo từng giờ ca trực.
              </p>
            </div>

            <div className="relative z-10 pt-6 mt-6 border-t border-[#D1FAE5] flex flex-wrap gap-4 text-xs text-[#0F291E] font-semibold">
              <span className="flex items-center gap-1.5">
                <span className="w-2 h-2 rounded-full bg-[#00B14F]" /> Cập nhật tức thời 5s/lần
              </span>
              <span className="flex items-center gap-1.5">
                <span className="w-2 h-2 rounded-full bg-[#00B14F]" /> Nút gọi khẩn cấp SOS 24/7
              </span>
            </div>
          </div>

          {/* Top-Right Card: Verified & Background Checked */}
          <div className="bento-card rounded-3xl p-8 flex flex-col justify-between min-h-[380px]">
            <div>
              <div className="w-14 h-14 rounded-2xl bg-[#ECFDF5] border border-[#D1FAE5] text-[#00B14F] flex items-center justify-center mb-6">
                <svg className="w-8 h-8 text-[#00B14F]" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
                  <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
                  <path className="stroke-draw-shield" d="M9 12l2 2 4-4" stroke="#00B14F" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" />
                </svg>
              </div>
              <span className="text-xs uppercase text-[#00B14F] font-bold tracking-wider">
                An tâm tuyệt đối
              </span>
              <h3 className="font-headline font-extrabold text-xl sm:text-2xl text-[#0F291E] mt-1 mb-3">
                Verified &amp; Background Checked
              </h3>
              <p className="text-[#4A6B5D] text-sm leading-relaxed">
                Quy trình xác minh 4 lớp khắt khe: Thẻ căn cước, lý lịch tư pháp không tiền án, kiểm tra sức khỏe và đánh giá chuyên môn trực tiếp.
              </p>
            </div>

            <div className="mt-6 pt-4 border-t border-[#D1FAE5] flex items-center justify-between text-xs text-[#00B14F] font-bold">
              <span>Đạt chuẩn an ninh</span>
              <ShieldCheck size={18} />
            </div>
          </div>

          {/* Bottom-Right Card: Instant In-App Chat */}
          <div className="bento-card rounded-3xl p-8 flex flex-col justify-between">
            <div>
              <div className="w-14 h-14 rounded-2xl bg-[#ECFDF5] border border-[#D1FAE5] text-[#00B14F] flex items-center justify-center mb-6">
                <MessageSquareText size={28} />
              </div>
              <span className="text-xs uppercase text-[#00B14F] font-bold tracking-wider">
                Kết nối liên tục
              </span>
              <h3 className="font-headline font-bold text-xl text-[#0F291E] mt-1 mb-2">
                Instant In-App Chat
              </h3>
              <p className="text-[#4A6B5D] text-xs sm:text-sm leading-relaxed mb-4">
                Trò chuyện, gửi ghi chú thuốc men, hình ảnh bữa ăn hay gọi điện miễn phí ngay trong ứng dụng mà không cần lộ số điện thoại cá nhân.
              </p>

              {/* Message Bubbles Simulation */}
              <div className="space-y-2 text-xs">
                <div className="bg-[#F0FDF4] border border-[#D1FAE5] p-2.5 rounded-2xl rounded-tl-none text-[#0F291E] max-w-[88%] font-medium shadow-xs">
                  Bác Nam đã uống thuốc huyết áp lúc 9:00 ạ! 💊
                </div>
                <div className="bg-[#00B14F] text-white p-2.5 rounded-2xl rounded-tr-none max-w-[88%] ml-auto flex items-center gap-1.5 font-medium shadow-xs">
                  <span>Cảm ơn em nhiều nhé!</span>
                  <CheckCheck size={14} className="text-white" />
                </div>
              </div>
            </div>
          </div>

          {/* Full-Width Bottom Card: Interactive Flexible Booking */}
          <div className="lg:col-span-2 bento-card rounded-3xl p-8 flex flex-col md:flex-row items-center justify-between gap-8">
            <div className="max-w-lg">
              <div className="w-14 h-14 rounded-2xl bg-[#ECFDF5] border border-[#D1FAE5] text-[#00B14F] flex items-center justify-center mb-6">
                <CalendarDays size={28} />
              </div>
              <span className="text-xs uppercase text-[#00B14F] font-bold tracking-wider">
                Linh hoạt thời gian
              </span>
              <h3 className="font-headline font-extrabold text-2xl sm:text-3xl text-[#0F291E] mt-1 mb-3">
                Flexible Booking — Theo Giờ, Ngày &amp; Dài Hạn
              </h3>
              <p className="text-[#4A6B5D] text-sm sm:text-base leading-relaxed mb-4">
                Tùy chỉnh lịch hẹn linh hoạt từ ca gấp 2-5 giờ, ca làm việc nguyên ngày đến gói chăm sóc cố định hàng tháng với chi phí tiết kiệm đến 20%.
              </p>
              <button
                onClick={onOpenBooking}
                className="inline-flex items-center gap-2 px-5 py-2.5 rounded-full bg-[#00B14F] text-white font-bold text-xs hover:bg-[#009b45] transition-all shadow-xs"
              >
                <Sparkles size={14} /> Thử Đặt Lịch Trực Tiếp
              </button>
            </div>

            {/* Interactive Mini Calendar Component */}
            <div className="w-full md:w-72 bg-white border border-[#D1FAE5] rounded-2xl p-4 shrink-0 shadow-sm">
              <div className="flex items-center justify-between text-xs font-bold text-[#0F291E] mb-3">
                <span>Tháng 10, 2026</span>
                <span className="text-[#00B14F] text-[10px] font-bold">Chạm để chọn</span>
              </div>
              <div className="grid grid-cols-7 gap-1.5 text-center text-[10px] mb-2 text-[#4A6B5D] font-bold">
                <span>T2</span><span>T3</span><span>T4</span><span>T5</span><span>T6</span><span>T7</span><span>CN</span>
              </div>
              <div className="grid grid-cols-7 gap-1.5 text-center text-xs">
                <span className="text-gray-300 py-1">29</span>
                <span className="text-gray-300 py-1">30</span>
                {[1, 2, 3, 4, 5].map((d) => (
                  <button
                    key={d}
                    onClick={() => setSelectedDay(d)}
                    className={`py-1 rounded-lg text-xs font-bold transition-all ${
                      selectedDay === d
                        ? 'bg-[#00B14F] text-white shadow-xs'
                        : 'bg-[#ECFDF5] text-[#00B14F] border border-[#D1FAE5] hover:bg-[#D1FAE5]'
                    }`}
                  >
                    0{d}
                  </button>
                ))}
              </div>

              <div className="mt-4 pt-3 border-t border-[#D1FAE5] flex items-center justify-between text-[11px] text-[#4A6B5D] font-semibold">
                <span>Ca ngày {selectedDay} Tháng 10 ({shiftHours}h):</span>
                <span className="text-[#00B14F] font-bold text-xs">
                  {(shiftHours * 120000).toLocaleString('vi-VN')}đ
                </span>
              </div>
            </div>

          </div>

        </div>

      </div>
    </section>
  );
}
