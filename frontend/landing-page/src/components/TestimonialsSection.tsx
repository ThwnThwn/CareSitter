"use client";

import { useCallback, useState } from "react";
import MotionWords from "./MotionWords";
import { motion } from "framer-motion";
import {
  BadgeCheck,
  Quote,
  Star,
} from "lucide-react";

const reviews = [
  {
    quote:
      "Đi làm cả ngày, nhưng mình vẫn biết mẹ đang được chăm sóc thế nào. Điều quý nhất là cảm giác mọi việc đều có người theo sát và chịu trách nhiệm.",
    author: "Minh Khôi",
    relation: "Con trai của cô Lan",
    location: "TP.HCM",
    initials: "MK",
  },
  {
    quote:
      "Lịch trình rõ ràng, cập nhật đúng lúc. Tôi có thể tập trung làm việc mà không cần gọi về nhà liên tục để hỏi thăm bố.",
    author: "Linh Thảo",
    relation: "Con gái của bác Hùng",
    location: "Hà Nội",
    initials: "LT",
  },
  {
    quote:
      "Caregiver đến đúng giờ, nói chuyện nhẹ nhàng và rất tôn trọng nếp sinh hoạt của bố tôi. Cả nhà yên tâm hơn hẳn.",
    author: "Anh Dũng",
    relation: "Con trai của bác Minh",
    location: "Đà Nẵng",
    initials: "AD",
  },
  {
    quote:
      "Từ buổi đầu làm quen đến mỗi lần bàn giao, mọi thông tin đều rõ ràng. Mẹ tôi cũng chủ động hỏi khi nào cô caregiver quay lại.",
    author: "Ngọc Mai",
    relation: "Gia đình cô Hạnh",
    location: "TP.HCM",
    initials: "NM",
  },
  {
    quote:
      "Không chỉ hỗ trợ sinh hoạt, caregiver còn biết cách trò chuyện để ông vui hơn. Đó là điều ứng dụng hay lịch trình không thể hiện hết.",
    author: "Tuấn Anh",
    relation: "Cháu của ông Phúc",
    location: "Hà Nội",
    initials: "TA",
  },
];

const compactReviews = [
  {
    quote: "Thông báo đúng lúc, lịch trình dễ theo dõi và không có khoản phí bất ngờ.",
    author: "Phương Vy",
    context: "Gia đình tại TP.HCM",
    initials: "PV",
  },
  {
    quote: "Mẹ tôi hợp với caregiver ngay từ buổi đầu. Cách trò chuyện rất tự nhiên.",
    author: "Hoàng Nam",
    context: "Gia đình tại Hà Nội",
    initials: "HN",
  },
  {
    quote: "Mỗi lần bàn giao đều rõ ràng nên anh chị em trong nhà cùng nắm được tình hình.",
    author: "Thu Hà",
    context: "Gia đình tại Hải Phòng",
    initials: "TH",
  },
  {
    quote: "Đổi lịch một lần nhưng được hỗ trợ rất nhanh, không làm gián đoạn ca chăm sóc.",
    author: "Quốc Bảo",
    context: "Gia đình tại Đà Nẵng",
    initials: "QB",
  },
  {
    quote: "Bố vui hơn vì có người đồng hành đều đặn, còn tôi bớt cảm giác phải xoay xở một mình.",
    author: "Hà My",
    context: "Gia đình tại Bình Dương",
    initials: "HM",
  },
  {
    quote: "Hồ sơ rõ ràng giúp gia đình chọn nhanh hơn mà vẫn cảm thấy mình đang quyết định kỹ.",
    author: "Đức Anh",
    context: "Gia đình tại TP.HCM",
    initials: "ĐA",
  },
];

function relativePosition(index: number, activeIndex: number) {
  let position = index - activeIndex;
  const midpoint = Math.floor(reviews.length / 2);

  if (position > midpoint) position -= reviews.length;
  if (position < -midpoint) position += reviews.length;

  return position;
}

export default function TestimonialsSection() {
  const [activeIndex, setActiveIndex] = useState(0);

  const goTo = useCallback((index: number) => {
    setActiveIndex((index + reviews.length) % reviews.length);
  }, []);

  const previous = useCallback(() => {
    setActiveIndex((current) => (current - 1 + reviews.length) % reviews.length);
  }, []);

  const next = useCallback(() => {
    setActiveIndex((current) => (current + 1) % reviews.length);
  }, []);

  return (
    <section className="stories-section" id="testimonials">
      <div className="shell">
        <header className="stories-section__heading">
          <div className="stories-section__intro">
            <p className="section-label section-label--ink">
              Câu chuyện từ gia đình
            </p>
            <h2 className="display display--section" data-scroll-reveal="heading">
              <MotionWords>
              Khi việc chăm sóc <em>trở nên nhẹ lòng.</em>
              </MotionWords>
            </h2>
          </div>

          <div className="stories-rating" aria-label="4,9 trên 5 sao">
            <strong>4,9</strong>
            <div>
              <span className="stories-rating__stars" aria-hidden="true">
                {[0, 1, 2, 3, 4].map((star) => (
                  <Star fill="currentColor" key={star} size={15} strokeWidth={0} />
                ))}
              </span>
              <span>từ hơn 12.000 lượt đánh giá</span>
            </div>
          </div>
        </header>

        <div className="review-carousel">
          <motion.div
            aria-label="Đánh giá của gia đình sử dụng CareSitter"
            aria-roledescription="carousel"
            className="review-carousel__stage"
            drag="x"
            dragConstraints={{ left: 0, right: 0 }}
            dragElastic={0.08}
            onDragEnd={(_, info) => {
              if (info.offset.x < -56 || info.velocity.x < -420) next();
              if (info.offset.x > 56 || info.velocity.x > 420) previous();
            }}
            onKeyDown={(event) => {
              if (event.key === "ArrowLeft") previous();
              if (event.key === "ArrowRight") next();
            }}
            role="region"
            tabIndex={0}
          >
            {reviews.map((review, index) => {
              const position = relativePosition(index, activeIndex);
              const isActive = position === 0;
              const isNearby = Math.abs(position) <= 1;

              return (
                <div className="review-carousel__slot" data-scroll-reveal="card" key={review.author}>
                  <motion.blockquote
                    animate={{
                      opacity: isActive ? 1 : isNearby ? 0.42 : 0,
                      scale: isActive ? 1 : 0.9,
                      x: `${position * 106}%`,
                    }}
                    aria-hidden={!isActive}
                    className="review-card"
                    initial={false}
                    style={{ pointerEvents: isActive ? "auto" : "none" }}
                    transition={{ duration: 0.55, ease: [0.22, 1, 0.36, 1] }}
                  >
                    <div className="review-card__topline">
                      <span className="review-card__stars" aria-label="5 trên 5 sao">
                        {[0, 1, 2, 3, 4].map((star) => (
                          <Star
                            aria-hidden="true"
                            fill="currentColor"
                            key={star}
                            size={17}
                            strokeWidth={0}
                          />
                        ))}
                      </span>
                      <Quote aria-hidden="true" size={34} strokeWidth={1.4} />
                    </div>

                    <p>“{review.quote}”</p>

                    <footer>
                      <span className="review-card__avatar" aria-hidden="true">
                        {review.initials}
                      </span>
                      <span className="review-card__person">
                        <strong>{review.author}</strong>
                        <small>
                          {review.relation} · {review.location}
                        </small>
                      </span>
                      <span className="review-card__verified">
                        <BadgeCheck aria-hidden="true" size={16} />
                        Đã xác thực
                      </span>
                    </footer>
                  </motion.blockquote>
                </div>
              );
            })}
          </motion.div>

          <div className="review-carousel__controls">
            <div className="review-carousel__dots" aria-label="Chọn đánh giá">
              {reviews.map((review, index) => (
                <button
                  aria-label={`Xem đánh giá của ${review.author}`}
                  aria-pressed={activeIndex === index}
                  key={review.author}
                  onClick={() => goTo(index)}
                  type="button"
                />
              ))}
            </div>

          </div>

          <div className="review-marquee" data-scroll-reveal="card">
            <div className="review-marquee__header">
              <h3>Những lời nhắn khác từ gia đình</h3>
            </div>

            <div
              aria-label="Các đánh giá ngắn từ gia đình"
              className="review-marquee__viewport"
              role="region"
            >
              <div className="review-marquee__track">
                {[false, true].map((isDuplicate) => (
                  <ul aria-hidden={isDuplicate} className="review-marquee__group" key={String(isDuplicate)}>
                    {compactReviews.map((review) => (
                      <li className="review-note" key={`${isDuplicate}-${review.author}`}>
                        <span className="review-note__stars" aria-label="5 trên 5 sao">
                          {[0, 1, 2, 3, 4].map((star) => (
                            <Star
                              aria-hidden="true"
                              fill="currentColor"
                              key={star}
                              size={14}
                              strokeWidth={0}
                            />
                          ))}
                        </span>
                        <p>“{review.quote}”</p>
                        <footer>
                          <span aria-hidden="true">{review.initials}</span>
                          <span>
                            <strong>{review.author}</strong>
                            <small>{review.context}</small>
                          </span>
                        </footer>
                      </li>
                    ))}
                  </ul>
                ))}
              </div>
            </div>
          </div>

          <p className="sr-only" aria-live="polite">
            Đánh giá {activeIndex + 1} trên {reviews.length}: {reviews[activeIndex].quote} —{" "}
            {reviews[activeIndex].author}
          </p>
        </div>
      </div>
    </section>
  );
}
