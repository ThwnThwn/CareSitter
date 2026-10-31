import type { Metadata } from "next";
import { Mail } from "lucide-react";
import LegalPage from "@/components/legal/LegalPage";
import styles from "@/components/legal/legal-page.module.css";

const requestSubject = encodeURIComponent("Yêu cầu xóa tài khoản CareSitter");
const requestBody = encodeURIComponent(
  "Vai trò (Customer/Caregiver):\nEmail hoặc số điện thoại tài khoản:\nTên hiển thị:\nLý do (không bắt buộc):\n\nTôi xác nhận muốn xóa tài khoản CareSitter và dữ liệu liên quan.",
);

export const metadata: Metadata = {
  title: "Yêu cầu xóa tài khoản | CareSitter",
  description:
    "Hướng dẫn yêu cầu xóa tài khoản và dữ liệu CareSitter Customer hoặc CareSitter Caregiver mà không cần cài ứng dụng.",
  alternates: { canonical: "/account-deletion" },
};

export default function AccountDeletionPage() {
  return (
    <LegalPage
      title="Xóa tài khoản CareSitter"
      summary="Bạn có thể yêu cầu xóa tài khoản Customer hoặc Caregiver ngay trong ứng dụng, hoặc gửi yêu cầu từ trang này mà không cần cài ứng dụng. CareSitter sẽ xác minh người yêu cầu trước khi xử lý để tránh xóa nhầm tài khoản."
      updatedAt="29/10/2026"
      action={
        <a
          className={styles.action}
          href={`mailto:hello@caresitter.vn?subject=${requestSubject}&body=${requestBody}`}
        >
          <Mail size={18} aria-hidden="true" />
          Gửi yêu cầu xóa qua email
        </a>
      }
      sections={[
        {
          id: "request",
          title: "Cách gửi yêu cầu",
          content: (
            <ol>
              <li>Trong ứng dụng: mở Cài đặt → Tài khoản → Xóa tài khoản, đọc hậu quả và xác nhận.</li>
              <li>Nếu không còn cài app, gửi email đến <a href={`mailto:hello@caresitter.vn?subject=${requestSubject}&body=${requestBody}`}>hello@caresitter.vn</a> bằng email đã đăng ký. Ghi rõ vai trò Customer/Caregiver và email hoặc số điện thoại tài khoản.</li>
              <li>CareSitter có thể yêu cầu một bước xác minh bổ sung. Không gửi mật khẩu, OTP, số thẻ hoặc giấy tờ đầy đủ qua email.</li>
            </ol>
          ),
        },
        {
          id: "deleted-data",
          title: "Dữ liệu sẽ được xóa hoặc ẩn danh",
          content: (
            <ul>
              <li>Thông tin đăng nhập, phiên, thiết bị nhận thông báo và khả năng truy cập tài khoản.</li>
              <li>Thông tin hồ sơ không còn cần thiết, địa chỉ, tùy chọn cá nhân và dữ liệu sức khỏe/dinh dưỡng do người dùng cung cấp.</li>
              <li>Nội dung, ảnh và dữ liệu liên quan khác khi không có nghĩa vụ lưu giữ hoặc tranh chấp đang xử lý.</li>
              <li>Dữ liệu trong hệ thống liên quan như Firebase/FCM và bộ nhớ tệp trong phạm vi CareSitter kiểm soát.</li>
            </ul>
          ),
        },
        {
          id: "retained-data",
          title: "Dữ liệu có thể được giữ lại",
          content: (
            <>
              <p>Một số hồ sơ booking, giao dịch, thuế/kế toán, KYC, chống gian lận, báo cáo an toàn, tranh chấp và audit có thể được giữ theo nghĩa vụ pháp luật hoặc lợi ích hợp pháp. Dữ liệu giữ lại sẽ bị hạn chế truy cập và không được dùng để tiếp thị.</p>
              <p>Nội dung đang chịu legal hold hoặc cần làm bằng chứng sẽ được xóa khi căn cứ lưu giữ kết thúc.</p>
            </>
          ),
        },
        {
          id: "timeline",
          title: "Thời gian và hậu quả",
          content: (
            <>
              <p>CareSitter xác nhận yêu cầu sau khi nhận và hoàn tất trong tối đa 30 ngày kể từ khi xác minh, trừ trường hợp pháp luật hoặc tranh chấp đòi hỏi thêm thời gian. Bạn sẽ nhận thông báo nếu thời hạn thay đổi.</p>
              <p className={styles.note}>Xóa tài khoản làm mất quyền truy cập lịch sử và không thể hoàn tác. Booking, thanh toán hoặc ca đang hoạt động cần được kết thúc hoặc xử lý an toàn trước khi xóa.</p>
            </>
          ),
        },
      ]}
    />
  );
}
