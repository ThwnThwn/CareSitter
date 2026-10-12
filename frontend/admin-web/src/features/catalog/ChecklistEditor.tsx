import { EmptyState, ErrorBanner, LoadingTable, StatusChip } from '../../components/Common';
import { CatalogService } from '../../types';
import { useChecklistEditor } from './useChecklistEditor';

export function ChecklistEditor({
  service,
  onBusy,
  onPolicyChanged,
}: {
  service: CatalogService;
  onBusy: (value: boolean) => void;
  onPolicyChanged: (value: boolean) => void;
}) {
  const {
    templates,
    loading,
    loadError,
    reload,
    editing,
    form,
    setForm,
    allowAdHocTasks,
    busy,
    error,
    disabled,
    nextSortOrder,
    reset,
    save,
    togglePolicy,
    toggleTemplate,
    removeTemplate,
    editTemplate,
  } = useChecklistEditor(service, onBusy, onPolicyChanged);
  return (
    <section className="data-panel">
      <div className="panel-heading">
        <div>
          <h2>Checklist của {service.name}</h2>
          <p>Thay đổi chỉ áp dụng cho booking xác nhận sau thời điểm lưu.</p>
        </div>
        <label className="switch-row">
          <span>Cho phép việc phát sinh</span>
          <input
            type="checkbox"
            checked={allowAdHocTasks}
            disabled={disabled}
            onChange={() => void togglePolicy()}
          />
        </label>
      </div>
      {loadError && <ErrorBanner message={loadError} onRetry={() => void reload()} />}
      {error && <ErrorBanner message={error} />}
      {loading ? (
        <LoadingTable rows={5} columns={4} />
      ) : loadError ? null : templates.length === 0 ? (
        <EmptyState
          title="Chưa có công việc mẫu"
          description="Thêm công việc đầu tiên bằng biểu mẫu bên dưới."
        />
      ) : (
        <div className="stack-list checklist-list">
          {templates.map((template) => (
            <article key={template.id}>
              <span className="order-badge">{template.sortOrder}</span>
              <div>
                <strong>{template.name}</strong>
                <p>{template.description}</p>
                <div className="tag-row">
                  <span>{template.isRequired ? 'Bắt buộc' : 'Tùy chọn'}</span>
                  {template.requiresPhoto && <span>Yêu cầu ảnh</span>}
                </div>
              </div>
              <div>
                <StatusChip value={template.isActive ? 'ACTIVE' : 'SUSPENDED'} />
                <button
                  className="row-action"
                  disabled={disabled}
                  onClick={() => editTemplate(template)}
                >
                  Sửa
                </button>
                <button
                  className="row-action"
                  disabled={disabled}
                  onClick={() => void toggleTemplate(template)}
                >
                  {template.isActive ? 'Tắt' : 'Bật'}
                </button>
                <button
                  className="row-action danger-text"
                  disabled={disabled}
                  onClick={() => {
                    if (window.confirm(`Xóa “${template.name}” khỏi checklist?`))
                      void removeTemplate(template);
                  }}
                >
                  Xóa
                </button>
              </div>
            </article>
          ))}
        </div>
      )}
      <form className="form-stack inset-form checklist-form" onSubmit={save}>
        <h3>{editing ? 'Chỉnh sửa công việc' : 'Thêm công việc'}</h3>
        <label>
          Tên công việc
          <input
            required
            minLength={3}
            maxLength={255}
            disabled={disabled}
            value={form.name}
            onChange={(e) => setForm({ ...form, name: e.target.value })}
          />
        </label>
        <label>
          Mô tả
          <textarea
            rows={3}
            maxLength={1000}
            disabled={disabled}
            value={form.description}
            onChange={(e) => setForm({ ...form, description: e.target.value })}
          />
        </label>
        <div className="form-columns">
          <label>
            Thứ tự
            <input
              type="number"
              min="0"
              max="1000"
              disabled={disabled}
              value={form.sortOrder ?? nextSortOrder}
              onChange={(e) => setForm({ ...form, sortOrder: Number(e.target.value) })}
            />
          </label>
          <div className="check-group">
            <label className="check-label">
              <input
                type="checkbox"
                disabled={disabled}
                checked={form.isRequired}
                onChange={(e) => setForm({ ...form, isRequired: e.target.checked })}
              />{' '}
              Bắt buộc
            </label>
            <label className="check-label">
              <input
                type="checkbox"
                disabled={disabled}
                checked={form.requiresPhoto}
                onChange={(e) => setForm({ ...form, requiresPhoto: e.target.checked })}
              />{' '}
              Yêu cầu ảnh
            </label>
          </div>
        </div>
        <div className="button-row">
          <button className="primary" disabled={disabled}>
            {busy === 'save' ? 'Đang lưu…' : editing ? 'Lưu thay đổi' : 'Thêm công việc'}
          </button>
          {editing && (
            <button type="button" className="secondary" disabled={disabled} onClick={reset}>
              Hủy sửa
            </button>
          )}
        </div>
      </form>
    </section>
  );
}
