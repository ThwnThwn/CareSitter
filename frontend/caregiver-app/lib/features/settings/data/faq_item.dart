class FaqItem {
  final String question;
  final String answer;

  const FaqItem({required this.question, required this.answer});
}

const caregiverFaqItems = [
  FaqItem(
    question: 'Làm sao để nhận ca chăm sóc?',
    answer:
        'Khi có ca phù hợp, ứng dụng sẽ gửi thông báo. Bạn có thể xem chi tiết ca rồi chọn nhận hoặc từ chối.',
  ),
  FaqItem(
    question: 'Khi nào tôi được thanh toán?',
    answer:
        'Thu nhập được ghi nhận sau khi ca hoàn tất và qua thời gian rà soát theo chính sách của CareSitter.',
  ),
  FaqItem(
    question: 'Tôi cần làm gì khi đến địa điểm chăm sóc?',
    answer:
        'Hãy bắt đầu di chuyển trong app, đến đúng địa chỉ, check-in bằng GPS và theo dõi checklist của ca.',
  ),
  FaqItem(
    question: 'Nếu có sự cố trong ca thì sao?',
    answer:
        'Sử dụng nút hỗ trợ hoặc liên hệ CareSitter ngay. Với tình huống khẩn cấp y tế, hãy gọi dịch vụ cấp cứu địa phương.',
  ),
];
