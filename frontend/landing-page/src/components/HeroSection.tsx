"use client";

import Image from "next/image";
import { ArrowDownRight, ArrowUpRight, ShieldCheck } from "lucide-react";

interface HeroSectionProps {
  onOpenBooking: (caregiver?: string, service?: string) => void;
}

export default function HeroSection({ onOpenBooking }: HeroSectionProps) {
  return (
    <section className="hero" id="hero">
      <div className="shell hero__grid">
        <div className="hero__copy">
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
          </div>

          <div className="hero__proof" aria-label="Đánh giá từ cộng đồng">
            <div className="avatar-stack" aria-hidden="true">
              {["caregiver-1.jpg", "caregiver-2.jpg", "caregiver-3.jpg"].map(
                (image) => (
                  <Image
                    alt=""
                    height={42}
                    key={image}
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
              priority
              sizes="(max-width: 900px) 100vw, 46vw"
              src="/images/app-hero.jpg"
            />
          </figure>

          <figure className="hero-collage__portrait">
            <Image
              alt="Chân dung caregiver Hải Đường"
              fill
              priority
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
