import type { Metadata } from "next";
import LegalPage from "@/components/legal/LegalPage";

export const metadata: Metadata = {
  title: "Chính sách quyền riêng tư | CareSitter",
  description:
    "Cách CareSitter thu thập, sử dụng, chia sẻ, bảo vệ và xóa dữ liệu của ứng dụng Customer và Caregiver.",
  alternates: { canonical: "/privacy" },
};

export default function PrivacyPage() {
  return (
    <LegalPage
      title="Chính sách quyền riêng tư"
      summary="Chính sách này áp dụng cho CareSitter Customer (vn.caresitter.customer), CareSitter Caregiver (vn.caresitter.caregiver), website và các dịch vụ hỗ trợ liên quan. CareSitter chỉ xử lý dữ liệu cần cho việc điều phối dịch vụ chăm sóc phi y tế, an toàn tài khoản và hỗ trợ người dùng."
      updatedAt="29/10/2026"
      sections={[
        {
          id: "data-we-collect",
          title: "Dữ liệu chúng tôi xử lý",
          content: (
            <>
              <p>Dữ liệu thay đổi theo vai trò và tính năng bạn sử dụng:</p>
              <ul>
                <li>Thông tin tài khoản: họ tên, email, số điện thoại, địa chỉ, mã người dùng và thông tin đăng nhập.</li>
                <li>Hồ sơ chăm sóc: người thụ hưởng, nhu cầu sinh hoạt, dị ứng, bệnh nền, thuốc, ghi chú dinh dưỡng và liên hệ khẩn cấp do người dùng cung cấp.</li>
                <li>Dữ liệu caregiver: hồ sơ nghề nghiệp, KYC, lịch làm việc, trạng thái ca, ảnh bằng chứng, thu nhập và thông tin nhận thanh toán.</li>
                <li>Dữ liệu giao dịch: booking, trạng thái thanh toán, hoàn tiền, ví và mã giao dịch. CareSitter không lưu đầy đủ thông tin thẻ thanh toán.</li>
                <li>Vị trí caregiver trong ngữ cảnh check-in, điều hướng và theo dõi ca; Customer không cần chia sẻ vị trí thiết bị chỉ để xem ca.</li>
                <li>Tin nhắn, báo cáo, ảnh đính kèm, yêu cầu hỗ trợ, đánh giá và nội dung người dùng gửi.</li>
                <li>Thông tin thiết bị cần cho thông báo, bảo mật phiên và vận hành ứng dụng, như FCM token và định danh ứng dụng.</li>
              </ul>
            </>
          ),
        },
        {
          id: "why-we-use-data",
          title: "Mục đích sử dụng",
          content: (
            <ul>
              <li>Tạo và bảo vệ tài khoản, xác minh caregiver, cung cấp booking và điều phối ca.</li>
              <li>Hiển thị tiến độ, bằng chứng, vị trí trong ca và gửi thông báo liên quan.</li>
              <li>Xử lý thanh toán cho dịch vụ chăm sóc ngoài đời thực, hoàn tiền và đối soát.</li>
              <li>Cá nhân hóa gợi ý sinh hoạt hoặc dinh dưỡng theo thông tin bạn chủ động cung cấp. CareSitter không chẩn đoán hay điều trị bệnh.</li>
              <li>Phòng chống gian lận, xử lý sự cố, tranh chấp, báo cáo nội dung và hỗ trợ khách hàng.</li>
              <li>Tuân thủ nghĩa vụ pháp luật và cải thiện độ ổn định, an toàn của dịch vụ.</li>
            </ul>
          ),
        },
        {
          id: "sharing",
          title: "Chia sẻ và nhà cung cấp dịch vụ",
          content: (
            <>
              <p>CareSitter không bán dữ liệu cá nhân. Chúng tôi chỉ chuyển dữ liệu cần thiết cho:</p>
              <ul>
                <li>Customer, caregiver được phân công và nhân sự vận hành có thẩm quyền để thực hiện ca.</li>
                <li>Nhà cung cấp hạ tầng, lưu trữ, Firebase/Google cho xác thực, thông báo, chat và bản đồ; cổng thanh toán cho giao dịch.</li>
                <li>Cơ quan có thẩm quyền khi pháp luật yêu cầu hoặc để bảo vệ an toàn, quyền lợi hợp pháp của các bên.</li>
              </ul>
              <p>Mỗi bên chỉ nhận phạm vi dữ liệu phù hợp với vai trò và mục đích đã nêu.</p>
            </>
          ),
        },
        {
          id: "retention-security",
          title: "Lưu giữ và bảo mật",
          content: (
            <>
              <p>Phiên khôi phục tài khoản được xóa sau thời hạn ngắn; vị trí trực tiếp hết hạn theo cấu hình vận hành; nội dung booking chat mặc định được lên lịch xóa sau 180 ngày kể từ khi hội thoại đóng, trừ khi có tranh chấp, báo cáo hoặc legal hold.</p>
              <p>Hồ sơ giao dịch, thanh toán, KYC, chống gian lận và nhật ký kiểm toán có thể được giữ lâu hơn khi cần cho nghĩa vụ pháp luật hoặc giải quyết tranh chấp. Khi không còn cần thiết, dữ liệu được xóa hoặc ẩn danh.</p>
              <p>CareSitter dùng phân quyền theo vai trò, thu hồi phiên, giới hạn truy cập và HTTPS cho hệ thống production. Không có phương thức truyền hoặc lưu trữ nào bảo đảm an toàn tuyệt đối.</p>
            </>
          ),
        },
        {
          id: "your-rights",
          title: "Quyền và lựa chọn của bạn",
          content: (
            <>
              <p>Bạn có thể xem, cập nhật, yêu cầu sửa hoặc xóa dữ liệu của mình; tắt thông báo không thiết yếu; và rút quyền vị trí/camera trong cài đặt thiết bị. Việc từ chối một quyền có thể làm tính năng liên quan không hoạt động.</p>
              <p>Để xóa tài khoản, dùng mục Xóa tài khoản trong ứng dụng hoặc làm theo hướng dẫn tại <a href="/account-deletion">trang yêu cầu xóa tài khoản</a>.</p>
            </>
          ),
        },
        {
          id: "age-contact",
          title: "Độ tuổi, thay đổi và liên hệ",
          content: (
            <>
              <p>Dịch vụ dành cho người từ 18 tuổi trở lên. Người dùng chỉ được cung cấp dữ liệu của người được chăm sóc khi có quyền hợp pháp hoặc sự đồng ý phù hợp.</p>
              <p>Chúng tôi có thể cập nhật chính sách khi tính năng, nhà cung cấp hoặc pháp luật thay đổi. Thay đổi quan trọng sẽ được thông báo trong ứng dụng hoặc trên website.</p>
              <p>Đơn vị vận hành: CareSitter. Liên hệ về quyền riêng tư: <a href="mailto:hello@caresitter.vn">hello@caresitter.vn</a>.</p>
            </>
          ),
        },
      ]}
    />
  );
}
