import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import {
  ArrowUpRight,
  BookOpen,
  CalendarDays,
  ClipboardList,
  HeartHandshake,
  Wallet,
} from "lucide-react";
import Header from "@/components/Header";
import Footer from "@/components/Footer";
import ConsultationProvider from "@/features/consultation/ConsultationProvider";
import CaregiverInterestPreview from "@/features/caregiver-interest/CaregiverInterestPreview";
import CaregiverRequirementsSection from "@/features/caregiver-interest/CaregiverRequirementsSection";

export const metadata: Metadata = {
  title: "Trở thành người chăm sóc | CareSitter",
  description:
    "Tìm hiểu cơ hội tham gia CareSitter, quyền lợi, thông tin cần chuẩn bị và quy trình xét duyệt hồ sơ người chăm sóc.",
  alternates: { canonical: "/tro-thanh-nguoi-cham-soc" },
  openGraph: {
    title: "Đồng hành cùng gia đình. Phát triển nghề chăm sóc.",
    description:
      "Tìm hiểu hành trình trở thành người chăm sóc cùng CareSitter.",
    url: "/tro-thanh-nguoi-cham-soc",
  },
};

const benefits = [
  {
    icon: HeartHandshake,
    title: "Cơ hội phù hợp với bạn",
    text: "Tiếp cận lời mời chăm sóc phù hợp với hồ sơ, khu vực và điều kiện của ca.",
  },
  {
    icon: ClipboardList,
    title: "Thông tin ca rõ ràng",
    text: "Xem thời gian, địa điểm, yêu cầu công việc và thu nhập dự kiến trước khi quyết định nhận ca.",
  },
  {
    icon: CalendarDays,
    title: "Theo dõi công việc thuận tiện",
    text: "Quản lý lịch làm, tiến độ chăm sóc và lịch sử ca trên ứng dụng.",
  },
  {
    icon: BookOpen,
    title: "Chuẩn bị cho hành trình tham gia",
    text: "Tìm hiểu yêu cầu hồ sơ, chia sẻ kinh nghiệm và nhu cầu bổ sung kỹ năng để được hướng dẫn các bước phù hợp.",
  },
  {
    icon: Wallet,
    title: "Ghi nhận thu nhập",
    text: "Theo dõi khoản thu nhập và gửi yêu cầu hỗ trợ về thanh toán trên nền tảng.",
  },
];
const steps = [
  [
    "Đăng ký quan tâm",
    "Chia sẻ thông tin liên hệ, kinh nghiệm và khu vực mong muốn làm việc.",
  ],
  [
    "Trao đổi ban đầu",
    "Bộ phận phụ trách tìm hiểu nhu cầu và hướng dẫn hồ sơ cần chuẩn bị.",
  ],
  [
    "Đánh giá hồ sơ và năng lực",
    "Xem xét kinh nghiệm, tài liệu chuyên môn và những thông tin cần bổ sung theo nhóm công việc.",
  ],
  [
    "Hoàn thiện hồ sơ nền tảng",
    "CareSitter ghi nhận kết quả và thực hiện quy trình xét duyệt tương ứng.",
  ],
  [
    "Sẵn sàng cho ca phù hợp",
    "Được hướng dẫn ứng dụng và quy trình làm việc trước khi tham gia các ca đủ điều kiện.",
  ],
];
const faqs = [
  [
    "Chưa có kinh nghiệm có thể tìm hiểu tham gia không?",
    "Bạn có thể chia sẻ nhu cầu học nghề trong biểu mẫu. Bộ phận phụ trách sẽ trao đổi về hướng đánh giá, đào tạo và nhóm công việc phù hợp.",
  ],
  [
    "CareSitter hỗ trợ người chăm sóc như thế nào?",
    "CareSitter xây dựng nền tảng kết nối với gia đình, xem thông tin ca và quản lý lịch làm việc. Quy trình tiếp nhận và xét duyệt cụ thể sẽ được công bố khi kênh đăng ký chính thức được mở.",
  ],
  [
    "Tôi cần chuẩn bị hồ sơ gì?",
    "Bước đầu chỉ cần thông tin liên hệ và kinh nghiệm. Giấy tờ định danh, chứng chỉ và các tài liệu chuyên môn được hướng dẫn ở bước hoàn thiện hồ sơ qua kênh tiếp nhận được công bố.",
  ],
  [
    "Tôi có thể nhận công việc điều dưỡng hoặc chuyên biệt không?",
    "Nhóm công việc này cần đánh giá chuyên môn và xác nhận phạm vi phù hợp. Điều kiện cụ thể được trao đổi trong quá trình xét duyệt hồ sơ.",
  ],
  [
    "Thu nhập, chi phí và thời gian thanh toán thế nào?",
    "Thông tin ca và thu nhập dự kiến được thể hiện trên ứng dụng. Chính sách phí, tỷ lệ thực nhận và lịch chi trả cần được trao đổi, xác nhận trước khi tham gia.",
  ],
  [
    "Biểu mẫu hiện đã tiếp nhận đăng ký chưa?",
    "Biểu mẫu đang ở chế độ xem thử để bạn tìm hiểu các thông tin cần chuẩn bị. Kênh tiếp nhận chính thức, khu vực và đầu mối liên hệ sẽ được công bố khi quy trình phối hợp hoàn tất.",
  ],
];

export default function CaregiverPage() {
  return (
    <ConsultationProvider>
      <a className="skip-link" href="#main-content">
        Bỏ qua điều hướng
      </a>
      <Header audience="caregiver" />
      <main id="main-content" className="caregiver-page">
        <section className="join-hero">
          <div className="shell join-hero__grid">
            <div>
              <p className="section-label section-label--ink">
                Dành cho người chăm sóc
              </p>
              <h1 className="display">
                Đồng hành cùng gia đình.
                <br />
                <em>Phát triển nghề chăm sóc.</em>
              </h1>
              <p className="join-hero__lead">
                Mang sự tận tâm của bạn đến những gia đình cần được sẻ chia.
                Cùng CareSitter tìm hiểu cơ hội chăm sóc phù hợp với kỹ năng và
                khu vực làm việc của bạn.
              </p>
              <a className="button button--primary" href="#dang-ky">
                Tìm hiểu đăng ký tham gia
                <ArrowUpRight size={18} aria-hidden="true" />
              </a>
              <div className="join-partner-mark">
                <span>Hành trình cùng CareSitter</span>
                <strong>Tận tâm trong công việc. Rõ ràng trong kết nối.</strong>
              </div>
            </div>
            <div className="join-hero__visual">
              <Image
                src="/images/caregiver-3.jpg"
                alt="Hình ảnh minh họa người chăm sóc đồng hành cùng người cao tuổi"
                fill
                priority
                sizes="(max-width: 800px) 100vw, 42vw"
              />
              <div className="join-hero__caption">
                <HeartHandshake size={24} aria-hidden="true" />
                <span>
                  Một công việc có giá trị.
                  <br />
                  <strong>Một hành trình có người đồng hành.</strong>
                </span>
              </div>
              <small>Hình ảnh minh họa</small>
            </div>
          </div>
        </section>
        <section className="join-benefits" id="quyen-loi">
          <div className="shell">
            <div className="section-intro">
              <div>
                <p className="section-label section-label--ink">
                  Cùng làm nghề, cùng phát triển
                </p>
                <h2 className="display display--section">
                  Để sự tận tâm
                  <br />
                  <em>có thêm điểm tựa.</em>
                </h2>
              </div>
              <p>
                Một nền tảng giúp bạn kết nối cơ hội, hiểu rõ công việc và theo
                dõi hành trình chăm sóc của mình.
              </p>
            </div>
            <div className="benefit-grid">
              {benefits.map(({ icon: Icon, title, text }) => (
                <article key={title}>
                  <Icon size={28} aria-hidden="true" />
                  <h3>{title}</h3>
                  <p>{text}</p>
                </article>
              ))}
            </div>
          </div>
        </section>
        <CaregiverRequirementsSection />
        <section className="join-process" id="quy-trinh">
          <div className="shell">
            <div className="section-intro">
              <div>
                <p className="section-label section-label--ink">
                  Hành trình tham gia dự kiến
                </p>
                <h2 className="display display--section">
                  Từng bước rõ ràng.
                  <br />
                  <em>Cùng bạn chuẩn bị.</em>
                </h2>
              </div>
              <p>
                CareSitter đang hoàn thiện quy trình tiếp nhận và xét duyệt hồ
                sơ. Tiêu chí và yêu cầu cụ thể sẽ được hướng dẫn khi tiếp nhận
                chính thức.
              </p>
            </div>
            <ol>
              {steps.map(([title, text], index) => (
                <li key={title}>
                  <span>{String(index + 1).padStart(2, "0")}</span>
                  <div>
                    <h3>{title}</h3>
                    <p>{text}</p>
                  </div>
                </li>
              ))}
            </ol>
            <div className="join-requirements">
              <h3>Bạn có thể bắt đầu chuẩn bị</h3>
              <p>
                Thông tin liên hệ, khu vực mong muốn làm việc và kinh nghiệm
                chăm sóc. Với công việc điều dưỡng hoặc chuyên biệt, chuẩn bị
                thông tin về chuyên môn và chứng chỉ liên quan để được hướng dẫn
                đánh giá.
              </p>
            </div>
          </div>
        </section>
        <section className="join-registration" id="dang-ky">
          <div className="shell registration-grid">
            <div>
              <p className="section-label section-label--ink">
                Bắt đầu từ câu chuyện của bạn
              </p>
              <h2 className="display display--section">
                Bạn muốn cùng
                <br />
                <em>CareSitter đồng hành?</em>
              </h2>
              <p>
                Tìm hiểu những thông tin cần chuẩn bị cho hành trình tham gia.
                Biểu mẫu hiện là bản xem thử để bạn khám phá quy trình.
              </p>
              <p className="registration-aside">
                Gia đình đang cần dịch vụ chăm sóc?{" "}
                <Link href="/#contact">Đăng ký tư vấn tại đây ↗</Link>
              </p>
            </div>
            <CaregiverInterestPreview />
          </div>
        </section>
        <section className="join-faq" id="cau-hoi">
          <div className="shell">
            <div className="section-intro">
              <div>
                <p className="section-label section-label--ink">
                  Những điều bạn muốn biết
                </p>
                <h2 className="display display--section">
                  Cùng giải đáp
                  <br />
                  <em>trước khi bắt đầu.</em>
                </h2>
              </div>
            </div>
            <div>
              {faqs.map(([question, answer]) => (
                <details key={question}>
                  <summary>
                    {question}
                    <span aria-hidden="true">+</span>
                  </summary>
                  <p>{answer}</p>
                </details>
              ))}
            </div>
          </div>
        </section>
      </main>
      <Footer />
    </ConsultationProvider>
  );
}
