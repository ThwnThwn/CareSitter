import { useCallback, useEffect, useRef, useState } from 'react';
import { api } from './api';
import type { Paged } from './types';

export function useResource<T>(path: string | null, initial: T) {
  const initialValue = useRef(initial);
  const currentPath = useRef(path);
  currentPath.current = path;
  const request = useRef(0);
  const mounted = useRef(true);
  const controller = useRef<AbortController | null>(null);
  const [state, setState] = useState({ path, data: initial, loading: !!path, error: '' });
  const reload = useCallback(async () => {
    if (!mounted.current || currentPath.current !== path) return;
    const sequence = ++request.current;
    controller.current?.abort();
    const abort = new AbortController();
    controller.current = abort;
    if (!path) {
      setState({ path, data: initialValue.current, loading: false, error: '' });
      return;
    }
    setState((previous) => ({ path, data: previous.path === path ? previous.data : initialValue.current, loading: true, error: '' }));
    try {
      const data = await api<T>(path, { signal: abort.signal });
      if (request.current === sequence && !abort.signal.aborted && currentPath.current === path) {
        setState({ path, data, loading: false, error: '' });
      }
    } catch (cause) {
      if (request.current === sequence && !abort.signal.aborted && currentPath.current === path) {
        setState((previous) => ({ ...previous, loading: false, error: cause instanceof Error ? cause.message : 'Không thể tải dữ liệu.' }));
      }
    }
  }, [path]);
  useEffect(() => {
    mounted.current = true;
    void reload();
    return () => { mounted.current = false; ++request.current; controller.current?.abort(); };
  }, [reload]);
  return {
    data: state.path === path ? state.data : initialValue.current,
    loading: state.path === path ? state.loading : !!path,
    error: state.path === path ? state.error : '',
    reload,
  };
}

export function usePagedResource<T>(path: string, page: number, setPage: (value: number) => void) {
  const resource = useResource<Paged<T>>(path, { items: [], total: 0, page: 1, pageSize: 20 });
  const lastPage = Math.max(1, Math.ceil(resource.data.total / resource.data.pageSize));
  const correctingPage = !resource.loading && !resource.error && page > lastPage;
  useEffect(() => { if (correctingPage) setPage(lastPage); }, [correctingPage, lastPage, setPage]);
  return { ...resource, loading: resource.loading || correctingPage };
}
