import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class DocumentCertificateHeading extends StatelessWidget {
  const DocumentCertificateHeading({super.key, required this.certificates});
  final List<XFile> certificates;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Expanded(
            child: Text('Chứng chỉ chuyên môn (không bắt buộc)',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          Text('${certificates.length}/10',
              style: const TextStyle(color: AppColors.textSecondary)),
        ],
      );
}
