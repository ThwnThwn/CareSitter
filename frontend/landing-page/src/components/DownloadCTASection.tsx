"use client";

import { ArrowUpRight, Smartphone } from "lucide-react";

interface DownloadCTASectionProps {
  onOpenBooking: () => void;
}

export default function DownloadCTASection({
  onOpenBooking,
}: DownloadCTASectionProps) {
  return (
    <section className="download-section" id="download">
      <div className="shell">
        <div className="download-panel">
          <div className="download-panel__copy" data-scroll-reveal="card">
            <p className="section-label">Bắt đầu khi gia đình sẵn sàng</p>
            <h2 className="display display--cta">
              Một ca chăm sóc tốt bắt đầu bằng một nhu cầu được nói rõ.
            </h2>
            <p>
              Cho CareSitter biết thời gian và kiểu hỗ trợ gia đình cần. Bạn sẽ
              xem được lựa chọn và mức phí trước khi xác nhận.
            </p>
            <div className="download-panel__actions">
              <button className="button button--light" onClick={onOpenBooking}>
                Đặt ca đầu tiên
                <ArrowUpRight size={18} aria-hidden="true" />
              </button>
              <a className="button button--ghost-light" href="#caregivers">
                Xem caregiver
              </a>
            </div>
          </div>

          <div className="download-card" data-scroll-reveal="card">
            <Smartphone size={28} aria-hidden="true" />
            <span>Ứng dụng CareSitter</span>
            <strong>Mọi cập nhật của ca chăm sóc, trong một nơi.</strong>
            <div className="download-card__stores">
              <a href="#" aria-label="Tải CareSitter trên App Store">
                <small>Tải trên</small>
                App Store
              </a>
              <a href="#" aria-label="Tải CareSitter trên Google Play">
                <small>Tải trên</small>
                Google Play
              </a>
            </div>
            <p>Sắp có mặt trên iOS và Android</p>
          </div>
        </div>
      </div>
    </section>
  );
}
