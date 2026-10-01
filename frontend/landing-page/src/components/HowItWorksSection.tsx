import { CheckCircle2, Clock3, MessageCircle, Search } from "lucide-react";

const steps = [
  {
    number: "01",
    title: "Kể CareSitter điều gia đình cần",
    text: "Chọn thời gian, địa điểm và những hỗ trợ sinh hoạt cần thiết. Chúng tôi dùng thông tin này để tìm người phù hợp hơn, không chỉ người gần nhất.",
  },
  {
    number: "02",
    title: "Xem hồ sơ và lựa chọn",
    text: "So sánh kinh nghiệm, kỹ năng, mức phí và đánh giá. Gia đình luôn là người quyết định caregiver nào sẽ nhận ca.",
  },
  {
    number: "03",
    title: "Theo dõi ca trong một nơi",
    text: "Nhận thông báo check-in, trao đổi trực tiếp và xem nhật ký chăm sóc sau ca ngay trên ứng dụng.",
  },
];

export default function HowItWorksSection() {
  return (
    <section className="process-section" id="how-it-works">
      <div className="shell">
        <div className="process-section__heading">
          <div>
            <p className="section-label section-label--ink">Ba bước, không vòng vo</p>
            <h2 className="display display--section">
              Từ nhu cầu đến ca chăm sóc
              <em>trong vài phút.</em>
            </h2>
          </div>
          <p>
            Không gọi nhiều nơi, không chờ báo giá mơ hồ. Gia đình nhìn thấy
            lựa chọn, chi phí và trạng thái ca trên cùng một hành trình.
          </p>
        </div>

        <div className="process-layout">
          <ol className="process-list">
            {steps.map((step) => (
              <li key={step.number}>
                <span>{step.number}</span>
                <div>
                  <h3>{step.title}</h3>
                  <p>{step.text}</p>
                </div>
              </li>
            ))}
          </ol>

          <div className="care-timeline" aria-label="Minh họa tiến trình một ca chăm sóc">
            <div className="care-timeline__top">
              <span>Ca hôm nay</span>
              <strong>14:00 — 18:00</strong>
            </div>
            <div className="care-timeline__person">
              <span className="care-timeline__avatar" aria-hidden="true">HĐ</span>
              <div>
                <strong>Hải Đường</strong>
                <span>Đồng hành sinh hoạt</span>
              </div>
              <span className="status-dot">Đã xác nhận</span>
            </div>
            <ul>
              <li>
                <CheckCircle2 size={18} aria-hidden="true" />
                <div>
                  <strong>13:52</strong>
                  <span>Caregiver đã đến điểm hẹn</span>
                </div>
              </li>
              <li>
                <Clock3 size={18} aria-hidden="true" />
                <div>
                  <strong>14:00</strong>
                  <span>Ca chăm sóc bắt đầu</span>
                </div>
              </li>
              <li>
                <MessageCircle size={18} aria-hidden="true" />
                <div>
                  <strong>15:20</strong>
                  <span>Đã gửi cập nhật cho gia đình</span>
                </div>
              </li>
            </ul>
            <div className="care-timeline__footer">
              <Search size={17} aria-hidden="true" />
              Mọi mốc quan trọng đều có thể kiểm tra lại
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
