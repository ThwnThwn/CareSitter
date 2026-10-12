import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_active_controller.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/active/shift_action_feedback.dart';

class ShiftSelfieStep extends ConsumerWidget {
  const ShiftSelfieStep({super.key, required this.bookingId});
  final String bookingId;
  Future<void> _pick(
      BuildContext context, WidgetRef ref, ImageSource source) async {
    final controller = ref.read(shiftActiveProvider(bookingId).notifier);
    final image = await ImagePicker()
        .pickImage(source: source, imageQuality: 85, maxWidth: 1440);
    if (!context.mounted || image == null || !controller.mounted) return;
    final result = await controller.uploadSelfie(image);
    if (context.mounted) showShiftActionResult(context, result);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploading = ref.watch(shiftActiveProvider(bookingId)
        .select((s) => s.busy.contains('selfie')));
    return Column(children: [
      const Icon(Icons.face_retouching_natural_rounded, size: 52),
      const SizedBox(height: AppSpacing.md),
      Text('Chụp ảnh selfie tại địa điểm',
          style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: AppSpacing.xs),
      const Text(
          'Ảnh selfie sẽ được gửi tới khách hàng\nnhư minh chứng bạn đã đến đúng địa điểm.',
          textAlign: TextAlign.center),
      const SizedBox(height: AppSpacing.md),
      Row(children: [
        Expanded(
            child: OutlinedButton.icon(
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Thư viện'),
                onPressed: uploading
                    ? null
                    : () => _pick(context, ref, ImageSource.gallery))),
        const SizedBox(width: AppSpacing.compact),
        Expanded(
            child: ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt_rounded),
                label: Text(uploading ? 'Đang tải…' : 'Chụp ảnh'),
                onPressed: uploading
                    ? null
                    : () => _pick(context, ref, ImageSource.camera))),
      ]),
    ]);
  }
}
