import 'package:flutter/foundation.dart';
import 'package:caresitter_customer/core/config/env_config.dart';

Future<bool> ensureGoogleMapsLoaded() async => switch (defaultTargetPlatform) {
      TargetPlatform.android =>
        EnvConfig.googleMapsAndroidApiKey.trim().isNotEmpty,
      TargetPlatform.iOS => EnvConfig.googleMapsIosApiKey.trim().isNotEmpty,
      _ => false,
    };
