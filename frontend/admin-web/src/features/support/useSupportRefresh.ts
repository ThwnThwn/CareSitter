import { useCallback, useEffect, useRef } from 'react';

// Finish the running read before processing the latest invalidation.
export function useSupportRefresh(load: (signal: AbortSignal) => Promise<void>) {
  const request = useRef<(() => void) | null>(null);

  useEffect(() => {
    const controller = new AbortController();
    let running = false;
    let pending = false;

    function refresh() {
      pending = true;
      if (running || controller.signal.aborted) return;
      void drain();
    }

    async function drain() {
      running = true;
      try {
        while (pending && !controller.signal.aborted) {
          pending = false;
          await load(controller.signal);
        }
      } finally {
        running = false;
      }
    }

    request.current = refresh;
    refresh();
    return () => {
      request.current = null;
      controller.abort();
    };
  }, [load]);

  return useCallback(() => request.current?.(), []);
}
