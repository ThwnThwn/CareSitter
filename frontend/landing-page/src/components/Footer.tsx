import Image from "next/image";

const footerGroups = [
  {
    title: "Khám phá",
    links: [
      ["Điểm khác biệt", "#features"],
      ["Quy trình", "#how-it-works"],
      ["Caregiver", "#caregivers"],
    ],
  },
  {
    title: "Hỗ trợ",
    links: [
      ["Chính sách quyền riêng tư", "/privacy"],
      ["Điều khoản dịch vụ", "/terms"],
      ["Xóa tài khoản", "/account-deletion"],
    ],
  },
];

export default function Footer() {
  return (
    <footer className="site-footer">
      <div className="shell site-footer__grid">
        <div className="site-footer__brand">
          <a className="brand-lockup brand-lockup--footer" href="#hero">
            <span className="brand-mark" aria-hidden="true">
              <Image
                src="/images/logo.png"
                alt="CareSitter"
                width={40}
                height={40}
              />
            </span>
            <span>
              <strong>CareSitter</strong>
              <small>Chăm sóc gia đình</small>
            </span>
          </a>
          <p>
            Nền tảng kết nối gia đình với người chăm sóc tại nhà đã được xác
            minh, dành cho các nhu cầu hỗ trợ sinh hoạt phi y tế.
          </p>
        </div>

        {footerGroups.map((group) => (
          <nav aria-label={group.title} key={group.title}>
            <strong>{group.title}</strong>
            {group.links.map(([label, href]) => (
              <a href={href} key={label}>
                {label}
              </a>
            ))}
          </nav>
        ))}

        <div className="site-footer__contact">
          <strong>Hỗ trợ 24/7</strong>
          <a href="tel:19001234">1900 1234</a>
          <span>hello@caresitter.vn</span>
        </div>
      </div>
      <div className="shell site-footer__bottom">
        <span>© 2026 CareSitter. Made with care in Vietnam.</span>
        <span>CareSitter không cung cấp dịch vụ y tế hoặc cấp cứu.</span>
      </div>
    </footer>
  );
}
