import 'package:flutter/material.dart';

class BeneficiaryContactEntry {
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  String relationship = 'Con trai';
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
  }
}
