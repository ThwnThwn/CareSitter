import { Component, ReactNode } from 'react';

interface Props {
  children: ReactNode;
  /** Tên page dùng để hiển thị trong thông báo lỗi */
  pageName?: string;
}

interface State {
  error: Error | null;
}

/**
 * Bắt lỗi render của một page đơn lẻ.
 * Đặt bao ngoài mỗi page trong Shell để một page crash
 * không làm trắng toàn bộ app admin.
 */
export class ErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props);
    this.state = { error: null };
  }

  static getDerivedStateFromError(error: Error): State {
    return { error };
  }

  override componentDidCatch(error: Error, info: { componentStack: string }) {
    // Ghi log để debug — không ghi credential hay dữ liệu nhạy cảm
    console.error('[AdminWeb] Lỗi render page:', error.message, info.componentStack);
  }

  override render() {
    if (this.state.error) {
      const { pageName } = this.props;
      return (
        <main className="boot-screen" role="alert">
          <div className="boot-card">
            <strong>
              {pageName ? `Không thể hiển thị trang "${pageName}"` : 'Lỗi hiển thị trang'}
            </strong>
            <p>
              Đã xảy ra lỗi không mong muốn. Vui lòng tải lại trang hoặc liên hệ bộ phận kỹ thuật
              nếu lỗi tiếp tục xảy ra.
            </p>
            <div className="button-row">
              <button
                className="primary"
                onClick={() => this.setState({ error: null })}
              >
                Thử lại
              </button>
              <button
                className="secondary"
                onClick={() => window.location.reload()}
              >
                Tải lại trang
              </button>
            </div>
          </div>
        </main>
      );
    }
    return this.props.children;
  }
}
