import 'dart:io';

import 'package:detoxo/core/constants/app_constants.dart';
import 'package:detoxo/features/additional_feature/app_feedback/domain/entities/feedback_report.dart';
import 'package:detoxo/features/additional_feature/app_feedback/domain/repositories/feedback_repository.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Delivers feedback by opening the device's native email composer (via
/// `flutter_email_sender`) pre-addressed to [AppSupport.supportEmail], with the
/// screenshot attached and a diagnostics-rich body. Requires a configured mail
/// app on the device; [send] throws otherwise so the UI can fall back.
class EmailFeedbackRepositoryImpl implements FeedbackRepository {
  EmailFeedbackRepositoryImpl({DeviceInfoPlugin? deviceInfo})
    : _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  final DeviceInfoPlugin _deviceInfo;

  @override
  Future<void> send(FeedbackReport report) async {
    final attachments = await _screenshotAttachment(report.screenshot);
    final email = Email(
      subject: _subject(report),
      recipients: const [AppSupport.supportEmail],
      body: await _body(report),
      attachmentPaths: attachments,
    );
    await FlutterEmailSender.send(email);
  }

  String _subject(FeedbackReport report) {
    final rating = report.rating > 0 ? ' (${report.rating}★)' : '';
    return '${AppSupport.feedbackSubjectPrefix} — ${report.category.label}$rating';
  }

  Future<String> _body(FeedbackReport report) async {
    final message = report.message.trim();
    final buffer = StringBuffer()
      ..writeln(message.isEmpty ? '(no message)' : message)
      ..writeln()
      ..writeln('———')
      ..writeln('Category: ${report.category.label}')
      ..writeln(
        'Rating: ${report.rating > 0 ? '${report.rating}/5' : 'not rated'}',
      );
    (await _diagnostics()).forEach(
      (key, value) => buffer.writeln('$key: $value'),
    );
    return buffer.toString();
  }

  /// App + device context appended to the body to speed up triage. Best-effort:
  /// a failing lookup falls back to a placeholder rather than aborting the send.
  Future<Map<String, String>> _diagnostics() async {
    final info = <String, String>{};
    try {
      final pkg = await PackageInfo.fromPlatform();
      info['App'] = '${pkg.appName} ${pkg.version} (${pkg.buildNumber})';
    } catch (_) {
      info['App'] = '${AppConstants.appName} ${AppConstants.appVersion}';
    }
    info['Platform'] = defaultTargetPlatform.name;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = await _deviceInfo.androidInfo;
        info['Device'] = '${android.manufacturer} ${android.model}';
        info['OS'] =
            'Android ${android.version.release} (SDK ${android.version.sdkInt})';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = await _deviceInfo.iosInfo;
        info['Device'] = ios.utsname.machine;
        info['OS'] = '${ios.systemName} ${ios.systemVersion}';
      }
    } catch (_) {
      info['Device'] = 'unavailable';
    }
    return info;
  }

  /// Writes the PNG bytes to a temp file and returns it as a single-item
  /// attachment list, or null if there is nothing to attach / the write fails
  /// (feedback still sends, just without the image).
  Future<List<String>?> _screenshotAttachment(Uint8List bytes) async {
    if (bytes.isEmpty) return null;
    try {
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/detoxo_feedback_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes, flush: true);
      return [file.path];
    } catch (_) {
      return null;
    }
  }
}
