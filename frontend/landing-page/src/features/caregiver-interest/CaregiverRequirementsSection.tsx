import {
  Activity,
  ArrowUpRight,
  BriefcaseBusiness,
  Camera,
  ClipboardCheck,
  GraduationCap,
  HeartHandshake,
  IdCard,
  Smartphone,
} from "lucide-react";

const requirementGroups = [
  {
    title: "Hồ sơ cần chuẩn bị",
    items: [
      {
        icon: IdCard,
        title: "Giấy tờ định danh",
        description:
          "CCCD hoặc giấy tờ định danh còn hiệu lực, cung cấp theo hướng dẫn ở bước hoàn thiện hồ sơ.",
      },
      {
        icon: Camera,
        title: "Ảnh chân dung",
        description: "Ảnh rõ khuôn mặt để hoàn thiện hồ sơ người chăm sóc.",
      },
      {
        icon: BriefcaseBusiness,
        title: "Thông tin kinh nghiệm",
        description:
          "Kinh nghiệm, kỹ năng chăm sóc, nhóm công việc và khu vực mong muốn làm việc.",
      },
      {
        icon: GraduationCap,
        title: "Bằng cấp, chứng chỉ liên quan",
        description:
          "Chuẩn bị tài liệu chuyên môn tương ứng nếu đăng ký công việc điều dưỡng hoặc dịch vụ chuyên biệt.",
      },
    ],
  },
  {
    title: "Yêu cầu khi tham gia",
    items: [
      {
        icon: Smartphone,
        title: "Sử dụng được ứng dụng",
        description:
          "Có điện thoại thông minh và kết nối Internet để theo dõi lịch, thông tin ca và cập nhật công việc.",
      },
      {
        icon: HeartHandshake,
        title: "Tận tâm và tôn trọng",
        description:
          "Kiên nhẫn, giao tiếp phù hợp, tôn trọng người được chăm sóc và bảo mật thông tin gia đình.",
      },
      {
        icon: Activity,
        title: "Phù hợp với công việc",
        description:
          "Có sức khỏe, kỹ năng và năng lực chuyên môn phù hợp với nhóm công việc đăng ký.",
      },
      {
        icon: ClipboardCheck,
        title: "Hoàn tất quy trình xét duyệt",
        description:
          "Cung cấp thông tin trung thực, bổ sung hồ sơ theo hướng dẫn và hoàn tất xét duyệt trước khi nhận ca.",
      },
    ],
  },
];

export default function CaregiverRequirementsSection() {
  return (
    <section className="join-documents" id="hanh-trang">
      <div className="shell">
        <div className="requirements-heading">
          <p className="section-label section-label--ink">
            Hành trang tham gia
          </p>
          <h2 className="display display--section">
            Chuẩn bị hồ sơ.
            <br />
            <em>Sẵn sàng đồng hành.</em>
          </h2>
          <p>
            Tìm hiểu những thông tin cần chuẩn bị và các yêu cầu khi tham gia
            chăm sóc cùng CareSitter.
          </p>
        </div>
        <div className="requirements-grid">
          {requirementGroups.map((group) => (
            <article className="requirements-card" key={group.title}>
              <h3>{group.title}</h3>
              <ul>
                {group.items.map(({ icon: Icon, title, description }) => (
                  <li key={title}>
                    <span className="requirements-icon" aria-hidden="true">
                      <Icon size={22} />
                    </span>
                    <div>
                      <h4>{title}</h4>
                      <p>{description}</p>
                    </div>
                  </li>
                ))}
              </ul>
            </article>
          ))}
        </div>
        <div className="requirements-note">
          <p>
            <strong>
              Bạn có thể bắt đầu bằng thông tin liên hệ và kinh nghiệm chăm sóc.
            </strong>{" "}
            Giấy tờ và tài liệu bổ sung sẽ được hướng dẫn ở bước hoàn thiện hồ
            sơ. Yêu cầu cụ thể được xác định theo từng nhóm công việc.
          </p>
          <a className="button button--primary" href="#dang-ky">
            Tìm hiểu đăng ký tham gia
            <ArrowUpRight size={18} aria-hidden="true" />
          </a>
        </div>
      </div>
    </section>
  );
}
