import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/diagnostics/diagnostics.dart';
import '../domain/bug_report_sending.dart';

export '../domain/bug_report_sending.dart';

typedef EmailSend = Future<void> Function(Email email);
typedef ShareFiles =
    Future<void> Function({
      required List<String> paths,
      required String subject,
      required String text,
      required Rect origin,
    });

/// 문제 신고 메일을 연다 (이슈 #255)
///
/// **iOS 에서는 메일 계정이 없으면 작성 화면이 아예 안 열린다**
/// (`MFMailComposeViewController.canSendMail()` 이 false → `not_available`).
/// 시뮬레이터와, 기본 메일 앱을 쓰지 않는 사용자가 여기 해당한다. 그래서
/// 실패하면 조용히 끝내지 않고 **공유 시트로 물러난다** — 첨부 파일은
/// 그대로 가고, 받는 사람만 본문에 적어 둔다.
class BugReportSender implements BugReportSending {
  BugReportSender({EmailSend? sendEmail, ShareFiles? shareFiles})
    : _sendEmail = sendEmail ?? FlutterEmailSender.send,
      _shareFiles = shareFiles ?? _defaultShare;

  final EmailSend _sendEmail;
  final ShareFiles _shareFiles;

  static Future<void> _defaultShare({
    required List<String> paths,
    required String subject,
    required String text,
    required Rect origin,
  }) async {
    // iOS 26 은 iPhone 에서도 공유 시트를 popover 로 띄워 기준 위치가 없으면
    // 예외가 난다 (이슈 #241)
    await Share.shareXFiles(
      [for (final path in paths) XFile(path, mimeType: 'text/plain')],
      subject: subject,
      text: text,
      sharePositionOrigin: origin,
    );
  }

  @override
  Future<BugReportOutcome> send({
    required String subject,
    required String body,
    required Rect origin,
    String? attachmentPath,
    String? fallbackNotice,
  }) async {
    final attached = attachmentPath != null;
    try {
      await _sendEmail(
        Email(
          subject: subject,
          body: body,
          recipients: const [bugReportAddress],
          attachmentPaths: attached ? [attachmentPath] : null,
        ),
      );
      Diagnostics.log('report', 'mail composer opened attached=$attached');
      return BugReportOutcome.mailComposer;
    } on Object catch (error) {
      // 사유를 남긴다: 삼키기만 하면 왜 공유 시트로 갔는지 알 수 없다
      Diagnostics.log(
        'report',
        'mail composer failed attached=$attached error=$error fallback=share',
      );
    }

    try {
      await _shareFiles(
        paths: [if (attached) attachmentPath],
        subject: subject,
        text: [if (fallbackNotice != null) fallbackNotice, body].join('\n\n'),
        origin: origin,
      );
      Diagnostics.log('report', 'share sheet opened attached=$attached');
      return BugReportOutcome.shareSheet;
    } on Object catch (error) {
      Diagnostics.log('report', 'share sheet failed error=$error');
    }

    // 마지막 수단 — 주소라도 복사해 사용자가 직접 보낼 수 있게 한다
    try {
      await Clipboard.setData(const ClipboardData(text: bugReportAddress));
    } on Object catch (error) {
      Diagnostics.log('report', 'address copy failed error=$error');
    }
    return BugReportOutcome.failed;
  }

  /// 메일 본문의 기기 정보 줄. **좌표는 넣지 않는다** — 좌표는 첨부 기록에만 있다
  ///
  /// [device] 는 네이티브가 모은 기기·앱 기본 정보 한 줄이다(이슈 #260).
  /// 못 읽었거나(`?`) 비어 있으면 줄을 넣지 않는다.
  @override
  String describeDevice({
    required String appVersion,
    String? locale,
    String? device,
  }) => deviceInfo(appVersion: appVersion, locale: locale, device: device);

  static String deviceInfo({
    required String appVersion,
    String? locale,
    String? device,
  }) {
    return [
      'App: $appVersion',
      'OS: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      if (locale != null) 'Locale: $locale',
      if (device != null && device.isNotEmpty && device != '?')
        'Device: $device',
    ].join('\n');
  }
}
