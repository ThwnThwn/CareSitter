import { ImagePlus, Trash2 } from 'lucide-react';

const allowedTypes = ['image/jpeg', 'image/png', 'image/webp'];

export function ServiceImageField({
  previewUrl,
  disabled,
  onSelect,
  onRemove,
}: {
  previewUrl: string;
  disabled: boolean;
  onSelect: (file: File) => void;
  onRemove: () => void;
}) {
  return (
    <section className="service-image-field" aria-labelledby="service-image-heading">
      <div className="service-image-preview">
        {previewUrl ? (
          <img src={previewUrl} alt="Ảnh xem trước của gói dịch vụ" />
        ) : (
          <div className="service-image-placeholder">
            <ImagePlus size={28} aria-hidden="true" />
            <span>Chưa có ảnh đại diện</span>
          </div>
        )}
      </div>
      <div className="service-image-actions">
        <div>
          <strong id="service-image-heading">Ảnh gói dịch vụ</strong>
          <p>JPEG, PNG hoặc WEBP, tối đa 5 MB. Nên dùng ảnh ngang tỉ lệ 16:9.</p>
        </div>
        <div className="button-row">
          <label className="secondary file-button">
            <ImagePlus size={15} aria-hidden="true" />
            {previewUrl ? 'Thay ảnh' : 'Chọn ảnh'}
            <input
              type="file"
              aria-label="Chọn ảnh gói dịch vụ"
              accept={allowedTypes.join(',')}
              disabled={disabled}
              onChange={(event) => {
                const file = event.target.files?.[0];
                if (file) onSelect(file);
                event.currentTarget.value = '';
              }}
            />
          </label>
          {previewUrl && (
            <button type="button" className="secondary danger-text" disabled={disabled} onClick={onRemove}>
              <Trash2 size={15} aria-hidden="true" /> Xóa ảnh
            </button>
          )}
        </div>
      </div>
    </section>
  );
}
