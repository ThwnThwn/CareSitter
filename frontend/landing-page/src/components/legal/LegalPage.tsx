import Link from "next/link";
import { ArrowLeft, Heart } from "lucide-react";
import styles from "./legal-page.module.css";

type LegalSection = {
  id: string;
  title: string;
  content: React.ReactNode;
};

type LegalPageProps = {
  title: string;
  summary: string;
  updatedAt: string;
  sections: LegalSection[];
  action?: React.ReactNode;
};

export default function LegalPage({
  title,
  summary,
  updatedAt,
  sections,
  action,
}: LegalPageProps) {
  return (
    <main className={styles.page}>
      <header className={styles.header}>
        <Link className={styles.brand} href="/" aria-label="Về trang chủ CareSitter">
          <span className={styles.mark} aria-hidden="true">
            <Heart size={18} strokeWidth={2.2} />
          </span>
          <span>
            <strong>CareSitter</strong>
            <small>Chăm sóc gia đình</small>
          </span>
        </Link>
        <Link className={styles.back} href="/">
          <ArrowLeft size={17} aria-hidden="true" />
          Trang chủ
        </Link>
      </header>

      <div className={styles.shell}>
        <aside className={styles.toc} aria-label="Mục lục">
          <p>Nội dung</p>
          <nav>
            {sections.map((section) => (
              <a href={`#${section.id}`} key={section.id}>
                {section.title}
              </a>
            ))}
          </nav>
        </aside>

        <article className={styles.article}>
          <div className={styles.intro}>
            <p className={styles.updated}>Cập nhật ngày {updatedAt}</p>
            <h1>{title}</h1>
            <p>{summary}</p>
            {action}
          </div>

          {sections.map((section) => (
            <section id={section.id} key={section.id}>
              <h2>{section.title}</h2>
              {section.content}
            </section>
          ))}

          <footer className={styles.footer}>
            <p>
              Cần hỗ trợ thêm? Gửi email đến{" "}
              <a href="mailto:hello@caresitter.vn">hello@caresitter.vn</a>.
            </p>
            <div>
              <Link href="/privacy">Chính sách quyền riêng tư</Link>
              <Link href="/terms">Điều khoản dịch vụ</Link>
              <Link href="/account-deletion">Xóa tài khoản</Link>
            </div>
          </footer>
        </article>
      </div>
    </main>
  );
}
