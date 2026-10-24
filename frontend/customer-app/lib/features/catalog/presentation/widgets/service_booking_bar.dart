import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ServiceBookingBar extends StatelessWidget {
  const ServiceBookingBar({super.key, required this.service});

  final ServiceModel service;

  @override
  Widget build(BuildContext context) {
    final price = service.baseHourlyPrice > 0
        ? '${NumberFormat.decimalPattern('vi').format(service.baseHourlyPrice)}đ/giờ'
        : 'Xem giá khi đặt lịch';
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.compact,
            AppSpacing.md,
            AppSpacing.compact,
          ),
          child: Row(
            children: [
              Expanded(child: _BookingPrice(price: price)),
              const SizedBox(width: AppSpacing.md),
              SizedBox(
                width: 172,
                child: FilledButton.icon(
                  onPressed: () => context.push(
                    AppRoutes.bookingNewWith(serviceId: service.id),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                  label: const Text('Đặt lịch ngay'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingPrice extends StatelessWidget {
  const _BookingPrice({required this.price});

  final String price;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chi phí từ',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.micro),
          Text(
            price,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      );
}
