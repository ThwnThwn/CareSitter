import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

ImageProvider<Object> appAvatarImageProvider(String value) {
  final uri = Uri.tryParse(value);
  final isRemote = uri != null &&
      uri.hasScheme &&
      (uri.scheme == 'http' || uri.scheme == 'https');

  if (kIsWeb || isRemote) return NetworkImage(value);
  return FileImage(File(value));
}
