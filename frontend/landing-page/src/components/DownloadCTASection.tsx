'use client';

import React from 'react';

export default function DownloadCTASection() {
  return (
    <section className="min-h-[85vh] relative flex items-center justify-center py-24 px-6 overflow-hidden bg-[#F0FDF4] border-t border-[#D1FAE5]" id="download">

      {/* Floating Solid Geometric Shapes */}
      <div className="geo-shape-1 absolute top-12 left-16 w-20 h-20 rounded-2xl bg-[#D1FAE5] opacity-50 pointer-events-none" />
      <div className="geo-shape-2 absolute bottom-16 right-20 w-32 h-32 rounded-full bg-[#ECFDF5] border-2 border-[#D1FAE5] opacity-60 pointer-events-none" />
      <div className="geo-shape-1 absolute top-1/3 right-12 w-14 h-14 rotate-45 bg-[#D1FAE5] opacity-40 pointer-events-none" />

      <div className="max-w-4xl mx-auto text-center relative z-10 flex flex-col items-center">

        {/* Floating Tag */}
        <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-white border border-[#D1FAE5] mb-8 shadow-xs">
          <span className="w-2.5 h-2.5 rounded-full bg-[#00B14F] animate-pulse" />
          <span className="text-xs uppercase font-bold text-[#00B14F] tracking-widest">
            Bắt đầu trải nghiệm ngay hôm nay
          </span>
        </div>

        {/* Big Headline */}
        <h2 className="font-headline font-extrabold text-4xl sm:text-6xl lg:text-7xl text-[#0F291E] tracking-tight leading-[1.08] mb-6">
          Ready to Find <br />
          <span className="text-[#00B14F]">Perfect Care?</span>
        </h2>

        {/* Subheadline */}
        <p className="text-[#4A6B5D] text-lg sm:text-xl max-w-2xl mb-12">
          Gia nhập cộng đồng hơn 50,000 gia đình tin chọn CareSitter mỗi ngày. Tải ứng dụng và nhận ngay voucher giảm 20% cho ca chăm sóc đầu tiên.
        </p>

        {/* Two Download Buttons */}
        <div className="flex flex-wrap items-center justify-center gap-5 mb-10 w-full sm:w-auto">
          {/* App Store */}
          <a
            href="#"
            className="hover-target btn-ripple flex items-center gap-4 px-8 py-5 rounded-full bg-[#00B14F] text-white font-headline font-bold text-base hover:bg-[#009b45] hover:scale-105 active:scale-95 transition-all shadow-md"
          >
            <svg className="w-7 h-7 fill-white" viewBox="0 0 24 24">
              <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M15.97 6.37c.61-.75 1.04-1.8 1.01-2.87-.9.04-2 .6-2.65 1.35-.58.65-1.09 1.71-1.01 2.76.99.08 2.04-.49 2.65-1.24z" />
            </svg>
            <div className="text-left leading-tight">
              <div className="text-[10px] uppercase font-semibold tracking-wider text-[#ECFDF5]">Download on</div>
              <div className="text-lg font-extrabold text-white">App Store</div>
            </div>
          </a>

          {/* Google Play */}
          <a
            href="#"
            className="hover-target btn-ripple flex items-center gap-4 px-8 py-5 rounded-full bg-white text-[#0F291E] font-headline font-bold text-base hover:scale-105 active:scale-95 transition-all border-2 border-[#D1FAE5] hover:border-[#00B14F] shadow-sm"
          >
            <svg className="w-7 h-7 fill-[#00B14F]" viewBox="0 0 24 24">
              <path d="M3.609 1.814L13.792 12 3.61 22.186a2.38 2.38 0 0 1-.61-.989V2.803c.174-.383.39-.73.61-.989zm11.603 11.604l2.568-2.568-11.75-6.784 9.182 9.352zm2.568-2.568l-2.568-2.569 2.568-2.568 3.522 2.033c1.004.58 1.004 1.523 0 2.103l-3.522 3.002zm-5.137-5.137L3.46 2.16 15.21 8.944l-2.567 2.369z" />
            </svg>
            <div className="text-left leading-tight">
              <div className="text-[10px] uppercase font-semibold tracking-wider text-[#4A6B5D]">Get it on</div>
              <div className="text-lg font-extrabold text-[#0F291E]">Google Play</div>
            </div>
          </a>
        </div>

        {/* Rating Proof Badge */}
        <div className="flex items-center gap-2 text-sm text-[#4A6B5D] mb-8 font-medium">
          <div className="flex text-amber-500 font-bold">
            <span>★</span><span>★</span><span>★</span><span>★</span><span>★</span>
          </div>
          <span className="font-bold text-[#0F291E]">4.9 / 5</span>
          <span>từ 12,000+ lượt tải và đánh giá</span>
        </div>

        {/* QR Code Scanner Box with 360 Spin Entrance */}
        <div className="qr-rotate-in flat-card p-4 rounded-2xl flex items-center gap-4 bg-white border border-[#D1FAE5]">
          <div className="w-16 h-16 bg-[#ECFDF5] p-2 rounded-xl shrink-0 flex items-center justify-center border border-[#D1FAE5]">
            <svg className="w-full h-full fill-[#00B14F]" viewBox="0 0 29 29">
              <path d="M0 0h9v9H0zm2 2v5h5V2zm9 0h2v2h-2zm4 0h2v4h-2zm4 0h9v9h-9zm2 2v5h5V2zm-9 3h2v2h-2zm0 4h2v2h-2zm-9 2h2v2H2zm4 0h4v2H6zm6 0h2v2h-2zm4 0h2v2h-2zm4 0h4v2h-4zm0 2h2v4h-2zm-8 2h2v2h-2zm4 0h2v2h-2zm4 0h2v2h-2zm-12 2h2v2H0zm4 0h2v4H4zm4 0h2v2H8zm8 0h2v2h-2zm-16 4h4v2H0zm6 0h4v2H6zm6 0h2v2h-2zm4 0h2v2h-2zm-12 2h9v9H0zm2 2v5h5v-5z" />
            </svg>
          </div>
          <div className="text-left">
            <span className="font-bold text-[#0F291E] text-sm block">Quét mã QR tải app</span>
            <span className="text-[#4A6B5D] text-xs block font-medium">Hỗ trợ cả iOS và Android</span>
          </div>
        </div>

      </div>
    </section>
  );
}
