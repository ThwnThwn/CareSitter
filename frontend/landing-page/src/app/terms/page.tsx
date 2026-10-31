import type { Metadata } from "next";
import LegalPage from "@/components/legal/LegalPage";

export const metadata: Metadata = {
  title: "Điều khoản dịch vụ | CareSitter",
  description:
    "Điều khoản sử dụng CareSitter Customer, CareSitter Caregiver và các kênh hỗ trợ liên quan.",
  alternates: { canonical: "/terms" },
};

export default function TermsPage() {
  return (
    <LegalPage
      title="Điều khoản dịch vụ"
      summary="Khi tạo tài khoản hoặc sử dụng CareSitter, bạn đồng ý với các điều khoản này. CareSitter kết nối gia đình với caregiver cho nhu cầu hỗ trợ sinh hoạt phi y tế; ứng dụng không thay thế dịch vụ y tế hoặc cấp cứu."
      updatedAt="29/10/2026"
      sections={[
        {
          id: "eligibility",
          title: "Tài khoản và điều kiện sử dụng",
          content: (
            <ul>
              <li>Bạn phải từ 18 tuổi, cung cấp thông tin chính xác và bảo vệ thông tin đăng nhập.</li>
              <li>Customer phải có quyền cung cấp thông tin của người được chăm sóc; caregiver phải hoàn tất yêu cầu xác minh áp dụng cho vai trò của mình.</li>
              <li>Không chia sẻ tài khoản, giả mạo danh tính, né tránh kiểm tra an toàn hoặc dùng dịch vụ cho mục đích trái pháp luật.</li>
            </ul>
          ),
        },
        {
          id: "service-scope",
          title: "Phạm vi dịch vụ phi y tế",
          content: (
            <>
              <p>CareSitter hỗ trợ đặt, điều phối và theo dõi các hoạt động sinh hoạt tại nhà. Caregiver không được tự ý chẩn đoán, kê đơn, thay đổi thuốc hoặc thực hiện can thiệp y khoa ngoài phạm vi hợp pháp và đã được xác minh.</p>
              <p>Trong tình huống khẩn cấp, hãy gọi cơ quan cấp cứu địa phương trước. Tính năng SOS/hỗ trợ CareSitter không thay thế dịch vụ khẩn cấp.</p>
            </>
          ),
        },
        {
          id: "bookings-payments",
          title: "Booking, thanh toán và tranh chấp",
          content: (
            <>
              <p>Giá, thời gian, phạm vi ca, phí và điều kiện hủy/hoàn được hiển thị trước khi Customer xác nhận. Thanh toán trong CareSitter dành cho dịch vụ chăm sóc ngoài đời thực, không phải nội dung số.</p>
              <p>Các bên cần lưu bằng chứng chính xác và hợp tác trong quy trình xử lý sự cố, hoàn tiền hoặc tranh chấp. CareSitter có thể tạm giữ thanh toán khi cần điều tra an toàn hoặc gian lận.</p>
            </>
          ),
        },
        {
          id: "ugc",
          title: "Tin nhắn và nội dung người dùng",
          content: (
            <>
              <p>Bạn chịu trách nhiệm về tin nhắn, ảnh, đánh giá, hồ sơ và nội dung mình gửi. Nội dung phải liên quan đến dịch vụ và tôn trọng quyền riêng tư của người khác.</p>
              <p>Không được gửi nội dung quấy rối, đe dọa, thù ghét, tình dục, bạo lực, lừa đảo, spam, thông tin y tế sai lệch, dữ liệu riêng tư không có quyền chia sẻ hoặc nội dung vi phạm pháp luật/quyền sở hữu trí tuệ.</p>
              <p>Người dùng có thể báo cáo nội dung hoặc người dùng và chặn tương tác 1:1. CareSitter có thể giới hạn, ẩn, lưu giữ để điều tra hoặc gỡ nội dung; cảnh báo, khóa hoặc chấm dứt tài khoản; và phối hợp với cơ quan có thẩm quyền khi cần. Bạn có thể liên hệ hỗ trợ để khiếu nại quyết định moderation.</p>
            </>
          ),
        },
        {
          id: "safety",
          title: "An toàn và giới hạn trách nhiệm",
          content: (
            <>
              <p>Không bên nào được yêu cầu hoặc thực hiện công việc không an toàn, trái pháp luật hoặc ngoài booking đã thống nhất. Hãy dùng kênh hỗ trợ để báo cáo sớm dấu hiệu rủi ro.</p>
              <p>Trong phạm vi pháp luật cho phép, CareSitter không chịu trách nhiệm cho gián đoạn ngoài kiểm soát hợp lý, thông tin sai do người dùng cung cấp hoặc hành vi cố ý vi phạm điều khoản.</p>
            </>
          ),
        },
        {
          id: "termination",
          title: "Chấm dứt và liên hệ",
          content: (
            <>
              <p>Bạn có thể ngừng sử dụng hoặc yêu cầu xóa tài khoản. CareSitter có thể hạn chế tài khoản để bảo vệ an toàn, điều tra gian lận, tuân thủ pháp luật hoặc xử lý vi phạm; các nghĩa vụ thanh toán, tranh chấp và lưu giữ hợp pháp vẫn có hiệu lực.</p>
              <p>Việc xử lý dữ liệu được mô tả tại <a href="/privacy">Chính sách quyền riêng tư</a>. Câu hỏi hoặc khiếu nại gửi đến <a href="mailto:hello@caresitter.vn">hello@caresitter.vn</a>.</p>
            </>
          ),
        },
      ]}
    />
  );
}
