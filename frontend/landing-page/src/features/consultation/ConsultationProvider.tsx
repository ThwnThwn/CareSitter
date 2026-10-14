"use client";
import { createContext, useCallback, useContext, useState, type ReactNode } from "react";
import QuickBookModal from "@/components/QuickBookModal";

type OpenConsultation = (caregiver?: string, service?: string) => void;
const ConsultationContext = createContext<OpenConsultation | null>(null);

export function useConsultation() {
  const open = useContext(ConsultationContext);
  if (!open) throw new Error("ConsultationProvider is required.");
  return open;
}

export default function ConsultationProvider({ children }: { children: ReactNode }) {
  const [selection, setSelection] = useState<{ caregiver?: string; service?: string } | null>(null);
  const open = useCallback<OpenConsultation>((caregiver, service) => {
    setSelection({ caregiver, service });
  }, []);
  return <ConsultationContext value={open}>
    {children}
    {selection && <QuickBookModal isOpen caregiverName={selection.caregiver}
      serviceCategory={selection.service} onClose={() => setSelection(null)} />}
  </ConsultationContext>;
}
