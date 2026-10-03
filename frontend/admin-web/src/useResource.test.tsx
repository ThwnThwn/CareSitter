import { act, renderHook, waitFor } from '@testing-library/react';
import { useState } from 'react';
import { expect, it, vi } from 'vitest';
import { usePagedResource, useResource } from './useResource';

function deferredResponse() {
  let resolve!: (response: Response) => void;
  const promise = new Promise<Response>((done) => { resolve = done; });
  return { promise, resolve: (data: unknown) => resolve(Response.json(data)) };
}

it('ignores late results from an old filter even if the transport does not abort', async () => {
  const first = deferredResponse(); const second = deferredResponse();
  const fetch = vi.fn().mockReturnValueOnce(first.promise).mockReturnValueOnce(second.promise);
  vi.stubGlobal('fetch', fetch);
  const { result, rerender } = renderHook(({ path }) => useResource<string[]>(path, []), { initialProps: { path: '/old' } });
  rerender({ path: '/new' });
  expect(fetch.mock.calls[0][1].signal.aborted).toBe(true);
  await act(async () => { second.resolve(['new']); });
  await waitFor(() => expect(result.current.data).toEqual(['new']));
  await act(async () => { first.resolve(['old']); });
  expect(result.current.data).toEqual(['new']);
});

it('aborts on unmount and ignores reload callbacks retained by an in-flight mutation', async () => {
  const pending = deferredResponse();
  const fetch = vi.fn().mockReturnValue(pending.promise);
  vi.stubGlobal('fetch', fetch);
  const { result, unmount } = renderHook(() => useResource('/page', []));
  const reload = result.current.reload;
  unmount();
  expect(fetch.mock.calls[0][1].signal.aborted).toBe(true);
  await reload();
  expect(fetch).toHaveBeenCalledTimes(1);
});

it('recovers to the last populated page after the last item is removed', async () => {
  const fetch = vi.fn().mockImplementation(async (url: string) => Response.json(url.includes('page=2')
    ? { items: [], total: 20, page: 2, pageSize: 20 }
    : { items: ['remaining'], total: 20, page: 1, pageSize: 20 }));
  vi.stubGlobal('fetch', fetch);
  const { result } = renderHook(() => {
    const [page, setPage] = useState(2);
    return usePagedResource<string>(`/list?page=${page}`, page, setPage);
  });
  await waitFor(() => expect(result.current.data.items).toEqual(['remaining']));
  expect(result.current.data.page).toBe(1);
  expect(fetch).toHaveBeenCalledTimes(2);
});

it('keeps an empty successful response distinct from a failed load and permits retry', async () => {
  vi.stubGlobal('fetch', vi.fn().mockRejectedValueOnce(new Error('offline')).mockResolvedValueOnce(Response.json([])));
  const { result } = renderHook(() => useResource('/data', []));
  await waitFor(() => expect(result.current.error).toBe('offline'));
  await act(async () => { await result.current.reload(); });
  expect(result.current.error).toBe('');
  expect(result.current.loading).toBe(false);
  expect(result.current.data).toEqual([]);
});
