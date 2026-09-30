'use client';

import React, { useState } from 'react';
import { X, Check, ShieldCheck } from 'lucide-react';

interface QuickBookModalProps {
  isOpen: boolean;
  onClose: () => void;
  caregiverName?: string;
  serviceCategory?: string;
}

export default function QuickBookModal({
  isOpen,
  onClose,
  caregiverName = 'Chuyên viên CareSitter',
  serviceCategory = 'Chăm sóc người cao tuổi',
}: QuickBookModalProps) {
  const [selectedService, setSelectedService] = useState(serviceCategory);
  const [hours, setHours] = useState('4');
  const [shiftDate, setShiftDate] = useState('2026-10-04');
  const [bookingSuccess, setBookingSuccess] = useState(false);

  if (!isOpen) return null;

  const baseRate = 120000;
  const totalAmount = parseInt(hours || '4', 10) * baseRate;

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setBookingSuccess(true);
    setTimeout(() => {
      setBookingSuccess(false);
      onClose();
    }, 2500);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-[#0F291E]/60 backdrop-blur-sm animate-fadeIn">
      <div className="relative w-full max-w-lg bg-white rounded-3xl border border-[#D1FAE5] shadow-2xl p-6 sm:p-8 overflow-hidden">
        {/* Close Button */}
        <button
          onClick={onClose}
          className="absolute top-5 right-5 w-9 h-9 rounded-full bg-[#F0FDF4] border border-[#D1FAE5] flex items-center justify-center text-[#4A6B5D] hover:text-[#00B14F] hover:bg-[#ECFDF5] transition-colors"
        >
          <X size={18} />
        </button>

        {bookingSuccess ? (
          <div className="py-12 text-center flex flex-col items-center">
            <div className="w-16 h-16 rounded-full bg-[#ECFDF5] text-[#00B14F] border-2 border-[#00B14F] flex items-center justify-center mb-4 animate-bounce">
              <Check size={32} />
            </div>
            <h3 className="text-2xl font-bold text-[#0F291E] mb-2 font-headline">Yêu Cầu Đã Gửi Thành Công!</h3>
            <p className="text-sm text-[#4A6B5D] max-w-sm">
              Hệ thống đang kết nối người chăm sóc phù hợp gần nhất. Thông báo chi tiết sẽ được gửi qua ứng dụng và SMS trong 3 phút.
            </p>
          </div>
        ) : (
          <div>
            {/* Header */}
            <div className="mb-6">
              <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-[#ECFDF5] border border-[#D1FAE5] text-[11px] font-bold text-[#00B14F] uppercase tracking-wider mb-2">
                <ShieldCheck size={14} /> 100% Bảo Chứng CareSitter
              </div>
              <h3 className="text-2xl font-extrabold text-[#0F291E] font-headline">Đặt Lịch Nhanh Chăm Sóc</h3>
              <p className="text-xs text-[#4A6B5D] mt-1">
                Người phụ trách dự kiến: <span className="font-bold text-[#00B14F]">{caregiverName}</span>
              </p>
            </div>

            {/* Form */}
            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="block text-xs font-bold text-[#0F291E] uppercase mb-1.5">Loại hình chăm sóc</label>
                <div className="grid grid-cols-3 gap-2 text-xs">
                  {['Người cao tuổi', 'Trông trẻ em', 'Hỗ trợ y tế'].map((srv) => (
                    <button
                      type="button"
                      key={srv}
                      onClick={() => setSelectedService(srv)}
                      className={`py-2.5 px-2 rounded-xl border text-center font-semibold transition-all ${
                        selectedService === srv
                          ? 'border-[#00B14F] bg-[#ECFDF5] text-[#00B14F] shadow-sm'
                          : 'border-[#D1FAE5] bg-white text-[#4A6B5D] hover:border-[#00B14F]/50'
                      }`}
                    >
                      {srv}
                    </button>
                  ))}
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold text-[#0F291E] uppercase mb-1.5">Ngày hẹn</label>
                  <div className="relative">
                    <input
                      type="date"
                      value={shiftDate}
                      onChange={(e) => setShiftDate(e.target.value)}
                      className="w-full text-xs font-medium px-3 py-2.5 rounded-xl border border-[#D1FAE5] text-[#0F291E] bg-[#F0FDF4] focus:outline-none focus:border-[#00B14F]"
                      required
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-xs font-bold text-[#0F291E] uppercase mb-1.5">Thời lượng ca</label>
                  <select
                    value={hours}
                    onChange={(e) => setHours(e.target.value)}
                    className="w-full text-xs font-medium px-3 py-2.5 rounded-xl border border-[#D1FAE5] text-[#0F291E] bg-[#F0FDF4] focus:outline-none focus:border-[#00B14F]"
                  >
                    <option value="2">2 Giờ (Ca ngắn)</option>
                    <option value="4">4 Giờ (Nửa ngày)</option>
                    <option value="8">8 Giờ (Nguyên ngày)</option>
                    <option value="12">12 Giờ (Ca đêm)</option>
                  </select>
                </div>
              </div>

              {/* Price Estimate Card */}
              <div className="p-4 rounded-2xl bg-[#F0FDF4] border border-[#D1FAE5] flex items-center justify-between">
                <div>
                  <span className="text-[11px] text-[#4A6B5D] block">Dự toán chi phí ({hours} giờ):</span>
                  <span className="text-xl font-extrabold text-[#00B14F] font-headline">
                    {totalAmount.toLocaleString('vi-VN')} đ
                  </span>
                </div>
                <div className="text-right">
                  <span className="text-[10px] text-[#00B14F] bg-white px-2 py-0.5 rounded-md border border-[#D1FAE5] font-bold">
                    Ưu đãi -20% lần đầu
                  </span>
                </div>
              </div>

              {/* Submit CTA */}
              <button
                type="submit"
                className="w-full py-3.5 rounded-full bg-[#00B14F] hover:bg-[#009b45] active:scale-95 text-white font-headline font-bold text-sm tracking-wide transition-all shadow-md mt-2"
              >
                Xác Nhận Đặt Lịch
              </button>
            </form>
          </div>
        )}
      </div>
    </div>
  );
}
