import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/features/auth/domain/google_identity_gateway.dart';

GoogleIdentityGateway createGoogleWebIdentityGateway(Ref ref) =>
    throw UnsupportedError('The Google OAuth popup is only available on web.');
