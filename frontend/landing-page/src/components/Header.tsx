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

  useEffect(() => {
    document.body.classList.toggle("menu-is-open", menuOpen);
    return () => document.body.classList.remove("menu-is-open");
  }, [menuOpen]);

  return (
    <header className="site-header">
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
              {item.label}
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
      >
        <nav aria-label="Điều hướng trên điện thoại">
          {navItems.map((item) => (
            <a
              href={item.href}
              key={item.href}
              onClick={() => setMenuOpen(false)}
            >
              {item.label}
            </a>
          ))}
          <button
            className="button button--wide"
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
