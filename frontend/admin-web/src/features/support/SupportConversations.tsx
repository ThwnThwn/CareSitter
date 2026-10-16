import { useCallback, useEffect, useRef, useState } from 'react';
import { HubConnectionBuilder } from '@microsoft/signalr';
import { useAdminMetadata } from '../../adminMetadata';
import { API_BASE, TOKEN_KEY } from '../../api';
import { EmptyState, ErrorBanner, PageHeader, StatusChip, formatDate, shortId } from '../../components/Common';
import { ChatConversation, ChatMessage, supportChatApi } from './supportChatApi';

const queues = [
  { value: 'new', label: 'Chưa nhận' },
  { value: 'mine', label: 'Của tôi' },
  { value: 'active', label: 'Đang xử lý' },
  { value: 'closed', label: 'Đã kết thúc' },
];

export function SupportConversations() {
  const { currentUser } = useAdminMetadata();
  const [enabled, setEnabled] = useState<boolean | null>(null);
  const [queue, setQueue] = useState('new');
  const [items, setItems] = useState<ChatConversation[]>([]);
  const [cursor, setCursor] = useState<{ createdAt: string; id: string } | null>(null);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [detail, setDetail] = useState<ChatConversation | null>(null);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [draft, setDraft] = useState('');
  const [pendingKey, setPendingKey] = useState<string | null>(null);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const [loading, setLoading] = useState(true);
  const lastSequence = useRef(0);
  const messageList = useRef<HTMLDivElement>(null);
  const lastReadRequested = useRef(0);
  const refreshInFlight = useRef<Promise<void> | null>(null);

  const refresh = useCallback(async () => {
    if (refreshInFlight.current) await refreshInFlight.current;
    const task = (async () => {
      try {
      const config = await supportChatApi.config();
      setEnabled(config.enabled);
      if (!config.enabled) { setItems([]); setDetail(null); return; }
      const list = await supportChatApi.list(queue);
      setItems(list.items);
      setCursor(list.hasMore && list.nextCreatedAt && list.nextId
        ? { createdAt: list.nextCreatedAt, id: list.nextId } : null);
      if (selectedId) {
        const conversation = await supportChatApi.get(selectedId);
        setDetail(conversation);
        // Poll even while a socket is connected: missing realtime events cannot leave a gap.
        let after = lastSequence.current;
        let watermark: number | undefined;
        const incoming: ChatMessage[] = [];
        for (let pageIndex = 0; pageIndex < 100; pageIndex++) {
          const page = await supportChatApi.messages(selectedId, after, watermark);
          watermark ??= page.highWatermarkSequence;
          incoming.push(...page.items);
          after = page.nextAfterSequence ?? after;
          if (!page.hasMore) break;
        }
        if (incoming.length) {
          setMessages(previous => [...previous, ...incoming].filter((message, index, all) =>
            all.findIndex(item => item.sequence === message.sequence) === index));
          lastSequence.current = after;
        }
      }
      setError('');
      } catch (cause) {
        setError(cause instanceof Error ? cause.message : 'Không tải được hội thoại.');
      } finally {
        setLoading(false);
      }
    })();
    refreshInFlight.current = task;
    try { await task; }
    finally { if (refreshInFlight.current === task) refreshInFlight.current = null; }
  }, [queue, selectedId, currentUser.id]);

  const markVisibleRead = useCallback(() => {
    const element = messageList.current;
    if (!element || !detail || detail.assignedAdminId !== currentUser.id ||
        messages.length === 0 ||
        element.scrollHeight - element.scrollTop - element.clientHeight > 24) return;
    const sequence = messages[messages.length - 1].sequence;
    if (sequence <= Math.max(detail.ownLastReadSequence, lastReadRequested.current)) return;
    lastReadRequested.current = sequence;
    void supportChatApi.read(detail.id, sequence).catch(() => {
      lastReadRequested.current = 0;
    });
  }, [currentUser.id, detail, messages]);

  useEffect(() => { markVisibleRead(); }, [markVisibleRead]);

  useEffect(() => {
    void refresh();
    const timer = window.setInterval(() => void refresh(), 15_000);
    return () => window.clearInterval(timer);
  }, [refresh]);

  useEffect(() => {
    if (!enabled || !sessionStorage.getItem(TOKEN_KEY)) return;
    let cancelled = false;
    const connection = new HubConnectionBuilder()
      .withUrl(`${API_BASE}/hubs/support-chat`, {
        accessTokenFactory: () => sessionStorage.getItem(TOKEN_KEY) ?? '',
      }).withAutomaticReconnect().build();
    for (const event of ['AdminQueueChanged', 'ConversationChanged', 'MessageCreated']) {
      connection.on(event, () => { if (!cancelled) void refresh(); });
    }
    connection.onreconnected(() => {
      if (cancelled) return;
      if (selectedId) void connection.invoke('JoinConversation', selectedId).catch(() => {});
      void refresh();
    });
    void connection.start().then(async () => {
      if (cancelled) return;
      if (selectedId) await connection.invoke('JoinConversation', selectedId);
      await refresh();
    }).catch(() => { /* Polling remains the recovery path. */ });
    return () => { cancelled = true; void connection.stop(); };
  }, [enabled, selectedId, refresh]);

  function open(id: string) {
    setSelectedId(id);
    setDetail(null);
    setMessages([]);
    lastSequence.current = 0;
    lastReadRequested.current = 0;
    setError('');
  }

  async function act(operation: () => Promise<unknown>) {
    if (busy) return;
    setBusy(true);
    try { await operation(); setError(''); await refresh(); }
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

  async function loadMore() {
    if (!cursor) return;
    try {
      const page = await supportChatApi.list(queue, cursor);
      setItems(previous => [...previous, ...page.items]);
      setCursor(page.hasMore && page.nextCreatedAt && page.nextId
        ? { createdAt: page.nextCreatedAt, id: page.nextId } : null);
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Không tải thêm được.'); }
  }

  return <>
    <PageHeader title="Chat hỗ trợ" description="Tin nhắn được lưu trên máy chủ; danh sách tự đồng bộ mỗi 15 giây."
      actions={<button className="secondary" onClick={() => void refresh()}>Làm mới</button>} />
    {error && <ErrorBanner message={error} onRetry={() => void refresh()} />}
    {enabled === false ? <EmptyState title="Chat hỗ trợ đang tắt" description="Tiếp tục xử lý yêu cầu qua ticket." /> : <>
      <section className="filter-bar"><label>Hàng đợi <select value={queue} onChange={event => {
        setQueue(event.target.value); setCursor(null); setItems([]);
      }}>{queues.map(item => <option key={item.value} value={item.value}>{item.label}</option>)}</select></label></section>
      <section className="data-panel">
        {loading ? <p>Đang tải hội thoại…</p> : items.length === 0 ?
          <EmptyState title="Chưa có hội thoại" description="Hội thoại mới sẽ xuất hiện tại đây." /> :
          <div className="table-wrap"><table className="data-table"><thead><tr>
            <th>Chủ đề</th><th>Người gửi</th><th>Ngày tạo</th><th>Trạng thái</th><th>Chưa đọc</th><th />
          </tr></thead><tbody>{items.map(item => <tr key={item.id}>
            <td><strong>{item.subject}</strong><small>{shortId(item.id)}</small></td>
            <td>{shortId(item.ownerUserId)}</td><td>{formatDate(item.createdAt)}</td>
            <td><StatusChip value={item.status} /></td><td>{item.unreadCount}</td>
            <td><button className="row-action" onClick={() => open(item.id)}>Mở chat</button></td>
          </tr>)}</tbody></table></div>}
        {cursor && <button className="secondary" onClick={() => void loadMore()}>Tải thêm</button>}
      </section>
      {selectedId && <section className="data-panel" aria-label="Chi tiết hội thoại">
        <button className="secondary" onClick={() => setSelectedId(null)}>Đóng chi tiết</button>
        {!detail ? <p>Đang tải tin nhắn…</p> : <>
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
            <label>Tin nhắn <textarea value={draft} maxLength={2000} onChange={event => {
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
      </section>}
    </>}
  </>;
}
