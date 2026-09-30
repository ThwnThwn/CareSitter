'use client';

import React from 'react';

const reviews = [
  {
    stars: 5,
    quote: '"Found an amazing sitter within 5 minutes! The background check feature gave me complete peace of mind. Chị chăm sóc rất nhẹ nhàng với bé nhà mình."',
    name: 'Linh T.',
    role: 'Mẹ của 2 bé • Hà Nội',
    initials: 'LT',
  },
  {
    stars: 5,
    quote: '"Booked a caregiver for my father last minute — they arrived in 20 minutes. Incredible! Bố mình rất quý bạn Nam vì biết cách nói chuyện và dìu ông tập thể dục."',
    name: 'Minh K.',
    role: 'Kỹ sư công nghệ • TP.HCM',
    initials: 'MK',
  },
  {
    stars: 5,
    quote: '"The app is so easy to use. I\'ve tried others but CareSitter just works. Tính năng cập nhật GPS và hình ảnh trong ca trực giúp mình yên tâm đi làm cả ngày."',
    name: 'Sarah D.',
    role: 'Quản lý dự án • Đà Nẵng',
    initials: 'SD',
  },
];

export default function TestimonialsSection() {
  return (
    <section className="py-24 bg-[#F0FDF4] border-t border-[#D1FAE5] relative" id="testimonials">
      <div className="max-w-7xl mx-auto px-6">

        {/* Header */}
        <div className="text-center max-w-2xl mx-auto mb-16">
          <div className="text-xs uppercase font-bold text-[#00B14F] tracking-widest mb-3">
            Cộng đồng tin cậy
          </div>
          <h2 className="font-headline font-extrabold text-3xl sm:text-4xl lg:text-5xl text-[#0F291E] tracking-tight">
            Loved By Families
          </h2>
          <p className="text-[#4A6B5D] text-base mt-4">
            Lắng nghe chia sẻ từ những người con, người cha, người mẹ đã tìm được sự an tâm trọn vẹn.
          </p>
        </div>

        {/* 3 Testimonial Cards */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
          {reviews.map((r, idx) => (
            <div
              key={idx}
              className="flat-card rounded-3xl p-8 flex flex-col justify-between bg-white relative transition-transform duration-300 hover:-translate-y-2 hover:border-[#00B14F] hover:shadow-lg"
            >
              {/* Decorative Quote Mark */}
              <span className="absolute top-4 right-6 text-6xl font-serif text-[#D1FAE5] pointer-events-none select-none">
                &ldquo;
              </span>

              <div>
                <div className="flex items-center gap-1 text-amber-500 text-base mb-6">
                  {[...Array(r.stars)].map((_, i) => (
                    <span key={i}>★</span>
                  ))}
                </div>

                <p className="text-[#0F291E] text-base leading-relaxed italic mb-8 font-medium">
                  {r.quote}
                </p>
              </div>

              <div className="flex items-center gap-4 pt-4 border-t border-[#D1FAE5]">
                <div className="w-12 h-12 rounded-full bg-[#00B14F] p-0.5 shadow-xs">
                  <div className="w-full h-full rounded-full bg-white flex items-center justify-center font-bold text-[#00B14F] font-headline text-sm">
                    {r.initials}
                  </div>
                </div>
                <div>
                  <h4 className="font-headline font-bold text-[#0F291E] text-sm">{r.name}</h4>
                  <p className="text-[#4A6B5D] text-xs">{r.role}</p>
                </div>
              </div>
            </div>
          ))}
        </div>

      </div>
    </section>
  );
}
