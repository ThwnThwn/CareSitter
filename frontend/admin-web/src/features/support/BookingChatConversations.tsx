import { useCallback, useEffect, useState } from 'react';
import { RefreshCw } from 'lucide-react';
import { DetailList, EmptyState, ErrorBanner, LoadingTable, PageHeader, formatDate, shortId } from '../../components/Common';
import type { BookingChatAdminActivity, BookingChatAdminDetail, BookingChatAdminFilter, BookingChatAdminItem, BookingChatAdminMessage } from '../../types';
import { bookingChatAdminApi } from './bookingChatAdminApi';

export function BookingChatConversations() {
  const [items, setItems] = useState<BookingChatAdminItem[]>([]);
  const [selected, setSelected] = useState<BookingChatAdminDetail | null>(null);
  const [messages, setMessages] = useState<BookingChatAdminMessage[]>([]);
  const [activity, setActivity] = useState<BookingChatAdminActivity[]>([]);
  const [currentCursor, setCurrentCursor] = useState<string | null>(null);
  const [cursorHistory, setCursorHistory] = useState<Array<string | null>>([]);
  const [nextCursor, setNextCursor] = useState<string | null>(null);
  const [nextMessageSequence, setNextMessageSequence] = useState<number | null>(null);
  const [nextActivityCursor, setNextActivityCursor] = useState<string | null>(null);
  const [readReason, setReadReason] = useState('');
  const [ticketId, setTicketId] = useState('');
  const [actionReason, setActionReason] = useState('');
  const [actionConfirmed, setActionConfirmed] = useState(false);
  const [filter, setFilter] = useState<BookingChatAdminFilter>({});
  const [filterDraft, setFilterDraft] = useState({
    reported: '', blocked: '', deadLetter: '', bookingId: '', userId: '', from: '', to: '',
  });
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  const load = useCallback(async (cursor: string | null = null) => {
    setLoading(true);
    try {
      const page = await bookingChatAdminApi.list(cursor, filter);
      setItems(page.items);
      setCurrentCursor(cursor);
      setNextCursor(page.nextCursor);
      setError('');
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Không tải được Booking Chat.');
    } finally {
      setLoading(false);
    }
  }, [filter]);

  useEffect(() => { void load(); }, [load]);

  async function open(id: string) {
    if (!readReason.trim()) {
      setError('Nhập lý do đọc nội dung trước khi mở hội thoại.');
      return;
    }
    setBusy(true);
    try {
      const context = { reason: readReason.trim(), ticketId: ticketId.trim() || undefined };
      const [detail, messagePage, activityPage] = await Promise.all([
        bookingChatAdminApi.get(id, context),
        bookingChatAdminApi.messages(id, context),
        bookingChatAdminApi.activity(id),
      ]);
      setSelected(detail);
      setMessages(messagePage.items);
      setNextMessageSequence(messagePage.nextBeforeSequence);
      setActivity(activityPage.items);
      setNextActivityCursor(activityPage.nextCursor);
      setActionReason('');
      setActionConfirmed(false);
      setError('');
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Không tải được chi tiết hội thoại.');
    } finally {
      setBusy(false);
    }
  }

  async function loadOlderMessages() {
    if (!selected || nextMessageSequence === null || busy) return;
    setBusy(true);
    try {
      const page = await bookingChatAdminApi.messages(selected.conversationId, {
        beforeSequence: nextMessageSequence,
        reason: readReason.trim(),
        ticketId: ticketId.trim() || undefined,
      });
      setMessages((current) => [...page.items, ...current]);
      setNextMessageSequence(page.nextBeforeSequence);
      setError('');
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Không tải được tin nhắn cũ hơn.');
    } finally {
      setBusy(false);
    }
  }

  async function loadMoreActivity() {
    if (!selected || !nextActivityCursor || busy) return;
    setBusy(true);
    try {
      const page = await bookingChatAdminApi.activity(selected.conversationId, nextActivityCursor);
      setActivity((current) => [...current, ...page.items]);
      setNextActivityCursor(page.nextCursor);
      setError('');
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Không tải được audit log cũ hơn.');
    } finally {
      setBusy(false);
    }
  }

  async function refreshAfterMutation(detail: BookingChatAdminDetail) {
    setSelected(detail);
    setActionReason('');
    setActionConfirmed(false);
    await load(currentCursor);
    const activityPage = await bookingChatAdminApi.activity(detail.conversationId);
    setActivity(activityPage.items);
    setNextActivityCursor(activityPage.nextCursor);
  }

  async function change(block: boolean) {
    if (!selected || busy || !actionReason.trim() || !actionConfirmed) return;
    setBusy(true);
    try {
      const detail = block
        ? await bookingChatAdminApi.block(selected.conversationId, selected.changeVersion, actionReason.trim())
        : await bookingChatAdminApi.unblock(selected.conversationId, selected.changeVersion, actionReason.trim());
      await refreshAfterMutation(detail);
      setError('');
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Không thể cập nhật trạng thái chat.');
    } finally {
      setBusy(false);
    }
  }

  async function releaseHold() {
    if (!selected || busy || !actionReason.trim() || !actionConfirmed) return;
    setBusy(true);
    try {
      const detail = await bookingChatAdminApi.releaseLegalHold(
        selected.conversationId, selected.changeVersion, actionReason.trim());
      await refreshAfterMutation(detail);
      setError('');
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Không thể gỡ legal hold.');
    } finally {
      setBusy(false);
    }
  }

  function goNext() {
    if (!nextCursor) return;
    setCursorHistory((history) => [...history, currentCursor]);
    void load(nextCursor);
  }

  function goPrevious() {
    const previous = cursorHistory.at(-1);
    if (previous === undefined) return;
    setCursorHistory((history) => history.slice(0, -1));
    void load(previous);
  }

  function applyFilters() {
    const booleanValue = (value: string) => value === '' ? undefined : value === 'true';
    setCursorHistory([]);
    setCurrentCursor(null);
    setSelected(null);
    setFilter({
      reported: booleanValue(filterDraft.reported),
      blocked: booleanValue(filterDraft.blocked),
      deadLetter: booleanValue(filterDraft.deadLetter),
      bookingId: filterDraft.bookingId.trim() || undefined,
      userId: filterDraft.userId.trim() || undefined,
      from: filterDraft.from ? new Date(filterDraft.from).toISOString() : undefined,
      to: filterDraft.to ? new Date(filterDraft.to).toISOString() : undefined,
    });
  }

  return <>
    <PageHeader title="Booking Chat" description="Xem theo quyền quản trị, xử lý report, khóa chat và kiểm tra audit log."
      actions={<button className="secondary" disabled={loading || busy} onClick={() => void load(currentCursor)}>
        <RefreshCw size={16} /> Làm mới
      </button>} />
    {error && <ErrorBanner message={error} onRetry={() => void load(currentCursor)} />}
    <div className="filter-bar filter-grid booking-chat-filters">
      <label>Report<select value={filterDraft.reported} onChange={(event) => setFilterDraft((value) => ({ ...value, reported: event.target.value }))}>
        <option value="">Tất cả</option><option value="true">Có report</option><option value="false">Chưa report</option>
      </select></label>
      <label>Khóa ghi<select value={filterDraft.blocked} onChange={(event) => setFilterDraft((value) => ({ ...value, blocked: event.target.value }))}>
        <option value="">Tất cả</option><option value="true">Đang khóa</option><option value="false">Đang mở</option>
      </select></label>
      <label>Dead letter<select value={filterDraft.deadLetter} onChange={(event) => setFilterDraft((value) => ({ ...value, deadLetter: event.target.value }))}>
        <option value="">Tất cả</option><option value="true">Có lỗi</option><option value="false">Không có lỗi</option>
      </select></label>
      <label>Booking ID<input value={filterDraft.bookingId} onChange={(event) => setFilterDraft((value) => ({ ...value, bookingId: event.target.value }))} /></label>
      <label>User ID<input value={filterDraft.userId} onChange={(event) => setFilterDraft((value) => ({ ...value, userId: event.target.value }))} /></label>
      <label>Từ ngày<input type="datetime-local" value={filterDraft.from} onChange={(event) => setFilterDraft((value) => ({ ...value, from: event.target.value }))} /></label>
      <label>Đến ngày<input type="datetime-local" value={filterDraft.to} onChange={(event) => setFilterDraft((value) => ({ ...value, to: event.target.value }))} /></label>
      <button className="primary filter-submit" disabled={loading} onClick={applyFilters}>Áp dụng bộ lọc</button>
    </div>
    <section className="data-panel booking-chat-access" aria-labelledby="booking-chat-access-title">
      <div className="panel-heading">
        <div><h2 id="booking-chat-access-title">Ngữ cảnh truy cập nội dung</h2><p>Lý do được ghi vào audit mỗi lần tải tin nhắn.</p></div>
      </div>
      <div className="form-columns">
        <label>Lý do đọc nội dung *<input value={readReason} maxLength={500}
          onChange={(event) => setReadReason(event.target.value)} placeholder="Ví dụ: Điều tra report của khách hàng" /></label>
        <label>Support ticket ID (nếu có)<input value={ticketId}
          onChange={(event) => setTicketId(event.target.value)} placeholder="UUID của ticket liên quan" /></label>
      </div>
    </section>
    <section className="data-panel">
      {loading ? <LoadingTable rows={6} columns={6} /> : items.length === 0 ?
        <EmptyState title="Chưa có Booking Chat" description="Hội thoại hợp lệ sẽ xuất hiện tại đây." /> :
        <div className="table-wrap"><table className="data-table"><thead><tr>
          <th>Booking</th><th>Cập nhật</th><th>Report</th><th>Khóa ghi</th><th>Legal hold</th><th />
        </tr></thead><tbody>{items.map(item => <tr key={item.conversationId}>
          <td><strong>{shortId(item.bookingId)}</strong><small>{shortId(item.conversationId)}</small></td>
          <td>{formatDate(item.updatedAt)}</td><td>{item.reportCount}{item.deadLetterCount > 0 ? ` · ${item.deadLetterCount} lỗi` : ''}</td>
          <td>{item.writeBlocked ? 'Đang khóa' : 'Mở'}</td><td>{item.legalHoldActive ? 'Đang giữ' : '—'}</td>
          <td><button className="row-action" disabled={busy || !readReason.trim()}
            onClick={() => void open(item.conversationId)}>Mở</button></td>
        </tr>)}</tbody></table></div>}
      <div className="cursor-pagination" aria-label="Phân trang Booking Chat">
        <button className="secondary" disabled={loading || cursorHistory.length === 0} onClick={goPrevious}>Trang trước</button>
        <span>Trang {cursorHistory.length + 1}</span>
        <button className="secondary" disabled={loading || !nextCursor} onClick={goNext}>Trang sau</button>
      </div>
    </section>
    {selected && <section className="data-panel" aria-label="Chi tiết Booking Chat">
      <div className="page-actions"><button className="secondary" disabled={busy} onClick={() => setSelected(null)}>Đóng</button></div>
      <DetailList items={[
        { label: 'Booking', value: shortId(selected.bookingId) }, { label: 'Version', value: selected.changeVersion },
        { label: 'Lý do khóa', value: selected.writeBlockReason }, { label: 'Legal hold', value: selected.legalHoldReason },
        { label: 'Dispute lock', value: selected.disputeLockedAt ? formatDate(selected.disputeLockedAt) : '—' },
      ]} />
      <div className="inset-form form-stack">
        <label>Lý do thao tác *<textarea value={actionReason} maxLength={500}
          onChange={(event) => { setActionReason(event.target.value); setActionConfirmed(false); }}
          placeholder="Lý do khóa, mở khóa hoặc gỡ legal hold" /></label>
        <label className="check-label"><input type="checkbox" checked={actionConfirmed}
          onChange={(event) => setActionConfirmed(event.target.checked)} />
          Tôi xác nhận thao tác này sẽ được ghi vào audit log.</label>
        <div className="page-actions">
          <button disabled={busy || !actionReason.trim() || !actionConfirmed} onClick={() => void change(!selected.writeBlocked)}>
            {selected.writeBlocked ? 'Mở khóa chat' : 'Khóa chat'}
          </button>
          {selected.legalHoldAt && !selected.legalHoldReleasedAt && <button className="secondary"
            disabled={busy || !actionReason.trim() || !actionConfirmed} onClick={() => void releaseHold()}>Gỡ legal hold</button>}
        </div>
      </div>
      <h2>Tin nhắn</h2>
      {nextMessageSequence !== null && <button className="text-button" disabled={busy}
        onClick={() => void loadOlderMessages()}>Tải tin nhắn cũ hơn</button>}
      {messages.length === 0 ? <p>Chưa có tin nhắn.</p> : <div className="booking-chat-messages">{messages.map(message =>
        <p key={message.id}><strong>{message.senderRole ?? 'Hệ thống'}</strong> · {formatDate(message.createdAt)}<br />{message.body}</p>)}</div>}
      <h2>Audit log</h2>
      {activity.length === 0 ? <p>Chưa có hoạt động.</p> : <ul>{activity.map(event =>
        <li key={event.id}>{formatDate(event.createdAt)} · {event.action}{event.reason ? ` — ${event.reason}` : ''}</li>)}</ul>}
      {nextActivityCursor && <button className="text-button" disabled={busy}
        onClick={() => void loadMoreActivity()}>Tải hoạt động cũ hơn</button>}
      <h2>Report và support ticket</h2>
      {selected.reports.length === 0 ? <p>Chưa có report.</p> : <div className="stack-list compact-list">{selected.reports.map(report =>
        <article key={report.id}><div><strong>{report.status} · {shortId(report.id)}</strong>
          <p>{report.reason}</p><small>{report.supportTicketId ? `Ticket ${shortId(report.supportTicketId)}` : 'Chưa liên kết ticket'} · {report.attempts} lần xử lý</small>
          {report.lastError && <p className="danger-text">{report.lastError}</p>}</div></article>)}</div>}
    </section>}
  </>;
}
