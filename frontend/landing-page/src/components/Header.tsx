"use client";

import { Heart, Menu, X } from "lucide-react";
import { useEffect, useState } from "react";

interface HeaderProps {
  onOpenBooking: () => void;
}

const navItems = [
  { label: "Điểm khác biệt", href: "#features" },
  { label: "Quy trình", href: "#how-it-works" },
  { label: "Caregiver", href: "#caregivers" },
  { label: "Câu chuyện", href: "#testimonials" },
];

export default function Header({ onOpenBooking }: HeaderProps) {
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
      const keyboardFocus = document.querySelector(".site-header :focus-visible");
      if (menuOpen || keyboardFocus || document.body.style.overflow === "hidden" || y < 90) {
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
        <a className="brand-lockup" href="#hero" aria-label="CareSitter — về đầu trang">
          <span className="brand-mark" aria-hidden="true">
            <Heart size={18} strokeWidth={2.2} />
          </span>
          <span>
            <strong>CareSitter</strong>
            <small>Chăm sóc gia đình</small>
          </span>
        </a>

        <nav className="desktop-nav" aria-label="Điều hướng chính">
          {navItems.map((item) => (
            <a href={item.href} key={item.href}>
              <span>{item.label}</span>
              <span className="desktop-nav__underline" aria-hidden="true" />
            </a>
          ))}
        </nav>

        <div className="header-actions">
          <button className="button button--compact" onClick={onOpenBooking}>
            Đặt ca chăm sóc
          </button>
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
            <a
              href={item.href}
              key={item.href}
              onClick={() => setMenuOpen(false)}
            >
              <span className="mobile-nav__label">
                <span>{item.label}</span>
                <span className="mobile-nav__underline" aria-hidden="true" />
              </span>
            </a>
          ))}
          <button
            className="button button--primary button--wide"
            onClick={() => {
              setMenuOpen(false);
              onOpenBooking();
            }}
          >
            Bắt đầu đặt ca
          </button>
        </nav>
      </div>
    </header>
  );
}
