import 'package:flutter/material.dart';

import '../../../core/config/build_info.dart';
import '../../../core/diagnostics/debug_report.dart';
import '../../../core/diagnostics/diagnostics.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/ui/components/bottom_sheet_with_header_layout.dart';
import '../../../core/ui/feedback/app_feedback.dart';
import '../../../core/text/keep_all.dart';
import '../../../core/ui/foundation/app_color_palette.dart';
import '../domain/bug_report_sending.dart';

/// 문제 신고 시트 (이슈 #255)
///
/// 메일 앱을 열어 주는 데까지만 한다. **보내는 것은 사용자다** — 작성 화면에서
/// 첨부를 확인하고 직접 보내야 전송된다. 그래서 앱이 좌표를 몰래 전송하지 않는다.
Future<void> showBugReportSheet(
  BuildContext context, {
  required String appVersion,
  required BugReportSending sender,
  required Future<String> Function() collectAppState,
}) {
  return showAppBottomSheet<void>(
    context,
    builder: (_) => _BugReportSheet(
      appVersion: appVersion,
      sender: sender,
      collectAppState: collectAppState,
    ),
  );
}

class _BugReportSheet extends StatefulWidget {
  const _BugReportSheet({
    required this.appVersion,
    required this.sender,
    required this.collectAppState,
  });

  final String appVersion;
  final BugReportSending sender;

  /// 첨부 보고서의 앱 상태 구역 (app 계층이 넣는다, 이슈 #290)
  final Future<String> Function() collectAppState;

  @override
  State<_BugReportSheet> createState() => _BugReportSheetState();
}

class _BugReportSheetState extends State<_BugReportSheet> {
  final _sendKey = GlobalKey();

  /// 기록이 비어도 앱 상태는 늘 담기므로 기본으로 켠다 (이슈 #290)
  bool _attachLog = true;
  bool _busy = false;

  Rect _origin() {
    final box = _sendKey.currentContext?.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
    final size = MediaQuery.sizeOf(context);
    return Rect.fromCenter(
      center: size.center(Offset.zero),
      width: 1,
      height: 1,
    );
  }

  Future<void> _send() async {
    if (_busy) return;
    final l10n = context.l10n;
    // await 뒤에는 context 를 쓰지 않도록 줄바꿈 처리한 문구를 미리 구한다
    final failedText = context.keepAllText(l10n.reportFailed);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final origin = _origin();
    final locale = Localizations.localeOf(context).toLanguageTag();
    setState(() => _busy = true);

    String? attachmentPath;
    if (_attachLog) {
      try {
        final report = await DebugReport.writeFile(
          appState: await widget.collectAppState(),
        );
        attachmentPath = report.path;
      } on Object catch (error) {
        // 보고서를 못 만들어도 신고는 보낼 수 있어야 한다
        Diagnostics.log('report', 'debug report failed error=$error');
      }
    }

    final body = [
      l10n.reportMailPrompt,
      '\n\n',
      '----',
      l10n.reportMailInfoHeader,
      widget.sender.describeDevice(
        appVersion: widget.appVersion,
        locale: locale,
        device: BuildInfo.deviceLabel,
      ),
    ].join('\n');

    final outcome = await widget.sender.send(
      subject: l10n.reportMailSubject,
      body: body,
      origin: origin,
      attachmentPath: attachmentPath,
      fallbackNotice: l10n.reportFallbackNotice(bugReportAddress),
    );

    if (!mounted) return;
    setState(() => _busy = false);
    switch (outcome) {
      case BugReportOutcome.mailComposer:
      case BugReportOutcome.shareSheet:
        navigator.pop();
      case BugReportOutcome.failed:
        showToastOnMessenger(messenger, failedText);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BottomSheetWithHeaderLayout(
      headerIcon: Icons.mail_outlined,
      title: l10n.reportSheetTitle,
      description: l10n.reportSheetHint,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _attachLog,
            onChanged: _busy
                ? null
                : (value) => setState(() => _attachLog = value ?? false),
            title: Text(
              l10n.reportAttachLog,
              style: context.appTextStyles.body,
            ),
            subtitle: Text(
              context.keepAllText(l10n.reportAttachLogNote),
              style: context.appTextStyles.caption,
            ),
          ),
        ],
      ),
      primaryAction: FilledButton(
        key: _sendKey,
        onPressed: _busy ? null : _send,
        child: Text(l10n.reportOpenMail),
      ),
    );
  }
}
