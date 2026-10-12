import 'package:ear_loc_alert/features/diagnostics/data/bug_report_sender.dart';
import 'package:flutter/services.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const origin = Rect.fromLTWH(0, 0, 10, 10);

  test('메일 작성 화면이 열리면 받는 사람과 첨부가 채워진다', () async {
    Email? sent;
    var shared = false;
    final sender = BugReportSender(
      sendEmail: (email) async => sent = email,
      shareFiles:
          ({
            required paths,
            required subject,
            required text,
            required origin,
          }) async {
            shared = true;
          },
    );

    final outcome = await sender.send(
      subject: '제목',
      body: '본문',
      origin: origin,
      attachmentPath: '/tmp/log.txt',
    );

    expect(outcome, BugReportOutcome.mailComposer);
    expect(shared, isFalse);
    expect(sent!.recipients, [bugReportAddress]);
    expect(sent!.attachmentPaths, ['/tmp/log.txt']);
    expect(sent!.body, '본문');
  });

  test('기록을 첨부하지 않으면 첨부 경로가 비어 있다', () async {
    Email? sent;
    final sender = BugReportSender(
      sendEmail: (email) async => sent = email,
      shareFiles:
          ({
            required paths,
            required subject,
            required text,
            required origin,
          }) async {},
    );

    await sender.send(subject: 's', body: 'b', origin: origin);

    expect(sent!.attachmentPaths, isNull);
  });

  test('iOS 에 메일 계정이 없으면(not_available) 공유 시트로 물러난다', () async {
    List<String>? sharedPaths;
    String? sharedText;
    final sender = BugReportSender(
      sendEmail: (_) async =>
          throw PlatformException(code: 'not_available', message: 'no mail'),
      shareFiles:
          ({
            required paths,
            required subject,
            required text,
            required origin,
          }) async {
            sharedPaths = paths;
            sharedText = text;
          },
    );

    final outcome = await sender.send(
      subject: 's',
      body: '본문',
      origin: origin,
      attachmentPath: '/tmp/log.txt',
      fallbackNotice: '안내',
    );

    expect(outcome, BugReportOutcome.shareSheet);
    // 첨부는 그대로 가고, 받는 사람은 본문 앞 안내에 적힌다
    expect(sharedPaths, ['/tmp/log.txt']);
    expect(sharedText, '안내\n\n본문');
  });

  test('메일도 공유도 안 되면 실패로 알리고 주소를 복사한다', () async {
    String? clipboard;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String?;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    final sender = BugReportSender(
      sendEmail: (_) async => throw PlatformException(code: 'x'),
      shareFiles:
          ({
            required paths,
            required subject,
            required text,
            required origin,
          }) async => throw PlatformException(code: 'y'),
    );

    final outcome = await sender.send(subject: 's', body: 'b', origin: origin);

    expect(outcome, BugReportOutcome.failed);
    expect(clipboard, bugReportAddress);
  });

  test('기기 정보에는 앱 버전과 OS 가 있고 좌표는 없다', () {
    final info = BugReportSender.deviceInfo(
      appVersion: '1.29.1 (130)',
      locale: 'ko',
    );

    expect(info, contains('App: 1.29.1 (130)'));
    expect(info, contains('OS: '));
    expect(info, contains('Locale: ko'));
    expect(info, isNot(contains('37.')));
  });
}
