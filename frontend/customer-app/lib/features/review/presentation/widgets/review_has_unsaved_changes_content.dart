import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:caresitter_customer/core/router/navigation_helpers.dart';

class ReviewHasUnsavedChangesContent extends StatelessWidget {
  const ReviewHasUnsavedChangesContent(
      {super.key, required this.hasUnsavedChanges, required this.action1});
  final bool hasUnsavedChanges;
  final Scaffold Function(BuildContext, void Function()) action1;
  @override
  Widget build(BuildContext context) => DiscardChangesGuard(
        hasChanges: () => hasUnsavedChanges,
        fallbackRoute: AppRoutes.bookings,
        builder: action1,
      );
}
