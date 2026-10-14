"use client";
import { useRef, useState, type FormEvent } from "react";
import { ConsultationSubmission } from "./client";
import { consultationServices, parseConsultation, vietnamToday, type ConsultationReceipt } from "./contract";

interface Props {
  caregiverName: string;
  serviceCategory: string;
  onSaved: (receipt: ConsultationReceipt) => void;
}

export default function ConsultationForm({ caregiverName, serviceCategory, onSaved }: Props) {
  const [selectedService, setSelectedService] = useState(
    consultationServices.find((item) => item.label === serviceCategory)?.value ?? "elderly_care");
  const [pending, setPending] = useState(false);
  const [error, setError] = useState("");
  const submission = useRef<ConsultationSubmission | null>(null);
  const locked = useRef(false);
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (locked.current) return;
    const form = new FormData(event.currentTarget);
    const draft = parseConsultation({
      contactName: form.get("contactName"), phone: form.get("phone"),
      serviceCategory: selectedService, preferredDate: form.get("preferredDate"),
      hours: Number(form.get("hours")), caregiverPreference: caregiverName,
      note: form.get("note"), consent: form.get("consent") === "on",
    });
    if (!draft) { setError("Vui lòng kiểm tra thông tin liên hệ và nhu cầu tư vấn."); return; }
    locked.current = true;
    setPending(true);
    setError("");
    try {
      if (!submission.current) {
        let storage: Storage | undefined;
        try { storage = window.sessionStorage; } catch { /* Optional retry persistence. */ }
        submission.current = new ConsultationSubmission(fetch, storage);
      }
      onSaved(await submission.current.submit(draft));
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "Chưa gửi được yêu cầu. Vui lòng thử lại.");
    } finally { locked.current = false; setPending(false); }
  }
  return <form className="booking-form" onSubmit={submit} aria-busy={pending}>
    <fieldset disabled={pending}>
      <legend>Thông tin liên hệ</legend>
      <div className="booking-form__row">
        <label>Họ và tên<input name="contactName" autoComplete="name" required minLength={2} maxLength={120} /></label>
        <label>Số điện thoại<input name="phone" type="tel" inputMode="tel" autoComplete="tel" required maxLength={24} /></label>
      </div>
    </fieldset>
    <fieldset disabled={pending}>
      <legend>Loại hỗ trợ</legend>
      <div className="service-options">{consultationServices.map((service) =>
        <button type="button" key={service.value}
          aria-pressed={selectedService === service.value}
          className={"service-option" + (selectedService === service.value ? " service-option--selected" : "")}
          onClick={() => setSelectedService(service.value)}>{service.label}</button>)}</div>
      <div className="booking-form__row">
        <label>Ngày dự kiến<input name="preferredDate" min={vietnamToday()} defaultValue={vietnamToday()} required type="date" /></label>
        <label>Thời lượng<select name="hours" defaultValue="4">
          {[2, 4, 8, 12].map((hours) => <option key={hours} value={hours}>{hours} giờ</option>)}
        </select></label>
      </div>
      <label>Ghi chú (không bắt buộc)<textarea name="note" maxLength={1000} rows={2}
        placeholder="Khu vực và thời gian thuận tiện để tư vấn" /></label>
      <label className="consultation-consent">
        <input name="consent" type="checkbox" required />
        <span>Tôi đồng ý để CareSitter sử dụng thông tin trên để liên hệ tư vấn về yêu cầu này.</span>
      </label>
    </fieldset>
    <p className="consultation-help">CareSitter sẽ xác nhận dịch vụ, người chăm sóc và mức phí khi tư vấn.</p>
    {error && <p className="consultation-error" role="alert">{error}</p>}
    <button className="button button--primary button--wide" disabled={pending} type="submit">
      {pending ? "Đang gửi yêu cầu…" : error ? "Gửi lại yêu cầu tư vấn" : "Gửi yêu cầu tư vấn"}
    </button>
  </form>;
}
