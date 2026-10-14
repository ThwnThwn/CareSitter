import 'package:flutter/material.dart';

class BookingExtensionUnavailableDialog extends StatelessWidget {
  const BookingExtensionUnavailableDialog({super.key});

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Chưa thể gia hạn trên ứng dụng'),
        content: const Text(
          'Ứng dụng chưa hỗ trợ gửi yêu cầu gia hạn ca. '
          'Vui lòng liên hệ bộ phận hỗ trợ để được hướng dẫn.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đã hiểu'),
          ),
        ],
      );
}
