"use client";

import { ArrowUpRight, Bot, LoaderCircle, Sparkles, X } from "lucide-react";
import { FormEvent, useState } from "react";
import { useCareAssistant } from "@/features/care-assistant/useCareAssistant";

interface CareAssistantProps {
  onOpenBooking: (caregiver?: string, service?: string) => void;
}

const examples = [
  "Mẹ tôi cần người ở cùng và hỗ trợ bữa ăn buổi sáng.",
  "Tôi cần người đưa bố đi khám và hỗ trợ di chuyển.",
];

export default function CareAssistant({ onOpenBooking }: CareAssistantProps) {
  const [open, setOpen] = useState(false);
  const [message, setMessage] = useState("");
  const { recommendation, error, loading, submit: requestSuggestion, cancel } = useCareAssistant();
  const close = () => { cancel(); setOpen(false); };

  const submit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (message.trim().length < 8 || loading) return;

    await requestSuggestion(message);
  };

  return (
    <>
      <button
        className="button button--ai"
        onClick={() => setOpen(true)}
        type="button"
      >
        <Sparkles size={17} aria-hidden="true" />
        Hỏi trợ lý AI
      </button>

      {open ? (
        <div className="ai-assistant-backdrop" onMouseDown={close}>
          <section
            aria-labelledby="care-assistant-title"
            aria-modal="true"
            className="ai-assistant"
            onMouseDown={(event) => event.stopPropagation()}
            role="dialog"
          >
            <button
              aria-label="Đóng trợ lý AI"
              className="ai-assistant__close"
              onClick={close}
              type="button"
            >
              <X size={18} aria-hidden="true" />
            </button>
            <div className="ai-assistant__heading">
              <span className="ai-assistant__icon" aria-hidden="true"><Bot size={21} /></span>
              <div>
                <p className="section-label section-label--ink">Trợ lý CareSitter</p>
                <h2 id="care-assistant-title">Mình giúp bạn chọn loại hỗ trợ phù hợp.</h2>
              </div>
            </div>
            <p className="ai-assistant__intro">
              Mô tả ngắn nhu cầu của gia đình. Đây là gợi ý ban đầu, chưa phải tư vấn y khoa hay xác nhận đặt ca.
            </p>
            <div className="ai-assistant__examples" aria-label="Gợi ý câu hỏi">
              {examples.map((example) => (
                <button key={example} onClick={() => setMessage(example)} type="button">
                  {example}
                </button>
              ))}
            </div>
            <form onSubmit={submit}>
              <label className="sr-only" htmlFor="care-assistant-message">Nhu cầu của gia đình</label>
              <textarea
                id="care-assistant-message"
                maxLength={1200}
                onChange={(event) => setMessage(event.target.value)}
                placeholder="Ví dụ: Mẹ tôi cần người đồng hành vài buổi chiều mỗi tuần…"
                rows={4}
                value={message}
              />
              <div className="ai-assistant__form-footer">
                <span>{message.length}/1200</span>
                <button className="button button--primary" disabled={loading || message.trim().length < 8} type="submit">
                  {loading ? <LoaderCircle className="spin" size={17} aria-hidden="true" /> : <ArrowUpRight size={17} aria-hidden="true" />}
                  {loading ? "Đang suy nghĩ" : "Nhận gợi ý"}
                </button>
              </div>
            </form>
            {error ? <p className="ai-assistant__error" role="alert">{error}</p> : null}
            {recommendation ? (
              <div className="ai-assistant__result" aria-live="polite">
                <span className="ai-assistant__result-label">Gợi ý ban đầu</span>
                <h3>{recommendation.serviceCategory}</h3>
                <p>{recommendation.summary}</p>
                <div className="ai-assistant__result-meta">
                  <span>Dự kiến {recommendation.hours} giờ</span>
                  <span>{recommendation.nextStep}</span>
                </div>
                <button
                  className="button button--primary button--wide"
                  onClick={() => onOpenBooking(undefined, recommendation.serviceCategory)}
                  type="button"
                >
                  Tiếp tục đặt ca
                  <ArrowUpRight size={17} aria-hidden="true" />
                </button>
              </div>
            ) : null}
          </section>
        </div>
      ) : null}
    </>
  );
}
