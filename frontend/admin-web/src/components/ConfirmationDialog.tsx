import { createContext, ReactNode, useCallback, useContext, useEffect, useRef, useState } from 'react';
import { AlertTriangle } from 'lucide-react';

type ConfirmationOptions = {
  title: string;
  message: string;
  confirmLabel: string;
  tone?: 'danger' | 'primary';
};

type PendingConfirmation = ConfirmationOptions & { resolve: (value: boolean) => void };
type Confirm = (options: ConfirmationOptions) => Promise<boolean>;

const ConfirmationContext = createContext<Confirm>(async ({ title, message }) => window.confirm(`${title} ${message}`));

export function ConfirmationProvider({ children }: { children: ReactNode }) {
  const [pending, setPending] = useState<PendingConfirmation | null>(null);
  const cancelButton = useRef<HTMLButtonElement>(null);
  const confirm = useCallback<Confirm>((options) => new Promise((resolve) => setPending({ ...options, resolve })), []);
  const close = useCallback((value: boolean) => {
    setPending((current) => {
      current?.resolve(value);
      return null;
    });
  }, []);

  useEffect(() => {
    if (!pending) return;
    cancelButton.current?.focus();
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') close(false);
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [pending, close]);

  return <ConfirmationContext.Provider value={confirm}>
    {children}
    {pending && <div className="confirmation-backdrop" onMouseDown={(event) => {
      if (event.target === event.currentTarget) close(false);
    }}>
      <section className="confirmation-dialog" role="alertdialog" aria-modal="true" aria-labelledby="confirmation-title" aria-describedby="confirmation-message">
        <span className={`confirmation-icon confirmation-icon--${pending.tone ?? 'danger'}`}><AlertTriangle size={22} /></span>
        <div>
          <h2 id="confirmation-title">{pending.title}</h2>
          <p id="confirmation-message">{pending.message}</p>
        </div>
        <div className="confirmation-actions">
          <button ref={cancelButton} className="secondary" onClick={() => close(false)}>Quay lại</button>
          <button className={pending.tone === 'primary' ? 'primary' : 'danger'} onClick={() => close(true)}>{pending.confirmLabel}</button>
        </div>
      </section>
    </div>}
  </ConfirmationContext.Provider>;
}

export const useConfirmation = () => useContext(ConfirmationContext);
