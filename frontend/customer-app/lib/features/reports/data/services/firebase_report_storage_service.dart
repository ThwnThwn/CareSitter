import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:caresitter_customer/core/error/app_exception.dart';
import '../../domain/report_request.dart';
import '../models/firebase_report_session.dart';

/// Uses an ephemeral Firebase identity, independently of Google sign-in and chat.
class FirebaseReportStorageService {
  ReportRequest<void> upload(FirebaseReportSession session, Uint8List bytes,
      String checksum, void Function(int, int) progress) {
    var cancelled = false;
    UploadTask? task;
    void check() {
      if (cancelled) {
        throw const AppApiException(
            message: 'Đã dừng gửi báo cáo.', isCancelled: true);
      }
      if (session.expiresAtMs <= DateTime.now().millisecondsSinceEpoch) {
        throw const AppApiException(
            message: 'Phiên lưu báo cáo đã hết hạn. Vui lòng thử lại.',
            statusCode: 401,
            code: 'report.session_expired');
      }
    }

    Future<void> run() async {
      FirebaseApp? app;
      StreamSubscription<TaskSnapshot>? subscription;
      try {
        check();
        const webOptions = FirebaseOptions(
          apiKey: String.fromEnvironment('CHAT_FIREBASE_API_KEY'),
          appId: String.fromEnvironment('CHAT_FIREBASE_APP_ID'),
          messagingSenderId:
              String.fromEnvironment('CHAT_FIREBASE_MESSAGING_SENDER_ID'),
          projectId: String.fromEnvironment('CHAT_FIREBASE_PROJECT_ID'),
          authDomain: String.fromEnvironment('CHAT_FIREBASE_AUTH_DOMAIN'),
        );
        final defaults = Firebase.apps.where((a) => a.name == '[DEFAULT]');
        final options = defaults.isNotEmpty
            ? defaults.first.options
            : kIsWeb
                ? webOptions
                : (await Firebase.initializeApp()).options;
        if (session.projectId != options.projectId ||
            session.customToken == null) {
          throw const AppApiException(
              message:
                  'Chức năng lưu báo cáo chưa sẵn sàng. Vui lòng thử lại sau.',
              statusCode: 503,
              code: 'report.firebase_configuration');
        }
        app = await Firebase.initializeApp(
            name: 'report-${DateTime.now().microsecondsSinceEpoch}',
            options: options);
        check();
        final auth = FirebaseAuth.instanceFor(app: app);
        if (kIsWeb) await auth.setPersistence(Persistence.NONE);
        final identity = await auth.signInWithCustomToken(session.customToken!);
        check();
        if (identity.user?.uid != session.uid) {
          throw const AppApiException(
              message: 'Phiên Firebase không thuộc tài khoản hiện tại.',
              statusCode: 403,
              code: 'report.session_owner');
        }
        final storage = FirebaseStorage.instanceFor(
            app: app, bucket: 'gs://${session.bucket}');
        storage.setMaxUploadRetryTime(const Duration(seconds: 90));
        final object = storage.ref(session.objectPath);
        var exists = false;
        try {
          await object.getMetadata();
          exists = true;
        } on FirebaseException catch (error) {
          if (error.code != 'object-not-found') rethrow;
        }
        check();
        if (!exists) {
          task = object.putData(
              bytes,
              SettableMetadata(
                  contentType: 'application/pdf',
                  cacheControl: 'private, no-store',
                  customMetadata: {'sha256': checksum}));
          subscription = task!.snapshotEvents.listen((snapshot) {
            if (!cancelled) {
              progress(snapshot.bytesTransferred, snapshot.totalBytes);
            }
          }, onError: (Object _) {/* The awaited task maps the error once. */});
          await task!;
          check();
        }
        // Exercise Firebase's download URL contract without persisting a share token in logs or the database.
        final url = Uri.parse(await object.getDownloadURL());
        if (url.scheme != 'https') {
          throw StateError('Unexpected Firebase download URL.');
        }
        check();
        progress(bytes.length, bytes.length);
      } on FirebaseException catch (error) {
        throw mapError(error);
      } finally {
        await subscription?.cancel();
        if (app != null) {
          try {
            await FirebaseAuth.instanceFor(app: app).signOut();
          } catch (_) {}
          try {
            await app.delete();
          } catch (_) {}
        }
      }
    }

    return ReportRequest(run(), () {
      cancelled = true;
      if (task != null) {
        unawaited(task!.cancel().then<void>((_) {}, onError: (Object _) {}));
      }
    });
  }

  static AppApiException mapError(FirebaseException error) =>
      switch (error.code) {
        'unauthorized' || 'permission-denied' => const AppApiException(
            message: 'Không có quyền lưu báo cáo này. Vui lòng đăng nhập lại.',
            statusCode: 403,
            code: 'report.firebase_permission'),
        'unauthenticated' ||
        'invalid-custom-token' ||
        'custom-token-mismatch' =>
          const AppApiException(
              message: 'Phiên Firebase không hợp lệ. Vui lòng thử lại.',
              statusCode: 401,
              code: 'report.firebase_auth'),
        'bucket-not-found' ||
        'project-not-found' ||
        'quota-exceeded' =>
          const AppApiException(
              message:
                  'Dịch vụ lưu báo cáo tạm thời chưa sẵn sàng. Vui lòng thử lại sau.',
              statusCode: 503,
              code: 'report.firebase_unavailable'),
        'canceled' => const AppApiException(
            message: 'Đã dừng gửi báo cáo.', isCancelled: true),
        _ => const AppApiException(
            message:
                'Chưa kết nối được Firebase Storage. Vui lòng thử lại cùng tệp.',
            code: 'report.firebase_network'),
      };
}
