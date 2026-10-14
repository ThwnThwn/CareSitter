"use client";
import { useConsultation } from "@/features/consultation/ConsultationProvider";

import Image from "next/image";
import { ArrowUpRight, BadgeCheck, Star } from "lucide-react";
import MotionWords from "./MotionWords";

const caregivers = [
  {
    name: "Trần Văn Nam",
    role: "Hỗ trợ vận động & đi lại",
    detail: "5 năm kinh nghiệm chăm sóc gia đình",
    rating: "4,9",
    image: "/images/caregiver-2.jpg",
  },
  {
    name: "Nguyễn Thị Bích",
    role: "Đồng hành sinh hoạt hằng ngày",
    detail: "4 năm đồng hành cùng người lớn tuổi",
    rating: "4,9",
    image: "/images/caregiver-3.jpg",
  },
];

export default function CaregiversSection() {
  const onOpenBooking = useConsultation();
  return (
    <section className="caregivers-section" id="caregivers">
      <div className="shell">
        <div className="caregivers-section__heading">
          <div>
            <p className="section-label section-label--ink">Những người CareSitter tin cậy</p>
            <h2 className="display display--section" data-scroll-reveal="heading">
              <MotionWords>
              Kinh nghiệm là quan trọng.
              <em>Sự phù hợp cũng vậy.</em>
              </MotionWords>
            </h2>
          </div>
          <p>
            Mỗi hồ sơ cho biết rõ kinh nghiệm, kỹ năng và đánh giá để gia đình
            chọn người phù hợp với nếp sống của người thân.
          </p>
        </div>

        <div className="caregiver-showcase">
          <article className="caregiver-featured" data-scroll-reveal="card">
            <figure>
              <Image
                alt="Caregiver Hải Đường"
                fill
                sizes="(max-width: 850px) 100vw, 47vw"
                src="/images/caregiver-1.jpg"
              />
              <span>
                <BadgeCheck size={17} aria-hidden="true" />
                Hồ sơ đã xác minh
              </span>
            </figure>
            <div className="caregiver-featured__body">
              <span className="caregiver-role">Đồng hành người cao tuổi</span>
              <h3>Hải Đường</h3>
              <p>
                Kiên nhẫn, nhẹ nhàng và hiểu nếp sinh hoạt gia đình. 7 năm
                kinh nghiệm đồng hành cùng người lớn tuổi tại nhà.
              </p>
              <div className="caregiver-meta">
                <span>
                  <Star size={16} fill="currentColor" aria-hidden="true" />
                  5,0 • 68 đánh giá
                </span>
                <span>Sẵn sàng hôm nay</span>
              </div>
              <button
                className="inline-link"
                onClick={() =>
                  onOpenBooking("Hải Đường", "Chăm sóc người cao tuổi")
                }
              >
                Xem lịch của Hải Đường
                <ArrowUpRight size={17} aria-hidden="true" />
              </button>
            </div>
          </article>

          <div className="caregiver-list">
            {caregivers.map((caregiver) => (
              <article className="caregiver-row" data-scroll-reveal="card" key={caregiver.name}>
                <figure>
                  <Image
                    alt={"Caregiver " + caregiver.name}
                    fill
                    sizes="160px"
                    src={caregiver.image}
                  />
                </figure>
                <div>
                  <span className="caregiver-role">{caregiver.role}</span>
                  <h3>{caregiver.name}</h3>
                  <p>{caregiver.detail}</p>
                  <div className="caregiver-meta">
                    <span>
                      <Star size={15} fill="currentColor" aria-hidden="true" />
                      {caregiver.rating}
                    </span>
                    <button
                      onClick={() =>
                        onOpenBooking(caregiver.name, caregiver.role)
                      }
                    >
                      Xem lịch <ArrowUpRight size={15} aria-hidden="true" />
                    </button>
                  </div>
                </div>
              </article>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
