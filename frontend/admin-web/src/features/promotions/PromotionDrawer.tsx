import { Drawer, ErrorBanner, LoadingTable } from '../../components/Common';
import { AdminPromotion } from '../../types';
import { useResource } from '../../useResource';
import { promotionsEndpoint as endpoint } from './promotionApi';
import { PromotionEditor } from './PromotionEditor';

export function PromotionDrawer({
  id,
  onClose,
  onChanged,
}: {
  id: string | null;
  onClose: () => void;
  onChanged: (message: string) => void;
}) {
  const { data, loading, error, reload } = useResource<AdminPromotion | null>(
    id ? `${endpoint}/${id}` : null,
    null,
  );
  if (loading || error || (id && !data))
    return (
      <Drawer title="Chi tiết chiến dịch" onClose={onClose}>
        {error ? (
          <ErrorBanner message={error} onRetry={() => void reload()} />
        ) : (
          <LoadingTable rows={5} columns={2} />
        )}
      </Drawer>
    );
  return (
    <PromotionEditor
      key={data?.updatedAt ?? 'new'}
      promotion={data}
      onClose={onClose}
      onChanged={onChanged}
      onReload={() => void reload()}
    />
  );
}
