import { useAdminMutation } from '../../hooks/useAdminMutation';
import { Booking, CareTask, TimelineEvent } from '../../types';
import { useResource } from '../../useResource';
import { completeBooking } from './bookingApi';

export function useBookingReview(booking: Booking, onChanged: () => void) {
  const detailResource = useResource<Booking>(`/api/v1/bookings/${booking.id}`, booking);
  const taskResource = useResource<CareTask[]>(`/api/v1/bookings/${booking.id}/tasks`, []);
  const timelineResource = useResource<TimelineEvent[]>(`/api/v1/bookings/${booking.id}/timeline`, []);
  const mutation = useAdminMutation<'complete'>();
  const loading = detailResource.loading || taskResource.loading || timelineResource.loading;
  const loadError = detailResource.error || taskResource.error || timelineResource.error;
  function reloadDetails() { void detailResource.reload(); void taskResource.reload(); void timelineResource.reload(); }
  async function complete(confirm: () => boolean) {
    if (mutation.busy || loading || loadError || detailResource.data.status !== 'checkout_pending_review') return;
    if (!confirm()) return;
    await mutation.run('complete', signal => completeBooking(booking.id, signal), 'Không thể hoàn tất booking.', onChanged);
  }
  return { detail: detailResource.data, tasks: taskResource.data, timeline: timelineResource.data,
    loading, loadError, reloadDetails, busy: !!mutation.busy, error: mutation.error, complete };
}
