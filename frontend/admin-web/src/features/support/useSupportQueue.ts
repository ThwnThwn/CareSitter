import { useCallback, useEffect, useRef, useState } from 'react';
import { supportChatApi, type ChatConversation } from './supportChatApi';
import { useSupportRefresh } from './useSupportRefresh';

type Cursor = { createdAt: string; id: string };
type QueuePage = Awaited<ReturnType<typeof supportChatApi.list>>;
type QueueSnapshot = { items: ChatConversation[]; cursor?: Cursor; pages: number };
const emptyQueue: QueueSnapshot = { items: [], pages: 0 };

function nextCursor(page: QueuePage): Cursor | undefined {
  if (page.hasMore && page.nextCreatedAt && page.nextId) {
    return { createdAt: page.nextCreatedAt, id: page.nextId };
  }
}

export function useSupportQueue(queue: string) {
  const [enabled, setEnabled] = useState<boolean | null>(null);
  const [data, setData] = useState(emptyQueue);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const snapshot = useRef(emptyQueue);
  const appendRequested = useRef(false);

  useEffect(() => {
    snapshot.current = emptyQueue;
    appendRequested.current = false;
    setData(emptyQueue);
    setError('');
    setLoading(true);
  }, [queue]);

  const load = useCallback(async (signal: AbortSignal) => {
    setLoading(true);
    const append = appendRequested.current;
    appendRequested.current = false;
    try {
      const current = snapshot.current;
      const items = new Map<string, ChatConversation>();
      let cursor = append ? current.cursor : undefined;
      let pages = append ? current.pages : 0;
      if (append) {
        if (!cursor) return;
        for (const item of current.items) items.set(item.id, item);
      } else {
        const config = await supportChatApi.config(signal);
        if (signal.aborted) return;
        setEnabled(config.enabled);
        if (!config.enabled) {
          snapshot.current = emptyQueue;
          setData(emptyQueue);
          setError('');
          return;
        }
      }
      const count = append ? 1 : Math.max(1, current.pages);
      for (let index = 0; index < count; index++) {
        const page = await supportChatApi.list(queue, cursor, signal);
        if (signal.aborted) return;
        for (const item of page.items) items.set(item.id, item);
        pages++;
        cursor = nextCursor(page);
        if (!cursor) break;
      }
      const result = { items: [...items.values()], cursor, pages };
      snapshot.current = result;
      setData(result);
      setError('');
    } catch (cause) {
      if (!signal.aborted) setError(cause instanceof Error ? cause.message : 'Không tải được hàng đợi.');
    } finally {
      if (!signal.aborted) setLoading(false);
    }
  }, [queue]);

  const refresh = useSupportRefresh(load);

  function loadMore() {
    if (!snapshot.current.cursor) return;
    appendRequested.current = true;
    refresh();
  }

  return { enabled, items: data.items, hasMore: !!data.cursor, error, loading, refresh, loadMore };
}
