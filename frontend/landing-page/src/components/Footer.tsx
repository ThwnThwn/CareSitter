'use client';

import React from 'react';
import { Heart, Lock } from 'lucide-react';

export default function Footer() {
  return (
    <footer className="bg-white border-t border-[#D1FAE5] py-16 relative z-10 text-sm text-[#4A6B5D]" id="page-footer">
      <div className="max-w-7xl mx-auto px-6">

        {/* Main Columns Grid */}
        <div className="grid grid-cols-1 md:grid-cols-5 gap-10 pb-12 border-b border-[#D1FAE5]">

          {/* Brand Info */}
          <div className="md:col-span-2">
            <div className="flex items-center gap-3 mb-4">
              <div className="w-8 h-8 rounded-lg bg-[#00B14F] p-0.5 flex items-center justify-center">
                <div className="w-full h-full bg-white rounded-[6px] flex items-center justify-center">
                  <Heart className="w-4 h-4 text-[#00B14F] fill-[#00B14F]" />
                </div>
              </div>
              <span className="font-headline font-extrabold text-xl tracking-tight text-[#0F291E]">
                CareSitter
              </span>
            </div>

            <p className="text-[#4A6B5D] text-sm max-w-sm leading-relaxed mb-6">
              Nền tảng công nghệ kết nối dịch vụ chăm sóc gia đình, người cao tuổi và trẻ nhỏ uy tín hàng đầu. Tận tâm, chu đáo và an toàn tuyệt đối.
            </p>

            {/* Social Icons with 360 Spin on Hover */}
            <div className="flex items-center gap-3">
              {['FB', 'IG', 'TT', 'IN'].map((item) => (
                <a
                  key={item}
                  href="#"
                  className="footer-social-icon w-9 h-9 rounded-full bg-[#ECFDF5] border border-[#D1FAE5] text-[#00B14F] flex items-center justify-center font-bold text-xs"
                >
                  {item}
                </a>
              ))}
            </div>
          </div>

          {/* Links Column 1: Services */}
          <div>
            <h4 className="font-headline font-bold text-[#0F291E] text-sm uppercase tracking-wider mb-4">
              Dịch vụ
            </h4>
            <ul className="space-y-2.5">
              <li><a className="footer-nav-link text-[#4A6B5D] hover:text-[#00B14F]" href="#">Chăm sóc người già</a></li>
              <li><a className="footer-nav-link text-[#4A6B5D] hover:text-[#00B14F]" href="#">Trông giữ trẻ em</a></li>
              <li><a className="footer-nav-link text-[#4A6B5D] hover:text-[#00B14F]" href="#">Hỗ trợ bệnh viện</a></li>
              <li><a className="footer-nav-link text-[#4A6B5D] hover:text-[#00B14F]" href="#">Gói theo tuần &amp; tháng</a></li>
            </ul>
          </div>

          {/* Links Column 2: About CareSitter */}
          <div>
            <h4 className="font-headline font-bold text-[#0F291E] text-sm uppercase tracking-wider mb-4">
              Về CareSitter
            </h4>
            <ul className="space-y-2.5">
              <li><a className="footer-nav-link text-[#4A6B5D] hover:text-[#00B14F]" href="#">Giới thiệu</a></li>
              <li><a className="footer-nav-link text-[#4A6B5D] hover:text-[#00B14F]" href="#">Tuyển dụng Caregiver</a></li>
              <li><a className="footer-nav-link text-[#4A6B5D] hover:text-[#00B14F]" href="#">Tiêu chuẩn an toàn</a></li>
              <li><a className="footer-nav-link text-[#4A6B5D] hover:text-[#00B14F]" href="#">Tin tức &amp; Blog</a></li>
            </ul>
          </div>

          {/* Links Column 3: 24/7 Support */}
          <div>
            <h4 className="font-headline font-bold text-[#0F291E] text-sm uppercase tracking-wider mb-4">
              Hỗ trợ 24/7
            </h4>
            <ul className="space-y-2.5">
              <li><a className="footer-nav-link text-[#4A6B5D] hover:text-[#00B14F]" href="#">Trung tâm trợ giúp</a></li>
              <li><a className="footer-nav-link text-[#4A6B5D] hover:text-[#00B14F]" href="#">Quy tắc ứng xử</a></li>
              <li><a className="footer-nav-link text-[#4A6B5D] hover:text-[#00B14F]" href="#">Chính sách bảo mật</a></li>
              <li><a className="footer-nav-link text-[#4A6B5D] hover:text-[#00B14F]" href="#">Điều khoản dịch vụ</a></li>
            </ul>
          </div>

        </div>

        {/* Bottom Copyright Strip */}
        <div className="pt-8 flex flex-col sm:flex-row items-center justify-between text-xs text-[#4A6B5D] gap-4">
          <div>
            © 2026 CareSitter. All rights reserved. Made with ❤️ in Vietnam.
          </div>
          <div className="flex items-center gap-6">
            <span className="flex items-center gap-1.5">
              <span className="w-1.5 h-1.5 rounded-full bg-[#00B14F]" /> Hệ thống vận hành ổn định
            </span>
            <span className="flex items-center gap-1">
              <Lock size={12} className="text-[#00B14F]" /> Bảo mật 256-bit SSL
            </span>
          </div>
        </div>

      </div>
    </footer>
  );
}
