import { useCallback, useEffect, useRef, useState } from 'react';
import { useAdminMetadata } from '../../adminMetadata';
import { ErrorBanner, formatDate, shortId } from '../../components/Common';
import { ChatConversation, ChatMessage, supportChatApi } from './supportChatApi';
import { useSupportRefresh } from './useSupportRefresh';

type Props = {
  id: string;
  revision: number;
  onClose: () => void;
  onQueueRefresh: () => void;
};

export function SupportConversationDetail({ id, revision, onClose, onQueueRefresh }: Props) {
  const { currentUser } = useAdminMetadata();
  const [detail, setDetail] = useState<ChatConversation | null>(null);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [draft, setDraft] = useState('');
  const [pendingKey, setPendingKey] = useState<string | null>(null);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const lastSequence = useRef(0);
  const messageList = useRef<HTMLDivElement>(null);
  const lastReadRequested = useRef(0);

  const load = useCallback(async (signal: AbortSignal) => {
    try {
      const conversation = await supportChatApi.get(id, signal);
      if (signal.aborted) return;
      setDetail(conversation);
      let after = lastSequence.current;
      let watermark: number | undefined;
      for (let pageIndex = 0; pageIndex < 100; pageIndex++) {
        const page = await supportChatApi.messages(id, after, watermark, signal);
        if (signal.aborted) return;
        if (page.items.length) {
          lastSequence.current = page.items[page.items.length - 1].sequence;
          setMessages(previous => [...previous, ...page.items]);
        }
        if (!page.hasMore || page.nextAfterSequence == null || page.nextAfterSequence <= after) break;
        after = page.nextAfterSequence;
        watermark ??= page.highWatermarkSequence;
      }
      setError('');
    } catch (cause) {
      if (!signal.aborted) setError(cause instanceof Error ? cause.message : 'Không tải được hội thoại.');
    }
  }, [id]);

  const refresh = useSupportRefresh(load);
  const lastRevision = useRef(revision);
  useEffect(() => {
    if (lastRevision.current === revision) return;
    lastRevision.current = revision;
    refresh();
  }, [refresh, revision]);

  const markVisibleRead = useCallback(() => {
    const element = messageList.current;
    if (!element || !detail || detail.assignedAdminId !== currentUser.id ||
        messages.length === 0 ||
        element.scrollHeight - element.scrollTop - element.clientHeight > 24) return;
    const sequence = messages[messages.length - 1].sequence;
    if (sequence <= Math.max(detail.ownLastReadSequence, lastReadRequested.current)) return;
    lastReadRequested.current = sequence;
    void supportChatApi.read(detail.id, sequence).then(onQueueRefresh).catch(() => {
      if (lastReadRequested.current === sequence) lastReadRequested.current = 0;
    });
  }, [currentUser.id, detail, messages, onQueueRefresh]);

  useEffect(() => { markVisibleRead(); }, [markVisibleRead]);

  async function act(operation: () => Promise<unknown>) {
    if (busy) return;
    setBusy(true);
    try {
      await operation();
      setError('');
      refresh();
      onQueueRefresh();
    }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Thao tác thất bại.'); }
    finally { setBusy(false); }
  }

  async function send() {
    if (!detail || !draft.trim() || busy) return;
    const body = draft.trim();
    const key = pendingKey ?? crypto.randomUUID();
    setPendingKey(key);
    await act(async () => {
      await supportChatApi.send(detail.id, body, key);
      setDraft(''); setPendingKey(null);
    });
  }

  return <section className="data-panel" aria-label="Chi tiết hội thoại">
    <button className="secondary" onClick={onClose}>Đóng chi tiết</button>
    {error && <ErrorBanner message={error} onRetry={refresh} />}
    {!detail ? (!error && <p>Đang tải tin nhắn…</p>) : <>
      <h2>{detail.subject}</h2>
      <p>Trạng thái: {detail.status} · Phụ trách: {detail.assignedAdminId ? shortId(detail.assignedAdminId) : 'Chưa nhận'}</p>
      <div ref={messageList} aria-live="polite" onScroll={markVisibleRead}
        style={{ maxHeight: 420, overflowY: 'auto', padding: 12 }}>
        {messages.length === 0 ? <p>Chưa có tin nhắn.</p> : messages.map(message =>
          <p key={message.id}><strong>{message.senderRole === 'ADMIN' ? 'CareSitter' : 'Người gửi'}</strong>
            {' · '}{formatDate(message.createdAt)}<br />{message.body}</p>)}
      </div>
      {detail.status === 'NEW' && <button disabled={busy} onClick={() => void act(() =>
        supportChatApi.claim(detail.id, detail.ticketVersion))}>Nhận xử lý</button>}
      {detail.status === 'IN_PROGRESS' && detail.assignedAdminId === currentUser.id && <>
        <label>Tin nhắn <textarea disabled={busy} value={draft} maxLength={2000} onChange={event => {
          setDraft(event.target.value); setPendingKey(null);
        }} /></label>
        <button disabled={busy || !draft.trim()} onClick={() => void send()}>Gửi phản hồi</button>
        <button className="secondary" disabled={busy} onClick={() => {
          const target = window.prompt('ID Admin nhận bàn giao');
          const reason = window.prompt('Lý do bàn giao');
          if (target && reason) void act(() => supportChatApi.transfer(detail.id, target, false,
            detail.ticketVersion, reason));
        }}>Chuyển người phụ trách</button>
      </>}
      {detail.status === 'IN_PROGRESS' && detail.assignedAdminId !== currentUser.id &&
        <button className="secondary" disabled={busy} onClick={() => {
          const reason = window.prompt('Lý do tiếp quản');
          if (reason) void act(() => supportChatApi.transfer(detail.id, currentUser.id, true,
            detail.ticketVersion, reason));
        }}>Tiếp quản</button>}
      {((detail.status === 'IN_PROGRESS' && detail.assignedAdminId === currentUser.id) ||
        detail.status === 'NEW' || (detail.status === 'RESOLVED' && detail.assignedAdminId === currentUser.id)) &&
        <button className="secondary" disabled={busy} onClick={() => {
          const reason = window.prompt('Kết quả hoặc lý do kết thúc');
          if (reason) void act(() => supportChatApi.status(detail.id,
            detail.status === 'NEW' || detail.status === 'RESOLVED' ? 'CLOSED' : 'RESOLVED',
            detail.ticketVersion, reason));
        }}>{detail.status === 'IN_PROGRESS' ? 'Đã giải quyết' : 'Đóng hội thoại'}</button>}
    </>}
  </section>;
}
