import { useSyncExternalStore } from 'react';

function subscribe(listener: () => void) {
  window.addEventListener('hashchange', listener);
  return () => window.removeEventListener('hashchange', listener);
}

export function useHashParam(name: string) {
  return useSyncExternalStore(subscribe, () => {
    const query = window.location.hash.split('?')[1];
    return new URLSearchParams(query).get(name);
  });
}

export function updateBookingLocation(id: string | null) {
  if (!id && window.history.state?.openedFromBookingList) {
    window.history.back();
    return;
  }
  const oldURL = window.location.href;
  if (id) window.history.pushState({ openedFromBookingList: true }, '', `#/bookings?id=${encodeURIComponent(id)}`);
  else window.history.replaceState(null, '', '#/bookings');
  window.dispatchEvent(new HashChangeEvent('hashchange', { oldURL, newURL: window.location.href }));
}
