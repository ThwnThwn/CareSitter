import { DataRow, DataTable } from '../../components/DataTable';
import { useCallback, useEffect, useRef, useState } from 'react';
import { HubConnectionBuilder } from '@microsoft/signalr';
import { API_BASE, TOKEN_KEY } from '../../api';
import { EmptyState, ErrorBanner, SectionTitle, StatusChip, formatDate, shortId } from '../../components/Common';
import { useSupportQueue } from './useSupportQueue';
import { SupportConversationDetail } from './SupportConversationDetail';

const queues = [
  { value: 'new', label: 'Chưa nhận' },
  { value: 'mine', label: 'Của tôi' },
  { value: 'active', label: 'Đang xử lý' },
  { value: 'closed', label: 'Đã kết thúc' },
];

export function SupportConversations() {
  const [queue, setQueue] = useState('new');
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const activeId = useRef<string | null>(null);
  const [conversationRevision, setConversationRevision] = useState(0);
  const { enabled, items, hasMore, error, loading, refresh: refreshQueue, loadMore } = useSupportQueue(queue);

  const refreshConversation = useCallback(() => setConversationRevision(value => value + 1), []);
  const refresh = useCallback(() => {
    refreshQueue();
    refreshConversation();
  }, [refreshQueue, refreshConversation]);

  function selectConversation(id: string | null) {
    activeId.current = id;
    setSelectedId(id);
  }

  useEffect(() => {
    if (enabled === false) selectConversation(null);
  }, [enabled]);

  useEffect(() => {
    const timer = window.setInterval(refresh, 15_000);
    return () => window.clearInterval(timer);
  }, [refresh]);

  useEffect(() => {
    if (!enabled || !sessionStorage.getItem(TOKEN_KEY)) return;
    let cancelled = false;
    let queueTimer: number | undefined;
    const connection = new HubConnectionBuilder()
      .withUrl(`${API_BASE}/hubs/support-chat`, {
        accessTokenFactory: () => sessionStorage.getItem(TOKEN_KEY) ?? '',
      }).withAutomaticReconnect().build();

    connection.on('AdminQueueChanged', (event: { conversationId: string }) => {
      if (cancelled) return;
      if (queueTimer === undefined) {
        queueTimer = window.setTimeout(() => {
          queueTimer = undefined;
          refreshQueue();
        }, 750);
      }
      if (event.conversationId === activeId.current) refreshConversation();
    });
    connection.onreconnected(() => { if (!cancelled) refresh(); });
    void connection.start()
      .then(() => { if (!cancelled) refresh(); })
      .catch(() => { /* Polling remains the recovery path. */ });
    return () => {
      cancelled = true;
      window.clearTimeout(queueTimer);
      void connection.stop();
    };
  }, [enabled, refresh, refreshConversation, refreshQueue]);

  function changeQueue(value: string) {
    selectConversation(null);
    setQueue(value);
  }

  return <>
    <SectionTitle title="Chat hỗ trợ" description="Tin nhắn được lưu trên máy chủ; danh sách tự đồng bộ mỗi 15 giây."
      action={<button className="secondary" onClick={() => void refresh()}>Làm mới</button>} />
    {error && <ErrorBanner message={error} onRetry={() => void refresh()} />}
    {enabled === false ? <EmptyState title="Chat hỗ trợ đang tắt" description="Tiếp tục xử lý yêu cầu qua ticket." /> : <>
      <section className="filter-bar"><label>Hàng đợi <select value={queue} onChange={event => changeQueue(event.target.value)}>{queues.map(item => <option key={item.value} value={item.value}>{item.label}</option>)}</select></label></section>
      <section className="data-panel">
        {loading && !items.length ? <p>Đang tải hội thoại…</p> : items.length === 0 ?
          <EmptyState title="Chưa có hội thoại" description="Hội thoại mới sẽ xuất hiện tại đây." /> :
          <div className="table-wrap"><DataTable columns={['Chủ đề', 'Người gửi', 'Ngày tạo', 'Trạng thái', 'Chưa đọc', '']}>{items.map(item => <DataRow key={item.id}>
            <td><strong>{item.subject}</strong><small>{shortId(item.id)}</small></td>
            <td>{shortId(item.ownerUserId)}</td><td>{formatDate(item.createdAt)}</td>
            <td><StatusChip value={item.status} /></td><td>{item.unreadCount}</td>
            <td><button className="row-action" onClick={() => selectConversation(item.id)}>Mở chat</button></td>
          </DataRow>)}</DataTable></div>}
        {hasMore && <button className="secondary" disabled={loading} onClick={loadMore}>Tải thêm</button>}
      </section>
      {enabled && selectedId && <SupportConversationDetail key={selectedId} id={selectedId} revision={conversationRevision}
        onClose={() => selectConversation(null)} onQueueRefresh={refreshQueue} />}
    </>}
  </>;
}
