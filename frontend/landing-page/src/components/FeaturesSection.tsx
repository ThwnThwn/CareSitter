import MotionWords from "./MotionWords";
import { LifeBuoy, MapPinned, ShieldCheck, WalletCards } from "lucide-react";

const promises = [
  {
    icon: ShieldCheck,
    meta: "Hồ sơ",
    title: "Hồ sơ được xét duyệt trước khi nhận ca",
    text: "Người chăm sóc hoàn tất quy trình nộp và xét duyệt hồ sơ trên nền tảng trước khi được nhận ca phù hợp.",
  },
  {
    icon: MapPinned,
    meta: "Trong ca",
    title: "Gia đình theo dõi được từng mốc quan trọng",
    text: "Check-in, trạng thái ca và nhật ký chăm sóc được cập nhật để người nhà không phải gọi hỏi liên tục.",
  },
  {
    icon: WalletCards,
    meta: "Thanh toán",
    title: "Thông tin ca và chi phí rõ ràng",
    text: "Gia đình xem dịch vụ, thời gian, địa điểm và mức giá trước khi xác nhận đặt ca.",
  },
  {
    icon: LifeBuoy,
    meta: "Hỗ trợ",
    title: "Có người tiếp nhận khi tình huống thay đổi",
    text: "Gia đình và người chăm sóc có thể gửi yêu cầu, bằng chứng và trao đổi với CareSitter khi phát sinh vấn đề.",
  },
];

export default function FeaturesSection() {
  return (
    <section className="promise-section" id="features">
      <div className="shell promise-section__grid">
        <div className="promise-section__intro">
          <p className="section-label">An tâm không đến từ một lời hứa</p>
          <h2 className="display display--section" data-scroll-reveal="heading">
            <MotionWords>
              Mọi ca chăm sóc đều có một
              <em>đường đi rõ ràng.</em>
            </MotionWords>
          </h2>
          <p>
            CareSitter tập trung vào những gì gia đình thực sự cần biết: ai đang
            đến, ca đang diễn ra ra sao và quyền lợi được bảo vệ thế nào.
          </p>
          <a className="inline-link inline-link--light" href="#how-it-works">
            Xem toàn bộ quy trình
            <span aria-hidden="true">↘</span>
          </a>
        </div>

        <div className="promise-list">
          {promises.map(({ icon: Icon, meta, text, title }) => (
            <article
              className="promise-item"
              data-scroll-reveal="item"
              key={title}
            >
              <div className="promise-item__icon" aria-hidden="true">
                <Icon size={22} strokeWidth={1.8} />
              </div>
              <div>
                <span>{meta}</span>
                <h3>{title}</h3>
                <p>{text}</p>
              </div>
            </article>
          ))}
        </div>
      </div>
    </section>
  );
}
