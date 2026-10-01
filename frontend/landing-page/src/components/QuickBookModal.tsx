"use client";

import { Check, ShieldCheck, X } from "lucide-react";
import { useEffect, useState } from "react";

interface QuickBookModalProps {
  isOpen: boolean;
  onClose: () => void;
  caregiverName?: string;
  serviceCategory?: string;
}

const services = [
  "Chăm sóc người cao tuổi",
  "Đồng hành sinh hoạt",
  "Hỗ trợ đi lại",
];

function localDateString() {
  const now = new Date();
  const local = new Date(now.getTime() - now.getTimezoneOffset() * 60_000);
  return local.toISOString().slice(0, 10);
}

export default function QuickBookModal({
  isOpen,
  onClose,
  caregiverName = "Chuyên viên CareSitter",
  serviceCategory = "Chăm sóc người cao tuổi",
}: QuickBookModalProps) {
  const [selectedService, setSelectedService] = useState(serviceCategory);
  const [hours, setHours] = useState("4");
  const [shiftDate, setShiftDate] = useState(localDateString);
  const [bookingSuccess, setBookingSuccess] = useState(false);

  useEffect(() => {
    if (!isOpen) return;

    document.body.style.overflow = "hidden";

    const handleEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape") onClose();
    };

    window.addEventListener("keydown", handleEscape);
    return () => {
      window.removeEventListener("keydown", handleEscape);
      document.body.style.overflow = "";
    };
  }, [isOpen, onClose, serviceCategory]);

  if (!isOpen) return null;

  const totalAmount = Number(hours) * 120_000;

  const handleSubmit = (event: React.FormEvent) => {
    event.preventDefault();
    setBookingSuccess(true);
  };

  return (
    <div className="modal-backdrop" onMouseDown={onClose}>
      <section
        aria-labelledby="booking-title"
        aria-modal="true"
        className="booking-modal"
        onMouseDown={(event) => event.stopPropagation()}
        role="dialog"
      >
        <button
          aria-label="Đóng cửa sổ đặt ca"
          className="modal-close"
          onClick={onClose}
          type="button"
        >
          <X size={20} />
        </button>

        {bookingSuccess ? (
          <div className="booking-success" aria-live="polite">
            <span>
              <Check size={30} aria-hidden="true" />
            </span>
            <h2 id="booking-title">Đã ghi nhận nhu cầu của gia đình</h2>
            <p>
              CareSitter sẽ liên hệ để xác nhận thông tin trước khi đề xuất
              caregiver phù hợp. Đây chưa phải là xác nhận đặt ca.
            </p>
            <button className="button button--primary" onClick={onClose}>
              Hoàn tất
            </button>
          </div>
        ) : (
          <>
            <header className="booking-modal__header">
              <span>
                <ShieldCheck size={16} aria-hidden="true" />
                Yêu cầu được bảo mật
              </span>
              <h2 id="booking-title">Cho CareSitter biết gia đình cần gì</h2>
              <p>
                Người phụ trách dự kiến: <strong>{caregiverName}</strong>
              </p>
            </header>

            <form className="booking-form" onSubmit={handleSubmit}>
              <fieldset>
                <legend>Loại hỗ trợ</legend>
                <div className="service-options">
                  {services.map((service) => (
                    <button
                      className={
                        "service-option" +
                        (selectedService === service
                          ? " service-option--selected"
                          : "")
                      }
                      key={service}
                      onClick={() => setSelectedService(service)}
                      type="button"
                    >
                      {service}
                    </button>
                  ))}
                </div>
              </fieldset>

              <div className="booking-form__row">
                <label>
                  Ngày bắt đầu
                  <input
                    min={localDateString()}
                    onChange={(event) => setShiftDate(event.target.value)}
                    required
                    type="date"
                    value={shiftDate}
                  />
                </label>
                <label>
                  Thời lượng
                  <select
                    onChange={(event) => setHours(event.target.value)}
                    value={hours}
                  >
                    <option value="2">2 giờ</option>
                    <option value="4">4 giờ</option>
                    <option value="8">8 giờ</option>
                    <option value="12">12 giờ</option>
                  </select>
                </label>
              </div>

              <div className="price-estimate">
                <span>Tạm tính cho {hours} giờ</span>
                <strong>{totalAmount.toLocaleString("vi-VN")} đ</strong>
                <small>Mức phí cuối cùng được xác nhận trước khi đặt ca.</small>
              </div>

              <button className="button button--primary button--wide" type="submit">
                Gửi nhu cầu
              </button>
            </form>
          </>
        )}
      </section>
    </div>
  );
}
