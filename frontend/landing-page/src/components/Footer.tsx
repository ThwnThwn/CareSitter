import Image from "next/image";
import Link from "next/link";

const footerGroups = [
  {
    title: "Khám phá",
    links: [
      ["Dịch vụ chăm sóc", "/#services"],
      ["Điểm khác biệt", "/#features"],
      ["Quy trình", "/#how-it-works"],
      ["Caregiver", "/#caregivers"],
      ["Về CareSitter", "/#about"],
      ["Trở thành người chăm sóc", "/tro-thanh-nguoi-cham-soc"],
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
          <Link className="brand-lockup brand-lockup--footer" href="/">
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
          </Link>
          <p>
            Nền tảng kết nối gia đình với người chăm sóc phù hợp, hướng đến sự
            minh bạch, thuận tiện và an tâm trong từng hành trình chăm sóc.
          </p>
        </div>

        {footerGroups.map((group) => (
          <nav aria-label={group.title} key={group.title}>
            <strong>{group.title}</strong>
            {group.links.map(([label, href]) => (
              <Link href={href} key={label}>
                {label}
              </Link>
            ))}
          </nav>
        ))}

        <div className="site-footer__contact">
          <strong>Kết nối với chúng tôi</strong>
          <Link href="/#contact">Đăng ký tư vấn dịch vụ ↗</Link>
          <Link href="/tro-thanh-nguoi-cham-soc#dang-ky">
            Tìm hiểu cách tham gia ↗
          </Link>
          <span>Kết nối gia đình và người chăm sóc</span>
        </div>
      </div>
      <div className="shell site-footer__bottom">
        <span>© 2026 CareSitter. Made with care in Vietnam.</span>
        <span>
          Dịch vụ được tư vấn theo nhu cầu và phạm vi chuyên môn phù hợp.
        </span>
      </div>
    </footer>
  );
}
