"use client";
import { Check, ShieldCheck, X } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import ConsultationForm from "@/features/consultation/ConsultationForm";
import type { ConsultationReceipt } from "@/features/consultation/contract";

interface QuickBookModalProps {
  isOpen: boolean;
  onClose: () => void;
  caregiverName?: string;
  serviceCategory?: string;
}

export default function QuickBookModal({
  isOpen, onClose, caregiverName = "Chuyên viên CareSitter",
  serviceCategory = "Chăm sóc người cao tuổi",
}: QuickBookModalProps) {
  const [receipt, setReceipt] = useState<ConsultationReceipt | null>(null);
  const dialog = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    if (!isOpen) return;
    const previousOverflow = document.body.style.overflow;
    const previousFocus = document.activeElement;
    const element = dialog.current;
    document.body.style.overflow = "hidden";
    element?.showModal();
    return () => {
      element?.close();
      document.body.style.overflow = previousOverflow;
      if (previousFocus instanceof HTMLElement) previousFocus.focus();
    };
  }, [isOpen]);
  if (!isOpen) return null;
  return <dialog ref={dialog} className="booking-modal consultation-dialog"
    aria-labelledby="booking-title" onCancel={onClose}>
    <button aria-label="Đóng cửa sổ tư vấn" className="modal-close" onClick={onClose} type="button">
      <X size={20} />
    </button>
    {receipt ? <div className="booking-success" aria-live="polite">
      <span><Check size={30} aria-hidden="true" /></span>
      <h2 id="booking-title">Đã lưu yêu cầu tư vấn</h2>
      <p>CareSitter sẽ liên hệ theo số điện thoại bạn cung cấp để xác nhận nhu cầu.
        Lịch chăm sóc sẽ được thống nhất sau khi tư vấn.</p>
      <p className="consultation-reference">Mã yêu cầu: {receipt.id}</p>
      <button className="button button--primary" onClick={onClose}>Hoàn tất</button>
    </div> : <>
      <header className="booking-modal__header">
        <span><ShieldCheck size={16} aria-hidden="true" />Đăng ký tư vấn</span>
        <h2 id="booking-title">Cho CareSitter biết gia đình cần gì</h2>
        <p>Người chăm sóc bạn quan tâm: <strong>{caregiverName}</strong></p>
      </header>
      <ConsultationForm caregiverName={caregiverName} serviceCategory={serviceCategory} onSaved={setReceipt} />
    </>}
  </dialog>;
}
