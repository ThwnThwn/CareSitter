import { act, renderHook } from '@testing-library/react';
import { expect, it, vi } from 'vitest';
import { TOKEN_KEY } from '../api';
import { useAdminMutation } from './useAdminMutation';

function deferred() {
  let resolve!: () => void;
  let reject!: (error: Error) => void;
  const promise = new Promise<void>((done, fail) => { resolve = done; reject = fail; });
  return { promise, resolve, reject };
}

it('blocks duplicate writes before the disabled button can render', async () => {
  const pending = deferred();
  const request = vi.fn(() => pending.promise);
  const onChanged = vi.fn();
  const { result } = renderHook(() => useAdminMutation<'resolve'>());
  let first!: Promise<boolean>;
  let second!: Promise<boolean>;
  act(() => {
    first = result.current.run('resolve', request, 'Lỗi thao tác', onChanged);
    second = result.current.run('resolve', request, 'Lỗi thao tác', onChanged);
  });
  expect(request).toHaveBeenCalledTimes(1);
  expect(await second).toBe(false);
  expect(result.current.busy).toBe('resolve');
  await act(async () => { pending.resolve(); expect(await first).toBe(true); });
  expect(onChanged).toHaveBeenCalledOnce();
  expect(result.current.busy).toBe('');
});

it('aborts a drawer-owned request and ignores its late response after unmount', async () => {
  const pending = deferred();
  let signal!: AbortSignal;
  const onChanged = vi.fn();
  const { result, unmount } = renderHook(() => useAdminMutation<'complete'>());
  let work!: Promise<boolean>;
  act(() => { work = result.current.run('complete', value => { signal = value; return pending.promise; }, 'Lỗi', onChanged); });
  unmount();
  expect(signal.aborted).toBe(true);
  pending.resolve();
  expect(await work).toBe(false);
  expect(onChanged).not.toHaveBeenCalled();
});

it('does not deliver a mutation result to a different login session', async () => {
  sessionStorage.setItem(TOKEN_KEY, 'first-session');
  const pending = deferred();
  const onChanged = vi.fn();
  const { result } = renderHook(() => useAdminMutation<'approve'>());
  let work!: Promise<boolean>;
  act(() => { work = result.current.run('approve', () => pending.promise, 'Lỗi', onChanged); });
  sessionStorage.setItem(TOKEN_KEY, 'second-session');
  await act(async () => { pending.resolve(); expect(await work).toBe(false); });
  expect(onChanged).not.toHaveBeenCalled();
  sessionStorage.removeItem(TOKEN_KEY);
});

it('shows a failed write, releases the lock, and supports an explicit next attempt', async () => {
  const pending = deferred();
  const onChanged = vi.fn();
  const onFailure = vi.fn();
  const { result } = renderHook(() => useAdminMutation<'save'>());
  let work!: Promise<boolean>;
  act(() => { work = result.current.run('save', () => pending.promise, 'Lỗi', onChanged, onFailure); });
  await act(async () => { pending.reject(new Error('Dữ liệu đã thay đổi')); expect(await work).toBe(false); });
  expect(result.current.error).toBe('Dữ liệu đã thay đổi');
  expect(result.current.busy).toBe('');
  expect(onFailure).toHaveBeenCalledOnce();
  await act(async () => { await result.current.run('save', async () => {}, 'Lỗi', onChanged); });
  expect(result.current.error).toBe('');
  expect(onChanged).toHaveBeenCalledOnce();
});
