import { useEffect, useRef, useState } from 'react';
import { TOKEN_KEY } from '../api';

export function useAdminMutation<Action extends string>() {
  const [busy, setBusy] = useState<Action | ''>('');
  const [error, setError] = useState('');
  const active = useRef<AbortController | null>(null);
  const mounted = useRef(true);
  useEffect(() => {
    mounted.current = true;
    return () => { mounted.current = false; active.current?.abort(); };
  }, []);

  async function run(action: Action, request: (signal: AbortSignal) => Promise<unknown>,
    fallback: string, onSuccess: () => void, onFailure?: () => void) {
    // A ref also blocks a second click before React renders the disabled button.
    if (active.current || !mounted.current) return false;
    const controller = new AbortController();
    const token = sessionStorage.getItem(TOKEN_KEY);
    active.current = controller;
    setBusy(action); setError('');
    const current = () => mounted.current && !controller.signal.aborted
      && sessionStorage.getItem(TOKEN_KEY) === token;
    try {
      await request(controller.signal);
      if (!current()) return false;
      onSuccess();
      return true;
    } catch (cause) {
      if (current()) {
        setError(cause instanceof Error ? cause.message : fallback);
        onFailure?.();
      }
      return false;
    } finally {
      if (active.current === controller) {
        active.current = null;
        if (mounted.current && !controller.signal.aborted) setBusy('');
      }
    }
  }
  return { busy, error, setError, run };
}
