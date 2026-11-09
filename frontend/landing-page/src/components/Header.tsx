"use client";
import { useConsultation } from "@/features/consultation/ConsultationProvider";

import Image from "next/image";
import Link from "next/link";
import { Menu, X } from "lucide-react";
import { useEffect, useState } from "react";

const familyNav = [
  { label: "Về chúng tôi", href: "/#about" },
  { label: "Điểm khác biệt", href: "/#features" },
  { label: "Quy trình", href: "/#how-it-works" },
  { label: "Dịch vụ", href: "/#services" },
  { label: "Câu chuyện", href: "/#testimonials" },
  { label: "Trở thành chăm sóc viên", href: "/tro-thanh-nguoi-cham-soc" },
];
const caregiverNav = [
  { label: "Quyền lợi", href: "#quyen-loi" },
  { label: "Hành trang", href: "#hanh-trang" },
  { label: "Quy trình", href: "#quy-trinh" },
  { label: "Câu hỏi", href: "#cau-hoi" },
];

export default function Header({
  audience = "family",
}: {
  audience?: "family" | "caregiver";
}) {
  const navItems = audience === "caregiver" ? caregiverNav : familyNav;
  const onOpenBooking = useConsultation();
  const [menuOpen, setMenuOpen] = useState(false);
  const [isHidden, setIsHidden] = useState(false);

  useEffect(() => {
    document.body.classList.toggle("menu-is-open", menuOpen);
    return () => document.body.classList.remove("menu-is-open");
  }, [menuOpen]);

  useEffect(() => {
    let previousY = Math.max(0, window.scrollY);
    let frame = 0;
    const update = () => {
      frame = 0;
      const y = Math.max(0, window.scrollY);
      const delta = y - previousY;
      const keyboardFocus = document.querySelector(
        ".site-header :focus-visible",
      );
      if (
        menuOpen ||
        keyboardFocus ||
        document.body.style.overflow === "hidden" ||
        y < 90
      ) {
        setIsHidden(false);
        previousY = y;
        return;
      }
      // Ignore sub-pixel inertia and small touch reversals near rest.
      if (Math.abs(delta) < 6) return;
      setIsHidden(delta > 0);
      previousY = y;
    };
    const onScroll = () => {
      if (!frame) frame = window.requestAnimationFrame(update);
    };
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => {
      window.removeEventListener("scroll", onScroll);
      window.cancelAnimationFrame(frame);
    };
  }, [menuOpen]);

  return (
    <header
      className="site-header"
      data-hidden={isHidden && !menuOpen}
      onFocusCapture={() => setIsHidden(false)}
    >
      <div className="site-header__inner shell">
        <Link
          className="brand-lockup"
          href="/"
          aria-label="CareSitter — về trang chủ"
        >
          <span className="brand-mark" aria-hidden="true">
            <Image
              src="/images/logo.png"
              alt="CareSitter"
              width={40}
              height={40}
              priority
            />
          </span>
          <span>
            <strong>CareSitter</strong>
            <small>Chăm sóc gia đình</small>
          </span>
        </Link>

        <nav className="desktop-nav" aria-label="Điều hướng chính">
          {navItems.map((item) => (
            <Link href={item.href} key={item.href}>
              <span>{item.label}</span>
              <span className="desktop-nav__underline" aria-hidden="true" />
            </Link>
          ))}
        </nav>

        <div className="header-actions">
          {audience === "caregiver" ? (
            <a className="button button--compact" href="#dang-ky">
              Tìm hiểu tham gia
            </a>
          ) : (
            <button
              className="button button--compact"
              onClick={() => onOpenBooking()}
            >
              Đăng ký tư vấn
            </button>
          )}
          <button
            className="menu-toggle"
            type="button"
            aria-label={menuOpen ? "Đóng menu" : "Mở menu"}
            aria-expanded={menuOpen}
            aria-controls="mobile-navigation"
            onClick={() => setMenuOpen((open) => !open)}
          >
            {menuOpen ? <X size={22} /> : <Menu size={22} />}
          </button>
        </div>
      </div>

      <div
        className={"mobile-nav" + (menuOpen ? " mobile-nav--open" : "")}
        id="mobile-navigation"
        inert={!menuOpen}
      >
        <nav aria-label="Điều hướng trên điện thoại">
          {navItems.map((item) => (
            <Link
              href={item.href}
              key={item.href}
              onClick={() => setMenuOpen(false)}
            >
              <span className="mobile-nav__label">
                <span>{item.label}</span>
                <span className="mobile-nav__underline" aria-hidden="true" />
              </span>
            </Link>
          ))}
          {audience === "caregiver" ? (
            <a
              className="button button--primary button--wide"
              href="#dang-ky"
              onClick={() => setMenuOpen(false)}
            >
              Tìm hiểu tham gia
            </a>
          ) : (
            <button
              className="button button--primary button--wide"
              onClick={() => {
                setMenuOpen(false);
                onOpenBooking();
              }}
            >
              Đăng ký tư vấn
            </button>
          )}
        </nav>
      </div>
    </header>
  );
}
