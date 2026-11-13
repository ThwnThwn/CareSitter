import 'package:flutter_riverpod/flutter_riverpod.dart';

final pushPermissionActionProvider =
    Provider<Future<void> Function()>((_) => () async {});
