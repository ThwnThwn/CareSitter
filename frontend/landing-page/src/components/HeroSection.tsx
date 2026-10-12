"use client";
import { useConsultation } from "@/features/consultation/ConsultationProvider";

import Image from "next/image";
import { ArrowDownRight, ArrowUpRight, ShieldCheck } from "lucide-react";
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

        <div className="hero-collage" aria-label="CareSitter trong một ca chăm sóc">
          <figure className="hero-collage__main">
            <Image
              alt="Người chăm sóc đồng hành cùng một gia đình trong không gian ấm cúng"
              fill
              loading="eager"
              fetchPriority="high"
              sizes="(max-width: 900px) 100vw, 46vw"
              src="/images/app-hero.jpg"
            />
          </figure>

          <figure className="hero-collage__portrait">
            <Image
              alt="Chân dung caregiver Hải Đường"
              fill
              loading="eager"
              sizes="180px"
              src="/images/caregiver-1.jpg"
            />
          </figure>

          <div className="hero-collage__caption">
            <span>Hôm nay • Quận 7</span>
            <strong>Caregiver đến đúng giờ</strong>
            <small>Gia đình đã nhận thông báo</small>
          </div>

          <div className="hero-collage__seal" aria-label="Hồ sơ đã xác minh">
            <ShieldCheck size={22} aria-hidden="true" />
            <span>
              <strong>Đã xác minh</strong>
              Hồ sơ &amp; danh tính
            </span>
          </div>

        </div>
      </div>
    </section>
  );
}
