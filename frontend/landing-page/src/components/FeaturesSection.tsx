import {
  LifeBuoy,
  MapPinned,
  ShieldCheck,
  WalletCards,
} from "lucide-react";

const promises = [
  {
    icon: ShieldCheck,
    meta: "Hồ sơ",
    title: "Danh tính rõ ràng trước khi bắt đầu",
    text: "Mỗi caregiver phải hoàn tất xác minh danh tính, hồ sơ và các bước đánh giá cần thiết trước khi được nhận ca.",
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
    title: "Chi phí hiển thị trước, quyền lợi được giữ lại",
    text: "Mức phí được xác nhận trước khi đặt. Khoản thanh toán chỉ được hoàn tất theo quy trình checkout của gia đình.",
  },
  {
    icon: LifeBuoy,
    meta: "Hỗ trợ",
    title: "Có người tiếp nhận khi tình huống thay đổi",
    text: "Kênh hỗ trợ và cảnh báo an toàn giúp kết nối gia đình, caregiver và bộ phận vận hành khi cần.",
  },
];

export default function FeaturesSection() {
  return (
    <section className="promise-section" id="features">
      <div className="shell promise-section__grid">
        <div className="promise-section__intro">
          <p className="section-label">An tâm không đến từ một lời hứa</p>
          <h2 className="display display--section">
            Mọi ca chăm sóc đều có một
            <em>đường đi rõ ràng.</em>
          </h2>
          <p>
            CareSitter tập trung vào những gì gia đình thực sự cần biết: ai
            đang đến, ca đang diễn ra ra sao và quyền lợi được bảo vệ thế nào.
          </p>
          <a className="inline-link inline-link--light" href="#how-it-works">
            Xem toàn bộ quy trình
            <span aria-hidden="true">↘</span>
          </a>
        </div>

        <div className="promise-list">
          {promises.map(({ icon: Icon, meta, text, title }) => (
            <article className="promise-item" key={title}>
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
