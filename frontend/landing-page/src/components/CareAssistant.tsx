"use client";

import { ArrowUpRight, Bot, LoaderCircle, Sparkles, X } from "lucide-react";
import { FormEvent, useEffect, useRef, useState } from "react";
import { useCareAssistant } from "@/features/care-assistant/useCareAssistant";

interface CareAssistantProps {
  onOpenBooking: (caregiver?: string, service?: string) => void;
}

const examples = [
  "CareSitter hoạt động như thế nào?",
  "Mẹ tôi cần người ở cùng và hỗ trợ bữa ăn buổi sáng.",
  "Tôi cần người đưa bố đi khám và hỗ trợ di chuyển.",
];

export default function CareAssistant({ onOpenBooking }: CareAssistantProps) {
  const [open, setOpen] = useState(false);
  const [message, setMessage] = useState("");
  const resultRef = useRef<HTMLDivElement>(null);
  const { reply, error, loading, submit: requestSuggestion, cancel } = useCareAssistant();
  const close = () => { cancel(); setOpen(false); };

  useEffect(() => {
    if (!reply) return;
    const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    resultRef.current?.scrollIntoView({ behavior: reduceMotion ? "auto" : "smooth", block: "nearest" });
  }, [reply]);

  const submit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (message.trim().length < 3 || loading) return;

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
                <h2 id="care-assistant-title">Hỏi mình về CareSitter.</h2>
              </div>
            </div>
            <p className="ai-assistant__intro">
              Bạn có thể hỏi CareSitter hoạt động thế nào, quy trình đặt ca ra sao hoặc mô tả nhu cầu của gia đình.
              Mình sẽ giải thích và gợi ý bước tiếp theo, không thay thế tư vấn y khoa.
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
                placeholder="Ví dụ: CareSitter chọn caregiver thế nào?"
                rows={4}
                value={message}
              />
              <div className="ai-assistant__form-footer">
                <span>{message.length}/1200</span>
                <button className="button button--primary" disabled={loading || message.trim().length < 3} type="submit">
                  {loading ? <LoaderCircle className="spin" size={17} aria-hidden="true" /> : <ArrowUpRight size={17} aria-hidden="true" />}
                  {loading ? "Đang suy nghĩ" : "Nhận gợi ý"}
                </button>
              </div>
            </form>
            {error ? <p className="ai-assistant__error" role="alert">{error}</p> : null}
            {reply ? (
              <div className={`ai-assistant__result ai-assistant__result--${reply.intent}`} aria-live="polite" ref={resultRef}>
                <span className="ai-assistant__result-label">
                  {reply.intent === "recommendation" ? "Gợi ý phù hợp" :
                    reply.intent === "explanation" ? "CareSitter giải thích" : "Mình cần bạn nói rõ hơn"}
                </span>
                <h3>{reply.title}</h3>
                <p>{reply.summary}</p>
                <div className="ai-assistant__result-meta">
                  {reply.intent === "recommendation" ? <span>Dự kiến {reply.hours} giờ</span> : null}
                  <span>{reply.nextStep}</span>
                </div>
                {reply.intent !== "clarification" ? (
                  <button
                    className="button button--primary button--wide"
                    onClick={() => onOpenBooking(undefined,
                      reply.intent === "recommendation" ? reply.serviceCategory : undefined)}
                    type="button"
                  >
                    {reply.intent === "recommendation" ? "Tiếp tục đặt ca" : "Đăng ký tư vấn"}
                    <ArrowUpRight size={17} aria-hidden="true" />
                  </button>
                ) : null}
              </div>
            ) : null}
          </section>
        </div>
      ) : null}
    </>
  );
}
