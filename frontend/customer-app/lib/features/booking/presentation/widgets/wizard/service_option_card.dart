import 'package:caresitter_customer/features/booking/presentation/models/service_option_style.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/wizard/service_option_surface.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';
import 'package:flutter/material.dart';

class ServiceOptionCard extends StatefulWidget {
  const ServiceOptionCard({
    super.key,
    required this.service,
    required this.selected,
    required this.onTap,
  });

  final ServiceModel service;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<ServiceOptionCard> createState() => _ServiceOptionCardState();
}

class _ServiceOptionCardState extends State<ServiceOptionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return ServiceOptionSurface(
      service: widget.service,
      option: ServiceOptionStyle.fromService(widget.service),
      selected: widget.selected,
      pressed: _pressed,
      transitionDuration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
      pressDuration: reduceMotion
          ? Duration.zero
          : Duration(milliseconds: _pressed ? 90 : 150),
      onHighlightChanged: (highlighted) {
        if (_pressed == highlighted) return;
        setState(() => _pressed = highlighted);
      },
      onTap: widget.onTap,
    );
  }
}
