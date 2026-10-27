"use client";
import { useConsultation } from "@/features/consultation/ConsultationProvider";

import Image from "next/image";
import {
  ArrowDownRight,
  ArrowUpRight,
  BellRing,
  Check,
  MapPinCheck,
  ShieldCheck,
} from "lucide-react";
import { useEffect, useRef } from "react";
import { useHeroCollageMotion } from "./useHeroCollageMotion";
import CareAssistant from "./CareAssistant";

export default function HeroSection() {
  const onOpenBooking = useConsultation();
  const heroRef = useRef<HTMLElement>(null);
  useHeroCollageMotion(heroRef);

  useEffect(() => {
    const hero = heroRef.current;
    if (!hero) return;

    const groups = Array.from(hero.querySelectorAll<HTMLElement>("[data-hero-entrance]"));
    const visibleGroups = new Set<HTMLElement>();

    const revealReadyGroups = () => {
      if (document.visibilityState !== "visible") return;

      for (const group of visibleGroups) {
        group.dataset.heroEntered = "true";
        visibleGroups.delete(group);
        observer?.unobserve(group);
      }
    };

    const observer = "IntersectionObserver" in window
      ? new IntersectionObserver((entries) => {
          for (const entry of entries) {
            const group = entry.target as HTMLElement;
            if (entry.isIntersecting) visibleGroups.add(group);
            else visibleGroups.delete(group);
          }
          revealReadyGroups();
        }, { threshold: 0.12 })
      : null;

    for (const group of groups) {
      if (observer) observer.observe(group);
      else visibleGroups.add(group);
    }
    revealReadyGroups();
    document.addEventListener("visibilitychange", revealReadyGroups);

    return () => {
      observer?.disconnect();
      document.removeEventListener("visibilitychange", revealReadyGroups);
      for (const group of groups) delete group.dataset.heroEntered;
    };
  }, []);

  return (
    <section className="hero" id="hero" ref={heroRef}>
      <div className="shell hero__grid">
        <div className="hero__copy" data-hero-entrance="copy">
          <div className="hero__kicker">
            <ShieldCheck size={15} aria-hidden="true" />
            Caregiver được xác minh trước khi nhận ca
          </div>

          <h1 className="display display--hero">
            Người thân được chăm.
            <em>Bạn được an lòng.</em>
          </h1>

          <p className="hero__lead">
            Tìm người đồng hành phù hợp cho cha mẹ ngay tại nhà — hồ sơ rõ
            ràng, lịch trình minh bạch và gia đình luôn biết ca chăm sóc đang
            diễn ra thế nào.
          </p>

          <div className="hero__actions">
            <button
              className="button button--primary"
              onClick={() =>
                onOpenBooking(undefined, "Chăm sóc người cao tuổi")
              }
            >
              Tìm người chăm sóc
              <ArrowUpRight size={18} aria-hidden="true" />
            </button>
            <a className="button button--text" href="#how-it-works">
              Xem cách hoạt động
              <ArrowDownRight size={18} aria-hidden="true" />
            </a>
            <CareAssistant onOpenBooking={onOpenBooking} />
          </div>

          <div className="hero__proof" aria-label="Đánh giá từ cộng đồng">
            <div className="avatar-stack" aria-hidden="true">
              {["caregiver-1.jpg", "caregiver-2.jpg", "caregiver-3.jpg"].map(
                (image) => (
                  <Image
                    alt=""
                    height={42}
                    key={image}
                    loading="eager"
                    src={"/images/" + image}
                    width={42}
                  />
                ),
              )}
            </div>
            <div>
              <strong>4,9/5 từ hơn 12.000 gia đình</strong>
              <span>Được tin chọn cho những ca chăm sóc mỗi ngày</span>
            </div>
          </div>
        </div>

        <div
          className="hero-journey"
          aria-label="Ba tín hiệu an tâm trong một ca chăm sóc CareSitter"
        >
          <figure
            className="hero-journey__photo"
            data-journey-layer
            data-depth="0.35"
          >
            <Image
              alt="Caregiver trò chuyện cùng người cao tuổi và gia đình trong không gian ấm cúng"
              fill
              loading="eager"
              fetchPriority="high"
              sizes="(max-width: 820px) 94vw, 52vw"
              src="/images/app-hero.jpg"
            />
          </figure>

          <div
            className="hero-journey__portrait"
            data-journey-layer
            data-depth="0.9"
          >
            <Image
              alt="Caregiver Hải Đường đã được xác minh"
              fill
              loading="eager"
              sizes="(max-width: 620px) 92px, 132px"
              src="/images/caregiver-1.jpg"
            />
            <span aria-hidden="true">
              <Check size={15} strokeWidth={3} />
            </span>
          </div>

          <svg
            aria-hidden="true"
            className="hero-journey__path"
            data-journey-layer
            data-depth="0.58"
            preserveAspectRatio="none"
            viewBox="0 0 760 610"
          >
            <path
              className="hero-journey__path-shadow"
              d="M285 62 C460 48 570 78 620 160 C660 226 626 278 676 334 C727 392 724 470 642 535"
            />
            <path
              className="hero-journey__path-line"
              d="M285 62 C460 48 570 78 620 160 C660 226 626 278 676 334 C727 392 724 470 642 535"
              pathLength="1"
            />
            <circle cx="285" cy="62" r="7" />
            <circle cx="620" cy="160" r="7" />
            <circle cx="676" cy="334" r="7" />
          </svg>

          <ol className="hero-journey__steps">
            <li
              className="hero-journey__step hero-journey__step--verified"
              data-journey-card
              data-journey-layer
              data-depth="1"
            >
              <span className="hero-journey__step-icon">
                <ShieldCheck size={24} aria-hidden="true" />
              </span>
              <span>
                <strong>Hồ sơ đã xác minh</strong>
                <small>Danh tính đã được đối chiếu</small>
              </span>
            </li>

            <li
              className="hero-journey__step hero-journey__step--arrived"
              data-journey-card
              data-journey-layer
              data-depth="1.1"
            >
              <span className="hero-journey__step-icon">
                <MapPinCheck size={24} aria-hidden="true" />
              </span>
              <span>
                <strong>Caregiver đã đến</strong>
                <small>GPS xác nhận lúc 08:02</small>
              </span>
            </li>

            <li
              className="hero-journey__step hero-journey__step--notified"
              data-journey-card
              data-journey-layer
              data-depth="1.18"
            >
              <span className="hero-journey__step-icon">
                <BellRing size={24} aria-hidden="true" />
              </span>
              <span>
                <strong>Gia đình đã nhận cập nhật</strong>
                <small>Thông báo được gửi ngay</small>
              </span>
            </li>
          </ol>

          <div
            className="hero-journey__resolution"
            data-journey-card
            data-journey-layer
            data-depth="0.92"
          >
            <span aria-hidden="true">
              <Check size={18} strokeWidth={3} />
            </span>
            Bạn luôn biết ca chăm sóc đang diễn ra thế nào.
          </div>
        </div>
      </div>
    </section>
  );
}
