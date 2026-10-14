import { useEffect, useState } from 'react';
import { ExternalLink } from 'lucide-react';
import { kycImage } from '../../api';

export function KycDocument({ label, mediaId }: { label: string; mediaId?: string }) {
  const [url, setUrl] = useState('');
  const [error, setError] = useState('');
  const [attempt, setAttempt] = useState(0);
  useEffect(() => {
    if (!mediaId) return;
    const controller = new AbortController();
    let objectUrl = '';
    setUrl(''); setError('');
    void kycImage(mediaId, controller.signal).then((blob) => {
      if (controller.signal.aborted) return;
      objectUrl = URL.createObjectURL(blob); setUrl(objectUrl);
    }).catch((cause) => {
      if (!controller.signal.aborted) setError(cause instanceof Error ? cause.message : 'Không thể đọc tài liệu.');
    });
    return () => { controller.abort(); if (objectUrl) URL.revokeObjectURL(objectUrl); };
  }, [mediaId, attempt]);
  if (!mediaId) return <div className="missing-document"><span>{label}</span><small>Chưa có tài liệu riêng tư</small></div>;
  if (!url) return <div className="missing-document" aria-live="polite"><span>{label}</span><small>{error || 'Đang tải tài liệu riêng tư…'}</small>{error && <button className="secondary" onClick={() => setAttempt((value) => value + 1)}>Thử lại</button>}</div>;
  return <a href={url} target="_blank" rel="noreferrer"><img src={url} alt={label} referrerPolicy="no-referrer" /><span>{label}<ExternalLink size={14} /></span></a>;
}
