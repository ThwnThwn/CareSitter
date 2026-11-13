"use client";

import { useEffect, useRef, useState } from "react";
import { requestRecommendation } from "./client";
import type { AssistantReply } from "./contract";

export function useCareAssistant() {
  const [reply, setReply] = useState<AssistantReply | null>(null);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const pending = useRef<AbortController | null>(null);
  useEffect(() => () => { pending.current?.abort(); }, []);

  async function submit(message: string) {
    if (pending.current) return;
    const request = new AbortController();
    pending.current = request;
    setLoading(true);
    setError("");
    setReply(null);
    try {
      const value = await requestRecommendation(message, request.signal);
      if (!request.signal.aborted) setReply(value);
    } catch (cause) {
      if (!request.signal.aborted)
        setError(cause instanceof Error ? cause.message : "Không thể nhận gợi ý lúc này.");
    } finally {
      if (pending.current === request) pending.current = null;
      if (!request.signal.aborted) setLoading(false);
    }
  }

  function cancel() {
    pending.current?.abort();
    pending.current = null;
    setLoading(false);
  }

  return { reply, error, loading, submit, cancel };
}
